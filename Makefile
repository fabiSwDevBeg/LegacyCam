ARCHS = armv7
TARGET = iphone:clang:7.1:7.1

include $(THEOS)/makefiles/common.mk

TOOL_NAME = legacycamd

legacycamd_FILES = LegacyCamDaemon.m HTTPServer.m LCCameraManager.m FlashManager.m LCConfigManager.m LCStatusManager.m LCRoutes.m LCPowerManager.m
legacycamd_FRAMEWORKS = Foundation UIKit CoreGraphics AVFoundation CoreMedia CoreVideo CoreImage
legacycamd_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tool.mk
