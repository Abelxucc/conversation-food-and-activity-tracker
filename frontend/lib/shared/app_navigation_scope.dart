import 'package:flutter/widgets.dart';

/// Shares the persistent navigation bar with the food flow's nested routes.
class AppNavigationScope extends InheritedWidget {
  const AppNavigationScope({
    super.key,
    required this.onBusyChanged,
    required super.child,
  });

  final ValueChanged<bool> onBusyChanged;

  static bool isPresent(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppNavigationScope>() != null;

  /// Keep tab switching and sign out unavailable during a food write.
  static Future<T> whileBusy<T>(
    BuildContext context,
    Future<T> Function() action,
  ) async {
    final scope = context.getInheritedWidgetOfExactType<AppNavigationScope>();
    scope?.onBusyChanged(true);
    try {
      return await action();
    } finally {
      scope?.onBusyChanged(false);
    }
  }

  @override
  bool updateShouldNotify(AppNavigationScope oldWidget) => false;
}
