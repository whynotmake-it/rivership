# Releasing

`dev` is the prerelease train and publishes `-dev.N` versions. `main` is the
stable train: it graduates versions released from `dev` and can ship hotfixes
directly.

## TL;DR

| I want to… | Do this |
|------------|---------|
| Ship prereleases of what's on dev | Actions → "Prepare release" → run on `dev` → review and merge the `chore(release)` PR |
| Ship stable versions | Open and merge the `dev` → `main` PR → CI automatically opens the graduation `chore(release)` PR → review and merge it |
| Ship a hotfix from main | Merge the fix PR to `main` → CI automatically opens a patch `chore(release)` PR → review and merge it |
| After any stable release | Open and merge the back-merge PR from `main` to `dev` |

In every case the `chore(release)` PR is the human checkpoint: review and merge
it, and tagging plus publishing follow automatically.

## How the pipeline works

1. Any push to `main` starts `.github/workflows/prepare-release.yaml`, except
   merges of a `chore(release)` PR, which the tagging workflow owns. The
   workflow inspects the publishable packages' pubspec versions: if any
   contains a prerelease (`-dev.`), it graduates them to stable versions (the
   `dev` → `main` merge case); otherwise it runs plain conventional-commit
   versioning (the hotfix case). If nothing is releasable, Melos makes no
   changes and no release PR is opened. Dispatching the workflow manually on
   `main` runs the same detection — use it as a fallback or re-run if an
   automatic run failed.
2. Dispatching the workflow on `dev` runs prerelease versioning. Any other
   dispatched branch is rejected.
3. Melos versions only changed, publishable packages according to conventional
   commits, runs a publish dry-run, and opens a
   `chore(release): Publish packages` PR.
4. Merging that PR starts `.github/workflows/tag-release.yaml`, which creates
   `<package>-v<version>` tags. The tags are pushed with `RELEASE_PAT` so their
   push events can start other workflows.
5. Each tag starts `.github/workflows/publish.yaml`. It publishes that package
   to pub.dev using OIDC and creates a GitHub release. Versions containing
   `-dev.N` become GitHub prereleases.

Normal stable releases graduate existing prereleases. Hotfix releases are the
exception and can version fixes landed directly on `main`.

## Reviewing a release PR

- Confirm every bumped package and version is expected.
- Read each generated CHANGELOG section. Edit unclear or incomplete entries on
  the release PR branch before merging; the PR is the human checkpoint.
- Confirm the Prepare release workflow's publish dry-run passed.
- Do not merge if a version, package, or CHANGELOG entry is surprising.

## CHANGELOG flow and the back-merge

Prerelease entries accumulate on `dev`. Graduation on `main` rewrites them to
the stable version. After a stable release, `main` contains release commits
that `dev` does not.

Promptly open and merge a PR from `main` back to `dev`. Skipping this back-merge
can make the next prerelease double-bump versions that already shipped stable.
Conflicts should be uncommon because `main` receives only merged `dev` work and
its own release commits.

## jj notes

Keep day-to-day work on the `dev` bookmark and push it normally. Do not create
release tags locally and do not commit directly to `main`. CI handles
versioning, tags, publishing, and GitHub releases. Create the `dev` → `main`
and `main` → `dev` PRs in GitHub; no local branch juggling is required.

## Hotfixing a stable release

Direct-from-`main` hotfixes are a first-class release path and need no manual
dispatch: landing the fix PR on `main` is the trigger. CI detects that the tree
contains only stable versions and runs conventional-commit versioning, so Melos
chooses the stable patch or minor bump from the fix commits. Review and merge
the generated release PR normally; never publish or tag by hand.

One edge to respect: if an un-merged graduation `chore(release)` PR is still
open, `main` still contains prerelease versions, so a hotfix push would detect
them and graduate instead of preparing a patch release. Merge or close pending
release PRs before landing hotfixes.

The fix must also land on `dev`, either by cherry-picking it or promptly
back-merging `main` into `dev`. The version math remains safe when `dev` is
already on its next prerelease line: after a `1.1.1` hotfix on `main`, a
back-merge keeps a version such as `2.0.0-dev.N` ahead because
`2.0.0-dev.N` sorts above `1.1.1`. Melos handles that ordering while continuing
the `dev` prerelease train.

## One-time setup (status)

- [ ] Create a fine-grained PAT limited to `whynotmake-it/rivership` with
  Contents: Read and write, and store it as the Actions secret `RELEASE_PAT`.
- [ ] Enable pub.dev automated publishing from GitHub Actions for `motor`,
  `heroine`, `rivership`, `rivership_test`, `scroll_drag_detector`, `snaptest`,
  `stupid_simple_sheet`, and `fixed_ticker`. Use repository
  `whynotmake-it/rivership` and each package's
  `<package>-v{{version}}` tag pattern.
- [ ] Confirm branch protection allows the intended PR-based `dev` → `main`
  and `main` → `dev` flow and requires the desired checks. The release
  workflows do not require direct commits to either branch.

## Motor 2.0 first prerelease checklist

- Expect Melos to compute `2.0.0-dev.0` from the breaking `feat(motor)!`
  commits on top of `motor-v1.1.0`. Stop and investigate if the release PR
  proposes another motor version.
- On the release PR, fold the hand-written `## Unreleased` narrative in
  `packages/motor/CHANGELOG.md` into the generated `## 2.0.0-dev.0` section,
  then remove the `## Unreleased` header. Melos does not do this automatically.
- Keep prerelease installation instructions explicit:
  `motor: ^2.0.0-dev.0`. The existing `motor: ^2.0.0` constraint does not
  resolve to a prerelease because prereleases sort below `2.0.0`.
- When `2.0.0` graduates on `main`, verify the README's stable install snippet
  and remove its `TODO(release)` comment.
- After publishing, verify that
  <https://pub.dev/packages/motor/versions> lists `2.0.0-dev.0` as a
  prerelease.
