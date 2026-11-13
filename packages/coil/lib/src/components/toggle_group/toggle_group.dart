import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/toggle_group/toggle_group_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilToggleGroup], as Motor tracks. Use them as
/// keys of [CoilToggleGroup.motions] or [CoilThemeData.trackMotions].
final class CoilToggleGroupTrack<T extends Object> extends Track<T> {
  CoilToggleGroupTrack._(super.converter, {required String super.debugLabel});

  /// The merged selection blocks. Default motion: `standard`.
  static final selection = CoilToggleGroupTrack<double>._(
    .single,
    debugLabel: 'CoilToggleGroup.selection',
  );

  /// The focus ring travelling between segments. Default motion: `quick`.
  static final ring = CoilToggleGroupTrack<double>._(
    .single,
    debugLabel: 'CoilToggleGroup.ring',
  );

  /// The label color. Default motion: `fade`.
  static final label = CoilToggleGroupTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilToggleGroup.label',
  );

  /// The touch press fill. Default motion: `fade`.
  static final press = CoilToggleGroupTrack<double>._(
    .single,
    debugLabel: 'CoilToggleGroup.press',
  );
}

/// A horizontal row of toggles whose selected items merge into one block: a
/// multi-select segmented control.
///
/// Left and Right (following the text direction) move focus, Home and End
/// jump, and Space or Enter toggles. The segments are one tab stop.
class CoilToggleGroup<T> extends StatelessWidget {
  /// Creates a toggle group.
  const CoilToggleGroup({
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

  /// The toggles: each option's [CoilOption.child] or `Text(label)`.
  final List<CoilOption<T>> options;

  /// The values of the selected toggles.
  final Set<T> values;

  /// Called with the new set of selected values. Null disables the group.
  final ValueChanged<Set<T>>? onChanged;

  /// Pins the group to one size step.
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions, keyed by [CoilToggleGroupTrack]s.
  final Map<CoilToggleGroupTrack<Object>, Motion>? motions;

  /// Overrides for this group's look, on top of the theme's
  /// [CoilToggleGroupStyle] and the defaults.
  final CoilToggleGroupStyle? style;

  /// Names the group for assistive technology.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: size);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final look = CoilToggleGroupStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilToggleGroupStyle>(context)).merge(style);
    Motion motionFor(
      CoilToggleGroupTrack<Object> track,
      Motion token, {
      bool spatial = true,
    }) => CoilTheme.trackMotionOf(
      context,
      track,
      instance: motions,
      token: token,
      spatial: spatial,
    );

    return Semantics(
      container: true,
      label: semanticLabel,
      child: CoilChoiceGroup<T>(
        options: options,
        selected: values,
        axis: Axis.horizontal,
        tabStops: CoilRovingTabStops.one,
        enabled: onChanged != null,
        selectionColor: look.selection!,
        highlightColor: look.highlight!,
        radius: look.radius!,
        selectionMotion: motionFor(
          CoilToggleGroupTrack.selection,
          tokens.standard,
        ),
        ringMotion: motionFor(CoilToggleGroupTrack.ring, tokens.quick),
        fadeMotion: tokens.fade,
        itemBuilder: (context, option, node, states) {
          final selected = values.contains(option.value);
          final onPressed = onChanged == null || !option.enabled
              ? null
              : () => onChanged!(
                  selected
                      ? ({...values}..remove(option.value))
                      : {...values, option.value},
                );
          return Semantics(
            container: true,
            selected: selected,
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
                CoilToggleGroupTrack.press,
                tokens.fade,
                spatial: false,
              ),
              releaseMotion: motionFor(
                CoilToggleGroupTrack.press,
                tokens.fadeExit,
                spatial: false,
              ),
              builder: (context, itemStates, _) {
                final color = look.label!.resolve({
                  if (selected) WidgetState.selected,
                  ...itemStates,
                })!;
                return ConstrainedBox(
                  constraints: BoxConstraints(minHeight: sizes.controlHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: sizes.controlPaddingX,
                      vertical: sizes.controlPaddingY(sizes.body),
                    ),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: MotionBuilder<Color>(
                        value: color,
                        motion: motionFor(
                          CoilToggleGroupTrack.label,
                          tokens.fade,
                          spatial: false,
                        ),
                        converter: .colorRgb,
                        builder: (context, color, child) => DefaultTextStyle(
                          style: look.textStyle!.copyWith(color: color),
                          maxLines: 1,
                          softWrap: false,
                          child: IconTheme(
                            data: IconThemeData(
                              size: sizes.iconSize,
                              applyTextScaling: true,
                              color: color,
                            ),
                            child: child!,
                          ),
                        ),
                        child: option.child ?? Text(option.label),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
