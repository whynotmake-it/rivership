import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Motion tokens, mirroring `registry/default/lib/springs.ts`.
///
/// Each tier enters on a spring and exits on a plain tween one tier quicker,
/// so a dismissal reads as crisp and final instead of replaying the entrance.
// ignore: use_enums, a namespace of constants, not a set of cases.
abstract final class FluidMotion {
  /// Hover, focus rings, fades, tooltips, selection indicators. 0.08s, no
  /// bounce.
  static const fast = CupertinoMotion(
    duration: Duration(milliseconds: 80),
  );

  /// The exit of [fast]: a 0.06s tween.
  static const fastExit = CurvedMotion(
    Duration(milliseconds: 60),
    Curves.easeOut,
  );

  /// Short travel and panels or sheets that must land exactly: dropdown and
  /// tab indicators, the switch thumb, the mobile drawer. 0.16s, no bounce.
  static const moderate = CupertinoMotion(
    duration: Duration(milliseconds: 160),
  );

  /// The exit of [moderate]: a 0.12s tween.
  static const moderateExit = CurvedMotion(
    Duration(milliseconds: 120),
    Curves.easeOut,
  );

  /// Large surfaces: dialogs, side panels, stepped flows. 0.24s, bounce 0.12.
  static const slow = CupertinoMotion(
    duration: Duration(milliseconds: 240),
    bounce: 0.12,
  );

  /// The exit of [slow]: a 0.16s tween.
  static const slowExit = CurvedMotion(
    Duration(milliseconds: 160),
    Curves.easeOut,
  );

  /// How long a pick holds a select open so the check can draw and the
  /// selected fill can spring to the picked row (`selectionAckMs`).
  static const selectionAck = Duration(milliseconds: 300);
}

/// Colors from `app/globals.css`, resolved for one brightness.
@immutable
class FluidColors {
  /// Creates a color set. [surfaces] holds `--surface-1` to `--surface-8`.
  const FluidColors({
    required this.brightness,
    required List<Color> surfaces,
    required this.foreground,
    required this.mutedForeground,
    required this.hover,
    required this.active,
    required this.tint,
    required this.focusRing,
    required this.destructive,
  }) : _surfaces = surfaces;

  /// `light-dark(…)` first values.
  static const light = FluidColors(
    brightness: Brightness.light,
    surfaces: [
      Color(0xFFFAFAFA),
      Color(0xFFFCFCFC),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
    ],
    foreground: Color(0xFF171717),
    mutedForeground: Color(0xFF737373),
    hover: Color(0x0A000000), // rgb(0 0 0 / 0.04)
    active: Color(0x12000000), // rgb(0 0 0 / 0.07)
    tint: Color(0x14000000), // rgb(0 0 0 / 0.08)
    focusRing: Color(0xFF6B97FF),
    destructive: Color(0xFFEF4444),
  );

  /// `light-dark(…)` second values.
  static const dark = FluidColors(
    brightness: Brightness.dark,
    surfaces: [
      Color(0xFF171717),
      Color(0xFF1E1E1E),
      Color(0xFF252525),
      Color(0xFF2C2C2C),
      Color(0xFF333333),
      Color(0xFF3A3A3A),
      Color(0xFF414141),
      Color(0xFF484848),
    ],
    foreground: Color(0xFFF5F5F5),
    mutedForeground: Color(0xFFA3A3A3),
    hover: Color(0x0FFFFFFF), // rgb(255 255 255 / 0.06)
    active: Color(0x1AFFFFFF), // rgb(255 255 255 / 0.1)
    tint: Color(0x40FFFFFF), // rgb(255 255 255 / 0.25)
    focusRing: Color(0xFF6B97FF),
    destructive: Color(0xFFFCA5A5),
  );

  /// The brightness these colors are for.
  final Brightness brightness;

  final List<Color> _surfaces;

  /// Text and icons.
  final Color foreground;

  /// Secondary text, unhighlighted menu rows, placeholders.
  final Color mutedForeground;

  /// The hover fill (`--hover`).
  final Color hover;

  /// The pressed and selected fill (`--active`).
  final Color active;

  /// See-through fill of secondary buttons (`--tint`).
  final Color tint;

  /// Every focus ring (`--focus-ring`, the accent).
  final Color focusRing;

  /// Errors.
  final Color destructive;

  /// `--border`: the foreground at 12%.
  Color get border => foreground.withValues(alpha: 0.12);

  /// The page background, `--surface-1`.
  Color get background => surface(1);

  /// The surface at [level] (1–8, clamped).
  Color surface(int level) => _surfaces[level.clamp(1, 8) - 1];

  /// `--shadow-N`, as box shadows. The dark recipe's inset highlight and ring
  /// are not expressible as [BoxShadow]s; [insetRing] returns them as a
  /// border to paint inside the box.
  List<BoxShadow> shadow(int level) {
    final n = level.clamp(1, 8);
    if (brightness == Brightness.light) {
      const c = Color(0x0F000000); // --shadow-color, rgb(0 0 0 / 0.06)
      return [
        const BoxShadow(color: c, spreadRadius: 1),
        for (var i = 1; i < n; i++)
          BoxShadow(
            color: c,
            offset: Offset(0, _drop(i)),
            blurRadius: _drop(i),
            spreadRadius: -_drop(i) / 2,
          ),
      ];
    }
    const drop = Color(0x2E000000); // --dm-drop, rgba(0,0,0,0.18)
    return [
      if (n >= 3)
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.12 + 0.02 * (n - 3)),
          spreadRadius: 1,
        ),
      for (var i = 1; i < n; i++)
        BoxShadow(
          color: drop,
          offset: Offset(0, _drop(i)),
          blurRadius: _drop(i),
          spreadRadius: -_drop(i) / 2,
        ),
    ];
  }

  /// The inner hairline of `--shadow-N`: light draws it outside (in
  /// [shadow]), dark draws an inset white ring.
  Border? insetRing(int level) {
    if (brightness == Brightness.light) return null;
    final n = level.clamp(1, 8);
    final alpha = n <= 3 ? 0.02 : (n <= 5 ? 0.04 : 0.06);
    return Border.all(color: Color.fromRGBO(255, 255, 255, alpha));
  }

  static double _drop(int i) =>
      const [1.0, 3.0, 6.0, 12.0, 24.0, 48.0, 96.0][i - 1];
}

