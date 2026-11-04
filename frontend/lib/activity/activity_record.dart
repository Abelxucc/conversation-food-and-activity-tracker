class ActivityDraft {
  const ActivityDraft({
    required this.name,
    required this.durationMinutes,
    required this.occurredAt,
    this.timeSpecified = false,
  });

  final String name;
  final int durationMinutes;
  final DateTime occurredAt;
  final bool timeSpecified;

  String get durationLabel =>
      '$durationMinutes ${durationMinutes == 1 ? 'minute' : 'minutes'}';

  Map<String, Object?> toJson() => {
    'name': name,
    'duration_minutes': durationMinutes,
    'occurred_at':
        (timeSpecified
                ? occurredAt
                : DateTime(occurredAt.year, occurredAt.month, occurredAt.day))
            .toUtc()
            .toIso8601String(),
    'time_specified': timeSpecified,
  };
}

class ActivityRecord extends ActivityDraft {
  const ActivityRecord({
    required this.id,
    required super.name,
    required super.durationMinutes,
    required super.occurredAt,
    super.timeSpecified,
  });

  final int id;

  factory ActivityRecord.fromJson(Map<String, dynamic> json) => ActivityRecord(
    id: json['id'] as int,
    name: json['name'] as String,
    durationMinutes: json['duration_minutes'] as int,
    occurredAt: DateTime.parse(json['occurred_at'] as String).toLocal(),
    timeSpecified: json['time_specified'] as bool,
  );
}
