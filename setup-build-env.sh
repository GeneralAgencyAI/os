#!/bin/bash
# PiKVM OS Build Environment Setup Script
# Checks and installs requirements from https://docs.pikvm.org/building_os/
#
# Requirements:
# - kernel >= 5.8
# - glibc >= 2.33
# - docker >= 19.03.13
# - git

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Version comparison function
version_ge() {
    # Returns 0 (true) if $1 >= $2
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        print_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root. This script should be run as a regular user."
        print_info "The script will use sudo when needed."
        return 0
    fi
    return 1
}

# Check and install package
install_package() {
    local package=$1
    local check_cmd=${2:-$package}
    
    if command -v "$check_cmd" &> /dev/null; then
        print_success "$package is already installed"
        return 0
    fi
    
    print_warning "$package is not installed. Installing..."
    
    case "$OS" in
        ubuntu|debian)
            sudo apt-get update -qq
            sudo apt-get install -y "$package"
            ;;
        fedora|rhel|centos)
            sudo dnf install -y "$package"
            ;;
        arch)
            sudo pacman -S --noconfirm "$package"
            ;;
        *)
            print_error "Unsupported OS: $OS"
            print_info "Please install $package manually"
            return 1
            ;;
    esac
    
    if command -v "$check_cmd" &> /dev/null; then
        print_success "$package installed successfully"
        return 0
    else
        print_error "Failed to install $package"
        return 1
    fi
}

# Check kernel version
check_kernel() {
    print_header "Checking Kernel Version"
    
    KERNEL_VERSION=$(uname -r | cut -d'-' -f1)
    REQUIRED_KERNEL="5.8"
    
    print_info "Current kernel version: $KERNEL_VERSION"
    print_info "Required kernel version: >= $REQUIRED_KERNEL"
    
    if version_ge "$KERNEL_VERSION" "$REQUIRED_KERNEL"; then
        print_success "Kernel version is sufficient"
        return 0
    else
        print_error "Kernel version is too old!"
        print_warning "Please upgrade your system kernel to >= $REQUIRED_KERNEL"
        print_info "On Ubuntu/Debian: sudo apt-get upgrade && sudo reboot"
        return 1
    fi
}

# Check glibc version
check_glibc() {
    print_header "Checking glibc Version"
    
    GLIBC_VERSION=$(ldd --version | head -n1 | awk '{print $NF}')
    REQUIRED_GLIBC="2.33"
    
    print_info "Current glibc version: $GLIBC_VERSION"
    print_info "Required glibc version: >= $REQUIRED_GLIBC"
    
    if version_ge "$GLIBC_VERSION" "$REQUIRED_GLIBC"; then
        print_success "glibc version is sufficient"
        return 0
    else
        print_error "glibc version is too old!"
        print_warning "Please upgrade your system to a newer distribution with glibc >= $REQUIRED_GLIBC"
        return 1
    fi
}

# Check and install git
check_git() {
    print_header "Checking Git"
    
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version | awk '{print $3}')
        print_success "Git is installed (version $GIT_VERSION)"
        return 0
    else
        print_warning "Git is not installed"
        install_package "git" "git"
        return $?
    fi
}

# Check and install Docker
check_docker() {
    print_header "Checking Docker"
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        REQUIRED_DOCKER="19.03.13"
        
        print_info "Current Docker version: $DOCKER_VERSION"
        print_info "Required Docker version: >= $REQUIRED_DOCKER"
        
        if version_ge "$DOCKER_VERSION" "$REQUIRED_DOCKER"; then
            print_success "Docker version is sufficient"
        else
            print_warning "Docker version might be too old"
        fi
    else
        print_warning "Docker is not installed. Installing..."
        
        case "$OS" in
            ubuntu|debian)
                sudo apt-get update -qq
                sudo apt-get install -y docker.io
                ;;
            fedora|rhel|centos)
                sudo dnf install -y docker
                ;;
            arch)
                sudo pacman -S --noconfirm docker
                ;;
            *)
                print_error "Unsupported OS: $OS"
                print_info "Please install Docker manually from https://docs.docker.com/engine/install/"
                return 1
                ;;
        esac
        
        if command -v docker &> /dev/null; then
            print_success "Docker installed successfully"
        else
            print_error "Failed to install Docker"
            return 1
        fi
    fi
    
    # Enable and start Docker service
    if systemctl is-active --quiet docker; then
        print_success "Docker service is running"
    else
        print_warning "Docker service is not running. Starting..."
        sudo systemctl enable docker
        sudo systemctl start docker
        print_success "Docker service started"
    fi
    
    return 0
}

