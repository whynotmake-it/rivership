import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:turns/scroll.dart';
import 'package:turns_example/src/concepts/concept_page.dart';
import 'package:turns_example/src/shell/turns_shell.dart';

/// A plain [ListView] and a [TurnScrollView] get the same older page
/// prepended; only one keeps what you were reading in place. Each pane
/// draws where the message you were reading was and where it went.
class PrependConcept extends StatefulWidget {
  const PrependConcept({super.key});

  @override
  State<PrependConcept> createState() => _PrependConceptState();
}

const _pageSize = 4;
const _pages = 12;
const _initialPages = 4;

/// Each page of history gets its own color and day, so a page landing
/// above you is easy to tell apart from the one you were reading.
const _pageNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _pageHues = [210.0, 150.0, 30.0, 280.0, 0.0, 95.0, 330.0];

class _PrependConceptState extends State<PrependConcept> {
  var _firstPage = _pages - _initialPages;
  var _generation = 0;
  final _listPane = GlobalKey<_PaneState>();
  final _turnPane = GlobalKey<_PaneState>();
  int? _reference;

  final _code = ValueNotifier(
    '// The same page goes to both lists:\n'
    'setState(() => messages = [...olderPage, ...messages]);\n'
    '\n'
    '// ListView keeps its pixels, so everything moves down a page.\n'
    'ListView.builder(itemCount: messages.length, ...);\n'
    '\n'
    '// TurnScrollView grows older items upward from its center.\n'
    'TurnScrollView(itemCount: messages.length, itemId: ..., ...);',
  );

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _loadOlder() async {
    if (_firstPage <= 0) return;
    // The message the reader is looking at: the one in the middle of the
    // TurnScrollView pane, followed in both panes.
    final reference = _turnPane.currentState?.middleItem();
    if (reference == null) return;
    for (final pane in [_listPane, _turnPane]) {
      pane.currentState?.captureBefore(reference);
    }
    setState(() {
      _firstPage--;
      _reference = reference;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    for (final pane in [_listPane, _turnPane]) {
      pane.currentState?.captureAfter();
    }
  }

  void _reset() => setState(() {
    _firstPage = _pages - _initialPages;
    _generation++;
    _reference = null;
  });

  @override
  Widget build(BuildContext context) {
    final first = _firstPage * _pageSize;
    final count = _pages * _pageSize - first;
    Widget pane(GlobalKey<_PaneState> key, {required bool turn}) => _Pane(
      key: key,
      title: turn ? 'TurnScrollView' : 'ListView',
      generation: _generation,
      first: first,
      count: count,
      reference: _reference,
      turn: turn,
    );
    return ConceptPage(
      routeName: turnsPrependRouteName,
      lead:
          'Both panes show the same chat, one color per day. Press "Load an '
          'older day" and watch the outlined message: the ListView shoves it '
          'down by a whole day, the TurnScrollView leaves it exactly where '
          'it was and grows the new day upward, out of sight.',
      controls: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          CoilButton(
            key: const Key('concept.prepend.load'),
            size: CoilSize.compact,
            leading: const Icon(LucideIcons.arrowUpToLine, size: 14),
            onPressed: _firstPage > 0 ? _loadOlder : null,
            child: Text(
              _firstPage > 0 ? 'Load an older day' : 'All history loaded',
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
          final border = CoilTheme.of(context).colors.border;
          final divider = ColoredBox(
            color: border,
            child: narrow
                ? const SizedBox(height: 1, width: double.infinity)
                : const SizedBox(width: 1, height: double.infinity),
          );
          final panes = [
            Expanded(child: pane(_listPane, turn: false)),
            divider,
            Expanded(child: pane(_turnPane, turn: true)),
          ];
          return narrow ? Column(children: panes) : Row(children: panes);
        },
      ),
      stageHeight: 480,
      readout: ConceptStats(
        children: [
          ConceptStat(
            label: 'Loaded',
            value: '${_pages - _firstPage} of $_pages days',
          ),
        ],
      ),
      code: _code,
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

  int? _reference;
  Rect? _before;
  double _extentBefore = 0;

  /// Where the reference was and is after the last load, in pane
  /// coordinates; cleared once the reader scrolls.
  ({Rect before, Rect? after, double moved})? _move;

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
      _move = null;
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

  /// The rect of message [index] in the pane, or null when not laid out.
  Rect? _rectOf(int index) {
    final box = _keys[index]?.currentContext?.findRenderObject();
    final pane = _viewport.currentContext?.findRenderObject();
    if (box is! RenderBox || pane is! RenderBox || !box.attached) return null;
    return pane.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
  }

  double _paneHeight() {
    final pane = _viewport.currentContext?.findRenderObject();
    return pane is RenderBox && pane.hasSize ? pane.size.height : 0;
  }

  /// The message at the pane's vertical middle.
  int? middleItem() {
    final middle = _paneHeight() / 2;
    for (final index in _keys.keys) {
      final rect = _rectOf(index);
      if (rect != null && rect.top <= middle && rect.bottom >= middle) {
        return index;
      }
    }
    return null;
  }

  /// Remembers where message [reference] is before a page lands.
  void captureBefore(int reference) {
    _reference = reference;
    _before = _rectOf(reference);
    if (!widget.turn && _listController.hasClients) {
      _extentBefore = _listController.position.maxScrollExtent;
    }
  }

  /// Measures where the remembered message went.
  void captureAfter() {
    final before = _before;
    final reference = _reference;
    if (before == null || reference == null) return;
    var after = _rectOf(reference);
    var moved = after == null ? double.nan : after.top - before.top;
    if (after != null && after.top > _paneHeight()) after = null;
    if (moved.isNaN && !widget.turn && _listController.hasClients) {
      // Pushed out of the pane: the ListView kept its pixels, so the
      // message moved down by however much content the page added.
      moved = _listController.position.maxScrollExtent - _extentBefore;
    }
    setState(() => _move = (before: before, after: after, moved: moved));
  }

  Widget _message(BuildContext context, int i) {
    final index = widget.first + i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: KeyedSubtree(
        key: _keyFor(index),
        child: _Message(index: index, outlined: index == widget.reference),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    final colors = CoilTheme.of(context).colors;
    final list = widget.turn
        ? TurnScrollView<Object>(
            key: ValueKey(widget.generation),
            controller: _turnController,
            itemCount: widget.count,
            itemId: (i) => widget.first + i,
            itemSpacing: 0,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            itemBuilder: _message,
          )
        : ListView.builder(
            key: ValueKey(widget.generation),
            controller: _listController,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            itemCount: widget.count,
            itemBuilder: _message,
          );

    final move = _move;
    final moved = move != null && (move.moved.isNaN || move.moved.abs() > 0.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Text(
                widget.title,
                style: text.caption.copyWith(fontWeight: text.emphasis),
              ),
              const Spacer(),
              if (move != null) _Verdict(moved: move.moved),
            ],
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollUpdateNotification>(
            onNotification: (n) {
              if (n.dragDetails != null && _move != null) {
                setState(() => _move = null);
              }
              return false;
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                KeyedSubtree(key: _viewport, child: list),
                if (move != null)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _MovePainter(
                        before: move.before,
                        after: move.after,
                        color: moved ? colors.destructive : colors.brandInk,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.moved});

  final double moved;

  @override
  Widget build(BuildContext context) {
    final still = !moved.isNaN && moved.abs() < 0.5;
    return CoilBadge(
      variant: CoilBadgeVariant.dot,
      color: still ? CoilBadgeColor.emerald : CoilBadgeColor.red,
      shape: CoilBadgeShape.pill,
      size: CoilSize.compact,
      child: Text(
        still
            ? 'Stayed put'
            : moved.isNaN
            ? 'Pushed out of view'
            : 'Moved ${moved.round()} px down',
      ),
    );
  }
}

/// A dashed outline where the message was, and an arrow to where it is.
class _MovePainter extends CustomPainter {
  const _MovePainter({
    required this.before,
    required this.after,
    required this.color,
  });

  final Rect before;
  final Rect? after;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final ghost = before.inflate(3);
    for (final (a, b) in [
      (ghost.topLeft, ghost.topRight),
      (ghost.topRight, ghost.bottomRight),
      (ghost.bottomRight, ghost.bottomLeft),
      (ghost.bottomLeft, ghost.topLeft),
    ]) {
      final length = (b - a).distance;
      final dir = (b - a) / length;
      for (var d = 0.0; d < length; d += 8) {
        canvas.drawLine(
          a + dir * d,
          a + dir * math.min(d + 4, length),
          paint,
        );
      }
    }
    final x = before.center.dx;
    final start = Offset(x, before.bottom + 4);
    final target = after;
    final end = target == null
        ? Offset(x, size.height - 4)
        : Offset(x, target.top - 2);
    if (end.dy - start.dy < 10) return;
    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(start, end, line)
      ..drawPath(
        Path()
          ..moveTo(end.dx - 6, end.dy - 8)
          ..lineTo(end.dx, end.dy)
          ..lineTo(end.dx + 6, end.dy - 8),
        line,
      );
  }

  @override
  bool shouldRepaint(_MovePainter old) =>
      old.before != before || old.after != after || old.color != color;
}

class _Message extends StatelessWidget {
  const _Message({required this.index, required this.outlined});

  final int index;
  final bool outlined;

  static const _lines = [
    'Running five minutes late.',
    'Did you see the new mockups? The spacing finally works.',
    'Lunch?',
    'I pushed the fix, CI should go green in a bit.',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final page = index ~/ _pageSize;
    final day = _pageNames[page % _pageNames.length];
    final dark = colors.brightness == Brightness.dark;
    final hue = _pageHues[page % _pageHues.length];
    final fill = HSLColor.fromAHSL(1, hue, 0.55, dark ? 0.28 : 0.9).toColor();
    final ink = HSLColor.fromAHSL(1, hue, 0.6, dark ? 0.75 : 0.32).toColor();
    final mine = index.isEven;
    final bubble = Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: fill,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: outlined ? colors.foreground : const Color(0x00000000),
                width: 2,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: outlined ? 'You were reading this  ' : '',
                    style: text.micro.copyWith(
                      color: colors.foreground,
                      fontWeight: text.emphasis,
                    ),
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
    if (index % _pageSize != 0) return bubble;
    Widget rule() => Expanded(
      child: ColoredBox(color: ink, child: const SizedBox(height: 2)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(
            children: [
              rule(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  day,
                  style: text.micro.copyWith(
                    color: ink,
                    fontWeight: text.emphasis,
                  ),
                ),
              ),
              rule(),
            ],
          ),
        ),
        bubble,
      ],
    );
  }
}
