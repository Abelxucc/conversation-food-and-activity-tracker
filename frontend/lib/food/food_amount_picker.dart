import 'package:flutter/cupertino.dart';

import '../shared/food_style.dart';

const foodUnitLabels = {
  'item': 'Item(s)',
  'bowl': 'Bowl',
  'cup': 'Cup',
  'slice': 'Slice',
  'portion': 'Portion',
  'g': 'g',
  'ml': 'ml',
};

Future<String?> showFoodUnitPicker(
  BuildContext context, {
  required String initialUnit,
}) {
  FocusScope.of(context).unfocus();
  return showCupertinoModalPopup<String>(
    context: context,
    builder: (_) => _FoodUnitPicker(initialUnit: initialUnit),
  );
}

class _FoodUnitPicker extends StatefulWidget {
  const _FoodUnitPicker({required this.initialUnit});
  final String initialUnit;

  @override
  State<_FoodUnitPicker> createState() => _FoodUnitPickerState();
}

class _FoodUnitPickerState extends State<_FoodUnitPicker> {
  late final Map<String, String> _units;
  late final FixedExtentScrollController _controller;
  late int _selected;

  @override
  void initState() {
    super.initState();
    _units = {
      ...foodUnitLabels,
      if (!foodUnitLabels.containsKey(widget.initialUnit))
        widget.initialUnit: widget.initialUnit,
    };
    _selected = _units.keys.toList().indexOf(widget.initialUnit);
    _controller = FixedExtentScrollController(initialItem: _selected);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FoodStyle.theme(
    Container(
      height: (344 + MediaQuery.paddingOf(context).bottom).clamp(
        0.0,
        MediaQuery.sizeOf(context).height,
      ),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemGroupedBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    key: const Key('amount-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Expanded(
                    child: Text(
                      'Unit',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    key: const Key('amount-done'),
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(_units.keys.elementAt(_selected)),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(color: CupertinoColors.separator),
              child: SizedBox(height: .5, width: double.infinity),
            ),
            Expanded(
              child: Semantics(
                label: 'Unit',
                child: CupertinoPicker(
                  key: const Key('amount-unit-picker'),
                  scrollController: _controller,
                  itemExtent: 36,
                  onSelectedItemChanged: (index) => _selected = index,
                  children: [
                    for (final label in _units.values)
                      Center(child: Text(label)),
                  ],
                ),
              ),
            ),
            CupertinoButton(
              key: const Key('amount-unspecified'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text(
                'Leave amount unspecified',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
