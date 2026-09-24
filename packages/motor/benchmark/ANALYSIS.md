# Analysis: Motor vs AnimationController

Measured on a Linux cloud VM (8 vCPU Intel Xeon) with Flutter 3.44.1 /
Dart 3.12.1. Timings come from AOT release builds (`melos run benchmark`), and
memory from one AOT profile build (`BENCH_BUILD=profile`).

- **Baseline:** `motor/2.0` at `3cc5de9`, before the optimization pass
  (three invocations of 7 runs each).
- **Final:** `motor/2.0` at `3e3e6d1`, after it (five invocations).
  Earlier final runs at `af172d6` and `e1869d9` gave the same animation
  ratios within noise.

The optimization pass changed four things:
- `f5fb928`/`43ea1d9`: segment ends are found as time passes, not searched
  up front.
- `3acafda`: velocities are computed only when read, and dimensions that
  share a curve evaluate it once per frame.
- `5fc7a94`/`38fc0ce`/`737d99b`: fewer allocations on start and per frame,
  and less memory retained per track.
- `ffd0c3c`/`3e3e6d1`: velocity samples go into a preallocated buffer, and
  `set` does less bookkeeping.

`4477802` also fixes `CurveSimulation.dx`, which reported 4× the real
velocity.

Tables show motor ÷ Flutter. Below 1× means motor is cheaper. The drag and
velocity tracking scenarios were added after the baseline, so they have
only final numbers.

## Summary

- **Per frame, motor matches `AnimationController` once there is more than
  one value.**
  - 10 to 1000 values on one controller cost 0.89× to 1.06× the equivalent
    `AnimationController`s, for curves and springs alike (baseline: 1.15×
    to 1.81×).
  - A single value still costs about 1.8×. That's a fixed overhead of about
    0.2 µs per controller per frame.
- **Multi-dimensional values:**
  - Springs are at parity with one controller per dimension: 0.94× to
    1.39×.
  - Curves cost 1.8× to 2.15× what one controller plus a tween costs
    (baseline: 2.8× to 4.5×).
- **Starting and retargeting got much cheaper.** Spring starts are 5× to
  9.5× faster than the baseline, spring retargets 5× to 10×, and curve
  starts 1.7× to 3.4×.
  - Starting now costs 2.1× to 4.2× the Flutter side, and retargeting a
    spring 1.4× to 3.1× (baseline: 5× to 39× and 9× to 25×).
  - 1000 springs start in 0.85 ms versus 0.21 ms, and one spring retargets
    in 1.4 µs versus 0.5 µs.
- **Following a drag with velocity tracking (on by default) is close to the
  Flutter equivalent.**
  - Tracking adds 0.02 to 0.08 µs per value per sample, about what a
    Flutter `VelocityTracker` adds (0.05 to 0.08 µs).
  - A tracked drag of 250 values costs 1.2× to 1.5× the
    `AnimationController`s plus `VelocityTracker`s, and a single value
    about 2× (0.31 µs versus 0.13 µs per frame).
  - The fling handoff costs 0.7× to 1.4×.
  - What's left of the gap is `set` itself: about 0.1 µs per track of
    bookkeeping even with tracking off.
- **Value reads:**
  - Curve tracks read faster than `CurvedAnimation.value` (0.6× to 0.7×).
  - Spring tracks read about 1.8× slower than `AnimationController.value`
    (about 26 versus 14 ns).
- **Memory:**
  - Motor allocates less per frame at scale: 0.25× (springs) and 0.31×
    (curves) of the Flutter side at 1000 values, which is 105 and 121 B
    per track.
  - Tracking retains about 0.5 KB per track, versus about 1.5 KB per
    `VelocityTracker`.
  - Each track retains about 1.5 KB (baseline: 1.8 KB), still about twice
    an `AnimationController` at scale.

## Method

**What is compared.** Each scenario pairs a motor setup with the
`AnimationController` code you would write for the same motion. After
warmup, both sides must read the same values; every run checks this and fails
otherwise.

