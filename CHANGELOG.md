# Changelog

All notable changes to LegacyCam are documented in this file.

The format loosely follows Keep a Changelog, and this project uses semantic versioning for package releases.

## [Unreleased]

### Added

- Full English README covering runtime model, API routes, build targets, installation, iOS 12 permission flow, service control, Home Assistant usage, troubleshooting, and project layout.
- Initial changelog based on the repository history.

### Changed

- Updated documentation to match the current SpringBoard-hosted and daemon-hosted runtime behavior.

### Notes

- The working tree also contains uncommitted source and Makefile changes for older SDK compatibility and iOS 6 helper targets. Those are intentionally listed here as unreleased until committed.

## [1.0.0] - 2026-07-10

### Added

- Added a working build path for both iOS 7 armv7 devices and iOS 12 arm64 devices.
- Added `LegacyCam.app` as a companion app and daemon entry point.
- Added `LegacyCamSpringBoard.dylib` for MobileSubstrate injection into SpringBoard on iOS 9 and newer.
- Added `LegacyCamSpringBoard.plist` filter for SpringBoard injection.
- Added `LegacyCamPrefs.bundle` and PreferenceLoader metadata.
- Added a `Camera Enabled` preference switch backed by `com.fabiswdevbeg.legacycam`.
- Added Darwin notification handling for live preference changes.
- Added camera permission UI in the companion app.
- Added best-effort TCC camera authorization for `com.fabiswdevbeg.legacycam` and `com.apple.springboard` during package installation.
- Added entitlements file with AVFoundation multitasking camera access entitlement.
- Added `LCCaptureDevice` helper for selecting the back camera with a fallback camera device.
- Added stream-client limits and `429 Too Many Requests` responses.
- Added richer `/status` fields including build tag, flash availability, flash errors, frame sequence, latest JPEG size, and maximum stream clients.
- Added automatic camera retry handling for daemon and SpringBoard host modes.

### Changed

- Changed the launch daemon to start `/Applications/LegacyCam.app/LegacyCam --daemon`.
- Changed iOS 9 and newer behavior so the launch daemon stays idle while SpringBoard hosts camera capture and the HTTP server.
- Changed camera capture and HTTP serving to support newer iOS camera permission restrictions.
- Updated the package metadata to depend on both PreferenceLoader and MobileSubstrate.
- Updated the launch daemon to run as `mobile`.
- Updated install and removal scripts to reload the daemon and clean up related processes.
- Improved camera state reporting for permission, startup, runtime, interruption, and stopped-session errors.
- Improved torch handling with availability checks and explicit error reporting.
- Improved app UI state reporting for camera permission.

### Fixed

- Fixed compatibility issues needed for the current iOS 7 and iOS 12 build setup.
- Fixed runtime behavior on iOS versions where a plain daemon cannot reliably access the camera.

## [1.0.0-beta.4] - 2026-06-11

### Added

- Added `LCPowerManager` for idle sleep prevention during camera capture.
- Added power assertion cleanup when camera capture stops.

### Changed

- Improved MJPEG performance by avoiding unnecessary per-client frame work.
- Removed snapshot-style endpoint behavior to keep LegacyCam stream-first.
- Reduced camera workload for older devices.

### Removed

- Removed the snapshot route from the route table.
- Removed unused snapshot configuration.

## [1.0.0-beta.3-service] - 2026-06-11

### Added

- Added launchd-backed daemon support.
- Added `LegacyCamDaemon`.
- Added `/Library/LaunchDaemons/com.fabiswdevbeg.legacycamd.plist`.
- Added Debian `postinst` and `prerm` package scripts.

### Changed

- Changed LegacyCam from an app-only runtime toward a background service model.
- Updated package description and documentation for service installation.

## [1.0.0-beta.3-refactor] - 2026-06-08

### Added

- Added `LCConfigManager` for central runtime configuration.
- Added `LCStatusManager` for uptime and active stream-client tracking.
- Added `LCRoutes` for centralized endpoint constants.
- Added `/ping` availability endpoint.
- Added `/status` JSON endpoint.

### Changed

- Refactored HTTP request handling and route dispatch.
- Refactored camera, flash, status, and configuration responsibilities into smaller managers.
- Changed flash endpoints to return JSON responses.
- Updated README with the refactored architecture and API behavior.

### Fixed

- Fixed status reporting and backend organization after the larger refactor.

## [1.0.0-beta.3-docs] - 2026-06-05

### Fixed

- Fixed the README command for switching to the `mobile` user.

## [1.0.0-beta.3] - 2026-06-05

### Added

- First beta release, tagged as `v1.0.0b-3` and `iOS_7.1.2_v1.0.0b3`.
