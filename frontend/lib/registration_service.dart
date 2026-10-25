import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'profile_details.dart';

class RegistrationException implements Exception {
  const RegistrationException(this.message);
  final String message;
}

class RegistrationService {
  const RegistrationService();

  Future<void> validateAccount({
    required String email,
    required String confirmEmail,
    required String password,
    required String phoneNumber,
  }) => _post('/api/auth/register/validate/', {
    'email': email.trim(),
    'confirm_email': confirmEmail.trim(),
    'password': password,
    'phone_number': phoneNumber.trim(),
  }, 204);

  Future<void> register({
    required String email,
    required String confirmEmail,
    required String password,
    required String phoneNumber,
    required ProfileDetails profile,
  }) => _post('/api/auth/register/', {
    'email': email.trim(),
    'confirm_email': confirmEmail.trim(),
    'password': password,
    'phone_number': phoneNumber.trim(),
    ...profile.toJson(),
  }, 201);

  Future<void> _post(
    String path,
    Map<String, Object> data,
    int successCode,
  ) async {
    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const RegistrationException(
        'The connection timed out. Please try again.',
      );
    } on http.ClientException {
      throw const RegistrationException('Could not connect. Please try again.');
    }
    if (response.statusCode == successCode) return;
    if (response.statusCode == 429) {
      throw const RegistrationException(
        'Too many attempts. Please wait a minute and try again.',
      );
    }
    if (response.statusCode == 400) {
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          if (body['detail'] is String) {
            throw RegistrationException(body['detail'] as String);
          }
          final messages = body.values
              .whereType<List>()
              .expand((list) => list)
              .whereType<String>()
              .toList();
          if (messages.isNotEmpty) {
            throw RegistrationException(messages.join('\n'));
          }
        }
      } on FormatException {
        // Do not show server HTML or internal error details in the form.
      }
      throw const RegistrationException(
        'Please check your details and try again.',
      );
    }
    throw const RegistrationException(
      'Registration is temporarily unavailable. Please try again.',
    );
  }
}
