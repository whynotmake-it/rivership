// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:math' as math;

import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/interaction.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// Which edge a [CoilCardStack] grows from. The front card sits at it.
enum CoilCardStackAnchor {
  /// The front card at the bottom; the cards behind peek and fan upward,
  /// like a toast stack or a pile above a composer.
  bottom,

  /// The front card at the top; the cards behind peek and fan downward.
  top,
}

/// When a [CoilCardStack] fans out.
enum CoilCardStackExpand {
  /// While a mouse rests on the pile or focus is inside it, and after a tap
  /// on the folded pile until it folds again (see [CoilCardStackFold]).
  auto,

  /// Never: only the front card shows in full, and cards past the peeks
  /// are hidden from focus and screen readers.
  never,
}

/// How a [CoilCardStack] that a tap fanned out folds again.
enum CoilCardStackFold {
  /// A tap outside the pile folds it.
  onTapOutside,

  /// Only its owner folds it, by setting [CoilCardStackController.pinned]
  /// to false (a collapse button).
  manual,
}

/// Holds whether a [CoilCardStack] is pinned open by a tap, and reports
/// whether it is fanned out.
class CoilCardStackController extends ChangeNotifier {
  bool _pinned = false;
  bool _expanded = false;

  /// Whether a tap fanned the pile out and it stays so until folded. Set it
  /// to false to fold the pile, or true to fan it out.
  bool get pinned => _pinned;
  set pinned(bool value) {
    if (value == _pinned) return;
    _pinned = value;
    notifyListeners();
  }

  /// Whether the pile was fanned out when it last built (pinned, hovered,
  /// focused inside or held). The stack updates it as it builds and doesn't
  /// notify; read it when you need it, such as in `didUpdateWidget`.
  bool get expanded => _expanded;
}

/// One card of a [CoilCardStack].
@immutable
class CoilCardStackItem {
  /// Creates an item.
  const CoilCardStackItem({
    required this.key,
    required this.child,
    this.slot,
    this.slotMotion,
    this.lifted = false,
    this.leaving = false,
  });

  /// Identifies the card across rebuilds, so it keeps its state and springs
  /// from where it was when the order changes.
  final Key key;

  /// The card.
  final Widget child;

  /// Its place from the front, 0 being the front card. Fractional while it
  /// follows a drag. Null places it by its index among the items that
  /// aren't [leaving].
  final double? slot;

  /// How it moves to a new [slot]. Null uses the stack's `slotMotion`.
  /// `Motion.instant()` makes it follow a drag.
  final Motion? slotMotion;

  /// Whether it paints above the others, such as while it is dragged.
  final bool lifted;

  /// Whether it is on its way out. It takes no input and keeps its place
  /// while the cards around it close the gap it leaves, smoothly whatever
  /// their heights. Remove it from the items once its own exit is done.
  final bool leaving;
}

/// Constraints a [CoilCardStack] gives its `background`: tight to the
/// stack, carrying the folded pile's extent from the anchor edge plus the
/// gap. Read them with a `LayoutBuilder` to keep content clear of the
/// pile, the way `Scaffold.extendBody` hands its body the bar's height.
class CoilCardStackConstraints extends BoxConstraints {
  /// Tight constraints of [size] with [pileExtent].
  CoilCardStackConstraints.tight(super.size, {required this.pileExtent})
    : super.tight();

  /// The folded pile's extent plus the gap; 0 with no cards.
  final double pileExtent;

  @override
  bool operator ==(Object other) =>
      other is CoilCardStackConstraints &&
      super == other &&
      other.pileExtent == pileExtent;

  @override
  int get hashCode => Object.hash(super.hashCode, pileExtent);
}

