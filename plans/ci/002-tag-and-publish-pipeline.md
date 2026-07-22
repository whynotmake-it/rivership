# Plan 002: Make tags trigger publishing — PAT-pushed tags + OIDC publish workflow

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/ci/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 4d16091..HEAD -- .github/workflows/tag-release.yaml .github/workflows/`
> If `tag-release.yaml` changed since this plan was written, compare the
> "Current state" excerpt against the live file before proceeding; on a
> mismatch, treat it as a STOP condition. (A new
> `.github/workflows/prepare-release.yaml` from plan 001 is expected, not
> drift.)

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (touches the path that will push real versions to pub.dev;
  mitigated by pub.dev's own tag-pattern validation and by two maintainer-only
  switches that gate the first real publish)
- **Depends on**: plans/ci/001-branch-aware-release-prepare-workflow.md
- **Category**: dx
- **Planned at**: commit `4d16091`, 2026-07-22

## Why this matters

This monorepo's release pipeline dead-ends: merging a `chore(release)` PR
creates per-package git tags (`.github/workflows/tag-release.yaml`) and then
nothing happens. No workflow in the repo — nor anywhere in its git history —
runs `dart pub publish` or `melos publish --no-dry-run`; every actual publish
has been manual from the maintainer's machine. Worse, the tags are pushed with
the default `GITHUB_TOKEN`, and GitHub suppresses workflow runs for events
created with that token — so a tag-triggered publish workflow would never fire
even if it existed. This plan (a) makes `tag-release.yaml` push tags with a
PAT so tag pushes can trigger workflows, and (b) adds a tag-triggered
`publish.yaml` that publishes the tagged package to pub.dev via OIDC
(no stored pub.dev credentials) and creates a GitHub release. Combined with
plan 001, this completes: dev merge → `-dev.N` prerelease on pub.dev; main
merge → stable release on pub.dev.

## Current state

Branches: `dev` = prerelease trunk, `main` = stable (see
`plans/ci/README.md`). Plan 001 replaced `version.yaml` with a branch-aware
`prepare-release.yaml` whose merged PRs (titled `chore(release): Publish
packages`) land on `dev` or `main` and are what triggers the workflow below.

The tag workflow, in full, as it exists at `4d16091`
(`.github/workflows/tag-release.yaml:1-25`):

```yaml
name: Tag release
on:
  push:
    branches: [main, dev]

jobs:
  publish-packages:
    name: Create tag for a release
    permissions:
      contents: write
    runs-on: [ ubuntu-latest ]
    if: contains(github.event.head_commit.message, 'chore(release)')
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
          tag: true
