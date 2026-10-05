import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../services/deep_links.dart';
import '../services/team_service.dart';
import '../services/ui.dart';
import '../state/app_state.dart';
import 'auth_screen.dart';
import 'home_shell.dart';
import 'profile_screen.dart';
import 'team_gate_screen.dart';

/// Decides which screen to show: login -> profile -> team -> app.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    Widget child;
    if (app.authLoading || app.profileLoading) {
      child = const Splash();
    } else if (app.user == null) {
      child = const AuthScreen();
    } else if (app.profile == null || !app.profile!.isComplete) {
      child = const ProfileScreen(setup: true);
    } else if (app.team == null) {
      child = app.teamLoading ? const Splash() : const TeamGateScreen();
    } else {
      child = const HomeShell();
    }
    return PendingJoinListener(child: child);
  }
}

class Splash extends StatelessWidget {
  const Splash({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/images/logo.png', width: 120),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ]),
        ),
      );
}

/// Opens a "join team?" dialog when the app was opened via an invite link.
class PendingJoinListener extends StatefulWidget {
  const PendingJoinListener({super.key, required this.child});
  final Widget child;

  @override
  State<PendingJoinListener> createState() => _PendingJoinListenerState();
}

class _PendingJoinListenerState extends State<PendingJoinListener> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    DeepLinks.pendingCode.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant PendingJoinListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void dispose() {
    DeepLinks.pendingCode.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());

  Future<void> _check() async {
    final code = DeepLinks.pendingCode.value;
    if (code == null || _busy || !mounted) return;
    final app = context.read<AppState>();
    final me = app.profile;
    if (app.user == null || me == null || !me.isComplete) return; // later
    _busy = true;
    DeepLinks.pendingCode.value = null;
    final s = S.of(context);
    final ok = await confirm(context,
        title: s.t('joinTeam'),
        message: s.t('joinWithCode', {'code': code}),
        ok: s.t('join'),
        cancel: s.t('cancel'));
    if (ok) {
      try {
        final r = await TeamService.joinTeam(code: code, me: me);
        toast(s.joinResult(r));
      } catch (e) {
        toast('${s.t('error')}: $e');
      }
    }
    _busy = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
