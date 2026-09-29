# Makefile for Skinner47 Keyboard ZMK Firmware
SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.NOTPARALLEL:

# Resolve repository and workspace paths
ROOT_DIR      := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
WORKSPACE_DIR := $(abspath $(ROOT_DIR)/..)
CONFIG_DIR    ?= $(ROOT_DIR)/config
BUILD_DIR     ?= $(ROOT_DIR)/build

# Add virtual environment to PATH if present
ifneq ($(wildcard $(WORKSPACE_DIR)/.venv/bin),)
  export PATH := $(WORKSPACE_DIR)/.venv/bin:$(PATH)
else ifneq ($(wildcard $(ROOT_DIR)/.venv/bin),)
  export PATH := $(ROOT_DIR)/.venv/bin:$(PATH)
endif

# Locate ZMK app directory
ifneq ($(wildcard $(WORKSPACE_DIR)/zmk/app),)
  ZMK_APP_DIR ?= $(WORKSPACE_DIR)/zmk/app
else ifneq ($(wildcard $(ROOT_DIR)/zmk/app),)
  ZMK_APP_DIR ?= $(ROOT_DIR)/zmk/app
else
  ZMK_APP_DIR ?=
endif

# Build options
PRISTINE   ?= always
TIMESTAMP  := $(shell date +"%Y-%m-%dT%H-%M-%S.%3N")
OUTPUT_DIR ?= $(ROOT_DIR)/builds/$(TIMESTAMP)

.PHONY: all left right reset dongle left-peri dongle-reset dongle-all clean distclean help check-env

# Standalone split builds (Left is Central, Right is Peripheral)
all: check-env left right reset
	@echo ""
	@echo "========================================="
	@echo " All Standalone Builds Completed Successfully!"
	@echo " Firmware files saved to:"
	@echo "   - $(OUTPUT_DIR)/skinner47_left.uf2"
	@echo "   - $(OUTPUT_DIR)/skinner47_right.uf2"
	@echo "   - $(OUTPUT_DIR)/settings_reset.uf2"
	@echo "========================================="

check-env:
	@if [ -z "$(ZMK_APP_DIR)" ]; then \
		echo "Error: Cannot find zmk/app directory in $(WORKSPACE_DIR) or $(ROOT_DIR)" >&2; \
		exit 1; \
	fi
	@VENV_BIN="$$(which west 2>/dev/null | xargs dirname 2>/dev/null || true)"; \
	if [ -n "$$VENV_BIN" ] && [ ! -f "$$VENV_BIN/protoc" ]; then \
		echo "Creating protoc wrapper in $$VENV_BIN..."; \
		printf '#!/bin/bash\nexec python3 -m grpc_tools.protoc "$$@"\n' > "$$VENV_BIN/protoc"; \
		chmod +x "$$VENV_BIN/protoc"; \
	fi
	@mkdir -p "$(OUTPUT_DIR)"

# Left half (Central for standalone mode)
left: check-env
	@echo ""
	@echo "--> Building Left Half Central (skinner47_left)..."
	west build -s "$(ZMK_APP_DIR)" -d "$(BUILD_DIR)" -b skinner47_left -p $(PRISTINE) -- \
		-DSHIELD=nice_view \
		-DSNIPPET=studio-rpc-usb-uart \
		-DZMK_CONFIG="$(CONFIG_DIR)"
	@mkdir -p "$(OUTPUT_DIR)"
	cp "$(BUILD_DIR)/zephyr/zmk.uf2" "$(OUTPUT_DIR)/skinner47_left.uf2"
	@echo "✔ Saved: $(OUTPUT_DIR)/skinner47_left.uf2"

# Right half (Peripheral - used for both standalone and dongle modes)
right: check-env
	@echo ""
	@echo "--> Building Right Half (skinner47_right)..."
	west build -s "$(ZMK_APP_DIR)" -d "$(BUILD_DIR)" -b skinner47_right -p $(PRISTINE) -- \
		-DSHIELD=nice_view \
		-DZMK_CONFIG="$(CONFIG_DIR)"
	@mkdir -p "$(OUTPUT_DIR)"
	cp "$(BUILD_DIR)/zephyr/zmk.uf2" "$(OUTPUT_DIR)/skinner47_right.uf2"
	@echo "✔ Saved: $(OUTPUT_DIR)/skinner47_right.uf2"

# Left half (Peripheral for dongle mode)
left-peri: check-env
	@echo ""
	@echo "--> Building Left Half Peripheral (skinner47_left + skinner47_peripheral)..."
	west build -s "$(ZMK_APP_DIR)" -d "$(BUILD_DIR)" -b skinner47_left -p $(PRISTINE) -- \
		-DSHIELD="nice_view skinner47_peripheral" \
		-DZMK_CONFIG="$(CONFIG_DIR)"
	@mkdir -p "$(OUTPUT_DIR)"
	cp "$(BUILD_DIR)/zephyr/zmk.uf2" "$(OUTPUT_DIR)/skinner47_left_peripheral.uf2"
	@echo "✔ Saved: $(OUTPUT_DIR)/skinner47_left_peripheral.uf2"

