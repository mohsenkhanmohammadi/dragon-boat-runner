import 'package:dragon_boat_runner/models/models.dart';
import 'package:dragon_boat_runner/services/run_tracker.dart';
import 'package:dragon_boat_runner/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('race time format (1/100 s)', () {
    test('values', () {
      expect(formatRaceTime(0), '0:00.00');
      expect(formatRaceTime(83456), '1:23.46');
      expect(formatRaceTime(59994), '0:59.99');
      expect(formatRaceTime(125000), '2:05.00');
    });
    test('speed and distance', () {
      expect(formatSpeed(5), '18.0 km/h');
      expect(formatDistance(200), '200 m');
      expect(formatDistance(1000), '1 km');
      expect(formatDistance(2600), '2.60 km');
    });
  });

  group('finish line interpolation', () {
    test('finish in the middle of a GPS segment', () {
      expect(finishFraction(190, 20, 200), 0.5);
      expect(finishFraction(195, 10, 200), 0.5);
    });
    test('edge cases', () {
      expect(finishFraction(200, 10, 200), 0.0);
      expect(finishFraction(100, 0, 200), 1.0);
      expect(finishFraction(150, 20, 200), 1.0); // clamped
    });
  });

  group('run statistics', () {
    final speeds = [0.0, 0.5, 2, 4, 3, 1.5, 5];
    final pts = [
      for (var i = 0; i < speeds.length; i++)
        RunPoint(52.0, 13.0 + i * 0.0001, i * 1000, speeds[i].toDouble())
    ];
    final r = computeRunStats(pts, 50000, 200);

    test('average speed = distance / time', () => expect(r.avg, 4.0));
    test('max speed and where', () {
      expect(r.max, 5.0);
      expect(r.maxIndex, 6);
    });
    test('min speed ignores the start phase', () {
      expect(r.min, 1.5);
      expect(r.minIndex, 5);
    });
    test('too few points', () {
      final e = computeRunStats(const [], 0, 200);
      expect(e.avg, 0);
      expect(e.max, 0);
    });
  });

  test('time per 500 m', () {
    final run = Run(
        id: 'x', uid: 'u', name: 'n', targetMeters: 200, timeMs: 50000,
        maxSpeed: 0, minSpeed: 0, avgSpeed: 0, points: const []);
    expect(run.pace500Ms, 125000);
  });

  group('attendance deadline', () {
    test('locked 1 hour before the start', () {
      final soon = Session(
          id: 's', type: SessionType.training,
          start: DateTime.now().add(const Duration(minutes: 50)));
      expect(soon.isLocked, isTrue);
      expect(soon.isStarted, isFalse);
    });
    test('open more than 1 hour before', () {
      final later = Session(
          id: 's', type: SessionType.training,
          start: DateTime.now().add(const Duration(minutes: 70)));
      expect(later.isLocked, isFalse);
    });
    test('started', () {
      final past = Session(
          id: 's', type: SessionType.training,
          start: DateTime.now().subtract(const Duration(minutes: 1)));
      expect(past.isStarted, isTrue);
    });
  });
}
