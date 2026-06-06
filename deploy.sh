#!/usr/bin/env bash
# ─── Otterly Digital — visionOS Developer Toolkit ───────────────────────────
# deploy.sh — Build, install, and bounce your app on a paired Vision Pro.
#
# Designed to work alongside the running watch-device.sh monitor. After the
# old process is terminated, the monitor's loop re-attaches via
# `--terminate-existing --console` to the freshly-installed binary.
#
# Usage:
#   ./Scripts/deploy.sh
#
# Overrides (env vars take precedence over project.conf):
#   OTTERLY_BUNDLE_ID    — override the bundle ID
#   OTTERLY_DEVICE_UUID  — target a specific device instead of auto-detecting
# ─────────────────────────────────────────────────────────────────────────────
set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Load project config
# shellcheck source=../project.conf
source "$REPO_ROOT/project.conf"

BUNDLE_ID="${OTTERLY_BUNDLE_ID:-$BUNDLE_ID}"
DEVICE="${OTTERLY_DEVICE_UUID:-$(xcrun devicectl list devices 2>/dev/null \
  | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
  | head -1)}"

if [[ -z "$DEVICE" ]]; then
  echo "[deploy] no connected Vision Pro found" >&2
  exit 1
fi

# Prefer workspace over project when both are configured
if [[ -n "$XCODE_WORKSPACE" && -d "$XCODE_WORKSPACE" ]]; then
  XCODE_ARG=(-workspace "$XCODE_WORKSPACE")
else
  XCODE_ARG=(-project "$XCODE_PROJECT")
fi

echo "[deploy] building $APP_NAME for device $DEVICE…"
xcodebuild "${XCODE_ARG[@]}" -scheme "$APP_NAME" \
    -destination "generic/platform=visionOS" \
    -configuration Debug build 2>&1 \
  | grep -E "error:|warning: .*\.swift|BUILD" | tail -10

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/"${APP_NAME}"-* \
    -path "*/Build/Products/Debug-xros/${APP_NAME}.app" \
    -not -path "*Index.noindex*" 2>/dev/null \
  | head -1)
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "[deploy] no ${APP_NAME}.app found in DerivedData" >&2
  exit 1
fi

echo "[deploy] installing $APP_PATH"
xcrun devicectl device install app --device "$DEVICE" "$APP_PATH" 2>&1 \
  | grep -iE "installed|error" | tail -3

# Force-kill the running process so the watch-device loop notices and
# re-attaches via `--terminate-existing --console` to the freshly-installed
# binary. The watcher's 3 s backoff gives the install enough time to settle.
PID=$(xcrun devicectl device info processes --device "$DEVICE" 2>/dev/null \
  | awk -v bid="$BUNDLE_ID" '$0 ~ bid { print $1; exit }')
if [[ -n "$PID" ]]; then
  echo "[deploy] terminating existing PID $PID"
  xcrun devicectl device process terminate --device "$DEVICE" --pid "$PID" 2>&1 \
    | grep -iE "terminated|error" | head -3 || true
else
  echo "[deploy] no running instance found"
fi

echo "[deploy] done. watch-device loop should re-attach in ~3 s."