/// A pile of cards that fans out into a list: the layout, motion and input
/// rules a card pile needs, for components to build on (the sidebar's
/// callouts, the queued messages above a composer).
///
/// [items] are front first. **Folded**, the front card shows in full at
/// the [anchor] edge and up to [maxPeeks] cards behind it peek out [peek]
/// apart, each [peekScale] smaller; cards of any height peek evenly,
/// because every card behind is placed by its far edge (taller ones are
/// cut off at the anchor edge, behind the front card). Cards past the
/// peeks fade out. **Fanned out**, the cards stack by their measured
/// heights with [gap] between each pair. Each card springs between the two
/// with the pile's expand spring, and to a new place with [slotMotion].
///
/// Input follows what shows:
///
/// - fanned out, every card takes taps, hovers, text and focus where it is
///   painted;
/// - folded, only the front card takes pointers; a tap anywhere else on
///   the pile (a peeking card) lands on the pile, which fans out, so it
///   never presses a control hidden under a peek;
/// - Tab visits the cards front first whatever their geometry, and focus
///   inside fans the pile out ([CoilCardStackExpand.auto]), so every card
///   is reachable by keyboard and screen readers.
///
/// [expand] decides when it fans out; [fold] how a tap-pinned pile folds.
/// [background] fills the stack under the pile and gets
/// [CoilCardStackConstraints]; [leading] and [trailing] sit beside the
/// front card, [sideWidth] wide, and the cards take the width between.
/// Without a background the stack is as tall as the pile.
///
/// Cards read the pile's state with [CoilCardStack.maybeOf].
class CoilCardStack extends StatefulWidget {
  /// Creates a card stack.
  const CoilCardStack({
    required this.items,
    super.key,
    this.anchor = CoilCardStackAnchor.bottom,
    this.expand = CoilCardStackExpand.auto,
    this.fold = CoilCardStackFold.onTapOutside,
    this.controller,
    this.holdExpanded = false,
    this.peek = defaultPeek,
    this.peekScale = defaultPeekScale,
    this.maxPeeks = defaultMaxPeeks,
    this.gap,
    this.shift = 0,
    this.background,
    this.leading,
    this.trailing,
    this.sideWidth = 0,
    this.expandMotion,
    this.foldMotion,
    this.slotMotion,
    this.leaveMotion,
  });

  /// The cards, front first.
  final List<CoilCardStackItem> items;

  /// The edge the front card sits at.
  final CoilCardStackAnchor anchor;

  /// When the pile fans out.
  final CoilCardStackExpand expand;

  /// How a pile a tap fanned out folds.
  final CoilCardStackFold fold;

  /// Pins the pile open and reports whether it is fanned out. One is kept
  /// internally when null.
  final CoilCardStackController? controller;

  /// Keeps the pile fanned out, such as while a card is dragged.
  final bool holdExpanded;

  /// How far each card behind the front one peeks out, folded.
  final double peek;

  /// How much smaller each peeking card is than the one in front of it.
  final double peekScale;

  /// How many cards peek out behind the front one, folded.
  final int maxPeeks;

  /// The space between fanned-out cards. Null uses the theme's
  /// `CoilMetrics.gap`.
  final double? gap;

  /// Moves the whole pile away from the anchor edge, in logical pixels,
  /// such as for a recoil.
  final double shift;

  /// Content the pile floats over, filling the stack.
  final Widget? background;

  /// Beside the front card, at the start.
  final Widget? leading;

  /// Beside the front card, at the end.
  final Widget? trailing;

  /// The width of [leading] and [trailing]; the cards take the rest.
  final double sideWidth;

  /// Fanning out. Defaults to the theme's `standard`.
  final Motion? expandMotion;

  /// Folding. Defaults to the theme's `standardExit`.
  final Motion? foldMotion;

  /// A card moving to a new place. Defaults to the theme's `standard`.
  final Motion? slotMotion;

  /// The gap a leaving card leaves closing. Defaults to the theme's
  /// `standard`.
  final Motion? leaveMotion;

  /// How far cards peek by default.
  static const defaultPeek = 12.0;

  /// How much smaller each peeking card is by default.
  static const defaultPeekScale = 0.05;

  /// How many cards peek by default.
  static const defaultMaxPeeks = 2;

  /// The nearest pile's state, for a card in it.
  static CoilCardStackScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoilCardStackScope>();

  @override
  State<CoilCardStack> createState() => _CoilCardStackState();
}

/// What a card in a [CoilCardStack] can read about its pile.
class CoilCardStackScope extends InheritedWidget {
  /// Creates the scope.
  const CoilCardStackScope({
    required this.expanded,
    required super.child,
    super.key,
  });