| Scenario | Motor | Flutter equivalent |
|---|---|---|
| Curve 1D ×N | 1 `TrackController`, N `CurvedMotion` tracks | N `AnimationController` + `CurvedAnimation` |
| Spring 1D ×N | 1 `TrackController`, N spring tracks | N unbounded `AnimationController` running `SpringSimulation` (`snapToEnd`, same description) |
| Curve Offset/Rect/Color | 1 track with the built-in converter | 1 `AnimationController` + `CurvedAnimation` + `Tween<Offset>` / `RectTween` / `ColorTween` |
| Spring Offset/Rect/Color | 1 track with the built-in converter | 1 unbounded `AnimationController` per dimension |
| Drag 1D/Offset ×1, ×250, tracking on | `TrackController.set` every frame with `VelocityTracking.on`, then `animate` (inherits the tracked velocity) | `AnimationController.value =` per dimension and one `VelocityTracker` per value, then `animateWith` a `SpringSimulation` with `getVelocity()` |
| Drag, tracking off | The same with `VelocityTracking.off` | The same without a tracker, flinging from rest |

Equivalence choices:

- **Multi-dimensional curves** share one timing across dimensions, so one
  controller driving a tween is the honest equivalent.
- **Multi-dimensional springs** need one simulation per dimension to be
  retargeted mid-flight while keeping each dimension's velocity, and motor
  does that. From rest, one controller plus a tween would give the same path
  more cheaply, but it can't retarget with velocity.
- **Curve starts on the Flutter side** call `forward`/`reverse` (1D) or
  re-aim the tween from the current value and call `forward(from: 0)`.
- **Spring starts and retargets on the Flutter side** call `animateWith`
  with a new `SpringSimulation` from the current value and velocity.
- **Motor** uses one `animate` call per start. Velocity tracking is off; it
  only affects `set`.

**Gestures.** A drag scenario moves the pointer 2 px per frame, and value
`k` follows it offset by `k`. Each drag sample calls `set` (or `value =`)
once per frame for every value. The fling handoff is the `animate` call (or,
on the Flutter side, `getVelocity` plus `animateWith`) plus the next frame.
One `VelocityTracker` per value matches motor, which tracks every track
separately. If all values derive from one pointer, Flutter code would need
only one tracker.

Motor stamps samples with `clock.now()`, and Flutter with the event time.
During drag scenarios the harness overrides `clock` to return the frame
timestamps as UTC `DateTime`s, so both sides see the same 60 Hz spacing and
the equivalence check covers the handed-over velocity. A local-time
`DateTime` would not be fair: constructing one costs about 2 µs here, far
more than the `DateTime.now()` it stands in for.

**Motions.** Steady-state scenarios use motions that stay in flight for the
whole window: a 60 s easeInOut curve, and a 20 s spring with 0.3 bounce, which
is underdamped, so both sides evaluate trigonometry. Starts and retargets use
realistic motions: a 300 ms curve and `CupertinoMotion.bouncy()`.

**How frames are produced.** The harness calls
`SchedulerBinding.handleBeginFrame` and `handleDrawFrame` directly with
synthetic 60 Hz timestamps. Both sides use plain `Ticker`s. There is no
widget tree and no `WidgetTester.pump`, so harness work doesn't dilute the
difference.

**Metrics:**

| Metric | Definition |
|---|---|
| Frame + reads | Engine frame plus one read of every value. The headline, because curves do their work in the frame on motor's side and at read time on Flutter's (`CurvedAnimation`). |
| Engine frame | Time in `handleBeginFrame`: every ticker callback plus the listeners they notify. |
| Value read | ns per value, timed over read passes after each frame. Reads aren't cached on either side, so repeated passes are representative. |
| Start | The `animate`/`forward` call from rest plus the frame that follows it, because engines may defer work to their first tick. |
| Retarget | The same, while already in flight. Springs only: a retargeted curve has no equivalent. |
| Drag sample | One `set` of every value from a gesture sample, µs per sample (one sample per frame). |
| Fling handoff | Starting a spring with the tracked velocity after a drag, plus the next frame. |
| Allocated | Heap growth per frame (frame plus one read pass), minus an idle frame. Measured with the VM service's `getMemoryUsage` over short windows, taking the median to discard windows a collection lands in. |
| Retained | Live heap after a full GC, with the side started, minus before it was created. |

**Statistics.** 60 warmup frames, then 240 timed frames and 30 timed
starts/retargets per run. Each side gets 7 runs plus one discarded warm-up
run, alternating which side goes first. Tables report the median over runs.
The console output also shows ± half the range. Final numbers are the median of five invocations,
baseline numbers of three. Single-value rows drift the most (up to ±15%
between invocations), since they are sub-microsecond.

**Reproducing.** Run `melos run benchmark` for AOT release, add
`BENCH_BUILD=profile` for allocations, and use `melos run benchmark:smoke`
for the JIT smoke run used in CI. See [README.md](README.md) for filters and
knobs. A full release run takes about 15 s after the build.

