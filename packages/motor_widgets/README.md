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
| `AnimatedSwitcher`, `AnimatedCrossFade` | `MotionSwitcher` | Presence springs, `MotionTransition` instead of a transition builder. |
| rivership `AnimatedSizeSwitcher` | `MotionSizeSwitcher` | `MotionSwitcher` inside `MotionSize`. |
| `transitionBuilder` | `MotionTransition` | `.fade`, `.scale`, `.slide`, `.translate`, `.blur`, `.blurFade`, composed with `+`. |

Every widget takes the parameters of the Flutter widget it replaces, except
that `duration` and `curve` become `motion` (and `reverseDuration` and
`switchOutCurve` become `exitMotion` on the switchers). Every widget also
takes `tickerRate` and `debugLabel`, like Motor's builders, so it shows up by
name in `motor_devtools`.

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
is still moving, because every property is its own track.

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
  transition: const .blurFade(),
  child: Text('$count', key: ValueKey(count)),
)
```

As with `AnimatedSwitcher`, a child that can't update the previous one (a
different type or key) switches. Each child has a presence value on its own
spring, from 0 (gone) to 1 (present): `motion` brings new children in,
`exitMotion` (usually a tighter spring) takes old ones out. A child whose key
comes back while it is still leaving turns around from where it is, with its
velocity, and keeps its state.

`MotionSizeSwitcher` adds a `MotionSize` around it, so the size springs to
the new child too:

```dart
MotionSizeSwitcher(
  transition: .fade + .scale(0.9),
  child: loading ? const Spinner() : Text(result),
)
```

### Transitions

A `MotionTransition` maps presence to how a child looks. Presence comes from
a spring, so it may overshoot past 1; a scale extrapolates, an opacity is
clamped.

| Transition | At presence 0 |
|---|---|
| `MotionTransition.fade` | invisible |
| `MotionTransition.scale(from)` | scaled to `from` |
| `MotionTransition.slide(offset)` | moved by `offset`, as a fraction of its size |
| `MotionTransition.translate(offset)` | moved by `offset` logical pixels |
| `MotionTransition.blur(sigma)` | blurred by `sigma` |
| `MotionTransition.blurFade(blur:, scale:, offset:)` | invisible, blurred, scaled and moved |

Transitions are values that compare by value. `a + b` wraps the child in
`b`, then in `a`:

```dart
const popover = MotionTransition.blurFade(blur: 6, scale: 0.9);
final sheet = MotionTransition.fade + const .slide(Offset(0, 0.2));
```

The blur is applied with `ImageFiltered`, which is turned off whenever the
blur is zero.

## Reduced motion

The widgets take whatever motion you pass. To honor reduced motion, pass
`Motion.instant()` (or a short spring) when
`MediaQuery.disableAnimationsOf(context)` is true, ideally once, in your
design system's motion tokens.
