#!/usr/bin/env bash
#
# termux-agent-station — installer
#
# Deploys the Termux configuration (touch-first extra-keys matrix +
# TokyoNight dark theme) and prints the next steps to expose a
# sub-5ms, low-latency SSH workstation over Tailscale.
#
# Usage:
#   bin/setup.sh            Deploy configs into ~/.termux
#   bin/setup.sh --dry-run  Show what would happen, change nothing
#   bin/setup.sh --help     Show this help
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIGS_DIR="${REPO_DIR}/configs"
TERMUX_CONFIG_HOME_DIR="${TERMUX_CONFIG_HOME:-${HOME}/.termux}"

DRY_RUN=0

for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,13p' "$0"
      exit 0
      ;;
    *) echo "Unknown argument: ${arg}" >&2; exit 1 ;;
  esac
done

log() { printf '[termux-agent-station] %s\n' "$*"; }

is_termux() {
  [ -d "/data/data/com.termux" ] || [ -n "${TERMUX_VERSION:-}" ]
}

main() {
  if ! is_termux; then
    echo "This installer must run inside Termux on Android." >&2
    exit 1
  fi

  if [ ! -d "${CONFIGS_DIR}" ]; then
    echo "Config directory not found: ${CONFIGS_DIR}" >&2
    exit 1
  fi

  [ "${DRY_RUN}" -eq 1 ] && log "Dry run — no files will be modified."

  mkdir -p "${TERMUX_CONFIG_HOME_DIR}"

  for cfg in colors.properties termux.properties; do
    src="${CONFIGS_DIR}/${cfg}"
    dst="${TERMUX_CONFIG_HOME_DIR}/${cfg}"

    if [ ! -f "${src}" ]; then
      echo "Missing source config: ${src}" >&2
      exit 1
    fi

    if [ "${DRY_RUN}" -eq 1 ]; then
      log "Would deploy ${src} -> ${dst}"
      continue
    fi

    if [ -f "${dst}" ]; then
      cp -f "${dst}" "${dst}.bak.$(date +%s)"
      log "Backed up existing ${dst}"
    fi

    cp -f "${src}" "${dst}"
    log "Deployed ${cfg}"
  done

  if [ "${DRY_RUN}" -eq 0 ]; then
    if command -v termux-reload-settings >/dev/null 2>&1; then
      termux-reload-settings
      log "Reloaded Termux settings."
    fi
  fi

  cat <<'NEXT'

Next steps
----------
1. Install and start Tailscale (no root required):
     pkg install tailscale
     tailscale up

2. Install OpenSSH, set a password, and start the server:
     pkg install openssh
     passwd
     sshd
   The SSH server listens on port 8022 by default.

3. From your laptop / agent host, connect over the Tailscale IP:
     ssh -p 8022 <your-user>@<your-tailscale-ip>

4. For persistent sessions, wrap your agent in tmux or herdr-remote.

See README.md for the full architecture and tuning guide.
NEXT
}

main "$@"
