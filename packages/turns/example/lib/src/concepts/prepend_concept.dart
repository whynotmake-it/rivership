import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:turns/scroll.dart';
import 'package:turns_example/src/concepts/concept_page.dart';
import 'package:turns_example/src/shell/turns_shell.dart';

/// A plain [ListView] and a [TurnScrollView] get the same older page
/// prepended; only one keeps what you were reading in place.
class PrependConcept extends StatefulWidget {
  const PrependConcept({super.key});

  @override
  State<PrependConcept> createState() => _PrependConceptState();
}

const _pageSize = 20;
const _firstLoaded = 400;

class _PrependConceptState extends State<PrependConcept> {
  var _first = _firstLoaded;
  var _generation = 0;
  final _listPane = GlobalKey<_PaneState>();
  final _turnPane = GlobalKey<_PaneState>();
  ({double list, double turn})? _shift;
  int? _reference;

  final _code = ValueNotifier(
    '// The same prepend goes to both lists:\n'
    'setState(() => messages = [...olderPage, ...messages]);\n'
    '\n'
    '// ListView keeps its pixels, so everything moves down by the page.\n'
    'ListView.builder(itemCount: messages.length, ...);\n'
    '\n'
    '// TurnScrollView grows older items upward from its center.\n'
    'TurnScrollView(itemCount: messages.length, itemId: ..., ...);',
  );

  Future<void> _loadOlder() async {
    if (_first <= 0) return;
    // What the reader is looking at: the message at the TurnScrollView
    // pane's middle, followed in both panes.
    final reference = _turnPane.currentState?.middleItem();
    if (reference == null) return;
    final extentBefore = _listPane.currentState?.listExtent();
    final before = (
      list: _listPane.currentState?.topOf(reference),
      turn: _turnPane.currentState?.topOf(reference),
    );
    setState(() {
      _first -= _pageSize;
      _reference = reference;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final after = (
      list: _listPane.currentState?.topOf(reference),
      turn: _turnPane.currentState?.topOf(reference),
    );
    double shift(double? a, double? b) =>
        a == null || b == null ? double.nan : b - a;
    final extentAfter = _listPane.currentState?.listExtent();
    var listShift = shift(before.list, after.list);
    if (listShift.isNaN && extentBefore != null && extentAfter != null) {
      // Pushed off screen: it moved by the height the page added above.
      listShift = extentAfter - extentBefore;
    }
    setState(
      () => _shift = (
        list: listShift,
        turn: shift(before.turn, after.turn),
      ),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _first = _firstLoaded;
    _generation++;
    _shift = null;
    _reference = null;
  });

  @override
  Widget build(BuildContext context) {
    final count = 500 - _first;
    String px(double v) =>
        v.isNaN ? 'off screen' : '${v.abs() < 0.5 ? 0 : v.round()} px';
    return ConceptPage(
      routeName: turnsPrependRouteName,
      lead:
          'Both lists show the same chat and get the same page of older '
          'messages. Scroll either one, then load older: the highlighted '
          'message stays put in the TurnScrollView and gets pushed down in '
          'the ListView.',
      controls: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          CoilButton(
            key: const Key('concept.prepend.load'),
            size: CoilSize.compact,
            leading: const Icon(LucideIcons.arrowUpToLine, size: 14),
            onPressed: _first > 0 ? _loadOlder : null,
            child: Text(
              _first > 0 ? 'Load $_pageSize older' : 'All history loaded',
            ),
          ),
          CoilButton(
            variant: CoilButtonVariant.ghost,
            size: CoilSize.compact,
            leading: const Icon(LucideIcons.rotateCcw, size: 14),
            onPressed: _reset,
            child: const Text('Reset'),
          ),
        ],
      ),
      stage: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final panes = [
            Expanded(
              child: _Pane(
                key: _listPane,
                title: 'ListView',
                generation: _generation,
                first: _first,
                count: count,
                reference: _reference,
                turn: false,
              ),
            ),
            if (narrow)
              const _Divider(horizontal: true)
            else
              const _Divider(horizontal: false),
            Expanded(
              child: _Pane(
                key: _turnPane,
                title: 'TurnScrollView',
                generation: _generation,
                first: _first,
                count: count,
                reference: _reference,
                turn: true,
              ),
            ),
          ];
          return narrow ? Column(children: panes) : Row(children: panes);
        },
      ),
      readout: ConceptStats(
        children: [
          ConceptStat(
            label: 'Loaded',
            value: '$count of 500 messages',
          ),
          if (_shift case final shift?) ...[
            ConceptStat(
              label: 'ListView · what you read moved',
              value: px(shift.list),
              tone: shift.list.abs() > 0.5 || shift.list.isNaN
                  ? ConceptTone.bad
                  : ConceptTone.neutral,
            ),
            ConceptStat(
              label: 'TurnScrollView · what you read moved',
              value: px(shift.turn),
              tone: ConceptTone.good,
            ),
          ],
        ],
      ),
      code: _code,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.horizontal});

  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final color = CoilTheme.of(context).colors.border;
    return horizontal
        ? SizedBox(
            height: 1,
            width: double.infinity,
            child: ColoredBox(color: color),
          )
        : SizedBox(
            width: 1,
            height: double.infinity,
            child: ColoredBox(color: color),
          );
  }
}