## Results

### Per frame (release)

Frame plus one read of every value. The absolute µs are from the final run.

| Scenario | Flutter setup | Flutter µs | Motor µs | Baseline | **Final** | Engine frame only | Read ns/value (Flutter → Motor) |
|---|---|---:|---:|---:|---:|---:|---:|
| Curve 1D ×1 | 1 AC + CurvedAnimation | 0.23 | 0.44 | 2.46× | **1.88×** | 2.13× | 40 → 28 |
| Curve 1D ×10 | 10 AC + CurvedAnimation | 1.45 | 1.53 | 1.53× | **1.04×** | 1.18× | 38 → 23 |
| Curve 1D ×50 | 50 AC + CurvedAnimation | 7.14 | 6.43 | 1.57× | **0.90×** | 0.99× | 38 → 25 |
| Curve 1D ×250 | 250 AC + CurvedAnimation | 31.5 | 31.1 | 1.73× | **1.01×** | 1.15× | 38 → 26 |
| Curve 1D ×1000 | 1000 AC + CurvedAnimation | 128 | 132 | 1.81× | **1.06×** | 1.21× | 39 → 28 |
| Spring 1D ×1 | 1 AC + SpringSimulation | 0.27 | 0.47 | 1.86× | **1.76×** | 1.77× | 15 → 26 |
| Spring 1D ×10 | 10 AC + SpringSimulation | 1.87 | 1.85 | 1.18× | **0.99×** | 0.94× | 14 → 23 |
| Spring 1D ×50 | 50 AC + SpringSimulation | 8.38 | 7.69 | 1.15× | **0.92×** | 0.85× | 13 → 24 |
| Spring 1D ×250 | 250 AC + SpringSimulation | 42.9 | 39.0 | 1.19× | **0.89×** | 0.82× | 14 → 26 |
| Spring 1D ×1000 | 1000 AC + SpringSimulation | 160 | 162 | 1.28× | **1.01×** | 0.92× | 14 → 26 |
| Curve Offset (2D) | 1 AC + CurvedAnimation + Tween<Offset> | 0.25 | 0.46 | 2.81× | **1.77×** | 2.13× | 57 → 34 |
| Spring Offset (2D) | 2 AC (one per dimension) | 0.41 | 0.56 | 1.47× | **1.39×** | 1.38× | 22 → 34 |
| Curve Rect (4D) | 1 AC + CurvedAnimation + RectTween | 0.23 | 0.49 | 4.49× | **2.09×** | 2.40× | 46 → 40 |
| Spring Rect (4D) | 4 AC (one per dimension) | 0.70 | 0.66 | 1.19× | **0.94×** | 0.93× | 36 → 41 |
| Curve Color (4D) | 1 AC + CurvedAnimation + ColorTween | 0.24 | 0.51 | 4.30× | **2.15×** | 2.50× | 53 → 52 |
| Spring Color (4D) | 4 AC (one per dimension) | 0.74 | 0.69 | 1.18× | **0.94×** | 0.92× | 45 → 51 |

### Start and retarget (release)

The call plus the next frame, in µs per operation, final run.

| Scenario | Start: Flutter µs | Motor µs | Baseline | **Final** | Retarget: Flutter µs | Motor µs | Baseline | **Final** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Curve 1D ×1 | 0.38 | 1.45 | 6.3× | **3.8×** | – | – | – | – |
| Curve 1D ×10 | 2.65 | 6.32 | 7.3× | **2.5×** | – | – | – | – |
| Curve 1D ×50 | 12.7 | 29.8 | 6.8× | **2.4×** | – | – | – | – |
| Curve 1D ×250 | 55.8 | 145 | 7.8× | **2.6×** | – | – | – | – |
| Curve 1D ×1000 | 241 | 568 | 8.6× | **2.4×** | – | – | – | – |
| Spring 1D ×1 | 0.37 | 1.51 | 21.2× | **4.2×** | 0.45 | 1.42 | 17.2× | **3.1×** |
| Spring 1D ×10 | 2.53 | 8.10 | 27.2× | **3.3×** | 3.50 | 8.07 | 20.4× | **2.3×** |
| Spring 1D ×50 | 10.1 | 37.0 | 33.5× | **3.7×** | 16.1 | 37.3 | 21.7× | **2.3×** |
| Spring 1D ×250 | 52.8 | 203 | 38.9× | **3.9×** | 78.6 | 189 | 23.3× | **2.3×** |
| Spring 1D ×1000 | 211 | 847 | 38.1× | **4.0×** | 319 | 784 | 25.4× | **2.4×** |
| Curve Offset (2D) | 0.55 | 1.50 | 4.9× | **2.7×** | – | – | – | – |
| Spring Offset (2D) | 0.54 | 1.59 | 17.2× | **2.9×** | 0.75 | 1.59 | 13.4× | **2.2×** |
| Curve Rect (4D) | 0.52 | 1.68 | 6.6× | **3.2×** | – | – | – | – |
| Spring Rect (4D) | 0.95 | 2.00 | 16.0× | **2.1×** | 1.38 | 1.98 | 11.3× | **1.5×** |
| Curve Color (4D) | 0.53 | 1.71 | 6.7× | **3.2×** | – | – | – | – |
| Spring Color (4D) | 0.96 | 1.97 | 12.9× | **2.1×** | 1.40 | 2.02 | 8.9× | **1.4×** |

