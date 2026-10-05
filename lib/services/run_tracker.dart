import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/models.dart';

enum RunPhase { preparing, ready, countdown, running, finished, error }

enum GpsProblem { serviceOff, denied, deniedForever }

/// Timed GPS run:
///   Start -> "Achtung, started" -> 1 s -> "Are you ready?" -> 1 s -> "Go!"
/// The clock starts at "Go" and stops exactly (interpolated between GPS
/// fixes) when the chosen distance is reached; then a boat horn sounds.
class RunTracker extends ChangeNotifier {
  RunTracker({required this.targetMeters});

  final double targetMeters;

  RunPhase phase = RunPhase.preparing;
  GpsProblem? problem;
  String? countdownText;
  Position? latest;

  final _sw = Stopwatch();
  double distance = 0;
  double currentSpeed = 0; // m/s
  final List<RunPoint> points = [];
  int? finalMs;

  // results
  double maxSpeed = 0, minSpeed = 0, avgSpeed = 0;
  int? maxIndex, minIndex;
  double? strokeRate;

  StreamSubscription<Position>? _posSub;
  StreamSubscription<UserAccelerometerEvent>? _accSub;
  Timer? _ticker;
  final _tts = FlutterTts();
  final _player = AudioPlayer();
  bool _disposed = false;
  bool _cancelled = false;

  Position? _last;
  int _lastMs = 0;

  // stroke detection (phone lying in the boat / on the paddler)
  double _accSmooth = 0;
  bool _accHigh = false;
  int _lastStrokeMs = -10000;
  final List<int> _strokes = [];

  int get elapsedMs => finalMs ?? _sw.elapsedMilliseconds;
  bool get gpsGood => latest != null && latest!.accuracy <= 25;

