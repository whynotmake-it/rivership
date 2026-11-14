import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// How far each card behind the front one peeks out of the collapsed pile.
const queuedStackPeek = 12.0;

/// How many cards peek out behind the front one.
const queuedStackMaxPeek = 2;

/// The gap between cards in the expanded stack.
const queuedStackGap = 8.0;

/// Lays out the queued cards, bottom-anchored.
///
/// The first child is the gutter, at the start of the bottom row. Every
/// other child is a card, placed by its [QueuedStackSlot]: collapsed, a card
/// `slot` places from the front peeks [queuedStackPeek] higher, up to
/// [queuedStackMaxPeek]; expanded, each sits a card plus [queuedStackGap]
/// above the one in front. [expand] blends the two. The height is what the
/// cards occupy, so it follows their springs.
class QueuedStackLayout extends MultiChildRenderObjectWidget {
  /// Creates the layout.
  const QueuedStackLayout({
    required this.expand,
    required this.gutterWidth,
    required super.children,
    super.key,
  });

  /// 0 collapsed, 1 expanded.
  final double expand;

  /// The width of the gutter on each side of the cards.
  final double gutterWidth;

  @override
  RenderQueuedStack createRenderObject(BuildContext context) =>
      RenderQueuedStack(
        expand: expand,
        gutterWidth: gutterWidth,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderQueuedStack renderObject,
  ) {
    renderObject
      ..expand = expand
      ..gutterWidth = gutterWidth
      ..textDirection = Directionality.of(context);
  }
}

/// Where a card sits in a [QueuedStackLayout].
class QueuedStackSlot extends ParentDataWidget<QueuedStackParentData> {
  /// Places [child] at [slot].
  const QueuedStackSlot({
    required this.slot,
    required this.lifted,
    required super.child,
    super.key,
  });

  /// Places from the front: 0 is the card sent next. Fractional while a
  /// card moves or is dragged.
  final double slot;

  /// Whether the card paints above the others (it's being dragged).
  final bool lifted;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as QueuedStackParentData;
    if (data.slot != slot || data.lifted != lifted) {
      data
        ..slot = slot
        ..lifted = lifted;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => QueuedStackLayout;
}

/// A card's place in a [RenderQueuedStack].
class QueuedStackParentData extends ContainerBoxParentData<RenderBox> {
  /// Places from the front.
  double slot = 0;

  /// Whether the card paints above the others.
  bool lifted = false;
}

/// The render object of [QueuedStackLayout].
class RenderQueuedStack extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, QueuedStackParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, QueuedStackParentData> {
  /// Creates the render object.
  RenderQueuedStack({
    required this._expand,
    required this._gutterWidth,
    required this._textDirection,
  });

  /// 0 collapsed, 1 expanded.
  double get expand => _expand;
  double _expand;
  set expand(double value) {
    if (value == _expand) return;
    _expand = value;
    markNeedsLayout();
  }

  /// The width of the gutter on each side of the cards.
  double get gutterWidth => _gutterWidth;
  double _gutterWidth;
  set gutterWidth(double value) {
    if (value == _gutterWidth) return;
    _gutterWidth = value;
    markNeedsLayout();
  }

  /// Which side the gutter's content sits on.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  /// Cards back to front, then the lifted one: the paint order.
  List<RenderBox> _paintOrder = const [];

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! QueuedStackParentData) {
      child.parentData = QueuedStackParentData();
    }
  }

  /// The card's bottom offset above the stack's bottom edge.
  double _rise(double slot, double pitch) {
    final collapsed =
        math.min(slot, queuedStackMaxPeek.toDouble()) * queuedStackPeek;
    final expanded = slot * pitch;
    return collapsed + (expanded - collapsed) * _expand;
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final gutter = firstChild;
    if (gutter == null) {
      size = constraints.smallest;
      return;
    }
    final cardWidth = math.max(0, width - 2 * _gutterWidth).toDouble();
    final cards = <RenderBox>[];
    var cardHeight = 0.0;
    var child = childAfter(gutter);
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: cardWidth),
        parentUsesSize: true,
      );
      cardHeight = math.max(cardHeight, child.size.height);
      cards.add(child);
      child = childAfter(child);
    }
    gutter.layout(
      BoxConstraints.tightFor(width: _gutterWidth, height: cardHeight),
      parentUsesSize: true,
    );

    final pitch = cardHeight + queuedStackGap;
    var top = cards.isEmpty ? 0.0 : cardHeight;
    for (final card in cards) {
      final data = card.parentData! as QueuedStackParentData;
      top = math.max(top, _rise(data.slot, pitch) + card.size.height);
    }
    size = constraints.constrain(Size(width, top));

    final ltr = _textDirection == TextDirection.ltr;
    (gutter.parentData! as QueuedStackParentData).offset = Offset(
      ltr ? 0 : width - _gutterWidth,
      size.height - cardHeight,
    );
    for (final card in cards) {
      final data = card.parentData! as QueuedStackParentData;
      data.offset = Offset(
        _gutterWidth,
        size.height - _rise(data.slot, pitch) - card.size.height,
      );
    }
    _paintOrder = [...cards]
      ..sort((a, b) {
        final da = a.parentData! as QueuedStackParentData;
        final db = b.parentData! as QueuedStackParentData;
        if (da.lifted != db.lifted) return da.lifted ? 1 : -1;
        return db.slot.compareTo(da.slot);
      });
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final gutter = firstChild;
    if (gutter == null) return;
    context.paintChild(
      gutter,
      (gutter.parentData! as BoxParentData).offset + offset,
    );
    for (final card in _paintOrder) {
      context.paintChild(
        card,
        (card.parentData! as BoxParentData).offset + offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in [?firstChild, ..._paintOrder].reversed) {
      final data = child.parentData! as BoxParentData;
      final hit = result.addWithPaintOffset(
        offset: data.offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