# Dongle (Central with ZMK Studio support)
dongle: check-env
	@echo ""
	@echo "--> Building Dongle (nrf52840dongle_nrf52840 + skinner47_dongle)..."
	west build -s "$(ZMK_APP_DIR)" -d "$(BUILD_DIR)" -b nrf52840dongle_nrf52840 -p $(PRISTINE) -- \
		-DSHIELD=skinner47_dongle \
		-DSNIPPET=studio-rpc-usb-uart \
		-DZMK_CONFIG="$(CONFIG_DIR)"
	@mkdir -p "$(OUTPUT_DIR)"
	cp "$(BUILD_DIR)/zephyr/zmk.hex" "$(OUTPUT_DIR)/skinner47_dongle.hex"
	@if [ -f "$(BUILD_DIR)/zephyr/zmk.uf2" ]; then \
		cp "$(BUILD_DIR)/zephyr/zmk.uf2" "$(OUTPUT_DIR)/skinner47_dongle.uf2"; \
		echo "✔ Saved: $(OUTPUT_DIR)/skinner47_dongle.uf2"; \
	fi
	@echo "✔ Saved: $(OUTPUT_DIR)/skinner47_dongle.hex"

# Settings reset for keyboard halves
reset: check-env
	@echo ""
	@echo "--> Building Settings Reset for Halves (skinner47_left)..."
	west build -s "$(ZMK_APP_DIR)" -d "$(BUILD_DIR)" -b skinner47_left -p $(PRISTINE) -- \
		-DSHIELD=settings_reset \
		-DZMK_CONFIG="$(CONFIG_DIR)"
	@mkdir -p "$(OUTPUT_DIR)"
	cp "$(BUILD_DIR)/zephyr/zmk.uf2" "$(OUTPUT_DIR)/settings_reset.uf2"
	@echo "✔ Saved: $(OUTPUT_DIR)/settings_reset.uf2"

# Settings reset for dongle
dongle-reset: check-env
	@echo ""
	@echo "--> Building Settings Reset for Dongle (nrf52840dongle_nrf52840)..."
	west build -s "$(ZMK_APP_DIR)" -d "$(BUILD_DIR)" -b nrf52840dongle_nrf52840 -p $(PRISTINE) -- \
		-DSHIELD=settings_reset \
		-DZMK_CONFIG="$(CONFIG_DIR)"
	@mkdir -p "$(OUTPUT_DIR)"
	cp "$(BUILD_DIR)/zephyr/zmk.hex" "$(OUTPUT_DIR)/settings_reset_dongle.hex"
	@if [ -f "$(BUILD_DIR)/zephyr/zmk.uf2" ]; then \
		cp "$(BUILD_DIR)/zephyr/zmk.uf2" "$(OUTPUT_DIR)/settings_reset_dongle.uf2"; \
		echo "✔ Saved: $(OUTPUT_DIR)/settings_reset_dongle.uf2"; \
	fi
	@echo "✔ Saved: $(OUTPUT_DIR)/settings_reset_dongle.hex"

# Complete dongle ecosystem build
dongle-all: check-env dongle left-peri right reset dongle-reset
	@echo ""
	@echo "========================================="
	@echo " Dongle Setup Builds Completed Successfully!"
	@echo " Firmware files saved to $(OUTPUT_DIR):"
	@echo "   - skinner47_dongle.hex / .uf2 (Dongle Central)"
	@echo "   - skinner47_left_peripheral.uf2 (Left Half Peripheral)"
	@echo "   - skinner47_right.uf2 (Right Half Peripheral)"
	@echo "   - settings_reset.uf2 (Reset for halves)"
	@echo "   - settings_reset_dongle.hex / .uf2 (Reset for dongle)"
	@echo "========================================="

clean:
	@echo "Cleaning build directory..."
	rm -rf "$(BUILD_DIR)"

distclean: clean
	@echo "Cleaning all builds..."
	rm -rf "$(ROOT_DIR)/builds"

help:
	@echo "Usage: make [target] [PRISTINE=always|auto|never] [OUTPUT_DIR=path]"
	@echo ""
	@echo "Targets (Standalone mode):"
	@echo "  all           Build left central, right, and reset firmware (default)"
	@echo "  left          Build left half firmware as Central (skinner47_left + nice_view + studio-rpc)"
	@echo "  right         Build right half firmware as Peripheral (skinner47_right + nice_view)"
	@echo "  reset         Build settings reset firmware for halves"
	@echo ""
	@echo "Targets (Dongle mode):"
	@echo "  dongle-all    Build all firmware needed for dongle mode (dongle, left-peri, right, resets)"
	@echo "  dongle        Build USB dongle central firmware (skinner47_dongle + studio-rpc)"
	@echo "  left-peri     Build left half firmware as Peripheral (skinner47_peripheral)"
	@echo "  dongle-reset  Build settings reset firmware for dongle"
	@echo ""
	@echo "Utilities:"
	@echo "  clean         Remove intermediate build directory ($(BUILD_DIR))"
	@echo "  distclean     Remove intermediate build directory and all generated builds/"
	@echo "  help          Display this help message"
	@echo ""
	@echo "Options:"
	@echo "  PRISTINE      West build pristine mode (default: always, options: auto, never)"
	@echo "  OUTPUT_DIR    Target directory for output files (default: builds/<timestamp>)"
	@echo "  BUILD_DIR     Intermediate build directory (default: build)"
