import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../activity/activity_details.dart';
import '../activity/activity_editor.dart';
import '../activity/activity_record.dart';
import '../shared/food_chrome.dart';
import '../shared/app_navigation_scope.dart';
import 'food_chat.dart';
import 'food_chat_store.dart';
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
    this.now = DateTime.now,
  });
  final FoodService service;
  final FoodRecord? initialRecord;
  final bool startWithActivity;
  final DateTime Function() now;
  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> with WidgetsBindingObserver {
  final _description = TextEditingController();
  final _chatScroll = ScrollController();
  final _chat = <FoodChatTurn>[];
  final _activityDescription = TextEditingController();
  final _activityChatScroll = ScrollController();
  final _activityChat = <ActivityChatTurn>[];
  late DateTime _chatDay;
  Timer? _midnight;
  FoodChatStore? _chatStore;
  bool _loadingChat = false;
  bool _editingRecord = false;
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
  bool _showFoodExample = true;
  bool _showActivityExample = true;
  String? _activityParseError;
  String? _parseError;
  bool get _busy => _saving || _parsing || _loadingChat;

  FoodChatTurn? get _pendingTurn {
    final last = _chat.lastOrNull;
    return last?.saved == null ? last : null;
  }

  ActivityChatTurn? get _pendingActivityTurn {
    final last = _activityChat.lastOrNull;
    return last?.saved == null ? last : null;
  }

  bool get _hasDraft => _activityMode ? _activityDraft != null : _draft != null;

  @override
  void initState() {
    super.initState();
    _description.addListener(_hideFoodExample);
    _activityDescription.addListener(_hideActivityExample);
    _draft = widget.initialRecord;
    _activityMode = widget.startWithActivity && widget.initialRecord == null;
    _chatDay = _localDay(widget.now());
    if (widget.initialRecord == null) {
      WidgetsBinding.instance.addObserver(this);
      _scheduleChatReset();
      final email = widget.service.accountEmail;
      if (email != null) {
        _loadingChat = true;
        unawaited(_restoreChat(email));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    _description.dispose();
    _chatScroll.dispose();
    _activityDescription.dispose();
    _activityChatScroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _resetChatIfNewDay();
    _scheduleChatReset();
  }

  static DateTime _localDay(DateTime now) =>
      DateTime(now.year, now.month, now.day);

  void _scheduleChatReset() {
    _midnight?.cancel();
    final now = widget.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(midnight.difference(now), () {
      _resetChatIfNewDay();
      _scheduleChatReset();
    });
  }

  void _resetChatIfNewDay() {
    if (widget.initialRecord != null ||
        _busy ||
        _editingRecord ||
        _askingToDiscard) {
      return;
    }
    final day = _localDay(widget.now());
    if (day == _chatDay) return;
    _description.clear();
    _activityDescription.clear();
    setState(() {
      if (_pendingActivityTurn != null) {
        _activityDraft = null;
        _activityError = null;
      }
      if (_pendingTurn != null) {
        _draft = null;
        _error = null;
      }
      _chatDay = day;
      _chat.clear();
      _parseError = null;
      _showFoodExample = true;
      _activityChat.clear();
      _activityParseError = null;
      _showActivityExample = true;
    });
    _persistChat();
  }

  Future<void> _restoreChat(String email) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      final day = _localDay(widget.now());
      final store = FoodChatStore(preferences, email);
      final restored = store.read(day);
      setState(() {
        _chatStore = store;
        _chatDay = day;
        if (restored != null) {
          _showFoodExample = restored.showExample;
          _chat.addAll(restored.turns);
          _showActivityExample = restored.showActivityExample;
          _activityChat.addAll(restored.activityTurns);
        }
      });
      if (restored == null) _persistChat();
      if (_chat.isNotEmpty) _scrollToLatestTurn();
    } catch (error) {
      debugPrint(
        'Could not restore the Food chat session: ${error.runtimeType}',
      );
    } finally {
      if (mounted) {
        setState(() => _loadingChat = false);
        _resetChatIfNewDay();
      }
    }
  }

  void _persistChat() {
    unawaited(
      _chatStore?.save(
        _chatDay,
        showExample: _showFoodExample,
        turns: _chat,
        showActivityExample: _showActivityExample,
        activityTurns: _activityChat,
      ),
    );
  }

  void _hideFoodExample() {
    if (!_showFoodExample || _description.text.trim().isEmpty) return;
    setState(() => _showFoodExample = false);
    _persistChat();
  }

  void _hideActivityExample() {
    if (!_showActivityExample || _activityDescription.text.trim().isEmpty) {
      return;
    }
    setState(() => _showActivityExample = false);
    _persistChat();
  }

  Future<void> _submitRecord() async {
    _resetChatIfNewDay();
    final activity = _activityMode;
    final input = activity ? _activityDescription : _description;
    final text = input.text.trim();
    if (_busy || text.isEmpty || _hasDraft) return;
    final sentAt = widget.now();
    FocusScope.of(context).unfocus();
    input.clear();
    setState(() {
      if (activity) {
        _activityChat.add(ActivityChatTurn(text, sentAt));
        _activityParseError = null;
      } else {
        _chat.add(FoodChatTurn(text, sentAt));
        _parseError = null;
      }
      _parsing = true;
    });
    _scrollToLatestTurn();

    final minimumWait = Future<void>.delayed(const Duration(seconds: 1));
    final ({FoodDraft? food, ActivityDraft? activity}) parsed;
    try {
      parsed = await AppNavigationScope.whileBusy(context, () async {
        try {
          return await widget.service.parseRecord(
            text,
            sentAt,
            activityMode: activity,
          );
        } finally {
          await minimumWait;
        }
      });
    } on FoodException catch (error) {
      _restoreUnsentText(text, error.message, activity: activity);
      return;
    } catch (_) {
      _restoreUnsentText(
        text,
        'Could not read that record. Try again or add it manually.',
        activity: activity,
      );
      return;
    }
    if (!mounted) return;
    final activityDraft = parsed.activity;
    if (activityDraft != null) {
      if (!activity && _activityDraft != null && _savedActivity == null) {
        _restoreUnsentText(
          text,
          'Finish your current Activity draft before sending another.',
          activity: false,
        );
        return;
      }
      setState(() {
        if (!activity) {
          _chat.removeLast();
          _activityChat.add(ActivityChatTurn(text, sentAt));
          _activityMode = true;
          _showActivityExample = false;
        }
        _savedActivity = null;
        _activityDraft = activityDraft;
        _activityError = null;
        _activityParseError = null;
        _parsing = false;
      });
      _persistChat();
    } else {
      if (activity && _draft != null && _saved == null) {
        _restoreUnsentText(
          text,
          'Finish your current Food draft before sending another.',
          activity: true,
        );
        return;
      }
      setState(() {
        if (activity) {
          _activityChat.removeLast();
          _chat.add(FoodChatTurn(text, sentAt));
          _activityMode = false;
          _showFoodExample = false;
        }
        _saved = null;
        _draft = parsed.food!;
        _error = null;
        _parseError = null;
        _parsing = false;
      });
      if (activity) _persistChat();
    }
    _resetChatIfNewDay();
    _scrollToLatestTurn();
    if (!_activityMode &&
        _pendingTurn != null &&
        !FoodStyle.meals.containsKey(_draft!.mealType)) {
      await _edit();
    }
  }

  void _restoreUnsentText(String text, String error, {required bool activity}) {
    if (!mounted) return;
    (activity ? _activityDescription : _description).text = text;
    setState(() {
      if (activity) {
        _activityChat.removeLast();
        _activityParseError = error;
      } else {
        _chat.removeLast();
        _parseError = error;
      }
      _parsing = false;
    });
    _resetChatIfNewDay();
  }

  void _scrollToLatestTurn() {
    final scroll = _activityMode ? _activityChatScroll : _chatScroll;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      final position = scroll.position;
      if (position.extentAfter == 0) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        position.jumpTo(position.maxScrollExtent);
      } else {
        position.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _edit({FoodChatTurn? savedTurn}) async {
    if (_busy || _editingRecord) return;
    _editingRecord = true;
    try {
      final turn = savedTurn ?? _pendingTurn;
      final existing = turn?.saved;
      FoodRecord? saved;
      final draft = await Navigator.of(context).push<FoodDraft>(
        CupertinoPageRoute(
          builder: (_) => FoodEditor(
            initialDraft: existing ?? _draft,
            service: widget.service,
            submitLabel: turn != null && existing == null ? 'Confirm' : null,
            onSave: turn == null
                ? null
                : (edited) async {
                    saved = await widget.service.save(edited, id: existing?.id);
                  },
          ),
        ),
      );
      if (!mounted || draft == null) return;
      setState(() {
        if (turn == null) {
          _draft = draft;
          _saved = null;
        } else {
          turn.saved = saved!;
          if (existing == null) _draft = null;
        }
        if (existing == null) {
          _error = null;
          _parseError = null;
        }
      });
      if (turn != null) _persistChat();
    } finally {
      _editingRecord = false;
      if (mounted) _resetChatIfNewDay();
    }
  }

  Future<void> _confirm() async {
    final draft = _draft;
    final turn = _pendingTurn;
    if (_busy || draft == null || _saved != null) return;
    if (turn != null && !FoodStyle.meals.containsKey(draft.mealType)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await AppNavigationScope.whileBusy(
        context,
        () => widget.service.save(draft, id: widget.initialRecord?.id),
      );
      if (mounted) {
        setState(() {
          if (turn == null) {
            _saved = saved;
            _draft = saved;
          } else {
            turn.saved = saved;
            _draft = null;
          }
        });
        if (turn != null) _persistChat();
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
      if (mounted) {
        setState(() => _saving = false);
        _resetChatIfNewDay();
      }
    }
  }

  Future<void> _history({DateTime? date}) async {
    if (widget.initialRecord != null) {
      Navigator.of(context).pop(_saved != null);
      return;
    }
    final activityMode = _activityMode;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute(
        builder: (_) => FoodHistoryPage(
          service: widget.service,
          initialDate:
              date ??
              (activityMode
                  ? (_activityDraft ?? _activityChat.lastOrNull?.saved)
                        ?.occurredAt
                  : (_saved ?? _draft ?? _chat.lastOrNull?.saved)?.eatenAt),
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
      } else if (_pendingActivityTurn != null) {
        _discardDraft(activity: true);
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
      _discardDraft();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _discardDraft({bool activity = false}) async {
    if (_askingToDiscard) return;
    _askingToDiscard = true;
    try {
      final discard = await FoodStyle.confirm(
        context,
        title: 'Discard this draft?',
        message:
            'This will clear your unsaved ${activity ? 'activity' : 'food'} record.',
        action: 'Discard',
        cancelLabel: 'Keep draft',
      );
      if (!mounted || discard != true) return;
      (activity ? _activityDescription : _description).clear();
      setState(() {
        if (activity) {
          _activityChat.removeLast();
          _activityDraft = null;
          _activityError = null;
          _activityParseError = null;
        } else {
          if (_pendingTurn != null) _chat.removeLast();
          _draft = null;
          _error = null;
          _parseError = null;
        }
      });
    } finally {
      _askingToDiscard = false;
      if (mounted) _resetChatIfNewDay();
    }
  }

  Future<void> _editActivity({ActivityChatTurn? savedTurn}) async {
    if (_busy || _editingRecord) return;
    _editingRecord = true;
    try {
      final turn = savedTurn ?? _pendingActivityTurn;
      final existing = turn?.saved;
      ActivityRecord? saved;
      final draft = await Navigator.of(context).push<ActivityDraft>(
        CupertinoPageRoute(
          builder: (_) => ActivityEditor(
            initialDraft: existing ?? _activityDraft,
            submitLabel: turn != null && existing == null ? 'Confirm' : null,
            onSave: turn == null
                ? null
                : (edited) async {
                    saved = await widget.service.saveActivity(
                      edited,
                      id: existing?.id,
                    );
                  },
          ),
        ),
      );
      if (!mounted || draft == null) return;
      setState(() {
        if (turn == null) {
          _activityDraft = draft;
          _savedActivity = null;
        } else {
          turn.saved = saved!;
          if (existing == null) _activityDraft = null;
        }
        if (existing == null) {
          _activityError = null;
          _activityParseError = null;
        }
      });
      if (turn != null) _persistChat();
    } finally {
      _editingRecord = false;
      if (mounted) _resetChatIfNewDay();
    }
  }

  Future<void> _confirmActivity() async {
    final draft = _activityDraft;
    final turn = _pendingActivityTurn;
    if (_busy ||
        draft == null ||
        draft.durationMinutes == null ||
        _savedActivity != null) {
      return;
    }
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
          if (turn == null) {
            _savedActivity = saved;
            _activityDraft = saved;
          } else {
            turn.saved = saved;
            _activityDraft = null;
          }
        });
        if (turn != null) _persistChat();
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
      if (mounted) {
        setState(() => _saving = false);
        _resetChatIfNewDay();
      }
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
    final showChat =
        !_activityMode &&
        widget.initialRecord == null &&
        (record == null || _pendingTurn != null);
    final showActivityChat =
        _activityMode &&
        (_activityDraft == null || _pendingActivityTurn != null);
    final pending = _activityMode
        ? _pendingActivityTurn != null
        : _pendingTurn != null;
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
                      subtitle: 'Today, ${FoodStyle.today(_chatDay)}',
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
                            : _selectMode,
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        key: PageStorageKey((
                          _activityMode,
                          saved,
                          showChat,
                          showActivityChat,
                        )),
                        controller: showActivityChat
                            ? _activityChatScroll
                            : showChat
                            ? _chatScroll
                            : null,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
                        children: _activityMode
                            ? (showActivityChat
                                  ? _activityInput()
                                  : _activityReview(_activityDraft!))
                            : (showChat ? _foodChat() : _review(record!)),
                      ),
                    ),
                    FoodComposer(
                      activity: _activityMode,
                      saved: _savedActivity != null,
                      showExample:
                          !_loadingChat &&
                          (_activityMode
                              ? _showActivityExample
                              : _showFoodExample),
                      controller: showActivityChat
                          ? _activityDescription
                          : showChat
                          ? _description
                          : null,
                      onSubmit: !_busy && !pending ? _submitRecord : null,
                      error: _activityMode ? _activityParseError : _parseError,
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

  void _selectMode(bool activity) {
    if (_activityMode == activity) return;
    FocusScope.of(context).unfocus();
    setState(() => _activityMode = activity);
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
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 22,
              height: 1.2,
            ),
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
    if (_activityChat.isEmpty && !_loadingChat)
      ..._examples(_activityDescription, const [
        'I went jogging for 30 minutes.',
        'I walked for 20 minutes yesterday.',
      ]),
    FoodStyle.secondary(
      key: const Key('add-activity-manually'),
      label: 'Add manually',
      onPressed: _busy || _pendingActivityTurn != null ? null : _editActivity,
    ),
    for (final turn in _activityChat)
      _chatTurn(turn, () => _activityChatCard(turn)),
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
              _activityActions(record),
          ],
        ),
      ),
    ];
  }

  Widget _activityActions(ActivityDraft record) => Row(
    children: [
      Expanded(
        child: FoodStyle.secondary(
          label: 'Edit',
          onPressed: _busy ? null : _editActivity,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: FoodStyle.primary(
          key: const Key('confirm-activity'),
          onPressed: _busy || record.durationMinutes == null
              ? null
              : _confirmActivity,
          child: _saving
              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
              : const Text('Confirm'),
        ),
      ),
    ],
  );

  Widget _activityChatCard(ActivityChatTurn turn) {
    final saved = turn.saved;
    final record = saved ?? _activityDraft!;
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(record.name, style: const TextStyle(fontSize: 16)),
            ),
            if (saved != null)
              const FoodSavedBadge()
            else
              const Text(
                'Activity',
                style: TextStyle(color: FoodStyle.muted, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ActivityDetails(record: record, showName: false),
      ],
    );
    if (saved != null) {
      return _savedChatCard(
        id: 'activity-${saved.id}',
        status: '✓ Your activity has been saved.',
        summary: summary,
        onEdit: () => _editActivity(savedTurn: turn),
        onHistory: () => _history(date: saved.occurredAt),
      );
    }
    return FoodStyle.card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          summary,
          if (_activityError case final error?)
            Text(
              error,
              style: const TextStyle(
                color: CupertinoColors.destructiveRed,
                fontSize: 13,
              ),
            ),
          if (record.durationMinutes == null)
            const Text(
              'Tap Edit to add the duration.',
              style: TextStyle(color: FoodStyle.muted, fontSize: 12),
            ),
          const SizedBox(height: 12),
          _activityActions(record),
        ],
      ),
    );
  }

  List<Widget> _foodChat() => [
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
    if (_chat.isEmpty && !_loadingChat)
      ..._examples(_description, const [
        'I ate 1 bowl of porridge with milk,\nblueberries and a banana for breakfast.',
        'I had a sandwich and an apple\nfor lunch.',
      ]),
    CupertinoButton(
      key: const Key('add-manually'),
      color: FoodStyle.pale,
      borderRadius: BorderRadius.circular(11),
      onPressed: _busy || _pendingTurn != null ? null : _edit,
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
    for (final turn in _chat) _chatTurn(turn, () => _chatCard(turn)),
  ];

  Widget _chatTurn<T>(RecordChatTurn<T> turn, Widget Function() card) {
    final pending = turn.saved == null;
    return Padding(
      key: ObjectKey(turn),
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FoodMessageBubble(
            message: turn.message,
            sentAt: turn.sentAt,
            animate: pending,
          ),
          const SizedBox(height: 12),
          if (_parsing && pending)
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: FoodTypingIndicator(),
            )
          else
            FoodChatAppearance(distance: 8, animate: pending, child: card()),
        ],
      ),
    );
  }

  Widget _chatCard(FoodChatTurn turn) {
    final saved = turn.saved;
    if (saved == null) return _foodCard(_draft!, saved: false, inChat: true);
    final meal = FoodStyle.meals[saved.mealType] ?? saved.mealType;
    return _savedChatCard(
      id: 'food-${saved.id}',
      status: '✓ Your ${meal.toLowerCase()} has been saved.',
      summary: RecordSummary(
        record: saved,
        saved: true,
        showTime: true,
        inChat: true,
      ),
      onEdit: () => _edit(savedTurn: turn),
      onHistory: () => _history(date: saved.eatenAt),
    );
  }

  Widget _savedChatCard({
    required String id,
    required String status,
    required Widget summary,
    required VoidCallback onEdit,
    required VoidCallback onHistory,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        liveRegion: true,
        child: Text(
          status,
          style: const TextStyle(color: FoodStyle.forest, fontSize: 13),
        ),
      ),
      const SizedBox(height: 10),
      FoodStyle.card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              hint: 'Opens the record editor',
              child: CupertinoButton(
                key: ValueKey('edit-saved-$id'),
                padding: EdgeInsets.zero,
                onPressed: _busy ? null : onEdit,
                child: summary,
              ),
            ),
            const SizedBox(height: 8),
            FoodStyle.primary(
              key: ValueKey('history-saved-$id'),
              onPressed: _busy ? null : onHistory,
              child: const Text('View history'),
            ),
          ],
        ),
      ),
    ],
  );

  List<Widget> _examples(
    TextEditingController controller,
    List<String> examples,
  ) => [
    const Text(
      'Try an example',
      style: TextStyle(fontSize: 13, color: FoodStyle.muted),
    ),
    for (final text in examples) ...[
      const SizedBox(height: 10),
      _example(text, controller),
    ],
    const SizedBox(height: 18),
    const Text(
      'Your words become a record you can review.',
      style: TextStyle(color: FoodStyle.muted, fontSize: 12),
    ),
    const SizedBox(height: 10),
  ];

  Widget _example(String text, TextEditingController controller) =>
      CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _busy
            ? null
            : () => controller.text = text.replaceAll('\n', ' '),
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
    _foodCard(record, saved: _saved != null),
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

  Widget _foodCard(
    FoodDraft record, {
    required bool saved,
    bool inChat = false,
  }) => FoodStyle.card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecordSummary(
          record: record,
          saved: saved,
          showTime: true,
          inChat: inChat,
        ),
        if (!saved || !inChat) const SizedBox(height: 16),
        if (!saved && _error != null) ...[
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
        if (!saved)
          Row(
            children: [
              Expanded(
                child: FoodStyle.secondary(
                  label: 'Edit',
                  onPressed: _saving ? null : _edit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FoodStyle.primary(
                  key: const Key('confirm-record'),
                  onPressed:
                      _saving ||
                          (inChat &&
                              !FoodStyle.meals.containsKey(record.mealType))
                      ? null
                      : _confirm,
                  child: _saving
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                        )
                      : const Text('Confirm'),
                ),
              ),
            ],
          )
        else if (!inChat)
          FoodStyle.primary(
            onPressed: _history,
            child: const Text('View history'),
          ),
      ],
    ),
  );
}

