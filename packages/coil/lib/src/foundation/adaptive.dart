import 'package:coil/src/foundation/metrics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// How an overlay that lists choices is shown.
enum CoilPresentation {
  /// Anchored to its trigger.
  popover,

  /// A bottom sheet with touch-sized rows.
  sheet,
}

/// Pins adaptive decisions for a subtree: the size [tier], the size step
/// ([size]), the overlay [presentation] and the [platform] whose
/// conventions apply.
///
/// The one adaptive context in coil. Unset values inherit from the nearest
/// ancestor scope; without one, the tier comes from the theme and then the
/// platform, the size is [CoilSize.regular], and the presentation is decided
/// per overlay when it opens (`CoilAdaptivePopup.presentationOf`).
///
/// It is an [InheritedTheme], so overlays opened below it keep its pins.
///
/// ```dart
/// CoilAdaptiveScope(size: .compact, child: Toolbar())
/// ```
class CoilAdaptiveScope extends StatelessWidget {
  /// Creates an adaptive scope.
  const CoilAdaptiveScope({
    required this.child,
    super.key,
    this.tier,
    this.size,
    this.presentation,
    this.platform,
  });

  /// The tier for this subtree, or null to inherit.
  final CoilTier? tier;

  /// The size step for this subtree, or null to inherit.
  final CoilSize? size;

  /// The presentation of every choice overlay in this subtree, or null to
  /// inherit (and, at the top, to decide per overlay).
  final CoilPresentation? presentation;

  /// The platform whose conventions this subtree follows, or null to
  /// inherit (and, at the top, to follow [defaultTargetPlatform]).
  ///
  /// Read it with `CoilTheme.platformOf`. It latches the tier like the real
  /// platform does, and decides the conventions coil follows per platform:
  /// shortcut modifiers (⌘ or Ctrl), the iOS back swipe over the start
  /// drawer, Android's long-press tooltips, the drawer's fallback screen
  /// corners and haptics. For a subtree that stands in for another device,
  /// such as a phone preview in a desktop window. Flutter's own platform
  /// reads (scroll physics, text editing) don't see it: pair it with a
  /// `ScrollConfiguration` for those.
  final TargetPlatform? platform;

  /// The subtree.
  final Widget child;

  /// The nearest pinned tier, if any.
  static CoilTier? maybeTierOf(BuildContext context) => _of(context)?.tier;

  /// The nearest pinned size step, if any.
  static CoilSize? maybeSizeOf(BuildContext context) => _of(context)?.size;

  /// The nearest pinned presentation, if any.
  static CoilPresentation? maybePresentationOf(BuildContext context) =>
      _of(context)?.presentation;

  /// The nearest pinned platform, if any.
  static TargetPlatform? maybePlatformOf(BuildContext context) =>
      _of(context)?.platform;

  static _CoilAdaptiveData? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CoilAdaptiveData>();

  @override
  Widget build(BuildContext context) {
    final parent = _of(context);
    return _CoilAdaptiveData(
      tier: tier ?? parent?.tier,
      size: size ?? parent?.size,
      presentation: presentation ?? parent?.presentation,
      platform: platform ?? parent?.platform,
      child: child,
    );
  }
}

class _CoilAdaptiveData extends InheritedTheme {
  const _CoilAdaptiveData({
    required this.tier,
    required this.size,
    required this.presentation,
    required this.platform,
    required super.child,
  });

  final CoilTier? tier;
  final CoilSize? size;
  final CoilPresentation? presentation;
  final TargetPlatform? platform;

  // Overlays (popovers, sheets) carry the opener's pins.
  @override
  Widget wrap(BuildContext context, Widget child) => CoilAdaptiveScope(
    tier: tier,
    size: size,
    presentation: presentation,
    platform: platform,
    child: child,
  );

  @override
  bool updateShouldNotify(_CoilAdaptiveData oldWidget) =>
      tier != oldWidget.tier ||
      size != oldWidget.size ||
      presentation != oldWidget.presentation ||
      platform != oldWidget.platform;
}
