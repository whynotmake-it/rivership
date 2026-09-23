# Analysis: Motor vs AnimationController

Measured on a Linux cloud VM (8 vCPU Intel Xeon) with Flutter 3.44.1 /
Dart 3.12.1. Timings come from AOT release builds (`melos run benchmark`), and
memory from one AOT profile build (`BENCH_BUILD=profile`).

- **Baseline:** `motor/2.0` at `3cc5de9`, before the optimization pass
  (three invocations of 7 runs each).
- **Final:** `motor/2.0` at `e1869d9`, after it (five invocations). An
  earlier final run at `af172d6` gave the same ratios within noise.

The optimization pass changed three things:
- `f5fb928`/`43ea1d9`: segment ends are found as time passes, not searched
  up front.
- `3acafda`: velocities are computed only when read, and dimensions that
  share a curve evaluate it once per frame.
- `5fc7a94`/`38fc0ce`: fewer allocations on start, and less memory retained
  per track.

`4477802` also fixes `CurveSimulation.dx`, which reported 4× the real
velocity.

Tables show motor ÷ Flutter. Below 1× means motor is cheaper. The drag and
velocity tracking scenarios were added after the baseline, so they have
only final numbers.

## Summary

- **Per frame, motor matches `AnimationController` once there is more than
  one value.**
  - 10 to 1000 values on one controller cost 0.91× to 1.07× the equivalent
    `AnimationController`s, for curves and springs alike (baseline: 1.15×
    to 1.81×).
  - A single value still costs about 1.9×. That's a fixed overhead of about
    0.25 µs per controller per frame.
- **Multi-dimensional values:**
  - Springs are at parity with one controller per dimension: 0.92× to
    1.37×.
  - Curves cost 1.75× to 2.1× what one controller plus a tween costs
    (baseline: 2.8× to 4.5×).
- **Starting and retargeting got much cheaper.** Spring starts and
  retargets are 4× to 8× faster than the baseline, and curve starts 1.4× to
  3× faster.
  - Starting now costs 2.2× to 4.4× the Flutter side, and retargeting a
    spring 1.6× to 3.4× (baseline: 5× to 39× and 9× to 25×).
  - 1000 springs start in 1.05 ms versus 0.25 ms, and one spring retargets
    in 1.8 µs versus 0.5 µs.
- **Velocity tracking (on by default) adds about 0.6 µs per tracked value
  per `set`**, with each sample allocating about 370 B more.
  - That is about 8× what a Flutter `VelocityTracker` adds (0.06 to
    0.08 µs and 64 B).
  - Following a drag costs about 1 µs per frame for one value, and 0.2 ms
    per frame for 250 values.
  - Almost all of it is storing each sample in `MotionVelocityTracker`'s
    ring buffer (details under Results).
  - The fling handoff with tracked velocity costs 1.0× to 1.55× the Flutter
    equivalent.
- **Value reads:**
  - Curve tracks read faster than `CurvedAnimation.value` (0.7×).
  - Spring tracks read about 1.9× slower than `AnimationController.value`
    (about 31 versus 16 ns).
