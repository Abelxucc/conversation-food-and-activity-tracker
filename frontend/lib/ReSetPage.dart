// ignore_for_file: file_names

import 'package:flutter/material.dart';

import 'auth_style.dart';
import 'password_reset_service.dart';

class ResetPage extends StatefulWidget {
  const ResetPage({super.key, this.initialEmail = ''});
  final String initialEmail;

  @override
  State<ResetPage> createState() => _ResetPageState();
}

class _ResetPageState extends State<ResetPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _service = const PasswordResetService();
  bool _busy = false;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
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
      await _service.requestReset(_email.text);
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

  void _backToLogin() =>
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);

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
                      width: 320,
                      height: 210,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _finished ? 'Request submitted' : 'Forgot password?',
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
                    _finished
                        ? 'Please contact your administrator to verify your identity and complete the reset.'
                        : 'Enter your registered email to request help from your administrator.',
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
                        size: 42,
                        color: AuthStyle.green,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your password will be changed after your identity is verified.',
                      style: AuthStyle.serif.copyWith(
                        fontSize: 16,
                        height: 1.45,
                        color: AuthStyle.muted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _backToLogin,
                      style: AuthStyle.primaryButton,
                      child: const Text('Back to log in'),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _finished = false;
                        _error = null;
                      }),
                      style: TextButton.styleFrom(
                        foregroundColor: AuthStyle.green,
                      ),
                      child: const Text('Use a different email'),
                    ),
                  ] else
                    AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Email address',
                              style: AuthStyle.serif.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
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
                                if (email.length > 254 ||
                                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch(email)) {
                                  return 'Enter a valid email address.';
                                }
                                return null;
                              },
                            ),
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
                                  : const Text('Request password reset'),
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
