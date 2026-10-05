import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/db.dart';
import '../services/run_tracker.dart';
import '../services/ui.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'run_result_screen.dart';

/// Live timing screen. Start -> voice countdown -> Go -> clock (1/100 s)
/// -> boat horn when the distance is reached -> result is saved.
class RunScreen extends StatefulWidget {
  const RunScreen(
      {super.key, required this.session, required this.targetMeters});
  final Session session;
  final double targetMeters;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  late final RunTracker _t;
  Run? _saved;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _t = RunTracker(targetMeters: widget.targetMeters)..addListener(_onTick);
    _t.prepare();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _t.removeListener(_onTick);
    _t.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {});
    if (_t.phase == RunPhase.finished && _saved == null && !_saving) {
      _save();
    }
  }

  Future<void> _save() async {
    final s = S.of(context);
    final app = context.read<AppState>();
    _saving = true;
    final run = _t.toRun(
        uid: app.uid,
        name: app.profile!.displayName,
        teamId: app.team!.id,
        session: widget.session);
    try {
      await Db.saveRun(app.team!.id, widget.session.id, run);
      if (mounted) setState(() => _saved = run);
      toast(s.t('runSaved'));
    } catch (e) {
      toast('${s.t('error')}: $e');
      _saving = false;
    }
  }

  bool get _active =>
      _t.phase == RunPhase.countdown || _t.phase == RunPhase.running;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      canPop: !_active,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await confirm(context,
            title: s.t('abortRun'),
            ok: s.t('abort'),
            cancel: s.t('cancel'),
            danger: true);
        if (ok && mounted) {
          _t.cancel();
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: deepWater,
        appBar: AppBar(
          backgroundColor: deepWater,
          foregroundColor: Colors.white,
          title: Text('${s.t('timing')} · ${formatDistance(widget.targetMeters)}'),
        ),
        body: SafeArea(child: _body(context, s)),
      ),
    );
  }

  Widget _body(BuildContext context, S s) {
    const white = TextStyle(color: Colors.white);
    switch (_t.phase) {
      case RunPhase.preparing:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(s.t('waitingGps'), style: white),
          ]),
        );
      case RunPhase.error:
        final msg = switch (_t.problem) {
          GpsProblem.serviceOff => s.t('gpsOff'),
          GpsProblem.denied => s.t('gpsDenied'),
          GpsProblem.deniedForever => s.t('gpsDeniedForever'),
          null => s.t('gpsError'),
        };
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_off, color: Colors.white, size: 56),
              const SizedBox(height: 12),
              Text(msg, style: white, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (_t.problem == GpsProblem.serviceOff) {
                    await Geolocator.openLocationSettings();
                  } else {
                    await Geolocator.openAppSettings();
                  }
                },
                child: Text(s.t('openSettings')),
              ),
            ]),
          ),
        );
      case RunPhase.ready:
        final acc = _t.latest?.accuracy;
        return Column(children: [
          const SizedBox(height: 24),
          Icon(Icons.gps_fixed,
              size: 40, color: _t.gpsGood ? Colors.greenAccent : Colors.orange),
          const SizedBox(height: 8),
          Text(
            acc == null
                ? s.t('waitingGps')
                : '${s.t('gpsAccuracy')}: ±${acc.toStringAsFixed(0)} m',
            style: white,
          ),
          if (!_t.gpsGood)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(s.t('gpsWeak'),
                  style: const TextStyle(color: Colors.orangeAccent),
                  textAlign: TextAlign.center),
            ),
          const Spacer(),
          GestureDetector(
            onTap: _t.latest == null ? null : _t.start,
            child: Container(
              width: 220,
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _t.latest == null ? Colors.grey : dragonRed,
                boxShadow: const [
                  BoxShadow(blurRadius: 30, color: Colors.black54)
                ],
              ),
              child: const Text('START',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w900)),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(s.t('startHint'),
                style: white.copyWith(fontSize: 13),
                textAlign: TextAlign.center),
          ),
        ]);
      case RunPhase.countdown:
        return Center(
          child: Text(
            _t.countdownText ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: dragonGold, fontSize: 48, fontWeight: FontWeight.w900),
          ),
        );
      case RunPhase.running:
        final progress =
            (_t.distance / widget.targetMeters).clamp(0.0, 1.0).toDouble();
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const SizedBox(height: 12),
            FittedBox(
              child: Text(formatRaceTime(_t.elapsedMs),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 84,
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 16,
                  color: dragonGold,
                  backgroundColor: Colors.white24),
            ),
            const SizedBox(height: 8),
            Text(
                '${_t.distance.toStringAsFixed(0)} / ${widget.targetMeters.toStringAsFixed(0)} m',
                style: white.copyWith(fontSize: 22)),
            const SizedBox(height: 24),
            Row(children: [
              _Live(label: s.t('speed'), value: formatSpeed(_t.currentSpeed)),
              _Live(
                  label: s.t('strokeRate'),
                  value: '${_t.liveStrokeRate.toStringAsFixed(0)} /min'),
            ]),
            const Spacer(),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54)),
              onPressed: _t.cancel,
              icon: const Icon(Icons.stop),
              label: Text(s.t('abort')),
            ),
          ]),
        );
      case RunPhase.finished:
        return _finished(context, s);
    }
  }

  Widget _finished(BuildContext context, S s) {
    const white = TextStyle(color: Colors.white);
    final pace = widget.targetMeters > 0
        ? ((_t.finalMs ?? 0) * 500 / widget.targetMeters).round()
        : 0;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Icon(Icons.sports_score, color: dragonGold, size: 56),
      Center(
        child: Text(formatRaceTime(_t.finalMs ?? 0),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.w900)),
      ),
      Center(
          child: Text(formatDistance(widget.targetMeters),
              style: white.copyWith(fontSize: 18))),
      const SizedBox(height: 20),
      _StatRow(label: s.t('maxSpeed'), value: formatSpeed(_t.maxSpeed), color: Colors.greenAccent),
      _StatRow(label: s.t('minSpeed'), value: formatSpeed(_t.minSpeed), color: Colors.redAccent),
      _StatRow(label: s.t('avgSpeed'), value: formatSpeed(_t.avgSpeed)),
      _StatRow(label: s.t('pace500'), value: formatRaceTime(pace)),
      if (_t.strokeRate != null)
        _StatRow(
            label: s.t('strokeRate'),
            value: '≈ ${_t.strokeRate!.toStringAsFixed(0)} /min'),
      const SizedBox(height: 20),
      if (_saved == null)
        const Center(child: CircularProgressIndicator(color: Colors.white))
      else
        FilledButton.icon(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    RunResultScreen(run: _saved!, sessionId: widget.session.id)),
          ),
          icon: const Icon(Icons.map),
          label: Text(s.t('showOnMap')),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(s.t('close'), style: white),
      ),
    ]);
  }
}

class _Live extends StatelessWidget {
  const _Live({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(label, style: const TextStyle(color: Colors.white60)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.color});
  final String label, value;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          if (color != null)
            Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}
