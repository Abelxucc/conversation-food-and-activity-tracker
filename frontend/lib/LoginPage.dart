// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_style.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _green = AuthStyle.green;
  static const _background = AuthStyle.background;
  static const _serif = AuthStyle.serif;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      TextInput.finishAutofillContext(shouldSave: false);
      FocusScope.of(context).unfocus();
      _comingSoon('Sign in');
    }
  }

  InputDecoration _decoration(String hint, {Widget? suffixIcon}) =>
      AuthStyle.inputDecoration(hint, suffixIcon: suffixIcon);

  @override
  Widget build(BuildContext context) {
    final labelStyle = _serif.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/images/Logo2.png',
                          width: 320,
                          height: 230,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 36,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.4,
                          color: Color(0xFF080C08),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A little Logging. A big tracking',
                        textAlign: TextAlign.center,
                        style: _serif.copyWith(
                          fontSize: 18,
                          color: const Color(0xFF858782),
                        ),
                      ),
                      const SizedBox(height: 34),
                      Text('Email address', style: labelStyle),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('login-email'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: _decoration('your@example.com'),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Enter your email address.';
                          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(email)) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Text('Password', style: labelStyle),
                      const SizedBox(height: 10),
                      TextFormField(
                        key: const Key('login-password'),
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        autocorrect: false,
                        enableSuggestions: false,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: _decoration(
                          'Enter your password',
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 21,
                              color: const Color(0xFF353A35),
                            ),
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter your password.'
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pushNamed(
                            '/reset-password',
                            arguments: _emailController.text.trim(),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: _green,
                            textStyle: _serif.copyWith(fontSize: 15),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: _serif.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Log in'),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(
                              color: Color(0xFF202520),
                              thickness: 1.5,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Text(
                              'OR',
                              style: _serif.copyWith(
                                color: _green,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(
                              color: Color(0xFF202520),
                              thickness: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      OutlinedButton(
                        onPressed: () => _comingSoon('Google sign in'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF222522),
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: Color(0xFFD5D5D5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _GoogleMark(),
                            SizedBox(width: 16),
                            Flexible(
                              child: Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'New to this APP?',
                            style: _serif.copyWith(
                              color: const Color(0xFF858782),
                              fontSize: 18,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _comingSoon('Sign up'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF080C08),
                              textStyle: _serif.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('Sign up here!'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => const SweepGradient(
          colors: [
            Color(0xFF4285F4),
            Color(0xFF34A853),
            Color(0xFFFBBC05),
            Color(0xFFEA4335),
            Color(0xFF4285F4),
          ],
          stops: [0, 0.25, 0.5, 0.75, 1],
        ).createShader(bounds),
        child: const Text(
          'G',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}