  /// Whether the pile is fanned out (or on its way there).
  final bool expanded;

  @override
  bool updateShouldNotify(CoilCardStackScope oldWidget) =>
      oldWidget.expanded != expanded;
}

/// What a card in a [CoilCardStack] can do in its pile: read with
/// [CoilCardStackItemScope.maybeOf].
class CoilCardStackItemScope extends InheritedWidget {
  /// Creates the scope.
  const CoilCardStackItemScope({
    required this.leave,
    required super.child,
    super.key,
  });

  /// Starts the card on its way out of the pile, as an item's
  /// [CoilCardStackItem.leaving] does: the cards around it close its gap,
  /// then `onLeft` is called. Remove the card from the pile there. A card
  /// that dismisses itself (a dismissible `CoilCard`) calls it instead of
  /// collapsing its own height.
  final void Function(VoidCallback onLeft) leave;

  /// The scope of the pile card [context] is in, if any.
  static CoilCardStackItemScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CoilCardStackItemScope>();

  @override
  bool updateShouldNotify(CoilCardStackItemScope oldWidget) => false;
}

class _CoilCardStackState extends State<CoilCardStack> {
  final _hover = WidgetStatesController();
  CoilCardStackController? _ownController;
  final _focused = <Key>{};

  /// Cards that asked to leave, with what to call once they have.
  final _leaving = <Key, VoidCallback>{};

  CoilCardStackController get _controller =>
      widget.controller ?? (_ownController ??= CoilCardStackController());

