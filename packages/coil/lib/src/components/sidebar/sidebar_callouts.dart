import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/sidebar/sidebar_scaffold.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// When a [CoilSidebarCalloutStack] fans its pile out.
enum CoilSidebarCalloutExpand {
  /// While a mouse rests on the pile or the keyboard focuses a card in it.
  /// For short inline cards.
  onHover,

  /// Never; only the front card shows in full. For tall banners, which
  /// fanned out would fill the sidebar.
  never,
}

/// A pile of callouts for the sidebar's footer, such as news and offers.
///
/// [children] are cards, usually dismissible `CoilCard`s, front first, each
/// with its own key. At rest the front card shows with up to two more
/// peeking behind it, each a step smaller. [expand] decides whether the
/// pile fans out into a list. Dismissing the front card and removing it
/// from [children] moves the next one forward. Touch never fans the pile.
///
/// The cards should share one anatomy: the pile is as tall as its tallest
/// card.
class CoilSidebarCalloutStack extends StatefulWidget {
  /// Creates a callout stack.
  const CoilSidebarCalloutStack({
    required this.children,
    super.key,
    this.expand = CoilSidebarCalloutExpand.onHover,
    this.motion,
    this.motions,
  });

  /// The cards, front first. Each needs a key.
  final List<Widget> children;

  /// When the pile fans out.
  final CoilSidebarCalloutExpand expand;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions for this instance, keyed by [CoilSidebarTrack]s.
  final Map<CoilSidebarTrack<Object>, Motion>? motions;

  /// How far each card behind the front one peeks out, at rest.
  static const peek = 12.0;

  /// How many cards peek behind the front one.
  static const maxPeeking = 2;

  /// How much smaller each peeking card is.
  static const scaleStep = 0.05;

  /// The space between cards when the pile fans out.
  static const gap = 4.0;

  @override
  State<CoilSidebarCalloutStack> createState() =>
      _CoilSidebarCalloutStackState();
}

