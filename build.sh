#!/bin/bash
#
# PiKVM Build Script
# 
# This script copies the pikvm repository to a build location with proper
# permissions, builds the OS and image, then copies the results back.
#
# Usage:
#   sudo ./build.sh                 # Build in /pikvm (default)
#   sudo BUILD_IN_TMP=1 ./build.sh  # Build in /tmp/pikvm (auto-cleanup on reboot)
#
# The script handles all permission issues automatically by:
# - Running as sudo to copy files to /pikvm
# - Preserving the actual user's UID/GID (not root)
# - Running make commands as the actual user to avoid Docker permission issues
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Source and destination paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIKVM_SOURCE_DIR="$(dirname "$SCRIPT_DIR")"  # Parent directory (pikvm)
# Use /pikvm by default, or /tmp/pikvm if BUILD_IN_TMP is set
DEST_DIR="${BUILD_IN_TMP:+/tmp}/pikvm"
IMAGE_DIR="images"

# Trap to handle errors
cleanup_on_error() {
    echo -e "\n${RED}Build failed! Check the error messages above.${NC}"
    echo -e "${YELLOW}Build directory preserved at: $DEST_DIR${NC}"
    echo -e "${YELLOW}You can inspect it or clean up with: sudo rm -rf $DEST_DIR${NC}"
}
trap cleanup_on_error ERR

echo -e "${GREEN}===== PiKVM Build Script =====${NC}"
echo "Source: $PIKVM_SOURCE_DIR"
echo "Build location: $DEST_DIR"
echo ""

# Start timing
BUILD_START=$(date +%s)

# Check if we're running as root (needed for copying to /)
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Warning: Not running as root. Will use sudo for copying to /${NC}"
    SUDO="sudo"
    REAL_USER=$(id -u)
    REAL_GROUP=$(id -g)
    REAL_USERNAME=$(id -un)
    REAL_HOME=$HOME
else
    SUDO=""
    # If running with sudo, get the actual user who invoked sudo
    if [ -n "$SUDO_UID" ]; then
        REAL_USER=$SUDO_UID
        REAL_GROUP=$SUDO_GID
        REAL_USERNAME=$SUDO_USER
        REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
    else
        # Running as actual root (not via sudo)
        echo -e "${RED}Error: Please run this script as a normal user with sudo, not as root${NC}"
        echo "Usage: sudo ./build.sh"
        exit 1
    fi
fi

echo "Building as user: $REAL_USERNAME (UID:$REAL_USER, GID:$REAL_GROUP)"
echo "Home directory: ${REAL_HOME:-/home/$REAL_USERNAME}"

# Step 1: Copy entire pikvm directory to /pikvm
echo -e "${GREEN}Step 1: Copying pikvm directory to $DEST_DIR${NC}"
$SUDO rm -rf "$DEST_DIR"
$SUDO mkdir -p "$DEST_DIR"
$SUDO cp -a "$PIKVM_SOURCE_DIR"/* "$DEST_DIR/"

# Ensure proper ownership and permissions
echo "Setting ownership to $REAL_USERNAME..."
$SUDO chown -R $REAL_USER:$REAL_GROUP "$DEST_DIR"

echo "Setting directory permissions to 755..."
$SUDO find "$DEST_DIR" -type d -exec chmod 755 {} \;

echo "Setting file permissions to 644 (scripts will be set to 755)..."
$SUDO find "$DEST_DIR" -type f -exec chmod 644 {} \;

echo "Making scripts executable..."
$SUDO find "$DEST_DIR" -type f \( -name "*.sh" -o -name "buildpkg" \) -exec chmod 755 {} \;

# Verify permissions
echo "Verifying permissions..."
OWNER_CHECK=$(stat -c '%U' "$DEST_DIR")
if [ "$OWNER_CHECK" != "$REAL_USERNAME" ]; then
    echo -e "${RED}Warning: Directory owner is $OWNER_CHECK, expected $REAL_USERNAME${NC}"
    echo -e "${YELLOW}Attempting to fix...${NC}"
    $SUDO chown -R $REAL_USER:$REAL_GROUP "$DEST_DIR"
fi

# Verify we can write to the directory
if [ ! -w "$DEST_DIR/os" ]; then
    echo -e "${RED}Error: Cannot write to $DEST_DIR/os${NC}"
    exit 1
fi

echo -e "${GREEN}Permissions verified successfully${NC}"

# Step 2: Build OS
echo ""
echo -e "${GREEN}Step 2: Building OS (make os)${NC}"
cd "$DEST_DIR/os"

# Run make as the actual user (not root) to avoid permission issues with Docker
if [ "$EUID" -eq 0 ]; then
    echo "Running make as $REAL_USERNAME..."
    sudo -u "$REAL_USERNAME" -E HOME="${REAL_HOME:-/home/$REAL_USERNAME}" make os
else
    make os
fi

# Step 3: Create image
echo ""
echo -e "${GREEN}Step 3: Creating image (make image)${NC}"
if [ "$EUID" -eq 0 ]; then
    sudo -u "$REAL_USERNAME" -E HOME="${REAL_HOME:-/home/$REAL_USERNAME}" make image
else
    make image
fi

# Step 4: Copy images back
echo ""
echo -e "${GREEN}Step 4: Copying built images back to source${NC}"
if [ -d "$DEST_DIR/os/$IMAGE_DIR" ]; then
    mkdir -p "$SCRIPT_DIR/$IMAGE_DIR"
    cp -a "$DEST_DIR/os/$IMAGE_DIR"/* "$SCRIPT_DIR/$IMAGE_DIR/"
    echo -e "${GREEN}Images copied to: $SCRIPT_DIR/$IMAGE_DIR${NC}"
    ls -lh "$SCRIPT_DIR/$IMAGE_DIR"
else
    echo -e "${RED}Error: Image directory not found at $DEST_DIR/os/$IMAGE_DIR${NC}"
    exit 1
fi

# Step 5: Optional - copy build artifacts back
echo ""
echo -e "${YELLOW}Copying build logs and artifacts...${NC}"
if [ -f "$DEST_DIR/os/build.log" ]; then
    cp "$DEST_DIR/os/build.log" "$SCRIPT_DIR/"
fi

echo ""
echo -e "${GREEN}===== Build Complete! =====${NC}"

# Calculate build time
BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))
BUILD_MINUTES=$((BUILD_TIME / 60))
BUILD_SECONDS=$((BUILD_TIME % 60))

echo ""
echo "Build Summary:"
echo "  Time taken: ${BUILD_MINUTES}m ${BUILD_SECONDS}s"
echo "  Images: $SCRIPT_DIR/$IMAGE_DIR"
if [ -d "$SCRIPT_DIR/$IMAGE_DIR" ]; then
    echo "  Total size: $(du -sh "$SCRIPT_DIR/$IMAGE_DIR" | cut -f1)"
fi
echo ""
echo -e "${GREEN}Images available at: $SCRIPT_DIR/$IMAGE_DIR${NC}"
echo ""
echo -e "${YELLOW}You can now clean up the build directory with:${NC}"
echo -e "${YELLOW}  sudo rm -rf $DEST_DIR${NC}"

