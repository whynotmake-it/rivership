import 'package:flutter/widgets.dart';

/// A [ScrollNotification] dispatched alongside Flutter's standard scroll
/// notifications whenever a `TurnScrollView` or `CustomTurnScrollView` updates
/// its scroll position.
///
/// Use with `NotificationListener<TurnScrollNotification>` for top-edge
/// pagination or scroll telemetry without handling negative `minScrollExtent`
/// values from bidirectional `Viewport(center:)` timelines.
class TurnScrollNotification extends ScrollNotification {
  /// Creates a turn scroll notification.
  TurnScrollNotification({
    required super.metrics,
    required super.context,
    required this.leadingExtent,
    required this.trailingExtent,
    required this.isProgrammatic,
    required this.isPinActive,
  });

  /// Distance in logical pixels before the current viewport (always `>= 0`,
  /// equivalent to `metrics.extentBefore`, transparently handling negative
  /// `minScrollExtent`).
  final double leadingExtent;

  /// Distance in logical pixels after the current viewport (always `>= 0`,
  /// equivalent to `metrics.extentAfter`).
  final double trailingExtent;

  /// Whether this scroll update is driven by programmatic navigation
  /// (`scrollTo`, `scrollToBottom`, pin animation, or initial positioning)
  /// rather than a user gesture.
  final bool isProgrammatic;

  /// Whether the enclosing view's `pinnedId` currently owns auto-pinning.
  final bool isPinActive;

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description
      ..add('leadingExtent: ${leadingExtent.toStringAsFixed(1)}')
      ..add('trailingExtent: ${trailingExtent.toStringAsFixed(1)}')
      ..add('isProgrammatic: $isProgrammatic')
      ..add('isPinActive: $isPinActive');
  }
}
