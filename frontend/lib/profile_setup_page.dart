import 'package:flutter/material.dart';

import 'GenderPage.dart';
import 'auth_style.dart';
import 'profile_details.dart';
import 'profile_step_layout.dart';
import 'registration_service.dart';

class ProfileSetupDraft {
  ProfileGender? gender;
  String height = '';
  String weight = '';
  String age = '';
  String feet = '';
  String inches = '';
  String pounds = '';
  bool heightInFeet = false;
  bool weightInPounds = false;
}

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({
    super.key,
    required this.draft,
    required this.onSubmit,
  });
  final ProfileSetupDraft draft;
  final Future<void> Function(ProfileDetails) onSubmit;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  static const _kgPerPound = 0.45359237;
  final _formKeys = List.generate(3, (_) => GlobalKey<FormState>());
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _age;
  late final TextEditingController _feet;
  late final TextEditingController _inches;
  late final TextEditingController _pounds;
  int _step = 1;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _height = TextEditingController(text: widget.draft.height);
    _weight = TextEditingController(text: widget.draft.weight);
    _age = TextEditingController(text: widget.draft.age);
    _feet = TextEditingController(text: widget.draft.feet);
    _inches = TextEditingController(text: widget.draft.inches);
    _pounds = TextEditingController(text: widget.draft.pounds);
  }

  @override
  void dispose() {
    for (final controller in [
      _height,
      _weight,
      _age,
      _feet,
      _inches,
      _pounds,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String value) {
    final number = double.tryParse(value.trim().replaceAll(',', '.'));
    return number != null && number.isFinite ? number : null;
  }

  String _format(double value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  void _updateFeetFromCm() {
    final cm = _number(_height.text);
    if (cm == null || cm <= 0) {
      _feet.clear();
      _inches.clear();
    } else {
      final totalInches = cm / 2.54;
      var feet = (totalInches / 12).floor();
      var inches = double.parse((totalInches - feet * 12).toStringAsFixed(2));
      if (inches >= 12) {
        feet++;
        inches = 0;
      }
      _feet.text = '$feet';
      _inches.text = _format(inches);
    }
    widget.draft.feet = _feet.text;
    widget.draft.inches = _inches.text;
  }

  void _updateCmFromFeet() {
    widget.draft.feet = _feet.text;
    widget.draft.inches = _inches.text;
    final feet = _number(_feet.text);
    final inches = _number(_inches.text);
    _height.text =
        feet == null || inches == null || feet < 0 || inches < 0 || inches >= 12
        ? ''
        : _format((feet * 12 + inches) * 2.54);
    widget.draft.height = _height.text;
  }

  void _setHeightUnit(bool useFeet) {
    if (useFeet == widget.draft.heightInFeet) return;
    FocusScope.of(context).unfocus();
    if (useFeet) _updateFeetFromCm();
    setState(() => widget.draft.heightInFeet = useFeet);
  }

  void _setWeightUnit(bool usePounds) {
    if (usePounds == widget.draft.weightInPounds) return;
    FocusScope.of(context).unfocus();
    if (usePounds) {
      final kg = _number(_weight.text);
      _pounds.text = kg == null ? '' : _format(kg / _kgPerPound);
      widget.draft.pounds = _pounds.text;
    }
    setState(() => widget.draft.weightInPounds = usePounds);
  }

  void _back() {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    if (_step == 1) {
      Navigator.of(context).pop(false);
    } else {
      setState(() {
        _step--;
        _error = null;
      });
    }
  }

  Future<void> _next() async {
    if (_busy || !_formKeys[_step - 2].currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (_step < 4) {
      setState(() => _step++);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        ProfileDetails(
          gender: widget.draft.gender!,
          heightCm: _height.text.trim().replaceAll(',', '.'),
          weightKg: _weight.text.trim().replaceAll(',', '.'),
          age: int.parse(_age.text.trim()),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on RegistrationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validateNumber(
    String? input,
    String label,
    num minimum,
    num maximum, {
    bool wholeNumber = false,
  }) {
    final value = input?.trim().replaceAll(',', '.') ?? '';
    final pattern = wholeNumber ? r'^\d{1,3}$' : r'^\d{1,4}(\.\d{1,2})?$';
    final number = _number(value);
    if (!RegExp(pattern).hasMatch(value) ||
        number == null ||
        number < minimum ||
        number > maximum) {
      return 'Enter $label between $minimum and $maximum${wholeNumber ? ' (whole numbers)' : ''}.';
    }
    return null;
  }

  String? _validateInches(String? value) {
    final error = _validateNumber(value, 'inches', 0, 11.99);
    if (error != null) return error;
    return _validateNumber(_height.text, 'height in cm', 30, 300);
  }

  String? _validatePounds(String? value) {
    final error = _validateNumber(value, 'weight in lb', 0.01, 1102.32);
    if (error != null) return error;
    return _validateNumber(_weight.text, 'weight in kg', 1, 500);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: _step == 1 && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _back();
      },
      child: _step == 1
          ? GenderPage(
              initialGender: widget.draft.gender,
              onChanged: (gender) => widget.draft.gender = gender,
              onContinue: () => setState(() => _step = 2),
              onBack: _back,
            )
          : _numberPage(),
    );
  }

  InputDecoration _decoration(String hint, {String? unit}) {
    return AuthStyle.inputDecoration(hint).copyWith(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      suffixIconConstraints: const BoxConstraints(
        minHeight: 40,
        minWidth: 64,
        maxWidth: 76,
      ),
      suffixIcon: unit == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 1,
                    height: 21,
                    color: const Color(0xFF525852),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF222522),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field({
    required String id,
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    required ValueChanged<String> onChanged,
    String? unit,
    bool wholeNumber = false,
    bool nextFocus = false,
  }) {
    return TextFormField(
      key: Key('profile-$id'),
      controller: controller,
      enabled: !_busy,
      style: const TextStyle(fontSize: 16),
      keyboardType: TextInputType.numberWithOptions(decimal: !wholeNumber),
      textInputAction: nextFocus ? TextInputAction.next : TextInputAction.done,
      decoration: _decoration(hint, unit: unit),
      onChanged: onChanged,
      validator: validator,
      onFieldSubmitted: (_) {
        if (nextFocus) {
          FocusScope.of(context).nextFocus();
        } else {
          _next();
        }
      },
    );
  }

  Widget _unitSwitch(
    List<String> labels,
    int selected,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      children: List.generate(
        labels.length,
        (index) => Expanded(
          child: Semantics(
            label: labels[index],
            checked: selected == index,
            inMutuallyExclusiveGroup: true,
            onTap: _busy ? null : () => onChanged(index),
            child: ExcludeSemantics(
              child: Material(
                color: selected == index ? AuthStyle.green : Colors.white,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: Key('unit-${labels[index]}'),
                  onTap: _busy ? null : () => onChanged(index),
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            labels[index],
                            style: TextStyle(
                              fontSize: 18,
                              color: selected == index
                                  ? Colors.white
                                  : const Color(0xFF444844),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _measurementFields() {
    if (_step == 2 && widget.draft.heightInFeet) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _field(
              id: 'height-feet',
              controller: _feet,
              hint: '5',
              unit: 'FT',
              wholeNumber: true,
              nextFocus: true,
              validator: (value) =>
                  _validateNumber(value, 'feet', 0, 9, wholeNumber: true),
              onChanged: (_) => _updateCmFromFeet(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _field(
              id: 'height-inches',
              controller: _inches,
              hint: '7',
              unit: 'IN',
              validator: _validateInches,
              onChanged: (_) => _updateCmFromFeet(),
            ),
          ),
        ],
      );
    }
    if (_step == 2) {
      return _field(
        id: 'height',
        controller: _height,
        hint: '170',
        unit: 'CM',
        validator: (value) => _validateNumber(value, 'height', 30, 300),
        onChanged: (value) {
          widget.draft.height = value;
          _updateFeetFromCm();
        },
      );
    }
    if (_step == 3 && widget.draft.weightInPounds) {
      return _field(
        id: 'weight-pounds',
        controller: _pounds,
        hint: '154',
        unit: 'LB',
        validator: _validatePounds,
        onChanged: (value) {
          widget.draft.pounds = value;
          final pounds = _number(value);
          _weight.text = pounds == null ? '' : _format(pounds * _kgPerPound);
          widget.draft.weight = _weight.text;
        },
      );
    }
    if (_step == 3) {
      return _field(
        id: 'weight',
        controller: _weight,
        hint: '70',
        unit: 'KG',
        validator: (value) => _validateNumber(value, 'weight', 1, 500),
        onChanged: (value) => widget.draft.weight = value,
      );
    }
    return _field(
      id: 'age',
      controller: _age,
      hint: 'Enter your age',
      wholeNumber: true,
      validator: (value) =>
          _validateNumber(value, 'age', 1, 120, wholeNumber: true),
      onChanged: (value) => widget.draft.age = value,
    );
  }

  Widget _numberPage() {
    final isHeight = _step == 2;
    final isWeight = _step == 3;
    return ProfileStepLayout(
      key: ValueKey(_step),
      step: _step,
      title: isHeight
          ? 'How tall are you?'
          : isWeight
          ? 'what is your weight?'
          : 'How old are you?',
      subtitle: isHeight
          ? 'Add your height to your profile.'
          : isWeight
          ? 'Add your weight to your profile.'
          : 'Add your age to your profile.',
      imageAsset:
          'assets/images/${isHeight
              ? 'height'
              : isWeight
              ? 'weight'
              : 'age'}.png',
      blendImageBackground: isWeight,
      onBack: _back,
      busy: _busy,
      nextLabel: isHeight
          ? 'Next: weight'
          : isWeight
          ? 'Next: age'
          : 'Get started!',
      children: [
        Form(
          key: _formKeys[_step - 2],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_step == 2) ...[
                _unitSwitch(
                  ['cm', 'ft / in'],
                  widget.draft.heightInFeet ? 1 : 0,
                  (index) => _setHeightUnit(index == 1),
                ),
                const SizedBox(height: 18),
              ],
              if (_step == 3) ...[
                _unitSwitch(
                  ['kg', 'lb'],
                  widget.draft.weightInPounds ? 1 : 0,
                  (index) => _setWeightUnit(index == 1),
                ),
                const SizedBox(height: 18),
              ],
              Text(
                isHeight
                    ? 'Height'
                    : isWeight
                    ? 'Weight'
                    : 'Age (years)',
                style: AuthStyle.serif.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _measurementFields(),
              SizedBox(height: _step == 4 ? 72 : 12),
              Text(
                'You can change this later in your profile',
                style: AuthStyle.serif.copyWith(
                  fontSize: 14,
                  height: 1.3,
                  color: AuthStyle.muted,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    key: const Key('registration-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      height: 1.4,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Edit account details'),
                ),
              ],
              SizedBox(height: _step == 4 ? 24 : 40),
              FilledButton(
                key: const Key('profile-continue'),
                onPressed: _busy ? null : _next,
                style: AuthStyle.primaryButton.copyWith(
                  minimumSize: const WidgetStatePropertyAll(
                    Size.fromHeight(44),
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(child: Text('Continue')),
                          SizedBox(width: 12),
                          Icon(Icons.arrow_forward_rounded, size: 25),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
