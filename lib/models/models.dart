import 'package:cloud_firestore/cloud_firestore.dart';

import '../config.dart';

typedef Json = Map<String, dynamic>;

enum SessionType { training, race, event }

enum RsvpStatus { yes, no, maybe }

enum Side { left, right }

String _str(Object? v) => v is String ? v : '';
String? _strOrNull(Object? v) => v is String && v.isNotEmpty ? v : null;
double? _dbl(Object? v) => v is num ? v.toDouble() : null;
int? _int(Object? v) => v is num ? v.toInt() : null;

DateTime? _date(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

String joinName(String first, String? last) =>
    [first.trim(), (last ?? '').trim()].where((s) => s.isNotEmpty).join(' ');

/// The signed-in user's own profile: users/{uid}
class UserProfile {
  UserProfile({
    required this.uid,
    this.firstName = '',
    this.lastName,
    this.age,
    this.weight,
    this.gender,
    this.email,
    this.phone,
    this.photoUrl,
    this.teamIds = const [],
    this.currentTeamId,
  });

  final String uid;
  final String firstName;
  final String? lastName;
  final int? age;
  final double? weight;
  final String? gender; // male | female | diverse
  final String? email;
  final String? phone;
  final String? photoUrl;
  final List<String> teamIds;
  final String? currentTeamId;

  bool get isComplete => firstName.trim().isNotEmpty;
  String get displayName => joinName(firstName, lastName);

  factory UserProfile.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const {};
    return UserProfile(
      uid: doc.id,
      firstName: _str(d['firstName']),
      lastName: _strOrNull(d['lastName']),
      age: _int(d['age']),
      weight: _dbl(d['weight']),
      gender: _strOrNull(d['gender']),
      email: _strOrNull(d['email']),
      phone: _strOrNull(d['phone']),
      photoUrl: _strOrNull(d['photoUrl']),
      teamIds: List<String>.from((d['teamIds'] as List?) ?? const []),
      currentTeamId: _strOrNull(d['currentTeamId']),
    );
  }

  /// Public data copied into teams/{teamId}/members/{uid}.
  Json memberMap() => {
        'firstName': firstName,
        'lastName': lastName,
        'weight': weight,
        'gender': gender,
        'photoUrl': photoUrl,
      };
}

/// teams/{teamId}
class Team {
  Team({
    required this.id,
    required this.name,
    required this.code,
    required this.ownerId,
    this.coAdminId,
    this.photoUrl,
    this.memberIds = const [],
    this.defaultLayouts = const {},
  });

  final String id;
  final String name;
  final String code;
  final String ownerId;
  final String? coAdminId;
  final String? photoUrl;
  final List<String> memberIds;

  /// boatId ('small' | 'large') -> seatId -> uid
  final Map<String, Map<String, String>> defaultLayouts;

  bool isManager(String? uid) =>
      uid != null && (uid == ownerId || uid == coAdminId);
  bool get isFull => memberIds.length >= AppConfig.maxMembers;

  factory Team.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const {};
    final layouts = <String, Map<String, String>>{};
    final raw = d['defaultLayouts'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) {
          layouts['$k'] = v.map((s, u) => MapEntry('$s', '$u'));
        }
      });
    }
    return Team(
      id: doc.id,
      name: _str(d['name']),
      code: _str(d['code']),
      ownerId: _str(d['ownerId']),
      coAdminId: _strOrNull(d['coAdminId']),
      photoUrl: _strOrNull(d['photoUrl']),
      memberIds: List<String>.from((d['memberIds'] as List?) ?? const []),
      defaultLayouts: layouts,
    );
  }
}

/// teams/{teamId}/members/{uid}
class Member {
  Member({
    required this.uid,
    required this.firstName,
    this.lastName,
    this.weight,
    this.gender,
    this.photoUrl,
  });

  final String uid;
  final String firstName;
  final String? lastName;
  final double? weight;
  final String? gender;
  final String? photoUrl;

  String get displayName => joinName(firstName, lastName);

  /// "Anna M." – short enough for a seat in the boat.
  String get shortName {
    final l = (lastName ?? '').trim();
    return l.isEmpty ? firstName : '$firstName ${l[0]}.';
  }

  factory Member.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const {};
    return Member(
      uid: doc.id,
      firstName: _str(d['firstName']),
      lastName: _strOrNull(d['lastName']),
      weight: _dbl(d['weight']),
      gender: _strOrNull(d['gender']),
      photoUrl: _strOrNull(d['photoUrl']),
    );
  }
}

/// teams/{teamId}/sessions/{sessionId} – training, race or other event.
class Session {
  Session({
    required this.id,
    required this.type,
    required this.start,
    this.title = '',
    this.location,
    this.notes,
    this.boat,
    this.seats = const {},
    this.manualSeats = const {},
  });

  final String id;
  final SessionType type;
  final DateTime start;
  final String title;
  final String? location;
  final String? notes;

  /// 'small' | 'large' | null (= automatic by number of attendees)
  final String? boat;

  /// seatId -> uid (saved layout; empty = automatic suggestion)
  final Map<String, String> seats;

