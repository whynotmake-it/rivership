import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/toggle_group/toggle_group_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The animated parts of a [CoilToggleGroup], as Motor tracks. Use them as
/// keys of [CoilToggleGroup.motions] or [CoilToggleGroupStyle.motions].
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

  /// A segment's width as its label changes: the segment springs and the
  /// selection follows it. Default motion: `standard`; the label
  /// cross-fades on `fade` / `fadeExit`.
  static final size = CoilToggleGroupTrack<double>._(
    .single,
    debugLabel: 'CoilToggleGroup.size',
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
/// A segment whose label changes cross-fades it and springs to the new
/// width ([CoilToggleGroupTrack.size]); the selection follows. A change of
/// the room around the group relayouts at once.
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

  /// The toggles: each option's [CoilOption.icon] (before the label) and
  /// [CoilOption.label]. An icon-only segment passes its icon as the label,
  /// with a [CoilOption.semanticLabel].
  final List<CoilOption<T>> options;

  /// The values of the selected toggles.
  final Set<T> values;

  /// Called with the new set of selected values. Null disables the group.
  final ValueChanged<Set<T>>? onChanged;

  /// Pins the group to one size step.
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions for this group, keyed by [CoilToggleGroupTrack]s.
  /// They win over the style's [CoilToggleGroupStyle.motions] and the
  /// tokens.
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
      styled: look.motions,
      token: token,
      spatial: spatial,
    );

    final group = CoilChoiceGroup<T>(
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
            : () {
                unawaited(CoilHaptics.play(context, CoilHapticEvent.toggle));
                onChanged!(
                  selected
                      ? ({...values}..remove(option.value))
                      : {...values, option.value},
                );
              };
        return Semantics(
          container: true,
          selected: selected,
          enabled: onPressed != null,
          label: option.semanticLabel,
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
                    vertical: sizes.controlPaddingY(look.textStyle!),
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
                        // The group cuts the widest items when they don't
                        // all fit; their labels end in an ellipsis.
                        overflow: TextOverflow.ellipsis,
                        child: IconTheme(
                          data: IconThemeData(
                            size: sizes.iconSize,
                            applyTextScaling: true,
                            color: color,
                          ),
                          child: child!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: sizes.buttonGap,
                        children: [
                          // The option's icon leads the label, in the same
                          // color and size; it yields before overflowing in a
                          // group too narrow for its segments.
                          if (option.icon case final icon?)
                            Flexible(child: icon),
                          Flexible(
                            child: CoilSizeSwitcher(
                              alignment: AlignmentDirectional.centerStart,
                              sizeMotion: motionFor(
                                CoilToggleGroupTrack.size,
                                tokens.standard,
                              ),
                              motion: motion,
                              debugLabel: 'CoilToggleGroup.label',
                              child: option.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    // The row: a hairline around the segments, `segmentPadding` out, its
    // corner sharing a center with theirs.
    final padding = look.padding!;
    final rowRadius = theme.shape
        .radii(sizes.tier)
        .concentric(
          look.radius!,
          padding,
          innerExtent: sizes.controlHeight,
        );
    return Semantics(
      container: true,
      label: semanticLabel,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(rowRadius),
            side: BorderSide(color: look.border!),
          ),
        ),
        child: Padding(padding: EdgeInsets.all(padding), child: group),
      ),
    );
  }
}
