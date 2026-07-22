# Plan 001: Replace version.yaml with a branch-aware release-prepare workflow

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/ci/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 4d16091..HEAD -- .github/workflows/version.yaml .github/workflows/tag-release.yaml pubspec.yaml`
> If any of these files changed since this plan was written, compare the
> "Current state" excerpts against the live files before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW (workflow file swap; nothing publishes yet — the publish tail
  arrives in plan 002)
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `4d16091`, 2026-07-22

## Why this matters

The maintainer wants `dev` to be the source of truth for package prereleases
and `main` to push full stable releases. Today the "Version" workflow
(`.github/workflows/version.yaml`) is a `workflow_dispatch` with two
independent booleans (`prerelease`, `graduate`) and no branch awareness: you
can dispatch a stable versioning run on `dev` or a prerelease on `main`, and
nothing stops you. This plan replaces it with a single "Prepare release"
workflow whose mode is derived from the branch it is dispatched on: `dev` →
`melos version --prerelease` (produces `-dev.N` versions), `main` →
`melos version --graduate` (promotes `-dev.N` prereleases to stable). Any
other branch fails fast. This encodes the branch policy in CI instead of in
the maintainer's head.

## Current state

Repo: Flutter/Dart melos monorepo (melos 7.4.0, configured inside the root
`pubspec.yaml` under the `melos:` key — there is no `melos.yaml` file).
Branches: `main` (remote default, stable) and `dev` (active trunk, contains
unreleased motor 2.0 work). Conventional commits are enforced on PR titles.
Per-package tags look like `motor-v1.1.0` / `motor-v1.0.0-dev.9`.

Release flow today: dispatch `version.yaml` → melos-action versions packages
and dry-runs publish → a PR titled `chore(release): Publish packages` is
opened → merging it triggers `.github/workflows/tag-release.yaml` (push to
main/dev + `chore(release)` in the head commit message) which creates and
pushes per-package tags. Nothing publishes to pub.dev (that is plan 002).

The file this plan replaces, in full, as it exists at `4d16091`
(`.github/workflows/version.yaml:1-47`):

```yaml
name: Version

on:
  workflow_dispatch:
    inputs:
      prerelease:
        description: 'Version as prerelease'
        required: false
        default: false
        type: boolean
      graduate:
        description: 'Graduate prereleases'
        required: false
        default: false
        type: boolean

jobs:
  prepare-release:
    name: Prepare release
    permissions:
      contents: write
      pull-requests: write
    runs-on: ubuntu-latest
    steps:
      - name: 📚 Checkout
        uses: actions/checkout@v5
        with:
          fetch-depth: 0

      - name: 🐦 Setup Flutter
        uses: subosito/flutter-action@v2

      - name: Ⓜ️ Set up Melos
        uses: bluefireteam/melos-action@v3
        with:
          run-versioning: ${{ inputs.prerelease == false }}
          run-versioning-prerelease: ${{ inputs.prerelease == true }}
          run-versioning-graduate: ${{ inputs.graduate == true }}
          publish-dry-run: true

      - name: 🎋 Create Pull Request
        uses: peter-evans/create-pull-request@v7
        with:
          title: "chore(release): Publish packages"
          body: "Prepared all packages to be released to pub.dev"
          branch: chore/release
          delete-branch: true
