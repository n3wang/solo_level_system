.PHONY: macos macos-build help

APP_NAME := solo_level_system.app
APP_BUILD := build/macos/Build/Products/Release/$(APP_NAME)
APP_DEST := /Applications/$(APP_NAME)

help:
	@echo "make macos        — release build and copy to /Applications"
	@echo "make macos-build  — release build only"

macos-build:
	flutter pub get
	cd macos && pod install
	flutter build macos --release

macos: macos-build
	cp -R "$(APP_BUILD)" "$(APP_DEST)"
	@echo "Installed $(APP_DEST)"
