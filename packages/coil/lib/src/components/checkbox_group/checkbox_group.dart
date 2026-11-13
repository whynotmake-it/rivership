import 'dart:async';

import 'package:coil/checkbox.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/checkbox_group/checkbox_group_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilCheckboxGroup], as Motor tracks. Use them as
/// keys of [CoilCheckboxGroup.motions] or [CoilThemeData.trackMotions].
final class CoilCheckboxGroupTrack<T extends Object> extends Track<T> {
  CoilCheckboxGroupTrack._(super.converter, {required String super.debugLabel});

  /// The merged selection blocks. Default motion: `standard`.
  static final selection = CoilCheckboxGroupTrack<double>._(
    .single,
    debugLabel: 'CoilCheckboxGroup.selection',
  );

  /// The focus ring travelling between rows. Default motion: `quick`.
  static final ring = CoilCheckboxGroupTrack<double>._(
    .single,
    debugLabel: 'CoilCheckboxGroup.ring',
  );

  /// The label color and weight. Default motion: `fade`.
  static final label = CoilCheckboxGroupTrack<double>._(
    .single,
    debugLabel: 'CoilCheckboxGroup.label',
  );

  /// The touch press fill. Default motion: `fade`.
  static final press = CoilCheckboxGroupTrack<double>._(
    .single,
    debugLabel: 'CoilCheckboxGroup.press',
  );
}

/// A vertical list of checkable rows.
///
/// Checked rows that touch share one background block. Checking the row
/// between two blocks merges them; unchecking a row inside a block splits
/// it. The hover highlight glides over the rows, and one focus ring travels
/// with the keyboard.
///
/// Every row is a tab stop. Up and Down move focus with wrapping, Home and
/// End jump, and Space or Enter toggles. Labels wrap and grow their row. On
/// touch the blocks are the only selection mark, and a finger shows a press
/// fill.
class CoilCheckboxGroup<T> extends StatelessWidget {
  /// Creates a checkbox group.
  const CoilCheckboxGroup({
    required this.options,
    required this.values,
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

  /// The values of the checked rows.
  final Set<T> values;

  /// Called with the new set of checked values. Null disables the group.
  final ValueChanged<Set<T>>? onChanged;

  /// Pins the group to one size step.
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilCheckboxGroupTrack]s.
  final Map<CoilCheckboxGroupTrack<Object>, Motion>? motions;

  /// Overrides for this group's look, on top of the theme's
  /// [CoilCheckboxGroupStyle] and the defaults.
  final CoilCheckboxGroupStyle? style;

  /// Names the group for assistive technology.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: size);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final look = CoilCheckboxGroupStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilCheckboxGroupStyle>(context)).merge(style);
    Motion motionFor(
      CoilCheckboxGroupTrack<Object> track,
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
      CoilCheckboxGroupTrack.label,
      tokens.fade,
      spatial: false,
    );

    return Semantics(
      container: true,
      label: semanticLabel,
      child: CoilChoiceGroup<T>(
        options: options,
        selected: values,
        enabled: onChanged != null,
        selectionColor: look.selection!,
        highlightColor: look.highlight!,
        radius: look.radius!,
        selectionMotion: motionFor(
          CoilCheckboxGroupTrack.selection,
          tokens.standard,
        ),
        ringMotion: motionFor(CoilCheckboxGroupTrack.ring, tokens.quick),
        fadeMotion: tokens.fade,
        itemBuilder: (context, option, node, states) {
          final checked = values.contains(option.value);
          final onPressed = onChanged == null || !option.enabled
              ? null
              : () {
                  unawaited(CoilHaptics.play(context, CoilHapticEvent.toggle));
                  onChanged!(
                    checked
                        ? ({...values}..remove(option.value))
                        : {...values, option.value},
                  );
                };
          return Semantics(
            container: true,
            checked: checked,
            enabled: onPressed != null,
            // The Text already names the row; a custom child needs it.
            label: option.child == null ? null : option.label,
            child: CoilChoiceItem(
              size: size,
              onPressed: onPressed,
              focusNode: node,
              statesController: states,
              pressFill: look.selection!,
              radius: look.radius!,
              pressMotion: motionFor(
                CoilCheckboxGroupTrack.press,
                tokens.fade,
                spatial: false,
              ),
              releaseMotion: motionFor(
                CoilCheckboxGroupTrack.press,
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
                leading: CoilCheckboxIndicator(
                  value: checked,
                  states: itemStates,
                  size: size,
                  motion: motion,
                  style: look.checkbox,
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