- **Memory:**
  - Retained memory is about 1.5 KB per track (baseline: 1.8 KB), still
    about twice an `AnimationController` at scale.
  - Curve garbage per frame went down: 0.31× the Flutter side at 1000
    values.
  - Spring garbage per frame went **up**, from 121 to 217 B per track per
    frame (0.29× → 0.52× of Flutter at scale). The likely cause is the
    per-frame lazy end check. It's still half of what N controllers
    allocate.

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
| Curve 1D ×1 | 1 AC + CurvedAnimation | 0.28 | 0.53 | 2.46× | **1.91×** | 2.16× | 48 → 34 |
| Curve 1D ×10 | 10 AC + CurvedAnimation | 1.91 | 1.87 | 1.53× | **0.97×** | 1.10× | 47 → 29 |
| Curve 1D ×50 | 50 AC + CurvedAnimation | 8.76 | 7.84 | 1.57× | **0.91×** | 0.97× | 46 → 30 |
| Curve 1D ×250 | 250 AC + CurvedAnimation | 39.1 | 38.6 | 1.73× | **0.99×** | 1.11× | 46 → 33 |
| Curve 1D ×1000 | 1000 AC + CurvedAnimation | 157 | 161 | 1.81× | **1.07×** | 1.19× | 47 → 34 |
| Spring 1D ×1 | 1 AC + SpringSimulation | 0.33 | 0.61 | 1.86× | **1.84×** | 1.84× | 18 → 31 |
| Spring 1D ×10 | 10 AC + SpringSimulation | 2.23 | 2.35 | 1.18× | **1.06×** | 1.01× | 16 → 28 |
| Spring 1D ×50 | 50 AC + SpringSimulation | 9.97 | 9.81 | 1.15× | **0.98×** | 0.91× | 15 → 29 |
| Spring 1D ×250 | 250 AC + SpringSimulation | 49.8 | 48.5 | 1.19× | **0.98×** | 0.88× | 16 → 34 |
| Spring 1D ×1000 | 1000 AC + SpringSimulation | 197 | 211 | 1.28× | **1.07×** | 0.99× | 16 → 32 |
| Curve Offset (2D) | 1 AC + CurvedAnimation + Tween<Offset> | 0.30 | 0.55 | 2.81× | **1.75×** | 2.07× | 69 → 41 |
| Spring Offset (2D) | 2 AC (one per dimension) | 0.53 | 0.72 | 1.47× | **1.37×** | 1.36× | 28 → 41 |
| Curve Rect (4D) | 1 AC + CurvedAnimation + RectTween | 0.29 | 0.58 | 4.49× | **2.06×** | 2.35× | 56 → 47 |
| Spring Rect (4D) | 4 AC (one per dimension) | 0.91 | 0.86 | 1.19× | **0.94×** | 0.93× | 46 → 50 |
| Curve Color (4D) | 1 AC + CurvedAnimation + ColorTween | 0.29 | 0.60 | 4.30× | **2.10×** | 2.42× | 64 → 64 |
| Spring Color (4D) | 4 AC (one per dimension) | 0.92 | 0.88 | 1.18× | **0.92×** | 0.91× | 58 → 64 |

### Start and retarget (release)

The call plus the next frame, in µs per operation, final run.

| Scenario | Start: Flutter µs | Motor µs | Baseline | **Final** | Retarget: Flutter µs | Motor µs | Baseline | **Final** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Curve 1D ×1 | 0.47 | 1.77 | 6.3× | **3.8×** | – | – | – | – |
| Curve 1D ×10 | 3.18 | 7.88 | 7.3× | **2.5×** | – | – | – | – |
| Curve 1D ×50 | 17.7 | 38.8 | 6.8× | **2.4×** | – | – | – | – |
| Curve 1D ×250 | 72.5 | 183 | 7.8× | **2.7×** | – | – | – | – |
| Curve 1D ×1000 | 287 | 692 | 8.6× | **2.4×** | – | – | – | – |
| Spring 1D ×1 | 0.44 | 1.93 | 21.2× | **4.4×** | 0.54 | 1.82 | 17.2× | **3.4×** |
| Spring 1D ×10 | 3.00 | 10.5 | 27.2× | **3.5×** | 4.06 | 10.2 | 20.4× | **2.5×** |
| Spring 1D ×50 | 11.8 | 45.5 | 33.5× | **3.9×** | 18.1 | 47.5 | 21.7× | **2.6×** |
| Spring 1D ×250 | 56.6 | 234 | 38.9× | **4.3×** | 83.2 | 226 | 23.3× | **2.7×** |
| Spring 1D ×1000 | 249 | 1,053 | 38.1× | **4.3×** | 365 | 976 | 25.4× | **2.7×** |
| Curve Offset (2D) | 0.66 | 1.76 | 4.9× | **2.7×** | – | – | – | – |
| Spring Offset (2D) | 0.63 | 2.00 | 17.2× | **3.1×** | 0.83 | 1.99 | 13.4× | **2.4×** |
| Curve Rect (4D) | 0.63 | 2.02 | 6.6× | **3.2×** | – | – | – | – |
| Spring Rect (4D) | 1.14 | 2.50 | 16.0× | **2.2×** | 1.59 | 2.54 | 11.3× | **1.6×** |
| Curve Color (4D) | 0.63 | 2.08 | 6.7× | **3.2×** | – | – | – | – |
| Spring Color (4D) | 1.16 | 2.57 | 12.9× | **2.2×** | 1.65 | 2.57 | 8.9× | **1.6×** |

