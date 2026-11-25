## 0.1.0-dev.0

First preview of `motor_devtools`. Works with [Motor](https://pub.dev/packages/motor) 2.0 pre-releases.

- **FEAT**: Add `MotorDevTools`, a draggable floating bubble that opens a live list of every Motor controller in your app.
- **FEAT**: Pause, replay, scrub, and slow down individual controllers or `MotorInspectionScope` groups without changing Flutter's global `timeDilation`.
- **FEAT**: Live motion override and spring duration × bounce tuner with copyable Dart code.
- **FEAT**: Add `MotorTimeline`, a read-only embeddable timeline widget for docs and demos.
- **FEAT**: Disabled in release builds by default; pass `--dart-define=MOTOR_DEVTOOLS=false` to strip the tools from a build.
