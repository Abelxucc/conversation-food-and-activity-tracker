import 'food_service.dart';

/// Orders one local day's meals, inserting timed snacks between them.
List<FoodRecord> sortFoodHistory(Iterable<FoodRecord> records) {
  const mealOrder = {'breakfast': 0, 'lunch': 1, 'dinner': 2};
  final dailyRecords = records.toList();
  final meals =
      dailyRecords.where((record) => record.mealType != 'snack').toList()
        ..sort((a, b) {
          final byMeal = (mealOrder[a.mealType] ?? 3).compareTo(
            mealOrder[b.mealType] ?? 3,
          );
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

int _compareTime(FoodRecord a, FoodRecord b) {
  final byTime = _minutes(a).compareTo(_minutes(b));
  // A stable tie-breaker prevents refreshes from swapping equal-time records.
  return byTime != 0 ? byTime : a.id.compareTo(b.id);
}

int _minutes(FoodRecord record) {
  if (record.timeSpecified) {
    return record.eatenAt.hour * 60 + record.eatenAt.minute;
  }
  // Sorting anchors only. Do not display these as user-entered meal times.
  return switch (record.mealType) {
    'breakfast' => 8 * 60,
    'lunch' => 12 * 60,
    'dinner' => 18 * 60,
    _ => 24 * 60,
  };
}
