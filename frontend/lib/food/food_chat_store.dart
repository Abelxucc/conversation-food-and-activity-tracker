import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../activity/activity_record.dart';
import '../shared/api_config.dart';
import 'food_service.dart';

typedef FoodChatTurn = RecordChatTurn<FoodRecord>;
typedef ActivityChatTurn = RecordChatTurn<ActivityRecord>;

class RecordChatTurn<T> {
  RecordChatTurn(this.message, this.sentAt, {this.saved});

  final String message;
  final DateTime sentAt;
  T? saved;
}

class FoodChatStore {
  FoodChatStore(this._preferences, String email)
    : _key = 'food-chat:${ApiConfig.baseUrl}:${email.trim().toLowerCase()}';

  final SharedPreferences _preferences;
  final String _key;

  ({
    bool showExample,
    bool showActivityExample,
    List<FoodChatTurn> turns,
    List<ActivityChatTurn> activityTurns,
  })?
  read(DateTime day) {
    final data = _preferences.getString(_key);
    if (data == null) return null;
    final saved = jsonDecode(data) as Map<String, dynamic>;
    if (saved['day'] != _dateKey(day)) return null;
    return (
      showExample: saved['show_example'] as bool,
      showActivityExample: saved['show_activity_example'] as bool? ?? true,
      turns: [
        for (final item
            in (saved['turns'] as List).cast<Map<String, dynamic>>())
          FoodChatTurn(
            item['message'] as String,
            DateTime.parse(item['sent_at'] as String).toLocal(),
            saved: FoodRecord.fromJson(item['record'] as Map<String, dynamic>),
          ),
      ],
      activityTurns: [
        for (final item
            in (saved['activity_turns'] as List? ?? [])
                .cast<Map<String, dynamic>>())
          ActivityChatTurn(
            item['message'] as String,
            DateTime.parse(item['sent_at'] as String).toLocal(),
            saved: ActivityRecord.fromJson(
              item['record'] as Map<String, dynamic>,
            ),
          ),
      ],
    );
  }

  Future<void> save(
    DateTime day, {
    required bool showExample,
    required List<FoodChatTurn> turns,
    required bool showActivityExample,
    required List<ActivityChatTurn> activityTurns,
  }) async {
    final data = jsonEncode({
      'day': _dateKey(day),
      'show_example': showExample,
      'show_activity_example': showActivityExample,
      'turns': [
        for (final turn in turns)
          if (turn.saved case final record?)
            {
              'message': turn.message,
              'sent_at': turn.sentAt.toUtc().toIso8601String(),
              'record': {...record.toJson(), 'id': record.id},
            },
      ],
      'activity_turns': [
        for (final turn in activityTurns)
          if (turn.saved case final record?)
            {
              'message': turn.message,
              'sent_at': turn.sentAt.toUtc().toIso8601String(),
              'record': {...record.toJson(), 'id': record.id},
            },
      ],
    });
    try {
      await _preferences.setString(_key, data);
    } catch (error) {
      debugPrint('Could not store the Food chat session: ${error.runtimeType}');
    }
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';
}
