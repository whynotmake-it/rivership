import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/checkbox/checkbox_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a checkbox, as Motor tracks. Use them as keys of
/// `motions` or [CoilThemeData.trackMotions].
final class CoilCheckboxTrack<T extends Object> extends Track<T> {
  CoilCheckboxTrack._(super.converter, {required String super.debugLabel});

  /// The box outline color. Default motion: `fade`.
  static final border = CoilCheckboxTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilCheckbox.border',
  );

  /// The tick or dash drawing in and out. Default motion: `fade` in,
  /// `fadeExit` out.
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

  /// Whether the box is checked. Null (only with [tristate]) shows a dash:
  /// some, not all, of what this box stands for is on.
  final bool? value;

  /// Called with the next value. Null disables the checkbox.
  final ValueChanged<bool?>? onChanged;

  /// Whether a tap cycles through null, and whether [value] may be null.
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

  /// Overrides the theme's motion tokens for this instance.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilCheckboxTrack]s.
  final Map<CoilCheckboxTrack<Object>, Motion>? motions;

  /// Overrides for this checkbox's look, on top of the theme's
  /// [CoilCheckboxStyle] and the defaults.
  final CoilCheckboxStyle? style;

  /// A label for assistive technology.
  final String? semanticLabel;

  /// Replaces the built-in tick and dash.
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

/// The corner radius of the box at the current text scale.
BorderRadius _radiusOf(BuildContext context, CoilCheckboxStyle style) {
  final box = MediaQuery.textScalerOf(context).scale(style.size!);
  return BorderRadius.circular(style.radius! * box / style.size!);
}

/// The box and glyph of a checkbox, with no interaction of its own.
///
/// [states] drives the border: `hovered` and `error` (invalid) are read, the
/// checked look comes from [value]. Use it inside a row that is already the
/// tap target. [CoilCheckbox] adds focus, hover and tap handling around it.
///
/// The box and tick grow with the text scale.
class CoilCheckboxIndicator extends StatefulWidget {
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

  /// Pins the box to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens for this instance.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilCheckboxTrack]s.
  final Map<CoilCheckboxTrack<Object>, Motion>? motions;

  /// Overrides for this indicator's look, on top of the theme's
  /// [CoilCheckboxStyle] and the defaults.
  final CoilCheckboxStyle? style;

  /// Replaces the built-in tick and dash.
  final CoilCheckboxGlyphBuilder? glyphBuilder;

  @override
  State<CoilCheckboxIndicator> createState() => _CoilCheckboxIndicatorState();
}

class _CoilCheckboxIndicatorState extends State<CoilCheckboxIndicator> {
  _Glyph get _glyph => switch (widget.value) {
    null => _Glyph.dash,
    true => _Glyph.check,
    false => _Glyph.none,
  };

  /// The glyph being drawn, kept while it retracts.
  late _Glyph _shown = _glyph;

  /// Bumped when the glyph changes shape, so a new one draws from 0.
  int _generation = 0;

  @override
  void didUpdateWidget(CoilCheckboxIndicator oldWidget) {
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
    final tokens = CoilTheme.motionOf(context, override: widget.motion);
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    final style = CoilCheckboxStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilCheckboxStyle>(context)).merge(widget.style);
    final on = _glyph != _Glyph.none;
    final scaler = MediaQuery.textScalerOf(context);
    final boxSize = scaler.scale(style.size!);
    final glyphSize = scaler.scale(
      sizes.checkboxGlyphSize * style.size! / sizes.checkboxSize,
    );
    final border = style.border!.resolve({
      if (widget.states.contains(WidgetState.hovered)) WidgetState.hovered,
      if (widget.states.contains(WidgetState.error)) WidgetState.error,
      if (on) WidgetState.selected,
    })!;

    Motion motionFor(CoilCheckboxTrack<Object> track, Motion token) =>
        CoilTheme.trackMotionOf(
          context,
          track,
          instance: widget.motions,
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
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: _radiusOf(context, style),
              side: BorderSide(color: borderColor, width: style.borderWidth!),
            ),
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
            motion: motionFor(
              CoilCheckboxTrack.glyph,
              on ? tokens.fade : tokens.fadeExit,
            ),
            builder: (context, progress, _) {
              final builder = widget.glyphBuilder;
              if (builder != null && _shown != _Glyph.none) {
                return builder(
                  context,
                  _shown == _Glyph.dash
                      ? CoilCheckboxGlyph.dash
                      : CoilCheckboxGlyph.check,
                  progress.clamp(0, 1),
                  style.glyphColor!,
                  glyphSize,
                );
              }
              return IconTheme(
                data: IconThemeData(
                  size: glyphSize,
                  applyTextScaling: false,
                  color: style.glyphColor,
                  weight: CoilIconWeight.emphasis,
                ),
                child: CoilDrawnGlyph(
                  _shown == _Glyph.dash ? CoilGlyph.dash : CoilGlyph.check,
                  progress: progress,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
