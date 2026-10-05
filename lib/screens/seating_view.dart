import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/db.dart';
import '../services/seating.dart';
import '../services/team_service.dart';
import '../services/ui.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/boat_view.dart';

/// Boat picture with the seating of all members who said 👍.
/// ≤ 12 attendees -> small boat (5 rows), otherwise large boat (10 rows).
/// Admin / co-admin can change seats (blue), auto-balance by weight,
/// save and apply a default seating.
class SeatingView extends StatefulWidget {
  const SeatingView({super.key, required this.session});
  final Session session;

  @override
  State<SeatingView> createState() => _SeatingViewState();
}

class _SeatingViewState extends State<SeatingView> {
  Stream<Map<String, Rsvp>>? _stream;
  String? _key;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final app = context.watch<AppState>();
    final team = app.team!;
    final session = widget.session;
    final key = '${team.id}/${session.id}';
    if (_key != key) {
      _key = key;
      _stream = Db.rsvpsStream(team.id, session.id);
    }

    return StreamBuilder<Map<String, Rsvp>>(
      stream: _stream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rsvps = snap.data!;
        final attendees = app.members
            .where((m) => rsvps[m.uid]?.status == RsvpStatus.yes)
            .toList();
        final memberMap = {for (final m in app.members) m.uid: m};
        final attendeeIds = attendees.map((m) => m.uid).toSet();
        final boat = session.boat != null
            ? BoatSpec.byId(session.boat!)
            : BoatSpec.forAttendees(attendees.length);
        final candidates = [
          for (final m in attendees)
            SeatCandidate(m.uid, weight: m.weight, pref: rsvps[m.uid]?.side)
        ];

        final isSaved = session.seats.isNotEmpty;
        Map<String, String> seats;
        Set<String> manual;
        if (isSaved) {
          seats = {
            for (final e in session.seats.entries)
              if (boat.hasSeat(e.key) && attendeeIds.contains(e.value))
                e.key: e.value
          };
          manual = session.manualSeats.where(seats.containsKey).toSet();
        } else {
          seats = autoSeat(boat, candidates,
                  fixed: team.defaultLayouts[boat.id] ?? const {})
              .seats;
          manual = <String>{};
        }
        final seated = seats.values.toSet();
        final reserves =
            attendees.where((m) => !seated.contains(m.uid)).toList();
        final weights = {for (final m in attendees) m.uid: m.weight};
        final stats = balanceOf(boat, seats, weights);

        Future<void> save(Map<String, String> newSeats, Set<String> newManual,
            {String? boatId, bool keepBoat = true}) async {
          setState(() => _busy = true);
          try {
            await Db.saveSeating(team.id, session.id,
                boat: keepBoat ? session.boat : boatId,
                seats: newSeats,
                manual: newManual);
          } catch (e) {
            toast('${s.t('error')}: $e');
          }
          if (mounted) setState(() => _busy = false);
        }

        Map<String, String> fixedManual(BoatSpec b) => {
              for (final seat in manual)
                if (b.hasSeat(seat) && seats[seat] != null) seat: seats[seat]!
            };

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                    avatar: const Icon(Icons.thumb_up, size: 16, color: yesGreen),
                    label: Text(s.t('attendeesN',
                        {'n': '${attendees.length}'}))),
                Chip(
                    avatar: const Icon(Icons.directions_boat, size: 16),
                    label: Text(boat == BoatSpec.small
                        ? s.t('smallBoat')
                        : s.t('largeBoat'))),
                if (!isSaved)
                  Chip(
                      avatar: const Icon(Icons.auto_awesome, size: 16),
                      label: Text(s.t('autoSuggestion'))),
              ],
            ),
            if (app.isManager) ...[
              const SizedBox(height: 8),
              _managerTools(context, s, team, boat, candidates, seats, manual,
                  save, fixedManual),
            ],
            const SizedBox(height: 12),
            BoatView(
              boat: boat,
              seats: seats,
              manual: manual,
              members: memberMap,
              showWeights: app.isManager,
              highlightUid: app.uid,
              onSeatTap: app.isManager && !_busy
                  ? (seat) => _pickForSeat(context, s, seat, attendees, seats,
                      manual, rsvps, save, team.id)
                  : null,
            ),
            const SizedBox(height: 16),
            _BalanceCard(stats: stats),
            if (reserves.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(s.t('reserves'),
                  style: Theme.of(context).textTheme.titleSmall),
              for (final m in reserves)
                ListTile(
                  dense: true,
                  leading: Avatar(url: m.photoUrl, name: m.displayName, radius: 16),
                  title: Text(m.displayName),
                ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                      color: adminBlue,
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 8),
              Expanded(child: Text(s.t('blueLegend'))),
            ]),
          ],
        );
      },
    );
  }

  Widget _managerTools(
    BuildContext context,
    S s,
    Team team,
    BoatSpec boat,
    List<SeatCandidate> candidates,
    Map<String, String> seats,
    Set<String> manual,
    Future<void> Function(Map<String, String>, Set<String>,
            {String? boatId, bool keepBoat})
        save,
    Map<String, String> Function(BoatSpec) fixedManual,
  ) {
    final session = widget.session;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'auto', label: Text(s.t('boatAuto'))),
              ButtonSegment(value: 'small', label: Text(s.t('boat10'))),
              ButtonSegment(value: 'large', label: Text(s.t('boat20'))),
            ],
            selected: {session.boat ?? 'auto'},
            onSelectionChanged: _busy
                ? null
                : (v) {
                    final id = v.first == 'auto' ? null : v.first;
                    final nb = id == null
                        ? BoatSpec.forAttendees(candidates.length)
                        : BoatSpec.byId(id);
                    final fixed = fixedManual(nb);
                    final r = autoSeat(nb, candidates, fixed: fixed);
                    save(r.seats, fixed.keys.toSet(),
                        boatId: id, keepBoat: false);
                  },
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            FilledButton.tonalIcon(
              onPressed: _busy
                  ? null
                  : () {
                      final fixed = fixedManual(boat);
                      final r = autoSeat(boat, candidates, fixed: fixed);
                      save(r.seats, fixed.keys.toSet());
                      toast(s.t('balanced'));
                    },
              icon: const Icon(Icons.balance),
              label: Text(s.t('autoBalance')),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => save({}, {}),
              icon: const Icon(Icons.restart_alt),
              label: Text(s.t('reset')),
            ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      await TeamService.saveDefaultLayout(
                          team.id, boat.id, seats);
                      toast(s.t('defaultSaved'));
                    },
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(s.t('saveDefault')),
            ),
            OutlinedButton.icon(
              onPressed: _busy || team.defaultLayouts[boat.id] == null
                  ? null
                  : () {
                      final r = autoSeat(boat, candidates,
                          fixed: team.defaultLayouts[boat.id]!);
                      save(r.seats, <String>{});
                      toast(s.t('defaultApplied'));
                    },
              icon: const Icon(Icons.bookmark_outline),
              label: Text(s.t('applyDefault')),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _pickForSeat(
    BuildContext context,
    S s,
    String seat,
    List<Member> attendees,
    Map<String, String> seats,
    Set<String> manual,
    Map<String, Rsvp> rsvps,
    Future<void> Function(Map<String, String>, Set<String>,
            {String? boatId, bool keepBoat})
        save,
    String teamId,
  ) async {
    String seatLabel(String id) {
      if (id == drummerSeat) return s.t('drummer');
      if (id == steerSeat) return s.t('steerer');
      final side = BoatSpec.sideOf(id) == Side.left
          ? s.t('leftShort')
          : s.t('rightShort');
      return '$side${BoatSpec.rowOf(id)}';
    }

    final where = {for (final e in seats.entries) e.value: e.key};
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SizedBox(
        height: MediaQuery.of(c).size.height * 0.7,
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('${s.t('seat')} ${seatLabel(seat)}',
                style: Theme.of(c).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.event_seat_outlined),
            title: Text(s.t('emptySeat')),
            onTap: () => Navigator.pop(c, ''),
          ),
          for (final m in attendees)
            ListTile(
              leading: Avatar(url: m.photoUrl, name: m.displayName, radius: 16),
              title: Text(m.displayName),
              subtitle: Text([
                if (m.weight != null) '${m.weight!.toStringAsFixed(0)} kg',
                if (rsvps[m.uid]?.side != null)
                  rsvps[m.uid]!.side == Side.left
                      ? s.t('prefersLeft')
                      : s.t('prefersRight'),
              ].join(' · ')),
              trailing: where[m.uid] == null
                  ? null
                  : Text(seatLabel(where[m.uid]!)),
              selected: seats[seat] == m.uid,
              onTap: () => Navigator.pop(c, m.uid),
            ),
        ]),
      ),
    );
    if (picked == null) return;

    final newSeats = Map<String, String>.from(seats);
    final newManual = Set<String>.from(manual);
    final moved = <String, String>{}; // uid -> new seat
    if (picked.isEmpty) {
      newSeats.remove(seat);
      newManual.remove(seat);
    } else {
      final from = where[picked];
      final occupant = seats[seat];
      if (from == seat) return;
      if (from != null) {
        if (occupant != null) {
          newSeats[from] = occupant;
          newManual.add(from);
          moved[occupant] = from;
        } else {
          newSeats.remove(from);
          newManual.remove(from);
        }
      }
      newSeats[seat] = picked;
      newManual.add(seat);
      moved[picked] = seat;
    }
    await save(newSeats, newManual);

    // The paddle side chosen by the admin is shown in blue for the member.
    for (final e in moved.entries) {
      final side = BoatSpec.sideOf(e.value);
      if (side != null && rsvps[e.key]?.side != side) {
        try {
          await Db.setRsvp(teamId, widget.session.id, e.key,
              side: side, byAdmin: true);
        } catch (_) {}
      }
    }
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.stats});
  final BalanceStats stats;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    String kg(double v) => '${v.toStringAsFixed(0)} kg';
    Widget bar(String a, double va, String b, double vb) {
      final total = va + vb;
      final frac = total == 0 ? 0.5 : va / total;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          Row(children: [
            Text('$a  ${kg(va)}'),
            const Spacer(),
            Text('${kg(vb)}  $b'),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 10,
              color: dragonRed,
              backgroundColor: deepWater.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text('Δ ${kg((va - vb).abs())}',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('balance'), style: Theme.of(context).textTheme.titleSmall),
          bar(s.t('left'), stats.left, s.t('right'), stats.right),
          bar(s.t('front'), stats.front, s.t('back'), stats.back),
          if (stats.unknown > 0)
            Text(s.t('unknownWeights', {'n': '${stats.unknown}'}),
                style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}
