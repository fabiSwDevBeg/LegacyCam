# LegacyCam Backend - Theos Daemon

LegacyCam is a lightweight MJPEG camera daemon for jailbroken iOS devices. The original target is iPhone 4 on iOS 7, and the Makefile also exposes an arm64 build path for iOS 12. It keeps the device workload intentionally small: no transcoding, overlays, motion detection, audio, or per-frame logging.

## Architecture Proposal

The backend is organized as a small set of managers around one launchd-managed daemon:

- `legacycamd`: starts camera capture, starts the HTTP server, and stays resident.
- `HTTPServer`: accepts requests, routes endpoints, writes HTTP responses.
- `LCCameraManager`: owns the capture session and keeps one compressed latest JPEG shared by every stream client.
- `FlashManager`: owns torch changes and cached flash state.
- `LCStatusManager`: tracks uptime and active stream client count.
- `LCConfigManager`: centralizes port, JPEG quality, frame interval, version, and device label.
- `LCPowerManager`: asks iOS to avoid idle sleep while streaming.
- `LCRoutes`: centralizes endpoint paths.

The package installs `/Library/LaunchDaemons/com.fabiswdevbeg.legacycamd.plist` with `RunAtLoad` and `KeepAlive`, so the service starts at boot and launchd restarts it if it exits.

## Folder Structure Proposal

Current Theos-compatible layout keeps sources at the app root:

```text
LC/
  LegacyCamDaemon.m
  HTTPServer.*
  LCCameraManager.*
  FlashManager.*
  LCStatusManager.*
  LCConfigManager.*
  LCPowerManager.*
  LCRoutes.*
  layout/Library/LaunchDaemons/com.fabiswdevbeg.legacycamd.plist
  layout/DEBIAN/postinst
  layout/DEBIAN/prerm
```

If this grows, the same modules can move into `Backend/HTTPServer`, `Backend/CameraManager`, `Backend/FlashManager`, `Backend/StatusManager`, `Backend/ConfigManager`, and `Backend/Routes` without changing responsibilities.

## API

```text
GET /stream
GET /flash/on
GET /flash/off
GET /flash/status
GET /status
GET /ping
```

`/status` returns a cheap JSON payload:

```json
{
  "online": true,
  "flash": false,
  "camera_enabled": true,
  "camera_running": true,
  "camera_error": "",
  "uptime": 12345,
  "version": "1.0.0",
  "device": "iPhone4",
  "stream_clients": 1
}
```

The root path returns a simple diagnostics page with links to stream and status.

## Refactor Plan

1. Compress each MJPEG frame once in `LCCameraManager`.
2. Share the latest compressed JPEG across all stream clients.
3. Keep status generation in memory only.
4. Avoid frame-level logging and extra image processing.
5. Centralize tuning in `LCConfigManager`.
6. Keep Home Assistant availability checks on `/ping` or `/status`.

## Breaking Changes

- LegacyCam is now installed as a background daemon instead of a SpringBoard app.
- The daemon binary is `/usr/bin/legacycamd`.
- launchd owns startup and restart through `com.fabiswdevbeg.legacycamd`.
- Flash endpoints now return JSON instead of plain text.
- `/snapshot.jpg` was removed to avoid extra JPEG work and keep the backend stream-only.
- The daemon now prevents idle sleep while running; a manual hardware lock may still stop camera capture on iOS 7.
- Unknown routes now return the diagnostics page.
- Home Assistant should use `/status` and `/ping` for state/availability.

## Migration Steps

1. Rebuild and reinstall the Theos package.
2. Confirm launchd loaded it:

```sh
launchctl list | grep legacycam
```

3. Confirm `http://DEVICE_IP:8080/ping` returns `{"ok":true}`.
4. Confirm `http://DEVICE_IP:8080/status` includes `online`, `flash`, `uptime`, `version`, `device`, and `stream_clients`.
5. Update the Home Assistant integration to the matching refactored version.

