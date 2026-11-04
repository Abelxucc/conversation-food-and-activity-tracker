import 'package:flutter/cupertino.dart';

import '../food/food_service.dart';
import '../shared/app_navigation_scope.dart';
import '../shared/food_chrome.dart';
import '../shared/food_style.dart';
import 'activity_record.dart';

class ActivityEditor extends StatefulWidget {
  const ActivityEditor({
    super.key,
    this.initialDraft,
    this.onSave,
    this.submitLabel,
  });

  final ActivityDraft? initialDraft;
  final Future<void> Function(ActivityDraft)? onSave;
  final String? submitLabel;

  @override
  State<ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends State<ActivityEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _duration;
  late DateTime _when;
  late bool _timeSpecified;
  bool _saving = false;
  String? _error;

  static final _fieldDecoration = BoxDecoration(
    color: CupertinoColors.white,
    borderRadius: BorderRadius.circular(11),
    border: Border.all(color: const Color(0xFFDCE3D5)),
  );

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _name = TextEditingController(text: draft?.name);
    _duration = TextEditingController(text: draft?.durationMinutes?.toString());
    _when = draft?.occurredAt ?? DateTime.now();
    _timeSpecified = draft?.timeSpecified ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(CupertinoDatePickerMode mode) async {
    FocusScope.of(context).unfocus();
    final pickingDate = mode == CupertinoDatePickerMode.date;
    final now = DateTime.now();
    final maximum = DateTime(now.year, now.month, now.day, 23, 59, 59);
    var selected = pickingDate && _when.isAfter(maximum) ? maximum : _when;
    final confirmed = await FoodStyle.picker(
      context,
      title: pickingDate ? 'Date' : 'Time',
      child: CupertinoDatePicker(
        key: Key(pickingDate ? 'activity-date-picker' : 'activity-time-picker'),
        mode: mode,
        initialDateTime: selected,
        minimumYear: 1900,
        maximumDate: pickingDate ? maximum : null,
        use24hFormat: true,
        onDateTimeChanged: (value) => selected = value,
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      if (pickingDate) {
        _when = DateTime(
          selected.year,
          selected.month,
          selected.day,
          _when.hour,
          _when.minute,
        );
      } else {
        _when = DateTime(
          _when.year,
          _when.month,
          _when.day,
          selected.hour,
          selected.minute,
        );
        _timeSpecified = true;
      }
    });
  }

  Future<void> _review() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final draft = ActivityDraft(
      name: _name.text.trim(),
      durationMinutes: int.parse(_duration.text.trim()),
      occurredAt: _when,
      timeSpecified: _timeSpecified,
    );
    final save = widget.onSave;
    if (save == null) {
      Navigator.of(context).pop(draft);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppNavigationScope.whileBusy(context, () => save(draft));
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
                    title: widget.initialDraft == null
                        ? 'Add activity manually'
                        : 'Edit activity',
                    subtitle: widget.initialDraft == null
                        ? 'Enter activity details'
                        : 'Check and update your record',
                    centerTitle: true,
                    showHistory: false,
                    backEnabled: !_saving,
                  ),
                  Expanded(
                    child: Form(
                      key: _form,
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                        children: [_formCard()],
                      ),
                    ),
                  ),
                  if (!AppNavigationScope.isPresent(context) &&
                      MediaQuery.viewInsetsOf(context).bottom == 0)
                    const FoodNavigation(highlightAdd: false),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _formCard() => FoodStyle.card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Activity'),
        _textField(
          key: const Key('activity-name'),
          controller: _name,
          label: 'Activity name',
          placeholder: 'e.g. Jogging',
          validator: (value) {
            final name = value?.trim() ?? '';
            if (name.isEmpty) return 'Enter an activity name.';
            if (name.runes.length > 200) return 'Use 200 characters or fewer.';
            return null;
          },
        ),
        const SizedBox(height: 12),
        _label('Duration · minutes'),
        _textField(
          key: const Key('activity-duration'),
          controller: _duration,
          label: 'Duration in minutes',
          placeholder: 'e.g. 30',
          numeric: true,
          validator: (value) {
            final text = value?.trim() ?? '';
            final minutes = int.tryParse(text);
            if (!RegExp(r'^\d+$').hasMatch(text) ||
                minutes == null ||
                minutes < 1 ||
                minutes > 2147483647) {
              return 'Enter a valid whole number of minutes.';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _label('Date'),
        _selection(
          'activity-date',
          FoodStyle.date(_when),
          () => _pickDateTime(CupertinoDatePickerMode.date),
        ),
        const SizedBox(height: 12),
        _label('Time · optional'),
        Row(
          children: [
            Expanded(
              child: _selection(
                'activity-time',
                _timeSpecified ? FoodStyle.time(_when) : 'Not specified',
                () => _pickDateTime(CupertinoDatePickerMode.time),
              ),
            ),
            if (_timeSpecified)
              CupertinoButton(
                key: const Key('activity-clear-time'),
                padding: const EdgeInsets.all(8),
                onPressed: _saving
                    ? null
                    : () => setState(() => _timeSpecified = false),
                child: const Icon(
                  CupertinoIcons.clear_circled,
                  size: 22,
                  color: FoodStyle.forest,
                  semanticLabel: 'Clear time',
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Leave time unspecified if you don’t know it.',
          style: TextStyle(color: FoodStyle.muted, fontSize: 11),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 13,
                color: CupertinoColors.destructiveRed,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FoodStyle.secondary(
                label: 'Cancel',
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FoodStyle.primary(
                key: const Key('review-activity'),
                onPressed: _saving ? null : _review,
                child: _saving
                    ? const CupertinoActivityIndicator(
                        color: CupertinoColors.white,
                      )
                    : Text(
                        widget.submitLabel ??
                            (widget.onSave == null
                                ? 'Review record'
                                : 'Save changes'),
                        style: const TextStyle(fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _textField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required FormFieldValidator<String> validator,
    bool numeric = false,
  }) => FormField<String>(
    initialValue: controller.text,
    validator: validator,
    builder: (field) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Semantics(
            label: label,
            child: CupertinoTextField(
              key: key,
              controller: controller,
              enabled: !_saving,
              placeholder: placeholder,
              keyboardType: numeric ? TextInputType.number : TextInputType.text,
              textInputAction: numeric
                  ? TextInputAction.done
                  : TextInputAction.next,
              textCapitalization: numeric
                  ? TextCapitalization.none
                  : TextCapitalization.sentences,
              textAlignVertical: TextAlignVertical.center,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: _fieldDecoration,
              style: const TextStyle(fontSize: 14),
              onChanged: field.didChange,
            ),
          ),
        ),
        if (field.errorText case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.destructiveRed,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, color: FoodStyle.muted),
    ),
  );

  Widget _selection(String key, String value, VoidCallback onPressed) =>
      Container(
        decoration: _fieldDecoration,
        child: CupertinoButton(
          key: Key(key),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          onPressed: _saving ? null : onPressed,
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: FoodStyle.ink),
          ),
        ),
      );
}
