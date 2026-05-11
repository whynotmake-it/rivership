# Fixed Ticker

A drop-in replacement for Flutter's `Ticker` that runs at a fixed frame rate using `Timer.periodic` instead of vsync.

## Why?

In Flutter, every active `Ticker` — even one driving a subtle, low-priority animation — causes the entire app to repaint at the display's full refresh rate (60fps, 120fps, or higher). That's a lot of GPU work for an animation that might not need it.

`FixedTicker` lets you choose your own frame rate. A background shimmer at 10fps? A progress indicator at 30fps? No problem. Your animation still runs smoothly, but the rest of your app isn't forced to keep up.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  fixed_ticker: ^0.1.0
```

## Usage

### Basic: swap the mixin

The simplest way to use `FixedTicker` is to replace your ticker provider mixin. Everything else stays the same — your `AnimationController`, your `AnimatedBuilder`, all of it.

```dart
// Before: every frame, full refresh rate
class _MyState extends State<MyWidget>
    with SingleTickerProviderStateMixin {
  // ...
}

// After: fixed 30fps
class _MyState extends State<MyWidget>
    with SingleFixedTickerProviderStateMixin {
  // ...
}
```

That's it. Your `AnimationController` now ticks at ~30fps by default.

### Custom frame rate

Override `tickerInterval` to pick your own rate:

```dart
class _MyState extends State<MyWidget>
    with SingleFixedTickerProviderStateMixin {
  @override
  Duration get tickerInterval =>
      const Duration(milliseconds: 100); // 10fps

  // ...
}
```

The animation duration stays the same regardless of the interval — a 1-second animation still takes 1 second, just with fewer frames.

### Multiple controllers

Need more than one `AnimationController`? Use `FixedTickerProviderStateMixin` (the multi-ticker variant):

```dart
class _MyState extends State<MyWidget>
    with FixedTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;

  // Both tick at the mixin's tickerInterval
}
```

### Using FixedTicker directly

You can also create a `FixedTicker` yourself if you're not using the mixins:

```dart
final ticker = FixedTicker(
  (elapsed) => print('Elapsed: $elapsed'),
  interval: const Duration(milliseconds: 50), // 20fps
);
ticker.start();
// ...
ticker.stop();
ticker.dispose();
```

## Testing

`FixedTicker` works in both `fakeAsync` and `testWidgets` with zero setup. The `clock.now()` calls are automatically faked by Flutter's test infrastructure.

One thing to watch out for: **`tester.pumpAndSettle()` doesn't know about `FixedTicker`**. It only checks for scheduled frames, and `FixedTicker` uses `Timer.periodic` instead. Import the testing utilities and use `pumpAndSettleFixedTickers()` instead:

```dart
import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:fixed_ticker/testing.dart';

testWidgets('my animation completes', (tester) async {
  await tester.pumpWidget(MyAnimatedWidget());
  await tester.pumpAndSettleFixedTickers();
  // Animation has completed
});
```

`pumpAndSettleFixedTickers` is a superset of `pumpAndSettle` — it waits for both scheduled frames *and* active fixed tickers to stop.

## How it works

`FixedTicker` extends Flutter's `Ticker` and overrides `scheduleTick` / `unscheduleTick` to use `Timer.periodic` instead of `SchedulerBinding.scheduleFrameCallback`.

Elapsed time is always computed as `clock.now() - startTime`, never by adding up intervals. This means:

- **No drift** — each tick reports the true elapsed time, not an approximation
- **Muting works correctly** — when a `TickerMode` ancestor disables ticking, the timer stops but elapsed time keeps counting (matching normal `Ticker` behavior)
- **Tests are deterministic** — `clock.now()` is faked automatically

## Known limitations

- **`pumpAndSettle()`** doesn't work — use `pumpAndSettleFixedTickers()` from `package:fixed_ticker/testing.dart`
- **Timer jitter** — `Timer.periodic` doesn't guarantee exact intervals under load. Elapsed values are always accurate, but frame spacing may vary slightly.
- **Sub-interval durations** — if your animation duration is shorter than the tick interval, it completes on the first tick.
