# PiKVM OS - Local Build System

Build custom PiKVM OS images with your local code modifications.

**Hybrid Approach:**
- ✅ Your local **kvmd** code (always rebuilt)
- ✅ Official pre-built packages (fast downloads)
- ⚡ **Result:** 5-10 minute builds instead of 60+ minutes

---

## Prerequisites

From [PiKVM documentation](https://docs.pikvm.org/building_os/):
- Linux kernel >= 5.8
- glibc >= 2.33
- Docker >= 19.03.13
- git, make, curl, binutils

---

## Quick Setup (Automated)

### 1. Install Prerequisites

```bash
cd /mnt/e/GitHub/Symmetric/pikvm/os

# Automated setup (Ubuntu/Debian/Fedora/Arch)
./setup-build-env.sh
```

**What it does:**
- ✅ Checks system requirements (kernel, glibc, Docker)
- ✅ Installs missing packages
- ✅ Adds you to docker group
- ✅ Enables Docker service
- ✅ Tests Docker privileged mode

**After setup:** Log out and back in, or run:
```bash
newgrp docker
```

### 2. Configure Build

Edit `config.mk`:
```makefile
# Hardware
BOARD = rpi4
PLATFORM = v4plus-hdmi

# Credentials
ROOT_PASSWD = rootpass
WEBUI_ADMIN_PASSWD = adminpass
IPMI_ADMIN_PASSWD = adminpass

# Locale
HOSTNAME = pikvm
LOCALE = en_US
TIMEZONE = America/Los_Angeles

# Source paths (REQUIRED - already configured for WSL)
LOCAL_KVMD_REPO = /pikvm/kvmd
LOCAL_PACKAGES_REPO = /pikvm/packages
```

### 3. Fix binfmt (First Time Only)

```bash
# For rpi4 (64-bit)
sudo bash -c 'echo -1 > /proc/sys/fs/binfmt_misc/aarch64'

# For rpi2/rpi3/zero2w (32-bit)
sudo bash -c 'echo -1 > /proc/sys/fs/binfmt_misc/arm'
```

---

## Building (Two Methods)

### Method 1: Automated Build Script (Recommended for WSL)

The `build.sh` script handles all the complexities:

```bash
cd /mnt/e/GitHub/Symmetric/pikvm/os

# Build OS and create image
sudo ./build.sh
```

**What it does:**
1. Copies pikvm directory to `/pikvm/` (avoids WSL path issues)
2. Builds kvmd package from your local source
3. Creates OS image with official packages + your kvmd
4. Copies images back to `os/images/`
5. Shows build time and summary

**Options:**
```bash
# Build in /tmp (auto-cleanup on reboot)
sudo BUILD_IN_TMP=1 ./build.sh
```

**Output:** `os/images/v4plus-hdmi-rpi4/arm/*.img`

### Method 2: Direct Make (For Native Linux)

```bash
cd /mnt/e/GitHub/Symmetric/pikvm/os

# Build OS
make os

# Create flashable image
make image
```

**Output:** `os/images/v4plus-hdmi-rpi4/arm/*.img`

---

## Making Changes (Development Workflow)

```bash
# 1. Edit your code in Windows
# Edit: E:\GitHub\Symmetric\pikvm\kvmd\apps\kvmd\api.py

# 2. Rebuild (fast!)
cd /mnt/e/GitHub/Symmetric/pikvm/os
sudo ./build.sh

# Total time: ~5-10 minutes
# - Build kvmd: ~5 min
# - Create image: ~2 min

# 3. Flash to SD card and test
```

**Your changes are automatically included!**

---

## Verification

Check that your local code was used:

```bash
# After building
./verify-local-build.sh
```

**Example output:**
```
1. Checking for local kvmd package in build...
   ✅ Found kvmd package: kvmd-4.32-1-any.pkg.tar.xz

2. Checking Dockerfile configuration...
   ✅ Dockerfile configured to use local kvmd

3. Checking package sources...
   ✅ Local package repository found (45 packages)

4. Checking build markers...
   ✅ Git commit: abc1234 Custom changes

✅ Build verification PASSED
```

**On device:**
```bash
ssh root@pikvm
cat /usr/share/kvmd/.build-info
```

---

## Cleanup

Remove build artifacts to free disk space:

```bash
cd /mnt/e/GitHub/Symmetric/pikvm/os

# Interactive cleanup (asks what to remove)
./clean.sh

# Force cleanup (no prompts)
./clean.sh --force

# Only Docker images
./clean.sh --docker

# Everything including Docker system prune
./clean.sh --all
```

**What gets cleaned:**
- `os/.pi-builder/` - OS build cache
- `packages/.pi-builder/` - Package build cache
- `packages/.build/` - Package build directory
- `os/images/` - Built OS images (asks first)
- `packages/repos/` - Built packages (asks first)
- Docker images (pi-builder.*, pikvm-packages.*)

**After cleanup:**
```bash
# Clean up /pikvm build location (if using build.sh)
sudo rm -rf /pikvm
```

---

## Configuration Options

### Supported Boards

| Board | ARCH | PLATFORM Options |
|-------|------|------------------|
| rpi4 | arm | v4plus-hdmi, v4mini-hdmi |
| rpi3 | arm | v3-hdmi |
| rpi2 | arm | v2-hdmi |
| zero2w | arm | v2-hdmi |

### Example Configs

**Raspberry Pi 4 Plus:**
```makefile
BOARD = rpi4
PLATFORM = v4plus-hdmi
```

**Raspberry Pi 3:**
```makefile
BOARD = rpi3
PLATFORM = v3-hdmi
```

---

## Troubleshooting

### Build Script Fails with Permission Errors

**Solution:** Ensure you run with `sudo`:
```bash
sudo ./build.sh
```

The script needs sudo to copy to `/pikvm/` but runs builds as your user.

### Docker Permission Denied

**Solution:**
```bash
sudo usermod -aG docker $USER
newgrp docker  # or log out/in
```

### Docker Build Fails (getcwd error)

**Solution:** Use legacy builder:
```bash
export DOCKER_BUILDKIT=0
make os
```

Or use `build.sh` which handles this automatically.

### Kernel/glibc Too Old

**Solution:** Upgrade your distribution:
```bash
sudo apt-get update && sudo apt-get dist-upgrade
sudo reboot
```

Or use Ubuntu 22.04 or newer.

### binfmt Already Registered

If you see errors about binfmt, reset it:
```bash
# For rpi4
sudo bash -c 'echo -1 > /proc/sys/fs/binfmt_misc/aarch64'

# For rpi2/rpi3
sudo bash -c 'echo -1 > /proc/sys/fs/binfmt_misc/arm'
```

---

## Build Performance

| Environment | Build Time | Notes |
|-------------|------------|-------|
| Native Linux VM | ~10-15 min | Best performance |
| WSL2 (with build.sh) | ~15-20 min | Handles path issues |
| WSL2 (direct make) | ~10-15 min | If paths work |

**Tips:**
- Use SSD storage
- Allocate 4+ GB RAM to Docker
- Native Linux VM is fastest
- `build.sh` solves WSL path issues automatically

---

## What Gets Built Locally

| Component | Source | Time |
|-----------|--------|------|
| **kvmd** | Your local repo | ~5 min |
| ustreamer | Official package | Downloaded |
| kvmd-webterm | Official package | Downloaded |
| kvmd-fan | Official package | Downloaded |
| Dependencies | Official packages | Downloaded |

**Total:** ~10-15 minutes vs 60+ minutes for full local build

---

## Scripts Reference

### `build.sh`
Automated build with WSL path handling.

**Usage:**
```bash
sudo ./build.sh                 # Build in /pikvm
sudo BUILD_IN_TMP=1 ./build.sh  # Build in /tmp
```

### `clean.sh`
Remove build artifacts and Docker images.

**Usage:**
```bash
./clean.sh           # Interactive
./clean.sh --force   # No prompts
./clean.sh --docker  # Only Docker
./clean.sh --all     # Everything + system prune
```

### `setup-build-env.sh`
Install and configure build prerequisites.

**Usage:**
```bash
./setup-build-env.sh
```

### `verify-local-build.sh`
Verify your local code was used in build.

**Usage:**
```bash
./verify-local-build.sh
```

---

## Getting Help

- **PiKVM Documentation:** https://docs.pikvm.org/
- **Discord:** https://discord.gg/bpmXfz5
- **Forum:** https://forum.pikvm.org/
- **GitHub Issues:** https://github.com/pikvm/os/issues

---

## Official Images

Pre-built images (if you don't need custom builds):
https://files.pikvm.org
