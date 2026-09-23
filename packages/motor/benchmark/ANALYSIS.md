# Analysis: Motor vs AnimationController

Measured on a Linux cloud VM (8 vCPU Intel Xeon) with Flutter 3.44.1 /
Dart 3.12.1. Timings come from AOT release builds (`melos run benchmark`), and
memory from one AOT profile build (`BENCH_BUILD=profile`).

- **Baseline:** `motor/2.0` at `3cc5de9`, before the optimization pass
  (three invocations of 7 runs each).
- **Final:** `motor/2.0` at `af172d6`, after it (five invocations).

The optimization pass changed three things:
- `f5fb928`/`43ea1d9`: segment ends are found as time passes, not searched
  up front.
- `3acafda`: velocities are computed only when read, and dimensions that
  share a curve evaluate it once per frame.
- `5fc7a94`/`38fc0ce`: fewer allocations on start, and less memory retained
  per track.

`4477802` also fixes `CurveSimulation.dx`, which reported 4× the real
velocity.

Tables show motor ÷ Flutter. Below 1× means motor is cheaper.

## Summary

- **Per frame, motor now matches `AnimationController` once there is more
  than one value.**
  - 10 to 1000 values on one controller cost 0.87× to 1.09× the equivalent
    `AnimationController`s, for curves and springs alike (baseline: 1.15×
    to 1.81×).
  - A single value still costs 1.7× to 2.2×. That's a fixed overhead of
    about 0.3 µs per controller per frame.
- **Multi-dimensional values:**
  - Springs are at parity with one controller per dimension: 0.96× to
    1.33×.
  - Curves cost 1.8× to 2.1× what one controller plus a tween costs
    (baseline: 2.8× to 4.5×).
- **Starting and retargeting got much cheaper.** Spring starts and
  retargets are 4× to 8× faster than the baseline, and curve starts 1.4× to
  3× faster.
  - Starting now costs 2.1× to 4.3× the Flutter side, and retargeting a
    spring 1.5× to 3.5× (baseline: 5× to 39× and 9× to 25×).
  - 1000 springs start in 1.0 ms versus 0.24 ms, and one spring retargets
    in 1.7 µs versus 0.5 µs.
- **Value reads are unchanged:**
  - Curve tracks read faster than `CurvedAnimation.value` (0.6× to 0.7×).
  - Spring tracks read about 1.8× slower than `AnimationController.value`
    (about 28 versus 16 ns).
- **Memory:**
  - Retained memory went down about 17%, to about 1.5 KB per track (still
    1.6× to 1.9× an `AnimationController` at scale).
  - Curve garbage per frame went down: 0.31× the Flutter side at 1000
    values.
  - Spring garbage per frame went **up**, from 121 to 217 B per track per
    frame (0.29× → 0.52× of Flutter at scale), which is likely the
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
| Curve 1D ×1 | 1 AC + CurvedAnimation | 0.30 | 0.66 | 2.46× | **2.16×** | 2.47× | 47 → 31 |
| Curve 1D ×10 | 10 AC + CurvedAnimation | 1.82 | 1.86 | 1.53× | **1.03×** | 1.11× | 44 → 27 |
| Curve 1D ×50 | 50 AC + CurvedAnimation | 8.32 | 7.46 | 1.57× | **0.87×** | 0.96× | 44 → 28 |
| Curve 1D ×250 | 250 AC + CurvedAnimation | 36.3 | 37.4 | 1.73× | **1.01×** | 1.15× | 44 → 31 |
| Curve 1D ×1000 | 1000 AC + CurvedAnimation | 145 | 151 | 1.81× | **1.07×** | 1.23× | 44 → 30 |
| Spring 1D ×1 | 1 AC + SpringSimulation | 0.32 | 0.58 | 1.86× | **1.74×** | 1.75× | 18 → 28 |
| Spring 1D ×10 | 10 AC + SpringSimulation | 2.12 | 2.23 | 1.18× | **1.06×** | 1.01× | 16 → 27 |
| Spring 1D ×50 | 50 AC + SpringSimulation | 9.70 | 9.61 | 1.15× | **0.98×** | 0.91× | 16 → 28 |
| Spring 1D ×250 | 250 AC + SpringSimulation | 48.4 | 46.4 | 1.19× | **0.95×** | 0.86× | 16 → 32 |
| Spring 1D ×1000 | 1000 AC + SpringSimulation | 186 | 203 | 1.28× | **1.09×** | 1.01× | 16 → 30 |
| Curve Offset (2D) | 1 AC + CurvedAnimation + Tween<Offset> | 0.29 | 0.52 | 2.81× | **1.77×** | 2.10× | 65 → 36 |
| Spring Offset (2D) | 2 AC (one per dimension) | 0.48 | 0.63 | 1.47× | **1.33×** | 1.32× | 26 → 37 |
| Curve Rect (4D) | 1 AC + CurvedAnimation + RectTween | 0.26 | 0.59 | 4.49× | **2.11×** | 2.39× | 53 → 44 |
| Spring Rect (4D) | 4 AC (one per dimension) | 0.85 | 0.76 | 1.19× | **0.96×** | 0.96× | 42 → 45 |
| Curve Color (4D) | 1 AC + CurvedAnimation + ColorTween | 0.28 | 0.58 | 4.30× | **2.06×** | 2.37× | 61 → 57 |
| Spring Color (4D) | 4 AC (one per dimension) | 0.86 | 0.82 | 1.18× | **0.96×** | 0.95× | 53 → 59 |

### Start and retarget (release)

The call plus the next frame, in µs per operation, final run.