```

Facts about `bluefireteam/melos-action@v3` you need (verified against the
action's `action.yml` at the `v3` tag):

- `run-versioning-prerelease: 'true'` runs
  `melos version --yes --no-git-tag-version --prerelease` (default preid is
  `dev`, i.e. versions become `X.Y.Z-dev.N`).
- `run-versioning-graduate: 'true'` runs
  `melos version --yes --no-git-tag-version --graduate`.
- `publish-dry-run: 'true'` runs `melos publish -y --dry-run` (validation
  gate; fails the job on publish warnings/errors).
- The action always runs `melos bootstrap` first and needs Flutter on the
  path (hence the `subosito/flutter-action` step before it).
- Composite-action inputs are strings: workflow expressions like
  `${{ github.ref_name == 'dev' }}` serialize to the strings `'true'`/`'false'`,
  which is exactly what the action compares against. The existing
  `version.yaml:36-38` relies on the same mechanism with `inputs.*` booleans.

Repo conventions that apply:

- Step names use emoji prefixes (`📚 Checkout`, `🐦 Setup Flutter`,
  `Ⓜ️ Set up Melos`) — match them.
- Actions are used at major-version tags (`actions/checkout@v5`,
  `subosito/flutter-action@v2`, `peter-evans/create-pull-request@v7`);
  dependabot manages bumps (`.github/dependabot.yaml`). Keep `@v7` for
  create-pull-request even though a dependabot PR for v8 is open upstream.
- The release PR title must keep the `chore(release)` prefix: the tag workflow
  triggers on `contains(github.event.head_commit.message, 'chore(release)')`
  (`.github/workflows/tag-release.yaml:12`), and the squash-merge commit title
  comes from the PR title.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| YAML syntax check | `ruby -ryaml -e 'YAML.load_file(".github/workflows/prepare-release.yaml"); puts "ok"'` | prints `ok` |
| Workflow lint (only if installed) | `actionlint .github/workflows/prepare-release.yaml` | exit 0, no output (skip if `command -v actionlint` fails; it is not installed on the maintainer's machine) |
| Melos still healthy | `melos list` | exit 0, lists 14 packages incl. `motor`, `heroine` |
| Scope check | `git status --porcelain` | only the files listed under "In scope" |

Note: `melos` is globally activated on the maintainer's machine
(`~/.pub-cache/bin/melos`). If unavailable, use `dart run melos list` from the
repo root.

## Scope

**In scope** (the only files you should modify):
- `.github/workflows/version.yaml` (delete)
- `.github/workflows/prepare-release.yaml` (create)
- `plans/ci/README.md` (status row only)

**Out of scope** (do NOT touch, even though they look related):
- `.github/workflows/tag-release.yaml` and any publish workflow — plan 002.
- `.github/workflows/main.yaml` — the `steps.pkg` artifact-name bug in it is
  fixed by plan 003.
- `pubspec.yaml` melos config (`updateGitTagRefs`, changelog settings, hooks) —
  behavior is correct as-is.
- Any package `pubspec.yaml`/`CHANGELOG.md` — versioning happens via the
  workflow at release time, never in this plan.

## Git workflow

- Branch: `advisor/ci-001-prepare-release-workflow`
- Single commit; message style is conventional commits, `ci:` type for
  workflow changes (repo example: `ci: remove GeneratedPluginRegistrant.swift
  from codegen check`). Suggested:
  `ci: make release preparation branch-aware (dev=prerelease, main=graduate)`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Create `.github/workflows/prepare-release.yaml`

Create the file with exactly this content:

```yaml
name: Prepare release

on:
  workflow_dispatch:

jobs:
  prepare-release:
    name: Prepare ${{ github.ref_name == 'main' && 'stable release' || 'prerelease' }}
    permissions:
      contents: write
      pull-requests: write
    runs-on: ubuntu-latest
    steps:
      - name: 🛑 Enforce release branches
        if: github.ref_name != 'main' && github.ref_name != 'dev'
        run: |
          echo "::error::Release preparation runs only on 'dev' (prerelease) or 'main' (stable graduation), not '${{ github.ref_name }}'."
          exit 1

      - name: 📚 Checkout
        uses: actions/checkout@v5
        with:
          fetch-depth: 0

      - name: 🐦 Setup Flutter
        uses: subosito/flutter-action@v2

      - name: Ⓜ️ Version packages (dev → prerelease, main → graduate)
        uses: bluefireteam/melos-action@v3
        with:
          run-versioning-prerelease: ${{ github.ref_name == 'dev' }}
          run-versioning-graduate: ${{ github.ref_name == 'main' }}
          publish-dry-run: true

      - name: 🎋 Create Pull Request
        uses: peter-evans/create-pull-request@v7
        with:
          title: "chore(release): Publish packages"
          body: |
            Prepared packages for release to pub.dev from `${{ github.ref_name }}`.

            - dispatched on `dev` → prerelease versions (`-dev.N`)
            - dispatched on `main` → graduated stable versions

            Review the version bumps and CHANGELOG entries before merging.
            Merging this PR triggers tagging (and, once plan 002 is live,
            publishing to pub.dev).
          branch: chore/release-${{ github.ref_name }}
          base: ${{ github.ref_name }}
          delete-branch: true
