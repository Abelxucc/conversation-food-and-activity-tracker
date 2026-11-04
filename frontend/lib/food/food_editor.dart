import 'package:flutter/cupertino.dart';

import 'food_amount.dart';
import '../shared/app_navigation_scope.dart';
import 'food_amount_input.dart';
import '../shared/food_chrome.dart';
import 'food_service.dart';
import '../shared/food_style.dart';

class FoodEditor extends StatefulWidget {
  const FoodEditor({super.key, this.initialDraft, this.service, this.onSave});
  final FoodDraft? initialDraft;
  final FoodService? service;
  final Future<void> Function(FoodDraft)? onSave;
  @override
  State<FoodEditor> createState() => _FoodEditorState();
}

class _FoodInputs {
  _FoodInputs([FoodItem? item])
    : name = TextEditingController(text: item?.name),
      amount = TextEditingController(
        text: item?.quantity == null ? '' : item!.amount,
      );
  final TextEditingController name;
  final TextEditingController amount;
  bool get isBlank =>
      name.text.trim().isEmpty && FoodAmount.isUnspecified(amount.text);
  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _FoodEditorState extends State<FoodEditor> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _mealField = GlobalKey<FormFieldState<String>>();
  late String? _meal;
  late DateTime _eatenAt;
  late bool _timeSpecified;
  late final List<_FoodInputs> _items;
  final _removed = <_FoodInputs>[];
  bool _saving = false;
  String? _error;
  bool get _editing => widget.initialDraft != null;