### Memory (profile)

Absolute values are from the final run.

| Scenario | Allocated B/frame: Flutter | Motor | Baseline | **Final** | Retained KB: Flutter | Motor | Baseline | **Final** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Curve 1D ×1 | 499 | 867 | 1.83× | **1.74×** | 1.00 | 3.31 | 3.59× | **3.31×** |
| Curve 1D ×10 | 4,227 | 1,971 | 0.58× | **0.47×** | 8.42 | 16.7 | 2.13× | **1.98×** |
| Curve 1D ×50 | 20,099 | 6,835 | 0.46× | **0.34×** | 40.7 | 75.6 | 1.99× | **1.86×** |
| Curve 1D ×250 | 96,602 | 30,771 | 0.44× | **0.32×** | 203 | 367 | 1.96× | **1.81×** |
| Curve 1D ×1000 | 385,635 | 120,915 | 0.44× | **0.31×** | 813 | 1,464 | 1.96× | **1.80×** |
| Spring 1D ×1 | 531 | 963 | 1.63× | **1.81×** | 0.95 | 3.34 | 3.82× | **3.51×** |
| Spring 1D ×10 | 4,464 | 2,931 | 0.43× | **0.66×** | 7.58 | 17.0 | 2.41× | **2.24×** |
| Spring 1D ×50 | 21,699 | 11,635 | 0.31× | **0.54×** | 36.4 | 77.2 | 2.26× | **2.12×** |
| Spring 1D ×250 | 104,643 | 54,771 | 0.29× | **0.52×** | 182 | 375 | 2.23× | **2.06×** |
| Spring 1D ×1000 | 417,552 | 216,915 | 0.29× | **0.52×** | 726 | 1,495 | 2.22× | **2.06×** |
| Curve Offset (2D) | 643 | 931 | 1.62× | **1.45×** | 0.97 | 3.73 | 4.18× | **3.85×** |
| Spring Offset (2D) | 915 | 1,027 | 1.03× | **1.12×** | 1.83 | 3.81 | 2.21× | **2.09×** |
| Curve Rect (4D) | 579 | 979 | 2.10× | **1.69×** | 0.97 | 4.19 | 4.73× | **4.32×** |
| Spring Rect (4D) | 1,603 | 1,075 | 0.64× | **0.67×** | 3.34 | 4.36 | 1.37× | **1.30×** |
| Curve Color (4D) | 579 | 979 | 2.10× | **1.69×** | 0.97 | 4.19 | 4.73× | **4.32×** |
| Spring Color (4D) | 1,603 | 1,075 | 0.64× | **0.67×** | 3.34 | 4.36 | 1.37× | **1.30×** |

### Following a gesture and velocity tracking (release; memory from profile)

