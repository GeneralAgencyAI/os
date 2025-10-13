#!/bin/bash
# Verify that the OS image was built from local sources
# Run this after: make os or ./build.sh

set -e

echo "========================================"
echo "PiKVM Local Build Verification"
echo "========================================"
echo ""

# Detect if we're in the build location or source location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$SCRIPT_DIR" = "/pikvm/os" ] || [ "$SCRIPT_DIR" = "/tmp/pikvm/os" ]; then
    echo "📍 Running from build location: $SCRIPT_DIR"
    BUILD_LOCATION="$SCRIPT_DIR"
else
    echo "📍 Running from source location: $SCRIPT_DIR"
    echo "   Checking build at /pikvm/os (or /tmp/pikvm/os if exists)"
    if [ -d "/pikvm/os" ]; then
        BUILD_LOCATION="/pikvm/os"
    elif [ -d "/tmp/pikvm/os" ]; then
        BUILD_LOCATION="/tmp/pikvm/os"
    else
        BUILD_LOCATION="$SCRIPT_DIR"
        echo "   ⚠️  Build location not found, checking local directory"
    fi
fi
echo ""

# Check build logs for local source indicators
cd "$BUILD_LOCATION"
BUILDER_DIR="./.pi-builder/v4plus-hdmi-rpi4-aarch64"

if [ ! -d "$BUILDER_DIR" ]; then
    echo "❌ Build directory not found: $BUILDER_DIR"
    echo "   Run 'make os' first"
    exit 1
fi

echo "1. Checking for local kvmd package in build..."
if [ -d "$BUILDER_DIR/local-kvmd" ]; then
    echo "   ✅ Local kvmd package directory exists in build context"
    echo "   Location: $BUILDER_DIR/local-kvmd"
    
    # Check if kvmd package exists
    KVMD_PKG=$(find "$BUILDER_DIR/local-kvmd" -name "kvmd-*.pkg.tar.xz" 2>/dev/null | head -1)
    if [ -n "$KVMD_PKG" ]; then
        echo "   ✅ Found kvmd package: $(basename "$KVMD_PKG")"
        echo "   📦 Size: $(du -h "$KVMD_PKG" | cut -f1)"
    else
        echo "   ⚠️  kvmd package not found in local-kvmd directory"
    fi
else
    echo "   ❌ Local kvmd package directory not found"
    echo "   The build may have used remote packages"
fi

echo ""
echo "2. Checking Dockerfile for local kvmd package configuration..."
DOCKERFILE_PATH="$BUILDER_DIR/stages/arch/pikvm/Dockerfile.part"
if [ -f "$DOCKERFILE_PATH" ]; then
    if grep -q "COPY.*local-kvmd.*kvmd.*\.pkg\.tar\.xz" "$DOCKERFILE_PATH" 2>/dev/null || \
       grep -q "local-kvmd" "$DOCKERFILE_PATH" 2>/dev/null; then
        echo "   ✅ Dockerfile configured to use local kvmd package"
        echo "   📄 Path: $DOCKERFILE_PATH"
    else
        echo "   ❌ Dockerfile not configured for local kvmd package"
        echo "   📄 Path: $DOCKERFILE_PATH"
    fi
else
    echo "   ⚠️  Dockerfile not found at: $DOCKERFILE_PATH"
    echo "   (This is expected if build hasn't started yet)"
fi

echo ""
echo "3. Checking package sources..."
# Determine packages repo location based on where we're running
if [ "$BUILD_LOCATION" = "/pikvm/os" ] || [ "$BUILD_LOCATION" = "/tmp/pikvm/os" ]; then
    PACKAGES_REPO="$(dirname "$BUILD_LOCATION")/packages"
else
    PACKAGES_REPO="${LOCAL_PACKAGES_REPO:-/pikvm/packages}"
fi

# Try both rpi4-aarch64 and rpi4-arm architectures
TARGET_ARCH=""
if [ -d "$PACKAGES_REPO/repos/rpi4-arm" ]; then
    TARGET_ARCH="rpi4-arm"
