# Plan 006: Skip duration probing in TrimmedMotion when the parent duration is known; document wrapper cost

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat d36d4cb..HEAD -- packages/motor/lib/src/motion.dart packages/motor/test/src/motion_test.dart packages/motor/test/src/motion_curve_test.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: perf + docs
- **Planned at**: commit `d36d4cb`, 2026-07-14

## Why this matters

`estimateSimulationDuration` runs an exponential search plus 24 binary-search
iterations, each evaluating the parent simulation — roughly 30–60 simulation
evaluations per call. `TrimmedMotion.createSimulation` pays this on **every**
simulation creation, even when the parent motion reports an exact
`Motion.duration` (all curves, linear, none, and springs report a
characteristic duration). Spanning sequences create a trimmed simulation per
phase transition, and any motion wrapper recreated per animation start pays it
again. `FixedDurationMotion` already implements the correct pattern (use
`parent.duration` when known, probe as fallback); `TrimmedMotion` doesn't.

Second, the docs never warn that wrapper motions (`scaleTo`, `.trimmed()`,
`.sliced()`, `.segment()`) should be constructed once and reused rather than
rebuilt in hot paths — the wrappers are immutable and value-equatable, so
hoisting them is free.

## Current state

`packages/motor/lib/src/motion.dart`.

The pattern to copy — `FixedDurationMotion.createSimulation`:

```908:915:packages/motor/lib/src/motion.dart
    return _FixedDurationSimulation(
      parent: parentSimulation,
      duration: duration,
      start: start,
      end: end,
      sourceDuration: parent.duration?.toSeconds() ??
          estimateSimulationDuration(parentSimulation, fallback: duration),
    );
```

The offender — `TrimmedMotion.createSimulation`:

```1241:1253:packages/motor/lib/src/motion.dart
    return _TrimmedSimulation(
      parent: scaledSim,
      startTrim: fromStart,
      endTrim: fromEnd,
      trimmedExtent: trimmedExtent,
      start: start,
      end: end,
      parentDuration: estimateSimulationDuration(
        scaledSim,
        fallback: const Duration(seconds: 1),
        max: const Duration(seconds: 10),
      ),
    );
```

Notes:
- `Motion.duration` (getter, lines 147–156) returns exact durations for
  curves/linear/none, the characteristic settling time for springs, `null`
  when unknown. For springs the characteristic duration is an *approximation*
  of when the simulation isDone — see caveat in Step 1.
- `TrimmedMotion.duration` (lines 1205–1212) already scales
  `parent.duration` by the trimmed extent — don't confuse it with the
  *parent* simulation duration needed here.
- `estimateSimulationDuration` doc (lines 42–53) already calls itself "an
  expensive fallback".
- `Duration.toSeconds()` is a private extension at the bottom of the file
  (lines 1406–1408).

Doc locations for the reuse guidance:
- `MotionBase.scaleTo` declaration: lines 39–40 (one-line doc).
- `MotionTrimming` extension doc: lines 1339–1348.
- README "Motion" section: `packages/motor/README.md:47-77`.

Existing tests: `packages/motor/test/src/motion_test.dart` and
`packages/motor/test/src/motion_curve_test.dart` cover trimmed/sliced behavior
numerically — they are the regression net for Step 1.

## Commands you will need

| Purpose | Command (from `packages/motor/`) | Expected on success |
|---------|----------------------------------|---------------------|
| Targeted tests | `flutter test test/src/motion_test.dart test/src/motion_curve_test.dart` | all pass |
| Full package tests | `flutter test` | all pass |
| Analyze | `dart analyze --fatal-infos` | exit 0 |

## Scope

**In scope**:
- `packages/motor/lib/src/motion.dart` (`TrimmedMotion.createSimulation`,
  dartdoc on `scaleTo` / `MotionTrimming`)
- `packages/motor/test/src/motion_test.dart` (extend)
- `packages/motor/README.md` (one short paragraph)
- `packages/motor/CHANGELOG.md`

**Out of scope** (do NOT touch):
- `FixedDurationMotion` / `FixedDurationFreeMotion` — the free variant *must*
  probe (free motions have no target duration; the probe also computes the
  rest position via `simulation.x(sourceDuration)`), and the fixed variant
  already skips when it can.
- `estimateSimulationDuration` itself.
- Memoizing estimates on motion instances — rejected: the estimate depends on
  `start`/`end`/`velocity`, so an instance-level cache would need a keyed map
  with unbounded growth for marginal benefit. Documenting reuse + this skip
  captures most of the win.

## Git workflow

