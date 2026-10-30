# LegacyCam

LegacyCam is a lightweight MJPEG camera server for jailbroken iOS devices. It is designed for older iPhones that can be reused as simple network cameras, with a small runtime footprint and an HTTP API that works well with Home Assistant and other MJPEG clients.

The default target is iPhone 4-class hardware on iOS 7, but the project also includes helper targets for iOS 6, iPhone 5-class armv7s builds, and arm64 iOS 12 devices.

## Features

- MJPEG streaming over HTTP on port `8080`.
- Camera status and health endpoints for automation.
- Torch control endpoints with JSON responses.
- PreferenceLoader switch to enable or disable camera capture.
- Companion app for requesting and checking camera permission on iOS 7 and newer.
- SpringBoard-hosted camera/server path on iOS 9 and newer, where a plain daemon cannot reliably access the camera.
- launchd-managed background process with `RunAtLoad` and `KeepAlive`.
- Low-overhead frame handling: each frame is JPEG-compressed once and shared with all stream clients.
- Camera frame watchdog that retries a stalled capture session.
- Timestamped rolling runtime log for HTTP, camera, permission, and flash events.
- Idle sleep prevention while camera capture is enabled.
- One active stream at a time; a new stream request takes over from the previous client.

LegacyCam intentionally avoids transcoding, motion detection, audio, overlays, frame-by-frame logging, and heavyweight processing.

## Package Contents

The Debian package installs:

- `LegacyCam.app`: companion app and daemon entry point.
- `LegacyCamSpringBoard.dylib`: MobileSubstrate tweak injected into SpringBoard on iOS 9 and newer.
- `LegacyCamPrefs.bundle`: PreferenceLoader settings panel.
- `/Library/LaunchDaemons/com.fabiswdevbeg.legacycamd.plist`: launchd service definition.
- Package scripts that create logs, load/unload the daemon, and try to pre-authorize camera access on writable TCC databases.

## Runtime Model

LegacyCam uses two hosting modes:

- iOS 6 and iOS 7: the launch daemon starts the camera manager and HTTP server directly.
- iOS 9 and newer: the launch daemon remains alive, but camera capture and the HTTP server are hosted inside SpringBoard through `LegacyCamSpringBoard.dylib`.

The iOS 9+ SpringBoard host exists because newer iOS versions are stricter about camera access from a plain background daemon.

## HTTP API

The server listens on:

```text
http://DEVICE_IP:8080
```

Available routes:

| Route | Method | Description |
| --- | --- | --- |
| `/` | `GET` | Diagnostics page with current status and links. |
| `/stream` | `GET` | MJPEG stream using `multipart/x-mixed-replace`. |
| `/status` | `GET` | JSON status payload. |
| `/ping` | `GET` | Lightweight availability check. |
| `/flash/on` | `GET` | Enables torch if available. |
| `/flash/off` | `GET` | Disables torch if available. |
| `/flash/status` | `GET` | Returns torch availability, state, and error details. |

### `/ping`

```json
{"ok":true}
```

### `/status`

Example response:

```json
{
  "online": true,
  "flash": false,
  "camera_enabled": true,
  "camera_running": true,
  "camera_error": "",
  "uptime": 12345,
  "version": "1.0.0",
  "build": "single-stream-watchdog-20261030",
  "device": "iPhone3,1",
  "stream_clients": 1,
  "flash_available": true,
  "flash_error": "",
  "frame_sequence": 250,
  "latest_jpeg_bytes": 18421,
  "max_stream_clients": 1,
  "camera_producing_frames": true
}
```

### `/flash/status`

Example response:

```json
{
  "enabled": false,
  "available": true,
  "error": ""
}
```

### Error Responses

`/stream` returns:

- `503 Service Unavailable` when camera capture is disabled or not running.

When a new `/stream` request arrives, it replaces the currently connected stream client.

## Settings

LegacyCam installs a PreferenceLoader panel at:

```text
Settings -> LegacyCam
```

The `Camera Enabled` switch defaults to on. Turning it off:

- Stops camera capture.
- Stops idle sleep prevention.
- Keeps the HTTP service online.
- Makes `/stream` return `503 Service Unavailable` until the switch is enabled again.
- Updates `/status` through `camera_enabled`, `camera_running`, and `camera_error`.

Preference changes are delivered through the Darwin notification:

```text
com.fabiswdevbeg.legacycam/preferenceschanged
```

## Build Requirements

- Theos.
- A jailbroken iOS target device.
- MobileSubstrate.
- PreferenceLoader.
- SDK/toolchain support for the target architecture and deployment version.

Theos does not support project paths containing spaces. If needed, build from a path without spaces.

## Build

Default build:

```sh
make clean
make package
```

The default Makefile configuration is:

```text
ARCHS=armv7
TARGET=iphone:clang:7.1:7.1
```

Helper targets:

```sh
make package-ios6
make package-ios7
make package-iphone5
make package-ios12
make package-all
```

Release targets use `FINALPACKAGE=1`:

```sh
make release-ios6
make release-ios7
make release-iphone5
make release-ios12
make release-all
```

`package-all` and `release-all` copy the generated packages to labelled filenames in `packages/`, for example:

```text
packages/com.fabiswdevbeg.legacycam_1.0.0_iphoneos-arm_ios6-armv7.deb
packages/com.fabiswdevbeg.legacycam_1.0.0_iphoneos-arm_ios7-armv7.deb
packages/com.fabiswdevbeg.legacycam_1.0.0_iphoneos-arm_ios12-arm64.deb
```

For a pinned iOS 12 SDK, build manually:

```sh
make clean package FINALPACKAGE=1 ARCHS=arm64 TARGET=iphone:clang:12.4:12.0
```

