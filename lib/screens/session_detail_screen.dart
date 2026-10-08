import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/db.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/session_widgets.dart';
import 'seating_view.dart';
import 'session_editor_screen.dart';
import 'timing_tab.dart';

/// One training / race / event with three tabs:
/// overview + attendance, boat seating, timed runs (GPS).
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen(
      {super.key, required this.sessionId, this.initialTab = 0});
  final String sessionId;

  /// 0 = overview, 1 = boat seating, 2 = timing
  final int initialTab;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  Stream<Session?>? _stream;

  @override
  void initState() {
    super.initState();
    final teamId = context.read<AppState>().team!.id;
    _stream = Db.sessionStream(teamId, widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final app = context.watch<AppState>();
    return StreamBuilder<Session?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()));
        }
        final session = snap.data;
        if (session == null) {
          return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(s.t('entryDeleted'))));
        }
        return DefaultTabController(
          length: 3,
          initialIndex: widget.initialTab,
          child: Scaffold(
            appBar: AppBar(
              title: Text(sessionTitle(s, session)),
              actions: [
                if (app.isManager)
                  IconButton(
                    tooltip: s.t('editEntry'),
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => SessionEditorScreen(session: session)),
                    ),
                  ),
              ],
              bottom: TabBar(tabs: [
                Tab(icon: const Icon(Icons.info_outline), text: s.t('overview')),
                Tab(icon: const Icon(Icons.rowing), text: s.t('boat')),
                Tab(icon: const Icon(Icons.timer_outlined), text: s.t('timing')),
              ]),
            ),
            body: TabBarView(children: [
              _Overview(session: session),
              SeatingView(session: session),
              TimingTab(session: session),
            ]),
          ),
        );
      },
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = context.select<AppState, String>((a) => a.lang);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          leading: Icon(sessionIcon(session.type),
              color: sessionColor(session.type)),
          title: Text(s.sessionType(session.type)),
          subtitle: Text(formatDate(session.start, lang)),
        ),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: Text('${s.t('startTime')}: ${formatTime(session.start, lang)}'),
          subtitle: Text(s.t('rsvpUntil',
              {'time': formatDateTime(session.rsvpLockAt, lang)})),
        ),
        if (session.location != null)
          ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(session.location!)),
        if (session.notes != null)
          ListTile(
              leading: const Icon(Icons.notes), title: Text(session.notes!)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: RsvpBar(session: session),
        ),
        const Divider(),
        AttendanceList(session: session, shrinkWrap: true),
      ],
    );
  }
}
