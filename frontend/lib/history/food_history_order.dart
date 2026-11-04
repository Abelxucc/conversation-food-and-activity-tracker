import '../activity/activity_record.dart';
import '../food/food_service.dart';

// These slots determine meal order and position snacks next to untimed meals.
const _mealSlots = {
  'breakfast': 8 * 60,
  'brunch': 10 * 60 + 30,
  'elevenses': 11 * 60,
  'lunch': 12 * 60,
  'afternoon_tea': 16 * 60,
  'dinner': 18 * 60,
  'supper': 22 * 60,
};

int _mealSlot(String mealType) => _mealSlots[mealType] ?? 24 * 60;

/// Orders one local day's meals, inserting timed snacks between them.
List<FoodRecord> sortFoodHistory(Iterable<FoodRecord> records) {
  final dailyRecords = records.toList();
  final meals =
      dailyRecords.where((record) => record.mealType != 'snack').toList()
        ..sort((a, b) {
          final byMeal = _mealSlot(a.mealType).compareTo(_mealSlot(b.mealType));
          return byMeal != 0 ? byMeal : _compareTime(a, b);
        });
  final timedSnacks =
      dailyRecords
          .where((record) => record.mealType == 'snack' && record.timeSpecified)
          .toList()
        ..sort(_compareTime);
  final untimedSnacks =
      dailyRecords
          .where(
            (record) => record.mealType == 'snack' && !record.timeSpecified,
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  final ordered = <FoodRecord>[];
  var nextSnack = 0;
  for (final meal in meals) {
    while (nextSnack < timedSnacks.length &&
        _minutes(timedSnacks[nextSnack]) < _minutes(meal)) {
      ordered.add(timedSnacks[nextSnack++]);
    }
    ordered.add(meal);
  }
  ordered.addAll(timedSnacks.skip(nextSnack));
  ordered.addAll(untimedSnacks);
  return ordered;
}

/// Adds activities to the existing meal order for a single local day.
List<Object> sortRecordHistory(
  Iterable<FoodRecord> food,
  Iterable<ActivityRecord> activity,
) {
  final activities = activity.toList()
    ..sort((a, b) {
      if (a.timeSpecified != b.timeSpecified) return a.timeSpecified ? -1 : 1;
      if (a.timeSpecified) {
        final byTime = _clockMinutes(a.occurredAt)
            .compareTo(_clockMinutes(b.occurredAt));
        if (byTime != 0) return byTime;
      }
      return a.id.compareTo(b.id);
    });

  final ordered = <Object>[];
  var next = 0;
  for (final meal in sortFoodHistory(food)) {
    while (next < activities.length &&
        activities[next].timeSpecified &&
        _clockMinutes(activities[next].occurredAt) < _minutes(meal)) {
      ordered.add(activities[next++]);
    }
    ordered.add(meal);
  }
  ordered.addAll(activities.skip(next));
  return ordered;
}

int _compareTime(FoodRecord a, FoodRecord b) {
  final byTime = _minutes(a).compareTo(_minutes(b));
  // A stable tie-breaker prevents refreshes from swapping equal-time records.
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

int _minutes(FoodRecord record) {
  if (record.timeSpecified) {
    return _clockMinutes(record.eatenAt);
  }
  return _mealSlot(record.mealType);
}

int _clockMinutes(DateTime value) => value.hour * 60 + value.minute;
