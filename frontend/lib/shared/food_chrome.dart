import 'dart:ui';

import 'package:flutter/cupertino.dart';

import 'food_style.dart';
import 'page_back_button.dart';

/// Shared header layout from the Add record design.
class FoodHeader extends StatelessWidget {
  const FoodHeader({
    super.key,
    this.title = 'Add record',
    this.onHistory,
    this.onBack,
    this.showHistory = true,
    this.subtitle,
    this.backEnabled = true,
    this.showBack = true,
    this.centerTitle = false,
  });
  final String title;
  final VoidCallback? onHistory;
  final VoidCallback? onBack;
  final bool showHistory;
  final String? subtitle;
  final bool backEnabled;
  final bool showBack;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: NavigationToolbar(
            centerMiddle: centerTitle,
            middleSpacing: 0,
            leading: showBack
                ? PageBackButton(
                    onPressed: onBack,
                    enabled: backEnabled,
                    color: FoodStyle.forest,
                  )
                : null,
            middle: Text(
              title,
              style: const TextStyle(fontSize: 21, letterSpacing: -.6),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: showHistory
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onHistory,
                    child: const Text(
                      'History',
                      style: TextStyle(fontSize: 14, color: FoodStyle.forest),
                    ),
                  )
                : null,
          ),
        ),
        Text(
          subtitle ?? 'Today, ${FoodStyle.today(DateTime.now())}',
          style: const TextStyle(fontSize: 13, color: FoodStyle.muted),
        ),
      ],
    ),
  );
}

class FoodModeSelector extends StatelessWidget {
  const FoodModeSelector({super.key, this.activity = false, this.onChanged});

  final bool activity;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: FoodStyle.pale,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [_choice('Food', false), _choice('Activity', true)]),
  );

  Widget _choice(String label, bool choice) {
    final selected = activity == choice;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: CupertinoButton(
          key: Key('record-mode-${label.toLowerCase()}'),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(vertical: 7),
          color: selected ? FoodStyle.surface : null,
          borderRadius: BorderRadius.circular(13),
          onPressed: onChanged == null ? null : () => onChanged!(choice),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? FoodStyle.forest : FoodStyle.muted,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

enum FoodDestination { home, food, add, activity, me }

class FoodNavigation extends StatelessWidget {
  const FoodNavigation({
    super.key,
    this.highlightAdd = true,
    this.onAdd,
    this.selectedDestination,
    this.onSelected,
  });
  final bool highlightAdd;
  final VoidCallback? onAdd;
  final FoodDestination? selectedDestination;
  final ValueChanged<FoodDestination>? onSelected;

  FoodDestination? get _selected =>
      selectedDestination ?? (highlightAdd ? FoodDestination.add : null);

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(42),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xDDF8FAF3),
              border: Border.all(color: const Color(0xCCFFFFFF)),
              borderRadius: BorderRadius.circular(42),
            ),
            child: SizedBox(
              height: 50,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width =
                      constraints.maxWidth / FoodDestination.values.length;
                  final selected = _selected;
                  return Stack(
                    children: [
                      if (selected != null)
                        AnimatedPositioned(
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          left: width * selected.index + (width - 50) / 2,
                          top: 0,
                          width: 50,
                          height: 50,
                          child: const DecoratedBox(
                            key: Key('nav-selection'),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: FoodStyle.pale,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          _destination(
                            FoodDestination.home,
                            'Home',
                            'Home.png',
                            duration,
                          ),
                          _destination(
                            FoodDestination.food,
                            'Food',
                            'food.png',
                            duration,
                          ),
                          _destination(
                            FoodDestination.add,
                            'Add record',
                            null,
                            duration,
                          ),
                          _destination(
                            FoodDestination.activity,
                            'Activity',
                            'activity.png',
                            duration,
                          ),
                          _destination(
                            FoodDestination.me,
                            'Me',
                            'Me.png',
                            duration,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _destination(
    FoodDestination destination,
    String label,
    String? asset,
    Duration duration,
  ) {
    final selected = _selected == destination;
    final action = onSelected != null
        ? () => onSelected!(destination)
        : destination == FoodDestination.add
        ? onAdd
        : null;
    return Expanded(
      child: Semantics(
        key: Key('nav-${destination.name}'),
        label: label,
        button: true,
        enabled: action != null,
        selected: selected,
        child: ExcludeSemantics(
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: action,
            child: Center(
              child: AnimatedSlide(
                duration: duration,
                curve: Curves.easeOutCubic,
                offset: selected ? const Offset(0, -.025) : Offset.zero,
                child: AnimatedScale(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  scale: selected ? 1.06 : 1,
                  child: asset == null
                      ? Icon(
                          CupertinoIcons.plus,
                          size: 29,
                          color: selected ? FoodStyle.forest : FoodStyle.ink,
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/$asset',
                              width: 38,
                              height: 34,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 1),
                            AnimatedDefaultTextStyle(
                              duration: duration,
                              style: TextStyle(
                                fontFamily: 'CupertinoSystemText',
                                fontSize: 10,
                                color: selected
                                    ? FoodStyle.forest
                                    : FoodStyle.ink,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FoodComposer extends StatelessWidget {
  const FoodComposer({
    super.key,
    this.activity = false,
    this.saved = false,
    this.showExample = true,
    this.controller,
    this.onSubmit,
    this.error,
  });

  final bool activity;
  final bool saved;
  final bool showExample;
  final TextEditingController? controller;
  final VoidCallback? onSubmit;
  final String? error;

  @override
  Widget build(BuildContext context) => Semantics(
    label: activity ? 'Activity description input' : 'Food description input',
    enabled: controller != null && onSubmit != null,
    child: Container(
      margin: const EdgeInsets.fromLTRB(22, 8, 22, 10),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
      decoration: BoxDecoration(
        color: FoodStyle.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C263D2D),
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller == null)
            Text(
              activity
                  ? (saved ? 'Add another detail...' : 'Type what you did...')
                  : 'Type what you ate...',
              style: const TextStyle(fontSize: 17, color: FoodStyle.muted),
            )
          else
            CupertinoTextField(
              key: Key(activity ? 'activity-description' : 'food-description'),
              controller: controller,
              enabled: onSubmit != null,
              placeholder: activity
                  ? 'Type what you did...'
                  : 'Type what you ate...',
              decoration: null,
              padding: EdgeInsets.zero,
              maxLength: 2000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit?.call(),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.destructiveRed,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (showExample)
                Expanded(
                  child: Text(
                    activity
                        ? 'e.g. I went jogging for 30 minutes'
                        : 'e.g. I had porridge for breakfast',
                    style: const TextStyle(
                      fontSize: 11,
                      color: FoodStyle.muted,
                    ),
                  ),
                ),
              if (controller == null)
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: FoodStyle.forest,
                  ),
                  child: const Icon(
                    CupertinoIcons.arrow_up,
                    size: 25,
                    color: CupertinoColors.white,
                  ),
                )
              else
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller!,
                  builder: (context, value, _) => CupertinoButton(
                    key: Key(activity ? 'parse-activity' : 'parse-food'),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    onPressed: value.text.trim().isEmpty ? null : onSubmit,
                    child: Semantics(
                      label: activity
                          ? 'Send activity message'
                          : 'Send food message',
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: FoodStyle.forest,
                        ),
                        child: const Icon(
                          CupertinoIcons.arrow_up,
                          size: 25,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
