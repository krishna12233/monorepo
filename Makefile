MAKEFILE_PATH := $(realpath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(shell dirname $(MAKEFILE_PATH))
BUILD_DIR := $(MAKEFILE_DIR)/build
BUNDLE_DIR := $(BUILD_DIR)/opt-layer2
$(shell mkdir -p $(BUILD_DIR))

VERSION := $(shell ./version)

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

.PHONY: l2-install
l2-install: l2-bootstrap
	sshpass -f build/vm_password.txt \
		ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		$(shell cat build/vm_user.txt)@$(shell cat build/vm_ip.txt) "sudo su - root bash -c \
		'ansible-playbook -vvvvv /opt/ansible/opt-layer2/playbook.yml'"

.PHONY: l2-bootstrap
l2-bootstrap: $(ONLINE_BUNDLE)
	ansible-playbook -i $(BOOTSTRAP_INVENTORY) -e L2_VERSION=$(VERSION) -e L2_BUNDLE_PATH=$(ONLINE_BUNDLE) -e L2_BUNDLE_NAME=$(ONLINE_BUNDLE_NAME) -vvvvv vm_builder/bootstrap-l2-vm.yml

# Destroy the bootstrapped/installed vm. Can override vm name in vcenter by exporting 'ANSIBLE_vm_BASENAME'
.PHONY: teardown
teardown:
	ansible-playbook -i $(BOOTSTRAP_INVENTORY) vm_builder/teardown.yml
	rm -f build/*.txt

.PHONY: ansible-lint
ansible-lint:
	docker build -t $(LINT_IMAGE) test/lint/
	docker run --rm -v $(MAKEFILE_DIR):/opt-layer2 -it $(LINT_IMAGE) ansible-lint /opt-layer2/vm_builder
	docker run --rm -v $(MAKEFILE_DIR):/opt-layer2 -it $(LINT_IMAGE) ansible-lint /opt-layer2/opt-layer2

.PHONY: buildinfo
buildinfo:
	./bin/generate_buildinfo

$(OVA_PATH): l2-install
	ansible-playbook -i $(BOOTSTRAP_INVENTORY) vm_builder/shutdown.yml
	./bin/export_vm $(shell cat build/vm_vm_name.txt) $(OVA_PATH)

$(OFFLINE_BUNDLE): buildinfo
	export L2_TEMPLATE_VERSION=4.0.0; \
	cp -R opt-layer2 $(BUNDLE_DIR); \
	ansible-playbook -i $(UPGRADE_INVENTORY) -e L2_VERSION=$(VERSION) -e BUNDLE_FILENAME=$(OFFLINE_BUNDLE_NAME) -e BUNDLE_DIR=$(BUNDLE_DIR) -e PKG_DIR=$(BUNDLE_DIR)/pkg vm_builder/write-bundle-metadata.yml vm_builder/populate-offline-bundle.yml
	cd $(BUNDLE_DIR); \
	tar -czf $(OFFLINE_BUNDLE) ./*
	export L2_TEMPLATE_VERSION=4.0.0; \
	ansible-playbook -i $(UPGRADE_INVENTORY) vm_builder/teardown.yml
	rm -f build/*.txt
	rm -rf $(BUNDLE_DIR)

$(ONLINE_BUNDLE): buildinfo
	./download_bundle.sh
	cp -R opt-layer2 $(BUNDLE_DIR); \
	ansible-playbook -e L2_VERSION=$(VERSION) -e BUNDLE_FILENAME=$(ONLINE_BUNDLE_NAME) -e BUNDLE_DIR=$(BUNDLE_DIR) vm_builder/write-bundle-metadata.yml
	cd $(BUNDLE_DIR); \
	tar -czf $(ONLINE_BUNDLE) ./*
	rm -rf $(BUNDLE_DIR)

.PHONY: ova
ova: $(OVA_PATH)

.PHONY: publish-ova
publish-ova: $(OVA_PATH)
	curl -v -u "$(NEXUS_USERNAME)":"$(NEXUS_PASSWORD)" --upload-file $(OVA_PATH) https://nexus.opt.net/repository/appliance-builds/$(OVA_NAME)
	ansible-playbook -i $(BOOTSTRAP_INVENTORY) vm_builder/convert-vm-to-template.yml

.PHONY: offline-bundle
offline-bundle: $(OFFLINE_BUNDLE)

.PHONY: online-bundle
online-bundle: $(ONLINE_BUNDLE)

.PHONY: bundles
bundles: online-bundle offline-bundle

.PHONY: publish-online-bundle
publish-online-bundle: online-bundle
	curl -v -u "$(NEXUS_USERNAME)":"$(NEXUS_PASSWORD)" --upload-file $(ONLINE_BUNDLE) https://nexus.opt.net/repository/ansible-layer2/Packages/$(ONLINE_BUNDLE_NAME)

.PHONY: publish-offline-bundle
publish-offline-bundle: offline-bundle
	curl -v -u "$(NEXUS_USERNAME)":"$(NEXUS_PASSWORD)" --upload-file $(OFFLINE_BUNDLE) https://nexus.opt.net/repository/ansible-layer2/Packages/$(OFFLINE_BUNDLE_NAME)

.PHONY: publish
publish: publish-ova publish-online-bundle publish-offline-bundle

.PHONY: upgrade-bundles
upgrade-bundles: offline-bundle online-bundle

.PHONY: tag
tag:
	@if [[ "$(FINAL_RELEASE)" == "true" ]]; then \
		./version -t; \
	else \
		./version -f -t; \
	fi

.PHONY: tag-push
tag-push: tag
	git push --tags

.PHONY: clean
clean:
	rm -rf build/

