import 'package:coil/foundation.dart';
import 'package:coil/src/components/tabs/tabs.dart' show CoilTabsTrack;
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Overrides for how a `CoilTabs` looks. Unset fields come from
/// [CoilTabsStyle.fallback], derived from the theme's tokens. Set a
/// style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// [label] is resolved with [WidgetState.selected] and
/// [WidgetState.hovered].
class CoilTabsStyle extends CoilComponentStyle<CoilTabsStyle> {
  /// Creates a style.
  const CoilTabsStyle({
    this.pill,
    this.hoverPill,
    this.hoverPillOpacity,
    this.label,
    this.textStyle,
    this.radius,
    this.minHeight,
    this.edgeFade,
    this.motions,
  });

  /// The defaults from the theme's tokens.
  factory CoilTabsStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    return CoilTabsStyle(
      // The current tab is marked in the brand: a wash under brand text.
      pill: c.brandWash,
      // Hover is never colored: it previews a tab in the neutral wash.
      hoverPill: c.active,
      hoverPillOpacity: 0.4,
      label: WidgetStateProperty<Color?>.fromMap({
        WidgetState.selected: c.brandInk,
        WidgetState.hovered: c.foreground,
        WidgetState.any: c.mutedForeground,
      }),
      textStyle: theme.typography.resolve(metrics.tier, metrics.size).body,
      radius: theme.shape.radii(metrics.tier).item,
      minHeight: metrics.controlHeight,
      edgeFade: 24,
    );
  }

  /// The selected pill.
  final Color? pill;

  /// The hover pill's color, before [hoverPillOpacity]. Neutral, so only
  /// the selected tab is marked in the brand.
  final Color? hoverPill;

  /// How strong the hover pill is, as a fraction of [hoverPill].
  final double? hoverPillOpacity;

  /// The label and icon color.
  final WidgetStateProperty<Color?>? label;

  /// The label style (color from [label], weight animated).
  final TextStyle? textStyle;

  /// The pills' corner radius.
  final double? radius;

  /// The minimum tab height (tabs grow with text).
  final double? minHeight;

  /// How far an edge fades when more tabs are scrolled out behind it.
  final double? edgeFade;

  /// Springs for the tabs' animated parts, keyed by [CoilTabsTrack]s:
  /// `{CoilTabsTrack.selected: const Motion.bouncySpring()}`. A tab bar's
  /// own `motions:` win over these; these win over the motion tokens.
  /// [merge] combines the maps key by key.
  final Map<CoilTabsTrack<Object>, Motion>? motions;

  @override
  CoilTabsStyle merge(CoilTabsStyle? other) => other == null
      ? this
      : CoilTabsStyle(
          pill: other.pill ?? pill,
          hoverPill: other.hoverPill ?? hoverPill,
          hoverPillOpacity: other.hoverPillOpacity ?? hoverPillOpacity,
          label: CoilComponentStyle.mergeStates(label, other.label),
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          radius: other.radius ?? radius,
          minHeight: other.minHeight ?? minHeight,
          edgeFade: other.edgeFade ?? edgeFade,
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
        );

  @override
  List<Object?> get props => [
    pill,
    hoverPill,
    hoverPillOpacity,
    label,
    textStyle,
    radius,
    minHeight,
    edgeFade,
    motions,
  ];
}
