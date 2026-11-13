import 'dart:math' as math;

import 'package:coil/src/primitives/presence.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Which side of its anchor a popover landed on.
enum CoilPopoverSide {
  /// Below the anchor (the preferred side).
  bottom,

  /// Above the anchor, flipped for lack of room below.
  top,
}

/// An overlay anchored to a rect: a popover, a menu, a select list.
///
/// A [PopupRoute] for what routes give for free (a focus scope, the
/// dismissible barrier, Escape and back, `Navigator.pop` returning the
/// result, focus returning to the opener's scope). Its transition is a
/// [CoilSpringRoute]: the route's animation is the presence value, sprung in
/// on [enterMotion] and out on [exitMotion], shown with [CoilBlurFade] from
/// the anchored edge.
///
/// The side is chosen before layout from [estimatedHeight] (the caller's
/// arithmetic, e.g. rows × row height): below if it fits or if there is
/// more room below, else above. The content is then laid out within the
/// room on that side.
class CoilPopoverRoute<T> extends PopupRoute<T> with CoilSpringRoute<T> {
  /// Creates a popover anchored to [anchor] (in the navigator's coordinates).
  CoilPopoverRoute({
    required this.anchor,
    required this.builder,
    required this.estimatedHeight,
    required this.enterMotion,
    required this.exitMotion,
    this.minWidth = 0,
    this.maxHeight = double.infinity,
    this.sideOffset = 6,
    this.edgePadding = 8,
    this.capturedThemes,
    this.barrierLabel = 'Dismiss',
    super.settings,
  });

  /// The anchor's rect.
  final Rect anchor;

  /// The contents.
  final WidgetBuilder builder;

  /// The contents' expected height, used to pick a side.
  final double estimatedHeight;

  @override
  final Motion enterMotion;

  @override
  final Motion exitMotion;

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

  @override
  bool get barrierDismissible => true;

  @override
  final String? barrierLabel;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    final safe = media.padding + media.viewInsets;
    final spaceBelow =
        media.size.height -
        safe.bottom -
        edgePadding -
        anchor.bottom -
        sideOffset;
    final spaceAbove = anchor.top - sideOffset - edgePadding - safe.top;
    final wanted = math.min(estimatedHeight, maxHeight);
    final side = spaceBelow >= wanted || spaceBelow >= spaceAbove
        ? CoilPopoverSide.bottom
        : CoilPopoverSide.top;
    final room = side == CoilPopoverSide.bottom ? spaceBelow : spaceAbove;
    final bottom = side == CoilPopoverSide.bottom;
    Widget content = CoilBlurFade(
      presence: animation,
      alignment: bottom ? Alignment.topCenter : Alignment.bottomCenter,
      offset: Offset(0, bottom ? -4 : 4),
      child: Builder(builder: builder),
    );
    content = capturedThemes?.wrap(content) ?? content;
    return CustomSingleChildLayout(
      delegate: _CoilPopoverLayout(
        anchor: anchor,
        side: side,
        sideOffset: sideOffset,
        edgePadding: edgePadding,
        minWidth: minWidth,
        maxHeight: math.max(0, math.min(maxHeight, room)).toDouble(),
        textDirection: Directionality.of(context),
      ),
      child: content,
    );
  }
}

class _CoilPopoverLayout extends SingleChildLayoutDelegate {
  _CoilPopoverLayout({
    required this.anchor,
    required this.side,
    required this.sideOffset,
    required this.edgePadding,
    required this.minWidth,
    required this.maxHeight,
    required this.textDirection,
  });

  final Rect anchor;
  final TextDirection textDirection;
  final CoilPopoverSide side;
  final double sideOffset;
  final double edgePadding;
  final double minWidth;
  final double maxHeight;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = math.max(0, constraints.maxWidth - edgePadding * 2);
    return BoxConstraints(
      minWidth: math.min(minWidth, maxWidth).toDouble(),
      maxWidth: maxWidth.toDouble(),
      maxHeight: maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Start-aligned with the anchor, shifted back inside the window.
    final start = textDirection == TextDirection.ltr
        ? anchor.left
        : anchor.right - childSize.width;
    final x = start
        .clamp(
          edgePadding,
          math.max(edgePadding, size.width - edgePadding - childSize.width),
        )
        .toDouble();
    final y = side == CoilPopoverSide.bottom
        ? anchor.bottom + sideOffset
        : anchor.top - sideOffset - childSize.height;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_CoilPopoverLayout old) =>
      anchor != old.anchor ||
      side != old.side ||
      minWidth != old.minWidth ||
      maxHeight != old.maxHeight ||
      textDirection != old.textDirection ||
      sideOffset != old.sideOffset ||
      edgePadding != old.edgePadding;
}
