/// @docImport 'package:coil/checkbox_group.dart';
library;

import 'package:coil/checkbox.dart';
import 'package:coil/foundation.dart';
import 'package:coil/src/components/checkbox_group/checkbox_group.dart'
    show CoilCheckboxGroupTrack;
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Overrides for how a [CoilCheckboxGroup] looks.
///
/// Unset fields come from [CoilCheckboxGroupStyle.fallback], derived from the
/// theme's tokens. Set a style app-wide or for a subtree with
/// [CoilThemeData.withComponentStyle], or per instance with `style:`.
///
/// [label] is resolved with [WidgetState.selected], [WidgetState.hovered]
/// and [WidgetState.focused].
class CoilCheckboxGroupStyle
    extends CoilComponentStyle<CoilCheckboxGroupStyle> {
  /// Creates a style.
  const CoilCheckboxGroupStyle({
    this.selection,
    this.highlight,
    this.label,
    this.textStyle,
    this.radius,
    this.checkbox,
    this.motions,
  });

  /// The defaults from the theme's tokens.
  factory CoilCheckboxGroupStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    return CoilCheckboxGroupStyle(
      selection: c.active,
      highlight: c.hover,
      // Touch rows rest at full strength: "the pointer is here" means nothing
      // to a finger.
      label: metrics.tier == CoilTier.touch
          ? WidgetStatePropertyAll<Color?>(c.foreground)
          : WidgetStateProperty<Color?>.fromMap({
              WidgetState.selected | WidgetState.hovered | WidgetState.focused:
                  c.foreground,
              WidgetState.any: c.mutedForeground,
            }),
      textStyle: theme.typography.resolve(metrics.tier, metrics.size).body,
      radius: theme.shape.radii(metrics.tier).item,
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

  /// The corner radius of blocks and the highlight.
  final double? radius;

  /// The look of each row's box.
  final CoilCheckboxStyle? checkbox;

  /// Springs for the group's animated parts, keyed by
  /// [CoilCheckboxGroupTrack]s:
  /// `{CoilCheckboxGroupTrack.selection: const Motion.bouncySpring()}`.
  ///
  /// A group's own `motions:` win over these; these win over the motion tokens.
  /// [merge] combines the maps key by key.
  final Map<CoilCheckboxGroupTrack<Object>, Motion>? motions;

  @override
  CoilCheckboxGroupStyle merge(CoilCheckboxGroupStyle? other) => other == null
      ? this
      : CoilCheckboxGroupStyle(
          selection: other.selection ?? selection,
          highlight: other.highlight ?? highlight,
          label: CoilComponentStyle.mergeStates(label, other.label),
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          radius: other.radius ?? radius,
          checkbox: checkbox?.merge(other.checkbox) ?? other.checkbox,
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
    checkbox,
    motions,
  ];
}
