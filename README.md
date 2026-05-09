<div align="center">

<br>

[![Typing SVG](https://readme-typing-svg.demolab.com?font=Monaspace+Krypton&weight=600&size=60&duration=2000&pause=100&color=8FBCBB&center=true&vCenter=true&multiline=true&repeat=false&random=true&width=500&height=150&lines=NAVIOS)](https://git.io/typing-svg)

[![Typing SVG](https://readme-typing-svg.demolab.com?font=Monaspace+Krypton&weight=600&size=45&duration=2000&pause=100&color=8FBCBB&center=true&vCenter=true&multiline=true&repeat=false&random=true&width=1000&height=150&lines=Nord-palette+dotfiles+for+Arch)](https://git.io/typing-svg)

**A.U.R.I. — Autonomous User Resource Interface**

*my personal Arch Linux desktop environment, built from scratch*

<br>

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=arch-linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?style=flat-square&logo=hyprland&logoColor=black)
![QML](https://img.shields.io/badge/Quickshell-41CD52?style=flat-square&logo=qt&logoColor=white)
![Wayland](https://img.shields.io/badge/Wayland-FFBC00?style=flat-square&logo=wayland&logoColor=black)

<br>

</div>
---
 
## ✦ Screenshots
 
> *coming soon...*
 
---
 
## ✦ Overview
 
NaviOS is not just a rice — it's a fully custom shell environment built on top of Arch Linux and Hyprland, shaped around the **NaviStar / A.U.R.I.** visual identity. Every component, from the lockscreen to the wallpaper selector, is hand-crafted with QML via [Quickshell](https://quickshell.outfoxxed.me/).
 
The aesthetic draws from sci-fi UI design, deep-space color language, and the kind of minimalism that still has something to say.
 
---
 
## ✦ Stack
 
| Component       | Program                                             |
|-----------------|-----------------------------------------------------|
| **OS**          | [Arch Linux](https://archlinux.org/)               |
| **WM**          | [Hyprland](https://hyprland.org/)                  |
| **Shell (UI)**  | [Quickshell](https://quickshell.outfoxxed.me/) (QML) |
| **Terminal**    | [Ghostty](https://ghostty.org/)                    |
| **Shell**       | Zsh + Oh My Zsh + Powerlevel10k                     |
| **Editor**      | [Zed](https://zed.dev/)                             |
| **Browser**     | Firefox                                             |
| **Lockscreen**  | Custom QML (replaces hyprlock)                     |
| **Wallpaper**   | [hyprquickpaper](https://github.com/...) via `awww` (GIF support) |
| **Compositor**  | Hyprland (built-in)                                 |
| **Audio**       | PipeWire + custom VoicerWindow TTS/voice changer   |
| **Fetch**       | fastfetch                                           |
| **GTK Theme**   | *custom*                                            |
 
---
 
## ✦ Features
 
- **Custom QML shell** — bars, widgets, popups, notification center, all written in QML using Quickshell  
- **Wayland-native lockscreen** — replaces hyprlock, animated, fully integrated with the rest of the shell  
- **hyprquickpaper** — wallpaper switcher with GIF support built on top of `awww`  
- **VoicerWindow** — TTS + PipeWire virtual sink voice changer UI  
- **Stow-based dotfile management** — clean symlink deployment with `install.sh`  
- **Powerlevel10k** — tuned prompt with custom p10k config  
---
 
## ✦ Installation
 
> **⚠ These dots are tailored for my specific machine and setup.**
> You will almost certainly need to tweak paths, monitor configs, and package names. PRs and issues are welcome.
 
```bash
# Clone the repo
git clone https://github.com/TheDocingEast/NaviOS-dotfiles.git ~/NaviOS-dotfiles
cd ~/NaviOS-dotfiles
 
# Run the install script (deploys via GNU stow)
./install.sh
```
 
Make sure you have the following installed before running:
 
- `hyprland`, `quickshell`, `ghostty`, `zsh`, `stow`
- `awww` (for wallpaper)
- `pipewire`, `wireplumber` (for audio)
- `fastfetch`, `oh-my-zsh`, `zed`
---
 
## ✦ Structure
 
```
NaviOS-dotfiles/
├── .config/          # XDG config (hyprland, quickshell, ghostty, zed, ...)
├── .oh-my-zsh/       # Oh My Zsh customizations
├── bin/              # Custom scripts and utilities
├── navios/           # NaviOS-specific resources (themes, assets)
├── .p10k.zsh         # Powerlevel10k prompt config
├── .zshrc            # Zsh config
└── install.sh        # Stow-based deployment script
```
 
---
 
## ✦ Inspiration & Credits
 
- [Quickshell docs](https://quickshell.outfoxxed.me/)
- [Hyprland wiki](https://wiki.hyprland.org/)
- [r/unixporn](https://reddit.com/r/unixporn)
- [Barbaross93/Nebula](https://github.com/Barbaross93/Nebula) and countless other dotfile authors who inspired this journey
---
 
<div align="center">
<br>
*crafted with obsession by* [**TheDocingEast**](https://github.com/TheDocingEast) · [thedocingeast.space](https://www.thedocingeast.space)
 
<br>
</div>
