import 'package:intl/intl.dart';

/// 83456 ms -> "1:23.45"
String formatRaceTime(int ms) {
  final totalHundredths = (ms / 10).round();
  final h = totalHundredths % 100;
  final totalSec = totalHundredths ~/ 100;
  final s = totalSec % 60;
  final m = totalSec ~/ 60;
  return '$m:${s.toString().padLeft(2, '0')}.${h.toString().padLeft(2, '0')}';
}

/// m/s -> "12.3 km/h"
String formatSpeed(double mps) => '${(mps * 3.6).toStringAsFixed(1)} km/h';

String formatDistance(double meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(meters % 1000 == 0 ? 0 : 2)} km'
    : '${meters.round()} m';

String formatDateTime(DateTime d, String lang) =>
    DateFormat.MMMEd(lang).add_Hm().format(d);

String formatDate(DateTime d, String lang) =>
    DateFormat.yMMMMEEEEd(lang).format(d);

String formatTime(DateTime d, String lang) => DateFormat.Hm(lang).format(d);
