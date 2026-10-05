import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../screens/session_detail_screen.dart';
import '../services/db.dart';
import '../services/ui.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'avatar.dart';

IconData sessionIcon(SessionType t) => switch (t) {
      SessionType.training => Icons.rowing,
      SessionType.race => Icons.emoji_events,
      SessionType.event => Icons.celebration,
    };

Color sessionColor(SessionType t) => switch (t) {
      SessionType.training => dragonRed,
      SessionType.race => const Color(0xFF7C3AED),
      SessionType.event => const Color(0xFF0E7490),
    };

String sessionTitle(S s, Session x) =>
    x.title.trim().isNotEmpty ? x.title : s.sessionType(x.type);

/// Card for one training / race / event, optionally with the RSVP controls.
class SessionCard extends StatelessWidget {
  const SessionCard({super.key, required this.session, this.showRsvp = true});
  final Session session;
  final bool showRsvp;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = context.select<AppState, String>((a) => a.lang);
    final c = sessionColor(session.type);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SessionDetailScreen(sessionId: session.id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: c.withValues(alpha: 0.12),
                  child: Icon(sessionIcon(session.type), color: c, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sessionTitle(s, session),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        [
                          formatDateTime(session.start, lang),
                          if (session.location != null) session.location!,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ]),
              if (showRsvp) ...[
                const SizedBox(height: 8),
                RsvpBar(session: session),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 👍 / 👎 / ❓ + left/right paddle side + "who is coming".
class RsvpBar extends StatefulWidget {
  const RsvpBar({super.key, required this.session});
  final Session session;

  @override
  State<RsvpBar> createState() => _RsvpBarState();
}

class _RsvpBarState extends State<RsvpBar> {
  Stream<Map<String, Rsvp>>? _stream;
  String? _key;

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
        final map = snap.data ?? const <String, Rsvp>{};
        final mine = map[app.uid];
        int count(RsvpStatus st) =>
            map.values.where((r) => r.status == st).length;

        final started = session.isStarted;
        final locked = session.isLocked;
        bool canSet(RsvpStatus st) =>
            !started && (!locked || st == RsvpStatus.no);

        Future<void> set({RsvpStatus? status, Side? side, bool clear = false}) async {
          try {
            await Db.setRsvp(team.id, session.id, app.uid,
                status: status, side: side, clearSide: clear);
          } catch (e) {
            toast(s.t('rsvpClosed'));
          }
        }

        final showSide = mine?.status == RsvpStatus.yes ||
            mine?.status == RsvpStatus.maybe;
        final blue = mine?.sideByAdmin == true;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _StatusButton(
                icon: Icons.thumb_up,
                color: yesGreen,
                tooltip: s.t('yes'),
                count: count(RsvpStatus.yes),
                selected: mine?.status == RsvpStatus.yes,
                onTap: canSet(RsvpStatus.yes)
                    ? () => set(status: RsvpStatus.yes)
                    : null,
              ),
              _StatusButton(
                icon: Icons.thumb_down,
                color: noRed,
                tooltip: s.t('no'),
                count: count(RsvpStatus.no),
                selected: mine?.status == RsvpStatus.no,
                onTap: canSet(RsvpStatus.no)
                    ? () => set(status: RsvpStatus.no)
                    : null,
              ),
              _StatusButton(
                icon: Icons.question_mark,
                color: maybeAmber,
                tooltip: s.t('maybe'),
                count: count(RsvpStatus.maybe),
                selected: mine?.status == RsvpStatus.maybe,
                onTap: canSet(RsvpStatus.maybe)
                    ? () => set(status: RsvpStatus.maybe)
                    : null,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => showAttendanceSheet(context, session),
                icon: const Icon(Icons.groups, size: 20),
                label: Text(s.t('whoIsComing')),
              ),
            ]),
            if (showSide)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Text(s.t('paddleSide'),
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 8),
                  SegmentedButton<Side>(
                    showSelectedIcon: false,
                    emptySelectionAllowed: true,
                    style: blue
                        ? SegmentedButton.styleFrom(
                            selectedBackgroundColor: adminBlue,
                            selectedForegroundColor: Colors.white)
                        : null,
                    segments: [
                      ButtonSegment(value: Side.left, label: Text(s.t('left'))),
                      ButtonSegment(
                          value: Side.right, label: Text(s.t('right'))),
                    ],
                    selected: mine?.side == null ? <Side>{} : {mine!.side!},
                    onSelectionChanged: locked
                        ? null
                        : (v) => v.isEmpty
                            ? set(clear: true)
                            : set(side: v.first),
                  ),
                  if (blue) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(s.t('setByAdmin'),
                          style: const TextStyle(
                              color: adminBlue, fontSize: 12)),
                    ),
                  ],
                ]),
              ),
            if (started)
              _hint(context, s.t('sessionStarted'))
            else if (locked)
              _hint(context, s.t('rsvpLockedHint')),
          ],
        );
      },
    );
  }

  Widget _hint(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          const Icon(Icons.lock_clock, size: 14),
          const SizedBox(width: 4),
          Flexible(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      );
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.icon,
    required this.color,
    required this.selected,
    required this.count,
    required this.tooltip,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final bool selected;
  final int count;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? color : color.withValues(alpha: 0.08),
          shape: StadiumBorder(
              side: BorderSide(color: color.withValues(alpha: 0.5))),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Opacity(
                opacity: disabled && !selected ? 0.4 : 1,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 18, color: selected ? Colors.white : color),
                  const SizedBox(width: 4),
                  Text('$count',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : color)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showAttendanceSheet(BuildContext context, Session session) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => SizedBox(
      height: MediaQuery.of(c).size.height * 0.75,
      child: AttendanceList(session: session),
    ),
  );
}