class _Pane extends StatefulWidget {
  const _Pane({
    required this.title,
    required this.generation,
    required this.first,
    required this.count,
    required this.reference,
    required this.turn,
    super.key,
  });

  final String title;
  final int generation;
  final int first;
  final int count;
  final int? reference;
  final bool turn;

  @override
  State<_Pane> createState() => _PaneState();
}

class _PaneState extends State<_Pane> {
  final _keys = <int, GlobalKey>{};
  final _viewport = GlobalKey();
  var _listController = ScrollController();
  var _turnController = TurnScrollController();

  @override
  void initState() {
    super.initState();
    _openListAtBottom();
  }

  @override
  void didUpdateWidget(_Pane old) {
    super.didUpdateWidget(old);
    if (old.generation != widget.generation) {
      _listController.dispose();
      _turnController.dispose();
      _listController = ScrollController();
      _turnController = TurnScrollController();
      _keys.clear();
      _openListAtBottom();
    }
  }

  void _openListAtBottom() {
    if (widget.turn) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listController.hasClients) return;
      _listController.jumpTo(_listController.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _listController.dispose();
    _turnController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int index) => _keys.putIfAbsent(index, GlobalKey.new);

  /// The top of message [index] relative to the pane, or null off screen.
  double? topOf(int index) {
    final box = _keys[index]?.currentContext?.findRenderObject();
    final pane = _viewport.currentContext?.findRenderObject();
    if (box is! RenderBox || pane is! RenderBox || !box.attached) return null;
    final y = pane.globalToLocal(box.localToGlobal(Offset.zero)).dy;
    if (y + box.size.height < 0 || y > pane.size.height) return null;
    return y;
  }

  /// The ListView's scroll extent: it keeps its pixels on a prepend, so what
  /// you read moves down by however much this grows.
  double? listExtent() => _listController.hasClients
      ? _listController.position.maxScrollExtent
      : null;

  /// The message at the pane's vertical middle.
  int? middleItem() {
    final pane = _viewport.currentContext?.findRenderObject();
    if (pane is! RenderBox) return null;
    final middle = pane.size.height / 2;
    for (final MapEntry(:key, :value) in _keys.entries) {
      final box = value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final y = pane.globalToLocal(box.localToGlobal(Offset.zero)).dy;
      if (y <= middle && y + box.size.height >= middle) return key;
    }
    return null;
  }

  Widget _message(BuildContext context, int i) {
    final index = widget.first + i;
    return KeyedSubtree(
      key: _keyFor(index),
      child: _Message(
        index: index,
        highlighted: index == widget.reference,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final colors = CoilTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Icon(
                widget.turn ? LucideIcons.circleCheck : LucideIcons.circleAlert,
                size: 14,
                color: widget.turn ? colors.brandInk : colors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Text(
                widget.title,
                style: text.caption.copyWith(fontWeight: text.emphasis),
              ),
            ],
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: _viewport,
            child: widget.turn
                ? TurnScrollView<Object>(
                    key: ValueKey(widget.generation),
                    controller: _turnController,
                    itemCount: widget.count,
                    itemId: (i) => widget.first + i,
                    itemSpacing: 6,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemBuilder: _message,
                  )
                : ListView.builder(
                    key: ValueKey(widget.generation),
                    controller: _listController,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: widget.count,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _message(context, i),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.index, required this.highlighted});

  final int index;
  final bool highlighted;

  static const _lines = [
    'Running five minutes late.',
    'Did you see the new mockups? The spacing finally works.',
    'Lunch?',
    'I pushed the fix, CI should go green in a bit.',
    'Can we move the review to Thursday afternoon instead?',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final mine = index.isEven;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: highlighted
                ? colors.brandWash
                : mine
                ? colors.muted
                : colors.background,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: highlighted ? colors.brandMark : colors.border,
                width: highlighted ? 1.5 : 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '#$index  ',
                    style: text.muted.micro.tabular,
                  ),
                  TextSpan(
                    text: _lines[index % _lines.length],
                    style: text.caption,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