### Memory (profile)

Absolute values are from the final run.

| Scenario | Allocated B/frame: Flutter | Motor | Baseline | **Final** | Retained KB: Flutter | Motor | Baseline | **Final** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Curve 1D ×1 | 499 | 867 | 1.83× | **1.74×** | 1.00 | 3.23 | 3.59× | **3.23×** |
| Curve 1D ×10 | 4,227 | 1,971 | 0.58× | **0.47×** | 8.42 | 16.6 | 2.13× | **1.97×** |
| Curve 1D ×50 | 20,099 | 6,835 | 0.46× | **0.34×** | 40.7 | 75.5 | 1.99× | **1.85×** |
| Curve 1D ×250 | 96,643 | 30,771 | 0.44× | **0.32×** | 203 | 367 | 1.96× | **1.81×** |
| Curve 1D ×1000 | 385,635 | 120,915 | 0.44× | **0.31×** | 813 | 1,464 | 1.96× | **1.80×** |
| Spring 1D ×1 | 531 | 851 | 1.63× | **1.60×** | 0.95 | 3.27 | 3.82× | **3.43×** |
| Spring 1D ×10 | 4,547 | 1,811 | 0.43× | **0.40×** | 7.58 | 16.9 | 2.41× | **2.23×** |
| Spring 1D ×50 | 21,699 | 6,035 | 0.31× | **0.28×** | 36.4 | 77.1 | 2.26× | **2.12×** |
| Spring 1D ×250 | 104,643 | 26,771 | 0.29× | **0.26×** | 182 | 375 | 2.23× | **2.06×** |
| Spring 1D ×1000 | 417,635 | 104,915 | 0.29× | **0.25×** | 726 | 1,495 | 2.22× | **2.06×** |
| Curve Offset (2D) | 643 | 931 | 1.62× | **1.45×** | 0.97 | 3.66 | 4.18× | **3.77×** |
| Spring Offset (2D) | 915 | 915 | 1.03× | **1.00×** | 1.83 | 3.73 | 2.21× | **2.04×** |
| Curve Rect (4D) | 579 | 979 | 2.10× | **1.69×** | 0.97 | 4.11 | 4.73× | **4.24×** |
| Spring Rect (4D) | 1,603 | 963 | 0.64× | **0.60×** | 3.34 | 4.28 | 1.37× | **1.28×** |
| Curve Color (4D) | 579 | 979 | 2.10× | **1.69×** | 0.97 | 4.11 | 4.73× | **4.24×** |
| Spring Color (4D) | 1,603 | 963 | 0.64× | **0.60×** | 3.34 | 4.28 | 1.37× | **1.28×** |

### Following a gesture and velocity tracking (release; memory from profile)

