

DEBUG=0
#export TARGET=iphone:clang:latest
export THEOS_DEVICE_IP=192.168.8.108
FINALPACKAGE=1.900
include theos/makefiles/common.mk
TWEAK_NAME = SaveBot
SaveBot_ARCHS=arm64 armv7 armv7s

SaveBot_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
SaveBot_LDFLAGS += -Wl,-segalign,4000
SaveBot_FILES = Tweak.xm SVProgressHUD.m NSGIF.m
SaveBot_FRAMEWORKS = UIKit QuartzCore MobileCoreServices CoreGraphics
BUNDLE_NAME = SaveBotB

SaveBotB_INSTALL_PATH = /Library/Application Support/
include $(THEOS)/makefiles/bundle.mk
include $(THEOS_MAKE_PATH)/tweak.mk


include $(THEOS_MAKE_PATH)/aggregate.mk
