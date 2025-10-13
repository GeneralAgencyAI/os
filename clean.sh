#!/usr/bin/env bash
# =============================================================================
# PiKVM Build Cleanup Script
# =============================================================================
# This script removes all build artifacts, caches, and Docker images created
# during the PiKVM OS and Packages build process.
#
# Usage:
#   ./clean.sh              # Interactive mode (asks for confirmation)
#   ./clean.sh --force      # Force mode (no confirmation)
#   ./clean.sh --docker     # Only clean Docker images/containers
#   ./clean.sh --all        # Clean everything including Docker system prune
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory (os/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$(cd "$SCRIPT_DIR/../packages" && pwd)"
cd "$SCRIPT_DIR"

# Parse arguments
FORCE=false
DOCKER_ONLY=false
CLEAN_ALL=false

for arg in "$@"; do
    case $arg in
        --force|-f)
            FORCE=true
            ;;
        --docker|-d)
            DOCKER_ONLY=true
            ;;
        --all|-a)
            CLEAN_ALL=true
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force, -f     Skip confirmation prompts"
            echo "  --docker, -d    Only clean Docker images and containers"
            echo "  --all, -a       Clean everything including Docker system prune"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            exit 1
            ;;
    esac
done

# Function to print colored messages
print_step() {
    echo -e "${BLUE}====>${NC} ${1}"
}

print_success() {
    echo -e "${GREEN}✓${NC} ${1}"
}

print_warning() {
    echo -e "${YELLOW}!${NC} ${1}"
}

print_error() {
    echo -e "${RED}✗${NC} ${1}"
}