| Scenario | Flutter setup | Drag: Flutter µs | Motor µs | Motor / Flutter | Fling: Flutter µs | Motor µs | Motor / Flutter | Allocated B/sample: Flutter → Motor | Retained KB: Flutter → Motor |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Drag 1D, tracking on ×1 | 1 AC + 1 VelocityTracker | 0.13 | 0.31 | **2.36×** | 1.24 | 1.73 | 1.40× | 275 → 787 | 2.31 → 2.42 |
| Drag 1D, tracking on ×250 | 250 AC + 250 VelocityTracker | 26.1 | 37.9 | **1.46×** | 259 | 224 | 0.87× | 68,003 → 57,187 | 496 → 207 |
| Drag Offset, tracking on ×1 | 2 AC + 1 VelocityTracker | 0.17 | 0.33 | **1.91×** | 1.41 | 1.83 | 1.31× | 483 → 915 | 2.77 → 2.70 |
| Drag Offset, tracking on ×250 | 500 AC + 250 VelocityTracker | 39.2 | 45.9 | **1.17×** | 352 | 257 | 0.71× | 120,003 → 89,187 | 610 → 277 |
| Drag 1D, tracking off ×1 | 1 AC | 0.08 | 0.24 | **3.04×** | 0.38 | 1.32 | 3.61× | 211 → 595 | 0.48 → 1.67 |
| Drag 1D, tracking off ×250 | 250 AC | 10.1 | 33.7 | **3.55×** | 51.3 | 126 | 2.53× | 52,003 → 41,059 | 119 → 83.5 |
| Drag Offset, tracking off ×1 | 2 AC | 0.11 | 0.25 | **2.28×** | 0.57 | 1.46 | 2.47× | 419 → 675 | 0.94 → 1.80 |
| Drag Offset, tracking off ×250 | 500 AC | 19.9 | 37.5 | **1.90×** | 102 | 154 | 1.51× | 104,003 → 61,059 | 232 → 115 |

The same numbers, with tracking on versus off:

| Values | Motor: off → on, µs/sample | Motor: added per value | Flutter: no tracker → VelocityTracker | Flutter: added per value |
|---|---:|---:|---:|---:|
| 1D ×1 | 0.24 → 0.31 (1.30×) | +0.070 µs | 0.08 → 0.13 | +0.048 µs |
| 1D ×250 | 33.7 → 37.9 (1.12×) | +0.017 µs | 10.1 → 26.1 | +0.064 µs |
| Offset ×1 | 0.25 → 0.33 (1.33×) | +0.082 µs | 0.11 → 0.17 | +0.056 µs |
| Offset ×250 | 37.5 → 45.9 (1.22×) | +0.033 µs | 19.9 → 39.2 | +0.077 µs |

Before `ffd0c3c`, each tracked sample cost about 0.6 µs and 370 B. About
0.4 µs of that went to storing a freshly allocated `List<double>`, record
and `Duration` into `MotionVelocityTracker`'s long-lived ring buffer. Samples
now go into a preallocated buffer, so tracking adds 0.02 to 0.08 µs per
value per sample and about 64 B per value per sample at scale, the same
as `VelocityTracker`.
Estimating the velocity is lazy: it runs once at the fling, not per sample.

Even with tracking off, `set` costs 1.9× to 3.6× `AnimationController.value
=`: about 0.1 µs per track of slot bookkeeping and notification.

### Why AOT: baseline ratios under `flutter test`

| Scenario | Frame + reads: AOT release | JIT debug | Start: AOT release | JIT debug |
|---|---:|---:|---:|---:|
| Curve 1D ×1 | 2.46× | 1.42× | 6.3× | 2.8× |
| Curve 1D ×1000 | 1.81× | 1.13× | 8.6× | 0.9× |
| Spring 1D ×1 | 1.86× | 1.40× | 21.2× | 2.2× |
| Spring 1D ×1000 | 1.28× | 0.76× | 38.1× | 2.8× |

In debug, assertions in `AnimationController`, `Ticker` and the scheduler
hide most of the difference. The smoke run only checks that the harness and
the equivalence still hold.

## Next targets

1. **Per-controller fixed cost.** A single value still costs about 1.8× per
   frame, about 0.2 µs per controller per frame. This matters most for the
   common one-controller-per-widget case.
2. **Start and retarget** are still 2× to 4×: building a plan, its steps
   and its simulations per call.
3. **`set` bookkeeping:** about 0.1 µs per track, which makes a
   single-value drag about 2×.
4. **Reads and retained memory:** spring reads cost about 1.8×, and a track
   retains about 1.5 KB versus about 0.75 to 0.85 KB per
   `AnimationController`.

## History

Before `36bee1f`, this file tracked per-phase numbers from the original
harness (definev, #307). That harness timed `WidgetTester.pump` under
`flutter test`, used a looping curve for multi-track, and read uncurved
`AnimationController.value`. Its tables live in git history
(`git show 36bee1f^:packages/motor/benchmark/ANALYSIS.md`). The widget
rebuild, manual `set` and velocity tracking scenarios were dropped with it;
the drag scenarios replace the last two.
They measured widget or `set` paths rather than the animation engine, and
they are in the same history.
