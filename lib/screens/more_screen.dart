import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../widgets/avatar.dart';
import 'feedback_screen.dart';
import 'profile_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final app = context.watch<AppState>();
    final me = app.profile!;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('navMore'))),
      body: ListView(children: [
        ListTile(
          leading: Avatar(url: me.photoUrl, name: me.displayName),
          title: Text(me.displayName),
          subtitle: Text(me.email ?? me.phone ?? ''),
          trailing: const Icon(Icons.edit),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProfileScreen())),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(s.t('language')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'de', label: Text('🇩🇪  Deutsch')),
              ButtonSegment(value: 'en', label: Text('🇬🇧  English')),
            ],
            selected: {app.lang},
            onSelectionChanged: (v) => app.setLang(v.first),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.feedback_outlined),
          title: Text(s.t('feedback')),
          subtitle: Text(s.t('feedbackSub')),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const FeedbackScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(s.t('about')),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: AppConfig.appName,
            applicationVersion: '1.0.0',
            applicationIcon: Image.asset('assets/images/logo.png', width: 48),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(s.t('logout')),
          onTap: app.signOut,
        ),
      ]),
    );
  }
}
