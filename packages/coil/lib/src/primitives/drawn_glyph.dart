/// @docImport 'package:coil/src/components/chat_message/chat_message_action.dart';
library;

import 'dart:ui' as ui;

import 'package:coil/src/foundation/icons.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/foundation/typography.dart';
import 'package:coil/src/primitives/icon_presence.dart';
import 'package:flutter/widgets.dart';

/// The icon for [role]: the theme's ([CoilThemeData.icons]) when it sets
/// one, else Coil's drawn glyph for it.
///
/// Components show their icons through it, after their own slot:
/// `widget.dismissIcon ?? const CoilIcon(.close)`. Like a slot, it is
/// styled by the ambient [IconTheme].
///
/// Like Flutter's [Icon], it is hidden from screen readers unless it has a
/// [semanticLabel]. Give it one when the icon is all that names a control,
/// such as a [CoilChatMessageAction]'s icon-only button.
class CoilIcon extends StatelessWidget {
  /// Creates the icon for [role].
  const CoilIcon(this.role, {super.key, this.semanticLabel});

  /// Which icon.
  final CoilIconRole role;

  /// What screen readers announce for the icon, as with [Icon].
  ///
  /// It merges into the control around it, so an icon-only button is named
  /// by it.
  ///
  /// Null leaves the icon out of the semantics tree: a decorative icon, or
  /// one beside a label that already names its control.
  final String? semanticLabel;

  /// The glyph Coil draws for [role] when the theme sets no icon.
  static CoilGlyph glyphFor(CoilIconRole role) => switch (role) {
    CoilIconRole.check => CoilGlyph.check,
    CoilIconRole.dash => CoilGlyph.dash,
    CoilIconRole.copy => CoilGlyph.copy,
    CoilIconRole.failed || CoilIconRole.close => CoilGlyph.cross,
    CoilIconRole.alert => CoilGlyph.alert,
    CoilIconRole.chevronStart => CoilGlyph.chevronStart,
    CoilIconRole.chevronEnd => CoilGlyph.chevronEnd,
    CoilIconRole.chevronDown => CoilGlyph.chevronDown,
    CoilIconRole.chevronUp => CoilGlyph.chevronUp,
    CoilIconRole.send => CoilGlyph.arrowUp,
    CoilIconRole.stop => CoilGlyph.stop,
  };

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: ExcludeSemantics(
      child:
          CoilTheme.of(context).icons[role] ??
          CoilDrawnGlyph.presence(glyphFor(role)),
    ),
  );
}

/// The small glyphs Coil draws itself (DESIGN.md §11), by shape.
///
/// Components show them by [CoilIconRole] through [CoilIcon], so an app's
/// icon set replaces them.
enum CoilGlyph {
  /// A tick: checked, copied.
  check,

  /// Two overlapping sheets: copy.
  copy,

  /// A dash: indeterminate.
  dash,

  /// An ×: failed.
  cross,

  /// A circled exclamation mark: a field error.
  alert,

  /// A chevron pointing to the end: right, or left in RTL.
  chevronEnd,

  /// A chevron pointing to the start: left, or right in RTL.
  chevronStart,

  /// A chevron pointing down.
  chevronDown,

  /// A chevron pointing up.
  chevronUp,

  /// An arrow pointing up: send.
  arrowUp,

  /// A rounded square: stop.
  stop,
}

/// Draws a [CoilGlyph] on the 24-unit grid with a round stroke.
///
/// It sizes, colors and weighs itself like an [Icon], from the ambient
/// [IconTheme] and scaled with text: the stroke is 1.5 at
/// [CoilIconWeight.rest] and 2 at [CoilIconWeight.emphasis]. Indicators
/// (a checkbox tick, a select check, a field alert) draw at emphasis.
/// [progress] draws the strokes in from 0 (nothing) to 1
/// (complete), for a glyph that animates in. [CoilDrawnGlyph.presence]
/// draws itself in and out with its [CoilIconPresence] instead.
class CoilDrawnGlyph extends StatelessWidget {
  /// Creates a drawn glyph, [progress] of the way in.
  const CoilDrawnGlyph(this.glyph, {super.key, this.progress = 1, this.color})
    : _followsPresence = false;

