import 'dart:ui' as ui;

import 'package:coil/src/foundation/typography.dart';
import 'package:flutter/widgets.dart';

/// The small glyphs coil draws itself (DESIGN.md §11).
enum CoilGlyph {
  /// A tick: checked, copied.
  check,

  /// A dash: indeterminate.
  dash,

  /// An ×: failed.
  cross,

  /// A circled exclamation mark: a field error.
  alert,

  /// A chevron pointing to the end: right, or left in RTL.
  chevronEnd,

  /// A chevron pointing down.
  chevronDown,

  /// A chevron pointing up.
  chevronUp,
}

/// Draws a [CoilGlyph] on the 24-unit grid with a round stroke.
///
/// It sizes, colors and weighs itself like an `Icon`, from the ambient
/// [IconTheme] and scaled with text: the stroke is 1.5 at
/// [CoilIconWeight.rest] and 2 at [CoilIconWeight.emphasis]. Indicators
/// (a checkbox tick, a select check, a field alert) draw at emphasis.
/// [progress] draws the strokes in from 0 (nothing) to 1
/// (complete), for a glyph that animates in.
class CoilDrawnGlyph extends StatelessWidget {
  /// Creates a drawn glyph.
  const CoilDrawnGlyph(this.glyph, {super.key, this.progress = 1, this.color});

  /// Which glyph.
  final CoilGlyph glyph;

  /// How much of the strokes is drawn, 0 to 1.
  final double progress;

  /// The stroke color; the ambient [IconTheme]'s when null.
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(CoilIconSize.of(context)),
      painter: _GlyphPainter(
        glyph,
        progress.clamp(0, 1),
        color ?? IconTheme.of(context).color ?? const Color(0xFF000000),
        // Like a stroke icon: 1.5 at rest, 2 at emphasis. IconTheme.of
        // always supplies a weight (400 when nothing sets one).
        stroke: 1.5 * IconTheme.of(context).weight! / CoilIconWeight.rest,
        rtl: Directionality.maybeOf(context) == TextDirection.rtl,
      ),
    ),
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(
    this.glyph,
    this.progress,
    this.color, {
    required this.stroke,
    required this.rtl,
  });

  final CoilGlyph glyph;
  final double progress;
  final Color color;
  final double stroke;
  final bool rtl;

  ui.Path _path() => switch (glyph) {
    CoilGlyph.check =>
      ui.Path()
        ..moveTo(6, 12)
        ..lineTo(10, 16)
        ..lineTo(18, 8),
    CoilGlyph.dash =>
      ui.Path()
        ..moveTo(7, 12)
        ..lineTo(17, 12),
    CoilGlyph.cross =>
      ui.Path()
        ..moveTo(7, 7)
        ..lineTo(17, 17)
        ..moveTo(17, 7)
        ..lineTo(7, 17),
    CoilGlyph.alert =>
      ui.Path()
        ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 10))
        ..moveTo(12, 8)
        ..lineTo(12, 12)
        ..moveTo(12, 16)
        ..lineTo(12.01, 16),
    CoilGlyph.chevronEnd =>
      rtl
          ? (ui.Path()
              ..moveTo(15, 6)
              ..lineTo(9, 12)
              ..lineTo(15, 18))
          : (ui.Path()
              ..moveTo(9, 6)
              ..lineTo(15, 12)
              ..lineTo(9, 18)),
    CoilGlyph.chevronDown =>
      ui.Path()
        ..moveTo(6, 9)
        ..lineTo(12, 15)
        ..lineTo(18, 9),
    CoilGlyph.chevronUp =>
      ui.Path()
        ..moveTo(6, 15)
        ..lineTo(12, 9)
        ..lineTo(18, 15),
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    var path = _path();
    if (progress < 1) {
      final drawn = ui.Path();
      for (final metric in path.computeMetrics()) {
        drawn.addPath(metric.extractPath(0, metric.length * progress), .zero);
      }
      path = drawn;
    }
    canvas
      ..save()
      ..scale(size.width / 24)
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph ||
      old.progress != progress ||
      old.color != color ||
      old.stroke != stroke ||
      old.rtl != rtl;
}
