import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/db.dart';
import '../services/team_service.dart';
import '../services/ui.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'team_gate_screen.dart';

/// Team page: name + photo (editable by admins), invite code / link,
/// member list (max. 60), roles, leave / switch team.
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final app = context.watch<AppState>();
    final team = app.team!;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('navTeam')),
        actions: [
          IconButton(
            tooltip: s.t('switchTeam'),
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => _switchTeam(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Stack(children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: dragonRed,
                foregroundImage:
                    team.photoUrl != null ? NetworkImage(team.photoUrl!) : null,
                child: Image.asset('assets/images/logo.png', width: 80),
              ),
              if (app.isManager)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    tooltip: s.t('changePhoto'),
                    icon: const Icon(Icons.photo_camera, size: 18),
                    onPressed: () async {
                      try {
                        await TeamService.pickTeamPhoto(team.id);
                      } catch (e) {
                        toast('${s.t('error')}: $e');
                      }
                    },
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(
              child: Text(team.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            if (app.isManager)
              IconButton(
                tooltip: s.t('rename'),
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _rename(context, team),
              ),
          ]),
          _InviteCard(team: team),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              s.t('membersCount', {
                'n': '${team.memberIds.length}',
                'max': '${AppConfig.maxMembers}'
              }),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final m in app.members) _memberTile(context, s, app, team, m),
          const SizedBox(height: 16),
          if (app.isOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                Text(s.t('ownerLeaveHint'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: noRed),
                  icon: const Icon(Icons.delete_forever),
                  label: Text(s.t('deleteTeam')),
                  onPressed: () async {
                    final ok = await confirm(context,
                        title: s.t('deleteTeam'),
                        message: s.t('deleteTeamMsg', {'team': team.name}),
                        ok: s.t('delete'),
                        cancel: s.t('cancel'),
                        danger: true);
                    if (!ok) return;
                    try {
                      await TeamService.deleteTeam(team);
                      toast(s.t('teamDeleted'));
                    } catch (e) {
                      toast('${s.t('error')}: $e');
                    }
                  },
                ),
              ]),
            ),
          if (!app.isOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: noRed),
                icon: const Icon(Icons.exit_to_app),
                label: Text(s.t('leaveTeam')),
                onPressed: () async {
                  final ok = await confirm(context,
                      title: s.t('leaveTeam'),
                      message: s.t('leaveTeamMsg', {'team': team.name}),
                      ok: s.t('leave'),
                      cancel: s.t('cancel'),
                      danger: true);
                  if (!ok) return;
                  try {
                    await TeamService.leaveTeam(team: team, uid: app.uid);
                  } catch (e) {
                    toast('${s.t('error')}: $e');
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _memberTile(
      BuildContext context, S s, AppState app, Team team, Member m) {
    final role = m.uid == team.ownerId
        ? s.t('admin')
        : m.uid == team.coAdminId
            ? s.t('coAdmin')
            : null;
    final details = <String>[
      if (role != null) role,
      if (app.isManager && m.weight != null)
        '${m.weight!.toStringAsFixed(0)} kg',
    ];
    final canManage = app.isManager && m.uid != team.ownerId && m.uid != app.uid;
    return ListTile(
      leading: Avatar(url: m.photoUrl, name: m.displayName),
      title: Text(m.displayName +
          (m.uid == app.uid ? ' (${s.t('you')})' : '')),
      subtitle: details.isEmpty ? null : Text(details.join(' · ')),
      trailing: !canManage
          ? (role != null
              ? const Icon(Icons.verified, color: adminBlue)
              : null)
          : PopupMenuButton<String>(
              onSelected: (v) async {
                try {
                  if (v == 'co') {
                    await TeamService.setCoAdmin(team.id, m.uid);
                  } else if (v == 'unco') {
                    await TeamService.setCoAdmin(team.id, null);
                  } else if (v == 'owner') {
                    final ok = await confirm(context,
                        title: s.t('transferAdmin'),
                        message: s.t('transferAdminMsg',
                            {'name': m.displayName}),
                        ok: s.t('transfer'),
                        cancel: s.t('cancel'),
                        danger: true);
                    if (ok) {
                      await TeamService.transferOwnership(
                          team: team, newOwnerUid: m.uid);
                      toast(s.t('adminTransferred'));
                    }
                  } else if (v == 'remove') {
                    final ok = await confirm(context,
                        title: s.t('removeMember'),
                        message: m.displayName,
                        ok: s.t('remove'),
                        cancel: s.t('cancel'),
                        danger: true);
                    if (ok) {
                      await TeamService.removeMember(
                          team: team, memberUid: m.uid);
                    }
                  }
                } catch (e) {
                  toast('${s.t('error')}: $e');
                }
              },
              itemBuilder: (_) => [
                if (app.isOwner && team.coAdminId != m.uid)
                  PopupMenuItem(value: 'co', child: Text(s.t('makeCoAdmin'))),
                if (app.isOwner && team.coAdminId == m.uid)
                  PopupMenuItem(
                      value: 'unco', child: Text(s.t('removeCoAdmin'))),
                if (app.isOwner)
                  PopupMenuItem(
                      value: 'owner', child: Text(s.t('transferAdmin'))),
                PopupMenuItem(value: 'remove', child: Text(s.t('removeMember'))),
              ],
            ),
    );
  }

  Future<void> _rename(BuildContext context, Team team) async {
    final s = S.of(context);
    final ctrl = TextEditingController(text: team.name);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.t('teamName')),
        content: TextField(controller: ctrl, autofocus: true, maxLength: 60),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: Text(s.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: Text(s.t('save'))),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      try {
        await TeamService.renameTeam(team.id, name);
      } catch (e) {
        toast('${s.t('error')}: $e');
      }
    }
  }

  Future<void> _switchTeam(BuildContext context) async {
    final s = S.of(context);
    final app = context.read<AppState>();
    final ids = app.profile?.teamIds ?? const <String>[];
    // load names of all own teams
    final teams = <Team>[];
    for (final id in ids) {
      try {
        final d = await Db.team(id).get(const GetOptions());
        if (d.exists) teams.add(Team.fromDoc(d));
      } catch (_) {}
    }
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final t in teams)
            ListTile(
              leading: const Icon(Icons.groups),
              title: Text(t.name),
              trailing: t.id == app.team?.id ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.pop(c);
                app.switchTeam(t.id);
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(s.t('addTeam')),
            onTap: () {
              Navigator.pop(c);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TeamGateScreen(pushed: true)));
            },
          ),
        ]),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.team});
  final Team team;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final link = AppConfig.inviteLink(team.code);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(s.t('inviteCode'), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(team.code,
              style: const TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 6)),
          const SizedBox(height: 4),
          Text(s.t('inviteHint'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: Text(s.t('copy')),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: team.code));
                toast(s.t('copied'));
              },
            ),
            FilledButton.icon(
              icon: const Icon(Icons.share),
              label: Text(s.t('shareLink')),
              onPressed: team.isFull
                  ? null
                  : () => SharePlus.instance.share(ShareParams(
                        subject: AppConfig.appName,
                        text: s.t('shareText', {
                          'team': team.name,
                          'code': team.code,
                          'link': link,
                        }),
                      )),
            ),
          ]),
          if (team.isFull)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(s.t('teamFull'),
                  style: const TextStyle(color: noRed)),
            ),
        ]),
      ),
    );
  }
}
