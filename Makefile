-include config.mk

PLATFORM ?= v2-hdmi
SUFFIX ?=
export BOARD ?= rpi4
export ARCH ?= arm
PROJECT ?= pikvm-os.$(PLATFORM)$(SUFFIX)
STAGES ?= __init__ os pikvm-repo pistat watchdog rootdelay ro pikvm restore-mirrorlist __cleanup__
export NC ?=

export HOSTNAME ?= pikvm
export LOCALE ?= en_US
export TIMEZONE ?= UTC
# Use California mirror - other mirrors having 404 issues
export ARCH_DIST_REPO_URL ?= http://ca.us.mirror.archlinuxarm.org
BUILD_OPTS ?=

ROOT_PASSWD ?= root
WEBUI_ADMIN_PASSWD ?= admin
IPMI_ADMIN_PASSWD ?= admin

# Export local repo paths (defined in config.mk or override here)
export LOCAL_KVMD_REPO ?= /pikvm/kvmd
export LOCAL_PACKAGES_REPO ?= /pikvm/packages

export DISK ?= $(shell pwd)/disk/$(word 1,$(subst -, ,$(PLATFORM))).conf
export CARD ?= /dev/null
export IMAGE_XZ ?=

DEPLOY_USER ?= root


# =====
SHELL = /usr/bin/env bash
_BUILDER_DIR = ./.pi-builder/$(PLATFORM)-$(BOARD)-$(ARCH)$(SUFFIX)

define optbool
$(filter $(shell echo $(1) | tr A-Z a-z),yes on 1)
endef

# Get version from files.pikvm.org for official packages
define fv
$(shell curl --silent "https://files.pikvm.org/repos/arch/$(BOARD)-$(ARCH)/latest/$(1)")
endef

# Read version from local PKGBUILD for locally-built packages
define read_pkgver
$(shell grep -E '^pkgver=' $(LOCAL_PACKAGES_REPO)/packages/$(1)/PKGBUILD | cut -d= -f2)
endef

define read_pkgrel
$(shell grep -E '^pkgrel=' $(LOCAL_PACKAGES_REPO)/packages/$(1)/PKGBUILD | cut -d= -f2)
endef

# Get package version in format: version-release
define pkgversion
$(call read_pkgver,$(1))-$(call read_pkgrel,$(1))
endef


# =====
all:
	@ echo "Available commands:"
	@ echo "    make                # Print this help"
	@ echo "    make os             # Build OS with your default config"
	@ echo "    make shell          # Run Arch-ARM shell"
	@ echo "    make install        # Install rootfs to partitions on $(CARD)"
	@ echo "    make image          # Create a binary image for burning outside of make install"
	@ echo "    make scan           # Find all RPi devices in the local network"
	@ echo "    make clean          # Remove the generated rootfs"
	@ echo "    make clean-all      # Remove the generated rootfs and pi-builder toolchain"


shell: $(_BUILDER_DIR)
	$(MAKE) -C $(_BUILDER_DIR) shell


# Build only kvmd package from local source (hybrid approach)
build-kvmd-package:
	@ echo "===== Building kvmd package from local source ====="
	@ echo "BOARD=$(BOARD), ARCH=$(ARCH)"
	@ echo "LOCAL_PACKAGES_REPO=$(LOCAL_PACKAGES_REPO)"
	@ echo "LOCAL_KVMD_REPO=$(LOCAL_KVMD_REPO)"
	@ test -n "$(LOCAL_PACKAGES_REPO)" || (echo "ERROR: LOCAL_PACKAGES_REPO not set in config.mk" && exit 1)
	@ test -n "$(LOCAL_KVMD_REPO)" || (echo "ERROR: LOCAL_KVMD_REPO not set in config.mk" && exit 1)
	@ test -d "$(LOCAL_PACKAGES_REPO)" || (echo "ERROR: LOCAL_PACKAGES_REPO directory not found: $(LOCAL_PACKAGES_REPO)" && exit 1)
	@ test -d "$(LOCAL_KVMD_REPO)" || (echo "ERROR: LOCAL_KVMD_REPO directory not found: $(LOCAL_KVMD_REPO)" && exit 1)
	$(MAKE) -C $(LOCAL_PACKAGES_REPO) buildenv BOARD=$(BOARD) ARCH=$(ARCH) PROJECT=pikvm-packages STAGES="__init__ buildenv"
	$(MAKE) -C $(LOCAL_PACKAGES_REPO) _build BOARD=$(BOARD) ARCH=$(ARCH) PKG=kvmd PROJECT=pikvm-packages NOSIGN=1 FORCE=1 NOINT=1
	@ echo "===== Verifying kvmd package was built ====="
	@ test -d "$(LOCAL_PACKAGES_REPO)/repos/$(BOARD)-$(ARCH)" || (echo "ERROR: Package repository directory not created: $(LOCAL_PACKAGES_REPO)/repos/$(BOARD)-$(ARCH)" && exit 1)
	@ ls -lh $(LOCAL_PACKAGES_REPO)/repos/$(BOARD)-$(ARCH)/kvmd*.pkg.tar.xz 2>/dev/null || (echo "ERROR: No kvmd package found in $(LOCAL_PACKAGES_REPO)/repos/$(BOARD)-$(ARCH)/" && exit 1)
	@ echo "✓ kvmd package build complete and verified"


