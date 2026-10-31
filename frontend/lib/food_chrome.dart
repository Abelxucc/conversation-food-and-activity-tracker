import 'dart:ui';

import 'package:flutter/cupertino.dart';

import 'food_style.dart';

/// Shared layout from the Add record design. Future destinations stay inert.
class FoodHeader extends StatelessWidget {
  const FoodHeader({
    super.key,
    this.title = 'Add record',
    this.onHistory,
    this.onBack,
    this.showHistory = true,
  });
  final String title;
  final VoidCallback? onHistory;
  final VoidCallback? onBack;
  final bool showHistory;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 8, 22, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              if (onBack != null)
                CupertinoButton(
                  padding: const EdgeInsets.only(right: 6),
                  onPressed: onBack,
                  child: const Icon(CupertinoIcons.chevron_back, size: 21),
                ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 22, letterSpacing: -.6),
                ),
              ),
              if (showHistory)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onHistory,
                  child: const Text(
                    'History',
                    style: TextStyle(fontSize: 14, color: FoodStyle.forest),
                  ),
                ),
            ],
          ),
        ),
        Text(
          'Today, ${FoodStyle.today(DateTime.now())}',
          style: const TextStyle(fontSize: 13, color: FoodStyle.muted),
        ),
      ],
    ),
  );
}

class FoodModeSelector extends StatelessWidget {
  const FoodModeSelector({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: FoodStyle.pale,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            selected: true,
            label: 'Food',
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: FoodStyle.surface,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Text(
                'Food',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FoodStyle.forest,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Semantics(
            button: true,
            enabled: false,
            child: Text(
              'Activity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FoodStyle.muted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class FoodNavigation extends StatelessWidget {
  const FoodNavigation({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
          child: Row(
            children: [
              _destination('Home', 'Home.png'),
              _destination('Food', 'food.png'),
              Expanded(
                child: Semantics(
                  key: const Key('nav-add'),
                  label: 'Add record',
                  button: true,
                  enabled: false,
                  selected: true,
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: FoodStyle.pale,
                      ),
                      child: const Icon(
                        CupertinoIcons.plus,
                        size: 25,
                        color: FoodStyle.forest,
                      ),
                    ),
                  ),
                ),
              ),
              _destination('Activity', 'activity.png'),
              _destination('Me', 'Me.png'),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _destination(String label, String asset) => Expanded(
    child: Semantics(
      key: Key('nav-${label.toLowerCase()}'),
      label: label,
      button: true,
      enabled: false,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/$asset',
              width: 38,
              height: 36,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: FoodStyle.ink),
            ),
          ],
        ),
      ),
    ),
  );
}

class FoodComposer extends StatelessWidget {
  const FoodComposer({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Food description input',
    enabled: false,
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
          const Text(
            'Type what you ate...',
            style: TextStyle(fontSize: 17, color: FoodStyle.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'e.g. I had porridge for breakfast',
                  style: TextStyle(fontSize: 11, color: FoodStyle.muted),
                ),
              ),
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
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
