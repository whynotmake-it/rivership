/// Turn-anchored scroll primitives built on Motor springs and Flutter slivers.
///
/// - [TurnScrollView] and [TurnScrollView.sectioned]: bidirectional
///   `Viewport(center:)` timeline with O(1) open at bottom or any
///   `initialItemId`, `0.0px`-shift prepend pagination, single-pass
///   [SliverTurnStage] turn pinning, and optional sticky section headers.
/// - [CustomTurnScrollView] and [SliverTurnList]: forward-only sliver viewport
///   for arbitrary Flutter slivers (`SliverAppBar`, `SliverMainAxisGroup`,
///   `SliverPersistentHeader`) with offscreen `scrollTo` and `scrollToBottom`.
/// - [TurnScrollController], [TurnScrollNotification], [TurnScrollScope],
///   [TurnScrollItem], [SliverTurnStage], and [TurnAnchorConfig].
/// - [TurnScrollFuture]: what `scrollTo` and `scrollToBottom` return, with
///   [TurnScrollFuture.ended] for when the motion looks finished, before the
///   spring settles.
///
/// @docImport 'package:turns/scroll.dart';
library;

export 'src/scroll/custom_turn_scroll_view.dart';
export 'src/scroll/sliver_turn_list.dart';
export 'src/scroll/turn_scroll_controller.dart';
export 'src/scroll/turn_scroll_motion.dart';
export 'src/scroll/turn_scroll_notification.dart';
export 'src/scroll/turn_scroll_view.dart';
export 'src/scroll/turn_sliver.dart';
