ARCHS ?= armv7
TARGET ?= iphone:clang:7.1:7.1

include $(THEOS)/makefiles/common.mk

TOOL_NAME = legacycamd
APPLICATION_NAME = LegacyCam
BUNDLE_NAME = LegacyCamPrefs
TWEAK_NAME = LegacyCamSpringBoard

legacycamd_FILES = LegacyCamToolMain.m LegacyCamDaemon.m HTTPServer.m LCCameraManager.m FlashManager.m LCConfigManager.m LCStatusManager.m LCRoutes.m LCPowerManager.m LCPreferences.m LCCaptureDevice.m LCLog.m
legacycamd_FRAMEWORKS = Foundation UIKit CoreGraphics AVFoundation CoreMedia CoreVideo CoreImage
legacycamd_CFLAGS = -fobjc-arc -fmodules-cache-path=.theos/ModuleCache
legacycamd_CODESIGN_FLAGS = -SLegacyCam.entitlements

LegacyCam_FILES = main.m LCAppDelegate.m LCRootViewController.m LegacyCamDaemon.m HTTPServer.m LCCameraManager.m FlashManager.m LCConfigManager.m LCStatusManager.m LCRoutes.m LCPowerManager.m LCPreferences.m LCCaptureDevice.m LCLog.m
LegacyCam_FRAMEWORKS = Foundation UIKit CoreGraphics AVFoundation CoreMedia CoreVideo CoreImage
LegacyCam_CFLAGS = -fobjc-arc -fmodules-cache-path=.theos/ModuleCache
LegacyCam_CODESIGN_FLAGS = -SLegacyCam.entitlements
LegacyCam_RESOURCE_DIRS = Resources

LegacyCamSpringBoard_FILES = LegacyCamSpringBoardHost.m HTTPServer.m LCCameraManager.m FlashManager.m LCConfigManager.m LCStatusManager.m LCRoutes.m LCPowerManager.m LCPreferences.m LCCaptureDevice.m LCLog.m
LegacyCamSpringBoard_FRAMEWORKS = Foundation UIKit CoreGraphics AVFoundation CoreMedia CoreVideo CoreImage
LegacyCamSpringBoard_CFLAGS = -fobjc-arc -fmodules-cache-path=.theos/ModuleCache
LegacyCamSpringBoard_CODESIGN_FLAGS = -SLegacyCam.entitlements

LegacyCamPrefs_FILES = LegacyCamPrefs/LegacyCamPrefsRootListController.m
LegacyCamPrefs_INSTALL_PATH = /Library/PreferenceBundles
LegacyCamPrefs_FRAMEWORKS = UIKit
LegacyCamPrefs_CFLAGS = -fobjc-arc -fmodules-cache-path=.theos/ModuleCache
LegacyCamPrefs_LDFLAGS = -undefined dynamic_lookup
LegacyCamPrefs_RESOURCE_DIRS = LegacyCamPrefs/Resources

include $(THEOS_MAKE_PATH)/tool.mk
include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

.PHONY: clean-stage copy-last-package package-ios6 package-ios7 package-ios12 package-iphone5 package-all release-ios6 release-ios7 release-ios12 release-iphone5 release-all

clean-stage:
	rm -rf "$(THEOS_STAGING_DIR)" "$(_THEOS_STAGING_TMP)"

copy-last-package:
	@last_package="$$(cat .theos/last_package)"; \
	base_name="$${last_package##*/}"; \
	base_name="$${base_name%.deb}"; \
	if [ -z "$(PACKAGE_LABEL)" ]; then \
		echo "PACKAGE_LABEL is required"; \
		exit 1; \
	fi; \
	cp "$$last_package" "packages/$${base_name}_$(PACKAGE_LABEL).deb"; \
	echo "Copied packages/$${base_name}_$(PACKAGE_LABEL).deb"

package-ios6:
	$(MAKE) clean ARCHS=armv7 TARGET=iphone:clang:6.1:6.1
	$(MAKE) clean-stage ARCHS=armv7 TARGET=iphone:clang:6.1:6.1
	$(MAKE) all package ARCHS=armv7 TARGET=iphone:clang:6.1:6.1

package-ios7:
	$(MAKE) clean ARCHS=armv7 TARGET=iphone:clang:7.1:7.1
	$(MAKE) clean-stage ARCHS=armv7 TARGET=iphone:clang:7.1:7.1
	$(MAKE) all package ARCHS=armv7 TARGET=iphone:clang:7.1:7.1

package-ios12:
	$(MAKE) clean ARCHS=arm64 TARGET=iphone:clang:latest:12.0
	$(MAKE) clean-stage ARCHS=arm64 TARGET=iphone:clang:latest:12.0
	$(MAKE) all package ARCHS=arm64 TARGET=iphone:clang:latest:12.0

package-iphone5:
	$(MAKE) clean ARCHS=armv7s TARGET=iphone:clang:7.1:7.1
	$(MAKE) clean-stage ARCHS=armv7s TARGET=iphone:clang:7.1:7.1
	$(MAKE) all package ARCHS=armv7s TARGET=iphone:clang:7.1:7.1

package-all:
	$(MAKE) package-ios6
	$(MAKE) copy-last-package PACKAGE_LABEL=ios6-armv7
	$(MAKE) package-ios7
	$(MAKE) copy-last-package PACKAGE_LABEL=ios7-armv7
	$(MAKE) package-ios12
	$(MAKE) copy-last-package PACKAGE_LABEL=ios12-arm64

release-ios6:
	$(MAKE) clean FINALPACKAGE=1 ARCHS=armv7 TARGET=iphone:clang:6.1:6.1
	$(MAKE) clean-stage FINALPACKAGE=1 ARCHS=armv7 TARGET=iphone:clang:6.1:6.1
	$(MAKE) all package FINALPACKAGE=1 ARCHS=armv7 TARGET=iphone:clang:6.1:6.1

release-ios7:
	$(MAKE) clean FINALPACKAGE=1 ARCHS=armv7 TARGET=iphone:clang:7.1:7.1
	$(MAKE) clean-stage FINALPACKAGE=1 ARCHS=armv7 TARGET=iphone:clang:7.1:7.1
	$(MAKE) all package FINALPACKAGE=1 ARCHS=armv7 TARGET=iphone:clang:7.1:7.1

release-ios12:
	$(MAKE) clean FINALPACKAGE=1 ARCHS=arm64 TARGET=iphone:clang:latest:12.0
	$(MAKE) clean-stage FINALPACKAGE=1 ARCHS=arm64 TARGET=iphone:clang:latest:12.0
	$(MAKE) all package FINALPACKAGE=1 ARCHS=arm64 TARGET=iphone:clang:latest:12.0

release-iphone5:
	$(MAKE) clean FINALPACKAGE=1 ARCHS=armv7s TARGET=iphone:clang:7.1:7.1
	$(MAKE) clean-stage FINALPACKAGE=1 ARCHS=armv7s TARGET=iphone:clang:7.1:7.1
	$(MAKE) all package FINALPACKAGE=1 ARCHS=armv7s TARGET=iphone:clang:7.1:7.1

release-all:
	$(MAKE) release-ios6
	$(MAKE) copy-last-package PACKAGE_LABEL=ios6-armv7
	$(MAKE) release-ios7
	$(MAKE) copy-last-package PACKAGE_LABEL=ios7-armv7
	$(MAKE) release-ios12
	$(MAKE) copy-last-package PACKAGE_LABEL=ios12-arm64
