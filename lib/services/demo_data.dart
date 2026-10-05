import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Sample data for demo mode: one team with 15 members, upcoming trainings
/// with answers, a race, an event and a past training with timed runs.
class DemoData {
  static const meUid = 'demo-me';
  static const teamId = 'demo-team';
  static const code = 'DEMO42';

  static const _members = <(String, String, String?, double?, String?)>[
    // uid, first name, last name, weight, gender
    (meUid, 'Mohsen', 'K.', 78, 'male'),
    ('m1', 'Anna', 'Schmidt', 64, 'female'),
    ('m2', 'Lukas', 'Becker', 86, 'male'),
    ('m3', 'Sophie', 'Wagner', 59, 'female'),
    ('m4', 'Jonas', 'Hoffmann', 92, 'male'),
    ('m5', 'Lea', 'Schulz', 61, 'female'),
    ('m6', 'Felix', 'Koch', 80, 'male'),
    ('m7', 'Marie', 'Richter', 67, 'female'),
    ('m8', 'Paul', 'Klein', 74, 'male'),
    ('m9', 'Emma', 'Wolf', null, 'female'),
    ('m10', 'Ben', 'Neumann', 95, 'male'),
    ('m11', 'Mia', 'Schwarz', 56, 'female'),
    ('m12', 'Leon', 'Zimmermann', 83, 'male'),
    ('m13', 'Hannah', 'Braun', 70, 'female'),
    ('m14', 'Tim', 'Krüger', null, 'male'),
  ];

  static Future<void> seed(FirebaseFirestore fs) async {
    final team = fs.collection('teams').doc(teamId);
    final ids = [for (final m in _members) m.$1];

    await team.set({
      'name': 'Drachenboot Demo Team',
      'code': code,
      'ownerId': meUid,
      'coAdminId': 'm1',
      'photoUrl': null,
      'memberIds': ids,
      'defaultLayouts': <String, dynamic>{},
    });
    await fs.collection('codes').doc(code).set({'teamId': teamId});

    for (final m in _members) {
      final data = {
        'firstName': m.$2,
        'lastName': m.$3,
        'weight': m.$4,
        'gender': m.$5,
        'photoUrl': null,
      };
      await team.collection('members').doc(m.$1).set(data);
      if (m.$1 == meUid) {
        await fs.collection('users').doc(meUid).set({
          ...data,
          'age': 35,
          'email': 'demo@dragonboat.app',
          'teamIds': [teamId],
          'currentTeamId': teamId,
        });
      }
    }

    // ------------------------------------------------ calendar
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final trainings = <DateTime>[];
    for (var d = 0; trainings.length < 7; d++) {
      final day = today.add(Duration(days: d));
      final start = day.weekday == DateTime.saturday
          ? DateTime(day.year, day.month, day.day, 10)
          : DateTime(day.year, day.month, day.day, 18, 30);
      if ((day.weekday == DateTime.tuesday ||
              day.weekday == DateTime.thursday ||
              day.weekday == DateTime.saturday) &&
          start.isAfter(now.add(const Duration(hours: 2)))) {
        trainings.add(start);
      }
    }
    final sessions = team.collection('sessions');
    final rnd = math.Random(7);
    final sides = ['left', 'right'];

    for (var i = 0; i < trainings.length; i++) {
      final ref = sessions.doc('t$i');
      await ref.set({
        'type': 'training',
        'title': '',
        'start': Timestamp.fromDate(trainings[i]),
        'location': 'Bootshaus am See',
        'notes': i == 0 ? 'Bitte 15 Minuten früher da sein.' : '',
        'createdBy': meUid,
      });
      // first training: 12 yes (small boat), second: 17 yes (large boat)
      final yesCount = i == 0 ? 12 : (i == 1 ? 17 : 6 + rnd.nextInt(6));
      for (var k = 0; k < ids.length; k++) {
        final uid = ids[k];
        String? status;
        if (k < yesCount) {
          status = 'yes';
        } else if (k == yesCount) {
          status = 'maybe';
        } else if (k == yesCount + 1) {
          status = 'no';
        }
        if (status == null) continue;
        await ref.collection('rsvps').doc(uid).set({
          'status': status,
          if (status == 'yes' && k % 3 != 2) 'side': sides[k % 2],
          'sideByAdmin': false,
        });
      }
    }

    final race = today.add(const Duration(days: 16));
    await sessions.doc('race1').set({
      'type': 'race',
      'title': 'Drachenboot-Cup',
      'start': Timestamp.fromDate(DateTime(race.year, race.month, race.day, 9)),
      'location': 'Regattastrecke',
      'notes': '200 m und 500 m',
    });
    final party = today.add(const Duration(days: 23));
    await sessions.doc('event1').set({
      'type': 'event',
      'title': 'Saisonabschluss-Grillen',
      'start':
          Timestamp.fromDate(DateTime(party.year, party.month, party.day, 17)),
      'location': 'Vereinsheim',
    });

    // ------------------------------------------------ past training + runs
    final past = today.subtract(const Duration(days: 2));
    final pastStart = DateTime(past.year, past.month, past.day, 18, 30);
    final pastRef = sessions.doc('past1');
    await pastRef.set({
      'type': 'training',
      'title': '',
      'start': Timestamp.fromDate(pastStart),
      'location': 'Bootshaus am See',
    });
    final pastRace = today.subtract(const Duration(days: 9));
    final pastRaceStart = DateTime(pastRace.year, pastRace.month, pastRace.day, 10);
    final pastRaceRef = sessions.doc('pastRace');
    await pastRaceRef.set({
      'type': 'race',
      'title': 'Herbst-Regatta',
      'start': Timestamp.fromDate(pastRaceStart),
      'location': 'Regattastrecke',
    });

    for (final (ref, type, start) in [
      (pastRef, 'training', pastStart),
      (pastRaceRef, 'race', pastRaceStart),
    ]) {
      for (var k = 0; k < 8; k++) {
        final m = _members[k];
        for (final dist in [200.0, 500.0]) {
          final avg = 3.4 + rnd.nextDouble() * 1.2 + (type == 'race' ? 0.2 : 0);
          final run = _fakeRun(dist, avg, rnd);
          await ref.collection('runs').add({
            'uid': m.$1,
            'name': [m.$2, m.$3].whereType<String>().join(' '),
            'teamId': teamId,
            'sessionId': ref.id,
            'sessionType': type,
            'sessionStart': Timestamp.fromDate(start),
            'targetMeters': dist,
            ...run,
            'createdAt': Timestamp.fromDate(
                start.add(Duration(minutes: 20 + k * 3))),
          });
        }
      }
    }
  }

