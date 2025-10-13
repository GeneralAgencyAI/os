# PiKVM OS Build Environment Setup Guide

## Overview

This guide covers setting up your build environment for compiling PiKVM OS with local modifications.

## System Requirements

Per [PiKVM Building Documentation](https://docs.pikvm.org/building_os/):

| Requirement | Minimum Version |
|-------------|----------------|
| Linux Kernel | >= 5.8 |
| glibc | >= 2.33 |
| Docker | >= 19.03.13 |
| Git | (any recent version) |

Additional tools needed:
- `make`
- `curl`
- `binutils`

## Automated Setup

### Quick Setup (Recommended)

```bash
cd /mnt/e/GitHub/Symmetric/pikvm/os
./setup-build-env.sh
```

The script will:
1. ✅ Detect your operating system
2. ✅ Check kernel and glibc versions
3. ✅ Install git, docker, make, curl, binutils (if missing)
4. ✅ Add your user to the docker group
5. ✅ Enable and start Docker service
6. ✅ Test Docker privileged mode

### Post-Setup Steps

If the script added you to the docker group, you'll need to either:

**Option 1: Quick (for current session only)**
```bash
newgrp docker
```

**Option 2: Permanent (requires logout)**
```bash
# Log out and log back in
```

## Manual Setup

If you prefer manual setup or the script doesn't work for your distribution:

### Ubuntu/Debian

```bash
# Install packages
sudo apt-get update
sudo apt-get install -y git make curl binutils docker.io

# Add user to docker group
sudo usermod -aG docker $USER

# Enable Docker
sudo systemctl enable docker
sudo systemctl start docker

# Log out and back in
```

### Fedora/RHEL/CentOS

```bash
# Install packages
sudo dnf install -y git make curl binutils docker

# Add user to docker group
sudo usermod -aG docker $USER

# Enable Docker
sudo systemctl enable docker
sudo systemctl start docker

# Log out and back in
```

### Arch Linux

```bash
# Install packages
sudo pacman -S git make curl binutils docker

# Add user to docker group
sudo usermod -aG docker $USER

# Enable Docker
sudo systemctl enable docker
sudo systemctl start docker

# Log out and back in
```

## Verifying Your Setup

### Check All Requirements

```bash
# Kernel version
uname -r
# Should be >= 5.8

# glibc version
ldd --version | head -n1
# Should be >= 2.33

# Docker version
docker --version
# Should be >= 19.03.13

# Git
git --version

# Test Docker (without sudo)
docker ps

# Test Docker privileged mode
docker run --rm --privileged alpine echo "Success"
```

## Building for the First Time

### 1. Configure Your Build

Edit `config.mk`:
```makefile
# Base board
BOARD = rpi4

# Hardware configuration
PLATFORM = v4plus-hdmi

# Target hostname
HOSTNAME = pikvm

# Locale
LOCALE = en_US

# Timezone
TIMEZONE = Europe/Nicosia

# Passwords
ROOT_PASSWD = rootpass
WEBUI_ADMIN_PASSWD = adminpass
IPMI_ADMIN_PASSWD = adminpass

# Local repository paths (relative paths work!)
LOCAL_KVMD_REPO = ../kvmd
LOCAL_PACKAGES_REPO = ../packages
```

### 2. Fix binfmt (First Time Only)

```bash
# For rpi4 (aarch64)
sudo bash -c 'echo -1 > /proc/sys/fs/binfmt_misc/aarch64'

# OR use the fix script
sudo bash fix-binfmt.sh
```

### 3. Build OS

```bash
cd /mnt/e/GitHub/Symmetric/pikvm/os

# Build OS (includes building kvmd package)
make os

# Create flashable image
make image
```

The image will be in `images/v4plus-hdmi-rpi4/arm/`.

## Recommended Environments

### Best: Native Ubuntu VM

**Why:**
- ✅ Most reliable (official environment)
- ✅ Best performance (native Linux filesystem)
- ✅ No WSL quirks or path translation issues
- ✅ Guaranteed to work

**Setup:**
1. Install Ubuntu 22.04 or newer in a VM (VirtualBox, VMware, Hyper-V)
2. Give it 4+ GB RAM and 50+ GB disk
3. Run `./setup-build-env.sh`
4. Build!

### Good: WSL2 (Ubuntu)

**Why:**
- ✅ Convenient (Windows integration)
- ⚠️ Some filesystem performance overhead
- ⚠️ Occasional path translation issues

**Recommendations:**
- Use **relative paths** in config.mk (not absolute `/mnt/e/...` paths)
- Build from within WSL filesystem when possible
- May need to use `DOCKER_BUILDKIT=0` if issues occur

### Possible Issues on WSL

If you encounter `getcwd: No such file or directory`:

**Solution 1:** Use relative paths (already configured)
```makefile
LOCAL_KVMD_REPO = ../kvmd
LOCAL_PACKAGES_REPO = ../packages
```

**Solution 2:** Disable Docker buildx
```bash
export DOCKER_BUILDKIT=0
make os
```

**Solution 3:** Move to native WSL filesystem
```bash
# Copy repos to WSL home
cp -r /mnt/e/GitHub/Symmetric/pikvm ~/
cd ~/pikvm/os
make os
```

## Troubleshooting

### Docker Permission Denied

```bash
# Add user to docker group (if not already done)
sudo usermod -aG docker $USER

# Log out and back in, OR:
newgrp docker
```

### Docker Build Fails with getcwd Error

```bash
# Use legacy builder instead of buildx
export DOCKER_BUILDKIT=0
make os
```

### Kernel Too Old

Upgrade your distribution:
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get dist-upgrade
sudo reboot
```

### glibc Too Old

Upgrade to a newer distribution version (e.g., Ubuntu 22.04 or newer).

## Build Performance Tips

1. **Use SSD storage** - Dramatically faster than HDD
2. **Allocate more CPU cores** to VM if using virtualization
3. **Use native Linux** instead of WSL for best performance
4. **Cache Docker layers** - Don't use `--no-cache` unless necessary

## Getting Help

- **PiKVM Discord**: https://discord.gg/bpmXfz5
- **PiKVM Forum**: https://forum.pikvm.org/
- **Documentation**: https://docs.pikvm.org/
- **GitHub Issues**: https://github.com/pikvm/os/issues

## References

- [Official PiKVM Building Documentation](https://docs.pikvm.org/building_os/)
- [Docker Installation Guide](https://docs.docker.com/engine/install/)
- [PiKVM GitHub - OS Repository](https://github.com/pikvm/os)

