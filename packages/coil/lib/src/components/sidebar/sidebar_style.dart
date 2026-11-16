import 'package:coil/foundation.dart';
import 'package:coil/src/components/sidebar/sidebar_scaffold.dart'
    show CoilSidebarTrack;
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Overrides for how a `CoilSidebarScaffold` and its parts look; unset
/// fields come from [CoilSidebarStyle.fallback].
class CoilSidebarStyle extends CoilComponentStyle<CoilSidebarStyle> {
  /// Creates a sidebar style.
  const CoilSidebarStyle({
    this.background,
    this.edgeColor,
    this.railColor,
    this.inset,
    this.padding,
    this.gap,
    this.actionSize,
    this.actionGap,
    this.labelStyle,
    this.labelColor,
    this.motions,
  });

  /// The defaults from [theme]'s tokens at [metrics].
  factory CoilSidebarStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    return CoilSidebarStyle(
      edgeColor: c.border,
      railColor: CoilColorMix.withTransparent(c.foreground, 0.25),
      inset: 8,
      padding: 8,
      gap: 8,
      actionSize: 24,
      actionGap: 4,
      labelStyle: theme.typography.resolve(metrics.tier, metrics.size).caption,
      labelColor: WidgetStateProperty<Color?>.fromMap({
        WidgetState.hovered | WidgetState.focused: c.foreground,
        WidgetState.any: c.mutedForeground,
      }),
    );
  }

  /// The `sidebar` variant's fill. Null leaves it transparent, on
  /// whatever is behind the scaffold.
  final Color? background;

  /// The `sidebar` variant's hairline at its inner edge. Transparent draws
  /// none.
  final Color? edgeColor;

  /// The rail's hairline while hovered or dragged.
  final Color? railColor;

  /// The margin around a `floating` card and an `inset` page card.
  final double? inset;

  /// The space between the sidebar's edges and its sections.
  final double? padding;

  /// The space between sections, and between the parts of a header or
  /// footer.
  final double? gap;

  /// The square of a `CoilSidebarAction`, before the touch hit area.
  final double? actionSize;

  /// The space between neighboring actions.
  final double? actionGap;

  /// A group label's text style. Its color comes from [labelColor].
  final TextStyle? labelStyle;

  /// A group label's color, resolved with [WidgetState.hovered] and
  /// [WidgetState.focused].
  final WidgetStateProperty<Color?>? labelColor;

  /// Springs for the sidebar's animated parts, keyed by [CoilSidebarTrack]s:
  /// `{CoilSidebarTrack.fold: const Motion.bouncySpring()}`. A scaffold's,
  /// menu's or callout's own `motions:` win over these; these win over the
  /// motion tokens. [merge] combines the maps key by key.
  final Map<CoilSidebarTrack<Object>, Motion>? motions;

  @override
  CoilSidebarStyle merge(CoilSidebarStyle? other) => other == null
      ? this
      : CoilSidebarStyle(
          background: other.background ?? background,
          edgeColor: other.edgeColor ?? edgeColor,
          railColor: other.railColor ?? railColor,
          inset: other.inset ?? inset,
          padding: other.padding ?? padding,
          gap: other.gap ?? gap,
          actionSize: other.actionSize ?? actionSize,
          actionGap: other.actionGap ?? actionGap,
          labelStyle: labelStyle?.merge(other.labelStyle) ?? other.labelStyle,
          labelColor: other.labelColor ?? labelColor,
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
        );

  @override
  List<Object?> get props => [
    background,
    edgeColor,
    railColor,
    inset,
    padding,
    gap,
    actionSize,
    actionGap,
    labelStyle,
    labelColor,
    motions,
  ];
}
