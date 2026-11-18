import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A render object that paints its child away from where layout put it,
/// without telling hit testing, so `localToGlobal` doesn't include the
/// offset.
///
/// `MotionLayoutItem` is one: while it flies, it paints the item at an offset
/// but hit-tests it at its layout position.
abstract interface class PaintOffset {
  /// How far from its layout position the child was last painted, in the
  /// parent's coordinates.
  Offset get paintOffset;
}

/// The rect of [box] in global coordinates as it was last painted: its
/// layout position plus the [PaintOffset] of every ancestor, each in its own
/// coordinates, so a transform above one, such as a scale, applies to it.
/// With [includeOwn], also [box]'s own [PaintOffset].
Rect paintedGlobalRect(RenderBox box, {bool includeOwn = false}) =>
    MatrixUtils.transformRect(
      paintedTransformToGlobal(box, includeOwn: includeOwn),
      Offset.zero & box.size,
    );

/// Where [box]'s top left was last painted, in global coordinates, with its
/// size in its own coordinates: the rect a landing flight measures, as the
/// flight follows the site's leader layer, which applies any transform
/// above the site to the feedback. With [includeOwn], it includes [box]'s
/// own [PaintOffset].
Rect landingRect(RenderBox box, {bool includeOwn = false}) =>
    MatrixUtils.transformPoint(
      paintedTransformToGlobal(box, includeOwn: includeOwn),
      Offset.zero,
    ) &
    box.size;

/// The rect of [box] in global coordinates as it is laid out, through any
/// transform above it, without paint offsets.
Rect layoutGlobalRect(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

/// The transform from [box]'s coordinates to global ones as it was last
/// painted: `getTransformTo(null)` with the [PaintOffset] of every ancestor
/// applied in that ancestor's coordinates. With [includeOwn], also [box]'s
/// own.
Matrix4 paintedTransformToGlobal(RenderObject box, {bool includeOwn = false}) {
  final path = <RenderObject>[];
  for (RenderObject? node = box; node != null; node = node.parent) {
    path.add(node);
  }
  final transform = Matrix4.identity();
  // As getTransformTo(null), leave out the root's transform to physical
  // pixels.
  for (var i = path.length - 2; i > 0; i--) {
    final node = path[i];
    if (node is PaintOffset) {
      final offset = (node as PaintOffset).paintOffset;
      transform.translateByDouble(offset.dx, offset.dy, 0, 1);
    }
    node.applyPaintTransform(path[i - 1], transform);
  }
  if (includeOwn && box is PaintOffset) {
    final offset = (box as PaintOffset).paintOffset;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }
  return transform;
}

/// The sum of the [PaintOffset]s of [box]'s ancestors: how far from its
/// layout position it was last painted, ignoring any transform between
/// them. See [paintedGlobalRect] for a rect in global coordinates.
Offset paintOffsetAbove(RenderObject box) {
  var offset = Offset.zero;
  for (var node = box.parent; node != null; node = node.parent) {
    if (node is PaintOffset) offset += (node as PaintOffset).paintOffset;
  }
  return offset;
}

/// Where [context] can be seen: the intersection of its [Scrollable]s'
/// painted rects in global coordinates, or null when it has none.
Rect? visibleRectOf(BuildContext context) {
  Rect? visible;
  for (
    var scrollable = Scrollable.maybeOf(context);
    scrollable != null;
    scrollable = Scrollable.maybeOf(scrollable.context)
  ) {
    final box = scrollable.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) continue;
    final rect = paintedGlobalRect(box);
    visible = visible?.intersect(rect) ?? rect;
  }
  return visible;
}

/// Paints a [LeaderLayer] for [link] around its child while [link] is set,
/// so that a [CompositedTransformFollower] can follow where the child is
/// painted, frame by frame.
///
/// Unlike [CompositedTransformTarget], it can come and go without changing
/// the widget tree, so the child keeps its state, and it only composites
/// while it leads.
class LeaderWhile extends SingleChildRenderObjectWidget {
  /// Leads [link] around [child] while [link] isn't null.
  const LeaderWhile({required this.link, super.child, super.key});

  /// The link to lead, or null for none.
  final LayerLink? link;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderLeaderWhile(link);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLeaderWhile renderObject,
  ) {
    renderObject.link = link;
  }
}

/// The render object of [LeaderWhile].
class RenderLeaderWhile extends RenderProxyBox {
  /// Leads [link] while it isn't null.
  RenderLeaderWhile(this._link);

