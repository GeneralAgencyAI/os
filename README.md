# PiKVM OS - Hybrid Local Build

This build system uses a **hybrid approach**:
- ✅ **Official pre-built packages** from files.pikvm.org (fast)
- ✅ **Your local kvmd code** automatically built and included (guaranteed)

**Best of both worlds: Fast builds + Your modifications!**

## Prerequisites

Before building, ensure your system meets the requirements from [PiKVM documentation](https://docs.pikvm.org/building_os/):
- kernel >= 5.8
- glibc >= 2.33
- docker >= 19.03.13
- git

**Automatic setup** (recommended):
```bash
./setup-build-env.sh
```

This script will:
- ✅ Check all system requirements
- ✅ Install missing packages (git, docker, make, curl, binutils)
- ✅ Add your user to the docker group
- ✅ Verify Docker privileged mode works

**Note:** After running the script, you may need to log out and back in for Docker group membership to take effect.

## Quick Start

```bash
cd /mnt/e/GitHub/Symmetric/pikvm/os

# Fix binfmt (first time only - use script or manual command)
# Option 1: Use the script
sudo bash fix-binfmt.sh

# Option 2: Manual command for aarch64 (rpi4)
sudo bash -c 'echo -1 > /proc/sys/fs/binfmt_misc/aarch64'

# Option 3: Manual command for arm (rpi2/rpi3)
sudo bash -c 'echo -1 > /proc/sys/fs/binfmt_misc/arm'

# Build OS from local source
make os      # Builds kvmd package → OS image
make image   # Creates flashable .img file
```

## Configuration

All configuration is in `config.mk`:

- `LOCAL_KVMD_REPO` - Path to local kvmd source (REQUIRED)
- `LOCAL_PACKAGES_REPO` - Path to local packages repo (REQUIRED)
- `BOARD` - Target board (rpi4, rpi3, rpi2, zero2w)
- `ARCH` - Architecture (aarch64 for rpi4, arm for others)
- `PLATFORM` - Hardware config (v4plus-hdmi, v3-hdmi, v2-hdmi, etc.)

## What Happens

When you run `make os`:

1. Builds **only** kvmd package from `/mnt/e/GitHub/Symmetric/pikvm/kvmd` (~5 min)
2. Downloads official pre-built dependencies from files.pikvm.org (~5 min)
3. Installs official packages, then **replaces kvmd** with your version
4. OS image ready at `images/*/` with YOUR kvmd code (~10-15 min total)

**Much faster than building everything from source!**

## Making Changes

```bash
# 1. Edit code
cd /mnt/e/GitHub/Symmetric/pikvm/kvmd
# ... edit files ...

# 2. Rebuild (super fast!)
cd /mnt/e/GitHub/Symmetric/pikvm/os
make os      # Only rebuilds kvmd (~5 min), reuses official packages
make image
```

**Your changes are automatically included!**

## How It Works (Hybrid Approach)

1. **Builds kvmd** from your local source (FORCE=1, always rebuilds)
2. **Uses official packages** for dependencies (ustreamer, kvmd-webterm, etc.)
3. **Replaces official kvmd** with your locally-built version
4. **Result:** OS image with official dependencies + YOUR kvmd code

**Benefits:**
- ⚡ **5x faster** than building everything from source
- ✅ **Still uses** your local kvmd modifications  
- ✅ **Official dependencies** (tested, stable)
- ✅ **Perfect for development**

## Official Images

Official pre-built images: https://files.pikvm.org
