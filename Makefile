ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = ShazamNotificationContentExtension


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MusicRecognitionMoreApps

MusicRecognitionMoreApps_FILES = Tweak.x
MusicRecognitionMoreApps_CFLAGS = -fobjc-arc
MusicRecognitionMoreApps_FRAMEWORKS = UIKit UserNotifications CoreServices

include $(THEOS_MAKE_PATH)/tweak.mk
