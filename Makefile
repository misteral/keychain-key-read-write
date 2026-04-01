.PHONY: build build-signed install uninstall clean help

BINARY_NAME = kc
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release
INSTALL_PATH = $(HOME)/.local/bin
APP_INSTALL_DIR = $(HOME)/.local/share/kc
APP_BUNDLE = $(APP_INSTALL_DIR)/kc.app
XCODE_DERIVED_DATA = $(BUILD_DIR)/DerivedData
XCODE_PROJECT = kc.xcodeproj
XCODE_SCHEME = kc
APP_OUTPUT = $(XCODE_DERIVED_DATA)/Build/Products/Release/kc.app

build:
	@echo "Building $(BINARY_NAME) in release mode with SwiftPM..."
	swift build -c release

build-signed:
	@echo "Generating Xcode project..."
	@command -v xcodegen >/dev/null 2>&1 || (echo "Error: xcodegen is required for signed builds (brew install xcodegen)" && exit 1)
	xcodegen generate
	@echo "Building signed app bundle..."
	xcodebuild -project $(XCODE_PROJECT) -scheme $(XCODE_SCHEME) -configuration Release -destination 'platform=macOS' -derivedDataPath $(XCODE_DERIVED_DATA) build

install: build-signed
	@echo "Installing signed $(BINARY_NAME) app bundle to $(APP_INSTALL_DIR)..."
	@mkdir -p $(APP_INSTALL_DIR) $(INSTALL_PATH)
	@rm -rf $(APP_BUNDLE)
	@cp -R $(APP_OUTPUT) $(APP_BUNDLE)
	@printf '%s\n' '#!/bin/sh' 'exec "$$HOME/.local/share/kc/kc.app/Contents/MacOS/kc" "$$@"' > $(INSTALL_PATH)/$(BINARY_NAME)
	@chmod +x $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "$(BINARY_NAME) installed successfully to $(INSTALL_PATH)/$(BINARY_NAME)"
	@echo "App bundle installed to $(APP_BUNDLE)"

uninstall:
	@echo "Uninstalling $(BINARY_NAME)..."
	@rm -f $(INSTALL_PATH)/$(BINARY_NAME)
	@rm -rf $(APP_BUNDLE)
	@rmdir $(APP_INSTALL_DIR) 2>/dev/null || true
	@echo "$(BINARY_NAME) uninstalled successfully"

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR) $(XCODE_PROJECT)
	@echo "Clean complete"

help:
	@echo "Available targets:"
	@echo "  build         - Build the unsigned $(BINARY_NAME) binary with SwiftPM"
	@echo "  build-signed  - Build the signed macOS app bundle with Xcode"
	@echo "  install       - Install the signed app bundle and CLI wrapper"
	@echo "  uninstall     - Remove the installed CLI wrapper and app bundle"
	@echo "  clean         - Remove build artifacts and generated Xcode project"
	@echo "  help          - Show this help message"
