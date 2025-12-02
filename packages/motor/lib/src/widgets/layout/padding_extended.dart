// ignore_for_file: lines_longer_than_80_chars

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

/// A widget that works exactly like [Padding] but allows negative values for
/// [padding].
///
/// In that case, this widget will effectively expand the child's size.
/// However, the hitbox will remain the same size as the [PaddingExtended]
/// widget due to how Flutter's hit testing works.
class PaddingExtended extends SingleChildRenderObjectWidget {
  /// Creates a widget that insets its child by the given padding.
  ///
  /// The [padding] argument accepts negative values.
  const PaddingExtended({
    required this.padding,
    super.child,
    super.key,
  });

  /// The amount of space by which to inset the child.
  ///
  /// If negative values are provided, the child will be outset outside
  /// the bounds of this widget.
  final EdgeInsetsGeometry padding;

  @override
  RenderPaddingExtended createRenderObject(BuildContext context) {
    return RenderPaddingExtended(
      padding: padding,
      textDirection: Directionality.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPaddingExtended renderObject,
  ) {
    renderObject
      ..padding = padding
      ..textDirection = Directionality.maybeOf(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding));
  }
}

@internal
class RenderPaddingExtended extends RenderShiftedBox {
  /// Creates a render object that insets its child.
  ///
  /// The [padding] argument allows negative insets.
  RenderPaddingExtended({
    required EdgeInsetsGeometry padding,
    TextDirection? textDirection,
    RenderBox? child,
  })  : _textDirection = textDirection,
        _padding = padding,
        super(child);

  EdgeInsets? _resolvedPaddingCache;
  EdgeInsets get _resolvedPadding {
    final returnValue =
        _resolvedPaddingCache ??= padding.resolve(textDirection);
    return returnValue;
  }

  void _markNeedResolution() {
    _resolvedPaddingCache = null;
    markNeedsLayout();
  }

  /// The amount to pad the child in each dimension.
  EdgeInsetsGeometry get padding => _padding;
  EdgeInsetsGeometry _padding;
  set padding(EdgeInsetsGeometry value) {
    // Assertion removed to allow negative values
    if (_padding == value) {
      return;
    }
    _padding = value;
    _markNeedResolution();
  }

  /// The text direction with which to resolve [padding].
  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) {
      return;
    }
    _textDirection = value;
    _markNeedResolution();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final padding = _resolvedPadding;
    double result;
    if (child != null) {
      // Logic maintained: subtract vertical padding from height availability
      result = child!
              .getMinIntrinsicWidth(math.max(0.0, height - padding.vertical)) +
          padding.horizontal;
    } else {
      result = padding.horizontal;
    }
    // Safety check: Intrinsic width cannot be negative.
    return math.max(0.0, result);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final padding = _resolvedPadding;
    double result;
    if (child != null) {
      result = child!
              .getMaxIntrinsicWidth(math.max(0.0, height - padding.vertical)) +
          padding.horizontal;
    } else {
      result = padding.horizontal;
    }
    return math.max(0.0, result);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final padding = _resolvedPadding;
    double result;
    if (child != null) {
      result = child!.getMinIntrinsicHeight(
            math.max(0.0, width - padding.horizontal),
          ) +
          padding.vertical;
    } else {
      result = padding.vertical;
    }
    return math.max(0.0, result);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final padding = _resolvedPadding;
    double result;
    if (child != null) {
      result = child!.getMaxIntrinsicHeight(
            math.max(0.0, width - padding.horizontal),
          ) +
          padding.vertical;
    } else {
      result = padding.vertical;
    }
    return math.max(0.0, result);
  }

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final padding = _resolvedPadding;
    if (child == null) {
      return constraints.constrain(
        Size(
          math.max(0.0, padding.horizontal),
          math.max(0.0, padding.vertical),
        ),
      );
    }
    // deflate works correctly with negative values (it inflates the constraints)
    final innerConstraints = constraints.deflate(padding);
    final childSize = child!.getDryLayout(innerConstraints);

    // We must ensure the calculated size is not negative before constraining it,
    // otherwise the Size constructor will throw.
    return constraints.constrain(
      Size(
        math.max(0.0, padding.horizontal + childSize.width),
        math.max(0.0, padding.vertical + childSize.height),
      ),
    );
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) {
      return null;
    }
    final padding = _resolvedPadding;
    final innerConstraints = constraints.deflate(padding);
    final result =
        BaselineOffset(child.getDryBaseline(innerConstraints, baseline)) +
            padding.top;
    return result.offset;
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    final padding = _resolvedPadding;
    if (child == null) {
      size = constraints.constrain(
        Size(
          math.max(0.0, padding.horizontal),
          math.max(0.0, padding.vertical),
        ),
      );
      return;
    }

    // When padding is negative, deflate implicitly adds space to constraints
    final innerConstraints = constraints.deflate(padding);
    child!.layout(innerConstraints, parentUsesSize: true);

    (child!.parentData! as BoxParentData)
        // Offsetting by negative padding shifts the child up/left, outside bounds
        .offset = Offset(padding.left, padding.top);

    // Ensure total size doesn't crash if padding is extremely negative
    size = constraints.constrain(
      Size(
        math.max(0.0, padding.horizontal + child!.size.width),
        math.max(0.0, padding.vertical + child!.size.height),
      ),
    );
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    super.debugPaintSize(context, offset);
    // ignore: prefer_asserts_with_message
    assert(
      () {
        final outerRect = offset & size;
        debugPaintPadding(
          context.canvas,
          outerRect,
          child != null ? _resolvedPaddingCache!.deflateRect(outerRect) : null,
        );
        return true;
      }(),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding))
      ..add(
        EnumProperty<TextDirection>(
          'textDirection',
          textDirection,
          defaultValue: null,
        ),
      );
  }
}
