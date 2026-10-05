import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../models/models.dart';
import 'backend.dart';
import 'db.dart';

enum JoinResult { joined, alreadyMember, notFound, full }

class TeamService {
  // no 0/O/1/I to avoid typos
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _rnd = Random.secure();

  static String _newCode() => List.generate(
      6, (_) => _alphabet[_rnd.nextInt(_alphabet.length)]).join();

  static String normalizeCode(String raw) =>
      raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static Json _memberDoc(UserProfile me) => {
        ...me.memberMap(),
        'joinedAt': FieldValue.serverTimestamp(),
      };

  /// Creates a team with a unique 6-character invite code.
  static Future<String> createTeam(
      {required String name, required UserProfile me}) async {
    final teamRef = Db.fs.collection('teams').doc();
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = _newCode();
      var taken = false;
      await Db.fs.runTransaction((tx) async {
        final c = await tx.get(Db.code(code));
        if (c.exists) {
          taken = true;
          return;
        }
        tx.set(teamRef, {
          'name': name.trim(),
          'code': code,
          'ownerId': me.uid,
          'coAdminId': null,
          'photoUrl': null,
          'memberIds': [me.uid],
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(Db.code(code), {
          'teamId': teamRef.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(Db.members(teamRef.id).doc(me.uid), _memberDoc(me));
        tx.set(
            Db.user(me.uid),
            {
              'teamIds': FieldValue.arrayUnion([teamRef.id]),
              'currentTeamId': teamRef.id,
            },
            SetOptions(merge: true));
      });
      if (!taken) return teamRef.id;
    }
    throw StateError('Could not create a unique team code');
  }

  /// Join a team with its invite code (max. [AppConfig.maxMembers] members).
  static Future<JoinResult> joinTeam(
      {required String code, required UserProfile me}) async {
    final c = normalizeCode(code);
    if (c.isEmpty) return JoinResult.notFound;
    final codeSnap = await Db.code(c).get();
    final teamId = codeSnap.data()?['teamId'] as String?;
    if (!codeSnap.exists || teamId == null) return JoinResult.notFound;

    var result = JoinResult.joined;
    await Db.fs.runTransaction((tx) async {
      final t = await tx.get(Db.team(teamId));
      if (!t.exists) {
        result = JoinResult.notFound;
        return;
      }
      final ids = List<String>.from((t.data()?['memberIds'] as List?) ?? []);
      if (ids.contains(me.uid)) {
        result = JoinResult.alreadyMember;
        tx.set(
            Db.user(me.uid),
            {
              'teamIds': FieldValue.arrayUnion([teamId]),
              'currentTeamId': teamId,
            },
            SetOptions(merge: true));
        return;
      }
      if (ids.length >= AppConfig.maxMembers) {
        result = JoinResult.full;
        return;
      }
      tx.update(Db.team(teamId), {
        'memberIds': FieldValue.arrayUnion([me.uid]),
      });
      tx.set(Db.members(teamId).doc(me.uid), _memberDoc(me));
      tx.set(
          Db.user(me.uid),
          {
            'teamIds': FieldValue.arrayUnion([teamId]),
            'currentTeamId': teamId,
          },
          SetOptions(merge: true));
    });
    return result;
  }

  static Future<void> leaveTeam({required Team team, required String uid}) {
    return Db.fs.runTransaction((tx) async {
      tx.update(Db.team(team.id), {
        'memberIds': FieldValue.arrayRemove([uid]),
        if (team.coAdminId == uid) 'coAdminId': null,
      });
      tx.delete(Db.members(team.id).doc(uid));
      tx.update(Db.user(uid), {
        'teamIds': FieldValue.arrayRemove([team.id]),
        'currentTeamId': FieldValue.delete(),
      });
    });
  }

  /// Admin / co-admin removes a member (never the owner).
  static Future<void> removeMember(
      {required Team team, required String memberUid}) {
    final batch = Db.fs.batch();
    batch.update(Db.team(team.id), {
      'memberIds': FieldValue.arrayRemove([memberUid]),
      if (team.coAdminId == memberUid) 'coAdminId': null,
    });
    batch.delete(Db.members(team.id).doc(memberUid));
    return batch.commit();
  }

  /// Owner chooses the "second person" (co-admin). null removes it.
  static Future<void> setCoAdmin(String teamId, String? uid) =>
      Db.team(teamId).update({'coAdminId': uid});

  /// Owner hands the admin role to another member. If that member was the
  /// co-admin, the old owner becomes co-admin.
  static Future<void> transferOwnership(
      {required Team team, required String newOwnerUid}) {
    return Db.team(team.id).update({
      'ownerId': newOwnerUid,
      'coAdminId':
          team.coAdminId == newOwnerUid ? team.ownerId : team.coAdminId,
    });
  }

  /// Deletes the team. A Cloud Function then removes trainings, results,
  /// the invite code and the team from every member's profile.
  static Future<void> deleteTeam(Team team) async {
    if (Backend.demo) {
      final batch = Db.fs.batch();
      batch.delete(Db.code(team.code));
      batch.delete(Db.team(team.id));
      await batch.commit();
      return;
    }
    await Db.team(team.id).delete();
  }

  static Future<void> renameTeam(String teamId, String name) =>
      Db.team(teamId).update({'name': name.trim()});

  static Future<void> saveDefaultLayout(
          String teamId, String boat, Map<String, String> seats) =>
      Db.team(teamId).update({'defaultLayouts.$boat': seats});

  // ----------------------------------------------------------------- photos

  static Future<String?> _pickAndUpload(String path) async {
    if (Backend.demo) throw DemoUnavailable();
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1024, imageQuality: 82);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  static Future<String?> pickTeamPhoto(String teamId) async {
    final url = await _pickAndUpload('teams/$teamId/photo.jpg');
    if (url != null) await Db.team(teamId).update({'photoUrl': url});
    return url;
  }

  static Future<String?> pickAvatar(String uid) =>
      _pickAndUpload('users/$uid/avatar.jpg');
}