| Scenario | Flutter setup | Drag: Flutter µs | Motor µs | Motor / Flutter | Fling: Flutter µs | Motor µs | Motor / Flutter | Allocated B/sample: Flutter → Motor | Retained KB: Flutter → Motor |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Drag 1D, tracking on ×1 | 1 AC + 1 VelocityTracker | 0.16 | 0.95 | **6.1×** | 1.52 | 2.40 | 1.55× | 275 → 1,379 | 2.31 → 5.03 |
| Drag 1D, tracking on ×250 | 250 AC + 250 VelocityTracker | 31.6 | 202 | **6.4×** | 327 | 340 | 1.03× | 68,003 → 201,203 | 496 → 838 |
| Drag Offset, tracking on ×1 | 2 AC + 1 VelocityTracker | 0.21 | 0.97 | **4.8×** | 1.74 | 2.61 | 1.50× | 483 → 1,523 | 2.77 → 5.80 |
| Drag Offset, tracking on ×250 | 500 AC + 250 VelocityTracker | 46.6 | 210 | **4.5×** | 419 | 430 | 1.01× | 120,003 → 237,203 | 610 → 1,029 |
| Drag 1D, tracking off ×1 | 1 AC | 0.10 | 0.38 | **4.0×** | 0.45 | 1.79 | 3.82× | 211 → 1,011 | 0.48 → 1.75 |
| Drag 1D, tracking off ×250 | 250 AC | 11.4 | 50.5 | **4.4×** | 58.6 | 147 | 2.53× | 52,003 → 109,203 | 119 → 83.6 |
| Drag Offset, tracking off ×1 | 2 AC | 0.14 | 0.37 | **2.7×** | 0.66 | 1.84 | 2.78× | 419 → 1,107 | 0.94 → 1.88 |
| Drag Offset, tracking off ×250 | 500 AC | 25.9 | 55.2 | **2.1×** | 121 | 183 | 1.52× | 104,003 → 133,203 | 232 → 115 |

The same numbers, with tracking on versus off:

| Values | Motor: off → on, µs/sample | Motor: added per value | Flutter: no tracker → VelocityTracker | Flutter: added per value |
|---|---:|---:|---:|---:|
| 1D ×1 | 0.38 → 0.95 (2.5×) | +0.57 µs | 0.10 → 0.16 | +0.06 µs |
| 1D ×250 | 50.5 → 202 (4.0×) | +0.61 µs | 11.4 → 31.6 | +0.08 µs |
| Offset ×1 | 0.37 → 0.97 (2.6×) | +0.60 µs | 0.14 → 0.21 | +0.07 µs |
| Offset ×250 | 55.2 → 210 (3.8×) | +0.62 µs | 25.9 → 46.6 | +0.08 µs |

Where motor's roughly 0.6 µs per tracked sample goes (AOT release,
measured separately):

- About 0.4 µs is `MotionVelocityTracker.addPosition` storing the sample in
  its 20-slot ring buffer. Each sample is a freshly allocated normalized
  `List<double>`, a record and a `Duration`, stored into the long-lived
  buffer. The same allocations cost about 4 ns when they don't escape, and
  Flutter's `VelocityTracker.addPosition` stores its sample in about 60 ns.
  Storing samples in a preallocated flat buffer would remove most of this
  without changing behavior or API.
- The remaining 0.1 to 0.2 µs is the controller's bookkeeping in
  `_trackVelocitySample`:
  a second `clock.now()` (about 50 ns), a `Duration`, and the pending
  estimate map.
- Estimating the velocity is lazy. It runs once at the fling, not per
  sample, and costs about 0.1 µs.
- Retained memory for tracking is about 3 KB per tracked track (the
  filled ring buffer), versus about 1.5 KB per `VelocityTracker`.

Even with tracking off, `set` costs 2× to 4.5× `AnimationController.value
=`: about 0.2 µs per track of slot bookkeeping and notification.

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

1. **Per-controller fixed cost.** A single value still costs about 1.9× per
   frame, about 0.25 µs per controller per frame. This matters most for the
   common one-controller-per-widget case.
2. **Velocity sample storage:** about 0.4 µs of every tracked `set` (see
   Results).
3. **Spring allocations per frame** rose about 96 B per track in the
   optimization pass.
4. **Start and retarget** are still 2× to 4×: building a plan, its steps
   and its simulations per call.
5. **Reads and retained memory:** spring reads cost about 1.9×, and a track
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
