import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../services/db.dart';
import '../services/team_service.dart';
import '../services/ui.dart';
import '../state/app_state.dart';
import '../widgets/avatar.dart';
import '../widgets/lang_switch.dart';

/// First-time setup (setup = true) and later editing of the own profile.
/// Name is required; last name, age, weight and gender are optional.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.setup = false});
  final bool setup;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _age = TextEditingController();
  final _weight = TextEditingController();
  String? _gender;
  String? _photoUrl;
  bool _busy = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile;
    if (p != null) {
      _first.text = p.firstName;
      _last.text = p.lastName ?? '';
      _age.text = p.age?.toString() ?? '';
      _weight.text = p.weight == null
          ? ''
          : (p.weight! % 1 == 0
              ? p.weight!.toInt().toString()
              : p.weight!.toString());
      _gender = p.gender;
      _photoUrl = p.photoUrl;
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _age.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final app = context.read<AppState>();
    setState(() => _uploading = true);
    try {
      final url = await TeamService.pickAvatar(app.uid);
      if (url != null) setState(() => _photoUrl = url);
    } catch (e) {
      toast('$e');
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _save() async {
    final s = S.of(context);
    final app = context.read<AppState>();
    if (_first.text.trim().isEmpty) {
      toast(s.t('firstNameRequired'));
      return;
    }
    final weight = double.tryParse(_weight.text.replaceAll(',', '.').trim());
    final age = int.tryParse(_age.text.trim());
    if (weight != null && (weight < 20 || weight > 250)) {
      toast(s.t('weightInvalid'));
      return;
    }
    setState(() => _busy = true);
    final user = app.user!;
    final data = <String, dynamic>{
      'firstName': _first.text.trim(),
      'lastName': _last.text.trim().isEmpty ? null : _last.text.trim(),
      'age': age,
      'weight': weight,
      'gender': _gender,
      'photoUrl': _photoUrl,
      'email': user.email,
      'phone': user.phoneNumber,
      'lang': app.lang,
    };
    try {
      final old = app.profile;
      if (old == null) {
        await Db.user(user.uid).set({...data, 'teamIds': <String>[]});
      } else {
        await Db.saveProfile(old, data);
      }
      if (!widget.setup && mounted) {
        toast(s.t('saved'));
        Navigator.pop(context);
      }
    } catch (e) {
      toast('${s.t('error')}: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final app = context.watch<AppState>();
    final user = app.user;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.setup ? s.t('createProfile') : s.t('myProfile')),
        actions: [
          if (widget.setup) const LangSwitch(),
          if (widget.setup)
            IconButton(
                tooltip: s.t('logout'),
                onPressed: app.signOut,
                icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(children: [
              Avatar(url: _photoUrl, name: _first.text, radius: 48),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  onPressed: _uploading ? null : _pickPhoto,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_camera, size: 18),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          if (user != null)
            Text(user.email ?? user.phoneNumber ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          TextField(
            controller: _first,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: '${s.t('firstName')} *'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _last,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
                labelText: s.t('lastName'), helperText: s.t('optional')),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _age,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: s.t('age'), helperText: s.t('optional')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _weight,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: s.t('weightKg'), helperText: s.t('optional')),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(s.t('weightHint'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Text('${s.t('gender')} (${s.t('optional')})'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            emptySelectionAllowed: true,
            segments: [
              ButtonSegment(value: 'female', label: Text(s.t('female'))),
              ButtonSegment(value: 'male', label: Text(s.t('male'))),
              ButtonSegment(value: 'diverse', label: Text(s.t('diverse'))),
            ],
            selected: _gender == null ? <String>{} : {_gender!},
            onSelectionChanged: (v) =>
                setState(() => _gender = v.isEmpty ? null : v.first),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(widget.setup ? s.t('continue') : s.t('save')),
          ),
        ],
      ),
    );
  }
}
