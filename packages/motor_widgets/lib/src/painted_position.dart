import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A render object that paints its child away from where layout put it,
/// without telling hit testing, so `localToGlobal` doesn't include the
/// offset.
///
/// `MotionReorder` is one: while it flies, it paints the item at an offset
/// but hit-tests it at its layout position.
abstract interface class PaintOffset {
  /// How far from its layout position the child was last painted, in the
  /// parent's coordinates.
  Offset get paintOffset;
}

/// The rect of [box] in global coordinates as it was last painted: its
/// layout position plus the [PaintOffset] of every ancestor.
Rect paintedGlobalRect(RenderBox box) {
  var topLeft = box.localToGlobal(Offset.zero);
  for (var node = box.parent; node != null; node = node.parent) {
    if (node is PaintOffset) topLeft += (node as PaintOffset).paintOffset;
  }
  return topLeft & box.size;
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
