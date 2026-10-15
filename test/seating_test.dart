import 'dart:math';

import 'package:dragon_boat_runner/models/models.dart';
import 'package:dragon_boat_runner/services/seating.dart';
import 'package:flutter_test/flutter_test.dart';

List<SeatCandidate> people(int n, {int seed = 1, int withoutWeight = 0}) {
  final r = Random(seed);
  return [
    for (var i = 0; i < n; i++)
      SeatCandidate('p$i',
          weight: i < n - withoutWeight ? 50.0 + r.nextInt(50) : null)
  ];
}

void checkValid(BoatSpec boat, SeatingResult r, int n) {
  // every seat exists, nobody sits twice, everybody seated or reserve
  for (final seat in r.seats.keys) {
    expect(boat.hasSeat(seat), isTrue, reason: 'unknown seat $seat');
  }
  final seated = r.seats.values.toList();
  expect(seated.toSet().length, seated.length, reason: 'duplicate person');
  expect(seated.length + r.reserves.length, n);
  expect(seated.length, min(n, boat.capacity));
}

void main() {
  group('boat size', () {
    test('up to 12 attendees -> small boat, 13+ -> large boat', () {
      expect(BoatSpec.forAttendees(1), BoatSpec.small);
      expect(BoatSpec.forAttendees(12), BoatSpec.small);
      expect(BoatSpec.forAttendees(13), BoatSpec.large);
      expect(BoatSpec.forAttendees(22), BoatSpec.large);
    });
    test('capacities', () {
      expect(BoatSpec.small.capacity, 12); // 10 paddlers + drummer + steerer
      expect(BoatSpec.large.capacity, 22); // 20 paddlers + drummer + steerer
    });
  });

  group('auto seating', () {
    for (final n in [1, 5, 10, 11, 12, 13, 20, 22, 25, 60]) {
      test('$n people: valid layout', () {
        final boat = BoatSpec.forAttendees(n);
        checkValid(boat, autoSeat(boat, people(n)), n);
      });
    }

    test('paddle seats are filled before drummer and steerer', () {
      final r = autoSeat(BoatSpec.small, people(10));
      expect(r.seats.containsKey(drummerSeat), isFalse);
      expect(r.seats.containsKey(steerSeat), isFalse);
      expect(r.seats.length, 10);
    });

    test('11th and 12th person become drummer and steerer, 13th reserve', () {
      final r = autoSeat(BoatSpec.small, people(13));
      expect(r.seats.containsKey(drummerSeat), isTrue);
      expect(r.seats.containsKey(steerSeat), isTrue);
      expect(r.reserves.length, 1);
    });

    test('left/right balance is good for 20 random paddlers', () {
      for (var seed = 1; seed <= 20; seed++) {
        final p = people(20, seed: seed);
        final w = {for (final x in p) x.uid: x.weight};
        final r = autoSeat(BoatSpec.large, p);
        final s = balanceOf(BoatSpec.large, r.seats, w);
        expect((s.left - s.right).abs(), lessThanOrEqualTo(10),
            reason: 'seed $seed: L=${s.left} R=${s.right}');
      }
    });

    test('side preferences are respected when possible', () {
      final p = [
        for (var i = 0; i < 10; i++)
          SeatCandidate('p$i',
              weight: 60.0 + i * 3, pref: i < 4 ? Side.left : (i < 8 ? Side.right : null))
      ];
      final r = autoSeat(BoatSpec.small, p);
      for (final e in r.seats.entries) {
        final pref = p.firstWhere((x) => x.uid == e.value).pref;
        if (pref != null) expect(BoatSpec.sideOf(e.key), pref);
      }
    });

    test('heaviest paddlers sit in the middle rows', () {
      final p = [for (var i = 0; i < 10; i++) SeatCandidate('p$i', weight: 50.0 + i * 5)];
      final r = autoSeat(BoatSpec.small, p);
      final seat = r.seats.entries.firstWhere((e) => e.value == 'p9').key;
      expect(BoatSpec.rowOf(seat), 3, reason: 'heaviest sits in $seat');
      // the lightest ones sit at the bow or stern
      for (final light in ['p0', 'p1']) {
        final s = r.seats.entries.firstWhere((e) => e.value == light).key;
        expect([1, 5], contains(BoatSpec.rowOf(s)), reason: '$light in $s');
      }
    });

    test('people without weight are placed, but after the weighted ones', () {
      final p = people(10, withoutWeight: 3);
      final r = autoSeat(BoatSpec.small, p);
      checkValid(BoatSpec.small, r, 10);
      // the middle row is taken by weighted people
      expect(p.firstWhere((x) => x.uid == r.seats['L3']).weight, isNotNull);
      expect(p.firstWhere((x) => x.uid == r.seats['R3']).weight, isNotNull);
    });

    test('seats fixed by the admin are kept', () {
      final p = people(10);
      final r = autoSeat(BoatSpec.small, p, fixed: {'L1': 'p0', steerSeat: 'p1'});
      expect(r.seats['L1'], 'p0');
      expect(r.seats[steerSeat], 'p1');
      checkValid(BoatSpec.small, r, 10);
    });

    test('fixed seats of people who are not coming are ignored', () {
      final r = autoSeat(BoatSpec.small, people(4), fixed: {'L1': 'ghost'});
      expect(r.seats.values, isNot(contains('ghost')));
    });
  });

  test('balance statistics', () {
    final s = balanceOf(BoatSpec.small, {'L1': 'a', 'R1': 'b', 'L5': 'c', 'D': 'd'},
        {'a': 70, 'b': 80, 'c': 60, 'd': null});
    expect(s.left, 130);
    expect(s.right, 80);
    expect(s.front, 150); // rows 1-2 (+ drummer)
    expect(s.back, 60);
    expect(s.unknown, 1);
  });
}