  /// The link to lead, or null for none.
  LayerLink? get link => _link;
  LayerLink? _link;
  set link(LayerLink? value) {
    if (value == _link) return;
    final composites = (value == null) != (_link == null);
    _link = value;
    if (composites) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _link != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    final link = _link;
    if (link == null) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    final leader = switch (layer) {
      final LeaderLayer leader =>
        leader
          ..link = link
          ..offset = offset,
      _ => LeaderLayer(link: link, offset: offset),
    };
    layer = leader;
    context.pushLayer(leader, super.paint, Offset.zero);
  }
}

/// A render object in the tree that can take over a landing flight from the
/// overlay, so the rest of it is clipped and stacked like the item itself.
///
/// `MotionLayoutItem` is one.
abstract interface class FlightReceiver {
  /// Whether it can take a flight now.
  bool get canReceiveFlight;

  /// Paints the child [offset] away from where it is painted now, moving at
  /// [velocity] in logical pixels per second, and springs it home from
  /// there.
  ///
  /// Both are relative to the child's current painted position, so a flight
  /// the receiver is already running carries on underneath.
  void receiveFlight({required Offset offset, required Offset velocity});

  /// The receiver's layout rect in global coordinates, without paint
  /// offsets, or null while it isn't laid out.
  ///
  /// A list paints an item only while this rect overlaps its viewport, so a
  /// flight handed to an item whose slot is out of view isn't seen.
  Rect? get layoutRect;
}

/// The nearest [FlightReceiver] above [box] that can take a flight now.
FlightReceiver? flightReceiverAbove(RenderObject box) {
  for (var node = box.parent; node != null; node = node.parent) {
    if (node is FlightReceiver) {
      final receiver = node as FlightReceiver;
      return receiver.canReceiveFlight ? receiver : null;
    }
  }
  return null;
}

/// Paints its child scaled and rotated around its center, and faded, by
/// the values [scale], [turns] and [opacity] return, repainting whenever
/// [listenable] notifies.
///
/// Only painting changes: layout and hit testing stay where the child is,
/// as with a paint offset. At rest (1, 0 and 1) it paints the child as is.
class PaintedVisuals extends SingleChildRenderObjectWidget {
  /// Paints [child] with the visuals that [scale], [turns] and [opacity]
  /// return.
  const PaintedVisuals({
    required this.listenable,
    required this.scale,
    required this.turns,
    required this.opacity,
    super.child,
    super.key,
  });

  /// Notifies when the visuals change.
  final Listenable? listenable;

  /// The scale around the child's center.
  final ValueGetter<double> scale;

  /// The clockwise rotation around the child's center, in full turns.
  final ValueGetter<double> turns;

  /// The opacity, clamped to 0 and 1.
  final ValueGetter<double> opacity;

  @override
  RenderPaintedVisuals createRenderObject(BuildContext context) =>
      RenderPaintedVisuals(this);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPaintedVisuals renderObject,
  ) {
    renderObject.widget = this;
  }
}

/// The render object of [PaintedVisuals].
class RenderPaintedVisuals extends RenderProxyBox {
  /// Paints with [widget]'s visuals.
  RenderPaintedVisuals(this._widget);

  /// The configuration.
  PaintedVisuals get widget => _widget;
  PaintedVisuals _widget;
  set widget(PaintedVisuals value) {
    if (identical(value, _widget)) return;
    final listens = attached && value.listenable != _widget.listenable;
    if (listens) _widget.listenable?.removeListener(markNeedsPaint);
    _widget = value;
    if (listens) _widget.listenable?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  final _transform = LayerHandle<TransformLayer>();
  final _opacity = LayerHandle<OpacityLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _widget.listenable?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _widget.listenable?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _transform.layer = null;
    _opacity.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final scale = _widget.scale();
    final angle = _widget.turns() * 2 * math.pi;
    final alpha = (_widget.opacity().clamp(0.0, 1.0) * 255).round();
    if (alpha == 0) {
      _transform.layer = null;
      _opacity.layer = null;
      return;
    }

    void paintTransformed(PaintingContext context, Offset offset) {
      if (scale == 1 && angle == 0) {
        _transform.layer = null;
        context.paintChild(child, offset);
        return;
      }
      final center = size.center(Offset.zero);
      final transform = Matrix4.identity()
        ..translateByDouble(center.dx, center.dy, 0, 1)
        ..rotateZ(angle)
        ..scaleByDouble(scale, scale, 1, 1)
        ..translateByDouble(-center.dx, -center.dy, 0, 1);
      _transform.layer = context.pushTransform(
        needsCompositing,
        offset,
        transform,
        (context, offset) => context.paintChild(child, offset),
        oldLayer: _transform.layer,
      );
    }

    if (alpha == 255) {
      _opacity.layer = null;
      paintTransformed(context, offset);
      return;
    }
    _opacity.layer = context.pushOpacity(
      offset,
      alpha,
      paintTransformed,
      oldLayer: _opacity.layer,
    );
  }
}
