# Motor vs AnimationController benchmarks

Microbenchmark suite comparing [motor](../packages/motor) to Flutter's
`AnimationController`.

Absolute µs include harness noise — read **Δ p50** (and p90 Δ). Prefer larger
multi-track counts; `BENCH_QUICK=1` is smoke only.

## Layers (`BENCH_MODE`)

| Mode | Measures |
|---|---|
| `tick` | Time inside the animation listener (notify + value read) |
| `pump` | Wall time of `tester.pump` loops (framework + tick) |
| `both` (default) | Record both layers per run |

## Scenarios

| ID | Comparison |
|---|---|
| `single_curve` | Looping curve, 1D |
| `single_spring` | Status-driven spring ping-pong (matched hot path) |
| `offset_spring` | Offset spring vs 2× AC |
| `multi_track_1/10/50/100/250/500` | 1 ticker × N tracks vs N controllers |
| `interrupt_retarget` | Mid-flight retarget |
| `widget_rebuild` | `TrackBuilder` vs `AnimatedBuilder` |
| `manual_set` | `set` (velocity off) vs `AC.value=` |
| `velocity_tracking_overhead` | Motor tracking on vs off |

## Run

```sh
cd benchmark
flutter pub get

# Full suite (debug VM — compare Δ, not absolute µs):
flutter test test/run_benchmarks_test.dart --reporter expanded

# Smoke:
BENCH_QUICK=1 flutter test test/run_benchmarks_test.dart --reporter expanded

# Tick-only + multi-track scale + JSON:
BENCH_MODE=tick BENCH_FILTER=multi_track,single_curve \
  BENCH_JSON=results/multi.json \
  flutter test test/run_benchmarks_test.dart --reporter expanded
```

Also: `melos run benchmark` from the repo root.

## Output

- Markdown tables per layer: baseline/primary **p50**, **Δ p50**, **p90 Δ**
- JSON at `results/latest.json` (and `BENCH_JSON` if set)

## Guarantees

- Animations **must stay active** for the measured window (asserted)
- Spring sides both use **status-driven** retarget (same hot path shape)
- Filter prefixes match `id` or `id_*` (so `multi_track_10` does not eat `multi_track_100`)
- Controllers are **stopped** before dispose to avoid hanging the test binding
