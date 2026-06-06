# visionOS Developer Toolkit — Claude Code instructions

## Auto-watching Xcode logs

Three scripts emit pre-filtered, line-buffered streams. When the user says "watch the build / sim / device," invoke the matching script via the Monitor tool with `persistent: true`:

- `Scripts/watch-build.sh [build|test]` — filtered xcodebuild output, success + failure markers
- `Scripts/watch-sim.sh` — booted visionOS simulator runtime (no ARKit)
- `Scripts/watch-device.sh` — paired Vision Pro runtime (full ARKit)

Each emitted line is a notification. On error/fault line: read ±20 lines of surrounding context from the source file referenced in the log, then either propose a fix inline or enter plan mode for non-trivial changes. On `** BUILD SUCCEEDED` / `** TEST SUCCEEDED`: acknowledge and stand down.

App stdout is filtered by the patterns in each script. Custom `LOG_TAGS` set in `project.conf` are automatically prepended to the grep pattern — any tag line will also wake the assistant.
