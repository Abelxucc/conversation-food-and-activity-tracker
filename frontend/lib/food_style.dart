import 'package:flutter/cupertino.dart';

class FoodStyle {
  static const background = Color(0xFFF0F3E8);
  static const surface = Color(0xFFFAFBF8);
  static const green = Color(0xFF009D59);
  static const ink = Color(0xFF1C2922);
  static const muted = Color(0xFF758575);
  static const pale = Color(0xFFE2EAD9);
  static const forest = Color(0xFF336651);
  static const meals = {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snack',
  };

  static Widget theme(Widget child) => CupertinoTheme(
    data: const CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: green,
      scaffoldBackgroundColor: background,
      barBackgroundColor: Color(0xF0F0F3E8),
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          fontFamily: 'CupertinoSystemText',
          fontSize: 17,
          color: ink,
        ),
        navTitleTextStyle: TextStyle(
          fontFamily: 'CupertinoSystemText',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        navLargeTitleTextStyle: TextStyle(
          fontFamily: 'CupertinoSystemDisplay',
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: .2,
          color: ink,
        ),
      ),
    ),
    child: DefaultTextStyle(
      style: const TextStyle(
        inherit: false,
        fontFamily: 'CupertinoSystemText',
        fontSize: 17,
        color: ink,
        decoration: TextDecoration.none,
      ),
      child: child,
    ),
  );

  static String date(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  static String today(DateTime value) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${value.day} ${months[value.month - 1]}';
  }

  static String recordDate(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year &&
            value.month == now.month &&
            value.day == now.day
        ? 'Today'
        : date(value);
  }

  static String time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  static Widget card(Widget child) => DecoratedBox(
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );

  static Widget primary({
    Key? key,
    required Widget child,
    required VoidCallback? onPressed,
  }) => CupertinoButton.filled(
    key: key,
    onPressed: onPressed,
    borderRadius: BorderRadius.circular(10),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: child,
  );

  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) => showCupertinoDialog<bool>(
    context: context,
    builder: (context) => theme(
      CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ),
  );

  static Future<bool?> picker(
    BuildContext context, {
    required String title,
    required Widget child,
  }) => showCupertinoModalPopup<bool>(
    context: context,
    builder: (context) => theme(
      Container(
        height: 300 + MediaQuery.paddingOf(context).bottom,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemGroupedBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: [
                    CupertinoButton(
                      key: const Key('picker-cancel'),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      key: const Key('picker-done'),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(color: CupertinoColors.separator),
                child: SizedBox(height: .5, width: double.infinity),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    ),
  );
}
