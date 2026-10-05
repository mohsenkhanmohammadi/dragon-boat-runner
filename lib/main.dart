import 'dart:async';

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

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    // In release builds Flutter shows an empty box for build errors –
    // show the message instead, so problems can be reported.
    ErrorWidget.builder = (details) => Material(
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text('${details.exception}\n\n${details.stack}',
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        );
    runApp(const BootApp());
  }, (error, stack) {
    debugPrint('Uncaught: $error\n$stack');
  });
}

/// Initialises Firebase (or demo mode). Returns the shared preferences.
Future<SharedPreferences> bootstrap({bool forceDemo = false}) async {
  await initializeDateFormatting();

  FirebaseOptions? options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } catch (_) {
    options = null; // `flutterfire configure` not run yet
  }

  if (options != null && !_forceDemo && !forceDemo) {
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
  try {
    await DeepLinks.init();
  } catch (_) {}
  return prefs;
}

/// Shows the dragon splash immediately, then the app – or the error text
/// if the start fails.
class BootApp extends StatefulWidget {
  const BootApp({super.key});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  late Future<SharedPreferences> _boot = bootstrap();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: _boot,
      builder: (context, snap) {
        if (snap.hasData) {
          return ChangeNotifierProvider(
            create: (_) => AppState(snap.data!),
            child: const DragonBoatApp(),
          );
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: Scaffold(
            backgroundColor: deepWater,
            body: Center(
              child: snap.hasError
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        const Icon(Icons.error_outline,
                            color: Colors.white, size: 48),
                        const SizedBox(height: 12),
                        SelectableText('${snap.error}\n\n${snap.stackTrace}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              setState(() => _boot = bootstrap()),
                          child: const Text('Retry'),
                        ),
                      ]),
                    )
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Image.asset('assets/images/logo.png', width: 140),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(color: Colors.white),
                    ]),
            ),
          ),
        );
      },
    );
  }
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