| Scenario | Start: Flutter µs | Motor µs | Baseline | **Final** | Retarget: Flutter µs | Motor µs | Baseline | **Final** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Curve 1D ×1 | 0.44 | 1.67 | 6.3× | **3.7×** | – | – | – | – |
| Curve 1D ×10 | 2.90 | 7.45 | 7.3× | **2.6×** | – | – | – | – |
| Curve 1D ×50 | 15.2 | 34.3 | 6.8× | **2.3×** | – | – | – | – |
| Curve 1D ×250 | 64.6 | 173 | 7.8× | **2.7×** | – | – | – | – |
| Curve 1D ×1000 | 269 | 657 | 8.6× | **2.5×** | – | – | – | – |
| Spring 1D ×1 | 0.41 | 1.79 | 21.2× | **4.2×** | 0.50 | 1.74 | 17.2× | **3.5×** |
| Spring 1D ×10 | 2.84 | 10.1 | 27.2× | **3.6×** | 3.76 | 9.85 | 20.4× | **2.6×** |
| Spring 1D ×50 | 11.6 | 44.2 | 33.5× | **3.8×** | 18.1 | 46.1 | 21.7× | **2.5×** |
| Spring 1D ×250 | 53.2 | 231 | 38.9× | **4.2×** | 82.4 | 221 | 23.3× | **2.7×** |
| Spring 1D ×1000 | 241 | 1,047 | 38.1× | **4.3×** | 343 | 959 | 25.4× | **2.8×** |
| Curve Offset (2D) | 0.62 | 1.61 | 4.9× | **2.7×** | – | – | – | – |
| Spring Offset (2D) | 0.60 | 1.84 | 17.2× | **3.0×** | 0.80 | 1.81 | 13.4× | **2.3×** |
| Curve Rect (4D) | 0.58 | 1.92 | 6.6× | **3.2×** | – | – | – | – |
| Spring Rect (4D) | 1.07 | 2.40 | 16.0× | **2.2×** | 1.54 | 2.43 | 11.3× | **1.6×** |
| Curve Color (4D) | 0.60 | 2.00 | 6.7× | **3.2×** | – | – | – | – |
| Spring Color (4D) | 1.09 | 2.40 | 12.9× | **2.1×** | 1.59 | 2.42 | 8.9× | **1.5×** |

### Memory (profile)

Absolute values are from the final run.

| Scenario | Allocated B/frame: Flutter | Motor | Baseline | **Final** | Retained KB: Flutter | Motor | Baseline | **Final** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Curve 1D ×1 | 499 | 867 | 1.83× | **1.74×** | 1.00 | 3.30 | 3.59× | **3.30×** |
| Curve 1D ×10 | 4,227 | 1,971 | 0.58× | **0.47×** | 9.19 | 16.6 | 2.13× | **1.81×** |
| Curve 1D ×50 | 20,099 | 6,835 | 0.46× | **0.34×** | 45.4 | 75.6 | 1.99× | **1.67×** |
| Curve 1D ×250 | 96,643 | 30,771 | 0.44× | **0.32×** | 225 | 367 | 1.96× | **1.63×** |
| Curve 1D ×1000 | 385,635 | 120,915 | 0.44× | **0.31×** | 899 | 1,464 | 1.96× | **1.63×** |
| Spring 1D ×1 | 531 | 963 | 1.63× | **1.81×** | 0.95 | 3.33 | 3.82× | **3.49×** |
| Spring 1D ×10 | 4,547 | 2,931 | 0.43× | **0.64×** | 8.34 | 17.0 | 2.41× | **2.03×** |
| Spring 1D ×50 | 21,699 | 11,635 | 0.31× | **0.54×** | 41.0 | 77.1 | 2.26× | **1.88×** |
| Spring 1D ×250 | 104,643 | 54,771 | 0.29× | **0.52×** | 203 | 375 | 2.23× | **1.84×** |
| Spring 1D ×1000 | 417,635 | 216,915 | 0.29× | **0.52×** | 813 | 1,495 | 2.22× | **1.84×** |
| Curve Offset (2D) | 643 | 931 | 1.62× | **1.45×** | 0.97 | 3.72 | 4.18× | **3.84×** |
| Spring Offset (2D) | 915 | 1,027 | 1.03× | **1.12×** | 1.88 | 3.80 | 2.21× | **2.02×** |
| Curve Rect (4D) | 579 | 979 | 2.10× | **1.69×** | 0.97 | 4.17 | 4.73× | **4.31×** |
| Spring Rect (4D) | 1,603 | 1,034 | 0.64× | **0.64×** | 3.48 | 4.34 | 1.37× | **1.25×** |
| Curve Color (4D) | 579 | 979 | 2.10× | **1.69×** | 0.97 | 4.17 | 4.73× | **4.31×** |
| Spring Color (4D) | 1,520 | 1,075 | 0.64× | **0.71×** | 3.48 | 4.34 | 1.37× | **1.25×** |


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

1. **Per-controller fixed cost.** A single value is still 1.7× to 2.2× per
   frame, about 0.3 µs per controller per frame. This matters most for the
   common one-controller-per-widget case.
2. **Spring allocations per frame** rose about 96 B per track in this
   pass.
3. **Start and retarget** are still 2× to 4×: building a plan, its steps
   and its simulations per call.
4. **Reads and retained memory:** spring reads cost about 1.8×, and a track
   retains about 1.5 KB versus about 0.85 KB per `AnimationController`.

## History

Before `36bee1f`, this file tracked per-phase numbers from the original
harness (definev, #307). That harness timed `WidgetTester.pump` under
`flutter test`, used a looping curve for multi-track, and read uncurved
`AnimationController.value`. Its tables live in git history
(`git show 36bee1f^:packages/motor/benchmark/ANALYSIS.md`). The widget
rebuild, manual `set` and velocity tracking scenarios were dropped with it.
They measured widget or `set` paths rather than the animation engine, and
they are in the same history.
