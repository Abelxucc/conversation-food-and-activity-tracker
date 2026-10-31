import 'package:flutter/cupertino.dart';

import 'food_page.dart';
import 'food_service.dart';
import 'food_style.dart';

class FoodHistoryPage extends StatefulWidget {
  const FoodHistoryPage({super.key, required this.service});
  final FoodService service;

  @override
  State<FoodHistoryPage> createState() => _FoodHistoryPageState();
}

class _FoodHistoryPageState extends State<FoodHistoryPage> {
  List<FoodRecord> _records = [];
  bool _loading = true;
  String? _error;
  int? _deleting;

  @override
  void initState() {
    super.initState();
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
    await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) =>
            FoodPage(service: widget.service, initialRecord: record),
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
      await widget.service.delete(record.id);
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

  @override
  Widget build(BuildContext context) => FoodStyle.theme(
    CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Food history'),
        previousPageTitle: 'Record',
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loading || _deleting != null ? null : _load,
          child: const Icon(
            CupertinoIcons.refresh,
            semanticLabel: 'Refresh history',
          ),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: _deleting == null ? _load : null,
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
                  sliver: SliverList.list(
                    children: [
                      const Text(
                        'Your food diary',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Saved meals, ready to revisit.',
                        style: TextStyle(color: FoodStyle.muted, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      if (_loading)
                        const Center(child: CupertinoActivityIndicator()),
                      if (_error != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            key: const Key('history-error'),
                            style: const TextStyle(
                              color: CupertinoColors.destructiveRed,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          onPressed: _loading || _deleting != null
                              ? null
                              : _load,
                          child: const Text('Try again'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (!_loading && _error == null && _records.isEmpty)
                        FoodStyle.card(
                          const Column(
                            children: [
                              Icon(
                                CupertinoIcons.book,
                                size: 38,
                                color: FoodStyle.forest,
                              ),
                              SizedBox(height: 16),
                              Text('No food records yet.'),
                              SizedBox(height: 8),
                              Text(
                                'Add your first meal to start your diary.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: FoodStyle.muted,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      for (final record in _records)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: FoodStyle.card(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                RecordSummary(record: record, showTime: true),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CupertinoButton(
                                        color: FoodStyle.pale,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        onPressed: _deleting == null
                                            ? () => _edit(record)
                                            : null,
                                        child: const Text(
                                          'Edit',
                                          style: TextStyle(
                                            color: FoodStyle.forest,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    CupertinoButton(
                                      onPressed: _deleting == null
                                          ? () => _delete(record)
                                          : null,
                                      child: Text(
                                        _deleting == record.id
                                            ? 'Deleting…'
                                            : 'Delete',
                                        style: const TextStyle(
                                          color: CupertinoColors.destructiveRed,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