  @override
  void initState() {
    super.initState();
    final meal = widget.initialDraft?.mealType;
    _meal = FoodStyle.meals.containsKey(meal) ? meal : null;
    _eatenAt = widget.initialDraft?.eatenAt ?? DateTime.now();
    _timeSpecified = widget.initialDraft?.timeSpecified ?? false;
    _items =
        widget.initialDraft?.items.map(_FoodInputs.new).toList() ??
        [_FoodInputs()];
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final item in [..._items, ..._removed]) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMeal() async {
    FocusScope.of(context).unfocus();
    final keys = FoodStyle.meals.keys.toList();
    var selected = _meal == null ? 0 : keys.indexOf(_meal!);
    final controller = FixedExtentScrollController(initialItem: selected);
    final confirmed = await FoodStyle.picker(
      context,
      title: 'Meal',
      child: CupertinoPicker(
        key: const Key('meal-picker'),
        scrollController: controller,
        itemExtent: 42,
        onSelectedItemChanged: (index) => selected = index,
        children: FoodStyle.meals.values
            .map(
              (meal) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(meal)),
                ),
              ),
            )
            .toList(),
      ),
    );
    controller.dispose();
    if (mounted && confirmed == true) {
      setState(() => _meal = keys[selected]);
      _mealField.currentState!.didChange(_meal);
    }
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final maximum = DateTime(now.year, now.month, now.day, 23, 59, 59);
    var selected = _eatenAt.isAfter(maximum) ? maximum : _eatenAt;
    final confirmed = await FoodStyle.picker(
      context,
      title: 'Date',
      child: CupertinoDatePicker(
        key: const Key('date-picker'),
        mode: CupertinoDatePickerMode.date,
        initialDateTime: selected,
        minimumYear: 1900,
        maximumDate: maximum,
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
        use24hFormat: true,
        onDateTimeChanged: (time) => selected = time,
      ),
    );
    if (mounted && confirmed == true) {
      setState(() {
        _eatenAt = DateTime(
          _eatenAt.year,
          _eatenAt.month,
          _eatenAt.day,
          selected.hour,
          selected.minute,
        );
        _timeSpecified = true;
      });
    }
  }

  void _remove(_FoodInputs item) {
    setState(() {
      _items.remove(item);
      _removed.add(item);
    });
  }

  Future<void> _review() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final draft = FoodDraft(
      mealType: _meal!,
      eatenAt: _eatenAt,
      timeSpecified: _timeSpecified,
      items: _items.where((item) => !item.isBlank).map((item) {
        final amount = FoodAmount.isUnspecified(item.amount.text)
            ? null
            : FoodAmount.tryParse(item.amount.text)!;
        return FoodItem(
          name: item.name.text.trim(),
          quantity: amount?.quantity,
          unit: amount?.unit ?? '',
        );
      }).toList(),
    );
    if (widget.onSave == null) {
      Navigator.of(context).pop(draft);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppNavigationScope.whileBusy(context, () => widget.onSave!(draft));
      if (mounted) Navigator.of(context).pop(draft);
    } on FoodException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save changes. Your edits are still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FoodStyle.theme(
    PopScope(
      canPop: !_saving,
      child: CupertinoPageScaffold(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  FoodHeader(
                    title: _editing ? 'Edit food record' : 'Add food manually',
                    centerTitle: true,
                    showHistory: false,
                    subtitle: _editing
                        ? 'Update foods, amounts, meal, date or time'
                        : 'Enter a food record without a message',
                    backEnabled: !_saving,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Form(
                      key: _form,
                      child: ListView(
                        controller: _scroll,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                        children: [
                          FoodStyle.card(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _label('Meal'),
                                const SizedBox(height: 6),
                                FormField<String>(
                                  key: _mealField,
                                  initialValue: _meal,
                                  validator: (value) =>
                                      value == null ? 'Choose a meal.' : null,
                                  builder: (field) => Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _selection(
                                        key: const Key('meal-type'),
                                        value:
                                            FoodStyle.meals[_meal] ??
                                            'Choose a meal',
                                        onTap: _pickMeal,
                                      ),
                                      if (field.hasError)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Text(
                                            field.errorText!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: CupertinoColors
                                                  .destructiveRed,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _label('Date'),
                                const SizedBox(height: 6),
                                _selection(
                                  key: const Key('food-date'),
                                  value: FoodStyle.today(_eatenAt),
                                  onTap: _pickDate,
                                ),
                                const SizedBox(height: 12),
                                _label('Time · optional'),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _selection(
                                        key: const Key('food-time'),
                                        value: _timeSpecified
                                            ? FoodStyle.time(_eatenAt)
                                            : 'Time not specified',
                                        onTap: _pickTime,
                                      ),
                                    ),
                                    if (_timeSpecified)
                                      CupertinoButton(
                                        key: const Key('clear-food-time'),
                                        padding: const EdgeInsets.all(8),
                                        onPressed: _saving
                                            ? null
                                            : () => setState(
                                                () => _timeSpecified = false,
                                              ),
                                        child: const Icon(
                                          CupertinoIcons.clear_circled,
                                          semanticLabel: 'Clear time',
                                          size: 22,
                                          color: FoodStyle.forest,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _label(
                                        _editing ? 'Food' : 'Food name',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 3,
                                      child: _label(
                                        _editing
                                            ? 'Amount'
                                            : 'Amount · optional',
                                      ),
                                    ),
                                    if (_editing) ...[
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 44,
                                        child: _label('Remove'),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                for (
                                  var index = 0;
                                  index < _items.length;
                                  index++
                                )
                                  _item(index),
                                CupertinoButton(
                                  key: const Key('add-food-item'),
                                  color: FoodStyle.pale,
                                  borderRadius: BorderRadius.circular(11),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  onPressed: _items.length >= 50 || _saving
                                      ? null
                                      : () => setState(
                                          () => _items.add(_FoodInputs()),
                                        ),
                                  child: const Text(
                                    '+ Add food item',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: FoodStyle.forest,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _missingAmounts,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.4,
                                    color: FoodStyle.muted,
                                  ),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 10),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _error!,
                                      key: const Key('edit-save-error'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: CupertinoColors.destructiveRed,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CupertinoButton(
                                        color: FoodStyle.pale,
                                        borderRadius: BorderRadius.circular(11),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        onPressed: _saving
                                            ? null
                                            : () =>
                                                  Navigator.of(context)
                                                      .maybePop(),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: FoodStyle.forest,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: FoodStyle.primary(
                                        key: const Key('review-record'),
                                        onPressed: _saving ? null : _review,
                                        child: _saving
                                            ? const CupertinoActivityIndicator(
                                                color: CupertinoColors.white,
                                              )
                                            : Text(
                                                _editing
                                                    ? 'Save changes'
                                                    : _hasName
                                                    ? 'Review record'
                                                    : 'Continue',
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
                      alignment: Alignment.centerRight,
                      color: CupertinoColors.systemGrey6,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 10,
                        ),
                        onPressed: () => FocusScope.of(context).unfocus(),
                        child: const Text('Done'),
                      ),
                    )
                  else if (!AppNavigationScope.isPresent(context))
                    const FoodNavigation(highlightAdd: false),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  bool get _hasName => _items.any((item) => item.name.text.trim().isNotEmpty);
  String get _missingAmounts {
    const hint =
        'Enter a quantity and tap the unit to choose it.\n'
        'Amounts are optional. Empty extra rows are ignored.';
    if (!_editing) return hint;
    final names = _items
        .where(
          (item) =>
              item.name.text.trim().isNotEmpty &&
              FoodAmount.isUnspecified(item.amount.text),
        )
        .map((item) => item.name.text.trim())
        .toList();
    return names.isEmpty
        ? hint
        : '${names.join(' & ')}: amounts not provided.\n$hint';
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontSize: 11, color: FoodStyle.muted));

  Widget _selection({
    required Key key,
    required String value,
    required VoidCallback onTap,
  }) => Container(
    decoration: BoxDecoration(
      color: CupertinoColors.white,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFDCE3D5)),
    ),
    child: CupertinoButton(
      key: key,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      onPressed: _saving ? null : onTap,
      child: Text(
        value,
        style: const TextStyle(fontSize: 14, color: FoodStyle.ink),
      ),
    ),
  );

  Widget _item(int index) {
    final item = _items[index];
    const decoration = BoxDecoration(
      color: CupertinoColors.white,
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    Widget field({
      required String id,
      required String label,
      required String placeholder,
      required TextEditingController controller,
      required FormFieldValidator<String> validator,
      int? maxLength,
    }) => FormField<String>(
      key: Key('$id-$index'),
      initialValue: controller.text,
      validator: validator,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: label,
            child: CupertinoTextField(
              controller: controller,
              enabled: !_saving,
              placeholder: placeholder,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: decoration,
              style: const TextStyle(
                fontSize: 13,
                height: 1.25,
                color: FoodStyle.ink,
              ),
              maxLength: maxLength,
              placeholderStyle: const TextStyle(
                fontSize: 12,
                color: FoodStyle.muted,
              ),
              textInputAction: TextInputAction.done,
              textCapitalization: id == 'food-name'
                  ? TextCapitalization.sentences
                  : TextCapitalization.none,
              autocorrect: id == 'food-name',
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              onChanged: (value) {
                field.didChange(value);
                setState(() {});
              },
            ),
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 5, 0, 0),
              child: Text(
                field.errorText!,
                style: const TextStyle(
                  color: CupertinoColors.destructiveRed,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: field(
              id: 'food-name',
              label: 'Food name ${index + 1}',
              placeholder: 'Enter food name',
              controller: item.name,
              maxLength: 200,
              validator: (text) =>
                  (text == null || text.trim().isEmpty) &&
                      (!item.isBlank || !_hasName)
                  ? 'Enter a food name.'
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: FoodAmountInput(
              key: Key('food-amount-$index'),
              controller: item.amount,
              index: index,
              enabled: !_saving,
              onChanged: () => setState(() {}),
            ),
          ),
          if (_editing) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: CupertinoButton(
                key: Key('remove-food-$index'),
                padding: EdgeInsets.zero,
                onPressed: _items.length == 1 || _saving
                    ? null
                    : () => _remove(item),
                child: Icon(
                  CupertinoIcons.minus,
                  size: 16,
                  semanticLabel:
                      'Remove ${item.name.text.isEmpty ? 'food ${index + 1}' : item.name.text}',
                  color: _items.length == 1
                      ? CupertinoColors.tertiaryLabel
                      : FoodStyle.forest,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    if (_editing || _items.length == 1) {
      return KeyedSubtree(key: ObjectKey(item), child: row);
    }
    return Dismissible(
      key: ObjectKey(item),
      direction: _saving ? DismissDirection.none : DismissDirection.endToStart,
      onDismissed: (_) => _remove(item),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: CupertinoColors.destructiveRed,
        child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
      ),
      child: row,
    );
  }
}
