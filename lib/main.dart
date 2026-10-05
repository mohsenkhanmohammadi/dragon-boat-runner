import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'firebase_options.dart';
import 'l10n/strings.dart';
import 'screens/root_gate.dart';
import 'services/backend.dart';
import 'services/deep_links.dart';
import 'services/demo_data.dart';
import 'services/ui.dart';
import 'state/app_state.dart';
import 'theme.dart';

/// `flutter build apk --dart-define=DEMO=true` forces demo mode.
const _forceDemo = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  FirebaseOptions? options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } catch (_) {
    options = null; // `flutterfire configure` not run yet
  }

  if (options != null && !_forceDemo) {
    await Firebase.initializeApp(options: options);
    Backend.firestore = FirebaseFirestore.instance;
    Backend.auth = FirebaseAuth.instance;
  } else {
    Backend.demo = true;
    final fs = FakeFirebaseFirestore();
    await DemoData.seed(fs);
    Backend.firestore = fs;
    Backend.auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: DemoData.meUid,
        email: 'demo@dragonboat.app',
        displayName: 'Mohsen',
      ),
    );
  }

  final prefs = await SharedPreferences.getInstance();
  await DeepLinks.init();
  runApp(ChangeNotifierProvider(
    create: (_) => AppState(prefs),
    child: const DragonBoatApp(),
  ));
}

class DragonBoatApp extends StatelessWidget {
  const DragonBoatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.select<AppState, String>((a) => a.lang);
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: buildTheme(),
      locale: Locale(lang),
      supportedLocales: const [Locale('en'), Locale('de')],
      localizationsDelegates: const [
        SDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RootGate(),
    );
  }
}
