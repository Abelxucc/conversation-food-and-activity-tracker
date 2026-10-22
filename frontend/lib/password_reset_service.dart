import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class PasswordResetException implements Exception {
  const PasswordResetException(this.message);
  final String message;
}

class PasswordResetService {
  const PasswordResetService();

  Future<void> requestReset(String email) =>
      _post('/api/auth/password-reset/', {'email': email.trim()});

  Future<void> _post(String path, Map<String, String> data) async {
    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const PasswordResetException(
        'The connection timed out. Please try again.',
      );
    } on http.ClientException {
      throw const PasswordResetException(
        'Could not connect. Please try again.',
      );
    }
    if (response.statusCode == 202) return;
    if (response.statusCode == 429) {
      throw const PasswordResetException(
        'Too many attempts. Please wait a minute and try again.',
      );
    }
    if (response.statusCode == 400) {
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          if (body['detail'] is String) {
            throw PasswordResetException(body['detail'] as String);
          }
          final errors = body['errors'];
          if (errors is Map) {
            final messages = errors.values
                .whereType<List>()
                .expand((list) => list)
                .whereType<String>();
            if (messages.isNotEmpty) {
              throw PasswordResetException(messages.join('\n'));
            }
          }
        }
      } on FormatException {
        // A proxy or server may return HTML; keep it out of the user interface.
      }
      throw const PasswordResetException(
        'Please check your details and try again.',
      );
    }
    throw const PasswordResetException(
      'Password reset is temporarily unavailable. Please try again.',
    );
  }
}
