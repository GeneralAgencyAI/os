# Base board
BOARD = rpi4

# Hardware configuration
PLATFORM = v4plus-hdmi

# Target hostname
HOSTNAME = pikvm

# ru_RU, etc. UTF-8 only
LOCALE = en_US

# See /usr/share/zoneinfo
TIMEZONE = America/Los_Angeles

# For SSH root user
ROOT_PASSWD = rootpass

# Web UI credentials: user=admin, password=adminpass
WEBUI_ADMIN_PASSWD = adminpass

# IPMI credentials: user=admin, password=adminpass
IPMI_ADMIN_PASSWD = adminpass

# Local repository paths (REQUIRED - always uses local repos)
# Use absolute WSL paths for Docker compatibility
LOCAL_KVMD_REPO = /pikvm/kvmd
LOCAL_PACKAGES_REPO = /pikvm/packages
