import 'package:motor/motor.dart';

/// Default Motor spring motion used by `TurnScrollView` and
/// `CustomTurnScrollView` for turn pinning, `jumpToBottom`, and `scrollTo`.
const Motion defaultTurnPinMotion = Motion.smoothSpring(
  duration: Duration(milliseconds: 360),
);
