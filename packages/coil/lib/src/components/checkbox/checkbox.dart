import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/checkbox/checkbox_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a checkbox, as Motor tracks.
///
/// Use them as keys of [CoilCheckbox.motions] or [CoilCheckboxStyle.motions].
final class CoilCheckboxTrack<T extends Object> extends Track<T> {
  CoilCheckboxTrack._(super.converter, {required String super.debugLabel});

  /// The box outline color.
  ///
  /// Default motion: [CoilMotion.fade].
  static final border = CoilCheckboxTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilCheckbox.border',
  );

  /// The tick or dash drawing in and out: its icon presence (a
  /// [CoilIconPresence]).
  ///
  /// Default motion: [CoilMotion.fade] in, [CoilMotion.fadeExit] out; under
  /// reduced motion it lands at once.
  static final glyph = CoilCheckboxTrack<double>._(
    .single,
    debugLabel: 'CoilCheckbox.glyph',
  );
}

/// A checkbox.
///
/// A tap, Space or Enter reports the next value. [value] is a `bool?` where
/// null means indeterminate, which needs [tristate]. Only a tristate
/// checkbox cycles through null (false, true, null, false); otherwise a tap
/// reports `!value`.
///
/// The box is a [CoilCheckboxIndicator]. Rows that are themselves the tap
/// target (a checkbox group) use the indicator directly.
class CoilCheckbox extends StatelessWidget {
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
    this.motions,
    this.style,
    this.semanticLabel,
    this.glyphBuilder,
  }) : assert(tristate || value != null, 'Only a tristate checkbox is null');

  /// Whether the box is checked.
  ///
  /// Null (only with [tristate]) shows a dash: some, not all, of what this box
  /// stands for is on.
  final bool? value;

  /// Called with the next value.
  ///
  /// Null disables the checkbox.
  final ValueChanged<bool?>? onChanged;

  /// Whether a tap cycles through null, and whether [value] may be null.
  final bool tristate;

  /// Marks the box as invalid (a red-tinted border while unchecked).
  final bool invalid;

  /// Pins the box to one size step.
  ///
  /// Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// The focus node.
  final FocusNode? focusNode;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// Observes, and can force, hover/focus/press states.
  final WidgetStatesController? statesController;

  /// Overrides the theme's motion tokens for this instance.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilCheckboxTrack]s.
  ///
  /// They win over the style's [CoilCheckboxStyle.motions] and the tokens.
  final Map<CoilCheckboxTrack<Object>, Motion>? motions;

  /// Overrides for this checkbox's look, on top of the theme's
  /// [CoilCheckboxStyle] and the defaults.
  final CoilCheckboxStyle? style;

  /// A label for assistive technology.
  final String? semanticLabel;

  /// Replaces the tick and dash: the theme's [CoilIcons.check] and
  /// [CoilIcons.dash], or Coil's drawn ones.
  final CoilCheckboxGlyphBuilder? glyphBuilder;

  bool? get _next => switch (value) {
    false => true,
    true => tristate ? null : false,
    null => false,
  };

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: size);
    final look = CoilCheckboxStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilCheckboxStyle>(context)).merge(style);
    final enabled = onChanged != null;
    final field = CoilFieldScope.maybeOf(context);
    void report() {
      unawaited(CoilHaptics.play(context, CoilHapticEvent.toggle));
      onChanged!(_next);
    }

    return CoilFieldControl(
      onLabelTap: enabled ? report : null,
      tapArea: CoilFieldTapArea.row,
      child: Semantics(
        container: true,
        checked: value ?? false,
        mixed: value == null,
        enabled: enabled,
        label: semanticLabel,
        child: CoilInteraction(
          onPressed: enabled ? report : null,
          focusNode: focusNode,
          autofocus: autofocus,
          statesController: statesController,
          // A framing container is the target.
          minHitTarget: (field?.framed ?? false) ? 0 : sizes.minHitTarget,
          builder: (context, states, _) => Opacity(
            opacity: enabled ? 1 : sizes.disabledOpacity,
            child: CoilFocusRing(
              visible:
                  states.contains(WidgetState.focused) &&
                  !(field?.framed ?? false),
              borderRadius: _radiusOf(context, look),
              child: CoilCheckboxIndicator(
                value: value,
                states: {
                  if (invalid) WidgetState.error,
                  if (enabled && (field?.containerHovered ?? false))
                    WidgetState.hovered,
                  if (enabled && (field?.containerPressed ?? false))
                    WidgetState.pressed,
                  ...states,
                },
                size: size,
                motion: motion,
                motions: motions,
                style: style,
                glyphBuilder: glyphBuilder,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// State glyph drawn inside a [CoilCheckbox] when checked or indeterminate.
enum CoilCheckboxGlyph {
  /// Checked.
  check,

  /// Indeterminate.
  dash,
}

/// Draws a checkbox glyph [progress] of the way in (0 hidden, 1 complete), at
/// [size] in [color].
///
/// Replaces the tick and dash, the theme's included. The tick and dash are
/// icons too ([CoilIcons.check], [CoilIcons.dash]): an icon that reads its
/// [CoilIconPresence] animates the same way.
typedef CoilCheckboxGlyphBuilder =
    Widget Function(
      BuildContext context,
      CoilCheckboxGlyph glyph,
      double progress,
      Color color,
      double size,
    );

/// The corner radius of the box at the current text scale.
BorderRadius _radiusOf(BuildContext context, CoilCheckboxStyle style) {
  final box = MediaQuery.textScalerOf(context).scale(style.size!);
  return BorderRadius.circular(style.radius! * box / style.size!);
}

/// The box and glyph of a checkbox, with no interaction of its own.
///
/// [states] drives the border: `hovered`, `pressed` and `error` (invalid)
/// are read, the checked look comes from [value]. Use it inside a row that
/// is already the tap target. [CoilCheckbox] adds focus, hover and tap
/// handling around it.
///
/// The box and tick grow with the text scale.
///
/// The tick and dash are [CoilIcons.check] and [CoilIcons.dash] (Coil's
/// drawn ones by default), shown in a [CoilIconPresence] that rises as they
/// appear: Coil's draw themselves in, other icons fade and scale. Changing
/// between them crosses the two.
class CoilCheckboxIndicator extends StatelessWidget {
  /// Creates a checkbox indicator.
  const CoilCheckboxIndicator({
    required this.value,
    required this.states,
    super.key,
    this.size,
    this.motion,
    this.motions,
    this.style,
    this.glyphBuilder,
  });

  /// Whether the box is checked; null shows the dash.
  final bool? value;

  /// The states the border reacts to.
  final Set<WidgetState> states;

  /// Pins the box to one size step.
  ///
  /// Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens for this instance.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilCheckboxTrack]s.
  ///
  /// They win over the style's [CoilCheckboxStyle.motions] and the tokens.
  final Map<CoilCheckboxTrack<Object>, Motion>? motions;

  /// Overrides for this indicator's look, on top of the theme's
  /// [CoilCheckboxStyle] and the defaults.
  final CoilCheckboxStyle? style;

  /// Replaces the tick and dash, the theme's included.
  final CoilCheckboxGlyphBuilder? glyphBuilder;

  CoilCheckboxGlyph? get _glyph => switch (value) {
    null => CoilCheckboxGlyph.dash,
    true => CoilCheckboxGlyph.check,
    false => null,
  };

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final sizes = CoilTheme.metricsOf(context, size: size);
    final style = CoilCheckboxStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilCheckboxStyle>(context)).merge(this.style);
    final glyph = _glyph;
    final on = glyph != null;
    final scaler = MediaQuery.textScalerOf(context);
    final boxSize = scaler.scale(style.size!);
    final glyphSize = scaler.scale(
      sizes.checkboxGlyphSize * style.size! / sizes.checkboxSize,
    );
    final border = style.border!.resolve({
      if (states.contains(WidgetState.hovered)) WidgetState.hovered,
      if (states.contains(WidgetState.pressed)) WidgetState.pressed,
      if (states.contains(WidgetState.error)) WidgetState.error,
      if (on) WidgetState.selected,
    })!;

    Motion motionFor(CoilCheckboxTrack<Object> track, Motion token) =>
        CoilTheme.trackMotionOf(
          context,
          track,
          instance: motions,
          styled: style.motions,
          token: token,
          spatial: false,
        );

    // The box keeps its size in a stretched parent (a field, a column) and
    // sits at the start, like text does.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: MotionBuilder<Color>(
        value: border,
        motion: motionFor(CoilCheckboxTrack.border, tokens.fade),
        converter: MotionConverter.colorRgb,
        builder: (context, borderColor, child) => Container(
          width: boxSize,
          height: boxSize,
          decoration: CoilRelief.decorate(
            ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: _radiusOf(context, style),
                side: BorderSide(color: borderColor, width: style.borderWidth!),
              ),
            ),
            // A well the tick sits in, under a plastic theme.
            CoilTheme.reliefOf(
              context,
              CoilReliefRole.recessed,
              override: style.plasticity,
              hover:
                  states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.pressed)
                  ? 1
                  : 0,
              enabled: !states.contains(WidgetState.disabled),
            ),
          ),
          child: child,
        ),
        child: OverflowBox(
          maxWidth: glyphSize,
          maxHeight: glyphSize,
          child: IconTheme(
            data: IconThemeData(
              size: glyphSize,
              applyTextScaling: false,
              color: style.glyphColor,
              weight: CoilIconWeight.emphasis,
            ),
            child: CoilIconSwitcher(
              motion: motionFor(CoilCheckboxTrack.glyph, tokens.fade),
              exitMotion: motionFor(CoilCheckboxTrack.glyph, tokens.fadeExit),
              child: switch (glyph) {
                null => null,
                final glyph => KeyedSubtree(
                  key: ValueKey(glyph),
                  child: switch (glyphBuilder) {
                    final builder? => _BuiltGlyph(
                      builder: builder,
                      glyph: glyph,
                      color: style.glyphColor!,
                      size: glyphSize,
                    ),
                    null => CoilIcon(switch (glyph) {
                      CoilCheckboxGlyph.check => CoilIconRole.check,
                      CoilCheckboxGlyph.dash => CoilIconRole.dash,
                    }),
                  },
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A [CoilCheckboxGlyphBuilder]'s glyph, drawn as far in as its icon
/// presence.
class _BuiltGlyph extends StatelessWidget {
  const _BuiltGlyph({
    required this.builder,
    required this.glyph,
    required this.color,
    required this.size,
  });

  final CoilCheckboxGlyphBuilder builder;
  final CoilCheckboxGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final presence =
        CoilIconPresence.maybeOf(context) ?? kAlwaysCompleteAnimation;
    return AnimatedBuilder(
      animation: presence,
      builder: (context, _) =>
          builder(context, glyph, presence.value, color, size),
    );
  }
}
