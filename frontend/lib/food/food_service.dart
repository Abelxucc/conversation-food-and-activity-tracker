import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../activity/activity_record.dart';
import '../shared/api_config.dart';

class FoodException implements Exception {
  const FoodException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
}

class FoodItem {
  const FoodItem({required this.name, this.quantity, this.unit = ''});
  final String name;
  final String? quantity;
  final String unit;

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    name: json['name'] as String,
    quantity: json['quantity']?.toString(),
    unit: json['unit'] as String? ?? '',
  );

  String get amount {
    if (quantity == null) return 'Amount not provided';
    final display = quantity!.contains('.')
        ? quantity!.replaceFirst(RegExp(r'\.?0+$'), '')
        : quantity!;
    return '$display $unit';
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
  };
}

class FoodDraft {
  const FoodDraft({
    required this.mealType,
    required this.eatenAt,
    required this.items,
    this.timeSpecified = true,
  });
  final String mealType;
  final DateTime eatenAt;
  final List<FoodItem> items;
  final bool timeSpecified;

  Map<String, Object?> toJson() => {
    'meal_type': mealType,
    'eaten_at':
        (timeSpecified
                ? eatenAt
                : DateTime(eatenAt.year, eatenAt.month, eatenAt.day))
            .toUtc()
            .toIso8601String(),
    'time_specified': timeSpecified,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class FoodRecord extends FoodDraft {
  const FoodRecord({
    required this.id,
    required super.mealType,
    required super.eatenAt,
    required super.items,
    super.timeSpecified,
  });
  final int id;

  factory FoodRecord.fromJson(Map<String, dynamic> json) => FoodRecord(
    id: json['id'] as int,
    mealType: json['meal_type'] as String,
    eatenAt: DateTime.parse(json['eaten_at'] as String).toLocal(),
    timeSpecified: json['time_specified'] as bool? ?? true,
    items: (json['items'] as List)
        .map((item) => FoodItem.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

typedef FoodTip = ({String title, String body, String sourceUrl});
typedef FoodWeek = ({
  DateTime start,
  DateTime end,
  int daysLogged,
  Map<String, List<String>> groups,
  FoodTip? tip,
});

class FoodService {
  const FoodService(this.token);
  final String token;

  static Future<String> signIn(String email, String password) async {
    final data = await _request(
      'POST',
      '/api/auth/login/',
      data: {'email': email.trim(), 'password': password},
    );
    return (data as Map<String, dynamic>)['token'] as String;
  }

  Future<List<FoodRecord>> list() async {
    final data = await _request('GET', '/api/food-records/', token: token);
    return (data as List)
        .map((record) => FoodRecord.fromJson(record as Map<String, dynamic>))
        .toList();
  }

  Future<FoodDraft> parseFood(String text, DateTime referenceDate) async {
    final data = await _request(
      'POST',
      '/api/food-records/parse/',
      token: token,
      data: {'text': text, 'reference_date': _dateOnly(referenceDate)},
    ) as Map<String, dynamic>;
    final time = data['time'] as String?;
    return FoodDraft(
      mealType: data['meal_type'] as String? ?? '',
      eatenAt: DateTime.parse("${data['date']}T${time ?? '00:00'}:00"),
      timeSpecified: time != null,
      items: (data['items'] as List)
          .map((item) => FoodItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<FoodWeek> week(DateTime date) async {
    final data = await _request(
      'GET',
      '/api/food-recommendations/?date=${_dateOnly(date)}',
      token: token,
    ) as Map<String, dynamic>;
    final groups = (data['groups'] as List).cast<Map<String, dynamic>>();
    final recommendation = data['recommendation'] as Map<String, dynamic>?;
    return (
      start: DateTime.parse(data['week_start'] as String),
      end: DateTime.parse(data['week_end'] as String),
      daysLogged: data['days_logged'] as int,
      groups: {
        for (final group in groups)
          group['label'] as String: (group['foods'] as List).cast<String>(),
      },
      tip: recommendation == null
          ? null
          : (
              title: recommendation['title'] as String,
              body: recommendation['body'] as String,
              sourceUrl: recommendation['source_url'] as String,
            ),
    );
  }

  static String _dateOnly(DateTime value) =>
      value.toIso8601String().split('T').first;

  Future<void> signOut() async {
    try {
      await _request('POST', '/api/auth/logout/', token: token);
    } on FoodException catch (error) {
      // An expired or already-revoked login can still be cleared locally.
      if (error.statusCode != 401) rethrow;
    }
  }

  Future<FoodRecord> save(FoodDraft draft, {int? id}) async {
    final data = await _request(
      id == null ? 'POST' : 'PUT',
      '/api/food-records/${id == null ? '' : '$id/'}',
      token: token,
      data: draft.toJson(),
    );
    return FoodRecord.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _request('DELETE', '/api/food-records/$id/', token: token);
  }

  Future<List<ActivityRecord>> listActivities() async {
    final data = await _request('GET', '/api/activity-records/', token: token);
    return (data as List)
        .map(
          (record) => ActivityRecord.fromJson(record as Map<String, dynamic>),
        )
        .toList();
  }

  Future<ActivityRecord> saveActivity(ActivityDraft draft, {int? id}) async {
    final data = await _request(
      id == null ? 'POST' : 'PUT',
      '/api/activity-records/${id == null ? '' : '$id/'}',
      token: token,
      data: draft.toJson(),
    );
    return ActivityRecord.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteActivity(int id) async {
    await _request('DELETE', '/api/activity-records/$id/', token: token);
  }

  static Future<Object?> _request(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? data,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Token $token',
      };
      final future = switch (method) {
        'GET' => http.get(uri, headers: headers),
        'POST' => http.post(uri, headers: headers, body: jsonEncode(data)),
        'PUT' => http.put(uri, headers: headers, body: jsonEncode(data)),
        'DELETE' => http.delete(uri, headers: headers),
        _ => throw ArgumentError.value(method),
      };
      final response = await future.timeout(const Duration(seconds: 15));
      if (response.statusCode == 204) return null;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
      if (response.statusCode == 401) {
        throw const FoodException(
          'Please sign out and log in again.',
          statusCode: 401,
        );
      }
      if (response.statusCode == 404) {
        throw const FoodException(
          'This record could not be found. Refresh your history.',
        );
      }
      if (response.statusCode == 429) {
        throw const FoodException(
          'Too many attempts. Please wait a minute and try again.',
        );
      }
      if (response.statusCode == 400 ||
          (response.statusCode == 503 && path == '/api/food-records/parse/')) {
        final body = jsonDecode(response.body);
        final messages = _messages(body).toList();
        throw FoodException(
          messages.isEmpty ? 'Please check your details.' : messages.join('\n'),
        );
      }
      throw const FoodException(
        'Could not save or load your record. Please try again.',
      );
    } on TimeoutException {
      throw FoodException(
        path == '/api/food-records/parse/'
            ? 'Could not read that record in time. Try again or add it manually.'
            : 'Connection timed out. Check history before saving again.',
      );
    } on http.ClientException {
      throw const FoodException(
        'Could not connect. Check that the backend is running.',
      );
    } on FormatException {
      throw const FoodException('Unexpected response. Please try again.');
    }
  }

  static Iterable<String> _messages(Object? value) sync* {
    if (value is String) {
      yield value;
    } else if (value is List) {
      for (final item in value) {
        yield* _messages(item);
      }
    } else if (value is Map) {
      for (final item in value.values) {
        yield* _messages(item);
      }
    }
  }
}
