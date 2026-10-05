import 'package:dragon_boat_runner/main.dart';
import 'package:dragon_boat_runner/models/models.dart';
import 'package:dragon_boat_runner/services/backend.dart';
import 'package:dragon_boat_runner/services/db.dart';
import 'package:dragon_boat_runner/services/demo_data.dart';
import 'package:dragon_boat_runner/services/seating.dart';
import 'package:dragon_boat_runner/state/app_state.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('demo data + queries + seating', () async {
    final fs = FakeFirebaseFirestore();
    await DemoData.seed(fs);
    Backend.firestore = fs;

    final sessions = await Db.upcomingSessions(DemoData.teamId).first;
    expect(sessions.where((s) => s.type == SessionType.training).length,
        greaterThanOrEqualTo(5));

    final members = await Db.membersStream(DemoData.teamId).first;
    expect(members.length, 15);

    final rsvps = await Db.rsvpsStream(DemoData.teamId, 't0').first;
    expect(rsvps.values.where((r) => r.status == RsvpStatus.yes).length, 12);

    final board = await Db.leaderboard(DemoData.teamId, 200).first;
    expect(board, isNotEmpty);

    final r = autoSeat(BoatSpec.small, [
      for (final m in members.take(12)) SeatCandidate(m.uid, weight: m.weight)
    ]);
    expect(r.seats.length, 12);
  });

  testWidgets('app starts in demo mode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late SharedPreferences prefs;
    await tester.runAsync(() async {
      prefs = await bootstrap(forceDemo: true);
    });
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(prefs),
      child: const DragonBoatApp(),
    ));
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Drachenboot Demo Team'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
