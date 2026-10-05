import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/backend.dart';
import '../services/db.dart';
import '../services/push_service.dart';

/// Global app state: login, own profile, current team + its members, language.
class AppState extends ChangeNotifier {
  AppState(this._prefs) : lang = _prefs.getString('lang') ?? _deviceLang() {
    _authSub = Backend.auth.authStateChanges().listen(_onAuth);
  }

  static String _deviceLang() =>
      ui.PlatformDispatcher.instance.locale.languageCode == 'de' ? 'de' : 'en';

  final SharedPreferences _prefs;
  String lang;

  User? user;
  UserProfile? profile;
  Team? team;
  List<Member> members = const [];

  bool authLoading = true;
  bool profileLoading = false;
  bool teamLoading = false;

  String? _teamId;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Json>>? _profileSub;
  StreamSubscription<DocumentSnapshot<Json>>? _teamSub;
  StreamSubscription<List<Member>>? _membersSub;

  String get uid => user!.uid;
  bool get isManager => team?.isManager(user?.uid) ?? false;
  bool get isOwner => team != null && team!.ownerId == user?.uid;

  Member? member(String uid) {
    for (final m in members) {
      if (m.uid == uid) return m;
    }
    return null;
  }

  void _onAuth(User? u) {
    user = u;
    _profileSub?.cancel();
    _stopTeam();
    profile = null;
    authLoading = false;
    if (u == null) {
      profileLoading = false;
      notifyListeners();
      return;
    }
    profileLoading = true;
    notifyListeners();
    PushService.init(u.uid);
    _profileSub = Db.user(u.uid).snapshots().listen((doc) {
      profile = doc.exists ? UserProfile.fromDoc(doc) : null;
      profileLoading = false;
      _watchTeam(_pickTeam());
      PushService.syncTopics(profile?.teamIds ?? const [], lang);
      notifyListeners();
    }, onError: (_) {
      profileLoading = false;
      notifyListeners();
    });
  }

  String? _pickTeam() {
    final p = profile;
    if (p == null) return null;
    if (p.currentTeamId != null && p.teamIds.contains(p.currentTeamId)) {
      return p.currentTeamId;
    }
    return p.teamIds.isNotEmpty ? p.teamIds.first : null;
  }

  void _stopTeam() {
    _teamSub?.cancel();
    _membersSub?.cancel();
    _teamSub = null;
    _membersSub = null;
    _teamId = null;
    team = null;
    members = const [];
    teamLoading = false;
  }

  void _watchTeam(String? id) {
    if (id == _teamId) return;
    _stopTeam();
    _teamId = id;
    if (id == null) return;
    teamLoading = true;
    _teamSub = Db.team(id).snapshots().listen((doc) {
      final t = doc.exists ? Team.fromDoc(doc) : null;
      teamLoading = false;
      if (t == null || !t.memberIds.contains(user?.uid)) {
        // team deleted or we were removed
        team = null;
        _dropTeam(id);
      } else {
        final wasNull = team == null;
        team = t;
        if (wasNull) {
          _membersSub ??= Db.membersStream(id).listen((list) {
            members = list;
            notifyListeners();
          }, onError: (_) {});
        }
      }
      notifyListeners();
    }, onError: (_) {
      teamLoading = false;
      team = null;
      notifyListeners();
    });
  }

  Future<void> _dropTeam(String id) async {
    final u = user;
    if (u == null) return;
    try {
      await Db.user(u.uid).update({
        'teamIds': FieldValue.arrayRemove([id]),
        'currentTeamId': FieldValue.delete(),
      });
    } catch (_) {}
  }

  Future<void> switchTeam(String teamId) async {
    final u = user;
    if (u == null) return;
    await Db.user(u.uid).update({'currentTeamId': teamId});
  }

  Future<void> setLang(String l) async {
    if (l == lang) return;
    lang = l;
    await _prefs.setString('lang', l);
    notifyListeners();
    final u = user;
    if (u != null) {
      try {
        await Db.user(u.uid).set({'lang': l}, SetOptions(merge: true));
      } catch (_) {}
      PushService.syncTopics(profile?.teamIds ?? const [], l);
    }
  }

  Future<void> signOut() async {
    await PushService.removeToken();
    await PushService.syncTopics(const [], lang);
    await Backend.auth.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    _stopTeam();
    super.dispose();
  }
}
