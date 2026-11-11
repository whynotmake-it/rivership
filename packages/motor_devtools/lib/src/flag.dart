/// Whether Motor DevTools are compiled into the app.
///
/// Build with `--dart-define=MOTOR_DEVTOOLS=false` to remove the tools and
/// motor's inspection hooks from the app entirely. `MotorDevTools` then
/// returns its child. `MotorTimeline` still draws, without look-ahead.
const bool kMotorDevTools = bool.fromEnvironment(
  'MOTOR_DEVTOOLS',
  defaultValue: true,
);
