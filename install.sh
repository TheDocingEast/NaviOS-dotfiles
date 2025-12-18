#!/bin/bash

CONFIG_DIR=".config"
BACKUP_SUFFIX=".bak"

mapfile -t CONFIG_FILES < <(ls "$CONFIG_DIR")

mkdir -p "$HOME/.config"

for config in "${CONFIG_FILES[@]}"; do
  DEST_PATH="$HOME/$CONFIG_DIR/$config"

  if [ -e "$DEST_PATH" ] || [ -L "$DEST_PATH" ]; then
    echo "Backing up existing $DEST_PATH to $DEST_PATH$BACKUP_SUFFIX"
    mv "$DEST_PATH" "$DEST_PATH$BACKUP_SUFFIX"
  fi
done

ZSHRC_DEST="$HOME/.zshrc"

if [ -e "$ZSHRC_DEST" ] || [ -L "$ZSHRC_DEST" ]; then
  echo "Backing up existing $ZSHRC_DEST to $ZSHRC_DEST$BACKUP_SUFFIX"
  mv "$ZSHRC_DEST" "$ZSHRC_DEST$BACKUP_SUFFIX"
fi

echo "Start GNU Stow"
stow .

echo "Installation complete! 🎉"
