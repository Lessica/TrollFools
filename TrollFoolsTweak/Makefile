ARCHS := arm64 arm64e
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES := TrollFools

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TrollFoolsTweak

TrollFoolsTweak_FILES = TrollFoolsTweak.x
TrollFoolsTweak_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
