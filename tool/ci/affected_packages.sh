#!/usr/bin/env bash
# Works out which workspace packages a change affects, so CI only tests those.
#
# Usage (from anywhere in the repo):
#   tool/ci/affected_packages.sh [--base <git ref>] [--files <file>]
#
#   --base   Diff HEAD against the merge base with this ref (default: origin/main).
#   --files  Read the changed paths (one per line) from a file instead of git.
#
# Environment:
#   EVENT_NAME     GitHub event name. "push" and "workflow_dispatch" force a full run.
#   GITHUB_OUTPUT  When set, outputs are appended to it (GitHub Actions).
#
# Outputs (printed as key=value lines):
#   full      true when everything should run.
#   matrix    JSON list of {name, path, ffmpeg} for affected packages that have tests.
#   has_tests true when the matrix is not empty.
#   motor     true when motor_benchmark, motor or fixed_ticker is affected.
#
# Needs: git, jq and melos (`melos list` works without bootstrapping).
set -euo pipefail

base=origin/main
files_from=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) base="$2"; shift 2 ;;
    --files) files_from="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

root=$(git rev-parse --show-toplevel)
cd "$root"

# Packages whose tests record videos through ffmpeg.
ffmpeg_packages='["snaptest","stupid_simple_sheet"]'
# Packages that are not part of the `flutter test` matrix.
excluded_packages='["motor_benchmark"]'

# name and path (relative to the repo root) of every workspace package.
packages=$(melos list --json 2>/dev/null |
  jq -c --arg root "$root/" '[.[] | {name, path: (.location | ltrimstr($root))}]')
all_names=$(jq -c '[.[].name]' <<<"$packages")

if [[ -n "$files_from" ]]; then
  changed=$(cat "$files_from")
else
  changed=$(git diff --name-only "$(git merge-base "$base" HEAD)" HEAD)
fi
# Documentation, coverage output and licenses never need a test run.
changed=$(grep -Ev '(\.md$|(^|/)coverage/|(^|/)LICENSE[^/]*$)' <<<"$changed" || true)

full=false
affected='[]'
if [[ "${EVENT_NAME:-}" == push || "${EVENT_NAME:-}" == workflow_dispatch ]]; then
  full=true
elif [[ -n "$(grep -Ev '^(packages|apps)/' <<<"$changed" || true)" ]]; then
  # Root config, workflows, tooling: could affect everything.
  full=true
elif [[ -n "$changed" ]]; then
  # Map each file to the package with the longest matching path prefix.
  direct=$(jq -Rn -c --argjson packages "$packages" '
    [inputs | select(length > 0)] as $files
    | [$files[] as $f
       | [$packages[] | . as $p | select($f | startswith($p.path + "/"))]
       | (max_by(.path | length) // {name: null})
       | .name]
    | unique' <<<"$changed")
  if [[ "$direct" == *null* ]]; then
    # A file under packages/ or apps/ that belongs to no known package.
    full=true
  else
    # Expand to dependents (dev_dependencies and transitive ones included).
    scope_args=()
    while read -r name; do scope_args+=("--scope=$name"); done < <(jq -r '.[]' <<<"$direct")
    affected=$(melos list "${scope_args[@]}" --include-dependents --json 2>/dev/null |
      jq -c '[.[].name]')
  fi
fi
if [[ "$full" == true ]]; then
  affected=$all_names
fi

candidates=$(jq -c -n \
  --argjson packages "$packages" --argjson affected "$affected" \
  --argjson ffmpeg "$ffmpeg_packages" --argjson excluded "$excluded_packages" '
  [$packages[]
   | select(.name as $n | ($affected | index($n)) and ($excluded | index($n) | not))
   | {name, path, ffmpeg: (.name as $n | $ffmpeg | index($n) != null)}]')
# Keep only packages that actually have a test directory.
matrix='[]'
while IFS= read -r entry; do
  [[ -z "$entry" ]] && continue
  path=$(jq -r '.path' <<<"$entry")
  if [[ -d "$path/test" ]]; then
    matrix=$(jq -c --argjson e "$entry" '. + [$e]' <<<"$matrix")
  fi
done < <(jq -c '.[]' <<<"$candidates")

has_tests=$(jq -r 'length > 0' <<<"$matrix")
motor=$(jq -r 'any(. == "motor_benchmark" or . == "motor" or . == "fixed_ticker")' <<<"$affected")

outputs="full=$full
matrix=$matrix
has_tests=$has_tests
motor=$motor"
echo "$outputs"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "$outputs" >>"$GITHUB_OUTPUT"
fi
