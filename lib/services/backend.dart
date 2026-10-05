import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Which backend the app talks to.
///
/// * Normal mode: the real Firebase project (after `flutterfire configure`).
/// * Demo mode: everything runs locally on the phone with sample data –
///   used automatically when Firebase is not configured yet, or forced with
///   `flutter build apk --dart-define=DEMO=true`.
class Backend {
  static bool demo = false;
  static late FirebaseFirestore firestore;
  static late FirebaseAuth auth;
}

class DemoUnavailable implements Exception {
  @override
  String toString() => 'Not available in demo mode';
}
