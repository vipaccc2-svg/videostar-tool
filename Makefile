ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = VideoStar

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = AutoLayer
AutoLayer_FILES = AutoLayer.m
AutoLayer_CFLAGS = -fobjc-arc
AutoLayer_FRAMEWORKS = UIKit Photos Foundation
AutoLayer_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/library.mk