  /// seats that were placed by the admin / co-admin (shown in blue)
  final Set<String> manualSeats;

  DateTime get rsvpLockAt => start.subtract(AppConfig.rsvpLock);
  bool get isStarted => !DateTime.now().isBefore(start);
  bool get isLocked => !DateTime.now().isBefore(rsvpLockAt);

  factory Session.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const {};
    final seatsRaw = d['seats'];
    return Session(
      id: doc.id,
      type: SessionType.values.asNameMap()[d['type']] ?? SessionType.training,
      start: _date(d['start']) ?? DateTime.now(),
      title: _str(d['title']),
      location: _strOrNull(d['location']),
      notes: _strOrNull(d['notes']),
      boat: _strOrNull(d['boat']),
      seats: seatsRaw is Map
          ? seatsRaw.map((k, v) => MapEntry('$k', '$v'))
          : <String, String>{},
      manualSeats: ((d['manualSeats'] as List?) ?? const [])
          .map((e) => '$e')
          .toSet(),
    );
  }
}

/// teams/{teamId}/sessions/{sessionId}/rsvps/{uid}
class Rsvp {
  Rsvp({required this.uid, this.status, this.side, this.sideByAdmin = false});

  final String uid;
  final RsvpStatus? status;
  final Side? side;
  final bool sideByAdmin;

  factory Rsvp.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const {};
    return Rsvp(
      uid: doc.id,
      status: RsvpStatus.values.asNameMap()[d['status']],
      side: Side.values.asNameMap()[d['side']],
      sideByAdmin: d['sideByAdmin'] == true,
    );
  }
}

class RunPoint {
  const RunPoint(this.lat, this.lng, this.tMs, this.speed);
  final double lat;
  final double lng;
  final int tMs; // ms since "Go"
  final double speed; // m/s

  Json toMap() => {'la': lat, 'ln': lng, 't': tMs, 'v': speed};
  factory RunPoint.fromMap(Map m) => RunPoint(
        (m['la'] as num).toDouble(),
        (m['ln'] as num).toDouble(),
        (m['t'] as num).toInt(),
        (m['v'] as num).toDouble(),
      );
}

/// teams/{teamId}/sessions/{sessionId}/runs/{runId} – one timed GPS run.
class Run {
  Run({
    required this.id,
    required this.uid,
    required this.name,
    required this.targetMeters,
    required this.timeMs,
    required this.maxSpeed,
    required this.minSpeed,
    required this.avgSpeed,
    required this.points,
    this.maxIndex,
    this.minIndex,
    this.strokeRate,
    this.createdAt,
    this.teamId = '',
    this.sessionId = '',
    this.sessionType,
    this.sessionStart,
  });

  final String id;
  final String teamId;
  final String sessionId;
  final SessionType? sessionType;
  final DateTime? sessionStart;
  final String uid;
  final String name;
  final double targetMeters;
  final int timeMs;
  final double maxSpeed; // m/s
  final double minSpeed; // m/s
  final double avgSpeed; // m/s
  final List<RunPoint> points;
  final int? maxIndex;
  final int? minIndex;
  final double? strokeRate; // strokes per minute (estimate)
  final DateTime? createdAt;

  /// time per 500 m in ms
  int get pace500Ms =>
      targetMeters <= 0 ? 0 : (timeMs * 500 / targetMeters).round();

  Json toMap() => {
        'uid': uid,
        'teamId': teamId,
        'sessionId': sessionId,
        'sessionType': sessionType?.name,
        'sessionStart':
            sessionStart == null ? null : Timestamp.fromDate(sessionStart!),
        'name': name,
        'targetMeters': targetMeters,
        'timeMs': timeMs,
        'maxSpeed': maxSpeed,
        'minSpeed': minSpeed,
        'avgSpeed': avgSpeed,
        'maxIndex': maxIndex,
        'minIndex': minIndex,
        'strokeRate': strokeRate,
        'points': points.map((p) => p.toMap()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory Run.fromDoc(DocumentSnapshot<Json> doc) {
    final d = doc.data() ?? const {};
    return Run(
      id: doc.id,
      teamId: _str(d['teamId']),
      sessionId: _strOrNull(d['sessionId']) ??
          doc.reference.parent.parent?.id ??
          '',
      sessionType: SessionType.values.asNameMap()[d['sessionType']],
      sessionStart: _date(d['sessionStart']),
      uid: _str(d['uid']),
      name: _str(d['name']),
      targetMeters: _dbl(d['targetMeters']) ?? 0,
      timeMs: _int(d['timeMs']) ?? 0,
      maxSpeed: _dbl(d['maxSpeed']) ?? 0,
      minSpeed: _dbl(d['minSpeed']) ?? 0,
      avgSpeed: _dbl(d['avgSpeed']) ?? 0,
      maxIndex: _int(d['maxIndex']),
      minIndex: _int(d['minIndex']),
      strokeRate: _dbl(d['strokeRate']),
      points: ((d['points'] as List?) ?? const [])
          .whereType<Map>()
          .map(RunPoint.fromMap)
          .toList(),
      createdAt: _date(d['createdAt']),
    );
  }
}
