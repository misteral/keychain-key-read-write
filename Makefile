.PHONY: build install uninstall clean help

BINARY_NAME = kc
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release
INSTALL_PATH = $(HOME)/.local/bin

build:
	@echo "Building $(BINARY_NAME) in release mode..."
	swift build -c release

install: build
	@echo "Installing $(BINARY_NAME) to $(INSTALL_PATH)..."
	@mkdir -p $(INSTALL_PATH)
	@cp -f $(RELEASE_DIR)/$(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "$(BINARY_NAME) installed successfully to $(INSTALL_PATH)/$(BINARY_NAME)"

uninstall:
	@echo "Uninstalling $(BINARY_NAME)..."
	@rm -f $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "$(BINARY_NAME) uninstalled successfully"

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "Clean complete"

help:
	@echo "Available targets:"
	@echo "  build      - Build the $(BINARY_NAME) binary in release mode"
	@echo "  install    - Build and install $(BINARY_NAME) to $(INSTALL_PATH)"
	@echo "  uninstall  - Remove $(BINARY_NAME) from $(INSTALL_PATH)"
	@echo "  clean      - Remove build artifacts"
	@echo "  help       - Show this help message"