  /// A straight-ish course on a lake with realistic speed changes.
  static Map<String, dynamic> _fakeRun(
      double dist, double avg, math.Random rnd) {
    const lat0 = 52.4890, lng0 = 13.4930; // a lake in Berlin
    const metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * math.cos(lat0 * math.pi / 180);
    final points = <Map<String, dynamic>>[];
    var d = 0.0, t = 0;
    var maxV = 0.0, minV = 99.0;
    int maxI = 0, minI = 0;
    points.add({'la': lat0, 'ln': lng0, 't': 0, 'v': 0.0});
    while (d < dist) {
      t += 1000;
      final phase = d / dist;
      // start sprint, steady middle, slight fade, final push
      var v = avg *
          (phase < 0.1
              ? 0.75 + phase * 3
              : phase > 0.85
                  ? 1.08
                  : 1.0 - 0.06 * math.sin(phase * math.pi));
      v += (rnd.nextDouble() - 0.5) * 0.3;
      d += v;
      final dd = math.min(d, dist);
      final lat = lat0 + dd * 0.8 / metersPerDegLat;
      final lng = lng0 +
          dd * 0.6 / metersPerDegLng +
          math.sin(dd / 60) * 4 / metersPerDegLng;
      points.add({'la': lat, 'ln': lng, 't': t, 'v': v});
      final i = points.length - 1;
      if (v > maxV) {
        maxV = v;
        maxI = i;
      }
      if (phase > 0.1 && v < minV) {
        minV = v;
        minI = i;
      }
    }
    final timeMs = (dist / avg * 1000).round();
    points.last['t'] = timeMs;
    return {
      'timeMs': timeMs,
      'maxSpeed': maxV,
      'minSpeed': minV == 99.0 ? 0.0 : minV,
      'avgSpeed': dist / (timeMs / 1000),
      'maxIndex': maxI,
      'minIndex': minI,
      'strokeRate': 58 + rnd.nextInt(20).toDouble(),
      'points': points,
    };
  }
}
