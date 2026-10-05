import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/db.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/avatar.dart';
import 'run_result_screen.dart';
import 'run_screen.dart';

/// Choose a distance, start a timed run, see all results of this session.
/// Only team members can see these results (Firestore rules).
class TimingTab extends StatefulWidget {
  const TimingTab({super.key, required this.session});
  final Session session;

  @override
  State<TimingTab> createState() => _TimingTabState();
}

class _TimingTabState extends State<TimingTab> {
  static const presets = [100.0, 200.0, 250.0, 500.0, 1000.0, 2600.0];
  double _distance = 200;
  bool _custom = false;
  bool _onlyMine = false;
  Stream<List<Run>>? _stream;

  @override
  void initState() {
    super.initState();
    final teamId = context.read<AppState>().team!.id;
    _stream = Db.runsStream(teamId, widget.session.id);
  }

  Future<void> _askCustom() async {
    final s = S.of(context);
    final ctrl = TextEditingController(
        text: _custom ? _distance.toStringAsFixed(0) : '');
    final v = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.t('customDistance')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'm'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: Text(s.t('cancel'))),
          FilledButton(
            onPressed: () {
              final d = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(c, d != null && d >= 10 && d <= 50000 ? d : null);
            },
            child: Text(s.t('ok')),
          ),
        ],
      ),
    );
    if (v != null) {
      setState(() {
        _distance = v;
        _custom = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final app = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(s.t('chooseDistance'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in presets)
            ChoiceChip(
              label: Text('${d.toStringAsFixed(0)} m'),
              selected: !_custom && _distance == d,
              onSelected: (_) => setState(() {
                _distance = d;
                _custom = false;
              }),
            ),
          ChoiceChip(
            avatar: const Icon(Icons.edit, size: 16),
            label: Text(_custom
                ? '${_distance.toStringAsFixed(0)} m'
                : s.t('custom')),
            selected: _custom,
            onSelected: (_) => _askCustom(),
          ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                textStyle: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RunScreen(
                    session: widget.session, targetMeters: _distance),
              ),
            ),
            icon: const Icon(Icons.play_arrow, size: 30),
            label: Text('START · ${formatDistance(_distance)}'),
          ),
        ),
        const SizedBox(height: 8),
        Text(s.t('startHint'), style: Theme.of(context).textTheme.bodySmall),
        const Divider(height: 32),
        Row(children: [
          Expanded(
            child: Text(s.t('results'),
                style: Theme.of(context).textTheme.titleMedium),
          ),
          FilterChip(
            label: Text(s.t('onlyMine')),
            selected: _onlyMine,
            onSelected: (v) => setState(() => _onlyMine = v),
          ),
        ]),
        StreamBuilder<List<Run>>(
          stream: _stream,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final runs = snap.data!
                .where((r) => !_onlyMine || r.uid == app.uid)
                .toList();
            if (runs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(s.t('noRuns'))),
              );
            }
            return Column(children: [
              for (final r in runs)
                Card(
                  child: ListTile(
                    leading: Avatar(
                        url: app.member(r.uid)?.photoUrl, name: r.name),
                    title: Text(
                        '${r.name} · ${formatDistance(r.targetMeters)}'),
                    subtitle: Text(
                        '⏱ ${formatRaceTime(r.timeMs)}   '
                        '▲ ${formatSpeed(r.maxSpeed)}   '
                        '▼ ${formatSpeed(r.minSpeed)}'),
                    trailing: const Icon(Icons.map_outlined),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => RunResultScreen(
                              run: r, sessionId: widget.session.id)),
                    ),
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }
}
