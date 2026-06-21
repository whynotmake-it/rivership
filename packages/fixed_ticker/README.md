# Fixed Ticker

[![Pub Version](https://img.shields.io/pub/v/fixed_ticker)](https://pub.dev/packages/fixed_ticker)
[![Coverage](./coverage.svg)](./test/)
[![lints by lintervention][lintervention_badge]][lintervention_link]
[![Bluesky](https://img.shields.io/badge/Bluesky-0285FF?logo=bluesky&logoColor=fff)](https://bsky.app/profile/i.madethese.works)

`FixedTicker` is a Flutter `Ticker` that can tick at a fixed rate instead of every display vsync.

It is designed as a drop-in replacement: keep your existing `AnimationController` setup, choose fixed timing when you want it, and switch back to normal vsync behavior whenever you need full display-rate animation.

## Why?

Flutter's `Ticker` is the right default for most animations: it tracks the display refresh rate and gives you the smoothest result the device can show.

Sometimes that is more work than the animation needs. A background shimmer, decorative pulse, loading indicator, or low-priority progress animation often looks fine at 10, 15, or 30 fps. If it is driven by a normal `Ticker`, though, it still wakes the app on every display frame, including 120 Hz screens.

`FixedTicker` lets those animations opt into a lower tick rate while keeping the same `AnimationController` workflow. Use vsync where full fidelity matters, and use a fixed rate where saving frame work matters more.

## Features

- Drop-in ticker provider mixins for `AnimationController`
- Fixed rates from frames-per-second values or explicit intervals
- Seamless switching between fixed-rate and normal vsync ticking
- `TickerRateScope` for subtree-wide rate control
- Testing utilities for fixed-rate animations

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  fixed_ticker: ^0.1.0
```

## Usage

### Basic: swap the mixin

The simplest way to use `FixedTicker` is to replace your ticker provider mixin. Everything else stays the same: your `AnimationController`, your `AnimatedBuilder`, and your animation lifecycle.

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

By default, `tickerRate` reads the nearest `TickerRateScope` and falls back to `TickerRate.vsync()`. In other words, a fixed ticker behaves like a normal `Ticker` until you opt into a fixed rate.

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

The animation continues without recreating the ticker or losing animation state.

You can also return `TickerRate.vsync()` to switch back to normal vsync-driven ticking, or return `TickerRate.interval(...)` / `TickerRate.fps(...)` to switch into fixed-rate mode.

### Subtree-wide rate control with TickerRateScope

Instead of configuring each widget individually, wrap a subtree in `TickerRateScope` to set the tick rate for all animations underneath:

```dart
TickerRateScope(
  rate: TickerRate.fps(30),
  child: MyAnimatedWidget(),
)
```

Any widget using `SingleFixedTickerProviderStateMixin` or `FixedTickerProviderStateMixin` automatically picks up the rate from the nearest scope. You do not need to override `tickerRate` or call `updateTickerRate()`.

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

**Precedence:** an overridden `tickerRate` getter wins over `TickerRateScope`. If neither is set, the ticker runs at normal vsync.

`TickerRate` constructors:

- `TickerRate.vsync()`: normal vsync refresh rate
- `TickerRate.interval(Duration(...))`: fixed duration between ticks
- `TickerRate.fps(30)`: fixed frames per second

`TickerRate` is a sealed class, so you can use exhaustive pattern matching:

```dart
final label = switch (rate) {
  VsyncTickerRate() => 'vsync',
  FixedTickerRate(:final interval) => '${interval.inMilliseconds}ms',
};
```

### Multiple controllers

Need more than one `AnimationController`? Use `FixedTickerProviderStateMixin`, the multi-ticker variant:

```dart
class _MyState extends State<MyWidget>
    with FixedTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;

  @override
  TickerRate get tickerRate => TickerRate.fps(30);
  // Both controllers tick at the mixin's tickerRate.
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

`FixedTicker` works in widget tests with the normal `tester.pump()` flow. In fixed-rate mode, timer ticks schedule frame callbacks, so tests need to pump frames instead of only advancing timers.

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

`pumpAndSettleFixedTickers` is a superset of `pumpAndSettle`: it waits for both scheduled frames and active fixed tickers to stop.

## How it works

`FixedTicker` extends Flutter's `Ticker` and overrides `scheduleTick` / `unscheduleTick` to use `Timer.periodic` as a rate limiter when an `interval` is set. When `interval` is `null`, it delegates entirely to the parent and behaves like a normal `Ticker`.

In fixed-rate mode, the periodic timer does not compute elapsed time itself. Each timer tick schedules a frame callback through the parent `Ticker`, and the parent computes elapsed from Flutter's monotonic frame timestamp. This means:

- **No mode-switch clock drift:** fixed and vsync modes use the same frame timestamp clock
- **`TickerMode` works seamlessly:** wrapping a subtree in `TickerMode(enabled: false)` mutes `FixedTicker` the same way it mutes a normal `Ticker`. The timer stops, but elapsed time keeps advancing on the frame clock, so animations may jump ahead when re-enabled.
- **Tests follow Flutter frame semantics:** use `tester.pump()` to advance timers and deliver the scheduled frame callbacks

## Known limitations

- **`pumpAndSettle()`** does not work with fixed-rate tickers. Use `pumpAndSettleFixedTickers()` from `package:fixed_ticker/testing.dart`.
- **Timer jitter:** `Timer.periodic` does not guarantee exact intervals under load. Fixed-rate ticks can be delayed or coalesced before the next frame callback is delivered.
- **Sub-interval durations:** if your animation duration is shorter than the tick interval, it completes on the first tick.
- **Not a replacement for every ticker:** keep normal vsync for interactions and foreground motion where maximum smoothness matters.

---

[lintervention_link]: https://github.com/whynotmake-it/lintervention
[lintervention_badge]: https://img.shields.io/badge/lints_by-lintervention-3A5A40