  /// A glyph that draws itself in and out with its [CoilIconPresence] when
  /// a component animates it (reading it, so Coil applies no fallback), and
  /// is complete outside one.
  ///
  /// Coil's role icons ([CoilIcon]) are these.
  const CoilDrawnGlyph.presence(this.glyph, {super.key, this.color})
    : progress = 1,
      _followsPresence = true;

  /// Which glyph.
  final CoilGlyph glyph;

  /// How much of the strokes is drawn, 0 to 1.
  ///
  /// A [CoilDrawnGlyph.presence] follows its presence instead.
  final double progress;

  final bool _followsPresence;

  /// The stroke color; the ambient [IconTheme]'s when null.
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(CoilIconSize.of(context)),
      painter: _GlyphPainter(
        (_followsPresence ? CoilIconPresence.maybeOf(context) : null) ??
            progress.clamp(0.0, 1.0),
        color ?? IconTheme.of(context).color ?? const Color(0xFF000000),
        glyph: glyph,
        // Like a stroke icon: 1.5 at rest, 2 at emphasis. IconTheme.of
        // always supplies a weight (400 when nothing sets one).
        stroke: 1.5 * IconTheme.of(context).weight! / CoilIconWeight.rest,
        rtl: Directionality.maybeOf(context) == TextDirection.rtl,
      ),
    ),
  );
}

class _GlyphPainter extends CustomPainter {
  /// [drawn] is a fixed progress (a `double`) or an icon presence (an
  /// `Animation<double>`), which repaints without a rebuild.
  _GlyphPainter(
    this.drawn,
    this.color, {
    required this.glyph,
    required this.stroke,
    required this.rtl,
  }) : super(repaint: drawn is Animation<double> ? drawn : null);

  final CoilGlyph glyph;
  final Object drawn;
  final Color color;
  final double stroke;
  final bool rtl;

  ui.Path _path() => switch (glyph) {
    CoilGlyph.check =>
      ui.Path()
        ..moveTo(6, 12)
        ..lineTo(10, 16)
        ..lineTo(18, 8),
    CoilGlyph.copy =>
      ui.Path()
        ..addRSuperellipse(
          RSuperellipse.fromRectAndRadius(
            const Rect.fromLTWH(8, 8, 14, 14),
            const Radius.circular(2),
          ),
        )
        ..moveTo(4, 16)
        ..arcToPoint(const Offset(2, 14), radius: const Radius.circular(2))
        ..lineTo(2, 4)
        ..arcToPoint(const Offset(4, 2), radius: const Radius.circular(2))
        ..lineTo(14, 2)
        ..arcToPoint(const Offset(16, 4), radius: const Radius.circular(2)),
    CoilGlyph.dash =>
      ui.Path()
        ..moveTo(7, 12)
        ..lineTo(17, 12),
    CoilGlyph.arrowUp =>
      ui.Path()
        ..moveTo(12, 19)
        ..lineTo(12, 5)
        ..moveTo(6, 11)
        ..lineTo(12, 5)
        ..lineTo(18, 11),
    CoilGlyph.stop =>
      ui.Path()..addRSuperellipse(
        RSuperellipse.fromRectAndRadius(
          const Rect.fromLTRB(7, 7, 17, 17),
          const Radius.circular(2),
        ),
      ),
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
    CoilGlyph.chevronStart =>
      !rtl
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
    final progress = switch (drawn) {
      final Animation<double> presence => presence.value,
      final double value => value,
      _ => 1.0,
    };
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
      old.drawn != drawn ||
      old.color != color ||
      old.stroke != stroke ||
      old.rtl != rtl;
}
