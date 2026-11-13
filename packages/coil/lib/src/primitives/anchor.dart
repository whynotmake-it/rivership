import 'dart:math' as math;

import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/popup_controller.dart';
import 'package:coil/src/primitives/presence.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Which side of its anchor a popover landed on.
enum CoilPopoverSide {
  /// Below the anchor (the preferred side).
  bottom,

  /// Above the anchor, when it doesn't fit below and there's more room
  /// above.
  top,

  /// Left of the anchor, for a horizontal popover.
  left,

  /// Right of the anchor, for a horizontal popover.
  right,
}

/// Shows and hides a [CoilPopover], like [OverlayPortalController] does
/// for an [OverlayPortal]. Call [show] and [hide] from event handlers, not
/// during build.
class CoilPopoverController {
  /// Creates a controller.
  CoilPopoverController({this.debugLabel});

  /// A name for debugging.
  final String? debugLabel;

  _CoilPopoverState? _state;

  /// Whether the popover is open. False as soon as [hide] is called, while
  /// it still springs out.
  bool get isOpen => _state?._open ?? false;

  /// Opens the popover next to the anchor, or at [at], a point in the
  /// anchor's local coordinates.
  void show({Offset? at}) {
    assert(_state != null, '$this is not attached to a CoilPopover');
    _state?._show(at);
  }

  /// Closes the popover: it springs out, then leaves the overlay.
  void hide() => _state?._hide();

  @override
  String toString() => 'CoilPopoverController(${debugLabel ?? ''})';
}

/// Shows [popover] next to [child]: a menu, a select list. [controller]
/// opens and closes it.
///
/// The popover lives in the nearest [Overlay] but stays a descendant of
/// this widget, so it inherits its themes and rebuilds with its owner. It
/// follows [child] in the same frame when [child] moves.
///
/// While open:
///
/// * A tap outside closes it on tap-up, with
///   [CoilPopupCloseReason.outsideTap], and doesn't reach what's below.
/// * It takes focus in its own scope and hands it back to what had focus
///   when it opened.
/// * Escape closes it with [CoilPopupCloseReason.escape].
/// * The system back gesture (Android predictive back included) closes it
///   with [CoilPopupCloseReason.dismissed] instead of popping the page.
///
/// Those ask [onClose] to close; the owner decides and calls
/// [CoilPopoverController.hide].
///
/// Like `MenuAnchor`, it blocks pointer input only. Screen readers reach
/// its content right after the anchor, and the rest of the page stays
/// reachable.
///
/// It springs in on the theme's `standard` tokens, growing from the edge
/// next to the anchor while it blur-fades. Under reduced motion it only
/// fades, on `fade`.
class CoilPopover extends StatefulWidget {
  /// Creates a popover anchored to [child].
  const CoilPopover({
    required this.controller,
    required this.onClose,
    required this.popover,
    required this.child,
    super.key,
    this.minWidth,
    this.maxHeight = double.infinity,
    this.sideOffset = 6,
    this.edgePadding = 8,
    this.axis = Axis.vertical,
    this.crossOffset = 0,
    this.motion,
  });

  /// Opens and closes the popover.
  final CoilPopoverController controller;

  /// Called when the popover asks to close.
  final ValueChanged<CoilPopupCloseReason> onClose;

  /// Builds the popover's content.
  final WidgetBuilder popover;

  /// The anchor.
  final Widget child;

  /// Minimum popover width. Defaults to the anchor's width, or none when it
  /// opens at a point.
  final double? minWidth;

  /// Maximum popover height.
  final double maxHeight;

  /// Gap between the anchor and the popover.
  final double sideOffset;

  /// Distance kept from the overlay's edges and the safe area.
  final double edgePadding;

  /// Where it opens: [Axis.vertical] below the anchor, or above it when
  /// there's more room; [Axis.horizontal] past the anchor's end, or before
  /// its start when it doesn't fit, like a submenu.
  final Axis axis;

  /// For [Axis.horizontal], how far above the anchor's top it starts, so
  /// its first row can line up with the anchor.
  final double crossOffset;

  /// Motion tokens for the enter and exit, instead of the theme's.
  final CoilMotion? motion;

  @override
  State<CoilPopover> createState() => _CoilPopoverState();
}

