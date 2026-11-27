import 'package:motor/motor.dart';

/// Default Motor spring motion used by `TurnScrollView` and
/// `CustomTurnScrollView` for automatic and programmatic scroll flights
/// (`pinnedId`, `scrollTo`, and `jumpToBottom`).
///
/// This controls only automatic scroll animations and never affects user drag
/// `physics`.
const Motion defaultTurnAutoScrollMotion = Motion.smoothSpring(
  duration: Duration(milliseconds: 360),
);
