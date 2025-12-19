#!/bin/bash

# Check if the script is run with root privileges (EUID 0)
if [ "$EUID" -ne 0 ]; then
  # Re-run the script with sudo if possible, preserving arguments
  exec sudo bash "$0" "$@"
  exit 1 # In case exec fails
fi
echo
echo "-------Cloning git repo with fonts-----------"
echo

git clone https://github.com/githubnext/monaspace.git ./monaspace

cp -r ./monaspace/fonts /usr/share/fonts
mv /usr/share/fonts/fonts /usr/share/fonts/monaspace

rm -rf ./monaspace

echo
echo "Install Lazyfox Pixel Font"
echo

cp ./LazyFox/LazyFoxPixelFont1.ttf /usr/share/fonts

echo
echo "Install Nerd, Awesome, Meslo fonts"
echo

pacman -S woof2-font-awesome ttf-meslo-nerd noto-fonts-emoji ttf-dejavu
