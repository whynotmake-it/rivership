import 'dart:math' as math;

import 'package:coil/src/primitives/presence.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Which side of its anchor a popover landed on.
enum CoilPopoverSide {
  /// Below the anchor (the preferred side).
  bottom,

  /// Above the anchor, when it doesn't fit below and there's more room
  /// above.
  top,
}

/// A popover anchored to a widget: a menu, a select list.
///
/// A [PopupRoute], so it gets a focus scope, Escape and back, and a result.
/// It springs in on [enterMotion] and out on [exitMotion] (a
/// [CoilSpringRoute]): it grows from the edge next to the anchor while it
/// blur-fades. Under reduced motion it only fades.
///
/// The side is decided in layout: the content is laid out first, then it
/// opens below the anchor if it fits, else above when there is more room
/// there. The anchor's rect is read whenever the route rebuilds, so the
/// popover follows the anchor when the window resizes or the keyboard
/// moves it (one frame behind the trigger).
class CoilPopoverRoute<T> extends PopupRoute<T> with CoilSpringRoute<T> {
  /// Creates a popover anchored to the box of [anchorContext].
  CoilPopoverRoute({
    required this.anchorContext,
    required this.builder,
    required this.enterMotion,
    required this.exitMotion,
    this.reduceMotion = false,
    this.minWidth = 0,
    this.maxHeight = double.infinity,
    this.sideOffset = 6,
    this.edgePadding = 8,
    this.capturedThemes,
    this.barrierLabel,
    this.barrierDismissible = true,
    super.settings,
  });

  /// The anchor: its box is read whenever the route builds.
  final BuildContext anchorContext;

  /// The contents.
  final WidgetBuilder builder;

  @override
  final Motion enterMotion;

  @override
  final Motion exitMotion;

  /// Whether to fade only, without the grow and blur.
  final bool reduceMotion;

  /// Minimum popover width (usually the anchor's).
  final double minWidth;

  /// Maximum popover height.
  final double maxHeight;

  /// Gap between the anchor and the popover.
  final double sideOffset;

  /// Distance kept from the window edges and safe area.
  final double edgePadding;

  /// Inherited themes carried over from the anchor's context.
  final CapturedThemes? capturedThemes;

  @override
  Color? get barrierColor => null;

  /// Whether tapping the invisible barrier pops the route. Off when the
  /// content closes itself on an outside tap.
  @override
  final bool barrierDismissible;

  @override
  final String? barrierLabel;

  /// The anchor's rect in [overlay]'s coordinates, or null while it isn't
  /// laid out. Read in build: a route may not read another subtree's size
  /// during its own layout.
  Rect? _anchorIn(RenderObject? overlay) {
    if (overlay == null || !anchorContext.mounted) return null;
    final box = anchorContext.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(overlay),
      Offset.zero & box.size,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    Widget content = CoilBlurFade(
      presence: animation,
      // The grow from the anchor's edge is the placement's: only it knows
      // which side that is.
      scale: 1,
      blur: reduceMotion ? 0 : 4,
      child: Builder(builder: builder),
    );
    content = capturedThemes?.wrap(content) ?? content;
    final media = MediaQuery.of(context);
    return _CoilPopoverPlacement(
      anchor: _anchorIn(navigator?.context.findRenderObject()),
      presence: animation,
      grow: !reduceMotion,
      safeArea: media.padding + media.viewInsets,
      sideOffset: sideOffset,
      edgePadding: edgePadding,
      minWidth: minWidth,
      maxHeight: maxHeight,
      textDirection: Directionality.of(context),
      child: content,
    );
  }
}

