# Fixed Ticker

A drop-in `Ticker` replacement that optionally runs at a fixed frame rate using `Timer.periodic` instead of vsync.

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
  @override
  TickerRate get tickerRate => TickerRate.fps(30);
  // ...
}
```

By default, `tickerRate` returns the nearest `TickerRateScope` rate, falling back to `TickerRate.vsync()`, which means the ticker behaves exactly like a normal `Ticker` — full vsync refresh rate. Override it with a `TickerRate` to opt into fixed-rate ticking.

### Changing the rate at runtime

The rate is mutable. Update whatever state drives `tickerRate` and call `updateTickerRate()`:

```dart
class _MyState extends State<MyWidget>
    with SingleFixedTickerProviderStateMixin {
  int _fps = 30;

  @override
  TickerRate get tickerRate => TickerRate.fps(_fps);

  void _onFpsChanged(int fps) {
    setState(() => _fps = fps);
    updateTickerRate(); // applies the new rate immediately
  }
  // ...
}
```

The animation continues seamlessly — no ticker recreation, no lost animation state.

You can also return `TickerRate.vsync()` to switch back to normal vsync-driven ticking, or return `TickerRate.interval(...)` / `TickerRate.fps(...)` to switch into fixed-rate mode.

### Subtree-wide rate control with TickerRateScope

Instead of configuring each widget individually, wrap a subtree in `TickerRateScope` to set the tick rate for all animations underneath:

```dart
TickerRateScope(
  rate: TickerRate.fps(30),
  child: MyAnimatedWidget(),
)
```

Any widget using `SingleFixedTickerProviderStateMixin` or `FixedTickerProviderStateMixin` will automatically pick up the rate from the nearest scope — no need to override `tickerRate` or call `updateTickerRate()`.

The rate syncs automatically when the scope changes:

```dart
TickerRateScope(
  rate: _useFixedRate
      ? TickerRate.fps(_fps)
      : const TickerRate.vsync(),
  child: const MyAnimatedWidget(),
)
```

You can also override `tickerRate` in a specific widget to ignore the scope:

```dart
class _MyState extends State<MyWidget>
    with SingleFixedTickerProviderStateMixin {
  @override
  TickerRate get tickerRate => TickerRate.fps(10); // ignores scope
}
```

**Precedence:** an overridden `tickerRate` getter always wins over `TickerRateScope`. If neither is set, the ticker runs at normal vsync.

`TickerRate` constructors:

- `TickerRate.vsync()` — normal vsync refresh rate
- `TickerRate.interval(Duration(...))` — fixed duration between ticks
- `TickerRate.fps(30)` — fixed frames per second

`TickerRate` is a sealed class, so you can use exhaustive pattern matching:

```dart
final label = switch (rate) {
  VsyncTickerRate() => 'vsync',
  FixedTickerRate(:final interval) => '${interval.inMilliseconds}ms',
};
```

### Multiple controllers

Need more than one `AnimationController`? Use `FixedTickerProviderStateMixin` (the multi-ticker variant):

```dart
class _MyState extends State<MyWidget>
    with FixedTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;

  @override
  TickerRate get tickerRate => TickerRate.fps(30);
  // Both tick at the mixin's tickerRate
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
// ...later...
ticker.interval = const Duration(milliseconds: 100); // switch to 10fps
// ...
ticker.stop();
ticker.dispose();
```

## Testing

`FixedTicker` works in widget tests with the normal `tester.pump()` flow. In fixed-rate mode, timer ticks schedule frame callbacks, so tests need to pump frames rather than only advancing timers.

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

`FixedTicker` extends Flutter's `Ticker` and overrides `scheduleTick` / `unscheduleTick` to use `Timer.periodic` as a rate limiter when an `interval` is set. When `interval` is `null`, it delegates entirely to the parent — behaving like a normal `Ticker`.

In fixed-rate mode, the periodic timer does not compute elapsed time itself. Each timer tick schedules a frame callback through the parent `Ticker`, and the parent computes elapsed from Flutter's monotonic frame timestamp. This means:

- **No mode-switch clock drift** — fixed and vsync modes use the same frame timestamp clock
- **`TickerMode` works seamlessly** — wrapping a subtree in `TickerMode(enabled: false)` mutes `FixedTicker` the same way it mutes a normal `Ticker`. The timer stops but elapsed time keeps advancing on the frame clock, so animations may jump ahead when re-enabled.
- **Tests follow Flutter frame semantics** — use `tester.pump()` to advance timers and deliver the scheduled frame callbacks

## Known limitations

- **`pumpAndSettle()`** doesn't work with fixed-rate tickers — use `pumpAndSettleFixedTickers()` from `package:fixed_ticker/testing.dart`
- **Timer jitter** — `Timer.periodic` doesn't guarantee exact intervals under load. Fixed-rate ticks can be delayed or coalesced before the next frame callback is delivered.
- **Sub-interval durations** — if your animation duration is shorter than the tick interval, it completes on the first tick.
