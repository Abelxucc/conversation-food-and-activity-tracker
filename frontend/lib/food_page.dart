import 'package:flutter/cupertino.dart';

import 'food_chrome.dart';
import 'food_editor.dart';
import 'food_history_page.dart';
import 'food_service.dart';
import 'food_style.dart';

class FoodPage extends StatefulWidget {
  static const routeName = '/food/add-record';

  const FoodPage({super.key, required this.service, this.initialRecord});
  final FoodService service;
  final FoodRecord? initialRecord;
  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  FoodDraft? _draft;
  FoodRecord? _saved;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialRecord;
  }

  Future<void> _edit() async {
    final draft = await Navigator.of(context).push<FoodDraft>(
      CupertinoPageRoute(
        builder: (_) =>
            FoodEditor(initialDraft: _draft, service: widget.service),
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
      final saved = await widget.service.save(
        _draft!,
        id: widget.initialRecord?.id,
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
    await Navigator.of(context).push<void>(
      CupertinoPageRoute(
        builder: (_) => FoodHistoryPage(
          service: widget.service,
          initialDate: (_saved ?? _draft)?.eatenAt,
        ),
      ),
    );
    if (mounted && _saved != null) {
      setState(() {
        _draft = null;
        _saved = null;
        _error = null;
      });
    }
  }

  void _back() {
    if (_saving) return;
    if (widget.initialRecord != null) {
      Navigator.of(context).pop(_saved != null);
    } else if (_saved != null) {
      setState(() {
        _saved = null;
        _draft = null;
        _error = null;
      });
    } else if (_draft != null) {
      _edit();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _saved ?? _draft;
    return FoodStyle.theme(
      PopScope(
        canPop: !_saving && widget.initialRecord != null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_saving && _draft != null) _back();
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
                      onHistory: _saving ? null : _history,
                      backEnabled: !_saving,
                      showBack: _draft != null || widget.initialRecord != null,
                      onBack: _back,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22),
                      child: FoodModeSelector(),
                    ),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
                        children: record == null ? _input() : _review(record),
                      ),
                    ),
                    const FoodComposer(),
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
      onPressed: _edit,
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

  Widget _example(String text) => Semantics(
    enabled: false,
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
