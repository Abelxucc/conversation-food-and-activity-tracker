import 'package:flutter/cupertino.dart';

import '../activity/activity_details.dart';
import '../activity/activity_editor.dart';
import '../activity/activity_record.dart';
import '../shared/food_chrome.dart';
import '../shared/app_navigation_scope.dart';
import 'food_editor.dart';
import '../history/food_history_page.dart';
import 'food_service.dart';
import '../shared/food_style.dart';

class FoodPage extends StatefulWidget {
  static const routeName = '/food/add-record';

  const FoodPage({
    super.key,
    required this.service,
    this.initialRecord,
    this.startWithActivity = false,
  });
  final FoodService service;
  final FoodRecord? initialRecord;
  final bool startWithActivity;
  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  final _description = TextEditingController();
  FoodDraft? _draft;
  FoodRecord? _saved;
  String? _error;
  ActivityDraft? _activityDraft;
  ActivityRecord? _savedActivity;
  String? _activityError;
  late bool _activityMode;
  bool _saving = false;
  bool _parsing = false;
  bool _askingToDiscard = false;
  String? _parseError;
  bool get _busy => _saving || _parsing;

  bool get _hasDraft => _activityMode ? _activityDraft != null : _draft != null;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialRecord;
    _activityMode = widget.startWithActivity && widget.initialRecord == null;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _parseFood() async {
    final text = _description.text.trim();
    if (_busy || text.isEmpty || _activityMode || _hasDraft) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _parsing = true;
      _parseError = null;
    });
    FoodDraft? draft;
    try {
      draft = await AppNavigationScope.whileBusy(
        context,
        () => widget.service.parseFood(text, DateTime.now()),
      );
    } on FoodException catch (error) {
      if (mounted) setState(() => _parseError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _parseError =
              'Could not read that record. Try again or add it manually.',
        );
      }
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
    if (!mounted || draft == null) return;
    if (draft.mealType.isEmpty) {
      await _edit(initialDraft: draft);
    } else {
      setState(() => _draft = draft);
    }
    if (mounted && _draft != null) _description.clear();
  }

  Future<void> _edit({FoodDraft? initialDraft}) async {
    if (_busy) return;
    final draft = await Navigator.of(context).push<FoodDraft>(
      CupertinoPageRoute(
        builder: (_) => FoodEditor(
          initialDraft: initialDraft ?? _draft,
          service: widget.service,
        ),
      ),
    );
    if (mounted && draft != null) {
      setState(() {
        _draft = draft;
        _saved = null;
        _error = null;
      });
    }
  }

  Future<void> _confirm() async {
    if (_saving || _draft == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await AppNavigationScope.whileBusy(
        context,
        () => widget.service.save(_draft!, id: widget.initialRecord?.id),
      );
      if (mounted) {
        setState(() {
          _saved = saved;
          _draft = saved;
        });
      }
    } on FoodException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Something went wrong. Your draft is still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _history() async {
    if (widget.initialRecord != null) {
      Navigator.of(context).pop(_saved != null);
      return;
    }
    final activityMode = _activityMode;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute(
        builder: (_) => FoodHistoryPage(
          service: widget.service,
          initialDate: activityMode
              ? _activityDraft?.occurredAt
              : (_saved ?? _draft)?.eatenAt,
          initialFilter: activityMode
              ? HistoryFilter.activity
              : HistoryFilter.all,
        ),
      ),
    );
    if (!mounted) return;
    if (activityMode) {
      if (_savedActivity != null) _resetActivity();
    } else if (_saved != null) {
      setState(() {
        _draft = null;
        _saved = null;
        _error = null;
      });
    }
  }

  void _back() {
    if (_busy) return;
    if (_activityMode) {
      if (_savedActivity != null) {
        _resetActivity();
      } else if (_activityDraft != null) {
        _editActivity();
      } else {
        Navigator.of(context).maybePop();
      }
      return;
    }
    if (widget.initialRecord != null) {
      Navigator.of(context).pop(_saved != null);
    } else if (_saved != null) {
      setState(() {
        _saved = null;
        _draft = null;
        _error = null;
      });
    } else if (_draft != null) {
      _discardFoodDraft();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _discardFoodDraft() async {
    if (_askingToDiscard) return;
    _askingToDiscard = true;
    try {
      final discard = await FoodStyle.confirm(
        context,
        title: 'Discard this draft?',
        message: 'This will clear your unsaved food record.',
        action: 'Discard',
        cancelLabel: 'Keep draft',
      );
      if (!mounted || discard != true) return;
      _description.clear();
      setState(() {
        _draft = null;
        _error = null;
        _parseError = null;
      });
    } finally {
      _askingToDiscard = false;
    }
  }

  Future<void> _editActivity() async {
    final draft = await Navigator.of(context).push<ActivityDraft>(
      CupertinoPageRoute(
        builder: (_) => ActivityEditor(initialDraft: _activityDraft),
      ),
    );
    if (!mounted || draft == null) return;
    setState(() {
      _activityDraft = draft;
      _savedActivity = null;
      _activityError = null;
    });
  }

  Future<void> _confirmActivity() async {
    final draft = _activityDraft;
    if (_saving || draft == null || _savedActivity != null) return;
    setState(() {
      _saving = true;
      _activityError = null;
    });
    try {
      final saved = await AppNavigationScope.whileBusy(
        context,
        () => widget.service.saveActivity(draft),
      );
      if (mounted) {
        setState(() {
          _savedActivity = saved;
          _activityDraft = saved;
        });
      }
    } on FoodException catch (error) {
      if (mounted) setState(() => _activityError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _activityError =
              'Could not save your activity. Your draft is still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetActivity() => setState(() {
    _activityDraft = null;
    _savedActivity = null;
    _activityError = null;
  });

  @override
  Widget build(BuildContext context) {
    final record = _saved ?? _draft;
    final saved = _activityMode ? _savedActivity != null : _saved != null;
    return FoodStyle.theme(
      PopScope(
        canPop: !_busy && widget.initialRecord != null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_busy && _hasDraft) _back();
        },
        child: CupertinoPageScaffold(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    FoodHeader(
                      title: widget.initialRecord == null
                          ? 'Add record'
                          : 'Edit record',
                      onHistory: _busy ? null : _history,
                      backEnabled: !_busy,
                      showBack: _hasDraft || widget.initialRecord != null,
                      onBack: _back,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: FoodModeSelector(
                        activity: _activityMode,
                        onChanged: _busy || widget.initialRecord != null
                            ? null
                            : (activity) =>
                                  setState(() => _activityMode = activity),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        key: ValueKey((_activityMode, saved)),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
                        children: _activityMode
                            ? (_activityDraft == null
                                  ? _activityInput()
                                  : _activityReview(_activityDraft!))
                            : (record == null ? _input() : _review(record)),
                      ),
                    ),
                    FoodComposer(
                      activity: _activityMode,
                      saved: _savedActivity != null,
                      controller: !_activityMode && record == null
                          ? _description
                          : null,
                      onSubmit: _parseFood,
                      busy: _parsing,
                      error: !_activityMode && record == null
                          ? _parseError
                          : null,
                    ),
                    if (!AppNavigationScope.isPresent(context))
                      const FoodNavigation(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _activityInput() => [
    Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: FoodStyle.forest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What did you do today?',
            style: TextStyle(color: CupertinoColors.white, fontSize: 22),
          ),
          SizedBox(height: 12),
          Text(
            'Log your activity and review the details before saving.',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    FoodStyle.secondary(
      key: const Key('add-activity-manually'),
      label: 'Add manually',
      onPressed: _editActivity,
    ),
  ];

  List<Widget> _activityReview(ActivityDraft record) {
    final saved = _savedActivity != null;
    return [
      FoodStyle.card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              saved ? 'Activity saved ✓' : 'Review activity',
              style: const TextStyle(fontSize: 21, color: FoodStyle.forest),
            ),
            const SizedBox(height: 8),
            Text(
              saved
                  ? 'Your activity is in your history.'
                  : 'Check the details before saving.',
              style: const TextStyle(fontSize: 13, color: FoodStyle.muted),
            ),
            const SizedBox(height: 6),
            ActivityDetails(record: record),
            const SizedBox(height: 12),
            if (_activityError != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  _activityError!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.destructiveRed,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (saved) ...[
              FoodStyle.primary(
                onPressed: _history,
                child: const Text(
                  'View history',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 10),
              FoodStyle.secondary(
                label: 'Add another',
                onPressed: _resetActivity,
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: FoodStyle.secondary(
                      label: 'Edit',
                      onPressed: _saving ? null : _editActivity,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FoodStyle.primary(
                      key: const Key('confirm-activity'),
                      onPressed: _saving ? null : _confirmActivity,
                      child: _saving
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : const Text(
                              'Confirm',
                              style: TextStyle(fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _input() => [
    Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: FoodStyle.forest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What did you eat today?',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 22,
              height: 1.2,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Tell me in your own words.\nYou can edit the details before saving.',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    const Text(
      'Try an example',
      style: TextStyle(fontSize: 13, color: FoodStyle.muted),
    ),
    const SizedBox(height: 10),
    _example(
      'I ate 1 bowl of porridge with milk,\nblueberries and a banana for breakfast.',
    ),
    const SizedBox(height: 10),
    _example('I had a sandwich and an apple\nfor lunch.'),
    const SizedBox(height: 18),
    const Text(
      'Your words become a record you can review.',
      style: TextStyle(color: FoodStyle.muted, fontSize: 12),
    ),
    const SizedBox(height: 10),
    CupertinoButton(
      key: const Key('add-manually'),
      color: FoodStyle.pale,
      borderRadius: BorderRadius.circular(11),
      onPressed: _busy ? null : _edit,
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: const Text(
        'Add manually',
        style: TextStyle(
          fontSize: 15,
          color: FoodStyle.forest,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ];

  Widget _example(String text) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: _busy
        ? null
        : () => _description.text = text.replaceAll('\n', ' '),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      decoration: BoxDecoration(
        color: FoodStyle.surface,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: FoodStyle.forest,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            CupertinoIcons.arrow_up_right,
            size: 17,
            color: FoodStyle.forest,
          ),
        ],
      ),
    ),
  );

  List<Widget> _review(FoodDraft record) => [
    Text(
      _saved != null
          ? '✓ Your food record has been saved.'
          : 'Here’s your record. Does it look right?',
      key: const Key('record-status'),
      style: const TextStyle(
        color: FoodStyle.forest,
        fontSize: 13,
        height: 1.5,
      ),
    ),
    const SizedBox(height: 10),
    FoodStyle.card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecordSummary(record: record, saved: _saved != null, showTime: true),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                key: const Key('save-error'),
                style: const TextStyle(
                  color: CupertinoColors.destructiveRed,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_saved != null)
            FoodStyle.primary(
              onPressed: _history,
              child: const Text('View history'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    color: FoodStyle.pale,
                    borderRadius: BorderRadius.circular(10),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: _saving ? null : _edit,
                    child: const Text(
                      'Edit',
                      style: TextStyle(color: FoodStyle.forest, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FoodStyle.primary(
                    key: const Key('confirm-record'),
                    onPressed: _saving ? null : _confirm,
                    child: _saving
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          )
                        : const Text('Confirm'),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
    if (_saved != null && widget.initialRecord == null) ...[
      const SizedBox(height: 8),
      CupertinoButton(
        onPressed: () => setState(() {
          _draft = null;
          _saved = null;
        }),
        child: const Text('Add another record', style: TextStyle(fontSize: 14)),
      ),
    ],
  ];
}

class RecordSummary extends StatelessWidget {
  const RecordSummary({
    super.key,
    required this.record,
    this.saved = false,
    this.showTime = false,
  });
  final FoodDraft record;
  final bool saved;
  final bool showTime;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              FoodStyle.meals[record.mealType] ?? record.mealType,
              style: const TextStyle(fontSize: 16, color: FoodStyle.ink),
            ),
          ),
          Flexible(
            flex: 2,
            child: Text(
              saved
                  ? '✓ Saved'
                  : showTime
                  ? '${FoodStyle.date(record.eatenAt)} · ${record.timeSpecified ? FoodStyle.time(record.eatenAt) : 'Time not specified'}'
                  : FoodStyle.recordDate(record.eatenAt),
              textAlign: TextAlign.right,
              style: const TextStyle(color: FoodStyle.muted, fontSize: 12),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      for (final item in record.items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  item.name,
                  style: const TextStyle(fontSize: 16, color: FoodStyle.ink),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  item.amount,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: FoodStyle.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      if (record.items.any((item) => item.quantity == null)) ...[
        const SizedBox(height: 8),
        const Text(
          'Add missing amounts if you know them.',
          style: TextStyle(color: FoodStyle.muted, fontSize: 11, height: 1.4),
        ),
      ],
    ],
  );
}
