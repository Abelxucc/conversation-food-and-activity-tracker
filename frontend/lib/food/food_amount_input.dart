import 'package:flutter/cupertino.dart';

import 'food_amount.dart';
import 'food_amount_picker.dart';
import '../shared/food_style.dart';

/// Edits quantity and unit separately while keeping the draft's combined amount.
class FoodAmountInput extends StatefulWidget {
  const FoodAmountInput({
    super.key,
    required this.controller,
    required this.index,
    required this.enabled,
    required this.onChanged,
  });
  final TextEditingController controller;
  final int index;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  State<FoodAmountInput> createState() => _FoodAmountInputState();
}

class _FoodAmountInputState extends State<FoodAmountInput> {
  late final TextEditingController _quantity;
  late String _unit;

  @override
  void initState() {
    super.initState();
    final amount = FoodAmount.tryParse(widget.controller.text);
    _quantity = TextEditingController(
      text: FoodAmount.isUnspecified(widget.controller.text)
          ? ''
          : amount?.quantity ?? widget.controller.text,
    );
    _unit = amount?.unit ?? 'item';
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _update(FormFieldState<String> field) {
    final quantity = _quantity.text.trim();
    widget.controller.text = quantity.isEmpty ? '' : '$quantity $_unit';
    field.didChange(_quantity.text);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => FormField<String>(
    initialValue: _quantity.text,
    validator: (value) {
      final quantity = value?.trim() ?? '';
      if (quantity.isEmpty) return null;
      return FoodAmount.tryParse(quantity)?.quantity == quantity
          ? null
          : 'Enter a positive number, e.g. 1 or 0.5.';
    },
    builder: (field) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Quantity ${widget.index + 1}',
                child: CupertinoTextField(
                  controller: _quantity,
                  enabled: widget.enabled,
                  placeholder: 'Amount',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    color: FoodStyle.ink,
                  ),
                  placeholderStyle: const TextStyle(
                    fontSize: 12,
                    color: FoodStyle.muted,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  onChanged: (_) => _update(field),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                label: 'Choose unit ${widget.index + 1}',
                child: CupertinoButton(
                  key: Key('choose-amount-${widget.index}'),
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 12,
                  ),
                  onPressed: !widget.enabled
                      ? null
                      : () async {
                          final unit = await showFoodUnitPicker(
                            context,
                            initialUnit: _unit,
                          );
                          if (!mounted || unit == null) return;
                          setState(() {
                            _unit = unit.isEmpty ? 'item' : unit;
                            if (unit.isEmpty) _quantity.clear();
                          });
                          _update(field);
                        },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          foodUnitLabels[_unit] ?? _unit,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: FoodStyle.forest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        CupertinoIcons.chevron_down,
                        size: 11,
                        color: FoodStyle.forest,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (field.hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 5, 0, 0),
            child: Text(
              field.errorText!,
              style: const TextStyle(
                fontSize: 11,
                color: CupertinoColors.destructiveRed,
              ),
            ),
          ),
      ],
    ),
  );
}
