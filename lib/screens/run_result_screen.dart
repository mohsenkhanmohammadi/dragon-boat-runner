import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/db.dart';
import '../services/ui.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

/// Google Map of one timed run: route coloured by speed (red = slow,
/// green = fast), markers for start, finish, max and min speed.
class RunResultScreen extends StatefulWidget {
  const RunResultScreen({super.key, required this.run, required this.sessionId});
  final Run run;
  final String sessionId;

  @override
  State<RunResultScreen> createState() => _RunResultScreenState();
}

class _RunResultScreenState extends State<RunResultScreen> {
  GoogleMapController? _map;

  Color _speedColor(double v, double lo, double hi) {
    final t = hi <= lo ? 0.5 : ((v - lo) / (hi - lo)).clamp(0.0, 1.0).toDouble();
    return t < 0.5
        ? Color.lerp(Colors.red, Colors.amber, t * 2)!
        : Color.lerp(Colors.amber, Colors.green, (t - 0.5) * 2)!;
  }

  LatLngBounds? _bounds(List<RunPoint> pts) {
    if (pts.isEmpty) return null;
    var minLat = pts.first.lat, maxLat = pts.first.lat;
    var minLng = pts.first.lng, maxLng = pts.first.lng;
    for (final p in pts) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    return LatLngBounds(
        southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final app = context.watch<AppState>();
    final run = widget.run;
    final pts = run.points;
    final lo = run.minSpeed, hi = run.maxSpeed;

    final polylines = <Polyline>{
      for (var i = 1; i < pts.length; i++)
        Polyline(
          polylineId: PolylineId('seg$i'),
          points: [LatLng(pts[i - 1].lat, pts[i - 1].lng), LatLng(pts[i].lat, pts[i].lng)],
          color: _speedColor(pts[i].speed, lo, hi),
          width: 6,
        ),
    };

    final markers = <Marker>{};
    if (pts.isNotEmpty) {
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: LatLng(pts.first.lat, pts.first.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'Start'),
      ));
      markers.add(Marker(
        markerId: const MarkerId('finish'),
        position: LatLng(pts.last.lat, pts.last.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: InfoWindow(
            title: s.t('finish'), snippet: formatRaceTime(run.timeMs)),
      ));
    }
    final maxI = run.maxIndex;
    if (maxI != null && maxI >= 0 && maxI < pts.length) {
      markers.add(Marker(
        markerId: const MarkerId('max'),
        position: LatLng(pts[maxI].lat, pts[maxI].lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
            title: '${s.t('maxSpeed')}: ${formatSpeed(run.maxSpeed)}',
            snippet: formatRaceTime(pts[maxI].tMs)),
      ));
    }
    final minI = run.minIndex;
    if (minI != null && minI >= 0 && minI < pts.length) {
      markers.add(Marker(
        markerId: const MarkerId('min'),
        position: LatLng(pts[minI].lat, pts[minI].lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
            title: '${s.t('minSpeed')}: ${formatSpeed(run.minSpeed)}',
            snippet: formatRaceTime(pts[minI].tMs)),
      ));
    }

    final canDelete = run.uid == app.uid || app.isManager;

    return Scaffold(
      appBar: AppBar(
        title: Text('${run.name} · ${formatDistance(run.targetMeters)}'),
        actions: [
          if (canDelete && run.id.isNotEmpty)
            IconButton(
              tooltip: s.t('delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirm(context,
                    title: s.t('deleteRun'),
                    ok: s.t('delete'),
                    cancel: s.t('cancel'),
                    danger: true);
                if (!ok) return;
                await Db.deleteRun(app.team!.id, widget.sessionId, run.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Column(children: [
        Expanded(
          flex: 3,
          child: pts.isEmpty
              ? Center(child: Text(s.t('noGpsData')))
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                      target: LatLng(pts.first.lat, pts.first.lng), zoom: 16),
                  polylines: polylines,
                  markers: markers,
                  myLocationButtonEnabled: false,
                  mapType: MapType.hybrid,
                  onMapCreated: (c) {
                    _map = c;
                    final b = _bounds(pts);
                    if (b != null) {
                      Future.delayed(const Duration(milliseconds: 400), () {
                        _map?.animateCamera(CameraUpdate.newLatLngBounds(b, 48));
                      });
                    }
                  },
                ),
        ),
        Expanded(
          flex: 2,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              Row(children: [
                Text(s.t('slow'), style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                          colors: [Colors.red, Colors.amber, Colors.green]),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(s.t('fast'), style: const TextStyle(fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              _row(context, Icons.timer, s.t('time'), formatRaceTime(run.timeMs)),
              _row(context, Icons.straighten, s.t('distance'),
                  formatDistance(run.targetMeters)),
              _row(context, Icons.arrow_upward, s.t('maxSpeed'),
                  formatSpeed(run.maxSpeed), Colors.green),
              _row(context, Icons.arrow_downward, s.t('minSpeed'),
                  formatSpeed(run.minSpeed), Colors.red),
              _row(context, Icons.speed, s.t('avgSpeed'), formatSpeed(run.avgSpeed)),
              _row(context, Icons.av_timer, s.t('pace500'),
                  formatRaceTime(run.pace500Ms)),
              if (run.strokeRate != null)
                _row(context, Icons.rowing, s.t('strokeRate'),
                    '≈ ${run.strokeRate!.toStringAsFixed(0)} /min'),
              if (run.createdAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(formatDateTime(run.createdAt!, app.lang),
                      style: Theme.of(context).textTheme.bodySmall),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value,
          [Color? color]) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Text(label),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16, color: color)),
        ]),
      );
}