/// Everybody's answer for one session, grouped. Admins can set the paddle
/// side of a member here (shown in blue).
class AttendanceList extends StatefulWidget {
  const AttendanceList({super.key, required this.session, this.shrinkWrap = false});
  final Session session;
  final bool shrinkWrap;

  @override
  State<AttendanceList> createState() => _AttendanceListState();
}

class _AttendanceListState extends State<AttendanceList> {
  Stream<Map<String, Rsvp>>? _stream;
  String? _key;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final app = context.watch<AppState>();
    final team = app.team;
    if (team == null) return const SizedBox();
    final key = '${team.id}/${widget.session.id}';
    if (_key != key) {
      _key = key;
      _stream = Db.rsvpsStream(team.id, widget.session.id);
    }
    return StreamBuilder<Map<String, Rsvp>>(
      stream: _stream,
      builder: (context, snap) {
        final map = snap.data ?? const <String, Rsvp>{};
        final groups = <RsvpStatus?, List<Member>>{
          RsvpStatus.yes: [],
          RsvpStatus.maybe: [],
          RsvpStatus.no: [],
          null: [],
        };
        for (final m in app.members) {
          groups[map[m.uid]?.status]!.add(m);
        }
        final children = <Widget>[];
        groups.forEach((status, list) {
          final (label, color, icon) = switch (status) {
            RsvpStatus.yes => (s.t('yes'), yesGreen, Icons.thumb_up),
            RsvpStatus.no => (s.t('no'), noRed, Icons.thumb_down),
            RsvpStatus.maybe => (s.t('maybe'), maybeAmber, Icons.question_mark),
            null => (s.t('noAnswer'), Colors.grey, Icons.hourglass_empty),
          };
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text('$label (${list.length})',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700)),
            ]),
          ));
          for (final m in list) {
            children.add(_tile(context, s, app, team.id, m, map[m.uid]));
          }
        });
        return ListView(
          shrinkWrap: widget.shrinkWrap,
          physics: widget.shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : null,
          children: children,
        );
      },
    );
  }

  Widget _tile(BuildContext context, S s, AppState app, String teamId,
      Member m, Rsvp? r) {
    final side = r?.side;
    final blue = r?.sideByAdmin == true;
    Widget? sideChip;
    if (side != null) {
      sideChip = Chip(
        visualDensity: VisualDensity.compact,
        backgroundColor: blue ? adminBlue : null,
        label: Text(side == Side.left ? s.t('leftShort') : s.t('rightShort'),
            style: TextStyle(
                color: blue ? Colors.white : null,
                fontWeight: FontWeight.w700)),
      );
    }
    return ListTile(
      dense: true,
      leading: Avatar(url: m.photoUrl, name: m.displayName, radius: 18),
      title: Text(m.displayName),
      subtitle: app.isManager && m.weight != null
          ? Text('${m.weight!.toStringAsFixed(m.weight! % 1 == 0 ? 0 : 1)} kg')
          : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (sideChip != null) sideChip,
        if (app.isManager)
          PopupMenuButton<String>(
            tooltip: s.t('setSide'),
            icon: const Icon(Icons.swap_horiz, color: adminBlue),
            onSelected: (v) async {
              try {
                await Db.setRsvp(teamId, widget.session.id, m.uid,
                    side: v == 'L'
                        ? Side.left
                        : v == 'R'
                            ? Side.right
                            : null,
                    clearSide: v == 'X',
                    byAdmin: true);
              } catch (e) {
                toast('${s.t('error')}: $e');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'L', child: Text(s.t('left'))),
              PopupMenuItem(value: 'R', child: Text(s.t('right'))),
              PopupMenuItem(value: 'X', child: Text(s.t('clearSide'))),
            ],
          ),
      ]),
    );
  }
}
