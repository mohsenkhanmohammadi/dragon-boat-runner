import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/db.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/avatar.dart';
import 'run_result_screen.dart';

/// Team ranking: best time of every member per distance.
/// Filter: all runs / only races / only trainings.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const distances = [100.0, 200.0, 250.0, 500.0, 1000.0, 2600.0];
  double _distance = 200;
  String _filter = 'all'; // all | race | training
  Stream<List<Run>>? _stream;
  String? _key;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final app = context.watch<AppState>();
    final team = app.team!;
    final key = '${team.id}/$_distance';
    if (_key != key) {
      _key = key;
      _stream = Db.leaderboard(team.id, _distance);
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.t('leaderboard'))),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final d in distances)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(formatDistance(d)),
                    selected: _distance == d,
                    onSelected: (_) => setState(() => _distance = d),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'all', label: Text(s.t('all'))),
              ButtonSegment(
                  value: 'race',
                  icon: const Icon(Icons.emoji_events, size: 18),
                  label: Text(s.t('races'))),
              ButtonSegment(
                  value: 'training',
                  icon: const Icon(Icons.rowing, size: 18),
                  label: Text(s.t('trainings'))),
            ],
            selected: {_filter},
            onSelectionChanged: (v) => setState(() => _filter = v.first),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<Run>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                    child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('${s.t('error')}: ${snap.error}'),
                ));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              // best run per member
              final best = <String, Run>{};
              for (final r in snap.data!) {
                if (_filter != 'all' && r.sessionType?.name != _filter) {
                  continue;
                }
                best.putIfAbsent(r.uid, () => r);
              }
              final list = best.values.toList()
                ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.leaderboard,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(s.t('noLeaderboard'), textAlign: TextAlign.center),
                    ]),
                  ),
                );
              }
              final leader = list.first.timeMs;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final r = list[i];
                  final medal = i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}.';
                  final gap = r.timeMs - leader;
                  final isMe = r.uid == app.uid;
                  return Card(
                    color: isMe ? dragonGold.withValues(alpha: 0.18) : null,
                    child: ListTile(
                      leading: SizedBox(
                        width: 76,
                        child: Row(children: [
                          SizedBox(
                            width: 32,
                            child: Text(medal,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: i < 3 ? 24 : 16,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 4),
                          Avatar(
                              url: app.member(r.uid)?.photoUrl,
                              name: r.name,
                              radius: 18),
                        ]),
                      ),
                      title: Text(r.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([
                        formatSpeed(r.avgSpeed),
                        if (r.sessionStart != null)
                          formatDate(r.sessionStart!, app.lang),
                      ].join(' · ')),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatRaceTime(r.timeMs),
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ])),
                          if (gap > 0)
                            Text('+${formatRaceTime(gap)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => RunResultScreen(
                                run: r, sessionId: r.sessionId)),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
