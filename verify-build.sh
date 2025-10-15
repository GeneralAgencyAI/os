#!/bin/bash
#
# Verify Build Script
# Checks the built image to ensure local kvmd was installed correctly
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}===== Verifying Build Output =====${NC}"
echo ""

# Check 1: Verify packages were built
echo -e "${YELLOW}Check 1: Verifying local packages were built${NC}"
if [ ! -d "/pikvm/packages/repos/rpi4-arm" ]; then
    echo -e "${RED}✗ FAIL: Package repository not found at /pikvm/packages/repos/rpi4-arm${NC}"
    echo "  The build-kvmd-package step may have failed"
    exit 1
fi

if ls /pikvm/packages/repos/rpi4-arm/kvmd-4.*.pkg.tar.xz 1> /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS: Found kvmd base package${NC}"
    ls -lh /pikvm/packages/repos/rpi4-arm/kvmd-4.*.pkg.tar.xz
else
    echo -e "${RED}✗ FAIL: kvmd base package not found${NC}"
    exit 1
fi

if ls /pikvm/packages/repos/rpi4-arm/kvmd-platform-v4plus-hdmi-rpi4-*.pkg.tar.xz 1> /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS: Found kvmd-platform package${NC}"
    ls -lh /pikvm/packages/repos/rpi4-arm/kvmd-platform-v4plus-hdmi-rpi4-*.pkg.tar.xz
else
    echo -e "${RED}✗ FAIL: kvmd-platform package not found${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Check 2: Verifying packages were copied to Docker context${NC}"
BUILDER_DIR="/pikvm/os/.pi-builder/v4plus-hdmi-rpi4-arm"

if [ ! -d "$BUILDER_DIR/local-kvmd" ]; then
    echo -e "${YELLOW}⚠ WARNING: Builder directory not found (may have been cleaned)${NC}"
    echo "  Skipping Docker context check"
else
    if ls $BUILDER_DIR/local-kvmd/kvmd-*.pkg.tar.xz 1> /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS: Packages found in Docker context${NC}"
        ls -lh $BUILDER_DIR/local-kvmd/
    else
        echo -e "${RED}✗ FAIL: No packages in Docker context${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}===== Build Verification Complete =====${NC}"
echo ""
echo "If all checks passed, the build should work correctly."
echo "If boot still fails, the issue is likely in the Docker image build itself."
echo ""
echo "To check the Docker build logs, look for these lines:"
echo "  '==> Found local kvmd packages:'"
echo "  '==> Successfully installed local kvmd packages:'"
echo ""