# Function to ask for confirmation
confirm() {
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    local prompt="${1} (y/N): "
    read -p "$prompt" -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Function to get directory size
get_size() {
    if [ -d "$1" ]; then
        du -sh "$1" 2>/dev/null | cut -f1
    else
        echo "0B"
    fi
}

# Main cleanup function
cleanup_build_artifacts() {
    print_step "Cleaning build artifacts..."
    
    # Calculate sizes for OS directory
    local os_pi_builder_size=$(get_size "$SCRIPT_DIR/.pi-builder")
    local os_cache_size=$(get_size "$SCRIPT_DIR/.cache")
    local images_size=$(get_size "$SCRIPT_DIR/images")
    
    # Calculate sizes for Packages directory
    local pkg_pi_builder_size=$(get_size "$PACKAGES_DIR/.pi-builder")
    local pkg_build_size=$(get_size "$PACKAGES_DIR/.build")
    local repos_size=$(get_size "$PACKAGES_DIR/repos")
    
    echo ""
    echo "OS directories to be removed:"
    [ -d "$SCRIPT_DIR/.pi-builder" ] && echo "  - os/.pi-builder/       ($os_pi_builder_size)"
    [ -d "$SCRIPT_DIR/.cache" ] && echo "  - os/.cache/            ($os_cache_size)"
    [ -d "$SCRIPT_DIR/images" ] && echo "  - os/images/            ($images_size - built OS images)"
    [ -f "$SCRIPT_DIR/build.log" ] && echo "  - os/build.log"
    
    echo ""
    echo "Packages directories to be removed:"
    [ -d "$PACKAGES_DIR/.pi-builder" ] && echo "  - packages/.pi-builder/ ($pkg_pi_builder_size)"
    [ -d "$PACKAGES_DIR/.build" ] && echo "  - packages/.build/      ($pkg_build_size)"
    [ -d "$PACKAGES_DIR/repos" ] && echo "  - packages/repos/       ($repos_size - built packages)"
    echo ""
    
    if confirm "Remove all build artifacts?"; then
        # Clean OS directory
        print_step "Cleaning OS build directory..."
        
        if [ -d "$SCRIPT_DIR/.pi-builder" ]; then
            rm -rf "$SCRIPT_DIR/.pi-builder"
            print_success "Removed os/.pi-builder/"
        fi
        
        if [ -d "$SCRIPT_DIR/.cache" ]; then
            rm -rf "$SCRIPT_DIR/.cache"
            print_success "Removed os/.cache/"
        fi
        
        if [ -f "$SCRIPT_DIR/build.log" ]; then
            rm -f "$SCRIPT_DIR/build.log"
            print_success "Removed os/build.log"
        fi
        
        # Clean Packages directory
        print_step "Cleaning Packages build directory..."
        
        if [ -d "$PACKAGES_DIR/.pi-builder" ]; then
            rm -rf "$PACKAGES_DIR/.pi-builder"
            print_success "Removed packages/.pi-builder/"
        fi
        
        if [ -d "$PACKAGES_DIR/.build" ]; then
            rm -rf "$PACKAGES_DIR/.build"
            print_success "Removed packages/.build/"
        fi
        
        # Ask about images directory separately
        if [ -d "$SCRIPT_DIR/images" ]; then
            echo ""
            print_warning "The os/images/ directory contains your built OS images."
            if confirm "Remove os/images directory too?"; then
                rm -rf "$SCRIPT_DIR/images"
                print_success "Removed os/images/"
            else
                print_warning "Kept os/images/ directory"
            fi
        fi
        
        # Ask about repos directory separately
        if [ -d "$PACKAGES_DIR/repos" ]; then
            echo ""
            print_warning "The packages/repos/ directory contains your built packages."
            if confirm "Remove packages/repos directory too?"; then
                rm -rf "$PACKAGES_DIR/repos"
                print_success "Removed packages/repos/"
            else
                print_warning "Kept packages/repos/ directory"
            fi
        fi
        
        print_success "Build artifacts cleaned"
    else
        print_warning "Skipped build artifacts cleanup"
    fi
}

# Docker cleanup function
cleanup_docker() {
    print_step "Cleaning Docker images and containers..."
    
    # List PiKVM related Docker images (both OS and Packages)
    local os_images=$(docker images --filter=reference='pi-builder.*' --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)
    local pkg_images=$(docker images --filter=reference='pikvm-packages.*' --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || true)
    
    local has_images=false
    
    if [ -n "$os_images" ] || [ -n "$pkg_images" ]; then
        echo ""
        echo "Docker images to be removed:"
        
        if [ -n "$os_images" ]; then
            echo ""
            echo "OS Build Images:"
            echo "$os_images" | sed 's/^/  - /'
            has_images=true
        fi
        
        if [ -n "$pkg_images" ]; then
            echo ""
            echo "Packages Build Images:"
            echo "$pkg_images" | sed 's/^/  - /'
            has_images=true
        fi
        echo ""
        
        if confirm "Remove PiKVM Docker images?"; then
            print_step "Removing PiKVM Docker images..."
            
            if [ -n "$os_images" ]; then
                docker images --filter=reference='pi-builder.*' -q | xargs -r docker rmi -f 2>/dev/null || true
            fi
            
            if [ -n "$pkg_images" ]; then
                docker images --filter=reference='pikvm-packages.*' -q | xargs -r docker rmi -f 2>/dev/null || true
            fi
            
            print_success "Removed PiKVM Docker images"
        else
            print_warning "Skipped Docker image cleanup"
        fi
    else
        print_warning "No PiKVM Docker images found"
    fi
    
    # Clean stopped containers (both OS and Packages)
    local stopped_os=$(docker ps -a --filter ancestor=pi-builder.common.buildenv --filter status=exited -q 2>/dev/null || true)
    local stopped_pkg=$(docker ps -a --filter ancestor=pikvm-packages.common.buildenv --filter status=exited -q 2>/dev/null || true)
    
    if [ -n "$stopped_os" ] || [ -n "$stopped_pkg" ]; then
        echo ""
        if confirm "Remove stopped PiKVM containers?"; then
            print_step "Removing stopped containers..."
            [ -n "$stopped_os" ] && echo "$stopped_os" | xargs -r docker rm 2>/dev/null || true
            [ -n "$stopped_pkg" ] && echo "$stopped_pkg" | xargs -r docker rm 2>/dev/null || true
            print_success "Removed stopped containers"
        fi
    fi
    
    # Docker system prune (if --all flag is set)
    if [ "$CLEAN_ALL" = true ]; then
        echo ""
        print_warning "Full Docker system prune will remove:"
        print_warning "  - All stopped containers"
        print_warning "  - All networks not used by at least one container"
        print_warning "  - All dangling images"
        print_warning "  - All dangling build cache"
        echo ""
        
        if confirm "Perform Docker system prune?"; then
            print_step "Running Docker system prune..."
            docker system prune -af
            print_success "Docker system cleaned"
        else
            print_warning "Skipped Docker system prune"
        fi
    fi
}

# Main execution
echo ""
echo "=========================================="
echo "  PiKVM Build Cleanup"
echo "  (OS + Packages)"
echo "=========================================="
echo ""

if [ "$DOCKER_ONLY" = true ]; then
    cleanup_docker
else
    cleanup_build_artifacts
    echo ""
    cleanup_docker
fi

echo ""
print_success "Cleanup complete!"
echo ""

# Show remaining space
if command -v df &> /dev/null; then
    echo "Current disk usage:"
    df -h "$SCRIPT_DIR" | tail -1
    echo ""
fi

