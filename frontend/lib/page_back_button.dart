import 'package:flutter/cupertino.dart';

/// Shared back affordance. The entry page has no previous route to return to.
class PageBackButton extends StatelessWidget {
  const PageBackButton({
    super.key,
    this.onPressed,
    this.enabled = true,
    this.color,
  });
  final VoidCallback? onPressed;
  final bool enabled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final action = enabled
        ? onPressed ?? (navigator.canPop() ? () => navigator.maybePop() : null)
        : null;
    return Semantics(
      label: 'Back',
      button: true,
      enabled: action != null,
      child: CupertinoButton(
        key: const Key('page-back'),
        padding: EdgeInsets.zero,
        minimumSize: const Size(36, 44),
        onPressed: action,
        child: Icon(
          CupertinoIcons.chevron_back,
          size: 23,
          color: action == null ? CupertinoColors.tertiaryLabel : color,
        ),
      ),
    );
  }
}
