# Analysis: Motor vs AnimationController

Harness by [definev](https://github.com/definev) (fork PR #307). Numbers below
come from `flutter test test/run_benchmarks_test.dart` (full config: warmup 60,
measure 240 frames, 7 repeats, `BENCH_MODE=both`) on a Linux cloud VM, Flutter
3.44.1, debug VM under `WidgetTester`. Compare the Δ columns (positive = Motor
slower); absolute µs mostly measure the harness.

What the layers measure:

- **pump**: wall time of `tester.pump` per frame, including ticking every
  simulation, notifying listeners, and framework scheduling. This is the best
  proxy for real per-frame cost.
- **tick**: time spent in `read()` inside the listener, i.e. reading values.
  It does not include advancing simulations.

## Results per phase (p50 Δ vs AnimationController)

| Scenario | Baseline pump | Phase 0.5 pump | Baseline tick | Phase 0.5 tick |
|---|---:|---:|---:|---:|
| Single curve (1D) | +15.4% | -2.4% | +135.6% | +190.3% |
| Single spring (1D) | +8.6% | -2.1% | +224.2% | +250.0% |
| Offset spring (2D) | +7.9% | +4.0% | +354.1% | +327.5% |
| Multi-track ×1 | +1.1% | -0.4% | +85.5% | +155.4% |
| Multi-track ×10 | +11.5% | +4.9% | +226.4% | +296.6% |
| Multi-track ×50 | +18.5% | -2.5% | +167.9% | +236.1% |
| Multi-track ×100 | +24.6% | -0.3% | +196.4% | +247.5% |
| Multi-track ×250 | +38.3% | +10.0% | +208.2% | +302.7% |
| Multi-track ×500 | +62.5% | +13.2% | +254.1% | +304.7% |
| Interrupt / retarget | +21.9% | +23.8% | +129.9% | +170.5% |
| Widget rebuild | -32.2% | -32.8% | +6.1% | -12.1% |
| Manual set (tracking off) | n/a | n/a | +2.6% | +45.0% |
| Velocity tracking on vs off | n/a | n/a | +4732% | +2736% |

- **Baseline**: `motor/2.0` at `3d517dd`, before any performance work.
- **Phase 0.5**: `ebb9068`. It adds in-place sampling, lazily cached
  denormalized values, a reused tick list, lazy velocity estimates, and a
  single clock read per tracked sample.

Reading the table:

- Per-frame cost (pump) improved most where it matters: many tracks on one
  controller. At 500 tracks the gap went from +62.5% to +13.2%.
- The tick layer is noisy at this scale (sub-microsecond values, p90 often
  2x the p50), so run-to-run swings of tens of percent are common. Sustained
  signals: reads cost more than `AnimationController.value` because each read
  looks a track up and denormalizes it, and tracked velocity still costs about
  3 µs per `set`. Most of that is the `clock.now()` inside
  `MotionVelocityTracker.addPosition`.
- The fork's original report measured -12% at 500 tracks after its changes,
  but on different hardware. It also included buffer aliasing between
  playback and slots, which is unsafe with converters that keep their lists,
  so that part was not adopted.

## Next targets

- Interrupt/retarget: each retarget builds a new playback and simulations.
  The segment-table redesign (plan phase 2) should reduce this.
- Value reads: the per-track slot lookup and denormalization.
- Velocity tracking: sample time comes from `clock.now()` inside the
  tracker; avoiding the second clock read needs a tracker API change.
