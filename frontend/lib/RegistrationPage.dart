// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_style.dart';
import 'profile_setup_page.dart';
import 'registration_service.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, this.initialEmail = ''});
  final String initialEmail;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _confirmEmail = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _service = const RegistrationService();
  bool _hidePassword = true;
  bool _busy = false;
  bool _created = false;
  String? _error;
  final _profileDraft = ProfileSetupDraft();

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    _confirmEmail.dispose();
    _password.dispose();
    _phone.dispose();
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
      await _service.validateAccount(
        email: _email.text,
        confirmEmail: _confirmEmail.text,
        password: _password.text,
        phoneNumber: _phone.text,
      );
      if (!mounted) return;
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/profile/setup'),
          builder: (_) => ProfileSetupPage(
            draft: _profileDraft,
            onSubmit: (profile) => _service.register(
              email: _email.text,
              confirmEmail: _confirmEmail.text,
              password: _password.text,
              phoneNumber: _phone.text,
              profile: profile,
            ),
          ),
        ),
      );
      if (mounted && created == true) {
        TextInput.finishAutofillContext(shouldSave: false);
        _password.clear();
        setState(() => _created = true);
      }
    } on RegistrationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _backToLogin() =>
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);

  Widget _label(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      label,
      style: AuthStyle.serif.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (email.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthStyle.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/Logo2.png',
                      width: 240,
                      height: 145,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _created ? 'Account created' : 'Create an account',
                    style: const TextStyle(
                      fontSize: 34,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                      color: Color(0xFF080C08),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _created
                        ? 'Your TrackTalk account and profile are ready.'
                        : 'A little Logging. A big tracking',
                    style: AuthStyle.serif.copyWith(
                      fontSize: 18,
                      color: AuthStyle.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (_created) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 44,
                        color: AuthStyle.green,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _email.text.trim(),
                      style: AuthStyle.serif.copyWith(
                        fontSize: 18,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 26),
                    FilledButton(
                      onPressed: _backToLogin,
                      style: AuthStyle.primaryButton,
                      child: const Text('Back to log in'),
                    ),
                  ] else
                    AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _label('Email address'),
                            TextFormField(
                              key: const Key('registration-email'),
                              controller: _email,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [
                                AutofillHints.newUsername,
                                AutofillHints.email,
                              ],
                              decoration: AuthStyle.inputDecoration(
                                'your@example.com',
                              ),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 18),
                            _label('Confirm email address'),
                            TextFormField(
                              key: const Key('registration-confirm-email'),
                              controller: _confirmEmail,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: AuthStyle.inputDecoration(
                                'Enter your email again',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Confirm your email address.';
                                }
                                if (value.trim().toLowerCase() !=
                                    _email.text.trim().toLowerCase()) {
                                  return 'The email addresses do not match.';
                                }
                                return _validateEmail(value);
                              },
                            ),
                            const SizedBox(height: 18),
                            _label('Password'),
                            TextFormField(
                              key: const Key('registration-password'),
                              controller: _password,
                              enabled: !_busy,
                              obscureText: _hidePassword,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: AuthStyle.inputDecoration(
                                'At least 8 characters',
                                suffixIcon: IconButton(
                                  tooltip: _hidePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 21,
                                    color: const Color(0xFF353A35),
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter a password.';
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
                            const SizedBox(height: 18),
                            _label('Phone number'),
                            TextFormField(
                              key: const Key('registration-phone'),
                              controller: _phone,
                              enabled: !_busy,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [
                                AutofillHints.telephoneNumber,
                              ],
                              decoration: AuthStyle.inputDecoration(
                                '+44 7700 900123',
                              ),
                              onFieldSubmitted: (_) => _submit(),
                              validator: (value) {
                                final phone = value?.trim() ?? '';
                                if (phone.isEmpty) {
                                  return 'Enter your phone number.';
                                }
                                final compact = phone.replaceAll(
                                  RegExp(r'[ ()\-.]'),
                                  '',
                                );
                                if (phone.length > 40 ||
                                    !RegExp(r'^\+?[0-9]{7,15}$')
                                        .hasMatch(compact)) {
                                  return 'Enter a valid phone number (7–15 digits).';
                                }
                                return null;
                              },
                            ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _error!,
                                    key: const Key('account-error'),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 26),
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
                                  : const Text('Create account'),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _busy ? null : _backToLogin,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF080C08),
                                textStyle: AuthStyle.serif.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              child: const Text(
                                'Already have an account? Log in',
                              ),
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