os: $(_BUILDER_DIR) build-kvmd-package
	@ echo "===== Preparing pikvm stage with local packages ====="
	rm -rf $(_BUILDER_DIR)/stages/arch/{pikvm,pikvm-otg-console}
	cp -a stages/arch/{pikvm,pikvm-otg-console} $(_BUILDER_DIR)/stages/arch
	@ echo "Copying local packages to stage directory..."
	rm -rf $(_BUILDER_DIR)/stages/arch/pikvm/local-kvmd
	mkdir -p $(_BUILDER_DIR)/stages/arch/pikvm/local-kvmd
	cp -a $(LOCAL_PACKAGES_REPO)/repos/$(BOARD)-$(ARCH)/kvmd*.pkg.tar.xz $(_BUILDER_DIR)/stages/arch/pikvm/local-kvmd/
	@ echo "Packages prepared for Docker context:"
	@ ls -lh $(_BUILDER_DIR)/stages/arch/pikvm/local-kvmd/ | head -5
	@ echo "✓ Local kvmd packages prepared"
	@ echo "Preparing SSH keys..."
	rm -rf $(_BUILDER_DIR)/stages/arch/pikvm/.ssh-copy
	mkdir -p $(_BUILDER_DIR)/stages/arch/pikvm/.ssh-copy
	@ if [ -d .ssh-copy ] && [ "$(shell ls -A .ssh-copy 2>/dev/null)" ]; then \
		echo "Copying SSH keys..."; \
		cp -a .ssh-copy/* $(_BUILDER_DIR)/stages/arch/pikvm/.ssh-copy/; \
		echo "✓ SSH keys prepared"; \
	else \
		echo "No SSH keys, creating empty directory"; \
		touch $(_BUILDER_DIR)/stages/arch/pikvm/.ssh-copy/.keep; \
		echo "✓ Empty .ssh-copy prepared"; \
	fi
	@ echo "✓ pikvm stage fully prepared"
	$(MAKE) -C $(_BUILDER_DIR) os \
		STAGES='$(STAGES)' \
		BUILD_OPTS=' $(BUILD_OPTS) \
			--build-arg PLATFORM=$(PLATFORM) \
			--build-arg OLED=$(call optbool,$(OLED)) \
			--build-arg VERSIONS=$(call fv,ustreamer)/$(call pkgversion,kvmd)/$(call pkgversion,kvmd-webterm)/$(call fv,kvmd-fan) \
			--build-arg FAN=$(call optbool,$(FAN)) \
			--build-arg ROOT_PASSWD=$(ROOT_PASSWD) \
			--build-arg WEBUI_ADMIN_PASSWD=$(WEBUI_ADMIN_PASSWD) \
			--build-arg IPMI_ADMIN_PASSWD=$(IPMI_ADMIN_PASSWD) \
		'


$(_BUILDER_DIR):
	mkdir -p `dirname $(_BUILDER_DIR)`
	git clone --depth=1 https://github.com/mdevaev/pi-builder $(_BUILDER_DIR)


update: $(_BUILDER_DIR)
	cd $(_BUILDER_DIR) && git pull --rebase
	git pull --rebase


install: $(_BUILDER_DIR)
	$(MAKE) -C $(_BUILDER_DIR) install


image: $(_BUILDER_DIR)
	$(eval _dir := images/$(PLATFORM)-$(BOARD)/$(ARCH))
	$(eval _dated := $(PLATFORM)-$(BOARD)-$(ARCH)$(SUFFIX)-$(shell date +%Y%m%d).img)
	$(eval _latest := $(PLATFORM)-$(BOARD)-$(ARCH)$(SUFFIX)-latest.img)
	$(eval _suffix = $(if $(call optbool,$(IMAGE_XZ)),.xz,))
	mkdir -p $(_dir)
	$(MAKE) -C $(_BUILDER_DIR) image IMAGE=$(shell pwd)/$(_dir)/$(_dated)
	cd $(_dir) && ln -sf $(_dated)$(_suffix) $(_latest)$(_suffix)
	cd $(_dir) && ln -sf $(_dated)$(_suffix).sha1 $(_latest)$(_suffix).sha1


scan: $(_BUILDER_DIR)
	$(MAKE) -C $(_BUILDER_DIR) scan


clean: $(_BUILDER_DIR)
	$(MAKE) -C $(_BUILDER_DIR) clean


clean-all:
	- $(MAKE) -C $(_BUILDER_DIR) clean-all
	rm -rf $(_BUILDER_DIR)
	- rmdir `dirname $(_BUILDER_DIR)`


upload:
	rsync -rl --progress \
		images/ \
		$(DEPLOY_USER)@files.pikvm.org:/var/www/files.pikvm.org/images
