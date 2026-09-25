#!/usr/bin/env bash
# ==============================================================================
# termux-agent-station installer
# Transforms Android Termux into a sub-5ms low-latency AI coding workstation.
# ==============================================================================

set -euo pipefail

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "============================================================"
    echo "      Termux Agent Station - Automated Installer            "
    echo "  Turn Android into a High-Performance AI Coding Node       "
    echo "============================================================"
    echo -e "${NC}"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

print_ok() {
    echo -e "${GREEN}[OK]${NC} $*"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

print_err() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

show_help() {
    cat <<EOF
Usage: ./install.sh [OPTIONS]

Options:
  --mirror-cn       Force switch Termux pkg sources to Tsinghua University mirror
  --mirror-ustc     Force switch Termux pkg sources to USTC mirror
  --mirror-default  Keep default official package repositories
  --skip-packages   Skip apt/pkg package installation
  -h, --help        Show this help message and exit

EOF
}

# 1. Environment Detection
is_termux() {
    if [[ -n "${TERMUX_VERSION:-}" ]] || [[ "${PREFIX:-}" =~ com\.termux ]]; then
        return 0
    fi
    return 1
}

# Parse command-line flags
FORCE_MIRROR=""
SKIP_PACKAGES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mirror-cn|--mirror-tsinghua)
            FORCE_MIRROR="tsinghua"
            shift
            ;;
        --mirror-ustc)
            FORCE_MIRROR="ustc"
            shift
            ;;
        --mirror-default)
            FORCE_MIRROR="default"
            shift
            ;;
        --skip-packages)
            SKIP_PACKAGES=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_err "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

print_banner

if is_termux; then
    print_ok "Termux environment detected (Prefix: ${PREFIX:-/data/data/com.termux/files/usr})"
else
    print_warn "Running in non-Termux environment. Proceeding with installation to local user paths."
fi

# 2. Mirror Configuration (if inside Termux)
configure_mirrors() {
    local target_mirror="$1"
    local sources_file="${PREFIX:-/data/data/com.termux/files/usr}/etc/apt/sources.list"

    if [[ ! -w "$(dirname "$sources_file")" && ! -w "$sources_file" ]]; then
        print_warn "Cannot write to $sources_file. Skipping mirror configuration."
        return
    fi

    # Backup original sources.list if not already backed up
    if [[ -f "$sources_file" && ! -f "$sources_file.bak" ]]; then
        cp "$sources_file" "$sources_file.bak"
        print_info "Backed up original sources.list to $sources_file.bak"
    fi

    case "$target_mirror" in
        tsinghua)
            print_info "Configuring Tsinghua University (TUNA) mirror..."
            cat > "$sources_file" <<'EOF'
# Tsinghua University Termux Mirror
deb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main stable main
EOF
            print_ok "Tsinghua mirror configured."
            ;;
        ustc)
            print_info "Configuring USTC mirror..."
            cat > "$sources_file" <<'EOF'
# USTC Termux Mirror
deb https://mirrors.ustc.edu.cn/termux/apt/termux-main stable main
EOF
            print_ok "USTC mirror configured."
            ;;
        *)
            print_info "Keeping default package sources."
            ;;
    esac
}

if is_termux; then
    if [[ -n "$FORCE_MIRROR" ]]; then
        configure_mirrors "$FORCE_MIRROR"
    else
        # Auto-detect if user is likely in Mainland China
        TZ_DETECT="$(date +%Z 2>/dev/null || echo '')"
        if [[ "$TZ_DETECT" == "CST" ]] || [[ -f /system/build.prop && $(grep -Ei "ro.build.version.incremental|ro.miui|ro.vivo|ro.oppo" /system/build.prop 2>/dev/null) ]]; then
            print_info "Detected China region environment. Switching to Tsinghua mirror for faster downloads..."
            configure_mirrors "tsinghua"
        fi
    fi
fi

# 3. Package Installation
REQUIRED_PKGS=(openssh git curl zsh jq tmux)

