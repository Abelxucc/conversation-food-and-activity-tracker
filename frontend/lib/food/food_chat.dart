import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../shared/food_style.dart';

class FoodMessageBubble extends StatelessWidget {
  const FoodMessageBubble({
    super.key,
    required this.message,
    required this.sentAt,
    required this.animate,
  });

  final String message;
  final DateTime sentAt;
  final bool animate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: AlignmentDirectional.centerEnd,
      child: FoodChatAppearance(
        animate: animate,
        distance: 52,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * .82),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              decoration: const BoxDecoration(
                color: FoodStyle.pale,
                borderRadius: BorderRadiusDirectional.only(
                  topStart: Radius.circular(19),
                  topEnd: Radius.circular(19),
                  bottomStart: Radius.circular(19),
                  bottomEnd: Radius.circular(5),
                ),
              ),
              child: Text(
                message,
                style: const TextStyle(fontSize: 15, height: 1.35),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Text(
                FoodStyle.time(sentAt),
                style: const TextStyle(fontSize: 11, color: FoodStyle.muted),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class FoodChatAppearance extends StatelessWidget {
  const FoodChatAppearance({
    super.key,
    required this.distance,
    required this.child,
    this.animate = true,
  });

  final double distance;
  final Widget child;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final motion = animate && !MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: motion ? 0 : 1, end: 1),
      duration: motion ? const Duration(milliseconds: 260) : Duration.zero,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, progress, child) => Transform.translate(
        offset: Offset(0, distance * (1 - progress)),
        child: Opacity(opacity: progress, child: child),
      ),
    );
  }
}

class FoodTypingIndicator extends StatefulWidget {
  const FoodTypingIndicator({super.key});

  @override
  State<FoodTypingIndicator> createState() => _FoodTypingIndicatorState();
}

class _FoodTypingIndicatorState extends State<FoodTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.reset();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'TrackTalk is typing',
    child: Container(
      key: const Key('food-typing'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: const BoxDecoration(
        color: FoodStyle.surface,
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(16),
          topEnd: Radius.circular(16),
          bottomEnd: Radius.circular(16),
          bottomStart: Radius.circular(5),
        ),
      ),
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 3; index++) ...[
              if (index > 0) const SizedBox(width: 5),
              Transform.translate(
                offset: Offset(
                  0,
                  -4 *
                      math.max(
                        0,
                        math.sin((_motion.value - index * .17) * math.pi * 2),
                      ),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: FoodStyle.forest,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 6, height: 6),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class FoodSavedBadge extends StatelessWidget {
  const FoodSavedBadge({super.key});

  @override
  Widget build(BuildContext context) => const Text(
    '✓ Saved',
    textAlign: TextAlign.right,
    style: TextStyle(color: FoodStyle.muted, fontSize: 13),
  );
}