## Install

Copy the generated package to the device and install it:

```sh
dpkg -i com.fabiswdevbeg.legacycam_1.0.0_iphoneos-arm.deb
su - mobile
uicache -a
su - root
killall SpringBoard
```

The package post-install script:

- Creates `/var/mobile/Library/Logs/LegacyCam`.
- Attempts to grant camera access to `com.fabiswdevbeg.legacycam` and `com.apple.springboard` when `/var/mobile/Library/TCC/TCC.db` is writable.
- Reloads `/Library/LaunchDaemons/com.fabiswdevbeg.legacycamd.plist`.

## Camera Permission Flow

On iOS 7 and newer versions with camera privacy enforcement:

1. Install the package.
2. Run `uicache`.
3. Open `LegacyCam` from the home screen.
4. Tap `Request Camera Access`.
5. Allow camera access.
6. Check `http://DEVICE_IP:8080/status`.

The permission is saved by iOS and is not revoked when the screen locks. On iOS 7, the camera and HTTP server run in the launchd service; the companion app only requests permission and can be closed afterward. Camera access can still be interrupted if another app takes the camera.

If permission is missing, `/status` may report:

```text
camera_permission_not_determined
camera_permission_denied
```

## Service Control

Reload the launch daemon:

```sh
launchctl unload /Library/LaunchDaemons/com.fabiswdevbeg.legacycamd.plist
launchctl load -w /Library/LaunchDaemons/com.fabiswdevbeg.legacycamd.plist
```

Check whether launchd knows about the service:

```sh
launchctl list | grep legacycam
```

Logs:

```sh
tail -f /var/mobile/Library/Logs/LegacyCam/legacycamd.log
tail -f /var/mobile/Library/Logs/LegacyCam/legacycamd.err
tail -f /var/mobile/Library/Logs/LegacyCam/legacycam-runtime.log
```

`legacycam-runtime.log` contains timestamped service startup, HTTP requests, camera permissions and interruptions, frame-watchdog restarts, and flash outcomes. It rotates at 512 KB; the previous file is kept as `legacycam-runtime.log.1`.

## Device Notes

- iPhone 4 and similar iOS 7 devices should use the armv7 iOS 7 target.
- iOS 6 builds are available through the armv7 iOS 6 helper target.
- iPhone 5 uses armv7s and can be built with `package-iphone5` or `release-iphone5`.
- iPhone 5s and newer 64-bit iOS 12 devices should use the arm64 iOS 12 target.
- iPhone 5 does not officially run iOS 12.
- Add `arm64e` only if your target jailbreak and Theos toolchain require it.

Legacy devices are sensitive to sustained camera and Wi-Fi usage. Keep the device on power for continuous streaming.

## Home Assistant Example

Example MJPEG camera configuration:

```yaml
camera:
  - platform: mjpeg
    name: LegacyCam
    mjpeg_url: http://DEVICE_IP:8080/stream
```

For availability checks, prefer `/ping` or `/status`.

## Troubleshooting

### `/ping` does not respond

- Confirm the package is installed.
- Confirm launchd loaded `com.fabiswdevbeg.legacycamd`.
- Check the log files under `/var/mobile/Library/Logs/LegacyCam`.
- Verify that port `8080` is reachable from your network.

### `/stream` returns `503`

- Check that `Settings -> LegacyCam -> Camera Enabled` is on.
- Open `/status` and inspect `camera_running` and `camera_error`.
- Open the app and check `Camera Permission`; use `Request Camera Access` if needed.
- Check `camera_producing_frames` as well as `camera_running`; the watchdog logs and retries stale sessions.

### Flash does not turn on

Open `/flash/status` and inspect:

```text
available
error
```

`/flash/on` and `/flash/off` return `202 Accepted` immediately; check `/flash/status` shortly afterward for the final state. Common errors include unavailable torch hardware, camera device unavailability, or a temporary lock/configuration failure.

### Camera stops after pressing the power button

LegacyCam asks iOS to prevent idle sleep while capture is enabled, but a manual hardware lock can still suspend or interrupt camera capture on older iOS versions. Keep the device awake and connected to power for long-running streams.

## Project Layout

```text
LC/
  Makefile
  control
  LegacyCamDaemon.*
  LegacyCamSpringBoardHost.m
  HTTPServer.*
  LCCameraManager.*
  LCCaptureDevice.*
  FlashManager.*
  LCConfigManager.*
  LCStatusManager.*
  LCPowerManager.*
  LCPreferences.*
  LCAppDelegate.*
  LCRootViewController.*
  LegacyCamPrefs/
  Resources/
  layout/
```

Key components:

- `LegacyCamDaemon`: daemon lifecycle, preference handling, retry loop, and host selection.
- `LegacyCamSpringBoardHost`: SpringBoard-hosted runtime for iOS 9 and newer.
- `HTTPServer`: HTTP request parsing, JSON responses, diagnostics, stream delivery, and stream limits.
- `LCCameraManager`: AVFoundation session, frame throttling, JPEG generation, camera errors, and latest-frame storage.
- `FlashManager`: torch state and error reporting.
- `LCStatusManager`: uptime and active stream-client tracking.
- `LCConfigManager`: port, version, build tag, quality, frame interval, device name, and client limits.
- `LCPowerManager`: idle sleep prevention through IOKit power assertions.
- `LCPreferences`: PreferenceLoader-backed camera enable flag.
- `LCRootViewController`: companion app UI for camera permission and daemon URL.

## Version

Package version: `1.0.0`

Runtime version: `1.0.0`

Runtime build: `ios7-4clients-20260619`
