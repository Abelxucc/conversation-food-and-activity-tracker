import 'package:flutter/cupertino.dart';

import '../food/food_page.dart';
import '../shared/app_navigation_scope.dart';
import '../food/food_service.dart';
import '../shared/food_style.dart';
import '../food/food_editor.dart';
import '../shared/food_chrome.dart';
import 'food_history_order.dart';

class FoodHistoryPage extends StatefulWidget {
  const FoodHistoryPage({super.key, required this.service, this.initialDate});
  final FoodService service;
  final DateTime? initialDate;

  @override
  State<FoodHistoryPage> createState() => _FoodHistoryPageState();
}

class _FoodHistoryPageState extends State<FoodHistoryPage> {
  List<FoodRecord> _records = [];
  bool _loading = true;
  String? _error;
  int? _deleting;
  late DateTime _date;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    final date = widget.initialDate ?? DateTime.now();
    _date = DateTime(date.year, date.month, date.day);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await widget.service.list();
      if (mounted) setState(() => _records = records);
    } on FoodException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load history. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(FoodRecord record) async {
    await Navigator.of(context).push<FoodDraft>(
      CupertinoPageRoute(
        builder: (_) => FoodEditor(
          initialDraft: record,
          service: widget.service,
          onSave: (draft) async {
            await widget.service.save(draft, id: record.id);
          },
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _delete(FoodRecord record) async {
    final confirmed = await FoodStyle.confirm(
      context,
      title: 'Delete this record?',
      action: 'Delete',
      message:
          '${FoodStyle.meals[record.mealType]} · ${FoodStyle.date(record.eatenAt)}\nThis will remove all foods in this record.',
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _deleting = record.id;
      _error = null;
    });
    try {
      await AppNavigationScope.whileBusy(
        context,
        () => widget.service.delete(record.id),
      );
      if (mounted) {
        setState(() => _records.removeWhere((item) => item.id == record.id));
      }
    } on FoodException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not delete this record. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = null);
    }
  }

  List<FoodRecord> get _visibleRecords => _filter == 'Activity'
      ? []
      : sortFoodHistory(
          _records.where((record) {
            final date = record.eatenAt;
            return date.year == _date.year &&
                date.month == _date.month &&
                date.day == _date.day;
          }),
        );

  void _changeDate(int days) => setState(() {
    _date = DateTime(_date.year, _date.month, _date.day + days);
  });

  Future<void> _pickDate() async {
    var selected = _date;
    final confirmed = await FoodStyle.picker(
      context,
      title: 'Date',
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: _date,
        minimumYear: 1900,
        onDateTimeChanged: (date) => selected = date,
      ),
    );
    if (mounted && confirmed == true) {
      setState(
        () => _date = DateTime(selected.year, selected.month, selected.day),
      );
    }
  }

  void _back() {
    if (_deleting != null) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil(
        (route) => route.settings.name == FoodPage.routeName || route.isFirst,
      );
    } else {
      _add();
    }
  }

  void _add() => Navigator.of(context).pushReplacement<void, void>(
    CupertinoPageRoute(
      settings: const RouteSettings(name: FoodPage.routeName),
      builder: (_) => FoodPage(service: widget.service),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final records = _visibleRecords;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final busy = _deleting != null;
    return FoodStyle.theme(
      PopScope(
        canPop: !busy,
        child: CupertinoPageScaffold(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    FoodHeader(
                      title: 'History',
                      centerTitle: true,
                      subtitle: 'Your saved food and activity',
                      showHistory: false,
                      backEnabled: !busy,
                      onBack: _back,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _dayButton(
                                'history-previous-day',
                                CupertinoIcons.chevron_left,
                                'Previous day',
                                busy ? null : () => _changeDate(-1),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: CupertinoButton(
                                  key: const Key('history-date'),
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 12,
                                  ),
                                  onPressed: busy ? null : _pickDate,
                                  child: Text(
                                    '${weekdays[_date.weekday - 1]}, ${FoodStyle.today(_date)}${_date.year == DateTime.now().year ? '' : ' ${_date.year}'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: FoodStyle.ink,
                                    ),
                                  ),
                                ),
                              ),
                              _dayButton(
                                'history-next-day',
                                CupertinoIcons.chevron_right,
                                'Next day',
                                busy ? null : () => _changeDate(1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (final filter in [
                                'All',
                                'Food',
                                'Activity',
                              ]) ...[
                                if (filter != 'All') const SizedBox(width: 8),
                                Expanded(
                                  child: Semantics(
                                    selected: _filter == filter,
                                    child: CupertinoButton(
                                      key: Key(
                                        'history-filter-${filter.toLowerCase()}',
                                      ),
                                      color: _filter == filter
                                          ? FoodStyle.green
                                          : FoodStyle.pale,
                                      borderRadius: BorderRadius.circular(11),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      onPressed: busy
                                          ? null
                                          : () => setState(
                                              () => _filter = filter,
                                            ),
                                      child: Text(
                                        filter,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _filter == filter
                                              ? CupertinoColors.white
                                              : FoodStyle.forest,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          CupertinoSliverRefreshControl(
                            onRefresh: busy ? null : _load,
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                            sliver: SliverList.list(
                              children: [
                                if (_loading)
                                  const Center(
                                    child: CupertinoActivityIndicator(),
                                  ),
                                if (_error != null) ...[
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _error!,
                                      key: const Key('history-error'),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: CupertinoColors.destructiveRed,
                                      ),
                                    ),
                                  ),
                                  CupertinoButton(
                                    onPressed: _loading || busy ? null : _load,
                                    child: const Text('Try again'),
                                  ),
                                ],
                                if (!_loading && _error == null) ...[
                                  Text(
                                    '${records.length} ${records.length == 1 ? 'record' : 'records'}',
                                    key: const Key('history-count'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: FoodStyle.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (records.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: FoodStyle.card(
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                              _filter == 'Activity'
                                                  ? 'No activity records yet.'
                                                  : 'No food records for this day.',
                                              style: const TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _filter == 'Activity'
                                                  ? 'Your saved activities will appear here.'
                                                  : 'Choose another date or add a record.',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: FoodStyle.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                                if (!_loading)
                                  for (final record in records)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _recordCard(record),
                                    ),
                                const SizedBox(height: 2),
                                CupertinoButton(
                                  key: const Key('history-add-record'),
                                  color: FoodStyle.pale,
                                  borderRadius: BorderRadius.circular(11),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  onPressed: busy ? null : _add,
                                  child: const Text(
                                    '+ Add record',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: FoodStyle.forest,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!AppNavigationScope.isPresent(context))
                      FoodNavigation(
                        highlightAdd: false,
                        onAdd: busy ? null : _add,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayButton(
    String id,
    IconData icon,
    String label,
    VoidCallback? onPressed,
  ) => CupertinoButton(
    key: Key(id),
    color: FoodStyle.pale,
    borderRadius: BorderRadius.circular(11),
    padding: const EdgeInsets.all(12),
    onPressed: onPressed,
    child: Icon(icon, size: 14, semanticLabel: label, color: FoodStyle.forest),
  );

  Widget _recordCard(FoodRecord record) => FoodStyle.card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                FoodStyle.meals[record.mealType] ?? record.mealType,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const Text(
              'Food',
              style: TextStyle(fontSize: 12, color: FoodStyle.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in record.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    item.name,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(
                    item.amount,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: FoodStyle.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          '${FoodStyle.today(record.eatenAt)} · ${record.timeSpecified ? FoodStyle.time(record.eatenAt) : 'Time not specified'}',
          style: const TextStyle(fontSize: 11, color: FoodStyle.muted),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _recordAction(
                'Edit',
                _deleting == null ? () => _edit(record) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _recordAction(
                _deleting == record.id ? 'Deleting…' : 'Delete',
                _deleting == null ? () => _delete(record) : null,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _recordAction(String label, VoidCallback? onPressed) =>
      CupertinoButton(
        color: FoodStyle.pale,
        borderRadius: BorderRadius.circular(11),
        padding: const EdgeInsets.symmetric(vertical: 12),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: FoodStyle.forest,
          ),
        ),
      );
}
