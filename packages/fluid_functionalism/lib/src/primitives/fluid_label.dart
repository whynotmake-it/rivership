import 'dart:math' as math;

import 'package:fluid_functionalism/src/foundation/fluid_theme.dart';
import 'package:fluid_functionalism/src/foundation/fluid_typography.dart'
    show FluidTypographyThemeData;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Trims a text label's box to its cap height, like CSS
/// `text-box: trim-both cap alphabetic`.
///
/// The box runs from the cap top of the first line to the alphabetic
/// baseline of the last, so whatever centers the box (a [Row], [Center], a
/// fixed-height control) centers the visible capitals: optically centered
/// labels whatever the font's ascender/descender balance, line height or
/// text scale. Text above the cap height (accents) and below the baseline
/// (descenders) still paints; it just doesn't count for layout.
///
/// [child] is usually a [Text] that inherits the ambient [DefaultTextStyle];
/// FluidLabel reads that style's font size and line height (scaled by the
/// ambient [TextScaler]) and the theme's
/// [FluidTypographyThemeData.capHeight]. Multi-line text assumes uniform
/// line heights, as CSS does for the trimmed edges.
///
/// Hit testing, semantics and the paint transform (used by the IME to place
/// its candidate window) all follow the shifted child.
class FluidLabel extends StatelessWidget {
  /// Creates a cap-trimmed label.
  const FluidLabel({required this.child, super.key, this.capHeight});

  /// The label.
  final Widget child;

  /// The font's cap height as a fraction of the em. Defaults to the theme's
  /// [FluidTypographyThemeData.capHeight].
  final double? capHeight;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    final fontSize = scaler.scale(style.fontSize ?? 14);
    final cap =
        (capHeight ?? FluidTheme.of(context).typography.capHeight) * fontSize;
    final height = style.height;
    return _TextBoxTrim(
      capHeight: cap,
      lineHeight: height == null ? null : height * fontSize,
      child: child,
    );
  }
}

class _TextBoxTrim extends SingleChildRenderObjectWidget {
  const _TextBoxTrim({
    required this.capHeight,
    required this.lineHeight,
    super.child,
  });

  final double capHeight;
  final double? lineHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderTextBoxTrim(capHeight: capHeight, lineHeight: lineHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTextBoxTrim renderObject,
  ) {
    renderObject
      ..capHeight = capHeight
      ..lineHeight = lineHeight;
  }
}

/// The render object behind [FluidLabel]: lays out its child at full height,
/// then sizes itself to the cap band and shifts the child up.
class RenderTextBoxTrim extends RenderProxyBox {
  /// Creates the render object.
  RenderTextBoxTrim({required double capHeight, double? lineHeight})
    : _capHeight = capHeight,
      _lineHeight = lineHeight;

  /// The cap height in logical pixels.
  double get capHeight => _capHeight;
  double _capHeight;
  set capHeight(double value) {
    if (value == _capHeight) return;
    _capHeight = value;
    markNeedsLayout();
  }

  /// The height of one line in logical pixels, or null to assume a single
  /// line and trim to the child's own height.
  double? get lineHeight => _lineHeight;
  double? _lineHeight;
  set lineHeight(double? value) {
    if (value == _lineHeight) return;
    _lineHeight = value;
    markNeedsLayout();
  }

  /// How far the child is shifted up: the space above the first cap top.
  double _top = 0;

  /// How much is cut below the last baseline.
  double _bottom = 0;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
      ),
      parentUsesSize: true,
    );
    final reported = child.getDistanceToBaseline(
      TextBaseline.alphabetic,
      onlyReal: true,
    );
    // The text engine paints the first baseline snapped to a whole logical
    // pixel (it reports 44.55 and paints at 45), so trim against where the
    // glyphs really land.
    final baseline = reported?.roundToDouble() ?? child.size.height;
    _top = math.max(0, baseline - capHeight);
    // The last line ends as far below its baseline as the first does.
    final line = lineHeight ?? child.size.height;
    _bottom = math.max(0, math.min(line, child.size.height) - baseline);
    size = constraints.constrain(
      Size(
        child.size.width,
        math.max(0, child.size.height - _top - _bottom),
      ),
    );
  }

  Offset get _childOffset => Offset(0, -_top);

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) context.paintChild(child, offset + _childOffset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: _childOffset,
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(0, -_top, 0, 1);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final childBaseline = child?.getDistanceToActualBaseline(baseline);
    return childBaseline == null ? null : childBaseline - _top;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _trimmed(super.computeMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _trimmed(super.computeMaxIntrinsicHeight(width));

  double _trimmed(double height) {
    final line = lineHeight;
    if (line == null) return math.min(height, capHeight);
    return math.max(0, height - (line - capHeight));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final full = child.getDryLayout(
      BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
      ),
    );
    return constraints.constrain(Size(full.width, _trimmed(full.height)));
  }
}
