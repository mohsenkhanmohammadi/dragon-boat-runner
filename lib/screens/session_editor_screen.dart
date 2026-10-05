import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/db.dart';
import '../services/ui.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/session_widgets.dart';

/// Create / edit a training, race or event (admin and co-admin only).
/// Saving triggers a push notification to all members (Cloud Function).
class SessionEditorScreen extends StatefulWidget {
  const SessionEditorScreen({super.key, this.session, this.initialDay});
  final Session? session;
  final DateTime? initialDay;

  @override
  State<SessionEditorScreen> createState() => _SessionEditorScreenState();
}

class _SessionEditorScreenState extends State<SessionEditorScreen> {
  late SessionType _type;
  late DateTime _date;
  late TimeOfDay _time;
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final x = widget.session;
    _type = x?.type ?? SessionType.training;
    final start = x?.start ??
        () {
          final d = widget.initialDay ?? DateTime.now();
          return DateTime(d.year, d.month, d.day, 18, 0);
        }();
    _date = DateTime(start.year, start.month, start.day);
    _time = TimeOfDay(hour: start.hour, minute: start.minute);
    _title.text = x?.title ?? '';
    _location.text = x?.location ?? '';
    _notes.text = x?.notes ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime get _start =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _save() async {
    final s = S.of(context);
    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      await Db.saveSession(app.team!.id, widget.session?.id,
          type: _type,
          start: _start,
          title: _title.text,
          location: _location.text,
          notes: _notes.text,
          startChanged: widget.session != null &&
              !widget.session!.start.isAtSameMomentAs(_start),
          uid: app.uid);
      toast(s.t('savedNotified'));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      toast('${s.t('error')}: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final s = S.of(context);
    final app = context.read<AppState>();
    final ok = await confirm(context,
        title: s.t('deleteEntry'),
        message: s.t('deleteEntryMsg'),
        ok: s.t('delete'),
        cancel: s.t('cancel'),
        danger: true);
    if (!ok) return;
    try {
      await Db.deleteSession(app.team!.id, widget.session!.id);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      toast('${s.t('error')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = context.select<AppState, String>((a) => a.lang);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session == null ? s.t('newEntry') : s.t('editEntry')),
        actions: [
          if (widget.session != null)
            IconButton(
                tooltip: s.t('delete'),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<SessionType>(
            segments: [
              for (final t in SessionType.values)
                ButtonSegment(
                    value: t,
                    icon: Icon(sessionIcon(t)),
                    label: Text(s.sessionType(t))),
            ],
            selected: {_type},
            onSelectionChanged: (v) => setState(() => _type = v.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: InputDecoration(
                labelText: s.t('title'),
                hintText: s.sessionType(_type),
                helperText: s.t('optional')),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(formatDate(_date, lang)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule),
            label: Text('${s.t('startTime')}: ${formatTime(_start, lang)}'),
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _location,
            decoration: InputDecoration(
                labelText: s.t('location'),
                prefixIcon: const Icon(Icons.place_outlined),
                helperText: s.t('optional')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: InputDecoration(
                labelText: s.t('notes'), helperText: s.t('optional')),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(s.t('save')),
          ),
        ],
      ),
    );
  }
}
