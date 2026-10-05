import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'team_service.dart';

/// Handles invite links:
///   https://<linkHost>/join/ABC123
///   dragonboatrunner://join?code=ABC123
class DeepLinks {
  static final pendingCode = ValueNotifier<String?>(null);
  static final _links = AppLinks();
  static String? _last;
  static DateTime _lastAt = DateTime(2000);

  static Future<void> init() async {
    try {
      // uriLinkStream also delivers the link that opened the app.
      _links.uriLinkStream.listen(_handle, onError: (_) {});
    } catch (_) {}
  }

  static void _handle(Uri uri) {
    String? code = uri.queryParameters['code'];
    if (code == null) {
      final segs = uri.pathSegments;
      final i = segs.indexOf('join');
      if (i >= 0 && i + 1 < segs.length) code = segs[i + 1];
    }
    if (code == null) return;
    code = TeamService.normalizeCode(code);
    if (code.isEmpty) return;
    final now = DateTime.now();
    if (code == _last && now.difference(_lastAt).inSeconds < 5) return;
    _last = code;
    _lastAt = now;
    pendingCode.value = code;
  }
}
