import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Motion tokens, mirroring `registry/default/lib/springs.ts`, as theme
/// data: components read them with `FluidTheme.motionOf(context)`, never
/// from a constant, so an app (or a subtree) can retune them at runtime and
/// the next animation picks the change up.
///
/// Each tier enters on a spring and exits on a plain tween one tier quicker,
/// so a dismissal reads as crisp and final instead of replaying the entrance.
///
/// The default springs are the *same physical springs* as the web's, not the
/// same numbers. motion.dev reads `{duration, bounce}` as a settle time: it
/// picks the stiffness at which the spring's envelope has decayed to 0.001
/// after `duration` (`findSpring`). Flutter's
/// `SpringDescription.withDurationAndBounce` (behind [CupertinoMotion])
/// reads `duration` as the period: stiffness = (2π / duration)². Solving
/// motion.dev's envelope for each tier and converting gives the durations
/// below. Same stiffness, same damping ratio (1 − bounce), mass 1:
///
/// | web token | ω (rad/s) | CupertinoMotion duration |
/// |---|---|---|
/// | fast 0.08s, bounce 0 | 115.4 | 54ms |
/// | moderate 0.16s, bounce 0 | 57.7 | 109ms |
/// | slow 0.24s, bounce 0.12 | 35.6 | 176ms |
///
/// Taking the web numbers literally (80/160/240ms) would make every Flutter
/// spring about 1.5× slower than the web.
@immutable
class FluidMotionThemeData {
  /// Creates motion tokens. Every argument defaults to the web's value.
  const FluidMotionThemeData({
    this.fast = const CupertinoMotion(duration: Duration(milliseconds: 54)),
    this.fastExit = const CurvedMotion(
      Duration(milliseconds: 60),
      Curves.easeOut,
    ),
    this.moderate = const CupertinoMotion(
      duration: Duration(milliseconds: 109),
    ),
    this.moderateExit = const CurvedMotion(
      Duration(milliseconds: 120),
      Curves.easeOut,
    ),
    this.slow = const CupertinoMotion(
      duration: Duration(milliseconds: 176),
      bounce: 0.12,
    ),
    this.slowExit = const CurvedMotion(
      Duration(milliseconds: 160),
      Curves.easeOut,
    ),
    this.color = const CurvedMotion(Duration(milliseconds: 80)),
    this.strokeIn = const CurvedMotion(
      Duration(milliseconds: 80),
      Curves.easeOut,
    ),
    this.strokeOut = const CurvedMotion(
      Duration(milliseconds: 40),
      Curves.easeIn,
    ),
    this.selectionAck = const Duration(milliseconds: 300),
  });

  /// The web's tokens.
  static const standard = FluidMotionThemeData();

  /// Hover, focus rings, fades, tooltips, selection indicators. Web
  /// `spring.fast` (0.08s, bounce 0).
  final Motion fast;

  /// The exit of [fast]: a 0.06s tween.
  final Motion fastExit;

  /// Short travel and panels or sheets that must land exactly: dropdown and
  /// tab indicators, the switch thumb, the mobile drawer. Web
  /// `spring.moderate` (0.16s, bounce 0).
  final Motion moderate;

  /// The exit of [moderate]: a 0.12s tween.
  final Motion moderateExit;

  /// Large surfaces: dialogs, side panels, stepped flows. Web `spring.slow`
  /// (0.24s, bounce 0.12).
  final Motion slow;

  /// The exit of [slow]: a 0.16s tween.
  final Motion slowExit;

  /// A CSS `transition-colors duration-80`: text and fill colors.
  final Motion color;

  /// A stroke drawing in (the select's check, 0.08s ease-out). A tween on
  /// purpose: the appear must outlast the disappear (motion-guidelines.md,
  /// "Icon swaps"), which a critically damped spring would invert.
  final Motion strokeIn;

  /// A stroke erasing (0.04s ease-in).
  final Motion strokeOut;

  /// How long a pick holds a select open so the check can draw and the
  /// selected fill can spring to the picked row (`selectionAckMs`).
  final Duration selectionAck;

  // Semantic aliases, so components say what moves rather than which tier.

  /// The fluid hover highlight and the focus ring travelling between rows.
  Motion get highlight => fast;

  /// The selected fill moving to a newly picked row.
  Motion get indicator => moderate;

  /// The exit of [indicator].
  Motion get indicatorExit => moderateExit;

  /// An anchored popover opening.
  Motion get popover => fast;

  /// An anchored popover closing.
  Motion get popoverExit => fastExit;

  /// A sheet or drawer opening.
  Motion get sheet => moderate;

  /// A sheet or drawer closing.
  Motion get sheetExit => moderateExit;

  /// Every motion swapped for [Motion.instant], for reduced motion. The web
  /// keeps a short opacity fade there; at these durations, instant is the
  /// honest equivalent.
  FluidMotionThemeData get reduced => const FluidMotionThemeData(
    fast: Motion.instant(),
    fastExit: Motion.instant(),
    moderate: Motion.instant(),
    moderateExit: Motion.instant(),
    slow: Motion.instant(),
    slowExit: Motion.instant(),
    color: Motion.instant(),
    strokeIn: Motion.instant(),
    strokeOut: Motion.instant(),
  ).copyWith(selectionAck: selectionAck);

  /// A copy with the given tokens replaced.
  FluidMotionThemeData copyWith({
    Motion? fast,
    Motion? fastExit,
    Motion? moderate,
    Motion? moderateExit,
    Motion? slow,
    Motion? slowExit,
    Motion? color,
    Motion? strokeIn,
    Motion? strokeOut,
    Duration? selectionAck,
  }) => FluidMotionThemeData(
    fast: fast ?? this.fast,
    fastExit: fastExit ?? this.fastExit,
    moderate: moderate ?? this.moderate,
    moderateExit: moderateExit ?? this.moderateExit,
    slow: slow ?? this.slow,
    slowExit: slowExit ?? this.slowExit,
    color: color ?? this.color,
    strokeIn: strokeIn ?? this.strokeIn,
    strokeOut: strokeOut ?? this.strokeOut,
    selectionAck: selectionAck ?? this.selectionAck,
  );

  /// Motions don't interpolate: switches at the midpoint, like
  /// `ThemeData.lerp` does for non-numeric fields.
  static FluidMotionThemeData lerp(
    FluidMotionThemeData a,
    FluidMotionThemeData b,
    double t,
  ) => t < 0.5 ? a : b;

  @override
  bool operator ==(Object other) =>
      other is FluidMotionThemeData &&
      other.fast == fast &&
      other.fastExit == fastExit &&
      other.moderate == moderate &&
      other.moderateExit == moderateExit &&
      other.slow == slow &&
      other.slowExit == slowExit &&
      other.color == color &&
      other.strokeIn == strokeIn &&
      other.strokeOut == strokeOut &&
      other.selectionAck == selectionAck;

  @override
  int get hashCode => Object.hash(
    fast,
    fastExit,
    moderate,
    moderateExit,
    slow,
    slowExit,
    color,
    strokeIn,
    strokeOut,
    selectionAck,
  );
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
    // 6 inset + 10 = 16: within a point of the trigger's 15, as on the web
    // (4 + 8 = 12 vs 12 + 1 = 13), so a row's label sits under the
    // trigger's.
    itemPaddingX: 10,
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
