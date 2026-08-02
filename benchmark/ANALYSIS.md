# Analysis report: Motor vs AnimationController

**Source:** `benchmark/results/full.json` (also `latest.json`)  
**Config:** full — warmup 60, measure 240 frames, 7 repeats, `BENCH_MODE=both`  
**Date:** 2026-08-02  
**Code:** after P1 (in-place sample + buffer alias + `growable: false`) + P2 (eager `T` cache, reuse `_waypoints`, scratch list each tick)

Positive Δ = Motor slower. Layer **tick** = notify + value read; layer **pump** = wall time of `tester.pump`.

## Verdict

Motor is at **parity or faster** on most practical paths. Multi-track beats Flutter on pump from ~50 tracks (×500: **−11.8%**). 1D spring is **−2%** pump. Interrupt improved clearly (pump **+27%**, ~+48% before P2). `VelocityTracking.on` is still ~8× vs off.

## Main results (p50)

| Scenario | Tick Δ | Pump Δ |
|---|---:|---:|
| Single curve (1D) | +170% | **+11.3%** |
| Single spring (1D) | +220% | **−2.0%** |
| Offset spring (2D) | +240% | **+4.8%** |
| Interrupt / retarget | +167% | **+27.0%** |
| Widget rebuild | **−23%** | **−22.9%** |
| Manual set (vel off) | +271% | — |
| Velocity tracking on vs off | **+723%** | — |

### Multi-track scale

| Tracks | Pump Δ | Tick Δ | Flutter pump | Motor pump |
|---:|---:|---:|---:|---:|
| 1 | +0.7% | +163% | 23.9 | 24.1 |
| 10 | +7.0% | +317% | 25.0 | 26.8 |
| 50 | **−9.7%** | +220% | 33.4 | 30.2 |
| 100 | **−8.2%** | +196% | 41.8 | 38.4 |
| 250 | **−12.1%** | +249% | 69.4 | 61.0 |
| 500 | **−11.8%** | +234% | 107.0 | 94.4 |

### vs full suite before P2

| Metric | Pre-P2 | Post-P2 |
|---|---:|---:|
| Spring 1D pump | +0.2% | **−2.0%** |
| Offset 2D pump | +1.0% | +4.8% |
| Interrupt pump | +47.9% | **+27.0%** |
| Widget rebuild pump | −18.3% | **−22.9%** |
| Multi ×500 pump | −17.6% | −11.8% |
| Velocity tracking | +722% | +723% |

Interrupt benefits clearly from waypoint reuse and fewer allocs on step changes. Multi ×500 still favors Motor; a few % of run-to-run swing is harness noise.

## By group

- **Parity (curve/spring/offset):** Pump ~−2–+11% — fine for normal UI.
- **Multi-track:** Cross-over around ~50 tracks; Motor faster as N grows.
- **Interrupt:** +27% pump — much better than +48% before P2.
- **Widget rebuild:** Motor ~23% faster on both tick and pump.
- **Velocity tracking:** Enable only when you need gesture velocity estimates.

## Recommendations

1. **P0** — Default `VelocityTracking.off` except on gesture paths.  
2. **P1** ~~— Cut allocs in `_TrackSlot.tick`.~~ **Done**  
3. **P2** ~~— Cache denormalized values / cut short-lived allocs.~~ **Done**  
4. **P3** ~~— Full suite.~~ **Done**  
5. **Optional** — Mutable/pooled `Simulation` if dense interrupt/retarget still shows up in profiles.

## Harness note

Status-driven spring ping-pong must listen for both `completed` and `dismissed` (Motor reports `dismissed` when settling back to `initialValue`).

## Limits

Debug VM · WidgetTester (not AOT device) · tick does not include all simulation advance before notify · n=7. Guidance for hot-path design, not a production SLA.

Canvas: `canvases/motor-bench-analysis.canvas.tsx`
