// ignore_for_file: file_names
import 'package:flutter/cupertino.dart';

import 'activity/activity_record.dart';
import 'food/food_service.dart';
import 'history/food_history_order.dart';
import 'history/food_history_page.dart';
import 'shared/food_style.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.service,
    required this.active,
    required this.openHistory,
  });

  final FoodService service;
  final bool active;
  final Future<void> Function(DateTime, HistoryFilter) openHistory;

  @override
  State<HomePage> createState() => _HomePageState();
}

typedef _DayRecords = ({List<FoodRecord> food, List<ActivityRecord> activity});
typedef _Preview = ({String icon, String title, String detail, String time});

class _HomePageState extends State<HomePage> {
  DateTime _selected = DateTime.now();
  Future<_DayRecords?>? _dayRecords;
  Future<FoodWeek?>? _week;

  @override
  void initState() {
    super.initState();
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  Future<_DayRecords?> _loadRecords() async {
    try {
      final (food, activity) = await (
        widget.service.list(),
        widget.service.listActivities(),
      ).wait;
      return (food: food, activity: activity);
    } catch (_) {
      return null;
    }
  }

  Future<FoodWeek?> _loadWeek(DateTime date) async {
    try {
      return await widget.service.week(date);
    } catch (_) {
      return null;
    }
  }

  void _load() {
    _dayRecords = _loadRecords();
    _week = _loadWeek(_selected);
  }

  DateTime _dayOffset(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  DateTime _monday(DateTime date) => _dayOffset(date, 1 - date.weekday);
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _chooseDate(DateTime date) {
    setState(() {
      if (!_sameDay(_monday(_selected), _monday(date))) {
        _week = _loadWeek(date);
      }
      _selected = date;
    });
  }

  Future<void> _history(HistoryFilter filter) async {
    await widget.openHistory(_selected, filter);
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = _sameDay(today, _selected);
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final date =
        '${weekdays[_selected.weekday - 1]}, ${FoodStyle.today(_selected)}';
    return TickerMode(
      enabled: widget.active,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isToday ? 'Today' : date,
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              date,
              style: const TextStyle(fontSize: 14, color: FoodStyle.muted),
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: FoodStyle.pale,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                for (var offset = -6; offset <= 0; offset++)
                  Expanded(
                    child: _dayButton(_dayOffset(today, offset), weekdays),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<_DayRecords?>(
            future: _dayRecords,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  !snapshot.hasData) {
                return FoodStyle.card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Could not load records.'),
                      _textButton('Try again', () => setState(_load)),
                    ],
                  ),
                );
              }
              final records = snapshot.data;
              if (records == null) {
                return snapshot.connectionState == ConnectionState.waiting
                    ? const CupertinoActivityIndicator()
                    : const SizedBox.shrink();
              }
              return _dailyContent(records);
            },
          ),
        ],
      ),
    );
  }

  Widget _dayButton(DateTime date, List<String> weekdays) {
    final selected = _sameDay(date, _selected);
    return Semantics(
      selected: selected,
      label: FoodStyle.today(date),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 7),
        color: selected ? FoodStyle.surface : null,
        borderRadius: BorderRadius.circular(13),
        onPressed: () => _chooseDate(date),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              weekdays[date.weekday - 1],
              style: const TextStyle(fontSize: 11, color: FoodStyle.forest),
            ),
            Text(
              '${date.day}',
              style: const TextStyle(fontSize: 16, color: FoodStyle.ink),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dailyContent(_DayRecords records) {
    final food = sortFoodHistory(
      records.food.where((item) => _sameDay(item.eatenAt, _selected)),
    );
    final activities =
        records.activity
            .where((item) => _sameDay(item.occurredAt, _selected))
            .toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final minutes = activities.fold(
      0,
      (total, item) => total + item.durationMinutes,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _metric(
                '${food.length}',
                'Food records',
                CupertinoIcons.list_bullet,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metric(
                '$minutes min',
                'Activity time',
                CupertinoIcons.timer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _recommendation(),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(child: Text('Food records', style: _sectionStyle)),
            _textButton('View history', () => _history(HistoryFilter.food)),
          ],
        ),
        if (food.isEmpty)
          FoodStyle.card(const Text('No food records for this day.'))
        else
          _RecordCarousel(
            key: ValueKey((
              'food',
              _selected,
              food.map((item) => item.id).join(','),
            )),
            records: [
              for (final record in food)
                (
                  icon: _foodIcon(record.items),
                  title: FoodStyle.meals[record.mealType] ?? 'Meal',
                  detail: record.items.map((item) => item.name).join(', '),
                  time: record.timeSpecified
                      ? FoodStyle.time(record.eatenAt)
                      : 'No time',
                ),
            ],
            open: () => _history(HistoryFilter.food),
          ),
        const SizedBox(height: 18),
        const Text('Activity records', style: _sectionStyle),
        const SizedBox(height: 8),
        if (activities.isEmpty)
          FoodStyle.card(const Text('No activities for this day.'))
        else
          _RecordCarousel(
            key: ValueKey((
              'activity',
              _selected,
              activities.map((item) => item.id).join(','),
            )),
            records: [
              for (final activity in activities)
                (
                  icon: '👟',
                  title: activity.name,
                  detail: '${activity.durationMinutes} min',
                  time: activity.timeSpecified
                      ? FoodStyle.time(activity.occurredAt)
                      : 'No time',
                ),
            ],
            open: () => _history(HistoryFilter.activity),
          ),
      ],
    );
  }

  Widget _recommendation() => FutureBuilder<FoodWeek?>(
    future: _week,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _tipCard(null, message: 'Checking this week’s food logs…');
      }
      return _tipCard(
        snapshot.data?.tip,
        message:
            snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasData
            ? 'Could not load your weekly food recommendation.'
            : null,
      );
    },
  );

  Widget _tipCard(FoodTip? tip, {String? message}) {
    const color = CupertinoColors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FoodStyle.forest,
        borderRadius: BorderRadius.circular(23),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Food recommendation',
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (tip != null) ...[
              Text(
                tip.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 5),
            ],
            Text(
              tip?.body ??
                  message ??
                  'Log a meal to see a food idea for this week.',
              style: TextStyle(fontSize: 14, color: color),
            ),
          ],
        ),
      ),
    );
  }

  static const _sectionStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  Widget _metric(String value, String label, IconData icon) => DecoratedBox(
    decoration: BoxDecoration(
      color: FoodStyle.surface,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Padding(
      padding: const EdgeInsets.all(9),
      child: Row(
        children: [
          Icon(icon, size: 20, color: FoodStyle.forest),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    color: FoodStyle.forest,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: FoodStyle.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _textButton(String text, VoidCallback onPressed) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    onPressed: onPressed,
    child: Text(
      text,
      style: const TextStyle(fontSize: 14, color: FoodStyle.forest),
    ),
  );

  String _foodIcon(List<FoodItem> items) {
    const icons = {
      'porridge': '🥣',
      'oats': '🥣',
      'spaghetti': '🍝',
      'pasta': '🍝',
      'noodles': '🍜',
      'sandwich': '🥪',
      'salad': '🥗',
      'soup': '🥣',
      'banana': '🍌',
    };
    for (final item in items) {
      for (final word in item.name.toLowerCase().split(RegExp(r'[^a-z]+'))) {
        final icon = icons[word];
        if (icon != null) return icon;
      }
    }
    return '🍽️';
  }
}

class _RecordCarousel extends StatefulWidget {
  const _RecordCarousel({super.key, required this.records, required this.open});
  final List<_Preview> records;
  final VoidCallback open;

  @override
  State<_RecordCarousel> createState() => _RecordCarouselState();
}

class _RecordCarouselState extends State<_RecordCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) => FoodStyle.card(
    Column(
      children: [
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(84),
          child: PageView.builder(
            itemCount: widget.records.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) {
              final record = widget.records[index];
              return CupertinoButton(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
                onPressed: widget.open,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: FoodStyle.pale,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          record.icon,
                          style: const TextStyle(fontSize: 21),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: FoodStyle.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            record.detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: FoodStyle.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      record.time,
                      style: const TextStyle(
                        fontSize: 13,
                        color: FoodStyle.ink,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (widget.records.length > 1)
          Semantics(
            label: 'Record ${_page + 1} of ${widget.records.length}',
            child: widget.records.length > 8
                ? Text(
                    '${_page + 1} / ${widget.records.length}',
                    style: const TextStyle(fontSize: 12),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (
                        var index = 0;
                        index < widget.records.length;
                        index++
                      )
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 7,
                          width: 7,
                          decoration: BoxDecoration(
                            color: _page == index
                                ? FoodStyle.forest
                                : FoodStyle.pale,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
          ),
      ],
    ),
  );
}
