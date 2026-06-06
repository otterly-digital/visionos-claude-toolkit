#!/usr/bin/env bash
# ─── Otterly Digital — visionOS Developer Toolkit ───────────────────────────
# watch-device.sh — Stream live stdout from a paired Vision Pro.
#
# Continuously re-launches your app under `xcrun devicectl device process
# launch --console` so the log stream stays alive across Xcode Run cycles and
# deploy.sh bounces. Each time the app exits the loop waits 3 s then
# re-attaches, letting a new install settle before launch.
#
# Why not `log stream --device`?
#   The host `log` tool on macOS 15+ does not support a --device flag.
# Why not `idevicesyslog`?
#   Vision Pro pairs via CoreDevice (Wi-Fi); the libimobiledevice USB/lockdownd
#   path can't see it.
#
# NOTE: intentionally no `set -o pipefail`. When deploy.sh or Xcode replaces
# the running binary, devicectl's attached process is terminated and the
# pipeline SIGPIPEs — that is a normal handoff, not a failure.
#
# Usage:
#   ./Scripts/watch-device.sh
#
# Overrides (env vars take precedence over project.conf):
#   OTTERLY_BUNDLE_ID    — override the bundle ID
#   OTTERLY_DEVICE_UUID  — target a specific device instead of auto-detecting
# ─────────────────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Load project config
# shellcheck source=../project.conf
source "$REPO_ROOT/project.conf"

BUNDLE_ID="${OTTERLY_BUNDLE_ID:-$BUNDLE_ID}"
DEVICE="${OTTERLY_DEVICE_UUID:-}"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun not found. Install Xcode command-line tools." >&2
  exit 127
fi

# Auto-pick the first connected device if OTTERLY_DEVICE_UUID isn't set.
if [[ -z "$DEVICE" ]]; then
  DEVICE=$(xcrun devicectl list devices 2>/dev/null \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
    | head -1)
fi

if [[ -z "$DEVICE" ]]; then
  echo "No connected device found. Pair a Vision Pro in Xcode (Window > Devices)." >&2
  exit 1
fi

# Build a grep pattern from LOG_TAGS (e.g. "[net] [auth]" → "\[net\]|\[auth\]|")
# Tags are appended before the generic error/fault patterns.
TAG_PATTERN=""
if [[ -n "$LOG_TAGS" ]]; then
  for tag in $LOG_TAGS; do
    escaped=$(printf '%s' "$tag" | sed 's/\[/\\[/g; s/\]/\\]/g')
    TAG_PATTERN="${TAG_PATTERN}${escaped}|"
  done
fi

# Loop: each devicectl --console invocation ends when the app exits (Xcode
# replacing the binary, user-stopped session, etc). Re-attach after a short
# backoff so the monitor pipeline stays alive across deploy cycles.
while true; do
  xcrun devicectl device process launch \
      --device "$DEVICE" \
      --console \
      --terminate-existing \
      "$BUNDLE_ID" 2>&1 \
    | grep -E -i --line-buffered \
        "${TAG_PATTERN}error|fault|exception|assertion failed|Thread [0-9]+: signal|Fatal error|precondition failed|launched application|terminated|Unable to"
  # Give a new install a moment to settle before re-attaching.
  sleep 3
done
