import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/radio_group/radio_group_style.dart';
import 'package:coil/src/components/radio_group/radio_indicator.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilRadioGroup], as Motor tracks. Use them as
/// keys of [CoilRadioGroup.motions] or [CoilThemeData.trackMotions].
final class CoilRadioGroupTrack<T extends Object> extends Track<T> {
  CoilRadioGroupTrack._(super.converter, {required String super.debugLabel});

  /// The selected fill gliding between rows. Default motion: `standard`.
  static final selection = CoilRadioGroupTrack<double>._(
    .single,
    debugLabel: 'CoilRadioGroup.selection',
  );

  /// The focus ring travelling between rows. Default motion: `quick`.
  static final ring = CoilRadioGroupTrack<double>._(
    .single,
    debugLabel: 'CoilRadioGroup.ring',
  );

  /// The label color and weight. Default motion: `fade`.
  static final label = CoilRadioGroupTrack<double>._(
    .single,
    debugLabel: 'CoilRadioGroup.label',
  );

  /// The touch press fill. Default motion: `fade`.
  static final press = CoilRadioGroupTrack<double>._(
    .single,
    debugLabel: 'CoilRadioGroup.press',
  );

  /// The circle's outline color. Default motion: `fade`.
  static final border = CoilRadioGroupTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilRadioGroup.border',
  );

  /// The dot scaling in and fading out. Default motion: `quick` in,
  /// `fadeExit` out.
  static final dot = CoilRadioGroupTrack<double>._(
    .single,
    debugLabel: 'CoilRadioGroup.dot',
  );
}

/// A vertical list of options where one is selected.
///
/// The selected row is the group's one tab stop. The arrow keys, Home and
/// End move to another row and select it, with wrapping. Disabled rows are
/// skipped. Labels wrap and grow their row.
///
/// Use a select for more than seven options.
class CoilRadioGroup<T> extends StatelessWidget {
  /// Creates a radio group.
  const CoilRadioGroup({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
    this.size,
    this.motion,
    this.motions,
    this.style,
    this.semanticLabel,
  });

  /// The rows: each option's [CoilOption.child] or `Text(label)`.
  final List<CoilOption<T>> options;

  /// The value of the selected row. A value no option has selects none.
  final T? value;

  /// Called with the value of the row to select. Null disables the group.
  final ValueChanged<T>? onChanged;

  /// Pins the group to one size step.
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilRadioGroupTrack]s.
  final Map<CoilRadioGroupTrack<Object>, Motion>? motions;

  /// Overrides for this group's look, on top of the theme's
  /// [CoilRadioGroupStyle] and the defaults.
  final CoilRadioGroupStyle? style;

  /// Names the group for assistive technology.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: size);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final look = CoilRadioGroupStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilRadioGroupStyle>(context)).merge(style);
    Motion motionFor(
      CoilRadioGroupTrack<Object> track,
      Motion token, {
      bool spatial = true,
    }) => CoilTheme.trackMotionOf(
      context,
      track,
      instance: motions,
      token: token,
      spatial: spatial,
    );
    final labelMotion = motionFor(
      CoilRadioGroupTrack.label,
      tokens.fade,
      spatial: false,
    );

    return Semantics(
      container: true,
      label: semanticLabel,
      role: SemanticsRole.radioGroup,
      child: CoilChoiceGroup<T>(
        options: options,
        selected: {?value},
        selection: CoilChoiceSelection.gliding,
        tabStops: CoilRovingTabStops.one,
        enabled: onChanged != null,
        selectionColor: look.selection!,
        highlightColor: look.highlight!,
        radius: look.radius!,
        selectionMotion: motionFor(
          CoilRadioGroupTrack.selection,
          tokens.standard,
        ),
        ringMotion: motionFor(CoilRadioGroupTrack.ring, tokens.quick),
        fadeMotion: tokens.fade,
        // Arrows move focus; landing on a row selects it.
        onFocusMoved: (v) {
          if (v == value) return;
          unawaited(CoilHaptics.play(context, CoilHapticEvent.toggle));
          onChanged!(v);
        },
        itemBuilder: (context, option, node, states) {
          final checked = option.value == value;
          final onPressed = onChanged == null || !option.enabled
              ? null
              : () {
                  unawaited(CoilHaptics.play(context, CoilHapticEvent.toggle));
                  onChanged!(option.value);
                };
          return Semantics(
            container: true,
            inMutuallyExclusiveGroup: true,
            checked: checked,
            enabled: onPressed != null,
            label: option.child == null ? null : option.label,
            child: CoilChoiceItem(
              size: size,
              onPressed: onPressed,
              focusNode: node,
              statesController: states,
              pressFill: look.selection!,
              radius: look.radius!,
              pressMotion: motionFor(
                CoilRadioGroupTrack.press,
                tokens.fade,
                spatial: false,
              ),
              releaseMotion: motionFor(
                CoilRadioGroupTrack.press,
                tokens.fadeExit,
                spatial: false,
              ),
              builder: (context, itemStates, _) => CoilChoiceRow(
                size: size,
                selected: checked,
                labelStyle: look.textStyle!,
                labelColor: look.label!.resolve({
                  if (checked) WidgetState.selected,
                  ...itemStates,
                })!,
                labelMotion: labelMotion,
                leading: CoilRadioIndicator(
                  selected: checked,
                  states: itemStates,
                  size: size,
                  motion: motion,
                  motions: motions,
                  style: style,
                ),
                label: option.child ?? Text(option.label),
              ),
            ),
          );
        },
      ),
    );
  }
}
