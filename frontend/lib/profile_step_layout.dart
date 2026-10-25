import 'package:flutter/material.dart';

import 'auth_style.dart';

class ProfileStepLayout extends StatelessWidget {
  const ProfileStepLayout({
    super.key,
    required this.step,
    required this.title,
    required this.children,
    required this.onBack,
    this.imageAsset,
    this.imageFit = BoxFit.contain,
    this.nextLabel,
    this.busy = false,
    this.subtitle,
    this.blendImageBackground = false,
  });

  final int step;
  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;
  final String? imageAsset;
  final BoxFit imageFit;
  final String? nextLabel;
  final bool busy;
  final String? subtitle;
  final bool blendImageBackground;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthStyle.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final imageHeight =
                    (constraints.maxHeight - (step == 1 ? 550 : 465)).clamp(
                      step == 1 ? 170.0 : 230.0,
                      step == 1 ? 290.0 : 365.0,
                    );
                return SingleChildScrollView(
                  key: ValueKey('profile-scroll-$step'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: IconButton(
                                tooltip: 'Back',
                                onPressed: busy ? null : onBack,
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 24,
                                  color: Color(0xFF202520),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Your profile',
                                    style: AuthStyle.serif.copyWith(
                                      fontSize: 20,
                                      color: const Color(0xFF080C08),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '$step of 4',
                                  style: AuthStyle.serif.copyWith(
                                    fontSize: 16,
                                    color: AuthStyle.muted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        label: 'Profile setup, step $step of 4',
                        child: ExcludeSemantics(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              4,
                              (index) => Container(
                                key: Key('profile-step-${index + 1}'),
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index + 1 == step
                                      ? const Color(0xFF202520)
                                      : const Color(0xFFBEC2BA),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: step == 1 ? 14 : 6),
                      if (imageAsset != null)
                        SizedBox(
                          height: imageHeight,
                          child: OverflowBox(
                            minWidth: constraints.maxWidth,
                            maxWidth: constraints.maxWidth,
                            minHeight: imageHeight,
                            maxHeight: imageHeight,
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                AuthStyle.background,
                                blendImageBackground
                                    ? BlendMode.darken
                                    : BlendMode.dst,
                              ),
                              child: Image.asset(
                                imageAsset!,
                                height: imageHeight,
                                width: constraints.maxWidth,
                                fit: imageFit,
                                excludeFromSemantics: true,
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: imageHeight,
                          child: Center(
                            child: Container(
                              width: 190,
                              height: 190,
                              decoration: const BoxDecoration(
                                color: Color(0xFFDCE6CF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.monitor_weight_outlined,
                                size: 108,
                                color: Color(0xFF426342),
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: step == 1 ? 24 : 2),
                      Text(
                        title,
                        textAlign: step == 1
                            ? TextAlign.start
                            : TextAlign.center,
                        style: TextStyle(
                          fontSize: step == 1 ? 34 : 31,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.4,
                          color: Color(0xFF080C08),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          textAlign: TextAlign.center,
                          style: AuthStyle.serif.copyWith(
                            fontSize: 17,
                            height: 1.3,
                            color: AuthStyle.muted,
                          ),
                        ),
                      ],
                      SizedBox(height: step == 1 ? 24 : 30),
                      ...children,
                      if (nextLabel != null) ...[
                        SizedBox(height: step == 1 ? 24 : 12),
                        Text(
                          nextLabel!,
                          textAlign: TextAlign.center,
                          style: AuthStyle.serif.copyWith(
                            fontSize: 18,
                            color: AuthStyle.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