if is_termux && ! $SKIP_PACKAGES; then
    print_info "Updating package lists and installing prerequisites: ${REQUIRED_PKGS[*]}..."
    pkg update -y || apt-get update -y
    pkg install -y "${REQUIRED_PKGS[@]}" || apt-get install -y "${REQUIRED_PKGS[@]}"
    print_ok "All prerequisite packages installed successfully."
elif ! $SKIP_PACKAGES; then
    print_info "Checking prerequisite packages on non-Termux system..."
    MISSING_PKGS=()
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            MISSING_PKGS+=("$pkg")
        fi
    done
    if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
        print_warn "Missing tools: ${MISSING_PKGS[*]}. Please install them using your system package manager."
    else
        print_ok "All prerequisite packages are already present."
    fi
fi

# 4. Install Termux UI & Key Configurations
TERMUX_CONFIG_DIR="$HOME/.termux"
mkdir -p "$TERMUX_CONFIG_DIR"

install_config() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [[ -f "$dest" ]]; then
        cp "$dest" "$dest.bak_$(date +%Y%m%d%H%M%S)"
        print_info "Backed up existing $name to $dest.bak_*"
    fi
    cp "$src" "$dest"
    print_ok "Installed $name -> $dest"
}

if [[ -f "$SCRIPT_DIR/configs/termux.properties" ]]; then
    install_config "$SCRIPT_DIR/configs/termux.properties" "$TERMUX_CONFIG_DIR/termux.properties" "termux.properties"
fi

if [[ -f "$SCRIPT_DIR/configs/colors.properties" ]]; then
    install_config "$SCRIPT_DIR/configs/colors.properties" "$TERMUX_CONFIG_DIR/colors.properties" "colors.properties"
fi

# Reload Termux UI if command is available
if command -v termux-reload-settings >/dev/null 2>&1; then
    termux-reload-settings
    print_ok "Reloaded Termux configuration via termux-reload-settings."
fi

# 5. Install CLI Executables
BIN_DEST=""
if is_termux && [[ -d "${PREFIX:-}/bin" && -w "${PREFIX:-}/bin" ]]; then
    BIN_DEST="${PREFIX}/bin"
else
    BIN_DEST="$HOME/.local/bin"
    mkdir -p "$BIN_DEST"
fi

print_info "Installing executable CLI tools to $BIN_DEST..."

for bin_file in "$SCRIPT_DIR/bin/"*; do
    if [[ -f "$bin_file" ]]; then
        bin_name="$(basename "$bin_file")"
        cp "$bin_file" "$BIN_DEST/$bin_name"
        chmod +x "$BIN_DEST/$bin_name"
        print_ok "Installed executable: $BIN_DEST/$bin_name"
    fi
done

# Ensure ~/.local/bin is on PATH if installed there
if [[ "$BIN_DEST" == "$HOME/.local/bin" ]]; then
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        print_warn "~/.local/bin is not currently in your PATH."
        print_info "Add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to your ~/.bashrc or ~/.zshrc."
    fi
fi

# 6. Initialize Config Directory
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/termux-agent-station"
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/config.env" ]]; then
    cat > "$CONFIG_DIR/config.env" <<'EOF'
# termux-agent-station runtime configuration
# Set your remote AI workstation parameters here

# HERDR_HOST="user@100.x.y.z"
# HERDR_SESSION="main"
# HERDR_SSH_PORT=22
# HERDR_IDENTITY="$HOME/.ssh/id_ed25519"
EOF
    print_ok "Initialized configuration template at $CONFIG_DIR/config.env"
fi

echo ""
print_ok "==> termux-agent-station installation completed! <=="
echo ""
echo -e "${BOLD}Next Steps:${NC}"
echo -e "  1. Generate & deploy your SSH key:  ${GREEN}setup-keys <user@remote-host>${NC}"
echo -e "  2. Connect to your AI workstation:  ${GREEN}herdr-remote <user@remote-host>${NC}"
echo -e "  3. Review Tailscale coexistence:    ${CYAN}cat guides/tailscale-flclash-coexist.md${NC}"
echo -e "  4. Setup Android background locks:  ${CYAN}cat guides/android-keepalive.md${NC}"
echo ""
