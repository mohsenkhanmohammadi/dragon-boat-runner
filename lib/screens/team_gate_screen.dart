import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../services/deep_links.dart';
import '../services/team_service.dart';
import '../services/ui.dart';
import '../state/app_state.dart';
import '../widgets/lang_switch.dart';

/// Create a new team (you become admin) or join one with an invite code.
class TeamGateScreen extends StatefulWidget {
  const TeamGateScreen({super.key, this.pushed = false});

  /// true when opened from the team page (to add another team)
  final bool pushed;

  @override
  State<TeamGateScreen> createState() => _TeamGateScreenState();
}

class _TeamGateScreenState extends State<TeamGateScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _code.text = DeepLinks.pendingCode.value ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final s = S.of(context);
    final me = context.read<AppState>().profile!;
    if (_name.text.trim().isEmpty) {
      toast(s.t('teamNameRequired'));
      return;
    }
    setState(() => _busy = true);
    try {
      await TeamService.createTeam(name: _name.text, me: me);
      toast(s.t('teamCreated'));
      if (widget.pushed && mounted) Navigator.pop(context);
    } catch (e) {
      toast('${s.t('error')}: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _join() async {
    final s = S.of(context);
    final me = context.read<AppState>().profile!;
    setState(() => _busy = true);
    try {
      final r = await TeamService.joinTeam(code: _code.text, me: me);
      toast(s.joinResult(r));
      if ((r == JoinResult.joined || r == JoinResult.alreadyMember) &&
          widget.pushed &&
          mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      toast('${s.t('error')}: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pushed ? s.t('addTeam') : AppConfig.appName),
        actions: [
          const LangSwitch(),
          if (!widget.pushed)
            IconButton(
                tooltip: s.t('logout'),
                onPressed: app.signOut,
                icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!widget.pushed) ...[
            Image.asset('assets/images/logo.png', height: 100),
            const SizedBox(height: 12),
            Text(
              s.t('helloName', {'name': app.profile?.firstName ?? ''}),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(s.t('noTeamYet'), textAlign: TextAlign.center),
            const SizedBox(height: 20),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.group_add),
                    const SizedBox(width: 8),
                    Text(s.t('joinTeam'),
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                        letterSpacing: 4,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                        labelText: s.t('inviteCode'), hintText: 'ABC123'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: _busy ? null : _join, child: Text(s.t('join'))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.add_circle_outline),
                    const SizedBox(width: 8),
                    Text(s.t('createTeam'),
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 4),
                  Text(s.t('createTeamHint'),
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    maxLength: 60,
                    decoration: InputDecoration(labelText: s.t('teamName')),
                  ),
                  FilledButton.tonal(
                      onPressed: _busy ? null : _create,
                      child: Text(s.t('createTeam'))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