```

Note the job id `publish-packages` (line 7) is a misnomer — it only tags.

Facts about `bluefireteam/melos-action@v3` you need (verified against the
action's `action.yml` at the `v3` tag):

- `tag: true` runs
  `melos exec -c 1 --no-private -- git tag $MELOS_PACKAGE_NAME-v$MELOS_PACKAGE_VERSION || true`
  then pushes tags **one by one** ("to avoid github limitation on emitting new
  tag events") — i.e. the action is designed for tag pushes to fan out into
  per-tag workflow runs. It pushes with whatever credentials the checkout
  configured, which is why the checkout token matters.
- `publish: true` extracts `PACKAGE_NAME`/`PACKAGE_VERSION` from
  `github.ref` (expects `refs/tags/<name>-v<version>`), runs
  `dart-lang/setup-dart` ("this sets up OIDC"), then
  `melos publish -y --no-dry-run --scope=$PACKAGE_NAME`.
- `create-release: true` extracts the tagged version's section from the
  package's `CHANGELOG.md` and creates a GitHub release; prerelease flag is
  auto-detected from a `-` in the version (so `-dev.N` → GitHub prerelease).

Tag conventions in this repo: `<package>-v<version>`, e.g. `motor-v1.1.0`,
`motor-v1.0.0-dev.9`, `stupid_simple_sheet-v1.0.0-dev.2` (`git tag` shows
~150 such tags). Published packages (8): `motor`, `heroine`, `rivership`,
`rivership_test`, `scroll_drag_detector`, `snaptest`, `stupid_simple_sheet`,
`fixed_ticker`. Private (`publish_to: none`, must never publish):
`example_design`, `springster`, plus all example apps.

pub.dev automated publishing (per
[dart.dev/tools/pub/automated-publishing](https://dart.dev/tools/pub/automated-publishing)):
enabled per package in the pub.dev admin UI with a repository
(`whynotmake-it/rivership`) and a tag pattern containing `{{version}}` (for
monorepos: `<package>-v{{version}}`). Publishing is only accepted from
workflow runs **triggered by a matching tag push**, with `id-token: write`
permission. `workflow_dispatch` or branch-push triggered runs are rejected by
pub.dev.

GitHub secrets: cannot be inspected from the repo. This plan assumes a
fine-grained PAT will be stored as secret `RELEASE_PAT` (maintainer action —
see Test plan). The workflow must degrade safely if it is missing.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| YAML syntax check | `ruby -ryaml -e 'YAML.load_file(".github/workflows/publish.yaml"); YAML.load_file(".github/workflows/tag-release.yaml"); puts "ok"'` | prints `ok` |
| Workflow lint (only if installed) | `actionlint .github/workflows/publish.yaml .github/workflows/tag-release.yaml` | exit 0 (skip if `command -v actionlint` fails; do not install) |
| Private packages stay private | `melos list --json \| ruby -rjson -e 'puts JSON.parse(STDIN.read).select { \|p\| p["private"] == false }.map { \|p\| p["name"] }'` | exactly the 8 published package names above |
| Publish gate dry-run | `melos publish --dry-run --yes` | exit 0 (warnings acceptable; errors are a STOP) |
| Scope check | `git status --porcelain` | only in-scope files |

## Scope

**In scope** (the only files you should modify):
- `.github/workflows/tag-release.yaml` (edit)
- `.github/workflows/publish.yaml` (create)
- `plans/ci/README.md` (status row only)

**Out of scope** (do NOT touch):
- `.github/workflows/prepare-release.yaml` (plan 001's output) and
  `main.yaml`, `deploy.yaml`.
- Any package pubspec/CHANGELOG; root `pubspec.yaml`.
- Creating GitHub secrets or changing pub.dev settings — maintainer-only;
  never attempt via `gh secret set` or the pub.dev site.

## Git workflow

- Branch: `advisor/ci-002-tag-publish-pipeline`
- Conventional commits, `ci:` type. Suggested single commit:
  `ci: publish tagged packages to pub.dev via OIDC`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Rework `.github/workflows/tag-release.yaml`

Replace the file's content with:

```yaml
name: Tag release

on:
  push:
    branches: [main, dev]

jobs:
  tag-release:
    name: Create tags for a release
    permissions:
      contents: write
    runs-on: ubuntu-latest
    if: contains(github.event.head_commit.message, 'chore(release)')
    steps:
      - name: 📚 Checkout
        uses: actions/checkout@v5
        with:
          fetch-depth: 0
          # Tags must be pushed with a PAT: tags pushed with the default
          # GITHUB_TOKEN do not trigger the publish.yaml workflow
          # (GitHub suppresses workflow runs for GITHUB_TOKEN-created events).
          token: ${{ secrets.RELEASE_PAT }}

      - name: 🐦 Setup Flutter
        uses: subosito/flutter-action@v2

      - name: Ⓜ️ Tag packages with Melos
        uses: bluefireteam/melos-action@v3
        with:
          tag: true
```

Changes vs. current: job id `publish-packages` → `tag-release` (it tags, it
does not publish), `runs-on: [ ubuntu-latest ]` → `runs-on: ubuntu-latest`,
checkout gets `token: ${{ secrets.RELEASE_PAT }}`, melos-action step renamed.
Keep everything else identical — in particular the `chore(release)` message
condition and the `branches: [main, dev]` trigger: with plan 001 in place,
release commits on `dev` carry `-dev.N` versions and release commits on `main`
carry stable versions, so this single workflow serves both trains.

**Verify**:
`ruby -ryaml -e 'YAML.load_file(".github/workflows/tag-release.yaml"); puts "ok"'`
→ `ok`, and
`grep -n "RELEASE_PAT" .github/workflows/tag-release.yaml` → 1 match on the
checkout `token:` line.

### Step 2: Create `.github/workflows/publish.yaml`

Create the file with exactly this content:

```yaml
name: Publish to pub.dev

