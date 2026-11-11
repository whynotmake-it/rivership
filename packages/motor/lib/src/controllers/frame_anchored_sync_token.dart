import 'package:meta/meta.dart';

/// A sync token whose barrier releases at the frame that observes it rather
/// than at the latest participant's exact arrival.
///
/// Only the deprecated `SequenceMotionController` uses this, to keep its
/// legacy phase timing, where each phase starts on the frame after the
/// previous one ended.
@internal
final class FrameAnchoredSyncToken {}
