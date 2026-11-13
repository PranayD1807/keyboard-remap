.PHONY: all build daemon ui install uninstall clean

BIN_DIR := $(HOME)/.local/bin
APP_DIR := $(HOME)/Applications

all: build

build: daemon ui

daemon:
	@mkdir -p $(BIN_DIR)
	swiftc -O src/daemon/main.swift -o $(BIN_DIR/lenovo-key-remap)

ui:
	@mkdir -p $(BIN_DIR)
	swiftc -framework SwiftUI -framework AppKit -O src/ui/main.swift -o $(BIN_DIR/keyboard-remap-ui)

install:
	@./install.sh

uninstall:
	@./uninstall.sh

clean:
	@rm -rf .build

