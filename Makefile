ARCHS = armv7
TARGET = iphone:clang:7.1:7.1
INSTALL_TARGET_PROCESSES = LegacyCam

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = LegacyCam

LegacyCam_FILES = main.m LCAppDelegate.m LCRootViewController.m HTTPServer.m LCCameraManager.m FlashManager.m LCConfigManager.m LCStatusManager.m LCRoutes.m
LegacyCam_FRAMEWORKS = UIKit CoreGraphics AVFoundation CoreMedia CoreVideo CoreImage
LegacyCam_ASSETS = Resources
LegacyCam_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk
