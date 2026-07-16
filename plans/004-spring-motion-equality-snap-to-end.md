# Plan 004: Include snapToEnd (and runtime shape) in SpringMotion equality; fix CupertinoMotion.copyWith

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat d36d4cb..HEAD -- packages/motor/lib/src/motion.dart packages/motor/test/src/motion_test.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW (stricter equality can only cause extra — correct — restarts)
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `d36d4cb`, 2026-07-14

## Why this matters

`SpringMotion` equality compares only the spring description's damping, mass,
and stiffness. `snapToEnd` — which changes observable settling behavior (exact
snap to target vs tolerance-stop) — is ignored. Motion equality is load-bearing
in 2.0: `TrackBuilder` uses deep equality of animations to decide whether a
rebuild restarts playback, `MotionController.motionPerDimension`'s setter
short-circuits on `motionsEqual`, and `Step`/`TrackAnimation` are `Equatable`
over their motions. Today, swapping `SpringMotion(desc, snapToEnd: true)` for
`snapToEnd: false` is silently ignored by all of these paths.

Additionally, `CupertinoMotion.copyWith` reads its defaults back through the
computed `SpringDescription` (`description.duration` / `description.bounce`)
instead of the stored fields, so every `copyWith` round-trips duration/bounce
through spring math and can drift numerically from what the user wrote.

## Current state

`packages/motor/lib/src/motion.dart`:

```481:494:packages/motor/lib/src/motion.dart
  @override
  bool operator ==(Object other) {
    if (other is SpringMotion) {
      return description.damping == other.description.damping &&
          description.mass == other.description.mass &&
          description.stiffness == other.description.stiffness;
    }
    return false;
  }

  /// Returns a hash code for this object.
  @override
  int get hashCode =>
      Object.hash(description.damping, description.mass, description.stiffness);
```

`snapToEnd` field: `motion.dart:436` (`final bool snapToEnd;`), used in
`createSimulation` (line 474, passed to `SpringSimulation`).

```630:641:packages/motor/lib/src/motion.dart
  @override
  CupertinoMotion copyWith({
    Duration? duration,
    double? bounce,
    bool? snapToEnd,
  }) {
    return CupertinoMotion(
      duration: duration ?? description.duration,
      bounce: bounce ?? description.bounce,
      snapToEnd: snapToEnd ?? this.snapToEnd,
    );
  }
```

Stored fields on `CupertinoMotion`: `duration` (line 617), `bounce`
(line 620). `description` is a computed getter
(`SpringDescription.withDurationAndBounce(...)`, lines 623–626).

Equality consumers (do not modify, just be aware):
- `packages/motor/lib/src/controllers/motion_controller.dart:503-509` — `motionsEqual`.
- `packages/motor/lib/src/widgets/track_builder.dart:136-142` — `_playbackChanged`.
- `packages/motor/lib/src/step.dart:84-85` — `StepTo.props` includes `motion`.

Existing tests for motion equality: `packages/motor/test/src/motion_test.dart`
(pattern to model after).

## Commands you will need

| Purpose | Command (from `packages/motor/`) | Expected on success |
|---------|----------------------------------|---------------------|
| Targeted tests | `flutter test test/src/motion_test.dart` | all pass |
| Full package tests | `flutter test` | all pass |
| Analyze | `dart analyze --fatal-infos` | exit 0 |

## Scope

**In scope**:
- `packages/motor/lib/src/motion.dart` (SpringMotion `==`/`hashCode`,
  `CupertinoMotion.copyWith` only)
- `packages/motor/test/src/motion_test.dart` (extend)
- `packages/motor/CHANGELOG.md`

**Out of scope** (do NOT touch):
- `CurvedMotion`/`TrimmedMotion`/`FixedDurationMotion` equality — already
  correct for their fields.
- `tolerance` in equality: `tolerance` is deliberately excluded today across
  all motion types; changing that is a broader decision — leave it, but note
  it in the CHANGELOG entry as a known limitation if you touch nearby docs.
- Widget/controller equality consumers listed above.

## Git workflow