## Build

Default build targets iPhone 4 / iOS 7:

```sh
make clean
make package
```

Explicit helper targets:

```sh
make package-ios7
make package-ios12
make package-all
```

Release packages use `FINALPACKAGE=1`:

```sh
make release-ios7
make release-ios12
make release-all
```

`release-all` builds both release variants and copies them to explicit filenames:

```text
packages/com.fabiswdevbeg.legacycam_1.0.0_iphoneos-arm_ios7-armv7.deb
packages/com.fabiswdevbeg.legacycam_1.0.0_iphoneos-arm_ios12-arm64.deb
```

The iOS 12 helper builds `ARCHS=arm64` with `TARGET=iphone:clang:latest:12.0`, which is correct for iPhone 5s (`iPhone6,1` / `iPhone6,2`) and newer 64-bit iOS 12 devices. If your Theos install has a specific iOS 12 SDK and you prefer pinning it, build manually, for example:

```sh
make clean package FINALPACKAGE=1 ARCHS=arm64 TARGET=iphone:clang:12.4:12.0
```

The Debian package version is `1.0.0`, matching the `/status` version reported by the daemon.

Theos does not support project paths containing spaces. If needed, build from a temporary copy or a path without spaces.

## iOS 12 Notes

- iPhone 5s is arm64. iPhone 5 (`iPhone5,1` / `iPhone5,2`) is armv7s and does not officially run iOS 12.
- `arm64` is the safest default slice for iOS 12 jailbreaks; add `arm64e` only if your Theos SDK/toolchain and target jailbreak need it.
- If the package installs but the stream does not start, check `/var/mobile/Library/Logs/LegacyCam/legacycamd.err` and the device syslog. iOS 12 camera/privacy behavior is stricter than iOS 7, so runtime verification on the device matters more than the compile result.
- iOS 12 requires camera permission through a real app bundle and refuses camera capture from a plain background daemon. On iOS 9 and newer, `LegacyCamSpringBoard.dylib` hosts the camera and HTTP server inside SpringBoard through MobileSubstrate; on iOS 7, the launch daemon remains the active host.
- On jailbreaks with writable TCC, `postinst` pre-authorizes `com.fabiswdevbeg.legacycam` and `com.apple.springboard` for camera access. If app permission fails, open `LegacyCam.app` once, tap `Request Camera Access`, allow camera access, then respring.

Recommended iOS 12 install flow:

```sh
dpkg -i com.fabiswdevbeg.legacycam_1.0.0_iphoneos-arm_ios12-arm64.deb
uicache
killall SpringBoard
```

If `/status` reports `camera_permission_denied`, open `LegacyCam` from the home screen and allow camera access. After that:

```sh
killall SpringBoard
curl http://127.0.0.1:8080/status
```

## Settings

The package installs a PreferenceLoader panel at:

```text
Settings -> LegacyCam
```

The `Camera Enabled` switch defaults to on. Turning it off keeps the HTTP daemon online, stops camera capture, stops idle-sleep prevention, and makes `/stream` return `503 Service Unavailable` until the switch is enabled again.

`/status` includes:

```json
{
  "camera_enabled": true,
  "camera_running": true,
  "camera_error": ""
}
```

## Service Control

```sh
launchctl unload /Library/LaunchDaemons/com.fabiswdevbeg.legacycamd.plist
launchctl load -w /Library/LaunchDaemons/com.fabiswdevbeg.legacycamd.plist
tail -f /var/mobile/Library/Logs/LegacyCam/legacycamd.log
tail -f /var/mobile/Library/Logs/LegacyCam/legacycamd.err
```

If the log files are missing, reinstall the package so `postinst` creates `/var/mobile/Library/Logs/LegacyCam`, then reload the launch daemon.

For continuous streaming, keep the phone on power and let the daemon prevent auto-lock. Pressing the power button can still force iOS to suspend camera capture.