  /// strokes per minute over the last 10 seconds
  double get liveStrokeRate {
    final now = elapsedMs;
    final recent = _strokes.where((t) => now - t <= 10000).length;
    return recent * 6.0;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> prepare() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        problem = GpsProblem.serviceOff;
        phase = RunPhase.error;
        _notify();
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        problem = GpsProblem.deniedForever;
        phase = RunPhase.error;
        _notify();
        return;
      }
      if (perm == LocationPermission.denied) {
        problem = GpsProblem.denied;
        phase = RunPhase.error;
        _notify();
        return;
      }
      _posSub = Geolocator.getPositionStream(locationSettings: _settings())
          .listen(_onPosition, onError: (_) {});
      try {
        await _tts.awaitSpeakCompletion(true);
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(0.5);
        if (Platform.isIOS) {
          await _tts.setSharedInstance(true);
          await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
              [IosTextToSpeechAudioCategoryOptions.mixWithOthers]);
        }
      } catch (_) {
        // no voice output available – timing still works
      }
      phase = RunPhase.ready;
      problem = null;
      _notify();
    } catch (_) {
      phase = RunPhase.error;
      _notify();
    }
  }

  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 500),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(
        accuracy: LocationAccuracy.best, distanceFilter: 0);
  }

  Future<void> _wait(int ms) => Future.delayed(Duration(milliseconds: ms));

  /// Speak and wait until finished (max. 3 s, in case the TTS engine hangs).
  Future<void> _say(String text) async {
    try {
      await _tts.speak(text).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> start() async {
    if (phase != RunPhase.ready) return;
    phase = RunPhase.countdown;
    _cancelled = false;

    countdownText = 'Achtung, started';
    _notify();
    await _say('Achtung, started');
    await _wait(1000);
    if (_cancelled || _disposed) return;

    countdownText = 'Are you ready?';
    _notify();
    await _say('Are you ready?');
    await _wait(1000);
    if (_cancelled || _disposed) return;

    countdownText = 'GO!';
    _tts.speak('Go!'); // not awaited – the clock starts with "Go"
    _sw
      ..reset()
      ..start();
    distance = 0;
    points.clear();
    _strokes.clear();
    _last = latest;
    _lastMs = 0;
    if (latest != null) {
      points.add(RunPoint(latest!.latitude, latest!.longitude, 0, 0));
    }
    phase = RunPhase.running;
    _accSub = userAccelerometerEventStream(
            samplingPeriod: SensorInterval.gameInterval)
        .listen(_onAcc, onError: (_) {});
    _ticker = Timer.periodic(
        const Duration(milliseconds: 40), (_) => _notify());
    _notify();
  }

  void cancel() {
    _cancelled = true;
    _tts.stop();
    _sw.stop();
    _ticker?.cancel();
    _accSub?.cancel();
    if (phase == RunPhase.countdown || phase == RunPhase.running) {
      phase = RunPhase.ready;
      countdownText = null;
      distance = 0;
      points.clear();
      _sw.reset();
    }
    _notify();
  }

  void _onAcc(UserAccelerometerEvent e) {
    if (phase != RunPhase.running) return;
    final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    _accSmooth = _accSmooth * 0.8 + mag * 0.2;
    final t = _sw.elapsedMilliseconds;
    if (!_accHigh && _accSmooth > 1.6) {
      _accHigh = true;
      if (t - _lastStrokeMs > 330) {
        // max ~180 strokes/min
        _strokes.add(t);
        _lastStrokeMs = t;
      }
    } else if (_accHigh && _accSmooth < 0.9) {
      _accHigh = false;
    }
  }

  void _onPosition(Position p) {
    latest = p;
    if (phase != RunPhase.running) {
      _notify();
      return;
    }
    if (p.accuracy > 30) return; // ignore bad fixes
    final t = _sw.elapsedMilliseconds;
    final prev = _last;
    if (prev == null) {
      _last = p;
      _lastMs = t;
      points.add(RunPoint(p.latitude, p.longitude, t, 0));
      return;
    }
    final d = Geolocator.distanceBetween(
        prev.latitude, prev.longitude, p.latitude, p.longitude);
    final dt = t - _lastMs;
    final computed = dt > 0 ? d / (dt / 1000) : 0.0;
    final v = p.speed > 0 ? p.speed : computed;
    currentSpeed = v;

    if (distance + d >= targetMeters) {
      final double frac = d > 0
          ? ((targetMeters - distance) / d).clamp(0.0, 1.0).toDouble()
          : 1.0;
      final crossMs = _lastMs + (dt * frac).round();
      points.add(RunPoint(
        prev.latitude + (p.latitude - prev.latitude) * frac,
        prev.longitude + (p.longitude - prev.longitude) * frac,
        crossMs,
        v,
      ));
      distance = targetMeters;
      _finish(crossMs);
      return;
    }
    distance += d;
    points.add(RunPoint(p.latitude, p.longitude, t, v));
    _last = p;
    _lastMs = t;
  }

  void _finish(int ms) {
    _sw.stop();
    finalMs = ms;
    phase = RunPhase.finished;
    countdownText = null;
    _ticker?.cancel();
    _accSub?.cancel();
    _player.play(AssetSource('sounds/horn.wav'));
    _computeStats();
    _notify();
  }

  void _computeStats() {
    final ms = finalMs ?? 0;
    avgSpeed = ms > 0 ? targetMeters / (ms / 1000) : 0;
    if (points.length < 2) return;
    // Min speed is measured after the start phase (once the boat is moving).
    var startIdx = points.indexWhere((p) => p.speed >= 1.0);
    if (startIdx < 1) startIdx = 1;
    maxSpeed = 0;
    minSpeed = double.infinity;
    for (var i = 1; i < points.length; i++) {
      final v = points[i].speed;
      if (v > maxSpeed) {
        maxSpeed = v;
        maxIndex = i;
      }
      if (i >= startIdx && v < minSpeed) {
        minSpeed = v;
        minIndex = i;
      }
    }
    if (minSpeed == double.infinity) minSpeed = 0;
    strokeRate = ms > 0 && _strokes.isNotEmpty
        ? _strokes.length / (ms / 60000)
        : null;
  }

  Run toRun({
    required String uid,
    required String name,
    required String teamId,
    required Session session,
  }) {
    // keep documents small for very long custom distances
    var pts = points;
    if (pts.length > 1500) {
      final step = (pts.length / 1500).ceil();
      pts = [
        for (var i = 0; i < pts.length; i++)
          if (i % step == 0 || i == pts.length - 1 || i == maxIndex || i == minIndex)
            pts[i]
      ];
    }
    final run = Run(
      id: '',
      teamId: teamId,
      sessionId: session.id,
      sessionType: session.type,
      sessionStart: session.start,
      uid: uid,
      name: name,
      targetMeters: targetMeters,
      timeMs: finalMs ?? 0,
      maxSpeed: maxSpeed,
      minSpeed: minSpeed,
      avgSpeed: avgSpeed,
      strokeRate: strokeRate,
      points: pts,
      maxIndex: maxIndex == null ? null : pts.indexOf(points[maxIndex!]),
      minIndex: minIndex == null ? null : pts.indexOf(points[minIndex!]),
    );
    return run;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelled = true;
    _posSub?.cancel();
    _accSub?.cancel();
    _ticker?.cancel();
    _tts.stop();
    _player.dispose();
    super.dispose();
  }
}
