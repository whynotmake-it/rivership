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

### Pump (per-frame cost)

| Scenario | Baseline | Phase 0.5 | Phase 1 | Phase 2 | Phase 3 | Phase 4 |
|---|---:|---:|---:|---:|---:|---:|
| Single curve (1D) | +15.4% | -2.4% | +17.2% | +19.0% | +20.2% | +19.0% |
| Single spring (1D) | +8.6% | -2.1% | +7.1% | +3.1% | +6.0% | +8.1% |
| Offset spring (2D) | +7.9% | +4.0% | +6.7% | +3.7% | +5.5% | +5.9% |
| Multi-track ×1 | +1.1% | -0.4% | -0.3% | +5.4% | -1.3% | +1.2% |
| Multi-track ×10 | +11.5% | +4.9% | +3.4% | +3.6% | +3.2% | +1.7% |
| Multi-track ×50 | +18.5% | -2.5% | +2.6% | -2.2% | +1.5% | -2.7% |
| Multi-track ×100 | +24.6% | -0.3% | +3.7% | -2.1% | +0.8% | -2.6% |
| Multi-track ×250 | +38.3% | +10.0% | +4.9% | +11.0% | +5.7% | +5.4% |
| Multi-track ×500 | +62.5% | +13.2% | +21.6% | +16.2% | +16.8% | +20.1% |
| Interrupt / retarget | +21.9% | +23.8% | +35.7% | +37.0% | +44.1% | +34.5% |
| Widget rebuild | -32.2% | -32.8% | -32.8% | -26.0% | -25.9% | -32.2% |

### Tick (value reads)

| Scenario | Baseline | Phase 0.5 | Phase 1 | Phase 2 | Phase 3 | Phase 4 |
|---|---:|---:|---:|---:|---:|---:|
| Single curve (1D) | +135.6% | +190.3% | +175.0% | +140.8% | +203.1% | +130.7% |
| Single spring (1D) | +224.2% | +250.0% | +268.7% | +245.2% | +264.7% | +289.7% |
| Offset spring (2D) | +354.1% | +327.5% | +333.3% | +340.0% | +293.3% | +352.6% |
| Multi-track ×1 | +85.5% | +155.4% | +154.7% | +74.6% | +141.3% | +88.9% |
| Multi-track ×10 | +226.4% | +296.6% | +237.5% | +246.2% | +222.6% | +230.2% |
| Multi-track ×50 | +167.9% | +236.1% | +211.5% | +208.5% | +198.5% | +202.3% |
| Multi-track ×100 | +196.4% | +247.5% | +261.8% | +232.3% | +234.3% | +238.6% |
| Multi-track ×250 | +208.2% | +302.7% | +274.8% | +285.3% | +291.2% | +296.4% |
| Multi-track ×500 | +254.1% | +304.7% | +321.9% | +305.2% | +303.0% | +295.0% |
| Interrupt / retarget | +129.9% | +170.5% | +200.0% | +225.6% | +264.8% | +223.6% |
| Widget rebuild | +6.1% | -12.1% | -8.8% | -15.8% | -12.2% | -42.3% |
| Manual set (tracking off, noise) | +2.6% | +45.0% | +64.4% | +274.9% | +279.5% | -3.6% |
| Velocity tracking on vs off | +4732% | +2736% | +3064% | +3484% | +3112% | +2876% |

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
- **Phase 2**: `c77fc41`..`3cc55f0`. The segment table, plus value reads
  without the Phase 0.5 cache. Pump is unchanged within noise (Motor at 500
  tracks: 157 to 160 µs, Phase 1: 160 to 163 µs). Value reads at 500 tracks
  recovered: 14.8 to 15.0 µs in the full suite (Phase 0.5: 15.6 to 16.0 µs)
  and 11.8 to 12.0 µs in filtered runs (baseline: 12.5 to 13.0 µs, Phase
  0.5: 15.6 to 17.0 µs).
- **Phase 3**: `73eb665`..`28073f3`. Exact barrier release, estimates from
  resolving plans ahead, deterministic segment ends, continuous `.at`, and
  `onStep` for every step. Pump is unchanged within noise except
  interrupt/retarget: Motor 47.6 µs per frame (Phase 2: 44.5 to 45.8 µs).
  Each retarget now scans its new segment's end once up front (1/60 s
  steps), which makes ticking and seeking agree for bouncy springs.
- **Phase 4**: `0e9de07`..`2e261c2`. Plan history, archived plans for
  scrubbing, segments in snapshots, and the devtools hooks. All of these
  only keep data while an inspection observer is attached. In a 3-run A/B
  against Phase 3, Motor at 500 tracks is 164 to 169 µs per frame versus
  157 to 161 µs (about +3%), likely the per-frame archive bookkeeping in
  each track slot. Interrupt/retarget is unchanged at about 45 µs.

Reading the table:

- Per-frame cost (pump) improved most where it matters: many tracks on one
  controller. At 500 tracks the gap went from +62.5% to +13.2%.
- Value reads at many tracks got about 25% slower in Phase 0.5 (500 tracks:
  12.5 to 13.6 µs became 15.6 to 17.0 µs). The lazy value cache was the
  cause: maintaining it every frame cost more than it saved. Phase 2 removed
  it, and filtered runs are now slightly below the baseline.
- The small single-value tick rows are noisy (sub-microsecond values, p90
  often 2x the p50), so run-to-run swings of tens of percent are common.
- Manual set is noise, not a regression: filtered reruns measure +97% to
  +130% at the baseline and +107% to +140% after Phase 0.5, and the
  full-suite value depends on scenario order (-3%, +111%, +10% in three
  runs).
- Reads cost more than `AnimationController.value` in general because each
  read looks a track up and denormalizes it. Tracked velocity still costs
  about 3 µs per `set`, mostly the `clock.now()` inside
  `MotionVelocityTracker.addPosition`.
- The fork's original report measured -12% at 500 tracks after its changes,
  but on different hardware. It also included buffer aliasing between
  playback and slots, which is unsafe with converters that keep their lists,
  so that part was not adopted.

## Next targets

- Interrupt/retarget: each retarget builds a new playback and simulations,
  and since Phase 3 also scans the new segment's end. Knowing a spring's
  settle time analytically would cut the scan.
- Value reads: the per-track slot lookup and denormalization.
- Velocity tracking: sample time comes from `clock.now()` inside the
  tracker; avoiding the second clock read needs a tracker API change.
