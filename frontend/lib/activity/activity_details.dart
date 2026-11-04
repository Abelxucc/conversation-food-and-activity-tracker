import 'package:flutter/cupertino.dart';

import '../shared/food_style.dart';
import 'activity_record.dart';

class ActivityDetails extends StatelessWidget {
  const ActivityDetails({
    super.key,
    required this.record,
    this.showName = true,
  });

  final ActivityDraft record;
  final bool showName;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _row(showName ? record.name : 'Duration', record.durationLabel),
      _row('Date', FoodStyle.date(record.occurredAt)),
      _row(
        'Time',
        record.timeSpecified
            ? FoodStyle.time(record.occurredAt)
            : 'Not specified',
      ),
    ],
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, color: FoodStyle.muted),
          ),
        ),
      ],
    ),
  );
}
