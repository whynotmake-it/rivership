import 'dart:ui' as ui;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A checkbox (`registry/radix/checkbox.tsx`).
///
/// A 1.5 px outlined square with no fill. Checking draws a check (or, when
/// [value] is null, a dash) in the foreground color that slightly overhangs
/// the box, drawing itself in on the theme's `fade` spring and retracting on
/// `fadeExit`.
///
/// Like Flutter's `Checkbox`: [value] is a `bool?` where null means
/// indeterminate, which needs [tristate]. Only a tristate checkbox cycles
/// through null when tapped (false → true → null → false); otherwise a tap
/// reports `!value`.
class CoilCheckbox extends StatefulWidget {
  /// Creates a checkbox.
  const CoilCheckbox({
    required this.value,
    required this.onChanged,
    super.key,
    this.tristate = false,
    this.invalid = false,
    this.size,
    this.focusNode,
    this.autofocus = false,
    this.statesController,
    this.motion,
    this.semanticLabel,
    this.glyphBuilder,
  }) : assert(tristate || value != null, 'Only a tristate checkbox is null');

  /// Whether the box is checked; null (only with [tristate]) shows a dash:
  /// some, not all, of what this box stands for is on.
  final bool? value;

  /// Called with the next value. Null disables the checkbox.
  final ValueChanged<bool?>? onChanged;

  /// Whether a tap cycles through null (false → true → null → false), and
  /// whether [value] may be null.
  final bool tristate;

  /// Marks the box as invalid (a red-tinted border while unchecked).
  final bool invalid;

  /// Pins the box to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// The focus node.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Observes, and can force, hover/focus/press states.
  final WidgetStatesController? statesController;

  /// Overrides the theme's motion tokens ([CoilThemeData.motion]) for this
  /// instance.
  final CoilMotion? motion;

  /// A label for assistive technology.
  final String? semanticLabel;

  /// Replaces the built-in tick and dash. Gets the glyph, its draw-in
  /// progress (animated on the theme's `fade` / `fadeExit`), color and
  /// size.
  final CoilCheckboxGlyphBuilder? glyphBuilder;

  @override
  State<CoilCheckbox> createState() => _CoilCheckboxState();
}

/// The glyph a [CoilCheckbox] shows.
enum CoilCheckboxGlyph {
  /// Checked.
  check,

  /// Indeterminate.
  dash,
}

/// Draws a checkbox glyph [progress] of the way in (0 hidden, 1 complete),
/// at [size] in [color]. Replaces the built-in drawn tick.
typedef CoilCheckboxGlyphBuilder =
    Widget Function(
      BuildContext context,
      CoilCheckboxGlyph glyph,
      double progress,
      Color color,
      double size,
    );

enum _Glyph { none, check, dash }

class _CoilCheckboxState extends State<CoilCheckbox> {
  /// The motion tokens, read where each animation starts so runtime
  /// theme changes apply to the next one.
  CoilMotion get _motion =>
      CoilTheme.motionOf(context, override: widget.motion);

  _Glyph get _glyph => switch (widget.value) {
    null => _Glyph.dash,
    true => _Glyph.check,
    false => _Glyph.none,
  };

  bool? get _next => switch (widget.value) {
    false => true,
    true => widget.tristate ? null : false,
    null => false,
  };

  /// The glyph being drawn, kept while it retracts.
  late _Glyph _shown = _glyph;

  /// Bumped when the glyph changes shape, so a new one draws from 0.
  int _generation = 0;

  @override
  void didUpdateWidget(CoilCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final glyph = _glyph;
    if (glyph != _Glyph.none && glyph != _shown) {
      _shown = glyph;
      _generation++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    final enabled = widget.onChanged != null;
    final on = _glyph != _Glyph.none;
    // The box and its glyph grow with text, like icons; gaps don't.
    final scaler = MediaQuery.textScalerOf(context);
    final boxSize = scaler.scale(sizes.checkboxSize);
    final glyphSize = scaler.scale(sizes.checkboxGlyphSize);
    final radius = BorderRadius.circular(
      theme.shape == CoilShape.sharp
          ? 0
          : sizes.checkboxRadius * boxSize / sizes.checkboxSize,
    );

    return Semantics(
      container: true,
      checked: widget.value ?? false,
      mixed: widget.value == null,
      enabled: enabled,
      label: widget.semanticLabel,
      child: CoilInteraction(
        onPressed: enabled ? () => widget.onChanged!(_next) : null,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        statesController: widget.statesController,
        minHitTarget: sizes.minHitTarget,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          final hoverBorder = colors.foreground.withValues(alpha: 0.4);
          final Color border;
          if (on) {
            border = hovered ? hoverBorder : colors.border.withValues(alpha: 0);
          } else if (hovered) {
            border = hoverBorder;
          } else if (widget.invalid) {
            border = colors.destructive.withValues(alpha: 0.5);
          } else {
            border = colors.border;
          }
          return Opacity(
            opacity: enabled ? 1 : 0.5,
            child: CoilFocusRing(
              visible: states.contains(WidgetState.focused),
              borderRadius: radius,
              child: MotionBuilder<Color>(
                value: border,
                motion: _motion.fade,
                converter: MotionConverter.colorRgb,
                builder: (context, borderColor, child) => Container(
                  width: boxSize,
                  height: boxSize,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: child,
                ),
                child: OverflowBox(
                  maxWidth: glyphSize,
                  maxHeight: glyphSize,
                  child: SingleMotionBuilder(
                    key: ValueKey(_generation),
                    value: on ? 1 : 0,
                    // A new glyph shape draws itself in from nothing.
                    from: _generation == 0 ? null : 0,
                    motion: on ? _motion.fade : _motion.fadeExit,
                    builder: (context, progress, _) {
                      final builder = widget.glyphBuilder;
                      if (builder != null && _shown != _Glyph.none) {
                        return builder(
                          context,
                          _shown == _Glyph.dash
                              ? CoilCheckboxGlyph.dash
                              : CoilCheckboxGlyph.check,
                          progress.clamp(0, 1),
                          colors.foreground,
                          glyphSize,
                        );
                      }
                      return CustomPaint(
                        size: Size.square(glyphSize),
                        painter: _GlyphPainter(
                          glyph: _shown,
                          progress: progress,
                          color: colors.foreground,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({
    required this.glyph,
    required this.progress,
    required this.color,
  });

  final _Glyph glyph;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (glyph == _Glyph.none || progress <= 0) return;
    // Paths from the web, on a 24-unit grid.
    final path = ui.Path();
    if (glyph == _Glyph.dash) {
      path
        ..moveTo(7, 12)
        ..lineTo(17, 12);
    } else {
      path
        ..moveTo(6, 12)
        ..lineTo(10, 16)
        ..lineTo(18, 8);
    }
    final scale = size.width / 24;
    final drawn = ui.Path();
    for (final metric in path.computeMetrics()) {
      drawn.addPath(
        metric.extractPath(0, metric.length * progress.clamp(0, 1)),
        Offset.zero,
      );
    }
    canvas
      ..save()
      ..scale(scale)
      ..drawPath(
        drawn,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.progress != progress || old.color != color;
}
