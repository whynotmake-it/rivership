import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'over_heroine.dart';

// ---------------------------------------------------------------------------
// ClippingShuttleBuilder
// ---------------------------------------------------------------------------

/// A [HeroineShuttleBuilder] that clips the flying hero to simulate occlusion
/// by [OverHeroine] widgets on both the source and destination routes.
///
/// During the flight the clipping region animates from the source occlusion
/// boundaries to the destination occlusion boundaries, so the hero never
/// appears as "popping out" from behind occluding elements.
///
/// ```dart
/// Heroine(
///   flightShuttleBuilder: ClippingShuttleBuilder(
///     inner: const FadeShuttleBuilder(),
///   ),
/// )
/// ```
class ClippingShuttleBuilder extends HeroineShuttleBuilder {
  /// Creates a [ClippingShuttleBuilder] that wraps [inner].
  const ClippingShuttleBuilder({
    required this.inner,
    super.curve,
  });

  /// The underlying shuttle builder whose output will be clipped.
  final HeroineShuttleBuilder inner;

  @override
  Widget call(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final child = inner(
      flightContext,
      animation,
      flightDirection,
      fromHeroContext,
      toHeroContext,
    );

    // 1. Find navigator as common coordinate-space ancestor (used only for
    //    the source rect and handoff size lerp — destination clip uses
    //    route-local space to avoid the slide animation offset).
    final navigator = Navigator.maybeOf(fromHeroContext);
    final navRenderObject = navigator?.context.findRenderObject();
    if (navRenderObject == null) return child;

    // 2. Get OverHeroine scopes.
    final srcScope = OverHeroineScope.of(fromHeroContext);
    final dstScope = OverHeroineScope.of(toHeroContext);

    // 3. Compute source clip — use source route's local space to avoid the
    //    slide offset that would be present in navigator space during a pop
    //    (when the source route is the one being animated out).
    final srcRoute = ModalRoute.of(fromHeroContext);
    final srcRouteRenderObj = srcRoute?.subtreeContext?.findRenderObject();
    if (srcRouteRenderObj == null) return child;

    final srcBox = fromHeroContext.findRenderObject() as RenderBox?;
    if (srcBox == null || !srcBox.hasSize) return child;
    final srcRouteLocalRect = MatrixUtils.transformRect(
      srcBox.getTransformTo(srcRouteRenderObj),
      Offset.zero & srcBox.size,
    );

    final srcOverlays = srcScope?.getRects(srcRouteRenderObj) ?? [];
    final srcClip = _visibleRect(srcOverlays, srcRouteLocalRect);

    final srcFrac = Rect.fromLTRB(
      srcClip.left / srcRouteLocalRect.width,
      srcClip.top / srcRouteLocalRect.height,
      srcClip.right / srcRouteLocalRect.width,
      srcClip.bottom / srcRouteLocalRect.height,
    );

    // For lerp we also need the source rect in navigator space at rest.
    // We can use the route-local position projected through the route subtree
    // context's transform (which at rest is the navigator-space position).
    final srcRect = MatrixUtils.transformRect(
      srcBox.getTransformTo(navRenderObject),
      Offset.zero & srcBox.size,
    );

    // 4. Compute destination clip in route-local space.
    final dstRoute = ModalRoute.of(toHeroContext);
    final dstRouteRenderObj = dstRoute?.subtreeContext?.findRenderObject();
    if (dstRouteRenderObj == null) return child;

    final toHeroBox = toHeroContext.findRenderObject() as RenderBox?;
    if (toHeroBox == null || !toHeroBox.hasSize) return child;
    final heroRouteLocalRect = MatrixUtils.transformRect(
      toHeroBox.getTransformTo(dstRouteRenderObj),
      Offset.zero & toHeroBox.size,
    );

    final dstOverlays = dstScope?.getRects(dstRouteRenderObj) ?? [];
    final dstClip = _visibleRect(dstOverlays, heroRouteLocalRect);

    final dstFrac = Rect.fromLTRB(
      dstClip.left / heroRouteLocalRect.width,
      dstClip.top / heroRouteLocalRect.height,
      dstClip.right / heroRouteLocalRect.width,
      dstClip.bottom / heroRouteLocalRect.height,
    );

    // 5. Get the handoff size from the spring prediction (for lerp).
    final flightInfo = Heroine.flightInfoOf(toHeroContext);
    if (flightInfo == null) return child;
    final handoffSize = flightInfo.handoffBoundingBox.size;

    // 6. Simple lerp animation from src to dst.
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = switch (flightDirection) {
          HeroFlightDirection.push => animation.value,
          HeroFlightDirection.pop => 1 - animation.value,
        };

        final size = Size.lerp(srcRect.size, handoffSize, t)!;
        final frac = Rect.lerp(srcFrac, dstFrac, t)!;

        final clipRect = Rect.fromLTRB(
          frac.left * size.width,
          frac.top * size.height,
          frac.right * size.width,
          frac.bottom * size.height,
        );

        return ClipRect(clipper: _RectClipper(clipRect), child: child);
      },
    );
  }

  @override
  List<Object?> get props => [inner, curve];
}

