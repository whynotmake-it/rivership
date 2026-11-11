#!/usr/bin/env bash
# Builds the benchmark as an AOT desktop app and runs it on this machine.
#
#   BENCH_BUILD=release (default) | profile   profile adds allocation numbers
#
# Other BENCH_* variables are passed through (see lib/motor_benchmark.dart).
# The desktop runner is generated on first use and is gitignored.
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${BENCH_BUILD:-release}"
case "$(uname -s)" in
  Linux) platform=linux ;;
  Darwin) platform=macos ;;
  *) echo "Unsupported host: $(uname -s)" >&2; exit 1 ;;
esac

if [ ! -d "$platform" ]; then
  tmp="$(mktemp -d)"
  flutter create --platforms="$platform" --project-name motor_benchmark \
    "$tmp/app" > /dev/null
  cp -R "$tmp/app/$platform" "$platform"
  rm -rf "$tmp"
  if [ "$platform" = macos ]; then
    # Results are written next to the package, outside the app container.
    perl -0pi -e 's|(app-sandbox</key>\s*)<true/>|$1<false/>|' \
      macos/Runner/*.entitlements
  fi
fi

flutter build "$platform" "--$mode" -t lib/main.dart

if [ "$platform" = linux ]; then
  binary=$(ls build/linux/*/"$mode"/bundle/motor_benchmark)
else
  capitalized="$(echo "${mode:0:1}" | tr '[:lower:]' '[:upper:]')${mode:1}"
  binary="build/macos/Build/Products/$capitalized/motor_benchmark.app/Contents/MacOS/motor_benchmark"
fi
exec "$binary"
