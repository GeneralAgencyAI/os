#!/bin/bash
# Verify that the OS image was built from local sources
# Run this after: make os

set -e

echo "========================================"
echo "PiKVM Local Build Verification"
echo "========================================"
echo ""

# Check build logs for local source indicators
BUILDER_DIR="./.pi-builder/v4plus-hdmi-rpi4-aarch64"

if [ ! -d "$BUILDER_DIR" ]; then
    echo "❌ Build directory not found: $BUILDER_DIR"
    echo "   Run 'make os' first"
    exit 1
fi

echo "1. Checking for local repository mount..."
if [ -d "$BUILDER_DIR/local-repo" ]; then
    echo "   ✅ Local package repository exists in build context"
    echo "   Location: $BUILDER_DIR/local-repo"
    
    # Check if kvmd package exists
    KVMD_PKG=$(find "$BUILDER_DIR/local-repo" -name "kvmd-4.*.pkg.tar.xz" 2>/dev/null | head -1)
    if [ -n "$KVMD_PKG" ]; then
        echo "   ✅ Found kvmd package: $(basename "$KVMD_PKG")"
    else
        echo "   ⚠️  kvmd package not found in local repo"
    fi
else
    echo "   ❌ Local repository directory not found"
    echo "   The build may have used remote packages"
fi

echo ""
echo "2. Checking Dockerfile for local repo configuration..."
if grep -q "COPY local-repo /local-repo" "$BUILDER_DIR/stages/pikvm/Dockerfile.part" 2>/dev/null; then
    echo "   ✅ Dockerfile configured to use local repository"
else
    echo "   ❌ Dockerfile not configured for local repository"
fi

echo ""
echo "3. Checking package sources..."
PACKAGES_REPO="${LOCAL_PACKAGES_REPO:-/pikvm/packages}"
if [ -d "$PACKAGES_REPO/repos/rpi4-aarch64" ]; then
    echo "   ✅ Local package repository found"
    echo "   Location: $PACKAGES_REPO/repos/rpi4-aarch64"
    
    # Count packages
    PKG_COUNT=$(find "$PACKAGES_REPO/repos/rpi4-aarch64" -name "*.pkg.tar.xz" 2>/dev/null | wc -l)
    echo "   📦 Package count: $PKG_COUNT"
    
    # Check kvmd package timestamp
    KVMD_LOCAL=$(find "$PACKAGES_REPO/repos/rpi4-aarch64" -name "kvmd-4.*.pkg.tar.xz" 2>/dev/null | head -1)
    if [ -n "$KVMD_LOCAL" ]; then
        echo "   📅 kvmd package modified: $(stat -c %y "$KVMD_LOCAL" 2>/dev/null || stat -f "%Sm" "$KVMD_LOCAL" 2>/dev/null)"
    fi
else
    echo "   ❌ Local package repository not found at: $PACKAGES_REPO/repos/rpi4-aarch64"
fi

echo ""
echo "4. Checking for build markers..."
KVMD_SRC="${LOCAL_KVMD_REPO:-/pikvm/kvmd}"
if [ -d "$KVMD_SRC/.git" ]; then
    echo "   ✅ Local kvmd repository is a git repo"
    echo "   📍 Current commit: $(git -C "$KVMD_SRC" log -1 --oneline 2>/dev/null || echo 'unknown')"
    echo "   🌿 Current branch: $(git -C "$KVMD_SRC" branch --show-current 2>/dev/null || echo 'unknown')"
else
    echo "   ⚠️  Local kvmd repository is not a git repo"
fi

echo ""
echo "========================================"
echo "Summary"
echo "========================================"

# Final verdict
ISSUES=0
if [ ! -d "$BUILDER_DIR/local-repo" ]; then ((ISSUES++)); fi
if ! grep -q "COPY local-repo /local-repo" "$BUILDER_DIR/stages/pikvm/Dockerfile.part" 2>/dev/null; then ((ISSUES++)); fi
if [ ! -d "$PACKAGES_REPO/repos/rpi4-aarch64" ]; then ((ISSUES++)); fi

if [ $ISSUES -eq 0 ]; then
    echo "✅ Build verification PASSED"
    echo "   Your OS image was built from local sources"
else
    echo "❌ Build verification FAILED ($ISSUES issues found)"
    echo "   Some components may have used remote sources"
    exit 1
fi

echo ""
echo "To verify on a running PiKVM device:"
echo "  ssh root@pikvm"
echo "  cat /usr/share/kvmd/.build-info"

