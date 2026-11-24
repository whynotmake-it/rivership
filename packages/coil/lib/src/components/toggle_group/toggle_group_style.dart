import 'package:coil/foundation.dart';
import 'package:coil/src/components/toggle_group/toggle_group.dart'
    show CoilToggleGroupTrack;
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Overrides for how a `CoilToggleGroup` looks. Unset fields come from
/// [CoilToggleGroupStyle.fallback], derived from the theme's tokens. Set a
/// style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// [label] is resolved with [WidgetState.selected], [WidgetState.hovered]
/// and [WidgetState.focused].
class CoilToggleGroupStyle extends CoilComponentStyle<CoilToggleGroupStyle> {
  /// Creates a style.
  const CoilToggleGroupStyle({
    this.selection,
    this.highlight,
    this.label,
    this.textStyle,
    this.radius,
    this.border,
    this.padding,
    this.motions,
  });

  /// The defaults from the theme's tokens.
  factory CoilToggleGroupStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    // With brand selection on, the selected segments are marked in the
    // brand: a wash under brand text.
    final brand = theme.selectsInBrand;
    final selectedLabel = brand ? c.brandInk : c.foreground;
    return CoilToggleGroupStyle(
      selection: brand ? c.brandWash : c.active,
      highlight: c.hover,
      // Touch rows rest at full strength: "the pointer is here" means nothing
      // to a finger.
      label: metrics.tier == CoilTier.touch
          ? WidgetStateProperty<Color?>.fromMap({
              WidgetState.selected: selectedLabel,
              WidgetState.any: c.foreground,
            })
          : WidgetStateProperty<Color?>.fromMap({
              WidgetState.selected: selectedLabel,
              WidgetState.hovered | WidgetState.focused: c.foreground,
              WidgetState.any: c.mutedForeground,
            }),
      textStyle: theme.typography.resolve(metrics.tier, metrics.size).body,
      radius: theme.shape.radii(metrics.tier).item,
      border: c.border,
      padding: metrics.segmentPadding,
    );
  }

  /// The merged block behind selected items.
  final Color? selection;

  /// The gliding hover highlight.
  final Color? highlight;

  /// The label color.
  final WidgetStateProperty<Color?>? label;

  /// The label style (color from [label]).
  final TextStyle? textStyle;

  /// The corner radius of the segments: their blocks, the highlight and
  /// the press fill. The row's corner is concentric with it, [padding]
  /// out.
  final double? radius;

  /// The row's 1 px outline; fully transparent draws none.
  final Color? border;

  /// The space between the row's edge and its segments
  /// (`CoilMetrics.segmentPadding`).
  final double? padding;

  /// Springs for the group's animated parts, keyed by
  /// [CoilToggleGroupTrack]s:
  /// `{CoilToggleGroupTrack.selection: const Motion.bouncySpring()}`. A
  /// group's own `motions:` win over these; these win over the motion
  /// tokens. [merge] combines the maps key by key.
  final Map<CoilToggleGroupTrack<Object>, Motion>? motions;

  @override
  CoilToggleGroupStyle merge(CoilToggleGroupStyle? other) => other == null
      ? this
      : CoilToggleGroupStyle(
          selection: other.selection ?? selection,
          highlight: other.highlight ?? highlight,
          label: CoilComponentStyle.mergeStates(label, other.label),
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          radius: other.radius ?? radius,
          border: other.border ?? border,
          padding: other.padding ?? padding,
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
        );

  @override
  List<Object?> get props => [
    selection,
    highlight,
    label,
    textStyle,
    radius,
    border,
    padding,
    motions,
  ];
}
