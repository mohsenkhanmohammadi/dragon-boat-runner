import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dragon_boat_runner/models/models.dart';
import 'package:dragon_boat_runner/services/backend.dart';
import 'package:dragon_boat_runner/services/db.dart';
import 'package:dragon_boat_runner/services/team_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile user(String uid) => UserProfile(uid: uid, firstName: 'User $uid');

Future<Team> team(String id) async => Team.fromDoc(await Db.team(id).get());

void main() {
  setUp(() => Backend.firestore = FakeFirebaseFirestore());

  test('create team -> unique 6 character code, creator is admin', () async {
    final id = await TeamService.createTeam(name: ' Drachen ', me: user('a'));
    final t = await team(id);
    expect(t.name, 'Drachen');
    expect(t.ownerId, 'a');
    expect(t.memberIds, ['a']);
    expect(RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(t.code), isTrue);
    final code = await Db.code(t.code).get();
    expect(code['teamId'], id);
    final me = UserProfile.fromDoc(await Db.user('a').get());
    expect(me.currentTeamId, id);
  });

  test('codes of many teams are all different', () async {
    final codes = <String>{};
    for (var i = 0; i < 30; i++) {
      final id = await TeamService.createTeam(name: 'T$i', me: user('o$i'));
      codes.add((await team(id)).code);
    }
    expect(codes.length, 30);
  });

  test('join with code (also lower case / with spaces)', () async {
    final id = await TeamService.createTeam(name: 'T', me: user('a'));
    final code = (await team(id)).code;
    final r = await TeamService.joinTeam(
        code: ' ${code.substring(0, 3).toLowerCase()} ${code.substring(3)} ',
        me: user('b'));
    expect(r, JoinResult.joined);
    expect((await team(id)).memberIds, containsAll(['a', 'b']));
    expect((await Db.members(id).doc('b').get()).exists, isTrue);
  });

  test('join twice -> already member', () async {
    final id = await TeamService.createTeam(name: 'T', me: user('a'));
    final code = (await team(id)).code;
    expect(await TeamService.joinTeam(code: code, me: user('a')),
        JoinResult.alreadyMember);
  });

  test('unknown code', () async {
    expect(await TeamService.joinTeam(code: 'ZZZZZZ', me: user('b')),
        JoinResult.notFound);
  });

  test('maximum 60 members', () async {
    final id = await TeamService.createTeam(name: 'T', me: user('m0'));
    await Db.team(id).update({
      'memberIds': [for (var i = 0; i < 60; i++) 'm$i'],
    });
    final code = (await team(id)).code;
    expect(await TeamService.joinTeam(code: code, me: user('x')),
        JoinResult.full);
    expect((await team(id)).memberIds.length, 60);
  });

  test('leave team (co-admin role is removed)', () async {
    final id = await TeamService.createTeam(name: 'T', me: user('a'));
    await TeamService.joinTeam(code: (await team(id)).code, me: user('b'));
    await TeamService.setCoAdmin(id, 'b');
    await TeamService.leaveTeam(team: await team(id), uid: 'b');
    final t = await team(id);
    expect(t.memberIds, ['a']);
    expect(t.coAdminId, isNull);
  });

  test('admin hands over to the co-admin -> roles swap', () async {
    final id = await TeamService.createTeam(name: 'T', me: user('a'));
    await TeamService.joinTeam(code: (await team(id)).code, me: user('b'));
    await TeamService.setCoAdmin(id, 'b');
    await TeamService.transferOwnership(team: await team(id), newOwnerUid: 'b');
    final t = await team(id);
    expect(t.ownerId, 'b');
    expect(t.coAdminId, 'a');
    expect(t.isManager('a'), isTrue);
    expect(t.isManager('b'), isTrue);
  });

  test('admin removes a member', () async {
    final id = await TeamService.createTeam(name: 'T', me: user('a'));
    await TeamService.joinTeam(code: (await team(id)).code, me: user('b'));
    await TeamService.removeMember(team: await team(id), memberUid: 'b');
    expect((await team(id)).memberIds, ['a']);
    expect((await Db.members(id).doc('b').get()).exists, isFalse);
  });

  test('attendance + paddle side, admin side is marked', () async {
    await Db.setRsvp('t', 's', 'u', status: RsvpStatus.yes, side: Side.left);
    var r = Rsvp.fromDoc(await Db.rsvps('t', 's').doc('u').get());
    expect(r.status, RsvpStatus.yes);
    expect(r.side, Side.left);
    expect(r.sideByAdmin, isFalse);

    await Db.setRsvp('t', 's', 'u', side: Side.right, byAdmin: true);
    r = Rsvp.fromDoc(await Db.rsvps('t', 's').doc('u').get());
    expect(r.side, Side.right);
    expect(r.sideByAdmin, isTrue); // shown in blue
    expect(r.status, RsvpStatus.yes); // unchanged

    await Db.setRsvp('t', 's', 'u', clearSide: true);
    r = Rsvp.fromDoc(await Db.rsvps('t', 's').doc('u').get());
    expect(r.side, isNull);
  });

  test('new start time resets the 3-hour reminder', () async {
    final id = await Db.saveSession('t', null,
        type: SessionType.training, start: DateTime(2030, 1, 1, 18),
        title: '', uid: 'a');
    await Db.sessions('t').doc(id).update({'reminderSent': true});
    await Db.saveSession('t', id,
        type: SessionType.training, start: DateTime(2030, 1, 1, 19),
        title: '', startChanged: true, uid: 'a');
    final d = await Db.sessions('t').doc(id).get();
    expect(d['reminderSent'], false);
    expect((d['start'] as Timestamp).toDate(), DateTime(2030, 1, 1, 19));
  });
}