class _CoilSidebarCalloutStackState extends State<CoilSidebarCalloutStack> {
  final _states = WidgetStatesController();
  bool _focusWithin = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_rebuild);
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Motion _motionFor(Motion token) => CoilTheme.trackMotionOf(
    context,
    CoilSidebarTrack.callouts,
    instance: widget.motions,
    token: token,
  );

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final expanded =
        widget.expand == CoilSidebarCalloutExpand.onHover &&
        (_states.value.contains(WidgetState.hovered) ||
            (_focusWithin &&
                CoilInputModality.instance.value == CoilModality.keyboard));
    final count = widget.children.length;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focusWithin = focused),
      child: CoilInteractionDetector(
        states: _states,
        trackPress: false,
        child: SingleMotionBuilder(
          value: expanded ? 1 : 0,
          motion: _motionFor(expanded ? motion.standard : motion.standardExit),
          builder: (context, fan, _) => _CalloutPile(
            fan: fan.clamp(0, 1),
            count: count,
            children: [
              for (final (i, card) in widget.children.indexed)
                _Card(
                  key: card.key,
                  slot: i,
                  fan: fan.clamp(0, 1),
                  motion: _motionFor(motion.standard),
                  child: card,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One card at its [slot] in the pile: it slides and scales there, and
/// only the front three show at rest.
class _Card extends StatelessWidget {
  const _Card({
    required this.slot,
    required this.fan,
    required this.motion,
    required this.child,
    super.key,
  });

  final int slot;
  final double fan;
  final Motion motion;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    value: slot.toDouble(),
    motion: motion,
    builder: (context, slot, child) {
      const max = CoilSidebarCalloutStack.maxPeeking;
      final peeking = math.min(slot, max.toDouble());
      final rest = -peeking * CoilSidebarCalloutStack.peek;
      final scale = 1 - peeking * CoilSidebarCalloutStack.scaleStep * (1 - fan);
      final visible = slot <= max + 0.01 || fan > 0;
      return Opacity(
        opacity: visible ? 1 : 0,
        child: Transform.translate(
          // At rest it peeks by a fixed amount; fanned out, it moves up
          // its own height per slot, plus the gap.
          offset: Offset(
            0,
            rest * (1 - fan) - slot * CoilSidebarCalloutStack.gap * fan,
          ),
          child: FractionalTranslation(
            translation: Offset(0, -slot * fan),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: ExcludeFocus(
                excluding: !visible,
                child: ExcludeSemantics(excluding: !visible, child: child),
              ),
            ),
          ),
        ),
      );
    },
    child: child,
  );
}

/// Lays the cards out on top of each other at the bottom, front card
/// painted last, and sizes itself to the pile at [fan].
class _CalloutPile extends MultiChildRenderObjectWidget {
  const _CalloutPile({
    required this.fan,
    required this.count,
    required super.children,
  });

  final double fan;
  final int count;

  @override
  _RenderCalloutPile createRenderObject(BuildContext context) =>
      _RenderCalloutPile(fan: fan, count: count);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCalloutPile renderObject,
  ) => renderObject
    ..fan = fan
    ..count = count;
}

class _PileParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderCalloutPile extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PileParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PileParentData> {
  _RenderCalloutPile({required this._fan, required this._count});

  double _fan;
  double get fan => _fan;
  set fan(double value) {
    if (value == _fan) return;
    _fan = value;
    markNeedsLayout();
  }

  int _count;
  int get count => _count;
  set count(int value) {
    if (value == _count) return;
    _count = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PileParentData) {
      child.parentData = _PileParentData();
    }
  }

  /// The pile's height for cards [card] tall.
  double _height(double card) {
    final n = _count;
    if (n == 0) return 0;
    final peeking = math.min(n - 1, CoilSidebarCalloutStack.maxPeeking);
    final rest = card + peeking * CoilSidebarCalloutStack.peek;
    final fanned = n * card + (n - 1) * CoilSidebarCalloutStack.gap;
    return rest + (fanned - rest) * _fan;
  }

  double _tallest(double Function(RenderBox child) height) {
    var tallest = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      tallest = math.max(tallest, height(child));
    }
    return tallest;
  }

  BoxConstraints _childConstraints(BoxConstraints constraints) =>
      BoxConstraints.tightFor(width: constraints.maxWidth);

  @override
  void performLayout() {
    final childConstraints = _childConstraints(constraints);
    final card = _tallest((child) {
      child.layout(childConstraints, parentUsesSize: true);
      return child.size.height;
    });
    size = constraints.constrain(Size(constraints.maxWidth, _height(card)));
    var child = firstChild;
    while (child != null) {
      (child.parentData! as _PileParentData).offset = Offset(
        0,
        size.height - child.size.height,
      );
      child = childAfter(child);
    }
  }

  // The front card is the first child: it paints last and hits first.
  @override
  void paint(PaintingContext context, Offset offset) {
    var child = lastChild;
    while (child != null) {
      final data = child.parentData! as _PileParentData;
      context.paintChild(child, data.offset + offset);
      child = data.previousSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _PileParentData;
      final hit = result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (result, transformed) =>
            child!.hitTest(result, position: transformed),
      );
      if (hit) return true;
      child = data.nextSibling;
    }
    return false;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _height(_tallest((child) => child.getMinIntrinsicHeight(width)));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _height(_tallest((child) => child.getMaxIntrinsicHeight(width)));

  @override
  double computeMinIntrinsicWidth(double height) =>
      _tallest((child) => child.getMinIntrinsicWidth(double.infinity));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _tallest((child) => child.getMaxIntrinsicWidth(double.infinity));

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final childConstraints = _childConstraints(constraints);
    final card = _tallest(
      (child) => child.getDryLayout(childConstraints).height,
    );
    return constraints.constrain(Size(constraints.maxWidth, _height(card)));
  }
}
