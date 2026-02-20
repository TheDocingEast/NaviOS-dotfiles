#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# Utils
# ─────────────────────────────────────────────

log() { printf "\e[0;32m[+] %s\e[0m\n" "$1"; }
warn() { printf "\e[0;31m[!] %s\e[0m\n" "$1"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    warn "Missing dependency: $1"
    exit 1
  }
}

# ─────────────────────────────────────────────
# Preconditions
# ─────────────────────────────────────────────

require_cmd git
require_cmd sudo

log "Running as user: $(whoami)"
log "HOME=$HOME"

ZAPRET_DIR="$HOME/zapret"

# ─────────────────────────────────────────────
# Clone repo (USER)
# ─────────────────────────────────────────────

if [ ! -d "$ZAPRET_DIR" ]; then
  log "Cloning zapret repo"
  git clone https://github.com/Sergeydigl3/zapret-discord-youtube-linux.git \
    "$ZAPRET_DIR"
else
  warn "Zapret repo already exists, skip clone"
fi

# ─────────────────────────────────────────────
# Config (USER)
# ─────────────────────────────────────────────

log "Writing conf.env"
warn "(RECOMMENDED STRATEGY ALT10 ON 10.02.2026 WILL BE WRITTEN)"

cat >"$ZAPRET_DIR/conf.env" <<EOF
strategy=general_alt10.bat
interface=any
gamefilter=true
EOF

# ─────────────────────────────────────────────
# Install (ROOT, but controlled)
# ─────────────────────────────────────────────

log "Installing zapret (root phase)"

# ВАЖНО:
# 1. не даём main_script.sh убить наш shell
# 2. явно передаём HOME пользователя
# 3. не используем exec

timeout 10s sudo env USER_HOME="$HOME" HOME="$HOME" bash "$ZAPRET_DIR/main_script.sh" -nointeractive || true

# ─────────────────────────────────────────────
# Service control (USER → sudo)
# ─────────────────────────────────────────────

log "Installing zapret service"
bash $ZAPRET_DIR/service.sh -i

log "Starting zapret service"
bash $ZAPRET_DIR/service.sh -s

# ─────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────

log "Zapret installation complete 🎉"
