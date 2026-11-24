import 'package:flutter/widgets.dart';

/// [OverlayPortal.overlayChildLayoutBuilder], minus the overlay child while
/// [child] is offstage.
///
/// An [Overlay] stops laying out the entries a fully opaque one covers, but
/// a shown layout-builder overlay child still lays itself out every frame,
/// with the overlay's size from its last layout. When the overlay resizes
/// meanwhile (the window does), Flutter's check that the two sizes agree
/// (`size == theater.size`) fails. So while the anchor is offstage, which
/// the overlay marks by turning its tickers off, the portal shows nothing;
/// the layout builder comes back, laid out at the current size, once the
/// anchor is onstage again.
///
/// Internal to Coil; not exported.
class AnchoredOverlayPortal extends StatelessWidget {
  /// Creates a portal showing [overlayChildBuilder]'s widget while
  /// [controller] shows it and [child] is onstage.
  const AnchoredOverlayPortal({
    required this.controller,
    required this.overlayChildBuilder,
    required this.child,
    super.key,
  });

  /// Shows and hides the overlay child.
  final OverlayPortalController controller;

  /// Builds the overlay child from the anchor's size and transform.
  final OverlayChildLayoutBuilder overlayChildBuilder;

  /// The anchor.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (TickerMode.valuesOf(context).enabled) {
      return OverlayPortal.overlayChildLayoutBuilder(
        controller: controller,
        overlayChildBuilder: overlayChildBuilder,
        child: child,
      );
    }
    // The same widget type in the same place, so [child] keeps its state.
    return OverlayPortal(
      controller: controller,
      overlayChildBuilder: _nothing,
      child: child,
    );
  }

  static Widget _nothing(BuildContext context) => const SizedBox.shrink();
}
