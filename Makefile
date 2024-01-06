MAKEFILE_PATH := $(realpath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(shell dirname $(MAKEFILE_PATH))
BUILD_DIR := $(MAKEFILE_DIR)/build
BUNDLE_DIR := $(BUILD_DIR)/opt-layer2
$(shell mkdir -p $(BUILD_DIR))

# Read the version from version.txt
VERSION := $(shell cat version.txt)

ONLINE_BUNDLE_NAME := opt-layer2-$(VERSION).x86_64.tar.gz
OFFLINE_BUNDLE_NAME := opt-layer2-$(VERSION)-offline.x86_64.tar.gz
ONLINE_BUNDLE := $(BUILD_DIR)/$(ONLINE_BUNDLE_NAME)
OFFLINE_BUNDLE := $(BUILD_DIR)/$(OFFLINE_BUNDLE_NAME)
TEMPLATE_NAME := vm-$(VERSION)
OVA_NAME := $(TEMPLATE_NAME).ova
OVA_PATH := $(BUILD_DIR)/$(OVA_NAME)
LINT_IMAGE := ansible-lint:latest

BOOTSTRAP_INVENTORY ?= vm_builder/inventory/golden_l1.py
UPGRADE_INVENTORY ?= vm_builder/inventory/template_l2.py

export ANSIBLE_vm_BASENAME := $(TEMPLATE_NAME)
export UPGRADE_vm_VM_NAME := vm-UPGRADERESOLV-4.0.0-$(VERSION)

# [Include other targets here as per your original Makefile]

.PHONY: increment-version
increment-version:
	@if [ "$(FINAL_RELEASE)" = "true" ]; then \
            ./version -f -t; \
        else \
            ./version -t; \
        fi

.PHONY: tag
tag: increment-version
	git tag -a $(shell cat version.txt) -m "Version $(shell cat version.txt)"
	git push origin $(shell cat version.txt)

# [Include the rest of your targets here]

.PHONY: tag-push
tag-push: tag
	git push --tags

# [Rest of your targets]

.PHONY: clean
clean:
	rm -rf build/

