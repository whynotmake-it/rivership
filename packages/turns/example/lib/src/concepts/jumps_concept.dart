import 'dart:async';
import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:turns/scroll.dart';
import 'package:turns_example/src/concepts/concept_page.dart';
import 'package:turns_example/src/concepts/visible_items.dart';
import 'package:turns_example/src/shell/turns_playground.dart';
import 'package:turns_example/src/shell/turns_shell.dart';

/// Jumps across 10,000 messages and draws what each jump did: the rows a
/// plain list would have laid out, the rows actually built, and the path
/// the view took (a teleport, then a glide over the last screen).
class JumpsConcept extends StatefulWidget {
  const JumpsConcept({super.key});

  @override
  State<JumpsConcept> createState() => _JumpsConceptState();
}

const _count = 10000;

@immutable
class _Jump {
  const _Jump({
    required this.from,
    required this.to,
    required this.built,
    required this.trail,
  });

  /// The rows on screen before the jump.
  final (int, int) from;

  /// The row jumped to.
  final int to;

  /// Every row built during the jump.
  final Set<int> built;

  /// The rows on screen, frame by frame.
  final List<(int, int)> trail;

  int get walked => (to - (from.$1 + from.$2) ~/ 2).abs();
}

class _JumpsConceptState extends State<JumpsConcept> {
  final _controller = TurnScrollController();
  final _viewportKey = GlobalKey();
  final _visible = VisibleItems();
  final _code = ValueNotifier("controller.scrollTo(5000);");
  var _animate = true;

  /// The jump underway or last finished.
  _Jump? _jump;

  /// When the last flight looked done ([TurnScrollFuture.ended]) and when
  /// it came to rest, in milliseconds after the call.
  ({int ended, int settled})? _timing;
  Set<int>? _building;
  int? _target;

  @override
  void initState() {
    super.initState();
    _visible
      ..attach(_viewportKey)
      ..addListener(_onVisible);
  }

  @override
  void dispose() {
    _visible
      ..removeListener(_onVisible)
      ..dispose();
    _controller.dispose();
    _code.dispose();
    super.dispose();
  }

  void _onVisible() {
    final jump = _jump;
    final range = _visible.value;
    if (_building == null || jump == null || range == null) return;
    setState(() => jump.trail.add(range));
  }

  Future<void> _go(int? index) async {
    final from = _visible.value ?? (_count - 1, _count - 1);
    final target = index ?? _count - 1;
    final call = index == null
        ? 'controller.scrollToBottom(animate: $_animate)'
        : 'controller.scrollTo($index, alignment: 0.3, animate: $_animate)';
    _code.value =
        'final flight = $call;\n'
        'await flight.ended; // looks done: highlight, focus, follow up\n'
        'await flight;       // the spring has come to rest';
    final built = <int>{};
    setState(() {
      _building = built;
      _target = target;
      _jump = _Jump(from: from, to: target, built: built, trail: [from]);
    });
    final clock = Stopwatch()..start();
    setState(() => _timing = null);
    final flight = index == null
        ? _controller.scrollToBottom(animate: _animate)
        : _controller.scrollTo(index, alignment: 0.3, animate: _animate);
    final ended = flight.ended.then((_) => clock.elapsedMilliseconds);
    await flight;
    final settled = clock.elapsedMilliseconds;
    _timing = (ended: await ended, settled: settled);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _building = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final jump = _jump;
    String n(int v) => v.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return ConceptPage(
      routeName: turnsJumpsRouteName,
      lead:
          'A plain sliver list has no map from index to offset: to reach a '
          'far row it lays out every row in between, the red band on the '
          'rail. TurnScrollView recenters next to the target and builds only '
          'what lands on screen, the ticks. The chart beside the rail is '
          'the view over time: a far jump teleports, then glides the last '
          'screen so it still reads as motion.',
      controls: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (index, label) in const [
            (0, '#0'),
            (2500, '#2,500'),
            (5000, '#5,000'),
            (9000, '#9,000'),
          ])
            CoilButton(
              key: Key('concept.jumps.$index'),
              variant: CoilButtonVariant.secondary,
              size: CoilSize.compact,
              onPressed: () => unawaited(_go(index)),
              child: Text('Jump to $label'),
            ),
          CoilButton(
            key: const Key('concept.jumps.bottom'),
            variant: CoilButtonVariant.secondary,
            size: CoilSize.compact,
            leading: const Icon(LucideIcons.arrowDownToLine, size: 14),
            onPressed: () => unawaited(_go(null)),
            child: const Text('Latest'),
          ),
          SizedBox(
            width: 150,
            child: PlaygroundToggle(
              label: 'Animate',
              value: _animate,
              onChanged: (v) => setState(() => _animate = v),
            ),
          ),
        ],
      ),
      stage: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: KeyedSubtree(
              key: _viewportKey,
              child: TurnScrollView<Object>(
                controller: _controller,
                itemCount: _count,
                itemId: (i) => i,
                itemSpacing: 4,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                itemBuilder: (context, i) {
                  _building?.add(i);
                  return _visible.wrap(
                    i,
                    _Row(index: i, target: i == _target && _building == null),
                  );
                },
              ),
            ),
          ),
          SizedBox(width: 1, child: ColoredBox(color: colors.border)),
          SizedBox(
            width: 180,
            child: ValueListenableBuilder(
              valueListenable: _visible,
              builder: (context, visible, _) =>
                  _JumpRail(visible: visible, jump: jump),
            ),
          ),
        ],
      ),
      stageHeight: 480,
      readout: ConceptStats(
        children: [
          ConceptStat(
            label: 'Rows a plain list would walk',
            value: jump == null ? '–' : n(jump.walked),
            tone: ConceptTone.bad,
          ),
          ConceptStat(
            label: 'Rows TurnScrollView built',
            value: jump == null ? '–' : n(jump.built.length),
            tone: ConceptTone.good,
          ),
          ConceptStat(
            label: 'Looks done (ended)',
            value: _timing == null ? '–' : '${_timing!.ended} ms',
            tone: ConceptTone.good,
          ),
          ConceptStat(
            label: 'Settled',
            value: _timing == null ? '–' : '${_timing!.settled} ms',
          ),
        ],
      ),
      code: _code,
    );
  }
}

