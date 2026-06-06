# Otterly Digital - visionOS <> Claude Developer Toolkit

A set of shell scripts that close the log-streaming gap in Vision Pro development and wire directly into Claude Code's Monitor tool — giving you an AI-assisted build-deploy-debug loop where Claude watches your logs, reads the context around each error, and proposes fixes without you leaving your editor. 
Built and maintained by [Otterly Digital](https://otterly.digital).

---

## Why these scripts exist

The standard Xcode workflow for Vision Pro development has a painful gap: once you click **Run**, your app's stdout disappears into the ether. There's no `log stream --device` support on macOS 15+, no USB-based `idevicesyslog` (Vision Pro pairs over Wi-Fi via CoreDevice), and Xcode's built-in console detaches the moment you stop the scheme.

These scripts close that gap. You get:

- **A persistent log stream** that survives across Xcode Run cycles and manual deploys - the monitor re-attaches automatically every time your app restarts.
- **A one-command deploy** that builds, installs, and bounces the app without touching Xcode - letting you stay in your editor and iterate faster.
- **Noise-filtered output** that suppresses Xcode's wall of build chatter and shows only errors, warnings, and your custom log tags.
- **Simulator parity** so the same tag-based filtering works whether you're testing on device or in the sim.

The result is a tight loop: edit code → `./Scripts/deploy.sh` → Claude sees the filtered log output within ~3 seconds, reads the surrounding source context, and either proposes a fix inline or drops into plan mode for non-trivial changes — no Xcode window switching, no terminal spelunking required.

---

## Scripts

| Script | Purpose |
|---|---|
| `deploy.sh` | Build for device, install to paired Vision Pro, terminate old process so the monitor re-attaches |
| `watch-device.sh` | Stream live stdout from a paired Vision Pro - runs forever, re-attaches after each app restart |
| `watch-sim.sh` | Stream your app's logs from the booted visionOS simulator |
| `watch-build.sh` | Run a filtered xcodebuild and show only errors, warnings, and pass/fail status |

---

## Prerequisites

- **Xcode 16+** with the visionOS SDK installed
- **Xcode Command Line Tools** (`xcode-select --install`)
- For device scripts: an **Apple Vision Pro** paired in Xcode (Window → Devices and Simulators → pair via Wi-Fi)
- For simulator scripts: a **visionOS Simulator** booted in Xcode

---

## Setup

### 1. Copy the Scripts folder into your repo

```
YourApp/
  YourApp.xcodeproj
  project.conf          ← copied and renamed from project.conf.sample
  Scripts/
    deploy.sh
    watch-device.sh
    watch-sim.sh
    watch-build.sh
    README.md
```

### 2. Create `project.conf` at your repo root

Copy `project.conf.sample` from this repo to your project root, rename it `project.conf`, and fill in your values.

Commit `project.conf` — it contains no secrets and every team member needs it.

### 3. Add the Claude Code instructions

Copy [CLAUDE.md](https://github.com/otterlydigital/visionos-tools/blob/main/CLAUDE.md) from this repo into your project root. It teaches Claude Code to invoke the watch scripts via its built-in Monitor tool whenever you ask it to watch the build, sim, or device — and how to react to what it sees.

### 4. Make the scripts executable

```bash
chmod +x Scripts/*.sh
```

### 5. Pair your Vision Pro

In Xcode: **Window → Devices and Simulators**, then connect Vision Pro to the same Wi-Fi network and follow the pairing flow. The scripts auto-detect the first paired device; no UUID configuration needed unless you have multiple devices.

---

## Usage

### With Claude Code (recommended)

With `CLAUDE.md` in your project root, Claude Code handles the monitoring for you. Just tell it what to watch:

> "Watch the device" / "Watch the sim" / "Watch the build"

Claude invokes the matching script via its Monitor tool with `persistent: true`. From that point:

- **Each filtered log line** (errors, faults, your `LOG_TAGS`) arrives as a notification that wakes Claude mid-session.
- **On an error or fault** — Claude reads ±20 lines of source context around the referenced file and line number, then either proposes a fix inline or enters plan mode for non-trivial changes.
- **On `** BUILD SUCCEEDED` / `** TEST SUCCEEDED`** — Claude acknowledges and stands down.

You stay in your editor. Run `./Scripts/deploy.sh` after each change and Claude reports back.

---

### Manual workflow

Open two terminals at your repo root.

**Terminal 1 - start the log monitor (leave it running):**

```bash
./Scripts/watch-device.sh
```

**Terminal 2 - deploy after each code change:**

```bash
./Scripts/deploy.sh
```

The monitor streams your app's stdout. Each time `deploy.sh` installs a new build and terminates the old process, the monitor re-attaches automatically within ~3 seconds.

### Simulator workflow

Boot a visionOS simulator in Xcode, then:

```bash
./Scripts/watch-sim.sh
```

Run your app from Xcode normally. Simulator logs appear in the terminal, filtered to your app and your `LOG_TAGS`.

### Build-only with filtered output

```bash
./Scripts/watch-build.sh          # build
./Scripts/watch-build.sh test     # test
```

---

## Adding your own log tags

In your Swift code, prefix log lines with a bracketed tag:

```swift
print("[net] fetching asset: \(url)")
print("[render] frame time: \(ms)ms")
```

Then in `project.conf`:

```bash
LOG_TAGS="[net] [render]"
```

Both `watch-device.sh` and `watch-sim.sh` will highlight those lines in their output alongside generic errors and faults.

---

## Environment variable overrides

These override the values in `project.conf` at runtime - useful for CI or targeting a specific device:

| Variable | Overrides | Example |
|---|---|---|
| `OTTERLY_BUNDLE_ID` | `BUNDLE_ID` in project.conf | `com.yourcompany.yourapp.staging` |
| `OTTERLY_DEVICE_UUID` | auto-detected device | `A1B2C3D4-…` from `xcrun devicectl list devices` |

```bash
OTTERLY_DEVICE_UUID=A1B2C3D4-... ./Scripts/deploy.sh
```

---

## Troubleshooting

**"No connected device found"**
Vision Pro must be on the same Wi-Fi network and paired in Xcode. Run `xcrun devicectl list devices` to verify it appears.

**Monitor shows nothing after deploy**
The 3-second backoff is intentional - the install needs to settle. If it never re-attaches, check that `BUNDLE_ID` in `project.conf` matches exactly what's in your target's Info.plist.

**`watch-build.sh` shows no output**
The filter only passes errors, warnings, and BUILD SUCCEEDED/FAILED lines. A clean build with no issues produces only the final status line - that's expected behavior.

**Workspace vs project**
If your app uses CocoaPods or a local Swift Package that requires a workspace, uncomment `XCODE_WORKSPACE` in `project.conf`. `deploy.sh` and `watch-build.sh` prefer the workspace when it's set.

---

## License

MIT — free to use, modify, and redistribute (including commercially), with attribution. See [LICENSE](LICENSE).

---

Made with care by [Otterly Digital](https://otterlydigital.com).