```

Design notes you must preserve if you adjust anything:

- Mode comes ONLY from `github.ref_name`; do not reintroduce dispatch inputs.
- `run-versioning` (plain stable bump) is intentionally absent: stable
  releases happen exclusively by graduating prereleases on `main` (design
  decision D7 in `plans/ci/README.md`).
- `base: ${{ github.ref_name }}` and the per-branch PR branch name
  (`chore/release-dev` / `chore/release-main`) keep concurrent trains from
  clobbering each other's PR branch (the old fixed `chore/release` could not
  distinguish them).
- The PR title must keep the `chore(release)` prefix (tag trigger depends on
  it — see Current state).

**Verify**:
`ruby -ryaml -e 'YAML.load_file(".github/workflows/prepare-release.yaml"); puts "ok"'`
→ prints `ok`.

### Step 2: Delete `.github/workflows/version.yaml`

Remove the file entirely. It is fully superseded by Step 1.

**Verify**: `ls .github/workflows/` → exactly `deploy.yaml  main.yaml
prepare-release.yaml  tag-release.yaml` (plus `publish.yaml` only if plan 002
already ran).

### Step 3: Sanity-check the expressions

Run:

```sh
grep -n "run-versioning-prerelease: \${{ github.ref_name == 'dev' }}" .github/workflows/prepare-release.yaml
grep -n "run-versioning-graduate: \${{ github.ref_name == 'main' }}" .github/workflows/prepare-release.yaml
grep -rn "workflow_dispatch" .github/workflows/prepare-release.yaml
```

**Verify**: first two greps each match exactly one line; third matches the
`on:` block and shows NO `inputs:` on the following lines
(`grep -A2 "workflow_dispatch" .github/workflows/prepare-release.yaml` must
not contain `inputs:`).

### Step 4: Update the plan index

Set plan 001's row to DONE in `plans/ci/README.md`.

**Verify**: `grep -n "001" plans/ci/README.md` shows the updated status.

## Test plan

CI workflows can't be executed locally; the gates are:

- YAML parses (Step 1 verification).
- `actionlint .github/workflows/prepare-release.yaml` if actionlint is
  installed (it is NOT on the maintainer's machine — skip without installing
  anything).
- `melos list` still exits 0 (nothing in the workspace was touched).
- **First-real-run checklist** (record in the PR description; the maintainer
  performs it after merge):
  1. Dispatch "Prepare release" on `dev` (Actions → Prepare release → Run
     workflow → branch `dev`). Expect: job succeeds, a PR
     `chore(release): Publish packages` appears with base `dev`, and motor is
     bumped to `2.0.0-dev.0` (dev history contains `feat(motor)!:` commits on
     top of `motor-v1.1.0`).
  2. Dispatch it on any other branch. Expect: fails within seconds at
     "🛑 Enforce release branches".
  3. Do NOT merge the release PR until plan 002's tag/publish tail is in
     place, unless tagging-without-publishing is acceptable.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `.github/workflows/version.yaml` does not exist
- [ ] `.github/workflows/prepare-release.yaml` exists and
      `ruby -ryaml -e 'YAML.load_file(".github/workflows/prepare-release.yaml")'` exits 0
- [ ] `grep -rn "inputs:" .github/workflows/prepare-release.yaml` → no matches
- [ ] `grep -c "github.ref_name" .github/workflows/prepare-release.yaml` ≥ 5
- [ ] `grep -rn "chore(release)" .github/workflows/prepare-release.yaml` → at least 1 match (PR title)
- [ ] `melos list` exits 0
- [ ] `git status --porcelain` shows only in-scope files
- [ ] `plans/ci/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check shows `.github/workflows/version.yaml`,
  `tag-release.yaml`, or the root `pubspec.yaml` changed since `4d16091`, and
  the live content no longer matches the excerpts above.
- `version.yaml` at HEAD does not match the full excerpt in "Current state"
  (someone already reworked versioning).
- A `prepare-release.yaml` (or similarly named release workflow) already
  exists.
- The root `pubspec.yaml` no longer contains the `melos:` section, or
  `melos list` fails (workspace broken — not this plan's job to fix).
- You find yourself wanting to change `tag-release.yaml` or `main.yaml` —
  those belong to plans 002/003.

## Maintenance notes

- If a third long-lived branch is ever added (e.g. `beta`), extend both the
  "Enforce release branches" guard and the versioning-mode expressions, and
  decide its preid (`--preid`) explicitly.
- Reviewer should scrutinize: the two `${{ github.ref_name == ... }}`
  expressions (a typo here silently versions nothing, because both action
  inputs would be `'false'` — the job would still go green having only
  dry-run-published).
- Deliberately deferred: the tag/publish tail (plan 002), the
  `main.yaml` artifact-name bug and the human runbook (plan 003), and any
  melos config changes in `pubspec.yaml` (not needed).
