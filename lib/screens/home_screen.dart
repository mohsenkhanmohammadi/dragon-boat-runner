import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/db.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/session_widgets.dart';

/// Start page: team photo + name, "Hallo <name>", next 5 trainings.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Stream<List<Session>>? _stream;
  String? _teamId;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final app = context.watch<AppState>();
    final team = app.team!;
    final me = app.profile!;
    if (_teamId != team.id) {
      _teamId = team.id;
      _stream = Db.upcomingSessions(team.id);
    }

    return RefreshIndicator(
      onRefresh: () async => setState(() => _teamId = null),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _TeamHeader(teamName: team.name, photoUrl: team.photoUrl)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                Avatar(url: me.photoUrl, name: me.displayName, radius: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.t('helloName', {'name': me.firstName}),
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(s.t('nextTrainings'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          StreamBuilder<List<Session>>(
            stream: _stream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final trainings = snap.data!
                  .where((x) => x.type == SessionType.training)
                  .take(5)
                  .toList();
              if (trainings.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(children: [
                      const Icon(Icons.rowing, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        app.isManager
                            ? s.t('noTrainingsManager')
                            : s.t('noTrainings'),
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                sliver: SliverList.list(
                  children: [
                    for (final t in trainings) SessionCard(session: t),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.teamName, this.photoUrl});
  final String teamName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 200 + top,
      child: Stack(fit: StackFit.expand, children: [
        if (photoUrl != null)
          Image.network(photoUrl!, fit: BoxFit.cover)
        else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [deepWater, dragonRed],
              ),
            ),
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.only(top: top),
              child: Image.asset('assets/images/logo.png', height: 110),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xCC000000)],
              stops: [0.5, 1],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14,
          child: Text(
            teamName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }
}
