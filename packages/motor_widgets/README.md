# Motor Widgets

Spring-driven versions of Flutter's implicit animation widgets, built on
[Motor](../motor).

Flutter's `AnimatedContainer`, `AnimatedSwitcher`, `AnimatedSize` and friends
run on an `AnimationController` with a duration and a curve. When their value
changes mid-flight, they start a new curve from where they are, at zero
velocity, so a quick series of changes stutters. They can't use springs.

The widgets here take a Motor `motion` instead. When their value changes
mid-flight, they head for the new value with the velocity they already have.
There is no `AnimationController`, `Tween` or curve in this package.

## Flutter widget → Motor widget

| Flutter | Motor widgets | Notes |
|---|---|---|
| `AnimatedOpacity` | `MotionOpacity` | The shown opacity stays within 0 and 1 while the spring overshoots. |
| `AnimatedAlign` | `MotionAlign` | `alignment`, `widthFactor` and `heightFactor` each have their own track. |
| `AnimatedPadding` | `MotionPadding` | Allows the negative padding a spring overshoots into, through `PaddingExtended`. |
| `AnimatedPositioned` | `MotionPositioned` | Also `MotionPositioned.fromRect`. |
| `AnimatedScale` | `MotionScale` | |
| `AnimatedRotation` | `MotionRotation` | `turns`, like `AnimatedRotation`. |
| `AnimatedSlide` | `MotionSlide` | `offset` is a fraction of the child's size. |
| `AnimatedContainer` | `MotionContainer` | One track per property; see below for what animates. |
| `AnimatedSize` | `MotionSize` | A render object that springs toward its child's size. |
| `AnimatedSwitcher` | `MotionSwitcher` | Same `transitionBuilder` and `layoutBuilder`, fed by a presence spring per child. |
| rivership `AnimatedSizeSwitcher` | `MotionSizeSwitcher` | `MotionSwitcher` inside `MotionSize`. |

Every widget takes the parameters of the Flutter widget it replaces, except
that `duration` and `curve` become `motion` (and `reverseDuration` and
`switchOutCurve` become `exitMotion` on the switchers). Every widget also
takes `tickerRate` and `debugLabel`, like Motor's builders, so it shows up by
name in `motor_devtools`.

## One motion per property: `motions`

Widgets that animate several properties (`MotionContainer`, `MotionAlign`,
`MotionPositioned`) play one Motor `Track` per property. Each widget
declares its tracks on its own track class (`MotionContainerTrack`,
`MotionAlignTrack`, `MotionPositionedTrack`). `motion` is the default for
every track, and `motions` overrides it for single tracks:

```dart
MotionContainer(
  motion: const .smoothSpring(),
  motions: {
    .color: const .snappySpring(),
    .padding: const .bouncySpring(),
  },
  color: selected ? Colors.indigo : Colors.grey,
  padding: .all(selected ? 24 : 12),
  child: child,
)
```

The keys are typed per widget (`Map<MotionContainerTrack<Object>, Motion>`),
so a track of another widget doesn't compile. Because the tracks are static
fields of that class, dot shorthand finds them: `.color` means
`MotionContainerTrack.color`. Motions compare by value, so a map literal
rebuilt in every `build` redirects nothing; only a track whose motion
actually changes is redirected. The tracks are real `Track`s with a
`debugLabel` (`MotionContainer.color`), so `motor_devtools` shows them by
name.

Widgets with a single value (`MotionOpacity`, `MotionScale`, `MotionSlide`,
…) just take `motion`.

## Examples

### Implicit animations

```dart
MotionOpacity(
  opacity: visible ? 1 : 0,
  motion: const .smoothSpring(),
  child: const Text('Hello'),
)
```

```dart
MotionContainer(
  motion: const .bouncySpring(),
  width: expanded ? 240 : 120,
  padding: .all(expanded ? 24 : 12),
  decoration: BoxDecoration(
    color: expanded ? Colors.indigo : Colors.teal,
    borderRadius: .circular(expanded ? 32 : 12),
  ),
  child: const FlutterLogo(),
)
```

Tap fast and the container never stutters: each property heads for its new
value with the velocity it has. Changing the color doesn't touch a width that
is still moving, because every property is its own track
(`MotionContainerTrack.color`, `.minWidth`, …).

`MotionContainer` animates `alignment`, `padding`, `margin`, `color`,
`width`, `height`, `constraints`, `transform` and `transformAlignment`, and
the `color` and `borderRadius` of a `BoxDecoration` in `decoration` or
`foregroundDecoration`. A decoration's border, shadows, gradient and image,
other kinds of `Decoration`, and unbounded (infinite) constraints change at
once. As in `AnimatedContainer`, a property that goes from null to a value
starts there.

### Size

```dart
MotionSize(
  motion: const .smoothSpring(),
  alignment: .topCenter,
  child: expanded ? const LongText() : const ShortText(),
)
```

### Switching children

```dart
MotionSwitcher(
  motion: const .smoothSpring(),
  exitMotion: const .snappySpring(duration: Duration(milliseconds: 300)),
  transitionBuilder: (child, animation) =>
      ScaleTransition(scale: animation, child: child),
  child: Text('$count', key: ValueKey(count)),
)
```

`MotionSwitcher` has `AnimatedSwitcher`'s API: the same `transitionBuilder`
(defaulting to `AnimatedSwitcher.defaultTransitionBuilder`, a fade) and
`layoutBuilder`. As with `AnimatedSwitcher`, a child that can't update the
previous one (a different type or key) switches.

The `Animation<double>` each child gets is its presence spring (a Motor
`SingleMotionController`): `motion` takes new children from 0 to 1,
`exitMotion` (usually a tighter spring) takes old ones to 0. Its status is
`forward` while entering and `reverse` while leaving. A child whose key comes
back while it is still leaving turns around from where it is, with its
velocity, and keeps its state.

The animation is the spring's raw value, so a bouncy spring overshoots past
1 (or below 0 on the way out). Flutter's transitions handle that:
`FadeTransition` clamps the opacity it paints, and `ScaleTransition` or
`SlideTransition` overshoot, which is the bounce. Only code that passes
`animation.value` to a widget that asserts its range, such as `Opacity`,
needs to clamp it.

`MotionSizeSwitcher` adds a `MotionSize` around it, so the size springs to
the new child too:

```dart
MotionSizeSwitcher(
  child: loading ? const Spinner() : Text(result),
)
```

## Reduced motion

The widgets take whatever motion you pass. To honor reduced motion, pass
`Motion.instant()` (or a short spring) when
`MediaQuery.disableAnimationsOf(context)` is true, ideally once, in your
design system's motion tokens.
