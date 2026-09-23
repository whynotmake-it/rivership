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

| Scenario | Baseline pump | Phase 0.5 pump | Phase 1 pump | Baseline tick | Phase 0.5 tick | Phase 1 tick |
|---|---:|---:|---:|---:|---:|---:|
| Single curve (1D) | +15.4% | -2.4% | +17.2% | +135.6% | +190.3% | +175.0% |
| Single spring (1D) | +8.6% | -2.1% | +7.1% | +224.2% | +250.0% | +268.7% |
| Offset spring (2D) | +7.9% | +4.0% | +6.7% | +354.1% | +327.5% | +333.3% |
| Multi-track ×1 | +1.1% | -0.4% | -0.3% | +85.5% | +155.4% | +154.7% |
| Multi-track ×10 | +11.5% | +4.9% | +3.4% | +226.4% | +296.6% | +237.5% |
| Multi-track ×50 | +18.5% | -2.5% | +2.6% | +167.9% | +236.1% | +211.5% |
| Multi-track ×100 | +24.6% | -0.3% | +3.7% | +196.4% | +247.5% | +261.8% |
| Multi-track ×250 | +38.3% | +10.0% | +4.9% | +208.2% | +302.7% | +274.8% |
| Multi-track ×500 | +62.5% | +13.2% | +21.6% | +254.1% | +304.7% | +321.9% |
| Interrupt / retarget | +21.9% | +23.8% | +35.7% | +129.9% | +170.5% | +200.0% |
| Widget rebuild | -32.2% | -32.8% | -32.8% | +6.1% | -12.1% | -8.8% |
| Manual set (tracking off) | n/a | n/a | n/a | +2.6% | +45.0% | +64.4% |
| Velocity tracking on vs off | n/a | n/a | n/a | +4732% | +2736% | +3064% |

- **Baseline**: `motor/2.0` at `3d517dd`, before any performance work.
- **Phase 0.5**: `ebb9068`. It adds in-place sampling, lazily cached
  denormalized values, a reused tick list, lazy velocity estimates, and a
  single clock read per tracked sample.
- **Phase 1**: `5e91da1`, the monotonic playback clock. It only changes
  bookkeeping, so the differences from Phase 0.5 are run-to-run noise.
  Motor's absolute pump time per frame is unchanged, for example single
  curve 75.8 µs versus 74 to 83 µs across the Phase 0.5 runs, and
  interrupt/retarget 45.6 µs versus 44.6 to 46.8 µs. The larger interrupt Δ
  comes from a faster `AnimationController` run.

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
