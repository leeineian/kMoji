#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Identifiers
PLASMOID_ID="org.kmoji.plasma"

# Colors - readonly for safety
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Pre-build tags for performance
readonly TAG_INFO="${GREEN}[INFO]${NC}"
readonly TAG_WARN="${YELLOW}[WARN]${NC}"
readonly TAG_ERROR="${RED}[ERROR]${NC}"
readonly TAG_STEP="${BLUE}==>${NC}"

# Logging functions
log_info() { printf '%b\n' "$TAG_INFO" "$*"; }
log_warn() { printf '%b\n' "$TAG_WARN" "$*"; }
log_error() { printf '%b\n' "$TAG_ERROR" "$*" >&2; }
log_step() { printf '%b\n' "$TAG_STEP" "$*"; }

# Trap errors and interrupts
trap 'log_error "Installation aborted (line $LINENO)"' ERR
trap 'log_error "Installation cancelled"; exit 130' INT

# Usage
usage() {
    cat << EOF
kMoji Installation Script

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -x, --verbose       Enable verbose output for debugging
    --reload            Restart plasmashell after install to apply changes
    --uninstall         Uninstall kMoji

Examples:
    $0                  # Standard installation
    $0 --reload         # Install and immediately restart plasmashell
    $0 --uninstall      # Remove kMoji

EOF
}

# Parse arguments
DEBUG=false
UNINSTALL=false
RELOAD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;; 
        -x|--verbose)
            DEBUG=true
            shift
            ;; 
        --reload)
            RELOAD=true
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;; 
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;; 
    esac
done

# Enable verbose mode if requested
if [[ "$DEBUG" == "true" ]]; then
    PS4='+ ${BASH_SOURCE}:${LINENO}: '  # Clean trace output
    set -x
    log_info "Verbose mode enabled"
fi

# Uninstall function
uninstall_kmoji() {
    log_info "Uninstalling kMoji..."

    # Remove widget
    if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q "$PLASMOID_ID"; then
        log_step "Removing widget..."
        kpackagetool6 --type Plasma/Applet --remove "$PLASMOID_ID" || true
        log_info "✓ kMoji removed"
    else
        log_warn "kMoji not found."
    fi

    log_info "Uninstallation complete!"
    exit 0
}

# Handle uninstall
if [[ "${UNINSTALL}" == "true" ]]; then
    uninstall_kmoji
fi

# Main installation
log_info "kMoji Installation Script"
echo "========================="

# Check for KDE Plasma 6 tools
log_step "Checking prerequisites..."
if ! command -v kpackagetool6 &>/dev/null; then
    log_error "KDE Plasma 6 (kpackagetool6) not found."
    exit 1
fi
log_info "✓ KDE Plasma 6"

# Install plasmoid
log_step "Installing Plasma widget..."
cd "$PROJECT_ROOT"

if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q "$PLASMOID_ID"; then
    log_info "Found existing installation, upgrading..."
    kpackagetool6 --type Plasma/Applet --upgrade plasmoid
else
    kpackagetool6 --type Plasma/Applet --install plasmoid
fi
log_info "✓ Plasma widget installed"

# Final message
echo
log_info "Installation complete!"
echo -e "\nTo add the widget to your panel:"
echo "1. Right-click on your Plasma panel"
echo "2. Select 'Add Widgets'"
echo "3. Search for 'kMoji'"
echo "4. Drag the widget to your panel"

# Optional plasmashell reload
if [[ "${RELOAD}" == "true" ]]; then
    echo
    log_step "Restarting plasmashell..."
    # Detach from terminal so closing the shell won't kill the new instance.
    # --replace tells the new process to take over the currently running one.
    nohup plasmashell --replace > /dev/null 2>&1 & disown
    log_info "✓ plasmashell restarting in background"
fi
