import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// How far each card behind the front one peeks out of the collapsed pile.
const queuedStackPeek = 12.0;

/// How many cards peek out behind the front one.
const queuedStackMaxPeek = 2;

/// The gap between cards in the expanded stack, and between the folded
/// pile and the content above it.
const queuedStackGap = 8.0;

/// Lays out a queued-message pile, bottom-anchored, over an optional body.
///
/// The children are, in order: the body (the content the pile floats over,
/// or an empty box), the pile's region (it takes the pile's hover), the
/// gutter, then every card. A card sits where its [QueuedStackSlot] says:
/// collapsed, a card `slot` places from the front peeks [queuedStackPeek]
/// higher, up to [queuedStackMaxPeek]; expanded, each sits a card plus
/// [queuedStackGap] above the one in front. [expand] blends the two.
///
/// With a body, the layout fills its constraints and lays the body out
/// first-come under the pile, with [QueuedStackBodyConstraints] that carry
/// the folded pile's height. Without one, it's as tall as the cards
/// occupy, so it follows their springs.
class QueuedStackLayout extends MultiChildRenderObjectWidget {
  /// Creates the layout.
  const QueuedStackLayout({
    required this.expand,
    required this.gutterWidth,
    required this.count,
    required this.bump,
    required this.hasBody,
    required super.children,
    super.key,
  });

  /// 0 collapsed, 1 expanded.
  final double expand;

  /// The width of the gutter on each side of the cards.
  final double gutterWidth;

  /// How many messages are queued (cards that are leaving don't count).
  final int count;

  /// How far the pile is lifted by its recoil, in logical pixels (negative
  /// is up).
  final double bump;

  /// Whether the first child is a body to lay out under the pile.
  final bool hasBody;

  @override
  RenderQueuedStack createRenderObject(BuildContext context) =>
      RenderQueuedStack(
        expand: expand,
        gutterWidth: gutterWidth,
        count: count,
        bump: bump,
        hasBody: hasBody,
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
      ..count = count
      ..bump = bump
      ..hasBody = hasBody
      ..textDirection = Directionality.of(context);
  }
}

/// Tight constraints for the body under a pile, carrying the folded pile's
/// height ([pileExtent]), gap included. A `LayoutBuilder` in the body reads
/// it, the way `Scaffold.extendBody` hands its body the bottom bar's
/// height.
class QueuedStackBodyConstraints extends BoxConstraints {
  /// Tight constraints of [size] with [pileExtent].
  QueuedStackBodyConstraints.tight(super.size, {required this.pileExtent})
    : super.tight();

  /// The folded pile's height plus the gap above it; 0 with no messages.
  final double pileExtent;

  @override
  bool operator ==(Object other) =>
      other is QueuedStackBodyConstraints &&
      super == other &&
      other.pileExtent == pileExtent;

  @override
  int get hashCode => Object.hash(super.hashCode, pileExtent);
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
    required this._count,
    required this._bump,
    required this._hasBody,
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

  /// How many messages are queued.
  int get count => _count;
  int _count;
  set count(int value) {
    if (value == _count) return;
    _count = value;
    markNeedsLayout();
  }

  /// The recoil's lift.
  double get bump => _bump;
  double _bump;
  set bump(double value) {
    if (value == _bump) return;
    _bump = value;
    markNeedsLayout();
  }

  /// Whether the first child is a body.
  bool get hasBody => _hasBody;
  bool _hasBody;
  set hasBody(bool value) {
    if (value == _hasBody) return;
    _hasBody = value;
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

  static Offset _offsetOf(RenderBox child) =>
      (child.parentData! as BoxParentData).offset;

  @override
  void performLayout() {
    final body = firstChild;
    final region = body == null ? null : childAfter(body);
    final gutter = region == null ? null : childAfter(region);
    if (body == null || region == null || gutter == null) {
      size = constraints.smallest;
      return;
    }
    final width = constraints.maxWidth;
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

    final pitch = cardHeight + queuedStackGap;
    var pileHeight = cards.isEmpty ? 0.0 : cardHeight;
    for (final card in cards) {
      final data = card.parentData! as QueuedStackParentData;
      pileHeight = math.max(
        pileHeight,
        _rise(data.slot, pitch) + card.size.height,
      );
    }
    // The folded pile, from the real card height: what the body keeps clear.
    final pileExtent = _count == 0
        ? 0.0
        : cardHeight +
              math.min(_count - 1, queuedStackMaxPeek) * queuedStackPeek +
              queuedStackGap;

    if (_hasBody) {
      size = constraints.biggest;
      body.layout(
        QueuedStackBodyConstraints.tight(size, pileExtent: pileExtent),
      );
    } else {
      size = constraints.constrain(Size(width, pileHeight));
      body.layout(const BoxConstraints.tightFor(width: 0, height: 0));
    }
    (body.parentData! as BoxParentData).offset = Offset.zero;

    final bottom = size.height + _bump;
    region.layout(BoxConstraints.tightFor(width: width, height: pileHeight));
    (region.parentData! as BoxParentData).offset = Offset(
      0,
      bottom - pileHeight,
    );
    gutter.layout(
      BoxConstraints.tightFor(width: _gutterWidth, height: cardHeight),
      parentUsesSize: true,
    );
    (gutter.parentData! as BoxParentData).offset = Offset(
      _textDirection == TextDirection.ltr ? 0 : width - _gutterWidth,
      bottom - cardHeight,
    );
    for (final card in cards) {
      final data = card.parentData! as QueuedStackParentData;
      data.offset = Offset(
        _gutterWidth,
        bottom - _rise(data.slot, pitch) - card.size.height,
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
    final body = firstChild;
    if (body == null) return;
    final region = childAfter(body)!;
    final gutter = childAfter(region)!;
    for (final child in [body, region, gutter, ..._paintOrder]) {
      context.paintChild(child, _offsetOf(child) + offset);
    }
  }

  bool _hit(BoxHitTestResult result, RenderBox child, Offset position) =>
      result.addWithPaintOffset(
        offset: _offsetOf(child),
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final body = firstChild;
    if (body == null) return false;
    final region = childAfter(body)!;
    final gutter = childAfter(region)!;
    var pile = false;
    for (final child in [..._paintOrder.reversed, gutter]) {
      if (_hit(result, child, position)) {
        pile = true;
        break;
      }
    }
    // A pointer over a card is over the pile too, so the region hears it
    // and the pile stays fanned out while the pointer moves between cards.
    if (_hit(result, region, position)) pile = true;
    return pile || _hit(result, body, position);
  }
}