/// All 10,000 rows top to bottom, with the last jump drawn on it, and the
/// view's position over that jump's frames beside it.
class _JumpRail extends StatelessWidget {
  const _JumpRail({required this.visible, required this.jump});

  final (int, int)? visible;
  final _Jump? jump;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('#0', style: text.muted.micro.tabular),
              const Spacer(),
              Text('frames →', style: text.muted.micro),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _JumpRailPainter(
                visible: visible,
                jump: jump,
                track: colors.muted,
                window: colors.brandFill,
                built: colors.brandInk,
                walked: colors.destructive,
                trail: colors.brandMark,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('#9,999', style: text.muted.micro.tabular),
        ],
      ),
    );
  }
}

class _JumpRailPainter extends CustomPainter {
  const _JumpRailPainter({
    required this.visible,
    required this.jump,
    required this.track,
    required this.window,
    required this.built,
    required this.walked,
    required this.trail,
  });

  final (int, int)? visible;
  final _Jump? jump;
  final Color track;
  final Color window;
  final Color built;
  final Color walked;
  final Color trail;

  static const _bar = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    double y(num index) => size.height * index / (_count - 1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, _bar, size.height),
        const Radius.circular(8),
      ),
      Paint()..color = track,
    );

    final jump = this.jump;
    if (jump != null) {
      // What a plain list lays out on the way: everything in between.
      final fromMid = (jump.from.$1 + jump.from.$2) / 2;
      final top = math.min(fromMid, jump.to.toDouble());
      final bottom = math.max(fromMid, jump.to.toDouble());
      final band = Rect.fromLTRB(
        0,
        y(top),
        _bar,
        math.max(y(bottom), y(top) + 2),
      );
      canvas
        ..save()
        ..clipRect(band);
      final hatch = Paint()
        ..color = walked.withValues(alpha: 0.55)
        ..strokeWidth = 1.2;
      for (var v = band.top - _bar; v < band.bottom; v += 4) {
        canvas.drawLine(Offset(0, v + _bar), Offset(_bar, v), hatch);
      }
      canvas.restore();

      // What TurnScrollView built: a tick per row.
      final tick = Paint()
        ..color = built
        ..strokeWidth = 2;
      for (final index in jump.built) {
        canvas.drawLine(
          Offset(-2, y(index)),
          Offset(_bar + 2, y(index)),
          tick,
        );
      }

      // The view over time: x is the frame, y the middle row on screen. A
      // teleport is a straight drop, the glide a short curve.
      const chartLeft = _bar + 12;
      final chartWidth = size.width - chartLeft;
      final frames = math.max(1, jump.trail.length - 1);
      final path = Path();
      for (final (i, range) in jump.trail.indexed) {
        final point = Offset(
          chartLeft + chartWidth * i / frames,
          y((range.$1 + range.$2) / 2),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawCircle(point, 2, Paint()..color = trail);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = trail
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    if (visible case final visible?) {
      final rect = Rect.fromLTRB(
        -3,
        y(visible.$1),
        _bar + 3,
        math.max(y(visible.$2 + 1), y(visible.$1) + 4),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = window,
      );
    }
  }

  @override
  bool shouldRepaint(_JumpRailPainter old) => true;
}

class _Row extends StatelessWidget {
  const _Row({required this.index, required this.target});

  final int index;
  final bool target;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    // Rows differ in height, as real messages do, so offsets can't be
    // computed from the index.
    final lines = 1 + (index * 7919) % 3;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: target ? colors.brandWash : colors.background,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: target ? colors.brandMark : colors.border,
            width: target ? 1.5 : 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Text('#$index', style: text.caption.tabular),
            ),
            Expanded(
              child: Text(
                List.filled(lines, 'Message body that takes a line.').join(
                  '\n',
                ),
                style: text.muted.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