Colocated jj repo: use `jj` for VCS mutations in the main workspace; plain git
in an isolated worktree. Message:
`perf(motor): skip duration probing in TrimmedMotion for known-duration parents`.

## Steps

### Step 1: Use parent.duration in TrimmedMotion.createSimulation

Replace the `parentDuration:` argument:

```dart
parentDuration: switch (parent.duration) {
  final d? when !parent.needsSettle => d.toSeconds(),
  final d? => estimateSimulationDuration(
      scaledSim,
      fallback: d,
      max: const Duration(seconds: 10),
    ),
  null => estimateSimulationDuration(
      scaledSim,
      fallback: const Duration(seconds: 1),
      max: const Duration(seconds: 10),
    ),
},
```

Rationale for the middle case: springs report a *characteristic* duration,
not the exact `isDone` time; using it directly would change trimmed-spring
output. Instead, feed it as the probe's `fallback`, which seeds the
exponential search near the answer and cuts most doubling iterations while
keeping identical results. For fixed-duration parents (`needsSettle == false`
⇒ curves/linear/none/fixed wrappers) the duration is exact and the probe is
skipped entirely.

**Verify**: `flutter test test/src/motion_test.dart test/src/motion_curve_test.dart`
→ all pass with **no expectation changes** (output must be identical for
deterministic parents).

### Step 2: Equivalence test

Add to `motion_test.dart`: for
`CurvedMotion(Duration(seconds: 1), Curves.easeInOut).trimmed(fromStart: 0.2, fromEnd: 0.1)`,
sample `x(t)` and `dx(t)` at t = 0, 0.1, 0.35, 0.7 (seconds) and assert they
equal the values produced before this change (compute expected values from the
trimming math, or pin them as literals with `closeTo(..., 1e-9)`). Also add a
spring-parent case (`CupertinoMotion()` trimmed) asserting `x` at a few sample
points matches `closeTo` the pre-change behavior — capture the literals by
running the test *before* applying Step 1 if practical; otherwise assert
structural properties (starts at `start`, ends at `end`, `isDone` monotonic).

**Verify**: `flutter test test/src/motion_test.dart` → all pass.

### Step 3: Document wrapper construction cost and reuse

1. `MotionBase.scaleTo` dartdoc (motion.dart:39–40): expand to note that
   wrappers of motions with unknown duration probe the simulation on each
   `createSimulation`; construct wrappers once (fields/constants) and reuse
   them rather than rebuilding in `build` or per frame; they are immutable and
   compare by value.
2. `MotionTrimming` extension doc (lines 1339–1348): same note, one sentence.
3. README, end of the "Motion" section (~line 77): add a short "**Tip:**"
   paragraph: motions and their wrappers are immutable value objects — declare
   them `const`/`static final` and reuse; wrappers like `scaleTo`/`trimmed`
   probe simulation durations when the underlying duration is unknown, so
   avoid re-creating them in hot paths.

**Verify**: `dart analyze --fatal-infos` → exit 0 (dartdoc syntax valid).

### Step 4: CHANGELOG

"Unreleased" → add a **PERF** entry: `TrimmedMotion` no longer probes the
parent simulation's duration when the parent reports a fixed duration, and
uses the spring's characteristic duration to seed the probe otherwise.

**Verify**: `flutter test` (whole package) → all pass.

## Test plan

- Step 2's equivalence tests (deterministic parent exact; spring parent
  `closeTo`).
- Existing `motion_test.dart` / `motion_curve_test.dart` trimming tests pass
  unchanged — this is the primary gate that behavior is preserved.

## Done criteria

- [ ] `flutter test` exits 0 with no expectation changes to existing tests
- [ ] `dart analyze --fatal-infos` exits 0
- [ ] `TrimmedMotion.createSimulation` no longer unconditionally calls
      `estimateSimulationDuration` (read the diff)
- [ ] README + dartdoc reuse guidance added
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Any existing trimming test's expected values change — behavior must be
  identical; a change means the `needsSettle` branch condition is wrong.
- `parent.duration` for some `Motion` subtype returns a value that is *not*
  its simulation duration for deterministic motions (check `NoMotion.duration`
  and `FixedDurationMotion.duration` — both are exact).
- Golden tests change.

## Maintenance notes

- If a future `Motion` subtype reports `duration` but `needsSettle == false`
  while its simulation actually runs longer (a contract violation), trimming
  output will clip — the equivalence tests in Step 2 are the tripwire.
- The rejected memoization idea is recorded in Scope; revisit only with
  profiling evidence from a real app.