class RecordSummary extends StatelessWidget {
  const RecordSummary({
    super.key,
    required this.record,
    this.saved = false,
    this.showTime = false,
    this.inChat = false,
  });
  final FoodDraft record;
  final bool saved;
  final bool showTime;
  final bool inChat;

  String get _dateAndTime {
    final time = record.timeSpecified
        ? FoodStyle.time(record.eatenAt)
        : 'Time not specified';
    return '${FoodStyle.date(record.eatenAt)} · $time';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              FoodStyle.meals[record.mealType] ??
                  (record.mealType.isEmpty
                      ? 'Meal not specified'
                      : record.mealType),
              style: const TextStyle(fontSize: 16, color: FoodStyle.ink),
            ),
          ),
          Expanded(
            flex: 2,
            child: saved && inChat
                ? const FoodSavedBadge()
                : Text(
                    saved
                        ? '✓ Saved'
                        : inChat
                        ? 'Food'
                        : showTime
                        ? _dateAndTime
                        : FoodStyle.recordDate(record.eatenAt),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: FoodStyle.muted,
                      fontSize: 12,
                    ),
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
                  saved && inChat && item.quantity == null
                      ? 'Add amount'
                      : item.amount,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: FoodStyle.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      if (inChat) ...[
        const SizedBox(height: 4),
        Text(
          _dateAndTime,
          style: const TextStyle(color: FoodStyle.muted, fontSize: 12),
        ),
      ],
      if ((!saved || inChat) &&
          record.items.any((item) => item.quantity == null)) ...[
        const SizedBox(height: 8),
        Text(
          saved
              ? "${record.items.where((item) => item.quantity == null).map((item) => item.name).join(' & ')}: amounts not provided."
              : 'Add missing amounts if you know them.',
          style: const TextStyle(
            color: FoodStyle.muted,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    ],
  );
}
