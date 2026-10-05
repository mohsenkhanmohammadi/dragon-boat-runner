import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'backend.dart';

/// All Firestore paths and simple read/write helpers in one place.
class Db {
  static FirebaseFirestore get fs => Backend.firestore;

  static DocumentReference<Json> user(String uid) =>
      fs.collection('users').doc(uid);
  static DocumentReference<Json> team(String id) =>
      fs.collection('teams').doc(id);
  static DocumentReference<Json> code(String code) =>
      fs.collection('codes').doc(code);
  static CollectionReference<Json> members(String teamId) =>
      team(teamId).collection('members');
  static CollectionReference<Json> sessions(String teamId) =>
      team(teamId).collection('sessions');
  static CollectionReference<Json> rsvps(String teamId, String sessionId) =>
      sessions(teamId).doc(sessionId).collection('rsvps');
  static CollectionReference<Json> runs(String teamId, String sessionId) =>
      sessions(teamId).doc(sessionId).collection('runs');
  static CollectionReference<Json> feedback() => fs.collection('feedback');

  // ---------------------------------------------------------------- streams

  static Stream<List<Member>> membersStream(String teamId) =>
      members(teamId).snapshots().map((q) {
        final list = q.docs.map(Member.fromDoc).toList();
        list.sort((a, b) => a.displayName
            .toLowerCase()
            .compareTo(b.displayName.toLowerCase()));
        return list;
      });

  /// Sessions that have not ended yet (start within the last 2 hours or later).
  static Stream<List<Session>> upcomingSessions(String teamId,
          {int limit = 40}) =>
      sessions(teamId)
          .where('start',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(hours: 2))))
          .orderBy('start')
          .limit(limit)
          .snapshots()
          .map((q) => q.docs.map(Session.fromDoc).toList());

  static Stream<List<Session>> sessionsBetween(
          String teamId, DateTime from, DateTime to) =>
      sessions(teamId)
          .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('start', isLessThan: Timestamp.fromDate(to))
          .orderBy('start')
          .snapshots()
          .map((q) => q.docs.map(Session.fromDoc).toList());

  static Stream<Session?> sessionStream(String teamId, String sessionId) =>
      sessions(teamId)
          .doc(sessionId)
          .snapshots()
          .map((d) => d.exists ? Session.fromDoc(d) : null);

  static Stream<Map<String, Rsvp>> rsvpsStream(
          String teamId, String sessionId) =>
      rsvps(teamId, sessionId).snapshots().map(
          (q) => {for (final d in q.docs) d.id: Rsvp.fromDoc(d)});

  static Stream<List<Run>> runsStream(String teamId, String sessionId) =>
      runs(teamId, sessionId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((q) => q.docs.map(Run.fromDoc).toList());

  /// Best times of the whole team for one distance (all sessions).
  static Stream<List<Run>> leaderboard(String teamId, double meters) =>
      fs
          .collectionGroup('runs')
          .where('teamId', isEqualTo: teamId)
          .where('targetMeters', isEqualTo: meters)
          .orderBy('timeMs')
          .limit(300)
          .snapshots()
          .map((q) => q.docs.map(Run.fromDoc).toList());

  // ----------------------------------------------------------------- writes

  static Future<void> saveProfile(UserProfile old, Json data) async {
    await user(old.uid).set(data, SetOptions(merge: true));
    // keep the public copy in every team up to date
    final memberData = <String, dynamic>{
      for (final k in ['firstName', 'lastName', 'weight', 'gender', 'photoUrl'])
        if (data.containsKey(k)) k: data[k],
    };
    if (memberData.isEmpty) return;
    for (final t in old.teamIds) {
      try {
        await members(t).doc(old.uid).set(memberData, SetOptions(merge: true));
      } catch (_) {
        // no longer a member of that team – ignore
      }
    }
  }

  static Future<void> setRsvp(
    String teamId,
    String sessionId,
    String uid, {
    RsvpStatus? status,
    Side? side,
    bool clearSide = false,
    bool byAdmin = false,
  }) {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status != null) data['status'] = status.name;
    if (clearSide) {
      data['side'] = FieldValue.delete();
      data['sideByAdmin'] = false;
    } else if (side != null) {
      data['side'] = side.name;
      data['sideByAdmin'] = byAdmin;
    }
    return rsvps(teamId, sessionId)
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  static Future<String> saveSession(String teamId, String? sessionId,
      {required SessionType type,
      required DateTime start,
      required String title,
      String? location,
      String? notes,
      bool startChanged = false,
      required String uid}) async {
    final data = <String, dynamic>{
      'type': type.name,
      'start': Timestamp.fromDate(start),
      'title': title.trim(),
      'location': (location ?? '').trim(),
      'notes': (notes ?? '').trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
      // a new start time means a new 3-hour reminder
      if (sessionId == null || startChanged) 'reminderSent': false,
    };
    if (sessionId == null) {
      final ref = await sessions(teamId).add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
      });
      return ref.id;
    }
    await sessions(teamId).doc(sessionId).update(data);
    return sessionId;
  }

  static Future<void> deleteSession(String teamId, String sessionId) =>
      sessions(teamId).doc(sessionId).delete();

  static Future<void> saveSeating(String teamId, String sessionId,
          {required String? boat,
          required Map<String, String> seats,
          required Set<String> manual}) =>
      sessions(teamId).doc(sessionId).update({
        'boat': boat,
        'seats': seats,
        'manualSeats': manual.toList(),
        'seatingUpdatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> saveRun(String teamId, String sessionId, Run run) =>
      runs(teamId, sessionId).add(run.toMap());

  static Future<void> deleteRun(String teamId, String sessionId, String runId) =>
      runs(teamId, sessionId).doc(runId).delete();

  /// Feedback is e-mailed to the developer by a Cloud Function.
  /// The address is only stored on the server – users never see it.
  static Future<void> sendFeedback(
          {required String text, required UserProfile me, required String lang}) =>
      feedback().add({
        'text': text.trim(),
        'uid': me.uid,
        'name': me.displayName,
        'email': me.email,
        'phone': me.phone,
        'lang': lang,
        'createdAt': FieldValue.serverTimestamp(),
      });
}
