import 'package:flutter/material.dart';

/// Where to redirect taps that land in the hit slop area.
enum TapRedirectionPolicy {
  /// Redirect taps that land in the hit slop area to the center of the child.
  center,

  /// Redirect taps that land in the hit slop area to the nearest edge of the
  /// child.
  nearestEdge,
}

/// A widget that adds hit slop to its child.
///
/// Internally, this uses a [TapRegion] to montior any taps outside this widget.
class HitSlop extends SingleChildRenderObjectWidget {
  const HitSlop({
    required this.hitSlop,
    required this.child,
    super.key,
  });

  final EdgeInsetsGeometry hitSlop;

  final Widget child;
}