class _CoilPopoverState extends State<CoilPopover>
    with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController(debugLabel: 'CoilPopover');
  final _scope = FocusScopeNode(debugLabel: 'CoilPopover');
  late final _presence = SingleMotionController(
    motion: const Motion.instant(),
    vsync: this,
    velocityTracking: const VelocityTracking.off(),
    debugLabel: 'CoilPopover.presence',
  )..addStatusListener(_onStatus);

  bool _open = false;

  /// The point it opened at, in the anchor's coordinates, if any.
  Offset? _at;

  /// What had focus when the popover opened.
  FocusNode? _returnFocus;

  /// Pointers that went down outside while open. Only their up is a tap
  /// outside: the finger that long-pressed it open lifts outside too.
  final _downOutside = <int>{};

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void didUpdateWidget(CoilPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller._state == this) {
        oldWidget.controller._state = null;
      }
      widget.controller._state = this;
    }
  }

  void _show(Offset? at) {
    if (_open) return;
    _returnFocus = FocusManager.instance.primaryFocus;
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    _portal.show();
    setState(() {
      _open = true;
      _at = at;
    });
    _presence
      ..motion = _reduceMotion ? motion.fade : motion.standard
      ..animateTo(1);
  }

  void _hide() {
    if (!_open) return;
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    setState(() => _open = false);
    _presence
      ..motion = _reduceMotion ? motion.fadeExit : motion.standardExit
      ..animateTo(0);
    if (_scope.hasFocus) _returnFocus?.requestFocus();
    _returnFocus = null;
  }

  void _onStatus(AnimationStatus status) {
    if (status.isDismissed && !_open && _portal.isShowing) _portal.hide();
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _presence.dispose();
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal.overlayChildLayoutBuilder(
    controller: _portal,
    overlayChildBuilder: _buildPopover,
    child: widget.child,
  );

  Widget _buildPopover(BuildContext context, OverlayChildLayoutInfo info) {
    final open = _open;
    final media = MediaQuery.of(context);
    final reduce = _reduceMotion;
    void close(CoilPopupCloseReason reason) {
      if (_open) widget.onClose(reason);
    }

    // A popover opened from inside another, like a submenu, counts as
    // inside it: taps in it don't close the outer one.
    final outer = _CoilPopoverGroup.maybeOf(context);
    final popover = PopScope<Object?>(
      // While open, back closes the popover instead of popping the page.
      canPop: !open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close(.dismissed);
      },
      child: _CoilPopoverPlacement(
        // A point opens it right there; the anchor's rect, next to it.
        anchor: MatrixUtils.transformRect(
          info.childPaintTransform,
          _at == null ? Offset.zero & info.childSize : _at! & Size.zero,
        ),
        presence: _presence,
        grow: !reduce,
        safeArea: media.padding + media.viewInsets,
        axis: widget.axis,
        crossOffset: widget.crossOffset,
        sideOffset: _at == null ? widget.sideOffset : 0,
        edgePadding: widget.edgePadding,
        minWidth: widget.minWidth ?? (_at == null ? info.childSize.width : 0),
        maxHeight: widget.maxHeight,
        textDirection: Directionality.of(context),
        // Closing: it can't be used while it springs out.
        child: IgnorePointer(
          ignoring: !open,
          // Like MenuAnchor: a tap outside closes it on tap-up and
          // doesn't reach what's below. No ModalBarrier: its
          // BlockSemantics would hide the popover too, whose semantics
          // hang under the anchor's node.
          child: TapRegion(
            groupId: this,
            consumeOutsideTaps: open,
            onTapOutside: (event) => _downOutside.add(event.pointer),
            onTapUpOutside: (event) {
              if (_downOutside.remove(event.pointer)) close(.outsideTap);
            },
            child: FocusScope(
              node: _scope,
              autofocus: true,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): () =>
                      close(.escape),
                },
                child: Semantics(
                  scopesRoute: true,
                  explicitChildNodes: true,
                  child: CoilBlurFade(
                    presence: _presence,
                    // The grow from the anchor's edge is the placement's:
                    // only it knows which side that is.
                    scale: 1,
                    blur: reduce ? 0 : 4,
                    child: _CoilPopoverGroup(
                      group: this,
                      child: Builder(builder: widget.popover),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return outer == null ? popover : TapRegion(groupId: outer, child: popover);
  }
}

/// The tap group of the popover around its content.
class _CoilPopoverGroup extends InheritedWidget {
  const _CoilPopoverGroup({required this.group, required super.child});

  final Object group;

  static Object? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_CoilPopoverGroup>()?.group;

  @override
  bool updateShouldNotify(_CoilPopoverGroup oldWidget) =>
      oldWidget.group != group;
}

/// Lays the popover out next to [anchor] and grows it from that edge as
/// [presence] goes from 0 to 1.
///
/// The side is decided in layout: the child is laid out first, then it
/// opens below the anchor if it fits, else above when there is more room
/// there. It fills the overlay; [anchor] is in the overlay's coordinates.
class _CoilPopoverPlacement extends SingleChildRenderObjectWidget {
  const _CoilPopoverPlacement({
    required this.anchor,
    required this.axis,
    required this.crossOffset,
    required this.presence,
    required this.grow,
    required this.safeArea,
    required this.sideOffset,
    required this.edgePadding,
    required this.minWidth,
    required this.maxHeight,
    required this.textDirection,
    required super.child,
  });

  /// The anchor's rect.
  final Rect anchor;

  /// Whether it opens below or beside the anchor.
  final Axis axis;

  /// How far above the anchor a horizontal child starts.
  final double crossOffset;

  /// 0 (gone) to 1 (fully present).
  final Animation<double> presence;

  /// Whether the child scales and slides from the anchored edge.
  final bool grow;

  /// Insets to keep clear: the safe area and the keyboard.
  final EdgeInsets safeArea;

  /// Gap between the anchor and the child.
  final double sideOffset;

  /// Distance kept from the edges.
  final double edgePadding;

  /// Minimum child width.
  final double minWidth;

  /// Maximum child height.
  final double maxHeight;

  /// Which edge of the anchor the child aligns with: its start.
  final TextDirection textDirection;

  @override
  _RenderCoilPopoverPlacement createRenderObject(BuildContext context) =>
      _RenderCoilPopoverPlacement(
        anchor: anchor,
        axis: axis,
        crossOffset: crossOffset,
        presence: presence,
        grow: grow,
        safeArea: safeArea,
        sideOffset: sideOffset,
        edgePadding: edgePadding,
        minWidth: minWidth,
        maxHeight: maxHeight,
        textDirection: textDirection,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCoilPopoverPlacement renderObject,
  ) {
    renderObject
      ..anchor = anchor
      ..axis = axis
      ..crossOffset = crossOffset
      ..presence = presence
      ..grow = grow
      ..safeArea = safeArea
      ..sideOffset = sideOffset
      ..edgePadding = edgePadding
      ..minWidth = minWidth
      ..maxHeight = maxHeight
      ..textDirection = textDirection;
  }
}

class _RenderCoilPopoverPlacement extends RenderProxyBox {
  /// Creates the render object.
  _RenderCoilPopoverPlacement({
    required this._anchor,
    required this._axis,
    required this._crossOffset,
    required this._presence,
    required this._grow,
    required this._safeArea,
    required this._sideOffset,
    required this._edgePadding,
    required this._minWidth,
    required this._maxHeight,
    required this._textDirection,
  });

  Rect get anchor => _anchor;
  Rect _anchor;
  set anchor(Rect value) {
    if (value == _anchor) return;
    _anchor = value;
    markNeedsLayout();
  }

  Axis get axis => _axis;
  Axis _axis;
  set axis(Axis value) {
    if (value == _axis) return;
    _axis = value;
    markNeedsLayout();
  }

  double get crossOffset => _crossOffset;
  double _crossOffset;
  set crossOffset(double value) {
    if (value == _crossOffset) return;
    _crossOffset = value;
    markNeedsLayout();
  }

  Animation<double> get presence => _presence;
  Animation<double> _presence;
  set presence(Animation<double> value) {
    if (value == _presence) return;
    if (attached) _presence.removeListener(_onPresence);
    _presence = value;
    if (attached) _presence.addListener(_onPresence);
    markNeedsPaint();
  }

  bool get grow => _grow;
  bool _grow;
  set grow(bool value) {
    if (value == _grow) return;
    _grow = value;
    markNeedsPaint();
  }

  EdgeInsets get safeArea => _safeArea;
  EdgeInsets _safeArea;
  set safeArea(EdgeInsets value) {
    if (value == _safeArea) return;
    _safeArea = value;
    markNeedsLayout();
  }

  double get sideOffset => _sideOffset;
  double _sideOffset;
  set sideOffset(double value) {
    if (value == _sideOffset) return;
    _sideOffset = value;
    markNeedsLayout();
  }

  double get edgePadding => _edgePadding;
  double _edgePadding;
  set edgePadding(double value) {
    if (value == _edgePadding) return;
    _edgePadding = value;
    markNeedsLayout();
  }

  double get minWidth => _minWidth;
  double _minWidth;
  set minWidth(double value) {
    if (value == _minWidth) return;
    _minWidth = value;
    markNeedsLayout();
  }

  double get maxHeight => _maxHeight;
  double _maxHeight;
  set maxHeight(double value) {
    if (value == _maxHeight) return;
    _maxHeight = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  CoilPopoverSide _side = CoilPopoverSide.bottom;
  Offset _childOffset = Offset.zero;

  void _onPresence() {
    // Only the grow depends on presence.
    if (_grow) markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _presence.addListener(_onPresence);
  }

  @override
  void detach() {
    _presence.removeListener(_onPresence);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) return;
    if (_axis == Axis.horizontal) return _layoutBeside(child);
    final below =
        size.height -
        _safeArea.bottom -
        _edgePadding -
        _anchor.bottom -
        _sideOffset;
    final above = _anchor.top - _sideOffset - _edgePadding - _safeArea.top;
    final maxWidth = math.max(0, size.width - _edgePadding * 2).toDouble();
    BoxConstraints within(double room) => BoxConstraints(
      minWidth: math.min(_minWidth, maxWidth),
      maxWidth: maxWidth,
      maxHeight: math.max(0, math.min(_maxHeight, room)).toDouble(),
    );

    // Lay out in the bigger room, then decide: below if it fits there,
    // else on the side with more room (laid out again if that's below).
    child.layout(within(math.max(below, above)), parentUsesSize: true);
    if (child.size.height <= below || below >= above) {
      _side = CoilPopoverSide.bottom;
      if (child.size.height > below) {
        child.layout(within(below), parentUsesSize: true);
      }
    } else {
      _side = CoilPopoverSide.top;
    }

    // Align with the anchor's start edge; if that runs off the window and
    // its end edge doesn't, align with the end, as menus at a pointer open
    // away from the edge. Else keep it on screen.
    final width = child.size.width;
    final ltr = _textDirection == TextDirection.ltr;
    final start = ltr ? _anchor.left : _anchor.right - width;
    final end = ltr ? _anchor.right - width : _anchor.left;
    bool fits(double x) =>
        x >= _edgePadding && x + width <= size.width - _edgePadding;
    final aligned = !fits(start) && fits(end) ? end : start;
    final x = aligned.clamp(
      _edgePadding,
      math.max(_edgePadding, size.width - _edgePadding - width),
    );
    final y = _side == CoilPopoverSide.bottom
        ? _anchor.bottom + _sideOffset
        : _anchor.top - _sideOffset - child.size.height;
    _childOffset = Offset(x.toDouble(), y);
  }

  /// Lays the child out past the anchor's end, or before its start when it
  /// only fits there, its top [crossOffset] above the anchor's.
  void _layoutBeside(RenderBox child) {
    final top = _safeArea.top + _edgePadding;
    final bottom = size.height - _safeArea.bottom - _edgePadding;
    final left = _safeArea.left + _edgePadding;
    final right = size.width - _safeArea.right - _edgePadding;
    child.layout(
      BoxConstraints(
        minWidth: math.min(_minWidth, math.max(0, right - left)),
        maxWidth: math.max(0, right - left),
        maxHeight: math.max(0, math.min(_maxHeight, bottom - top)),
      ),
      parentUsesSize: true,
    );
    final width = child.size.width;
    final afterRight = _anchor.right + _sideOffset;
    final beforeLeft = _anchor.left - _sideOffset - width;
    final rightFits = afterRight + width <= right;
    final leftFits = beforeLeft >= left;
    final preferRight = _textDirection == TextDirection.ltr;
    final onRight = preferRight
        ? rightFits || !leftFits && right - _anchor.right >= _anchor.left - left
        : !leftFits &&
              (rightFits || right - _anchor.right > _anchor.left - left);
    _side = onRight ? CoilPopoverSide.right : CoilPopoverSide.left;
    final x = (onRight ? afterRight : beforeLeft).clamp(
      left,
      math.max(left, right - width),
    );
    final y = (_anchor.top - _crossOffset).clamp(
      top,
      math.max(top, bottom - child.size.height),
    );
    _childOffset = Offset(x.toDouble(), y.toDouble());
  }

  /// Where the child is drawn: at its offset and, while growing, scaled
  /// 0.96 and slid 4 px toward the anchor at presence 0.
  Matrix4 get _childTransform {
    final transform = Matrix4.translationValues(
      _childOffset.dx,
      _childOffset.dy,
      0,
    );
    if (!_grow) return transform;
    final away = 1 - _presence.value;
    final size = child!.size;
    final (origin, slide) = switch (_side) {
      CoilPopoverSide.bottom => (
        Offset(size.width / 2, 0),
        const Offset(0, -4),
      ),
      CoilPopoverSide.top => (
        Offset(size.width / 2, size.height),
        const Offset(0, 4),
      ),
      CoilPopoverSide.right => (Offset.zero, const Offset(-4, 0)),
      CoilPopoverSide.left => (Offset(size.width, 0), const Offset(4, 0)),
    };
    final scale = 1 - 0.04 * away;
    return transform
      ..translateByDouble(slide.dx * away, slide.dy * away, 0, 1)
      ..translateByDouble(origin.dx, origin.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-origin.dx, -origin.dy, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _childTransform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.multiply(_childTransform);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _childTransform,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }
}
