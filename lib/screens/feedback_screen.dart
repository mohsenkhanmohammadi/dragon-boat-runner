import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../services/db.dart';
import '../services/ui.dart';
import '../state/app_state.dart';

/// Feedback form. The text is e-mailed to the developer by a Cloud Function;
/// the e-mail address is never shown in the app.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final s = S.of(context);
    final app = context.read<AppState>();
    if (_text.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await Db.sendFeedback(
          text: _text.text, me: app.profile!, lang: app.lang);
      toast(s.t('feedbackThanks'));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      toast('${s.t('error')}: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('feedback'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(s.t('feedbackIntro')),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            minLines: 8,
            maxLines: 16,
            maxLength: 3000,
            decoration: InputDecoration(hintText: s.t('feedbackHint')),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy || _text.text.trim().isEmpty ? null : _send,
            icon: const Icon(Icons.send),
            label: Text(s.t('send')),
          ),
        ],
      ),
    );
  }
}
