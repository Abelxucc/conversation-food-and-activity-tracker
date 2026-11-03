import 'package:flutter_test/flutter_test.dart';
import 'package:tracktalk/food_history_order.dart';
import 'package:tracktalk/food_service.dart';

FoodRecord record(
  int id,
  String meal,
  int hour, [
  int minute = 0,
  bool specified = true,
]) => FoodRecord(
  id: id,
  mealType: meal,
  eatenAt: DateTime(2026, 10, 31, hour, minute),
  timeSpecified: specified,
  items: const [FoodItem(name: 'Food')],
);

List<int> ids(Iterable<FoodRecord> records) =>
    sortFoodHistory(records).map((record) => record.id).toList();

void main() {
  test('breakfast, 10am snack, lunch and dinner ignore insertion order', () {
    final input = [
      record(1, 'dinner', 19),
      record(5, 'lunch', 12),
      record(9, 'snack', 10),
      record(12, 'breakfast', 8),
    ];
    expect(ids(input), [12, 9, 5, 1]);
    expect(input.map((record) => record.id), [1, 5, 9, 12]);
    expect(ids(input.reversed), [12, 9, 5, 1]);
  });

  test('main meals keep meal order even when logged at conflicting times', () {
    expect(
      ids([
        record(1, 'dinner', 10),
        record(2, 'lunch', 20),
        record(3, 'breakfast', 23),
      ]),
      [3, 2, 1],
    );
  });

  test(
    'snacks can precede breakfast, occur between meals or follow dinner',
    () {
      expect(
        ids([
          record(1, 'dinner', 19),
          record(2, 'snack', 21),
          record(3, 'lunch', 12),
          record(4, 'snack', 15),
          record(5, 'breakfast', 8),
          record(6, 'snack', 6),
          record(7, 'snack', 10),
        ]),
        [6, 5, 7, 3, 4, 1, 2],
      );
    },
  );

  test(
    'snacks use chosen meal times rather than fixed mealtime boundaries',
    () {
      expect(
        ids([
          record(1, 'lunch', 14),
          record(2, 'breakfast', 9, 30),
          record(3, 'snack', 13),
          record(4, 'snack', 9),
        ]),
        [4, 2, 3, 1],
      );
    },
  );

  test(
    'untimed meals have meal slots and untimed snacks always finish last',
    () {
      expect(
        ids([
          record(1, 'snack', 0, 0, false),
          record(2, 'dinner', 1, 0, false),
          record(3, 'snack', 22),
          record(4, 'lunch', 23, 0, false),
          record(5, 'snack', 10),
          record(6, 'breakfast', 21, 0, false),
          record(7, 'snack', 15),
        ]),
        [6, 5, 4, 7, 2, 3, 1],
      );
    },
  );

  test(
    'an explicit midnight snack is timed and equal-time snacks follow meals',
    () {
      expect(
        ids([
          record(1, 'snack', 0, 0, false),
          record(2, 'snack', 8),
          record(3, 'breakfast', 8),
          record(4, 'snack', 0),
        ]),
        [4, 3, 2, 1],
      );
    },
  );

  test('new meal slots place timed and untimed snacks in order', () {
    expect(
      ids([
        record(1, 'snack', 0, 0, false),
        record(2, 'supper', 1, 0, false),
        record(3, 'snack', 21),
        record(4, 'dinner', 23, 0, false),
        record(5, 'afternoon_tea', 0, 0, false),
        record(6, 'snack', 14),
        record(7, 'lunch', 2, 0, false),
        record(8, 'elevenses', 3, 0, false),
        record(9, 'snack', 10, 45),
        record(10, 'brunch', 2, 0, false),
        record(11, 'breakfast', 2, 0, false),
        record(12, 'snack', 22, 30),
      ]),
      [11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 12, 1],
    );
  });

  test(
    'repeated meals allow intervening snacks and ties stay deterministic',
    () {
      expect(
        ids([
          record(7, 'breakfast', 9),
          record(3, 'snack', 8, 30),
          record(6, 'breakfast', 8),
          record(2, 'breakfast', 8),
          record(9, 'snack', 8, 30),
        ]),
        [2, 6, 3, 9, 7],
      );
      expect(ids([record(9, 'snack', 10), record(3, 'snack', 10)]), [3, 9]);
      expect(ids([]), isEmpty);
    },
  );

  test(
    'the time flag survives JSON and date-only records do not invent a time',
    () {
      final dateOnly = record(1, 'snack', 23, 45, false);
      final json = dateOnly.toJson();
      final saved = FoodRecord.fromJson({'id': 1, ...json});
      expect(json['time_specified'], false);
      expect(saved.timeSpecified, false);
      expect(saved.eatenAt, DateTime(2026, 10, 31));
      final midnight = record(2, 'snack', 0);
      expect(
        FoodRecord.fromJson({'id': 2, ...midnight.toJson()}).timeSpecified,
        true,
      );
      final legacy = {...midnight.toJson()}..remove('time_specified');
      expect(FoodRecord.fromJson({'id': 2, ...legacy}).timeSpecified, true);
    },
  );
}
