#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.config"
BACKUP_SUFFIX=".bak"
SDDM_DIR="/usr/share/sddm"
SCRIPT_ROOT="$(pwd)"

log() {
  printf "[+] %s\n" "$1"
}

warn() {
  printf "[!] %s\n" "$1"
}

backup_if_exists() {
  local target="$1"

  if [ -e "$target" ] || [ -L "$target" ]; then
    log "Backup $target → $target$BACKUP_SUFFIX"
    mv "$target" "$target$BACKUP_SUFFIX"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1"
    exit 1
  }
}

# ─────────────────────────────────────────────
# Проверки
# ─────────────────────────────────────────────

require_cmd git
require_cmd stow

log "Launch under $HOME"

mkdir -p "$CONFIG_DIR"

# ─────────────────────────────────────────────
# Backup ~/.config/*
# ─────────────────────────────────────────────

if [ -d "$SCRIPT_ROOT/.config" ]; then
  for dir in "$SCRIPT_ROOT/.config/"*; do
    name="$(basename "$dir")"
    backup_if_exists "$CONFIG_DIR/$name"
  done
fi

backup_if_exists "$HOME/.zshrc"
backup_if_exists "$HOME/.oh-my-zsh"

# ─────────────────────────────────────────────
# Powerlevel10k
# ─────────────────────────────────────────────

if [ ! -d "$HOME/powerlevel10k" ]; then
  log "Installing powerlevel10k"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k"
else
  warn "powerlevel10k already exists, skip"
fi

# ─────────────────────────────────────────────
# Oh-My-Zsh plugins
# ─────────────────────────────────────────────

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom/plugins"
mkdir -p "$ZSH_CUSTOM"

clone_plugin() {
  local repo="$1"
  local name="$2"

  if [ ! -d "$ZSH_CUSTOM/$name" ]; then
    log "Installing $name"
    git clone "$repo" "$ZSH_CUSTOM/$name"
  else
    warn "$name already installed, skip"
  fi
}

clone_plugin https://github.com/zsh-users/zsh-autosuggestions zsh-autosuggestions
clone_plugin https://github.com/zsh-users/zsh-syntax-highlighting zsh-syntax-highlighting

# ─────────────────────────────────────────────
# GNU Stow
# ─────────────────────────────────────────────

log "Running GNU Stow"
stow .

# ─────────────────────────────────────────────
# SDDM
# ─────────────────────────────────────────────

if [ -d "$SDDM_DIR" ]; then
  log "SDDM detected, installing SilentSDDM"

  sudo tee /etc/sddm.conf >/dev/null <<EOF
[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard

[Theme]
Current=silent
EOF

  if [ ! -d /usr/share/sddm/themes/silent ]; then
    sudo git clone https://github.com/uiriansan/SilentSDDM.git \
      /usr/share/sddm/themes/silent
  fi

  WALLPAPER="$HOME/.config/hypr/wallpaper/Robots_on_charge.png"
  if [ -f "$WALLPAPER" ]; then
    sudo cp "$WALLPAPER" \
      /usr/share/sddm/themes/silent/backgrounds/smoky.jpg
  else
    warn "Wallpaper not found, skipping copy"
  fi
else
  warn "SDDM not found, skipping"
fi

echo
log "Next step: enable sddm.service if needed"
read -r -p "Press Enter to finish..."

log "Installation complete 🎉"
