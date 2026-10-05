import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/db.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/session_widgets.dart';
import 'session_editor_screen.dart';

/// Team calendar with trainings, races and events.
/// Admin and co-admin can add entries; everybody sees them.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;
  Stream<List<Session>>? _stream;
  String? _key;

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  void _ensureStream(String teamId) {
    final key = '$teamId/${_focused.year}-${_focused.month}';
    if (key == _key) return;
    _key = key;
    final from = DateTime(_focused.year, _focused.month - 1, 20);
    final to = DateTime(_focused.year, _focused.month + 1, 12);
    _stream = Db.sessionsBetween(teamId, from, to);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final app = context.watch<AppState>();
    final team = app.team!;
    _ensureStream(team.id);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('calendar'))),
      floatingActionButton: app.isManager
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionEditorScreen(
                    initialDay: _selected.isBefore(_day(DateTime.now()))
                        ? DateTime.now()
                        : _selected,
                  ),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(s.t('addEntry')),
            )
          : null,
      body: StreamBuilder<List<Session>>(
        stream: _stream,
        builder: (context, snap) {
          final all = snap.data ?? const <Session>[];
          final byDay = <DateTime, List<Session>>{};
          for (final x in all) {
            byDay.putIfAbsent(_day(x.start), () => []).add(x);
          }
          final today = byDay[_day(_selected)] ?? const <Session>[];
          return Column(children: [
            TableCalendar<Session>(
              locale: app.lang,
              firstDay: DateTime(2020),
              lastDay: DateTime(2100),
              focusedDay: _focused,
              calendarFormat: _format,
              availableCalendarFormats: {
                CalendarFormat.month: s.t('month'),
                CalendarFormat.twoWeeks: s.t('twoWeeks'),
                CalendarFormat.week: s.t('week'),
              },
              startingDayOfWeek: StartingDayOfWeek.monday,
              selectedDayPredicate: (d) => isSameDay(d, _selected),
              eventLoader: (d) => byDay[_day(d)] ?? const [],
              onDaySelected: (sel, foc) => setState(() {
                _selected = sel;
                _focused = foc;
              }),
              onPageChanged: (foc) => setState(() => _focused = foc),
              onFormatChanged: (f) => setState(() => _format = f),
              calendarBuilders: CalendarBuilders<Session>(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  return Positioned(
                    bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final e in events.take(3))
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: sessionColor(e.type),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(formatDate(_selected, app.lang),
                    style: Theme.of(context).textTheme.titleSmall),
              ),
            ),
            Expanded(
              child: today.isEmpty
                  ? Center(child: Text(s.t('nothingThisDay')))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 88),
                      children: [
                        for (final x in today) SessionCard(session: x),
                      ],
                    ),
            ),
          ]);
        },
      ),
    );
  }
}