elif [ -d "$PACKAGES_REPO/repos/rpi4-aarch64" ]; then
    TARGET_ARCH="rpi4-aarch64"
fi

if [ -n "$TARGET_ARCH" ]; then
    echo "   ✅ Local package repository found"
    echo "   Location: $PACKAGES_REPO/repos/$TARGET_ARCH"
    
    # Count packages
    PKG_COUNT=$(find "$PACKAGES_REPO/repos/$TARGET_ARCH" -name "*.pkg.tar.xz" 2>/dev/null | wc -l)
    echo "   📦 Package count: $PKG_COUNT"
    
    # Check kvmd package timestamp
    KVMD_LOCAL=$(find "$PACKAGES_REPO/repos/$TARGET_ARCH" -name "kvmd-*.pkg.tar.xz" 2>/dev/null | head -1)
    if [ -n "$KVMD_LOCAL" ]; then
        echo "   📅 kvmd package: $(basename "$KVMD_LOCAL")"
        echo "   📅 Modified: $(stat -c %y "$KVMD_LOCAL" 2>/dev/null || stat -f "%Sm" "$KVMD_LOCAL" 2>/dev/null)"
    fi
else
    echo "   ❌ Local package repository not found"
    echo "   Searched: $PACKAGES_REPO/repos/rpi4-{arm,aarch64}"
fi

echo ""
echo "4. Checking for build markers..."
# Determine kvmd source location based on where we're running
if [ "$BUILD_LOCATION" = "/pikvm/os" ] || [ "$BUILD_LOCATION" = "/tmp/pikvm/os" ]; then
    KVMD_SRC="$(dirname "$BUILD_LOCATION")/kvmd"
else
    KVMD_SRC="${LOCAL_KVMD_REPO:-/pikvm/kvmd}"
fi

if [ -d "$KVMD_SRC/.git" ]; then
    echo "   ✅ Local kvmd repository is a git repo"
    echo "   📂 Location: $KVMD_SRC"
    echo "   📍 Current commit: $(git -C "$KVMD_SRC" log -1 --oneline 2>/dev/null || echo 'unknown')"
    echo "   🌿 Current branch: $(git -C "$KVMD_SRC" branch --show-current 2>/dev/null || echo 'unknown')"
elif [ -d "$KVMD_SRC" ]; then
    echo "   ⚠️  Local kvmd repository exists but is not a git repo"
    echo "   📂 Location: $KVMD_SRC"
else
    echo "   ❌ Local kvmd repository not found at: $KVMD_SRC"
fi

echo ""
echo "========================================"
echo "Summary"
echo "========================================"

# Final verdict
ISSUES=0
if [ ! -d "$BUILDER_DIR/local-kvmd" ]; then 
    echo "⚠️  Issue: local-kvmd directory not found in build"
    ((ISSUES++))
fi
if [ -f "$DOCKERFILE_PATH" ] && ! grep -q "local-kvmd" "$DOCKERFILE_PATH" 2>/dev/null; then 
    echo "⚠️  Issue: Dockerfile not configured for local kvmd package"
    ((ISSUES++))
fi
if [ -z "$TARGET_ARCH" ]; then 
    echo "⚠️  Issue: Local package repository not found"
    ((ISSUES++))
fi
if [ ! -d "$KVMD_SRC" ]; then 
    echo "⚠️  Issue: Local kvmd source not found"
    ((ISSUES++))
fi

echo ""
if [ $ISSUES -eq 0 ]; then
    echo "✅ Build verification PASSED"
    echo "   Your OS image was built from local sources"
else
    echo "❌ Build verification FAILED ($ISSUES issues found)"
    echo "   Some components may have used remote sources"
    echo ""
    echo "💡 Tip: Make sure to run ./build.sh or verify config.mk paths are correct"
    exit 1
fi

echo ""
echo "To verify on a running PiKVM device:"
echo "  ssh root@pikvm"
echo "  cat /usr/share/kvmd/.build-info"