Colocated jj repo: use `jj` for VCS mutations in the main workspace; plain git
in an isolated worktree. Message: `fix(motor): include snapToEnd in SpringMotion equality`.

## Steps

### Step 1: Extend SpringMotion equality

In `motion.dart`, change `SpringMotion.==` and `hashCode` to include
`snapToEnd`:

```dart
@override
bool operator ==(Object other) {
  if (other is SpringMotion) {
    return description.damping == other.description.damping &&
        description.mass == other.description.mass &&
        description.stiffness == other.description.stiffness &&
        snapToEnd == other.snapToEnd;
  }
  return false;
}

@override
int get hashCode => Object.hash(
      description.damping,
      description.mass,
      description.stiffness,
      snapToEnd,
    );
```

Keep the cross-subtype semantics (a `CupertinoMotion` and a
`MaterialSpringMotion` with identical physics still compare equal) — that is
current, documented behavior (doc comment at lines 477–480); only `snapToEnd`
is added.

**Verify**: `dart analyze --fatal-infos` → exit 0.

### Step 2: Fix CupertinoMotion.copyWith defaults

Replace `description.duration` / `description.bounce` with the stored fields:

```dart
return CupertinoMotion(
  duration: duration ?? this.duration,
  bounce: bounce ?? this.bounce,
  snapToEnd: snapToEnd ?? this.snapToEnd,
);
```

**Verify**: `dart analyze --fatal-infos` → exit 0.

### Step 3: Tests

Extend `packages/motor/test/src/motion_test.dart`:

1. `SpringMotion(desc) == SpringMotion(desc, snapToEnd: false)` → `isFalse`;
   hashCodes differ.
2. `CupertinoMotion(duration: d, bounce: b) == CupertinoMotion.smooth(...)`
   with identical physics and same snapToEnd → still `isTrue` (guard the
   cross-subtype behavior).
3. `CupertinoMotion(duration: 320ms, bounce: 0.2).copyWith(snapToEnd: false)`
   → `.duration == 320ms` and `.bounce == 0.2` exactly (`equals`, not
   `closeTo` — the fix makes them exact).
4. Behavioral guard: `MotionController.motionPerDimension = [same spring with
   different snapToEnd]` triggers a redirect (was silently ignored). If
   setting up a controller test here is heavy, an equality-level test
   (`motionsEqual([a], [b])` is false) in `motion_test.dart` is acceptable —
   `motionsEqual` is exported `@internal` from
   `package:motor/src/controllers/motion_controller.dart`.

**Verify**: `flutter test test/src/motion_test.dart` → all pass.

### Step 4: CHANGELOG

Under "Unreleased" → "### Fixes": note that spring motions differing only in
`snapToEnd` now compare unequal (affects rebuild-restart detection), and that
`CupertinoMotion.copyWith` no longer round-trips duration/bounce through
`SpringDescription`.

**Verify**: `flutter test` (whole package) → all pass. If any *existing* test
fails after Step 1, examine whether it relied on snapToEnd-insensitive
equality; fix the test only if its intent was clearly "same physics ⇒ equal",
otherwise STOP.

## Test plan

Four new cases in `motion_test.dart` (listed in Step 3), full suite green.

## Done criteria

- [ ] `flutter test` exits 0
- [ ] `dart analyze --fatal-infos` exits 0
- [ ] `grep -n "description.duration" packages/motor/lib/src/motion.dart`
      shows no match inside `CupertinoMotion.copyWith` (the `SpringMotion.duration`
      getter at line ~427 still legitimately uses `description.duration`)
- [ ] CHANGELOG updated
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- More than 2 existing tests fail after Step 1 — that suggests snapToEnd
  equality is load-bearing somewhere unexpected; report the failures.
- Golden tests change — equality changes must not alter any rendered frame.
- You find `snapToEnd` also missing from another motion type's equality
  (report, don't expand scope).

## Maintenance notes

- `tolerance` remains excluded from all motion equality — a deliberate gap to
  revisit if anyone ever varies tolerances at runtime.
- If a future `MaterialSpringMotion.copyWith`-style API gets `snapToEnd`
  handling, mirror the stored-field pattern from Step 2.
