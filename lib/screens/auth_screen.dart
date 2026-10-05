import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../services/backend.dart';
import '../services/ui.dart';
import '../widgets/lang_switch.dart';

/// Login / registration with e-mail + password or mobile number (SMS code).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _mode = 0; // 0 = e-mail, 1 = phone
  bool _register = false;
  bool _busy = false;
  String? _error;
  String? _verificationId;

  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _phone = TextEditingController(text: '+49');
  final _sms = TextEditingController();

  final _auth = Backend.auth;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _phone.dispose();
    _sms.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? e.code;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _emailSubmit() => _run(() async {
        final email = _email.text.trim();
        final pass = _pass.text;
        if (_register) {
          await _auth.createUserWithEmailAndPassword(
              email: email, password: pass);
        } else {
          await _auth.signInWithEmailAndPassword(email: email, password: pass);
        }
      });

  Future<void> _resetPassword() async {
    final s = S.of(context);
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = s.t('enterEmailFirst'));
      return;
    }
    await _run(() async {
      await _auth.sendPasswordResetEmail(email: email);
      toast(s.t('resetSent'));
    });
  }

  Future<void> _sendSms() => _run(() async {
        await _auth.verifyPhoneNumber(
          phoneNumber: _phone.text.replaceAll(' ', ''),
          verificationCompleted: (cred) async {
            // Android can verify automatically
            await _auth.signInWithCredential(cred);
          },
          verificationFailed: (e) {
            if (mounted) {
              setState(() {
                _error = e.message ?? e.code;
                _busy = false;
              });
            }
          },
          codeSent: (id, _) {
            if (mounted) setState(() => _verificationId = id);
          },
          codeAutoRetrievalTimeout: (id) => _verificationId ??= id,
        );
      });

  Future<void> _verifySms() => _run(() async {
        final cred = PhoneAuthProvider.credential(
            verificationId: _verificationId!, smsCode: _sms.text.trim());
        await _auth.signInWithCredential(cred);
      });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: Alignment.centerRight, child: LangSwitch()),
                  Image.asset('assets/images/logo.png', height: 130),
                  const SizedBox(height: 12),
                  Text(AppConfig.appName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(s.t('welcomeSub'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                          value: 0,
                          icon: const Icon(Icons.alternate_email),
                          label: Text(s.t('email'))),
                      ButtonSegment(
                          value: 1,
                          icon: const Icon(Icons.smartphone),
                          label: Text(s.t('mobile'))),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (v) => setState(() {
                      _mode = v.first;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 20),
                  if (_mode == 0) ..._emailForm(s) else ..._phoneForm(s),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _emailForm(S s) => [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
              labelText: s.t('email'),
              prefixIcon: const Icon(Icons.alternate_email)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pass,
          obscureText: true,
          decoration: InputDecoration(
              labelText: s.t('password'),
              prefixIcon: const Icon(Icons.lock_outline)),
          onSubmitted: (_) => _emailSubmit(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _emailSubmit,
          child: _busy
              ? const _Spinner()
              : Text(_register ? s.t('register') : s.t('login')),
        ),
        TextButton(
          onPressed: () => setState(() => _register = !_register),
          child: Text(_register ? s.t('haveAccount') : s.t('noAccount')),
        ),
        if (!_register)
          TextButton(
              onPressed: _busy ? null : _resetPassword,
              child: Text(s.t('forgotPassword'))),
      ];

  List<Widget> _phoneForm(S s) => [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
              labelText: s.t('mobileNumber'),
              helperText: '+49 151 2345678',
              prefixIcon: const Icon(Icons.smartphone)),
        ),
        const SizedBox(height: 12),
        if (_verificationId == null)
          FilledButton(
            onPressed: _busy ? null : _sendSms,
            child: _busy ? const _Spinner() : Text(s.t('sendCode')),
          )
        else ...[
          TextField(
            controller: _sms,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: s.t('smsCode'), prefixIcon: const Icon(Icons.sms)),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _verifySms,
            child: _busy ? const _Spinner() : Text(s.t('login')),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _verificationId = null;
                      _sms.clear();
                    }),
            child: Text(s.t('changeNumber')),
          ),
        ],
      ];
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
}
