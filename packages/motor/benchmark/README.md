# Motor vs AnimationController benchmarks

Compares [motor](../) with the `AnimationController` setup you would write
for the same motion.

## Results

Motor ÷ `AnimationController` time for the same motion, from AOT release
builds (Flutter 3.44.1, Linux, 8 vCPU Xeon; median of 7 runs over 5
invocations). Below 1× means motor is cheaper.

| | Motor ÷ Flutter |
|---|---:|
| Per frame, 10 to 1000 values on one controller (curves or springs) | 0.89× to 1.06× |
| Per frame, a single value | about 1.8× (about 0.2 µs) |
| Per frame, multi-dimensional springs / curves | 0.94× to 1.39× / 1.8× to 2.15× |
| Starting a motion | 2.1× to 4.2× |
| Retargeting a spring | 1.4× to 3.1× |
| Following a drag with velocity tracking, 250 values / 1 value | 1.2× to 1.5× / about 2× |
| Handing the tracked velocity to a fling | 0.7× to 1.4× |

At scale motor allocates less per frame (0.25× to 0.31× at 1000 values),
while each track retains about 1.5 KB, about twice an `AnimationController`.

## Run

```sh
# AOT desktop build (Linux or macOS), the numbers to publish:
melos run benchmark
BENCH_BUILD=profile melos run benchmark   # adds allocation numbers

# Smoke run under flutter test (JIT, ~10 s), for CI:
melos run benchmark:smoke
```

Or from this directory: `./tool/run_aot.sh`, or
`BENCH_QUICK=1 flutter test test/run_benchmarks_test.dart`.

Environment variables:

| Variable | Effect |
|---|---|
| `BENCH_QUICK=1` | 2 runs × 30 frames instead of 7 × 240 |
| `BENCH_FILTER=spring_1d,curve_offset` | Only these ids, or ids starting with `<prefix>_` |
| `BENCH_RUNS`, `BENCH_FRAMES`, `BENCH_WARMUP` | Override runs, frames per run and warmup frames |
| `BENCH_JSON=path` | JSON output (default `results/latest.json`) |
| `BENCH_BUILD=profile` | AOT profile build; enables allocation profiling |
| `BENCH_ALLOC=0` | Skip allocation profiling |

`run_aot.sh` generates the desktop runner (`linux/` or `macos/`, gitignored)
on first use. Linux needs the usual Flutter desktop packages (clang, cmake,
ninja, GTK 3 headers, libstdc++ for the newest installed GCC) and a display.

## Scenarios

| Id | Motor | Flutter equivalent |
|---|---|---|
| `curve_1d_x{1,10,50,250,1000}` | 1 `TrackController`, N `CurvedMotion` tracks | N `AnimationController` + `CurvedAnimation` |
| `spring_1d_x{…}` | 1 `TrackController`, N spring tracks | N unbounded `AnimationController` + `SpringSimulation` |
| `curve_{offset,rect,color}` | 1 multi-dimensional track | 1 `AnimationController` + `CurvedAnimation` + tween |
| `drag_{tracked,untracked}_{1d,offset}_x{1,250}` | `set` every frame, velocity tracking on or off, then a fling | `AnimationController.value =` + one `VelocityTracker` per value (or none), then `animateWith` |
| `spring_{offset,rect,color}` | 1 multi-dimensional track | 1 `AnimationController` per dimension |

Every run checks that both sides read the same values after warmup, and fails
if they don't.
