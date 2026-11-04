import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/services.dart';

import '../history/food_history_order.dart';
import '../shared/food_style.dart';
import 'food_service.dart';

class FoodDiaryPage extends StatefulWidget {
  const FoodDiaryPage({
    super.key,
    required this.service,
    required this.active,
    required this.openHistory,
    required this.addFood,
  });

  final FoodService service;
  final bool active;
  final Future<void> Function(DateTime) openHistory;
  final VoidCallback addFood;

  @override
  State<FoodDiaryPage> createState() => _FoodDiaryPageState();
}

class _FoodDiaryPageState extends State<FoodDiaryPage> {
  static const _deep = Color(0xFF155A46);
  static const _muted = Color(0xFF526854);
  static const _tipFill = Color(0xFFE4EEE1);
  static const _section = TextStyle(fontSize: 19, fontWeight: FontWeight.w700);
  static const _guideUrl =
      'https://www.gov.uk/government/publications/the-eatwell-guide';

  DateTime _day = DateUtils.dateOnly(DateTime.now());
  DateTime _weekStart = _monday(DateTime.now());
  bool _showWeek = false;
  Future<List<FoodRecord>?>? _records;
  Future<FoodWeek?>? _week;

  static DateTime _offset(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  static DateTime _monday(DateTime date) => _offset(date, 1 - date.weekday);

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(FoodDiaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  Future<T?> _tryLoad<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (_) {
      return null;
    }
  }

  void _load() {
    if (_showWeek) {
      _week = _tryLoad(() => widget.service.week(_weekStart));
    } else {
      _records = _tryLoad(widget.service.list);
    }
  }

  void _selectView(bool showWeek) {
    if (showWeek == _showWeek) return;
    setState(() {
      _showWeek = showWeek;
      _load();
    });
  }

  void _changeDate(int direction) {
    setState(() {
      if (_showWeek) {
        _weekStart = _offset(_weekStart, direction * 7);
        _load();
      } else {
        _day = _offset(_day, direction);
      }
    });
  }

  Future<void> _history([DateTime? date]) async {
    await widget.openHistory(date ?? (_showWeek ? _weekStart : _day));
    if (mounted && widget.active) setState(_load);
  }

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: widget.active,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Food',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
            ),
            _textButton('History', _history),
          ],
        ),
        const Text(
          'Your food diary',
          style: TextStyle(fontSize: 14, color: _muted),
        ),
        const SizedBox(height: 16),
        _segmentedControl(),
        const SizedBox(height: 12),
        _dateControl(),
        const SizedBox(height: 12),
        if (_showWeek) _weeklyView() else _dailyView(),
      ],
    ),
  );

  Widget _segmentedControl() => _panel(
    radius: 15,
    padding: const EdgeInsets.all(4),
    color: FoodStyle.pale,
    child: Row(
      children: [
        for (final (weekly, label) in [(false, 'Today'), (true, 'This week')])
          Expanded(
            child: Semantics(
              selected: weekly == _showWeek,
              child: CupertinoButton(
                color: weekly == _showWeek ? CupertinoColors.white : null,
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                minimumSize: const Size(0, 35),
                onPressed: () => _selectView(weekly),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: weekly == _showWeek ? _deep : _muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _dateControl() {
    final today = DateUtils.dateOnly(DateTime.now());
    final end = _offset(_weekStart, 6);
    final dateLabel = _showWeek
        ? _weekStart.month == end.month
              ? '${_weekStart.day}–${FoodStyle.today(end)}'
              : '${FoodStyle.today(_weekStart)} – ${FoodStyle.today(end)}'
        : '${_day == today ? 'Today, ' : ''}${FoodStyle.today(_day)}';
    final canGoForward = _showWeek
        ? _weekStart.isBefore(_monday(today))
        : _day.isBefore(today);
    final period = _showWeek ? 'week' : 'day';
    return _panel(
      radius: 15,
      padding: EdgeInsets.zero,
      color: FoodStyle.pale,
      child: Row(
        children: [
          _dateArrow(
            'Previous $period',
            CupertinoIcons.chevron_left,
            () => _changeDate(-1),
          ),
          Expanded(
            child: Text(
              dateLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          _dateArrow(
            'Next $period',
            CupertinoIcons.chevron_right,
            canGoForward ? () => _changeDate(1) : null,
          ),
        ],
      ),
    );
  }

  Widget _dateArrow(String label, IconData icon, VoidCallback? onPressed) =>
      Semantics(
        label: label,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 42),
          onPressed: onPressed,
          child: Icon(
            icon,
            size: 17,
            color: onPressed == null ? FoodStyle.muted : FoodStyle.forest,
          ),
        ),
      );

  Widget _dailyView() => FutureBuilder<List<FoodRecord>?>(
    future: _records,
    builder: (context, snapshot) {
      final records = snapshot.data;
      if (records == null) {
        return _loadStatus(
          snapshot.connectionState,
          'Could not load food records.',
        );
      }
      final meals = sortFoodHistory(
        records.where((record) => DateUtils.isSameDay(record.eatenAt, _day)),
      );
      final snacks = meals
          .where(
            (meal) => meal.mealType == 'snack' || meal.mealType == 'elevenses',
          )
          .length;
      final mealCount = meals.length - snacks;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panel(
            color: _tipFill,
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${meals.length} food ${meals.length == 1 ? 'record' : 'records'}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _deep,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$mealCount ${mealCount == 1 ? 'meal' : 'meals'} · $snacks ${snacks == 1 ? 'snack' : 'snacks'}',
                        style: const TextStyle(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  color: _deep,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 9,
                  ),
                  onPressed: widget.addFood,
                  child: const Text(
                    '+ Add food',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          const Text('Meals & snacks', style: _section),
          const SizedBox(height: 8),
          if (meals.isEmpty)
            _panel(
              child: const Text(
                'No food records for this day.',
                style: TextStyle(fontSize: 14, color: _muted),
              ),
            )
          else
            for (final meal in meals)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: CupertinoButton(
                  key: ValueKey('diary-meal-${meal.id}'),
                  padding: EdgeInsets.zero,
                  color: FoodStyle.surface,
                  borderRadius: BorderRadius.circular(18),
                  onPressed: () => _history(meal.eatenAt),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _labelPair(
                            FoodStyle.meals[meal.mealType] ?? 'Meal',
                            meal.items.map((item) => item.name).join(', '),
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          meal.timeSpecified
                              ? FoodStyle.time(meal.eatenAt)
                              : 'No time',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 7),
          _allergiesCard(),
          const SizedBox(height: 12),
          _panel(
            color: _tipFill,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _recommendationTitle(),
                const SizedBox(height: 7),
                const Text(
                  'Ideas based on what you’ve logged this week.',
                  style: TextStyle(fontSize: 13),
                ),
                _textButton(
                  'View this week',
                  () => _selectView(true),
                  icon: CupertinoIcons.chevron_right,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _allergiesCard() => _panel(
    radius: 18,
    padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
    child: Row(
      children: [
        _iconTile(
          CupertinoIcons.shield,
          const Color(0xFFF2EBD9),
          FoodStyle.forest,
        ),
        const SizedBox(width: 10),
        Expanded(child: _labelPair('Food allergies', 'Save your allergens')),
        _textButton('Add', _showAllergies, icon: CupertinoIcons.chevron_right),
      ],
    ),
  );

  Future<void> _showAllergies() => showCupertinoDialog<void>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('Food allergies'),
      content: const Text('Allergy settings are coming soon.'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );

  Widget _weeklyView() => FutureBuilder<FoodWeek?>(
    future: _week,
    builder: (context, snapshot) {
      final week = snapshot.connectionState == ConnectionState.done
          ? snapshot.data
          : null;
      if (week == null) {
        return _loadStatus(
          snapshot.connectionState,
          'Could not load the weekly food review.',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'What you ate this week',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'From ${week.daysLogged} ${week.daysLogged == 1 ? 'day' : 'days'} of food logs',
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
              ),
              _textButton(
                'Eatwell Guide',
                () => _showGuide(week.tip?.sourceUrl ?? _guideUrl),
                icon: CupertinoIcons.arrow_up_right,
              ),
            ],
          ),
          _panel(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            child: Column(
              children: [
                for (final (index, group) in week.groups.entries.indexed) ...[
                  if (index != 0)
                    const Padding(
                      padding: EdgeInsets.only(left: 43),
                      child: SizedBox(
                        height: 1,
                        child: ColoredBox(color: Color(0xFFE5EBE2)),
                      ),
                    ),
                  _groupRow(group.key, group.value),
                ],
              ],
            ),
          ),
          const SizedBox(height: 13),
          _weeklyRecommendation(week.tip),
        ],
      );
    },
  );

  Widget _groupRow(String label, List<String> foods) {
    final (icon, background, foreground) = switch (label) {
      'Fruit & vegetables' => (
        CupertinoIcons.leaf_arrow_circlepath,
        const Color(0xFFE3EFD9),
        const Color(0xFF467343),
      ),
      'Starchy foods' => (
        CupertinoIcons.tree,
        const Color(0xFFF2EBD5),
        const Color(0xFF866A32),
      ),
      'Protein foods' => (
        CupertinoIcons.circle,
        const Color(0xFFF2E6E1),
        const Color(0xFF915E50),
      ),
      'Dairy & alternatives' => (
        CupertinoIcons.cube_box,
        const Color(0xFFE2ECF1),
        const Color(0xFF4B7086),
      ),
      'Oils & spreads' => (
        CupertinoIcons.drop,
        const Color(0xFFF2EEDC),
        const Color(0xFF84713D),
      ),
      _ => (
        CupertinoIcons.line_horizontal_3,
        const Color(0xFFEBEEE8),
        const Color(0xFF667465),
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          _iconTile(icon, background, foreground),
          const SizedBox(width: 11),
          Expanded(
            child: _labelPair(
              label,
              foods.isEmpty ? 'No entries yet' : foods.join(', '),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weeklyRecommendation(FoodTip? tip) {
    final pulses = tip?.title == 'No pulses logged this week';
    return _panel(
      color: _tipFill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _recommendationTitle(),
          if (tip != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    pulses ? 'Pulses' : tip.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (pulses)
                  _panel(
                    radius: 9,
                    color: const Color(0xFFF4F8F0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    child: const Text(
                      'Not logged',
                      style: TextStyle(
                        fontSize: 12,
                        color: FoodStyle.forest,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 7),
          Text(
            tip?.body ?? 'Log a meal to see a food idea for this week.',
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }

  Future<void> _showGuide(String url) => showCupertinoDialog<void>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('Eatwell Guide'),
      content: Text(url),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
        CupertinoDialogAction(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Copy link'),
        ),
      ],
    ),
  );

  Widget _loadStatus(ConnectionState state, String error) => switch (state) {
    ConnectionState.none => const SizedBox.shrink(),
    ConnectionState.done => _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error),
          _textButton('Try again', () => setState(_load)),
        ],
      ),
    ),
    _ => const Padding(
      padding: EdgeInsets.all(10),
      child: CupertinoActivityIndicator(),
    ),
  };

  Widget _textButton(String label, VoidCallback onPressed, {IconData? icon}) =>
      CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        minimumSize: const Size(0, 42),
        alignment: Alignment.centerLeft,
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: FoodStyle.forest,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 13, color: FoodStyle.forest),
            ],
          ],
        ),
      );

  Widget _labelPair(String label, String detail, {int? maxLines}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: FoodStyle.ink,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        detail,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: _muted),
      ),
    ],
  );

  Widget _recommendationTitle() => const Row(
    children: [
      Icon(CupertinoIcons.leaf_arrow_circlepath, color: _deep, size: 18),
      SizedBox(width: 7),
      Expanded(
        child: Text(
          'Food recommendations',
          style: TextStyle(
            color: _deep,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _iconTile(IconData icon, Color background, Color foreground) =>
      Container(
        height: 32,
        width: 32,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: foreground, size: 17),
      );

  Widget _panel({
    required Widget child,
    Color color = FoodStyle.surface,
    double radius = 21,
    EdgeInsets padding = const EdgeInsets.all(15),
  }) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Padding(padding: padding, child: child),
  );
}
