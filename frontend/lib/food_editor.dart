import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'food_chrome.dart';
import 'food_service.dart';
import 'food_style.dart';

class FoodEditor extends StatefulWidget {
  const FoodEditor({super.key, this.initialDraft});
  final FoodDraft? initialDraft;
  @override
  State<FoodEditor> createState() => _FoodEditorState();
}

class _FoodInputs {
  _FoodInputs([FoodItem? item])
    : name = TextEditingController(text: item?.name),
      quantity = TextEditingController(text: item?.quantity),
      unit = TextEditingController(text: item?.unit);
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unit;
  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
  }
}

class _FoodEditorState extends State<FoodEditor> {
  final _form = GlobalKey<FormState>();
  late String _meal;
  late DateTime _eatenAt;
  late final List<_FoodInputs> _items;
  final _removed = <_FoodInputs>[];

  @override
  void initState() {
    super.initState();
    _meal = widget.initialDraft?.mealType ?? 'breakfast';
    _eatenAt = widget.initialDraft?.eatenAt ?? DateTime.now();
    _items =
        widget.initialDraft?.items.map(_FoodInputs.new).toList() ??
        [_FoodInputs()];
  }

  @override
  void dispose() {
    for (final item in [..._items, ..._removed]) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMeal() async {
    FocusScope.of(context).unfocus();
    final keys = FoodStyle.meals.keys.toList();
    var selected = keys.indexOf(_meal);
    final controller = FixedExtentScrollController(initialItem: selected);
    final confirmed = await FoodStyle.picker(
      context,
      title: 'Meal',
      child: CupertinoPicker(
        key: const Key('meal-picker'),
        scrollController: controller,
        itemExtent: 42,
        useMagnifier: true,
        magnification: 1.07,
        onSelectedItemChanged: (index) {
          selected = index;
          HapticFeedback.selectionClick();
        },
        children: FoodStyle.meals.values
            .map((meal) => Center(child: Text(meal)))
            .toList(),
      ),
    );
    controller.dispose();
    if (mounted && confirmed == true) setState(() => _meal = keys[selected]);
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final lastDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final initialDate = _eatenAt.isAfter(lastDate) ? lastDate : _eatenAt;
    var selected = initialDate;
    final confirmed = await FoodStyle.picker(
      context,
      title: 'Date',
      child: CupertinoDatePicker(
        key: const Key('date-picker'),
        mode: CupertinoDatePickerMode.date,
        initialDateTime: initialDate,
        minimumYear: 1900,
        maximumDate: lastDate,
        onDateTimeChanged: (date) => selected = date,
      ),
    );
    if (mounted && confirmed == true) {
      setState(
        () => _eatenAt = DateTime(
          selected.year,
          selected.month,
          selected.day,
          _eatenAt.hour,
          _eatenAt.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    FocusScope.of(context).unfocus();
    var selected = _eatenAt;
    final confirmed = await FoodStyle.picker(
      context,
      title: 'Time',
      child: CupertinoDatePicker(
        key: const Key('time-picker'),
        mode: CupertinoDatePickerMode.time,
        initialDateTime: _eatenAt,
        use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        onDateTimeChanged: (date) => selected = date,
      ),
    );
    if (mounted && confirmed == true) {
      setState(
        () => _eatenAt = DateTime(
          _eatenAt.year,
          _eatenAt.month,
          _eatenAt.day,
          selected.hour,
          selected.minute,
        ),
      );
    }
  }

  void _review() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      FoodDraft(
        mealType: _meal,
        eatenAt: _eatenAt,
        items: _items
            .map(
              (item) => FoodItem(
                name: item.name.text.trim(),
                quantity: item.quantity.text.trim().isEmpty
                    ? null
                    : item.quantity.text.trim(),
                unit: item.unit.text.trim(),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FoodStyle.theme(
    CupertinoPageScaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                const FoodHeader(showHistory: false),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: FoodModeSelector(),
                ),
                Expanded(
                  child: Form(
                    key: _form,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                      children: [
                        Text(
                          'Edit your ${FoodStyle.meals[_meal]!.toLowerCase()} record',
                          style: const TextStyle(
                            fontSize: 14,
                            color: FoodStyle.forest,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FoodStyle.card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      FoodStyle.meals[_meal]!,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  Text(
                                    FoodStyle.recordDate(_eatenAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: FoodStyle.muted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _selection(
                                      key: const Key('meal-type'),
                                      title: 'Meal',
                                      value: FoodStyle.meals[_meal]!,
                                      onTap: _pickMeal,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _selection(
                                      key: const Key('food-date'),
                                      title: 'Date',
                                      value: FoodStyle.date(_eatenAt),
                                      onTap: _pickDate,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _selection(
                                key: const Key('food-time'),
                                title: 'Time',
                                value: FoodStyle.time(_eatenAt),
                                onTap: _pickTime,
                              ),
                              const SizedBox(height: 16),
                              for (
                                var index = 0;
                                index < _items.length;
                                index++
                              )
                                _item(index),
                              CupertinoButton(
                                key: const Key('add-food-item'),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                onPressed: _items.length >= 50
                                    ? null
                                    : () => setState(
                                        () => _items.add(_FoodInputs()),
                                      ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.plus,
                                      size: 18,
                                      color: FoodStyle.forest,
                                    ),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Add another food',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: FoodStyle.forest,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Add missing amounts if you know them.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: FoodStyle.muted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: CupertinoButton(
                                      color: FoodStyle.pale,
                                      borderRadius: BorderRadius.circular(10),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: FoodStyle.forest,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: FoodStyle.primary(
                                      key: const Key('review-record'),
                                      onPressed: _review,
                                      child: Text(
                                        widget.initialDraft == null
                                            ? 'Review record'
                                            : 'Save changes',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (MediaQuery.viewInsetsOf(context).bottom > 0)
                  Container(
                    decoration: const BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      border: Border(
                        top: BorderSide(
                          color: CupertinoColors.separator,
                          width: .5,
                        ),
                      ),
                    ),
                    alignment: Alignment.centerRight,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      onPressed: () => FocusScope.of(context).unfocus(),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                else
                  const FoodNavigation(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _selection({
    required Key key,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) => Semantics(
    label: title,
    button: true,
    child: CupertinoButton(
      key: key,
      color: FoodStyle.pale,
      borderRadius: BorderRadius.circular(10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: FoodStyle.forest),
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_down,
            size: 10,
            color: FoodStyle.forest,
          ),
        ],
      ),
    ),
  );

  Widget _item(int index) {
    final item = _items[index];
    const fieldDecoration = BoxDecoration(
      color: CupertinoColors.white,
      borderRadius: BorderRadius.all(Radius.circular(10)),
      border: Border.fromBorderSide(BorderSide(color: Color(0xFFDCE3D5))),
    );
    Widget field({
      required Key key,
      required TextEditingController controller,
      required String placeholder,
      required String label,
      required FormFieldValidator<String> validator,
      TextInputType? keyboardType,
      int? maxLength,
    }) => Semantics(
      label: label,
      child: CupertinoTextFormFieldRow(
        key: key,
        controller: controller,
        placeholder: placeholder,
        padding: EdgeInsets.zero,
        decoration: fieldDecoration,
        style: const TextStyle(fontSize: 14, color: FoodStyle.ink),
        textCapitalization: keyboardType == null
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        textInputAction: TextInputAction.done,
        keyboardType: keyboardType,
        maxLength: maxLength,
        onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
        validator: validator,
      ),
    );
    return Padding(
      key: ObjectKey(item),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Food ${index + 1}',
                  style: const TextStyle(fontSize: 11, color: FoodStyle.muted),
                ),
              ),
              if (_items.length > 1)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() {
                    _removed.add(_items.removeAt(index));
                  }),
                  child: Text(
                    'Remove',
                    semanticsLabel: 'Remove food ${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.destructiveRed,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          field(
            key: Key('food-name-$index'),
            controller: item.name,
            label: 'Food name',
            placeholder: 'Food name',
            maxLength: 200,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a food name.'
                : null,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: field(
                  key: Key('food-quantity-$index'),
                  controller: item.quantity,
                  label: 'Quantity',
                  placeholder: 'Quantity',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (input) {
                    final value = input?.trim() ?? '';
                    if (value.isEmpty) {
                      return item.unit.text.trim().isEmpty
                          ? null
                          : 'Enter quantity.';
                    }
                    if (!RegExp(r'^\d{1,6}(\.\d{1,2})?$').hasMatch(value) ||
                        (double.tryParse(value) ?? 0) <= 0) {
                      return 'Use a positive number\n(up to 2 decimals).';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: field(
                  key: Key('food-unit-$index'),
                  controller: item.unit,
                  label: 'Unit',
                  placeholder: 'Unit',
                  maxLength: 30,
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) &&
                          item.quantity.text.trim().isNotEmpty
                      ? 'Enter a unit.'
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
