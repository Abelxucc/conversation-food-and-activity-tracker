// ignore_for_file: file_names

import 'package:flutter/material.dart';

import 'auth_style.dart';
import 'profile_details.dart';
import 'profile_step_layout.dart';

export 'profile_details.dart' show ProfileGender;

class GenderPage extends StatefulWidget {
  const GenderPage({
    super.key,
    this.initialGender,
    this.onChanged,
    this.onContinue,
    this.onBack,
  });

  final ProfileGender? initialGender;
  final ValueChanged<ProfileGender>? onChanged;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  State<GenderPage> createState() => _GenderPageState();
}

class _GenderPageState extends State<GenderPage> {
  late ProfileGender? _selectedGender;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _selectedGender = widget.initialGender;
  }

  void _continue() {
    if (widget.onContinue == null) return;
    if (_selectedGender == null) {
      setState(() => _showError = true);
      return;
    }
    widget.onContinue!();
  }

  @override
  Widget build(BuildContext context) {
    return ProfileStepLayout(
      step: 1,
      title: 'What is your gender?',
      imageAsset: 'assets/images/gender.png',
      imageFit: BoxFit.cover,
      onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      nextLabel: 'Next: height',
      children: [
        for (var index = 0; index < ProfileGender.values.length; index++) ...[
          if (index > 0) const SizedBox(height: 14),
          _GenderOption(
            gender: ProfileGender.values[index],
            selected: _selectedGender == ProfileGender.values[index],
            onTap: () {
              final gender = ProfileGender.values[index];
              setState(() {
                _selectedGender = gender;
                _showError = false;
              });
              widget.onChanged?.call(gender);
            },
          ),
        ],
        if (_showError)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                'Choose an option to continue.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'You can change this later in your profile',
          textAlign: TextAlign.center,
          style: AuthStyle.serif.copyWith(
            fontSize: 14,
            height: 1.3,
            color: AuthStyle.muted,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          key: const Key('gender-continue'),
          onPressed: _continue,
          style: AuthStyle.primaryButton,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text('Continue')),
              SizedBox(width: 12),
              Icon(Icons.arrow_forward_rounded, size: 25),
            ],
          ),
        ),
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  const _GenderOption({
    required this.gender,
    required this.selected,
    required this.onTap,
  });

  final ProfileGender gender;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: Key('gender-${gender.name}'),
      label: gender.label,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: const BorderSide(color: Color(0xFFD5D5D5)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      gender.label,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222522),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: selected
                        ? const Icon(
                            Icons.check_box_rounded,
                            key: Key('gender-selected'),
                            size: 22,
                            color: Color(0xFF7053A5),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