// ---------------------------------------------------------------------------
// Helper: visible rect calculation
// ---------------------------------------------------------------------------

/// Given a list of [OverHeroine] rectangles (in the same coordinate space as
/// [heroRect]), returns the visible portion of [heroRect] after applying
/// each occlusion boundary in order.
///
/// Each occlusion is defined by a [KeepDir]:
/// - [KeepDir.bottom] — occludes from above; keep content *below* the occluder.
/// - [KeepDir.top]    — occludes from below; keep content *above* the occluder.
/// - [KeepDir.left]   — occludes from the right; keep content *left* of it.
/// - [KeepDir.right]  — occludes from the left; keep content *right* of it.
Rect _visibleRect(List<(Rect overRect, KeepDir keepDir)> overlays, Rect heroRect) {
  // Start with the full hero rect in local coordinates.
  var visible = Offset.zero & heroRect.size;

  for (final (overRect, keepDir) in overlays) {
    // Skip OverHeroines that don't intersect the hero at all.
    // An OverHeroine that doesn't overlap the hero shouldn't affect its
    // visible region, regardless of keepDir.
    if (!heroRect.overlaps(overRect)) continue;

    // Convert the OverHeroine's rect to hero-local coordinates.
    final localOver = Rect.fromLTRB(
      overRect.left - heroRect.left,
      overRect.top - heroRect.top,
      overRect.right - heroRect.left,
      overRect.bottom - heroRect.top,
    );

    visible = switch (keepDir) {
      // Keep the part below the OverHeroine's bottom edge.
      KeepDir.bottom => Rect.fromLTWH(
          visible.left,
          visible.top + _clampDelta(localOver.bottom - visible.top),
          visible.width,
          visible.height - _clampDelta(localOver.bottom - visible.top),
        ),
      // Keep the part above the OverHeroine's top edge.
      KeepDir.top => Rect.fromLTWH(
          visible.left,
          visible.top,
          visible.width,
          _clampDelta(localOver.top - visible.top),
        ),
      // Keep the part left of the OverHeroine's left edge.
      KeepDir.left => Rect.fromLTWH(
          visible.left,
          visible.top,
          _clampDelta(localOver.left - visible.left),
          visible.height,
        ),
      // Keep the part right of the OverHeroine's right edge.
      KeepDir.right => Rect.fromLTWH(
          visible.left + _clampDelta(localOver.right - visible.left),
          visible.top,
          visible.width - _clampDelta(localOver.right - visible.left),
          visible.height,
        ),
    };
  }

  return visible;
}

/// Returns [value] clamped to [0, double.infinity).
///
/// This ensures that when an OverHeroine is far away from the hero the clip
/// rect does not go negative (which would expand the visible area).
double _clampDelta(double value) => value.clamp(0, double.infinity);

// ---------------------------------------------------------------------------
// RectClipper
// ---------------------------------------------------------------------------

class _RectClipper extends CustomClipper<Rect> {
  const _RectClipper(this.rect);

  final Rect rect;

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(_RectClipper oldClipper) => oldClipper.rect != rect;
}
