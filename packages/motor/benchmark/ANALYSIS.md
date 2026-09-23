# Analysis: Motor vs AnimationController

Numbers from `motor/2.0` at `3cc5de9`, measured on a Linux cloud VM (8 vCPU
Intel Xeon) with Flutter 3.44.1 / Dart 3.12.1. Timings: AOT release build,
three invocations of `melos run benchmark` (7 runs each). Allocations: one AOT
profile build (`BENCH_BUILD=profile`).

## Summary

- **Per frame, springs are close to parity at scale.** One controller with
  10 to 1000 spring tracks costs 1.15× to 1.28× the equivalent
  `AnimationController`s. A single value costs about 1.9× because motor
  carries a fixed overhead of roughly 0.2 to 0.3 µs per controller per frame.
- **Curves cost more.** 1D curves cost 1.5× to 1.8× per frame, and a
  multi-dimensional curve track costs 2.8× to 4.5× what one controller plus a
  tween costs. Motor samples every dimension separately and also computes
  each velocity (`CurveSimulation.dx`), which is a central difference. That
  makes 3 curve evaluations per dimension per frame, where `CurvedAnimation`
  plus a tween evaluates the curve once.
- **Starting and retargeting is the big gap.** Starting a curve costs
  5× to 9× as much as on the Flutter side, and starting or retargeting a spring
  costs 9× to 39×. For example, 8 ms to start 1000 springs versus 0.2 ms, and
  7.3 µs versus 0.4 µs to retarget one spring. Each new segment searches for
  its end up front (`StepPlayback._findSegmentDuration`): it steps `isDone`
  forward in 1/60 s increments, then bisects to double precision.
- **Value reads:** reading a curve track is faster than reading
  `CurvedAnimation.value` (0.6× to 0.7×), because motor already applied the
  curve in the frame. Reading a spring track is about 1.8× slower than
  reading `AnimationController.value` (25 versus 13 ns), because of the slot
  lookup and denormalizing.
- **Memory:** at scale, motor allocates 30% to 45% of the per-frame garbage,
  because it runs one ticker instead of N. It retains about twice the memory:
  1.8 KB per track versus 0.8 to 0.9 KB per controller.
- **Debug builds flatter motor.** Under `flutter test` (JIT with asserts),
  `AnimationController` pays for its asserts. 1000 springs then look 24%
  *faster* than Flutter per frame, and spring starts look 2.8× instead of
  38×. Only AOT numbers should be quoted.

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
The console output also shows ± half the range. Ratios varied by at most 11%
across three invocations; single-value rows drift the most, since they are
sub-microsecond.

**Reproducing.** Run `melos run benchmark` for AOT release, add
`BENCH_BUILD=profile` for allocations, and use `melos run benchmark:smoke`
for the JIT smoke run used in CI. See [README.md](README.md) for filters and
knobs. A full release run takes about 15 s after the build.

## Results

### Per frame (release)

Frame plus one read of every value, in µs per frame.

| Scenario | Flutter setup | Flutter µs | Motor µs | Motor / Flutter | Engine frame only | Read ns/value (Flutter → Motor) |
|---|---|---:|---:|---:|---:|---:|
| Curve 1D ×1 | 1 AC + CurvedAnimation | 0.23 | 0.58 | **2.46×** | 2.83× | 39 → 28 |
| Curve 1D ×10 | 10 AC + CurvedAnimation | 1.59 | 2.48 | **1.53×** | 1.81× | 38 → 23 |
| Curve 1D ×50 | 50 AC + CurvedAnimation | 7.03 | 11.0 | **1.57×** | 1.91× | 37 → 24 |
| Curve 1D ×250 | 250 AC + CurvedAnimation | 31.1 | 53.5 | **1.73×** | 2.20× | 38 → 25 |
| Curve 1D ×1000 | 1000 AC + CurvedAnimation | 122 | 221 | **1.81×** | 2.33× | 38 → 25 |
| Spring 1D ×1 | 1 AC + SpringSimulation | 0.27 | 0.51 | **1.86×** | 1.87× | 15 → 26 |
| Spring 1D ×10 | 10 AC + SpringSimulation | 1.80 | 2.14 | **1.18×** | 1.14× | 13 → 23 |
| Spring 1D ×50 | 50 AC + SpringSimulation | 8.62 | 9.84 | **1.15×** | 1.11× | 13 → 24 |
| Spring 1D ×250 | 250 AC + SpringSimulation | 40.0 | 47.8 | **1.19×** | 1.13× | 13 → 25 |
| Spring 1D ×1000 | 1000 AC + SpringSimulation | 162 | 208 | **1.28×** | 1.23× | 13 → 26 |
| Curve Offset (2D) | 1 AC + CurvedAnimation + Tween<Offset> | 0.27 | 0.76 | **2.81×** | 3.43× | 60 → 37 |
| Spring Offset (2D) | 2 AC (one per dimension) | 0.44 | 0.64 | **1.47×** | 1.47× | 24 → 36 |
| Curve Rect (4D) | 1 AC + CurvedAnimation + RectTween | 0.24 | 1.10 | **4.49×** | 5.37× | 48 → 42 |
| Spring Rect (4D) | 4 AC (one per dimension) | 0.75 | 0.88 | **1.19×** | 1.19× | 37 → 41 |
| Curve Color (4D) | 1 AC + CurvedAnimation + ColorTween | 0.27 | 1.06 | **4.30×** | 5.23× | 56 → 53 |
| Spring Color (4D) | 4 AC (one per dimension) | 0.79 | 0.94 | **1.18×** | 1.19× | 51 → 54 |

### Start and retarget (release)

The call plus the next frame, in µs per operation.

