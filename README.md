# LegacyCam Backend - iPhone 4 Theos App

LegacyCam is a lightweight MJPEG camera server for a jailbroken iPhone 4 on iOS 7. It keeps the device workload intentionally small: no transcoding, overlays, motion detection, audio, or per-frame logging.

## Architecture Proposal

The backend is organized as a small set of managers around one socket server:

- `HTTPServer`: accepts requests, routes endpoints, writes HTTP responses.
- `LCCameraManager`: owns the capture session and keeps the latest low-rate frame.
- `FlashManager`: owns torch changes and cached flash state.
- `LCStatusManager`: tracks uptime and active stream client count.
- `LCConfigManager`: centralizes port, JPEG quality, frame interval, version, and device label.
- `LCRoutes`: centralizes endpoint paths.

## Folder Structure Proposal

Current Theos-compatible layout keeps sources at the app root:

```text
LC/
  HTTPServer.*
  LCCameraManager.*
  FlashManager.*
  LCStatusManager.*
  LCConfigManager.*
  LCRoutes.*
  LCAppDelegate.*
  LCRootViewController.*
  Resources/
```

If this grows, the same modules can move into `Backend/HTTPServer`, `Backend/CameraManager`, `Backend/FlashManager`, `Backend/StatusManager`, `Backend/ConfigManager`, and `Backend/Routes` without changing responsibilities.

## API

```text
GET /stream
GET /snapshot.jpg
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
  "uptime": 12345,
  "version": "1.0.0",
  "device": "iPhone4",
  "stream_clients": 1
}
```

The root path returns a simple diagnostics page with links to stream, snapshot, and status.

## Refactor Plan

1. Keep MJPEG and snapshot generation direct from the latest captured frame.
2. Keep status generation in memory only.
3. Avoid frame-level logging and extra image processing.
4. Centralize tuning in `LCConfigManager`.
5. Keep Home Assistant availability checks on `/ping` or `/status`, not snapshots.

## Breaking Changes

- Flash endpoints now return JSON instead of plain text.
- Unknown routes now return the diagnostics page.
- Home Assistant should use `/status` and `/ping` for state/availability.

## Migration Steps

1. Rebuild and reinstall the Theos package.
2. Confirm `http://DEVICE_IP:8080/ping` returns `{"ok":true}`.
3. Confirm `http://DEVICE_IP:8080/status` includes `online`, `flash`, `uptime`, `version`, `device`, and `stream_clients`.
4. Update the Home Assistant integration to the matching refactored version.

## Build

```sh
make clean
make package
```

Theos does not support project paths containing spaces. If needed, build from a temporary copy or a path without spaces.
