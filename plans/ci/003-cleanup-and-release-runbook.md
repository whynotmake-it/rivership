# Plan 003: Fix the stale CI artifact name and write the RELEASING.md runbook

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/ci/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 4d16091..HEAD -- .github/workflows/main.yaml packages/motor/CHANGELOG.md packages/motor/README.md packages/motor/pubspec.yaml`
> If `main.yaml` changed since this plan was written, compare the "Current
> state" excerpt against the live file before proceeding; on a mismatch, treat
> it as a STOP condition. Motor file drift only affects the runbook's motor
> checklist — update the checklist to match reality rather than stopping,
> unless motor's version is no longer `1.1.0` (then STOP: the 2.0 release may
> already be underway).

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/ci/001-branch-aware-release-prepare-workflow.md,
  plans/ci/002-tag-and-publish-pipeline.md
- **Category**: dx | docs
- **Planned at**: commit `4d16091`, 2026-07-22

## Why this matters

Two loose ends after plans 001/002 land. First, a real bug:
`.github/workflows/main.yaml` names its golden-test-failure artifact with an
expression referencing a step that does not exist, so the artifact is always
named `golden-failures-`. Second, and more important: the new two-train
release process (dev = prereleases, main = stable graduations) exists only in
CI YAML and in `plans/ci/`; there is no in-repo document telling the
maintainer (or a future contributor) how to actually cut a release, how
CHANGELOGs flow from dev to main, why the back-merge matters, or what the
motor 2.0 first prerelease specifically requires. This plan fixes the bug and
writes `RELEASING.md`.

## Current state

- Plans 001/002 have landed (verify before starting — see STOP conditions):
  `.github/workflows/` contains `deploy.yaml`, `main.yaml`,
  `prepare-release.yaml` (branch-aware versioning: dispatch on `dev` →
  `melos version --prerelease`, on `main` → `melos version --graduate`, then a
  `chore(release): Publish packages` PR), `tag-release.yaml` (tags
  `<pkg>-v<version>` on `chore(release)` merge commits, pushing with the
  `RELEASE_PAT` secret), and `publish.yaml` (tag-triggered, publishes the
  tagged package to pub.dev via OIDC and creates a GitHub release).

- The artifact-name bug, `.github/workflows/main.yaml:50-58` at `4d16091`:

  ```yaml
        - name: Upload golden test failures
          if: failure()
          uses: actions/upload-artifact@v4
          with:
            name: golden-failures-${{ steps.pkg.outputs.basename }}
            path: |
              **/test/**/failures/**
            if-no-files-found: ignore
  ```

  There is no step with id `pkg` anywhere in `main.yaml` (verify:
  `grep -n "id: pkg" .github/workflows/main.yaml` → no matches), so the
  expression evaluates to an empty string. The job is a single non-matrix job
  (`flutter-check`), so a static name is sufficient and unique per run.

- Motor 2.0 facts the runbook must capture (as of `4d16091`):
  - `packages/motor/pubspec.yaml:3` → `version: 1.1.0`; pub.dev latest is
    also 1.1.0.
  - dev history (already merged into `dev` via PR #283 and follow-ups)
    contains breaking conventional commits, e.g.
    `feat(motor)!: add automatic velocity tracking with opt-out design` —
    so `melos version --prerelease` computes `2.0.0-dev.0` for motor.
  - `packages/motor/CHANGELOG.md:1` starts with a hand-written
    `## Unreleased` section holding the whole motor 2.0 narrative. Melos
    prepends its own generated `## 2.0.0-dev.0` section ABOVE it and will
    never fold the hand-written notes in.
  - `packages/motor/README.md:36` contains
    `<!-- TODO(release): verify pubspec version is 2.0.0 before publishing -->`
    above an install snippet already pinned to `motor: ^2.0.0`.

- Repo/process conventions the runbook must reflect:
  - The maintainer uses jj (Jujutsu, colocated) locally on top of git:
    branches are bookmarks often created at push time; local tagging or
    committing directly to long-lived branches must never be required. All
    release mechanics happen in CI via dispatched workflows, PRs, and
    CI-pushed tags — the runbook must only ever ask the human to click
    "Run workflow", review/merge PRs, and move/push the `dev` bookmark.
  - Conventional commits; PR titles enforced by the semantic-pull-request
    check in `main.yaml`.
  - Prerelease suffix is `-dev.N`; tags are `<package>-v<version>`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| YAML syntax check | `ruby -ryaml -e 'YAML.load_file(".github/workflows/main.yaml"); puts "ok"'` | prints `ok` |
| Stale-ref gone | `grep -rn "steps.pkg" .github/workflows/` | no matches |
| Runbook exists | `test -f RELEASING.md && head -1 RELEASING.md` | prints the H1 |
| Scope check | `git status --porcelain` | only in-scope files |

## Scope

**In scope** (the only files you should modify):
- `.github/workflows/main.yaml` (one line)
- `RELEASING.md` (create, repo root)
- `plans/ci/README.md` (status row only)

**Out of scope** (do NOT touch):
- `packages/motor/CHANGELOG.md`, `packages/motor/README.md`,
  `packages/motor/pubspec.yaml` — the runbook DOCUMENTS the steps a human
  takes on the release PR; pre-editing them here would desync version and
  changelog.
- `prepare-release.yaml`, `tag-release.yaml`, `publish.yaml`, `deploy.yaml`.
- `README.md` (repo root) — do not add release docs there; link targets can
  be added later by the maintainer.

## Git workflow

- Branch: `advisor/ci-003-cleanup-runbook`
- Conventional commits. Suggested: one commit
  `ci: fix golden-failure artifact name` and one
  `docs: add RELEASING.md for the dev/main release trains`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Fix the artifact name in `main.yaml`

In `.github/workflows/main.yaml`, change line 54 only:

```yaml
          name: golden-failures-${{ steps.pkg.outputs.basename }}
```

becomes

```yaml
          name: golden-failures
```

**Verify**: `grep -rn "steps.pkg" .github/workflows/` → no matches, and
`ruby -ryaml -e 'YAML.load_file(".github/workflows/main.yaml"); puts "ok"'`
→ `ok`.

### Step 2: Write `RELEASING.md`

Create `RELEASING.md` at the repo root. Structure and required content
(write it in the repo's plain, direct doc voice; keep it under ~120 lines):

```markdown
# Releasing

<!-- intro: two trains, one sentence each -->

## TL;DR

| I want to… | Do this |
|------------|---------|
| Ship prereleases of what's on dev | Actions → "Prepare release" → run on `dev` → review & merge the `chore(release)` PR |
| Ship stable versions | PR `dev` → `main`, merge it, then Actions → "Prepare release" → run on `main` → review & merge the `chore(release)` PR |
| After any stable release | Open and merge the back-merge PR `main` → `dev` |

## How the pipeline works
<!-- the chain: prepare-release.yaml (branch decides prerelease vs graduate,
     melos version + publish dry-run, opens PR) → merge → tag-release.yaml
     (tags <pkg>-v<version>, pushed with RELEASE_PAT so they trigger
     workflows) → publish.yaml per tag (pub.dev OIDC publish + GitHub
     release, -dev.N marked prerelease). Mention that versioning is
     conventional-commit-driven and scoped to changed packages, and that
     stable releases ONLY graduate prereleases: everything ships from dev
     first. -->

## Reviewing a release PR
<!-- what to check: each bumped package's version makes sense, CHANGELOG
     sections read well (edit them on the PR branch if not — the PR is the
     checkpoint), publish dry-run passed in the workflow run. -->

## CHANGELOG flow and the back-merge
<!-- prerelease entries accumulate on dev; --graduate on main rewrites to the
     stable version. After a stable release, main carries release commits dev
     does not have; merge main back into dev promptly (PR main → dev) or the
     next dev prerelease will double-bump versions that already shipped
     stable. Conflicts are rare because main only ever receives dev merges +
     release commits. -->

## jj notes
<!-- day-to-day: work on dev bookmark, push; never tag locally, never commit
     to main locally; main only moves via merged PRs. Back-merge PR can be
     created from the GitHub UI — no local branch juggling needed. -->

## Hotfixing a stable release
<!-- escape hatch for D7: land the fix on dev, prerelease it, then graduate
     on main. If dev has unreleasable work stacked, cut a temporary branch
     from main, but prefer keeping dev releasable. -->

## One-time setup (status)
<!-- checklist with checkboxes the maintainer ticks:
     - [ ] RELEASE_PAT secret (fine-grained PAT, Contents RW, this repo)
     - [ ] pub.dev automated publishing for each of the 8 packages
           (repository whynotmake-it/rivership, tag pattern
           <package>-v{{version}}): motor, heroine, rivership,
           rivership_test, scroll_drag_detector, snaptest,
           stupid_simple_sheet, fixed_ticker -->

## Motor 2.0 first prerelease checklist
<!-- - expect melos to compute 2.0.0-dev.0 (breaking feat(motor)! commits on
       top of motor-v1.1.0); STOP and investigate if the release PR shows a
       different motor version
     - on the release PR: fold packages/motor/CHANGELOG.md's hand-written
       "## Unreleased" narrative into the generated "## 2.0.0-dev.0" section
       (melos will NOT do this), delete the "## Unreleased" header
     - packages/motor/README.md:36 has a TODO(release) gate: the README
       install snippet says motor: ^2.0.0, which does NOT resolve to
       2.0.0-dev.N (semver orders prereleases below 2.0.0) — prerelease users
       must depend on motor: ^2.0.0-dev.0 explicitly; the snippet becomes
       accurate, and the TODO comment gets removed, when 2.0.0 graduates on
       main
     - after publish, verify https://pub.dev/packages/motor/versions lists
       2.0.0-dev.0 flagged "prerelease" -->
```

The `<!-- ... -->` blocks above are content requirements, not literal text —
expand each into real prose/checklists. Every factual claim you write must
match the workflows as they exist in `.github/workflows/` at your HEAD (you
verified them in the drift check and STOP checks).

**Verify**: `test -f RELEASING.md` exits 0;
`grep -c "Prepare release" RELEASING.md` ≥ 2;
`grep -n "RELEASE_PAT" RELEASING.md` ≥ 1;
`grep -n "2.0.0-dev" RELEASING.md` ≥ 1;
`grep -n "back-merge\|Back-merge" RELEASING.md` ≥ 1.

### Step 3: Update the plan index

Set plan 003's row to DONE in `plans/ci/README.md`.

**Verify**: `grep -n "003" plans/ci/README.md` shows the updated status.

## Test plan

- Step 1 is verified by grep + YAML parse (the artifact name only manifests
  on a failing golden test in CI; note in the PR description: "next golden
  failure should upload an artifact named `golden-failures`").
- Step 2 is a document; its verification is the grep gates above plus a
  self-review pass: every workflow name, file name, secret name, tag format,
  and package list mentioned in `RELEASING.md` must appear verbatim in
  `.github/workflows/` or `plans/ci/README.md`.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `grep -rn "steps.pkg" .github/workflows/` → no matches
- [ ] `ruby -ryaml -e 'YAML.load_file(".github/workflows/main.yaml")'` exits 0
- [ ] `RELEASING.md` exists and passes all Step 2 grep gates
- [ ] `git status --porcelain` shows only `.github/workflows/main.yaml`, `RELEASING.md`, `plans/ci/README.md`
- [ ] `plans/ci/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `.github/workflows/prepare-release.yaml` or `.github/workflows/publish.yaml`
  does not exist, or `tag-release.yaml` lacks `RELEASE_PAT` — plans 001/002
  have not landed; this runbook would document a pipeline that isn't there.
- `main.yaml:50-58` does not match the excerpt in "Current state".
- `packages/motor/pubspec.yaml` no longer says `version: 1.1.0` (motor 2.0
  release already in flight; the checklist needs rethinking, not copying).
- A `RELEASING.md` already exists.

## Maintenance notes

- `RELEASING.md` duplicates facts from the workflows by design (it's the
  human-facing view); whoever edits a workflow later should grep
  `RELEASING.md` for the old name/value.
- The motor 2.0 checklist section is disposable — delete it from
  `RELEASING.md` once 2.0.0 stable has shipped.
- Reviewer should scrutinize: the back-merge section (this is the one
  process step that, if skipped, corrupts the next prerelease's version
  math), and that the runbook never asks the human to run git/jj tag or
  version commands locally.
- Deliberately deferred: wiring a link to `RELEASING.md` from the root
  `README.md` or `AGENTS.md` (maintainer's call on placement), and any
  automation of the back-merge PR (could be a small workflow later; keep the
  process manual until it has been exercised once).
