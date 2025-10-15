#!/bin/bash
# setup-dev-env.sh - Prepare PiKVM development environment
# This script sets up everything needed for KVMD development but does NOT install/modify KVMD itself

set -e  # Exit on error

echo "=========================================="
echo "PiKVM Development Environment Setup"
echo "=========================================="
echo ""

# Function to print status
print_status() {
    echo ""
    echo "---"
    echo "$1"
    echo "---"
}

# Switch to read-write mode
print_status "Switching to read-write mode"
rw

# Step 1: Check and install pip if needed
print_status "Step 1: Checking for pip"
if ! command -v pip &> /dev/null; then
    echo "pip not found, installing..."
    
    # Download get-pip.py
    cd /tmp
    curl -sS https://bootstrap.pypa.io/get-pip.py -o get-pip.py || \
    wget -q https://bootstrap.pypa.io/get-pip.py -O get-pip.py
    
    # Install pip
    python get-pip.py --break-system-packages
    rm -f get-pip.py
    
    echo "✓ pip installed"
else
    echo "✓ pip already installed: $(pip --version)"
fi

# Step 2: Set California mirror
print_status "Step 2: Configuring package mirror"
if grep -q "ca.us.mirror.archlinuxarm.org" /etc/pacman.d/mirrorlist; then
    echo "✓ California mirror already configured"
else
    echo "Setting California mirror as default..."
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    cat > /etc/pacman.d/mirrorlist << 'EOF'
# California Mirror (Primary)
Server = http://ca.us.mirror.archlinuxarm.org/$arch/$repo

# Fallback mirrors
Server = http://us.mirror.archlinuxarm.org/$arch/$repo
Server = http://mirror.archlinuxarm.org/$arch/$repo
EOF
    echo "✓ Mirror configured"
fi

# Refresh package database
echo "Refreshing package database..."
pacman -Syy

# Step 3: Install system dependencies
print_status "Step 3: Installing system dependencies"

CRITICAL_PACKAGES=(
    python-yaml
    python-aiohttp
    python-aiohappyeyeballs
    python-aiofiles
    python-async-lru
    python-passlib
    python-bcrypt
    python-pyotp
    python-pyserial
    python-pillow
    python-setproctitle
    python-psutil
    python-netifaces
    python-systemd
    python-dbus
    python-mako
    python-evdev
)

echo "Installing ${#CRITICAL_PACKAGES[@]} packages..."
set +e  # Don't exit on package install errors

INSTALLED=0
FAILED=0
ALREADY=0

for pkg in "${CRITICAL_PACKAGES[@]}"; do
    printf "  %-30s " "$pkg"
    
    if pacman -Q "$pkg" &>/dev/null; then
        echo "✓ already installed"
        ALREADY=$((ALREADY + 1))
    elif pacman -S --needed --noconfirm "$pkg" &>/dev/null; then
        echo "✓ installed"
        INSTALLED=$((INSTALLED + 1))
    else
        echo "✗ failed"
        FAILED=$((FAILED + 1))
    fi
done

set -e
echo ""
echo "Summary: $INSTALLED installed, $ALREADY already present, $FAILED failed"

if [ $FAILED -gt 0 ]; then
    echo ""
    echo "Warning: Some packages failed to install."
    echo "This may cause issues. Consider running: pacman -Syu"
    echo ""
    read -p "Continue anyway? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ro
        exit 1
    fi
fi

# Step 4: Fix broken aiohttp packages
print_status "Step 4: Fixing aiohttp compatibility"

echo "Reinstalling aiohttp and aiohappyeyeballs..."
set +e
pacman -S --noconfirm python-aiohttp python-aiohappyeyeballs 2>&1 | grep -v "^warning:" || true
set -e

# Verify they're installed
if pacman -Q python-aiohttp &>/dev/null && pacman -Q python-aiohappyeyeballs &>/dev/null; then
    echo "✓ aiohttp packages OK"
else
    echo "⚠ Warning: aiohttp packages may not be properly installed"
fi

# Step 5: Clone KVMD repository
print_status "Step 5: Cloning KVMD repository"

KVMD_DIR="$HOME/kvmd"

if [ -d "$KVMD_DIR" ]; then
    echo "KVMD directory already exists at: $KVMD_DIR"
    read -p "Remove and re-clone? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing existing directory..."
        rm -rf "$KVMD_DIR"
    else
        echo "Keeping existing directory, updating instead..."
        cd "$KVMD_DIR"
        if [ -d .git ]; then
            git pull || echo "Warning: git pull failed"
        fi
        print_status "Setup Complete!"
        ro
        exit 0
    fi
fi

echo "Cloning from git@github.com:GeneralAgencyAI/kvmd.git..."
cd "$HOME"

# Clone the repository
if git clone git@github.com:GeneralAgencyAI/kvmd.git; then
    echo "✓ Repository cloned to: $KVMD_DIR"
    cd "$KVMD_DIR"
    echo "Current commit: $(git log -1 --oneline 2>/dev/null || echo 'unknown')"
else
    echo "✗ Failed to clone repository"
    echo ""
    echo "Make sure:"
    echo "  1. Your SSH keys are properly configured in ~/.ssh/"
    echo "  2. Your SSH public key is added to your GitHub account"
    echo "  3. You have access to the GeneralAgencyAI/kvmd repository"
    echo ""
    echo "Test SSH access with: ssh -T git@github.com"
    ro
    exit 1
fi

# Step 6: Switch back to read-only mode
print_status "Step 6: Switching to read-only mode"
ro
echo "✓ Filesystem is now read-only"

# Final status
print_status "Setup Complete!"

echo ""
echo "=========================================="
echo "Development Environment Summary"
echo "=========================================="
echo ""
echo "✓ pip installed and configured"
echo "✓ System dependencies installed"
echo "✓ aiohttp compatibility fixed"
echo "✓ KVMD repository cloned to: $KVMD_DIR"
echo ""
echo "Next steps:"
echo "  1. Make your changes in: $KVMD_DIR"
echo "  2. Test your changes with: cd $KVMD_DIR && ./sideload_kvmd.sh"
echo ""
echo "Useful commands:"
echo "  cd $KVMD_DIR          # Navigate to KVMD source"
echo "  git status            # Check current changes"
echo "  git pull              # Update from remote"
echo "  ./sideload_kvmd.sh    # Install and test your changes"
echo ""
echo "=========================================="
echo ""
echo "Done!"

