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
	$(MAKE) -C $(LOCAL_PACKAGES_REPO) buildenv BOARD=$(BOARD) ARCH=$(ARCH) PROJECT=pikvm-packages STAGES="__init__ buildenv"
	$(MAKE) -C $(LOCAL_PACKAGES_REPO) _build BOARD=$(BOARD) ARCH=$(ARCH) PKG=kvmd PROJECT=pikvm-packages NOSIGN=1 FORCE=1 NOINT=1
	@ echo "===== kvmd package build complete ====="


os: $(_BUILDER_DIR) build-kvmd-package
	rm -rf $(_BUILDER_DIR)/stages/arch/{pikvm,pikvm-otg-console}
	cp -a stages/arch/{pikvm,pikvm-otg-console} $(_BUILDER_DIR)/stages/arch
	rm -rf $(_BUILDER_DIR)/local-kvmd
	mkdir -p $(_BUILDER_DIR)/local-kvmd
	cp -a $(LOCAL_PACKAGES_REPO)/repos/$(BOARD)-$(ARCH)/kvmd*.pkg.tar.xz $(_BUILDER_DIR)/local-kvmd/ 2>/dev/null || true
	$(MAKE) -C $(_BUILDER_DIR) os \
		BUILD_OPTS=' $(BUILD_OPTS) \
			--build-arg PLATFORM=$(PLATFORM) \
			--build-arg OLED=$(call optbool,$(OLED)) \
			--build-arg VERSIONS=$(call fv,ustreamer)/$(call pkgversion,kvmd)/$(call fv,kvmd-webterm)/$(call fv,kvmd-fan) \
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