on:
  push:
    tags:
      # Matches per-package tags like motor-v2.0.0 and motor-v2.0.0-dev.1.
      # Must stay aligned with the tag pattern configured on pub.dev for
      # each package: <package>-v{{version}}
      - '*-v[0-9]+.[0-9]+.[0-9]+*'

jobs:
  publish:
    name: Publish ${{ github.ref_name }}
    permissions:
      id-token: write # required for pub.dev OIDC authentication
      contents: write # required to create the GitHub release
    runs-on: ubuntu-latest
    steps:
      - name: 📚 Checkout
        uses: actions/checkout@v5
        with:
          fetch-depth: 0

      - name: 🐦 Setup Flutter
        uses: subosito/flutter-action@v2

      - name: Ⓜ️ Publish with Melos
        uses: bluefireteam/melos-action@v3
        with:
          publish: true
          create-release: true
```

Why this shape:

- One generic workflow handles all 8 packages: melos-action derives the
  package name and version from the tag ref and publishes only that package
  (`melos publish -y --no-dry-run --scope=$PACKAGE_NAME`). No per-package
  workflow files needed (design decision D3 in `plans/ci/README.md`).
- `create-release: true` also creates a GitHub release with the package's
  CHANGELOG section for that version; `-dev.N` versions are automatically
  marked as GitHub prereleases (melos-action `release-prerelease: auto`
  default).
- The private packages (`springster`, `example_design`, examples) are never
  tagged by melos-action (`--no-private` in its tag step), so no tag → no
  publish attempt.

**Verify**:
`ruby -ryaml -e 'YAML.load_file(".github/workflows/publish.yaml"); puts "ok"'`
→ `ok`, and
`grep -n "id-token: write" .github/workflows/publish.yaml` → 1 match.

### Step 3: Validate the publishable set and dry-run

```sh
melos list --json | ruby -rjson -e 'puts JSON.parse(STDIN.read).select { |p| p["private"] == false }.map { |p| p["name"] }.sort'
melos publish --dry-run --yes
```

**Verify**: the first command prints exactly `fixed_ticker`, `heroine`,
`motor`, `rivership`, `rivership_test`, `scroll_drag_detector`, `snaptest`,
`stupid_simple_sheet` (sorted); the dry-run exits 0. If either output differs,
see STOP conditions.

### Step 4: Update the plan index

Set plan 002's row to DONE in `plans/ci/README.md`.

**Verify**: `grep -n "002" plans/ci/README.md` shows the updated status.

## Test plan

Workflows can't run locally; local gates are the YAML/grep/dry-run
verifications above. The real proof is the first release — include this
checklist in the PR description for the maintainer:

**Maintainer setup (must exist before the first release merge; the executor
cannot and must not do these):**

1. Create a fine-grained PAT scoped to `whynotmake-it/rivership` with
   Contents: Read and write. Store it as the repo Actions secret
   `RELEASE_PAT`. (Without it, checkout falls back to an empty token value
   and the tag push fails visibly — nothing publishes silently.)
2. On pub.dev, for EACH of the 8 packages (`motor`, `heroine`, `rivership`,
   `rivership_test`, `scroll_drag_detector`, `snaptest`,
   `stupid_simple_sheet`, `fixed_ticker`): Admin tab → Automated publishing →
   Enable publishing from GitHub Actions → repository
   `whynotmake-it/rivership`, tag pattern `<package>-v{{version}}` (e.g.
   `motor-v{{version}}`). Requires uploader/publisher admin rights on pub.dev.

**First real run (expected observations):**

1. Dispatch "Prepare release" on `dev` (plan 001), merge the
   `chore(release)` PR into `dev`.
2. "Tag release" runs on the dev push and pushes tags, e.g.
   `motor-v2.0.0-dev.0` (motor's dev history contains `feat(motor)!:`
   commits on top of `motor-v1.1.0`).
3. Each pushed tag starts a "Publish to pub.dev" run — if none starts, the
   `RELEASE_PAT` secret is missing/wrong (step 1 above).
4. Each publish run ends with the package live on pub.dev as a prerelease
   (check `https://pub.dev/packages/motor/versions`) and a GitHub prerelease
   created. A pub.dev rejection mentioning the tag pattern or repository
   means step 2 above wasn't completed for that package.