  @override
  void initState() {
    super.initState();
    _hover.addListener(_rebuild);
    _controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(CoilCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.controller ?? _ownController;
    if (old != _controller) {
      old?.removeListener(_rebuild);
      _controller.addListener(_rebuild);
    }
    final live = widget.items.where((item) => !item.leaving).length;
    if (widget.expand == CoilCardStackExpand.never || live < 2) {
      // Nothing left to fan out to. Not while building: listeners build.
      _controller._pinned = false;
    }
    final keys = {for (final item in widget.items) item.key};
    _focused.retainWhere(keys.contains);
    _leaving.removeWhere((key, _) => !keys.contains(key));
  }

  @override
  void dispose() {
    _hover
      ..removeListener(_rebuild)
      ..dispose();
    _controller.removeListener(_rebuild);
    _ownController?.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  bool get _expanded =>
      widget.expand == CoilCardStackExpand.auto &&
      (_controller.pinned ||
          widget.holdExpanded ||
          _focused.isNotEmpty ||
          _hover.value.contains(WidgetState.hovered));

  @override
  Widget build(BuildContext context) {
    final tokens = CoilTheme.motionOf(context);
    final metrics = CoilTheme.metricsOf(context);
    final expanded = _expanded;
    _controller._expanded = expanded;
    final fans = widget.expand == CoilCardStackExpand.auto;
    bool leaving(CoilCardStackItem item) =>
        item.leaving || _leaving.containsKey(item.key);
    final live = widget.items.where((item) => !leaving(item)).toList();
    final pin = fans && !expanded && live.length > 1
        ? () => _controller.pinned = true
        : null;
    final tapOutside =
        _controller.pinned && widget.fold == CoilCardStackFold.onTapOutside;
    void onTapOutside(PointerDownEvent _) => _controller.pinned = false;
    Widget tapRegion(Widget child) => TapRegion(
      groupId: this,
      onTapOutside: tapOutside ? onTapOutside : null,
      child: child,
    );

    final slotMotion = widget.slotMotion ?? tokens.standard;
    final leaveMotion = widget.leaveMotion ?? tokens.standard;
    final hideExtra = widget.expand == CoilCardStackExpand.never;

    return MotorInspectionScope(
      group: 'CoilCardStack',
      child: CoilCardStackScope(
        expanded: expanded,
        // Tab follows the pile, front first, wherever the cards are on
        // their way between folded and fanned out.
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: SingleMotionBuilder(
            value: expanded ? 1 : 0,
            motion: expanded
                ? widget.expandMotion ?? tokens.standard
                : widget.foldMotion ?? tokens.standardExit,
            debugLabel: 'CoilCardStack.expand',
            builder: (context, fan, _) {
              final f = fan.clamp(0.0, 1.0);
              var liveIndex = 0;
              return _CardStackLayout(
                fan: f,
                anchor: widget.anchor,
                peek: widget.peek,
                maxPeeks: widget.maxPeeks,
                gap: widget.gap ?? metrics.gap,
                shift: widget.shift,
                sideWidth: widget.sideWidth,
                hasBackground: widget.background != null,
                children: [
                  if (widget.background case final background?)
                    // The content keeps its own (reading) order.
                    FocusTraversalGroup(child: background)
                  else
                    const SizedBox.shrink(),
                  // The pile's area: it takes the pile's hover, and a tap
                  // that no front-card control takes fans it out.
                  tapRegion(
                    CoilInteractionDetector(
                      states: _hover,
                      trackPress: pin != null,
                      onTap: pin,
                      excludeFromSemantics: true,
                      cursor: MouseCursor.defer,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  widget.leading ?? const SizedBox.shrink(),
                  widget.trailing ?? const SizedBox.shrink(),
                  for (final item in widget.items)
                    _Card(
                      key: item.key,
                      slot:
                          item.slot ??
                          (item.leaving ? null : (liveIndex++).toDouble()),
                      slotMotion: item.slotMotion ?? slotMotion,
                      leaveMotion: leaveMotion,
                      fan: f,
                      expanded: expanded,
                      anchor: widget.anchor,
                      peekScale: widget.peekScale,
                      maxPeeks: widget.maxPeeks,
                      lifted: item.lifted,
                      leaving: leaving(item),
                      onLeft: _leaving[item.key],
                      hideExtra: hideExtra,
                      onFocusChange: (focused) => setState(
                        () => focused
                            ? _focused.add(item.key)
                            : _focused.remove(item.key),
                      ),
                      child: CoilCardStackItemScope(
                        leave: (onLeft) =>
                            setState(() => _leaving[item.key] = onLeft),
                        child: tapRegion(item.child),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One card at its slot: its scale and fade, its place in the layout.
class _Card extends StatefulWidget {
  const _Card({
    required this.slot,
    required this.slotMotion,
    required this.leaveMotion,
    required this.fan,
    required this.expanded,
    required this.anchor,
    required this.peekScale,
    required this.maxPeeks,
    required this.lifted,
    required this.leaving,
    required this.onLeft,
    required this.hideExtra,
    required this.onFocusChange,
    required this.child,
    super.key,
  });

  /// Null keeps the last slot (a leaving card without one).
  final double? slot;
  final Motion slotMotion;
  final Motion leaveMotion;
  final double fan;
  final bool expanded;
  final CoilCardStackAnchor anchor;
  final double peekScale;
  final int maxPeeks;
  final bool lifted;
  final bool leaving;
  final VoidCallback? onLeft;
  final bool hideExtra;
  final ValueChanged<bool> onFocusChange;
  final Widget child;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  late double _slot = widget.slot ?? 0;
  var _left = false;

  /// Tells whoever asked the card to leave that it has, once.
  void _settle(double presence) {
    final onLeft = widget.onLeft;
    if (!widget.leaving || onLeft == null || _left || presence > 0.001) {
      return;
    }
    _left = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => onLeft());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slot case final slot?) _slot = slot;
    return SingleMotionBuilder(
      value: widget.leaving ? 0 : 1,
      motion: widget.leaveMotion,
      debugLabel: 'CoilCardStack.presence',
      builder: (context, presence, child) => SingleMotionBuilder(
        value: _slot,
        motion: widget.slotMotion,
        debugLabel: 'CoilCardStack.slot',
        child: child,
        builder: (context, slot, child) {
          _settle(presence);
          final fan = widget.fan;
          final peeking = slot.clamp(0.0, widget.maxPeeks.toDouble());
          final scale = 1 - peeking * widget.peekScale * (1 - fan);
          // Cards past the peeks fade out folded and in as it fans out.
          final folded = (widget.maxPeeks + 1 - slot).clamp(0.0, 1.0);
          final opacity = folded + (1 - folded) * fan;
          final hidden = widget.hideExtra && folded <= 0;
          return _CardSlot(
            slot: slot,
            presence: presence.clamp(0.0, 1.0),
            lifted: widget.lifted,
            // Folded, only the front card takes pointers.
            reachable:
                !widget.leaving &&
                (widget.expanded || (widget.slot ?? slot) < 0.5),
            scale: scale,
            child: Opacity(
              opacity: opacity,
              // Cards past the peeks stay readable: focus fans them out.
              alwaysIncludeSemantics: !widget.hideExtra,
              child: Transform.scale(
                scale: scale,
                // The far edge, the one that peeks, stays put.
                alignment: widget.anchor == CoilCardStackAnchor.bottom
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
                child: ExcludeFocus(
                  excluding: hidden,
                  child: ExcludeSemantics(excluding: hidden, child: child),
                ),
              ),
            ),
          );
        },
      ),
      child: Focus(
        // Fires for the card and anything focused inside it.
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: widget.onFocusChange,
        child: IgnorePointer(ignoring: widget.leaving, child: widget.child),
      ),
    );
  }
}

/// A card's place in a [_CardStackLayout].
class _CardSlot extends ParentDataWidget<_CardStackParentData> {
  const _CardSlot({
    required this.slot,
    required this.presence,
    required this.lifted,
    required this.reachable,
    required this.scale,
    required super.child,
  });

  final double slot;
  final double presence;
  final bool lifted;
  final bool reachable;
  final double scale;

  @override
  void applyParentData(RenderObject renderObject) {
    // Only hit testing reads `reachable`.
    final data = renderObject.parentData! as _CardStackParentData
      ..reachable = reachable;
    if (data.slot != slot ||
        data.presence != presence ||
        data.lifted != lifted ||
        data.scale != scale) {
      data
        ..slot = slot
        ..presence = presence
        ..lifted = lifted
        ..scale = scale;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _CardStackLayout;
}

class _CardStackParentData extends ContainerBoxParentData<RenderBox> {
  /// Places from the front, fractional while the card moves.
  double slot = 0;

  /// 1 while the card is in the pile, springing to 0 while it leaves: how
  /// much of its place the others still keep for it.
  double presence = 1;

  bool lifted = false;
  bool reachable = true;

  /// The card's paint scale, about its far edge.
  double scale = 1;

  /// How far from the anchor edge the card is cut off, or null when it
  /// isn't: the part of a card behind the front one that would pass the
  /// middle of the cards in front (and show at their rounded corners) is
  /// hidden behind them anyway.
  double? clipAt;
}

class _CardStackLayout extends MultiChildRenderObjectWidget {
  const _CardStackLayout({
    required this.fan,
    required this.anchor,
    required this.peek,
    required this.maxPeeks,
    required this.gap,
    required this.shift,
    required this.sideWidth,
    required this.hasBackground,
    required super.children,
  });

  final double fan;
  final CoilCardStackAnchor anchor;
  final double peek;
  final int maxPeeks;
  final double gap;
  final double shift;
  final double sideWidth;
  final bool hasBackground;

  @override
  RenderCoilCardStack createRenderObject(BuildContext context) =>
      RenderCoilCardStack(
        fan: fan,
        anchor: anchor,
        peek: peek,
        maxPeeks: maxPeeks,
        gap: gap,
        shift: shift,
        sideWidth: sideWidth,
        hasBackground: hasBackground,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCoilCardStack renderObject,
  ) {
    renderObject
      ..fan = fan
      ..anchor = anchor
      ..peek = peek
      ..maxPeeks = maxPeeks
      ..gap = gap
      ..shift = shift
      ..sideWidth = sideWidth
      ..hasBackground = hasBackground
      ..textDirection = Directionality.of(context);
  }
}

/// Where one card goes, as distances from the anchor edge.
class _Placement {
  const _Placement(this.far, this.near, this.clipAt);

  /// The far edge of the card's box (the edge that peeks).
  final double far;

  /// The near edge of its painted (scaled) box.
  final double near;

  /// Where it is cut off, or null.
  final double? clipAt;
}

/// The render object of a [CoilCardStack]'s layout.
///
/// Children, in order: the background (or an empty box), the pile's area,
/// the leading and trailing sides, then the cards.
///
/// Positions are distances from the anchor edge. For a card `c` at slot
/// `s`, the cards whose slots cover the slot range in front of it decide
/// where it goes, each by the share of a slot it covers (times its
/// presence), and any part no other card covers counts at `c`'s own size.
/// So with equal heights a card sits `s` pitches out, with mixed heights
/// it sits after the measured cards in front of it, and every position is
/// continuous in every slot, presence and height:
///
/// - fanned out, its near edge is the sum of the heights plus gaps in front
///   of it;
/// - folded, its far edge is the front card's far edge (the cover of slot
///   range 0–1) plus `min(s, maxPeeks)` peeks, so peeks are even whatever
///   the heights.
class RenderCoilCardStack extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CardStackParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CardStackParentData> {
  /// Creates the render object.
  RenderCoilCardStack({
    required this._fan,
    required this._anchor,
    required this._peek,
    required this._maxPeeks,
    required this._gap,
    required this._shift,
    required this._sideWidth,
    required this._hasBackground,
    required this._textDirection,
  });

  double _fan;

  /// 0 folded, 1 fanned out.
  double get fan => _fan;
  set fan(double value) {
    if (value == _fan) return;
    _fan = value;
    markNeedsLayout();
  }

  CoilCardStackAnchor _anchor;

  /// The edge the front card sits at.
  CoilCardStackAnchor get anchor => _anchor;
  set anchor(CoilCardStackAnchor value) {
    if (value == _anchor) return;
    _anchor = value;
    markNeedsLayout();
  }

  double _peek;

  /// How far each card behind the front one peeks, folded.
  double get peek => _peek;
  set peek(double value) {
    if (value == _peek) return;
    _peek = value;
    markNeedsLayout();
  }

  int _maxPeeks;

  /// How many cards peek, folded.
  int get maxPeeks => _maxPeeks;
  set maxPeeks(int value) {
    if (value == _maxPeeks) return;
    _maxPeeks = value;
    markNeedsLayout();
  }

  double _gap;

  /// The space between fanned-out cards.
  double get gap => _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _shift;

  /// How far the pile is moved away from the anchor edge.
  double get shift => _shift;
  set shift(double value) {
    if (value == _shift) return;
    _shift = value;
    markNeedsLayout();
  }

  double _sideWidth;

  /// The width of the leading and trailing sides.
  double get sideWidth => _sideWidth;
  set sideWidth(double value) {
    if (value == _sideWidth) return;
    _sideWidth = value;
    markNeedsLayout();
  }

  bool _hasBackground;

  /// Whether the first child is a background that fills the stack.
  bool get hasBackground => _hasBackground;
  set hasBackground(bool value) {
    if (value == _hasBackground) return;
    _hasBackground = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;

  /// Which side leading is on.
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  /// Cards back to front, then the lifted one: the paint order.
  List<RenderBox> _paintOrder = const [];

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CardStackParentData) {
      child.parentData = _CardStackParentData();
    }
  }

  static _CardStackParentData _data(RenderBox child) =>
      child.parentData! as _CardStackParentData;

  List<RenderBox> get _cards {
    final cards = <RenderBox>[];
    var child = firstChild;
    for (var i = 0; i < 4 && child != null; i++) {
      child = childAfter(child);
    }
    while (child != null) {
      cards.add(child);
      child = childAfter(child);
    }
    return cards;
  }

  /// How much of the slot range [from, to) the other cards cover, each
  /// weighted by `value(card)` and its presence; the rest counts at [own].
  static double _cover(
    List<({double slot, double presence, double extent})> others,
    double from,
    double to,
    double own,
  ) {
    final length = to - from;
    if (length <= 0) return 0;
    var covered = 0.0;
    var sum = 0.0;
    for (final other in others) {
      final overlap = math.min(to, other.slot + 1) - math.max(from, other.slot);
      if (overlap <= 0) continue;
      final weight = overlap * other.presence;
      covered += weight;
      sum += weight * other.extent;
    }
    // Cards crossing each other can cover a range twice for a moment.
    if (covered > length) {
      sum *= length / covered;
      covered = length;
    }
    return sum + (length - covered) * own;
  }

  /// Where each of [cards] goes, given its [heights].
  List<_Placement> _place(List<RenderBox> cards, List<double> heights) {
    final placements = <_Placement>[];
    for (var i = 0; i < cards.length; i++) {
      final data = _data(cards[i]);
      final others = [
        for (var j = 0; j < cards.length; j++)
          if (j != i)
            (
              slot: _data(cards[j]).slot,
              presence: _data(cards[j]).presence,
              extent: heights[j],
            ),
      ];
      final s = math.max<double>(0, data.slot);
      final h = heights[i];
      // Fanned: the near edge after the cards in front, a gap after each.
      final fannedNear = _cover(
        [
          for (final o in others)
            (slot: o.slot, presence: o.presence, extent: o.extent + _gap),
        ],
        0,
        s,
        h + _gap,
      );
      // Folded: the far edge a fixed number of peeks past the front card's.
      final front = _cover(others, 0, 1, h);
      final foldedFar = front + math.min(s, _maxPeeks.toDouble()) * _peek;
      final far = foldedFar + (fannedNear + h - foldedFar) * _fan;
      final near = far - h * data.scale;
      // Folded, the part past the middle of the cards in front is behind
      // them; cut it off so it can't show at their rounded corners. Fanned
      // out nothing overlaps, so the cut fades to the anchor edge.
      final behind = _cover(others, 0, 1, 0) / 2 * (1 - _fan);
      placements.add(
        _Placement(far, near, near < behind - 0.5 ? behind : null),
      );
    }
    return placements;
  }

  /// The pile's extent from the anchor edge: folded, fanned, and now.
  ({double folded, double now}) _extent(
    List<RenderBox> cards,
    List<double> heights,
  ) {
    var folded = 0.0;
    var fanned = 0.0;
    final saved = _fan;
    _fan = 0;
    final foldedPlaces = _place(cards, heights);
    _fan = 1;
    final fannedPlaces = _place(cards, heights);
    _fan = saved;
    for (var i = 0; i < cards.length; i++) {
      final presence = _data(cards[i]).presence;
      folded = math.max(folded, foldedPlaces[i].far * presence);
      fanned = math.max(fanned, fannedPlaces[i].far * presence);
    }
    return (folded: folded, now: folded + (fanned - folded) * _fan);
  }

  @override
  void performLayout() {
    final background = firstChild;
    final region = background == null ? null : childAfter(background);
    final leading = region == null ? null : childAfter(region);
    final trailing = leading == null ? null : childAfter(leading);
    if (background == null ||
        region == null ||
        leading == null ||
        trailing == null) {
      size = constraints.smallest;
      return;
    }
    final width = constraints.maxWidth;
    final cardWidth = math.max(0, width - 2 * _sideWidth).toDouble();
    final cards = _cards;
    final heights = <double>[];
    for (final card in cards) {
      card.layout(
        BoxConstraints.tightFor(width: cardWidth),
        parentUsesSize: true,
      );
      heights.add(card.size.height);
    }
    final places = _place(cards, heights);
    final extent = _extent(cards, heights);
    final live = cards.where((c) => _data(c).presence > 0).isNotEmpty;

    if (_hasBackground) {
      size = constraints.biggest;
      background.layout(
        CoilCardStackConstraints.tight(
          size,
          pileExtent: live ? extent.folded + _gap : 0,
        ),
      );
    } else {
      size = constraints.constrain(Size(width, extent.now));
      background.layout(const BoxConstraints.tightFor(width: 0, height: 0));
    }
    _data(background).offset = Offset.zero;

    final bottom = _anchor == CoilCardStackAnchor.bottom;
    // A distance from the anchor edge to a y offset for an [extent] tall
    // box whose far edge is [far] out.
    double y(double far, double extent) =>
        bottom ? size.height - _shift - far : _shift + far - extent;

    region.layout(BoxConstraints.tightFor(width: width, height: extent.now));
    _data(region).offset = Offset(0, y(extent.now, extent.now));

    // The sides sit beside the front card.
    var frontHeight = 0.0;
    var frontSlot = double.infinity;
    for (var i = 0; i < cards.length; i++) {
      final data = _data(cards[i]);
      if (data.presence < 1) continue;
      if (data.slot < frontSlot) {
        frontSlot = data.slot;
        frontHeight = heights[i];
      }
    }
    final ltr = _textDirection == TextDirection.ltr;
    for (final (side, start) in [(leading, true), (trailing, false)]) {
      side.layout(
        BoxConstraints.tightFor(width: _sideWidth, height: frontHeight),
      );
      _data(side).offset = Offset(
        start == ltr ? 0 : width - _sideWidth,
        y(frontHeight, frontHeight),
      );
    }

    for (var i = 0; i < cards.length; i++) {
      _data(cards[i])
        ..offset = Offset(_sideWidth, y(places[i].far, heights[i]))
        ..clipAt = places[i].clipAt;
    }
    _paintOrder = [...cards]
      ..sort((a, b) {
        final da = _data(a);
        final db = _data(b);
        if (da.lifted != db.lifted) return da.lifted ? 1 : -1;
        return db.slot.compareTo(da.slot);
      });
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final background = firstChild;
    if (background == null) return;
    final region = childAfter(background)!;
    final leading = childAfter(region)!;
    final trailing = childAfter(leading)!;
    for (final child in [background, region, leading, trailing]) {
      context.paintChild(child, _data(child).offset + offset);
    }
    // Generous on the sides and the far side, so shadows stay.
    const room = 1e5;
    final bottom = _anchor == CoilCardStackAnchor.bottom;
    for (final card in _paintOrder) {
      final data = _data(card);
      final clipAt = data.clipAt;
      if (clipAt == null) {
        context.paintChild(card, data.offset + offset);
        continue;
      }
      final edge = bottom ? size.height - _shift - clipAt : _shift + clipAt;
      final keep = bottom
          ? Rect.fromLTRB(-room, -room, size.width + room, edge)
          : Rect.fromLTRB(-room, edge, size.width + room, size.height + room);
      context.pushClipRect(
        needsCompositing,
        offset,
        keep,
        (context, offset) => context.paintChild(card, data.offset + offset),
      );
    }
  }

  bool _hit(BoxHitTestResult result, RenderBox child, Offset position) =>
      result.addWithPaintOffset(
        offset: _data(child).offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final background = firstChild;
    if (background == null) return false;
    final region = childAfter(background)!;
    final leading = childAfter(region)!;
    final trailing = childAfter(leading)!;
    var pile = false;
    for (final child in [..._paintOrder.reversed, leading, trailing]) {
      final data = _data(child);
      // A folded pile's cards behind the front one let the pointer through
      // to the pile, which fans out on a tap.
      if (!data.reachable) continue;
      if (_hit(result, child, position)) {
        pile = true;
        break;
      }
    }
    // A pointer over a card is over the pile too, so the pile hears it and
    // stays fanned out while the pointer moves between cards.
    if (_hit(result, region, position)) pile = true;
    return pile || _hit(result, background, position);
  }

  List<double> _heightsBy(double Function(RenderBox) height) => [
    for (final card in _cards) height(card),
  ];

  double _intrinsicHeight(double width, double Function(RenderBox, double) of) {
    if (_hasBackground) return 0;
    final cardWidth = math.max(0, width - 2 * _sideWidth).toDouble();
    final cards = _cards;
    return _extent(cards, _heightsBy((c) => of(c, cardWidth))).now;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(
    width,
    (child, width) => child.getMinIntrinsicHeight(width),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(
    width,
    (child, width) => child.getMaxIntrinsicHeight(width),
  );

  @override
  double computeMinIntrinsicWidth(double height) {
    var widest = 0.0;
    for (final card in _cards) {
      widest = math.max(widest, card.getMinIntrinsicWidth(double.infinity));
    }
    return widest + 2 * _sideWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var widest = 0.0;
    for (final card in _cards) {
      widest = math.max(widest, card.getMaxIntrinsicWidth(double.infinity));
    }
    return widest + 2 * _sideWidth;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (_hasBackground) return constraints.biggest;
    final width = constraints.maxWidth;
    final cardWidth = math.max(0, width - 2 * _sideWidth).toDouble();
    final cards = _cards;
    final heights = _heightsBy(
      (c) => c.getDryLayout(BoxConstraints.tightFor(width: cardWidth)).height,
    );
    return constraints.constrain(Size(width, _extent(cards, heights).now));
  }
}
