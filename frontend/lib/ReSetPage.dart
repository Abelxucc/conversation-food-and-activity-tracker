// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_style.dart';
import 'password_reset_service.dart';

class ResetPage extends StatefulWidget {
  const ResetPage({super.key, this.initialEmail = '', this.uid, this.token});

  final String initialEmail;
  final String? uid;
  final String? token;

  @override
  State<ResetPage> createState() => _ResetPageState();
}

class _ResetPageState extends State<ResetPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final TextEditingController _email;
  final _service = const PasswordResetService();
  bool _busy = false;
  bool _finished = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  String? _error;

  bool get _settingPassword => widget.uid != null && widget.token != null;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_settingPassword) {
        await _service.confirm(
          uid: widget.uid!,
          token: widget.token!,
          password: _password.text,
          confirmation: _confirmation.text,
        );
        TextInput.finishAutofillContext(shouldSave: false);
        _password.clear();
        _confirmation.clear();
      } else {
        await _service.requestLink(_email.text);
      }
      if (mounted) setState(() => _finished = true);
    } on PasswordResetException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _label(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      label,
      style: AuthStyle.serif.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _visibility(bool hidden, String field, VoidCallback onPressed) =>
      IconButton(
        tooltip: '${hidden ? 'Show' : 'Hide'} $field',
        onPressed: onPressed,
        icon: Icon(
          hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: const Color(0xFF353A35),
          size: 21,
        ),
      );

  void _backToLogin() =>
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);

  @override
  Widget build(BuildContext context) {
    final title = _finished
        ? (_settingPassword ? 'Password reset' : 'Reset link requested')
        : (_settingPassword ? 'Set a new password' : 'Forgot password?');
    final subtitle = _finished
        ? (_settingPassword
              ? 'Your new password is ready. You can return to log in.'
              : 'If an eligible account matches your email, a reset link has been prepared.')
        : (_settingPassword
              ? 'Choose a new password for your TrackTalk account.'
              : 'Enter your email and we’ll help you get back to your account.');

    return Scaffold(
      backgroundColor: AuthStyle.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back to log in',
                      onPressed: _busy ? null : _backToLogin,
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF353A35),
                      ),
                    ),
                  ),
                  Center(
                    child: Image.asset(
                      'assets/images/Logo2.png',
                      width: _settingPassword ? 260 : 320,
                      height: _settingPassword ? 160 : 210,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 34,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                      color: Color(0xFF080C08),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    style: AuthStyle.serif.copyWith(
                      fontSize: 18,
                      height: 1.45,
                      color: AuthStyle.muted,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_finished) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.check_circle_outline,
                        color: AuthStyle.green,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _backToLogin,
                      style: AuthStyle.primaryButton,
                      child: const Text('Back to log in'),
                    ),
                    if (!_settingPassword)
                      TextButton(
                        onPressed: () => setState(() {
                          _finished = false;
                          _error = null;
                        }),
                        child: const Text(
                          'Use a different email',
                          style: TextStyle(color: AuthStyle.green),
                        ),
                      ),
                  ] else
                    AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_settingPassword) ...[
                              _label('Email address'),
                              TextFormField(
                                key: const Key('reset-email'),
                                controller: _email,
                                enabled: !_busy,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.email],
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: AuthStyle.inputDecoration(
                                  'your@example.com',
                                ),
                                onFieldSubmitted: (_) => _submit(),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) {
                                    return 'Enter your email address.';
                                  }
                                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(email)) {
                                    return 'Enter a valid email address.';
                                  }
                                  return null;
                                },
                              ),
                            ] else ...[
                              _label('New password'),
                              TextFormField(
                                key: const Key('reset-password'),
                                controller: _password,
                                enabled: !_busy,
                                obscureText: _hidePassword,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: AuthStyle.inputDecoration(
                                  'At least 8 characters',
                                  suffixIcon: _visibility(
                                    _hidePassword,
                                    'new password',
                                    () => setState(
                                      () => _hidePassword = !_hidePassword,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter a new password.';
                                  }
                                  if (value.length < 8) {
                                    return 'Use at least 8 characters.';
                                  }
                                  if (value.length > 4096) {
                                    return 'Use a shorter password.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Use at least 8 characters. Avoid common passwords and numbers only.',
                                style: AuthStyle.serif.copyWith(
                                  color: AuthStyle.muted,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 22),
                              _label('Confirm new password'),
                              TextFormField(
                                key: const Key('reset-confirmation'),
                                controller: _confirmation,
                                enabled: !_busy,
                                obscureText: _hideConfirmation,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                autocorrect: false,
                                enableSuggestions: false,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: AuthStyle.inputDecoration(
                                  'Enter your new password again',
                                  suffixIcon: _visibility(
                                    _hideConfirmation,
                                    'confirmation password',
                                    () => setState(
                                      () => _hideConfirmation =
                                          !_hideConfirmation,
                                    ),
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Confirm your new password.'
                                    : value != _password.text
                                    ? 'The passwords do not match.'
                                    : null,
                              ),
                            ],
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 18),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _error!,
                                    key: const Key('reset-error'),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 28),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              style: AuthStyle.primaryButton,
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _settingPassword
                                          ? 'Reset password'
                                          : 'Request reset link',
                                    ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: _busy ? null : _backToLogin,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF080C08),
                                textStyle: AuthStyle.serif.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: const Text('Back to log in'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
