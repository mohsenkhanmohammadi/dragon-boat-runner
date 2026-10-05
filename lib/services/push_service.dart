import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';
import 'db.dart';
import 'ui.dart';

/// Push notifications.
///  * Calendar changes: FCM topics team_<teamId>_en / team_<teamId>_de.
///  * Personal reminders (3 h before a training, only to members who have
///    not answered): the device token stored in users/{uid}.fcmTokens.
/// Both are sent by Cloud Functions (functions/index.js).
/// In demo mode nothing is sent.
class PushService {
  static FirebaseMessaging get _fm => FirebaseMessaging.instance;
  static bool _initDone = false;
  static String? _uid;
  static String? _token;
  static Future<void> _queue = Future.value();
  static const _prefsKey = 'fcm_topics';

  static Future<void> init(String uid) async {
    if (Backend.demo) return;
    _uid = uid;
    if (!_initDone) {
      _initDone = true;
      try {
        await _fm.requestPermission(alert: true, badge: true, sound: true);
        await _fm.setForegroundNotificationPresentationOptions(
            alert: true, badge: true, sound: true);
      } catch (_) {}
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
          content: Text([n.title, n.body].whereType<String>().join('\n')),
          duration: const Duration(seconds: 5),
        ));
      });
      _fm.onTokenRefresh.listen(_saveToken, onError: (_) {});
    }
    try {
      if (Platform.isIOS && await _waitForApns() == null) return;
      final t = await _fm.getToken();
      if (t != null) await _saveToken(t);
    } catch (_) {}
  }

  static Future<void> _saveToken(String token) async {
    _token = token;
    final uid = _uid;
    if (uid == null) return;
    await Db.user(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  /// Called before sign-out so this phone gets no more personal reminders.
  static Future<void> removeToken() async {
    if (Backend.demo) return;
    final uid = _uid, t = _token;
    if (uid == null || t == null) return;
    try {
      await Db.user(uid).update({
        'fcmTokens': FieldValue.arrayRemove([t]),
      });
    } catch (_) {}
    _uid = null;
  }

  static Future<String?> _waitForApns() async {
    String? apns;
    for (var i = 0; i < 5 && apns == null; i++) {
      apns = await _fm.getAPNSToken();
      if (apns == null) await Future.delayed(const Duration(seconds: 2));
    }
    return apns;
  }

  static String topic(String teamId, String lang) => 'team_${teamId}_$lang';

  /// Makes sure we are subscribed to exactly the topics of [teamIds] in [lang].
  static Future<void> syncTopics(List<String> teamIds, String lang) {
    if (Backend.demo) return Future.value();
    _queue = _queue.then((_) => _sync(teamIds, lang)).catchError((_) {});
    return _queue;
  }

  static Future<void> _sync(List<String> teamIds, String lang) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_prefsKey) ?? const []).toSet();
    final wanted = {for (final t in teamIds) topic(t, lang)};
    if (current.length == wanted.length && current.containsAll(wanted)) return;
    if (Platform.isIOS && await _waitForApns() == null) return;
    for (final t in current.difference(wanted)) {
      await _fm.unsubscribeFromTopic(t);
    }
    for (final t in wanted.difference(current)) {
      await _fm.subscribeToTopic(t);
    }
    await prefs.setStringList(_prefsKey, wanted.toList());
  }
}
