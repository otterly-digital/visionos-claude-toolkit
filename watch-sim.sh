#!/usr/bin/env bash
# ─── Otterly Digital — visionOS Developer Toolkit ───────────────────────────
# watch-sim.sh — Stream your app's logs from the visionOS simulator.
#
# Taps the booted simulator's log stream and filters to only show lines from
# your app — stdout (Stdio category) plus errors and faults. Your custom
# LOG_TAGS from project.conf are highlighted alongside generic error patterns.
#
# Usage:
#   ./Scripts/watch-sim.sh
#   (Boot a visionOS simulator in Xcode first)
# ─────────────────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Load project config
# shellcheck source=../project.conf
source "$REPO_ROOT/project.conf"

# Build a grep pattern from LOG_TAGS (e.g. "[net] [auth]" → "\[net\]|\[auth\]|")
TAG_PATTERN=""
if [[ -n "$LOG_TAGS" ]]; then
  for tag in $LOG_TAGS; do
    escaped=$(printf '%s' "$tag" | sed 's/\[/\\[/g; s/\]/\\]/g')
    TAG_PATTERN="${TAG_PATTERN}${escaped}|"
  done
fi

PREDICATE="process == \"${APP_NAME}\" AND (category == \"Stdio\" OR messageType == error OR messageType == fault)"

xcrun simctl spawn booted log stream \
  --style compact \
  --predicate "$PREDICATE" \
  | grep -E --line-buffered \
      "${TAG_PATTERN}error|fault|exception|assertion failed|Thread [0-9]+: signal|Fatal error|precondition failed"
