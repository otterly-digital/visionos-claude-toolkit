#!/usr/bin/env bash
# ─── Otterly Digital — visionOS Developer Toolkit ───────────────────────────
# watch-build.sh — Stream filtered build output during compilation.
#
# Suppresses Xcode's verbose output and shows only errors, warnings, and
# build status lines so you can spot problems at a glance.
#
# Usage:
#   ./Scripts/watch-build.sh           # build (default)
#   ./Scripts/watch-build.sh test      # run tests
# ─────────────────────────────────────────────────────────────────────────────
set -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Load project config
# shellcheck source=../project.conf
source "$REPO_ROOT/project.conf"

ACTION="${1:-build}"

# Prefer workspace over project when both are configured
if [[ -n "$XCODE_WORKSPACE" && -d "$XCODE_WORKSPACE" ]]; then
  XCODE_ARG=(-workspace "$XCODE_WORKSPACE")
else
  XCODE_ARG=(-project "$XCODE_PROJECT")
fi

xcodebuild "${XCODE_ARG[@]}" -scheme "$APP_NAME" \
    -destination 'generic/platform=visionOS' "$ACTION" 2>&1 \
  | grep -E --line-buffered \
      'error:|warning:.*error|fatal error|FAILED|\*\* BUILD FAILED|Undefined symbol|Linker command failed|Test Case .* failed|XCTAssert.* failed|\*\* TEST FAILED|\*\* BUILD SUCCEEDED|\*\* TEST SUCCEEDED'