# Check and configure Docker group
check_docker_group() {
    print_header "Checking Docker Group Membership"
    
    if groups | grep -q docker; then
        print_success "User $USER is already in the docker group"
        
        # Test if docker works without sudo
        if docker ps &> /dev/null; then
            print_success "Docker works without sudo"
            return 0
        else
            print_warning "Docker group membership not yet active in current session"
            print_info "You may need to log out and back in, or run: newgrp docker"
            return 1
        fi
    else
        print_warning "User $USER is not in the docker group. Adding..."
        sudo usermod -aG docker "$USER"
        print_success "User added to docker group"
        print_warning "You MUST log out and log back in for this to take effect!"
        print_info "Or run: newgrp docker"
        return 1
    fi
}

# Install additional build tools
install_build_tools() {
    print_header "Checking Additional Build Tools"
    
    TOOLS=("make" "curl" "binutils")
    MISSING_TOOLS=()
    
    for tool in "${TOOLS[@]}"; do
        if command -v "$tool" &> /dev/null; then
            print_success "$tool is installed"
        else
            MISSING_TOOLS+=("$tool")
        fi
    done
    
    if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
        print_success "All build tools are installed"
        return 0
    fi
    
    print_warning "Installing missing build tools: ${MISSING_TOOLS[*]}"
    
    case "$OS" in
        ubuntu|debian)
            sudo apt-get update -qq
            sudo apt-get install -y make curl binutils
            ;;
        fedora|rhel|centos)
            sudo dnf install -y make curl binutils
            ;;
        arch)
            sudo pacman -S --noconfirm make curl binutils
            ;;
        *)
            print_error "Unsupported OS: $OS"
            return 1
            ;;
    esac
    
    print_success "Build tools installed"
    return 0
}

# Test Docker privileged mode
test_docker_privileged() {
    print_header "Testing Docker Privileged Mode"
    
    if ! docker ps &> /dev/null; then
        print_warning "Cannot test Docker (not accessible). Will test after relogin."
        return 1
    fi
    
    print_info "Testing Docker privileged mode..."
    if docker run --rm --privileged alpine echo "Docker privileged mode works" &> /dev/null; then
        print_success "Docker privileged mode is working"
        return 0
    else
        print_error "Docker privileged mode test failed"
        print_info "Make sure Docker daemon has necessary permissions"
        return 1
    fi
}

# Print summary
print_summary() {
    print_header "Setup Summary"
    
    echo ""
    echo "System Information:"
    echo "  OS: $OS $OS_VERSION"
    echo "  Kernel: $(uname -r)"
    echo "  glibc: $(ldd --version | head -n1 | awk '{print $NF}')"
    echo "  Git: $(git --version 2>/dev/null || echo 'not installed')"
    echo "  Docker: $(docker --version 2>/dev/null || echo 'not installed')"
    echo "  Make: $(make --version 2>/dev/null | head -n1 || echo 'not installed')"
    echo ""
    
    if [ $NEEDS_RELOGIN -eq 1 ]; then
        print_warning "ACTION REQUIRED:"
        echo ""
        echo "  You have been added to the docker group, but changes won't take"
        echo "  effect until you log out and log back in."
        echo ""
        echo "  Quick fix for current session:"
        echo "    newgrp docker"
        echo ""
        echo "  Or log out and back in for permanent effect."
        echo ""
    fi
    
    if [ $ALL_CHECKS_PASSED -eq 1 ]; then
        print_success "All requirements are satisfied!"
        echo ""
        echo "You can now build PiKVM OS:"
        echo "  cd $(dirname "$0")"
        echo "  make os"
        echo ""
    else
        print_error "Some requirements are not satisfied."
        echo ""
        echo "Please address the issues above before building PiKVM OS."
        echo ""
    fi
}

# Main execution
main() {
    print_header "PiKVM OS Build Environment Setup"
    echo ""
    print_info "This script will check and install requirements for building PiKVM OS"
    print_info "Reference: https://docs.pikvm.org/building_os/"
    echo ""
    
    # Detect OS
    detect_os
    print_info "Detected OS: $OS $OS_VERSION"
    echo ""
    
    # Track if relogin is needed
    NEEDS_RELOGIN=0
    ALL_CHECKS_PASSED=1
    
    # Run all checks
    check_kernel || ALL_CHECKS_PASSED=0
    echo ""
    
    check_glibc || ALL_CHECKS_PASSED=0
    echo ""
    
    check_git || ALL_CHECKS_PASSED=0
    echo ""
    
    install_build_tools || ALL_CHECKS_PASSED=0
    echo ""
    
    check_docker || ALL_CHECKS_PASSED=0
    echo ""
    
    if ! check_docker_group; then
        NEEDS_RELOGIN=1
        # Don't fail the check if we just added the user
        if [ $? -eq 1 ]; then
            true  # Don't mark as failed if we just need to relogin
        fi
    fi
    echo ""
    
    # Only test docker if we can access it
    if docker ps &> /dev/null; then
        test_docker_privileged || true  # Don't fail on this
        echo ""
    fi
    
    # Print summary
    print_summary
    
    if [ $ALL_CHECKS_PASSED -eq 0 ]; then
        exit 1
    fi
    
    exit 0
}

# Run main function
main "$@"