5. Later, merge `dev` → `main`, dispatch "Prepare release" on `main`, merge
   its PR: same chain, but versions graduate (e.g. `motor-v2.0.0`) and GitHub
   releases are non-prerelease.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `ruby -ryaml -e 'YAML.load_file(".github/workflows/tag-release.yaml"); YAML.load_file(".github/workflows/publish.yaml")'` exits 0
- [ ] `grep -n "token: \${{ secrets.RELEASE_PAT }}" .github/workflows/tag-release.yaml` → 1 match
- [ ] `grep -rn "publish-packages" .github/workflows/` → no matches
- [ ] `grep -n "publish: true" .github/workflows/publish.yaml` → 1 match; `grep -n "id-token: write" .github/workflows/publish.yaml` → 1 match
- [ ] `grep -rn "no-dry-run\|pub publish" .github/workflows/*.yaml` → no matches (publishing is delegated to melos-action, never inlined)
- [ ] `melos publish --dry-run --yes` exits 0
- [ ] `git status --porcelain` shows only in-scope files
- [ ] `plans/ci/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `tag-release.yaml` at HEAD does not match the full excerpt in "Current
  state" (someone already reworked tagging).
- A `publish.yaml` (or other workflow containing `dart pub publish` /
  `melos publish`) already exists in `.github/workflows/`.
- Plan 001's `prepare-release.yaml` is absent AND `version.yaml` is also
  gone (release preparation is in an unknown state; the dependency order was
  violated).
- `melos list --json` marks any of `example_design`, `springster`, or an
  `*example*` package as `"private": false` — a private package would get
  tagged and published; report instead of "fixing" pubspecs (out of scope).
- `melos publish --dry-run --yes` fails with errors (a package is not
  publishable as-is; publishing infrastructure must not land while that is
  true).
- You are tempted to create the `RELEASE_PAT` secret or change pub.dev
  settings yourself — these are maintainer-only.

## Maintenance notes

- The tag glob `*-v[0-9]+.[0-9]+.[0-9]+*` is a GitHub Actions filter glob
  (`+` literal is not regex `+` — Actions globs treat `[0-9]` as a class and
  `+`/`*` as glob wildcards). It intentionally over-matches (e.g. any
  `-vN.N.N` suffix); pub.dev's per-package tag pattern is the real gate, and a
  run for a bogus tag fails at the publish step without side effects.
- `RELEASE_PAT` is a fine-grained PAT and will expire (GitHub maximum
  lifetime applies). Rotation symptom: "Tag release" fails at checkout or
  push with 403. Consider a GitHub App installation token if rotation becomes
  annoying (design decision D5 alternative).
- If a package is ever renamed/added, enable pub.dev automated publishing for
  it with tag pattern `<newname>-v{{version}}` before its first release merge.
- Reviewer should scrutinize: that the checkout in `tag-release.yaml` is the
  ONLY place `RELEASE_PAT` is used, and that `publish.yaml` grants
  `id-token: write` at the job level only.
- Deliberately deferred: publish-time test/analyze gates inside
  `publish.yaml` — `main.yaml` already gates every push/PR to dev/main with
  `dart analyze --fatal-infos` + full tests, and the prepare workflow dry-runs
  publishing; duplicating tests per tag (8 packages = 8 runs) was judged not
  worth the Actions minutes. Revisit if a bad artifact ever ships.
