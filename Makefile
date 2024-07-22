ARCHS := arm64
TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES := TrollFools

include $(THEOS)/makefiles/common.mk

XCODEPROJ_NAME += TrollFools

include $(THEOS_MAKE_PATH)/xcodeproj.mk

SUBPROJECTS += TrollFoolsTweak

include $(THEOS_MAKE_PATH)/aggregate.mk

before-package::
	$(ECHO_NOTHING)ldid -STrollFools.entitlements $(THEOS_STAGING_DIR)/Applications/TrollFools.app$(ECHO_END)

after-package::
	$(ECHO_NOTHING)mkdir -p packages $(THEOS_STAGING_DIR)/Payload$(ECHO_END)
	$(ECHO_NOTHING)cp -rp $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Applications/TrollFools.app $(THEOS_STAGING_DIR)/Payload$(ECHO_END)
	$(ECHO_NOTHING)chmod 0644 $(THEOS_STAGING_DIR)/Payload/TrollFools.app/Info.plist$(ECHO_END)
	$(ECHO_NOTHING)rm $(THEOS_STAGING_DIR)/Payload/TrollFools.app/ldid-14 || true$(ECHO_END)
	$(ECHO_NOTHING)cd $(THEOS_STAGING_DIR); 7z a -tzip -mm=LZMA TrollFools.tipa Payload; cd -;$(ECHO_END)
	$(ECHO_NOTHING)cp -p TrollFools/ldid-14 $(THEOS_STAGING_DIR)/Payload/TrollFools.app/ldid-14$(ECHO_END)
	$(ECHO_NOTHING)cd $(THEOS_STAGING_DIR); zip -qr TrollFools14.tipa Payload; cd -;$(ECHO_END)
	$(ECHO_NOTHING)cp -p $(THEOS_STAGING_DIR)/TrollFools.tipa $(THEOS_STAGING_DIR)/TrollFools14.tipa packages$(ECHO_END)