/// Lays a popover out next to its anchor and grows it from that edge.
class _CoilPopoverPlacement extends SingleChildRenderObjectWidget {
  const _CoilPopoverPlacement({
    required this.anchor,
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

  final Rect? anchor;
  final Animation<double> presence;
  final bool grow;
  final EdgeInsets safeArea;
  final double sideOffset;
  final double edgePadding;
  final double minWidth;
  final double maxHeight;
  final TextDirection textDirection;

  @override
  _RenderCoilPopoverPlacement createRenderObject(BuildContext context) =>
      _RenderCoilPopoverPlacement(
        anchor: anchor,
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
      ..presence = presence
      ..grow = grow
      ..safeArea = safeArea
      ..sideOffset = sideOffset
      ..edgePadding = edgePadding
      ..minWidth = minWidth
      ..maxHeight = maxHeight
      ..textDirection = textDirection
      // The route rebuilt: the anchor or the safe area may have moved.
      ..markNeedsLayout();
  }
}

class _RenderCoilPopoverPlacement extends RenderProxyBox {
  _RenderCoilPopoverPlacement({
    required this._anchor,
    required this._presence,
    required this.grow,
    required this.safeArea,
    required this.sideOffset,
    required this.edgePadding,
    required this.minWidth,
    required this.maxHeight,
    required this.textDirection,
  });

  Rect? get anchor => _anchor;
  Rect? _anchor;
  set anchor(Rect? value) {
    if (value == _anchor) return;
    _anchor = value;
    markNeedsLayout();
  }

  bool grow;
  EdgeInsets safeArea;
  double sideOffset;
  double edgePadding;
  double minWidth;
  double maxHeight;
  TextDirection textDirection;

  Animation<double> get presence => _presence;
  Animation<double> _presence;
  set presence(Animation<double> value) {
    if (value == _presence) return;
    if (attached) _presence.removeListener(markNeedsPaint);
    _presence = value;
    if (attached) _presence.addListener(markNeedsPaint);
  }

  CoilPopoverSide _side = CoilPopoverSide.bottom;
  Offset _childOffset = Offset.zero;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _presence.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _presence.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;
    final anchor =
        this.anchor ??
        Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0);
    final below =
        size.height -
        safeArea.bottom -
        edgePadding -
        anchor.bottom -
        sideOffset;
    final above = anchor.top - sideOffset - edgePadding - safeArea.top;
    final maxWidth = math.max(0, size.width - edgePadding * 2).toDouble();
    BoxConstraints within(double room) => BoxConstraints(
      minWidth: math.min(minWidth, maxWidth),
      maxWidth: maxWidth,
      maxHeight: math.max(0, math.min(maxHeight, room)).toDouble(),
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

    final start = textDirection == TextDirection.ltr
        ? anchor.left
        : anchor.right - child.size.width;
    final x = start.clamp(
      edgePadding,
      math.max(edgePadding, size.width - edgePadding - child.size.width),
    );
    final y = _side == CoilPopoverSide.bottom
        ? anchor.bottom + sideOffset
        : anchor.top - sideOffset - child.size.height;
    _childOffset = Offset(x.toDouble(), y);
  }

  /// Grows from the edge next to the anchor: scale 0.96 and a 4 px slide
  /// toward the anchor at presence 0.
  Matrix4 get _grow {
    final away = 1 - presence.value;
    final bottom = _side == CoilPopoverSide.bottom;
    final size = child!.size;
    final origin = Offset(size.width / 2, bottom ? 0 : size.height);
    final scale = 1 - 0.04 * away;
    return Matrix4.identity()
      ..translateByDouble(0, (bottom ? -4.0 : 4.0) * away, 0, 1)
      ..translateByDouble(origin.dx, origin.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-origin.dx, -origin.dy, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final at = offset + _childOffset;
    if (!grow) {
      context.paintChild(child, at);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      at,
      _grow,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_childOffset.dx, _childOffset.dy, 0, 1);
    if (grow) transform.multiply(_grow);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform:
          (Matrix4.identity()
              ..translateByDouble(_childOffset.dx, _childOffset.dy, 0, 1))
            ..multiply(grow ? _grow : Matrix4.identity()),
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }
}