/// One role of the type scale: a size and a line height, in logical pixels.
@immutable
class FluidTypeRole {
  /// Creates a role.
  const FluidTypeRole(this.size, this.leading);

  /// Font size.
  final double size;

  /// Line height (CSS `line-height`), the height of one line box.
  final double leading;

  /// This role as a [TextStyle] in Inter.
  TextStyle style({FontWeight weight = FontWeight.w400, Color? color}) {
    final (wght, opsz) = switch (weight) {
      FontWeight.w700 || FontWeight.w800 || FontWeight.w900 => (700.0, 25.0),
      FontWeight.w500 || FontWeight.w600 => (550.0, 18.0),
      _ => (400.0, 14.0),
    };
    return TextStyle(
      fontFamily: 'Inter',
      package: 'fluid_mobile_spike',
      fontSize: size,
      height: leading / size,
      leadingDistribution: TextLeadingDistribution.even,
      fontWeight: weight,
      fontVariations: [
        FontVariation('wght', wght),
        FontVariation('opsz', opsz),
      ],
      color: color,
    );
  }
}

/// Every size that changes between a pointer UI and a touch UI.
///
/// [pointer] is the web's `default` ladder step verbatim (36px controls,
/// 13/20 body). [touch] is the mobile step specified in
/// `research/05-mobile-adaptations.md`: 44px controls and rows, 15/20 body,
/// 16px in editable fields, larger glyphs and gaps, rounder shells.
@immutable
class FluidMetrics {
  /// Creates a set of metrics.
  const FluidMetrics({
    required this.controlHeight,
    required this.rowHeight,
    required this.minHitTarget,
    required this.controlPaddingX,
    required this.itemPaddingX,
    required this.gap,
    required this.icon,
    required this.body,
    required this.caption,
    required this.title,
    required this.fieldFontSize,
    required this.popupInset,
    required this.itemRadius,
    required this.controlRadius,
    required this.containerRadius,
    required this.focusRingOutset,
    required this.triggerMinWidth,
  });

  /// The web's 36px step.
  static const pointer = FluidMetrics(
    controlHeight: 36,
    rowHeight: 36,
    minHitTarget: 24,
    controlPaddingX: 12,
    itemPaddingX: 8,
    gap: 8,
    icon: 16,
    body: FluidTypeRole(13, 20),
    caption: FluidTypeRole(12, 16),
    title: FluidTypeRole(16, 22),
    fieldFontSize: 13,
    popupInset: 4,
    itemRadius: 8,
    controlRadius: 8,
    containerRadius: 12,
    focusRingOutset: 2,
    triggerMinWidth: 160,
  );

  /// The touch step: 44px visual controls and rows.
  static const touch = FluidMetrics(
    controlHeight: 44,
    rowHeight: 44,
    minHitTarget: 44,
    controlPaddingX: 14,
    itemPaddingX: 12,
    gap: 12,
    icon: 20,
    body: FluidTypeRole(15, 20),
    caption: FluidTypeRole(13, 18),
    title: FluidTypeRole(17, 22),
    fieldFontSize: 16,
    popupInset: 6,
    itemRadius: 12,
    controlRadius: 12,
    containerRadius: 18,
    focusRingOutset: 2,
    triggerMinWidth: 160,
  );

  /// Height of bounded controls: buttons, inputs, select triggers.
  final double controlHeight;

  /// Height of list and menu rows. Equal to [controlHeight] by design, so a
  /// popup row lines up with the trigger that opened it.
  final double rowHeight;

  /// The smallest box a tap must land in, whatever the control looks like.
  final double minHitTarget;

  /// Horizontal padding of bounded controls.
  final double controlPaddingX;

  /// Horizontal padding of list and menu rows.
  final double itemPaddingX;

  /// Gap between a glyph and its label.
  final double gap;

  /// Glyph size inside controls and rows.
  final double icon;

  /// Control labels, rows, body copy.
  final FluidTypeRole body;

  /// Secondary text.
  final FluidTypeRole caption;

  /// Section headings, sheet titles.
  final FluidTypeRole title;

  /// Font size of editable text. 16 on touch so iOS-style zoom heuristics
  /// and small-text readability never bite.
  final double fieldFontSize;

  /// Padding of a popup shell around its rows.
  final double popupInset;

  /// Radius of a row and the fills that sit on it.
  final double itemRadius;

  /// Radius of bounded controls.
  final double controlRadius;

  /// Radius of a popup shell: [itemRadius] + [popupInset], concentric.
  final double containerRadius;

  /// How far a row's focus ring sits outside the row.
  final double focusRingOutset;

  /// Minimum width of a select trigger.
  final double triggerMinWidth;
}
