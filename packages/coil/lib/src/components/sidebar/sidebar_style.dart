import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/sidebar/sidebar_scaffold.dart'
    show CoilSidebarTrack;
import 'package:flutter/foundation.dart';
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
    this.drawerCornerRadius,
    this.drawerFallbackCornerRadius,
    this.drawerScrimColor,
    this.drawerShadows,
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
      drawerFallbackCornerRadius: CoilDrawerLook.fallbackCornerRadiusFor(
        defaultTargetPlatform,
      ),
      drawerShadows: CoilDrawerLook.edgeShadows(c),
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

  /// The page's corners while the phone drawer pushes it aside, in
  /// physical corners. Null follows the device's screen
  /// (`CoilScreenRadius`), so the page keeps the screen's shape as it
  /// moves; it squares up again once it covers the drawer.
  final BorderRadius? drawerCornerRadius;

  /// The page's corners while pushed aside where the screen's radius is
  /// unknown (web, desktop, a failed query, tests) and [drawerCornerRadius]
  /// is null. By default 40 on iOS and 24 on Android, square elsewhere
  /// (`CoilDrawerLook.fallbackCornerRadiusFor`).
  final BorderRadius? drawerFallbackCornerRadius;

  /// The scrim over the page once the drawer is fully open. Null, the
  /// default, is the drawer's for its reveal (`CoilDrawerLook.fallback`):
  /// the theme's `scrim` when it slides over the page, and
  /// `CoilDrawerLook.behindScrim` when it is revealed from behind: a
  /// lightening veil in light (white 35 %), a dim in dark (black 15 %),
  /// so the page recedes while its edge does the separating. The reveal is an
  /// adaptive choice the style can't see, so the default stays null.
  final Color? drawerScrimColor;

  /// The page's shadow while the drawer pushes it aside, faded in with the
  /// slide, with a hairline in the border color. By default the blurs of
  /// the theme's shadow step 8, centered on the page so they show along
  /// its side (`CoilDrawerLook.edgeShadows`).
  final List<BoxShadow>? drawerShadows;

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
          labelColor: CoilComponentStyle.mergeStates(
            labelColor,
            other.labelColor,
          ),
          drawerCornerRadius: other.drawerCornerRadius ?? drawerCornerRadius,
          drawerFallbackCornerRadius:
              other.drawerFallbackCornerRadius ?? drawerFallbackCornerRadius,
          drawerScrimColor: other.drawerScrimColor ?? drawerScrimColor,
          drawerShadows: other.drawerShadows ?? drawerShadows,
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
    drawerCornerRadius,
    drawerFallbackCornerRadius,
    drawerScrimColor,
    drawerShadows,
    motions,
  ];
}