| Scenario | Start: Flutter µs | Motor µs | Motor / Flutter | Retarget: Flutter µs | Motor µs | Motor / Flutter |
|---|---:|---:|---:|---:|---:|---:|
| Curve 1D ×1 | 0.37 | 2.41 | **6.3×** | – | – | – |
| Curve 1D ×10 | 2.60 | 18.6 | **7.3×** | – | – | – |
| Curve 1D ×50 | 13.3 | 90.7 | **6.8×** | – | – | – |
| Curve 1D ×250 | 54.2 | 429 | **7.8×** | – | – | – |
| Curve 1D ×1000 | 230 | 1,930 | **8.6×** | – | – | – |
| Spring 1D ×1 | 0.36 | 7.92 | **21.2×** | 0.43 | 7.33 | **17.2×** |
| Spring 1D ×10 | 2.47 | 68.0 | **27.2×** | 3.31 | 69.2 | **20.4×** |
| Spring 1D ×50 | 10.5 | 339 | **33.5×** | 15.7 | 337 | **21.7×** |
| Spring 1D ×250 | 44.6 | 1,736 | **38.9×** | 74.4 | 1,732 | **23.3×** |
| Spring 1D ×1000 | 210 | 8,023 | **38.1×** | 316 | 7,935 | **25.4×** |
| Curve Offset (2D) | 0.57 | 2.83 | **4.9×** | – | – | – |
| Spring Offset (2D) | 0.57 | 9.93 | **17.2×** | 0.73 | 9.72 | **13.4×** |
| Curve Rect (4D) | 0.56 | 3.54 | **6.6×** | – | – | – |
| Spring Rect (4D) | 0.98 | 15.6 | **16.0×** | 1.35 | 14.9 | **11.3×** |
| Curve Color (4D) | 0.57 | 3.81 | **6.7×** | – | – | – |
| Spring Color (4D) | 1.04 | 13.5 | **12.9×** | 1.49 | 13.1 | **8.9×** |

### Memory (profile)

| Scenario | Allocated B/frame: Flutter | Motor | Motor / Flutter | Retained KB: Flutter | Motor | Motor / Flutter |
|---|---:|---:|---:|---:|---:|---:|
| Curve 1D ×1 | 499 | 915 | 1.83× | 1.00 | 3.59 | 3.59× |
| Curve 1D ×10 | 4,227 | 2,451 | 0.58× | 9.19 | 19.6 | 2.13× |
| Curve 1D ×50 | 20,099 | 9,235 | 0.46× | 45.4 | 90.4 | 1.99× |
| Curve 1D ×250 | 96,643 | 42,771 | 0.44× | 225 | 441 | 1.96× |
| Curve 1D ×1000 | 385,635 | 168,915 | 0.44× | 899 | 1,761 | 1.96× |
| Spring 1D ×1 | 531 | 867 | 1.63× | 0.95 | 3.64 | 3.82× |
| Spring 1D ×10 | 4,547 | 1,971 | 0.43× | 8.34 | 20.1 | 2.41× |
| Spring 1D ×50 | 21,699 | 6,835 | 0.31× | 41.0 | 92.8 | 2.26× |
| Spring 1D ×250 | 104,643 | 30,771 | 0.29× | 203 | 453 | 2.23× |
| Spring 1D ×1000 | 417,635 | 120,915 | 0.29× | 813 | 1,808 | 2.22× |
| Curve Offset (2D) | 643 | 1,043 | 1.62× | 0.97 | 4.05 | 4.18× |
| Spring Offset (2D) | 915 | 947 | 1.03× | 1.88 | 4.14 | 2.21× |
| Curve Rect (4D) | 579 | 1,219 | 2.10× | 0.97 | 4.58 | 4.73× |
| Spring Rect (4D) | 1,603 | 1,027 | 0.64× | 3.48 | 4.77 | 1.37× |
| Curve Color (4D) | 579 | 1,219 | 2.10× | 0.97 | 4.58 | 4.73× |
| Spring Color (4D) | 1,603 | 1,027 | 0.64× | 3.48 | 4.77 | 1.37× |

Each `AnimationController` allocates about 400 B per frame (ticker
bookkeeping and elapsed-time objects). Motor allocates about 750 B per
controller plus 120 to 170 B per track.

### Why AOT: the same ratios under `flutter test`

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

1. **Segment end search on every start and retarget.** This is by far the
   largest gap, and it is linear in tracks.
   - Use `Motion.duration` for curves, and a closed-form settle time for
     springs (the damping envelope).
   - Otherwise, bisect only to about 1 µs instead of to double precision.
   - Or resolve the end lazily, as long as ticking and seeking still agree.
2. **Curve velocity every frame.** `CurveSimulation.dx` costs two extra curve
   evaluations per dimension per frame.
   - Compute velocity only when it's needed: on read, or when a retarget
     inherits it.
   - For multi-dimensional tracks whose dimensions share one motion,
     evaluate the curve once and lerp, as a tween does.
3. **Per-controller fixed cost** (0.2 to 0.3 µs per frame) and spring reads
   (25 versus 13 ns). Both come from the slot lookup and denormalizing on each
   read.
4. **Retained memory:** about 1.8 KB per track, versus 0.8 to 0.9 KB per
   `AnimationController` with its `CurvedAnimation`.

## History

Before `36bee1f`, this file tracked per-phase numbers from the original
harness (definev, #307). That harness timed `WidgetTester.pump` under
`flutter test`, used a looping curve for multi-track, and read uncurved
`AnimationController.value`. Its tables live in git history
(`git show 36bee1f^:packages/motor/benchmark/ANALYSIS.md`). The widget
rebuild, manual `set` and velocity tracking scenarios were dropped with it.
They measured widget or `set` paths rather than the animation engine, and
they are in the same history.
