#!/usr/bin/env bash
# -----------------------------------------------------------------------------
#  YeetPatch - Linux flavored this time (i used arch at some point in my life)
# -----------------------------------------------------------------------------
#  Modes:
#    - update: patch existing install to latest
#    - install: interactive install of any version
#  Given a path to VotV.exe (either via arg or via using that little comment i added in):
#    - Verifies prerequisites like 7z, jq (json parser tool doodad) and sha256sum (used for checking file hashes)
#    - Checks the game's main data .pak file SHA-256 hash
#    - Grabs the patch_manifest.json from votv.dev which contains a hashmap to detect version based on the .pak hash and patches that match that version
#    - Shows you a little summary with what version you have, which one is available, and asks (politely) if you want to update
#    - Downloads the patch, hashes it for verification, extracts next to the WindowsNoEditor folder
#    - Runs the apply_patch.sh script (which just calls hpatchz), cleans up extracted files after it's done
#  set -Eeuo pipefail is there to abandon ship immediately if something goes wrong (hopefully nothing does)
# -----------------------------------------------------------------------------

set -Eeuo pipefail

die() {
  echo "ERROR: $*" >&2
  exit 1
}
warn() { echo "[WARN] $*" >&2; }
info() { echo "-> $*"; }
to_tty_stderr() {
  if [[ -w /dev/tty ]]; then
    "$@" 2>/dev/tty
  else
    "$@"
  fi
}

# need bash >=4 for associative arrays
((BASH_VERSINFO[0] >= 4)) || die "Bash >= 4 is required (found ${BASH_VERSION})."

# script directory (for ./desync)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ----------------------------------------- config ----------------------------
# --- NOTICE
NOTICE_URL="${NOTICE_URL-https://votv.dev/patcher_assets/notice_linux}"                 # optional: startup notice text
NOTICE_STATE_DIR="${NOTICE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/yeetpatch}" # where "note seen" flags are stored
NOTICE_ONCE="${NOTICE_ONCE:-1}"                                                         # 1=show once per unique notice, 0=always show

# --- PATCH
MANIFEST_URL="https://votv.dev/patcher_assets/patch_manifest.json" # official patch manifest json
EXE_PATH=""                                                        # optional: default path to VotV.exe

# --- INSTALL
INSTALL_DIR="/home/thedocingeast/game"                                    # game install path (folder)
CACHE_DIR=""                                                              # optional: data cache folder
STORE_URL="https://votv.dev/patcher_assets/256-1024-4096-store"           # datastore url
SAVEGAME_DIR="/home/thedocingeast/.votv"                                  # optional: path to saves to back up; leave empty to skip
INSTALL_CATALOG_URL="https://votv.dev/patcher_assets/index_manifest.json" # optional: override via --catalog; expects array of {name,hash,link}
BACKUPS_DIR="$SCRIPT_DIR/backups"                                         # optional: save backups directory (if SAVEGAME_DIR is set)

# desync (binary must sit next to this script)
DESYNC_BIN="$SCRIPT_DIR/desync"
DESYNC_URL="${DESYNC_URL:-https://github.com/folbricht/desync/releases/download/v0.9.6/desync_0.9.6_linux_amd64.tar.gz}"

# -----------------------------------------------------------------------------

need_cmds_patch=(curl jq sha256sum 7z)
need_cmds_install=(curl jq tar)
missing_cmds=()

check_cmds() {
  local -n arr=$1
  local miss=()
  for cmd in "${arr[@]}"; do command -v "$cmd" >/dev/null 2>&1 || miss+=("$cmd"); done
  if ((${#miss[@]})); then
    declare -A apt_pkg=([curl]=curl [jq]=jq [sha256sum]=coreutils [7z]=p7zip-full [tar]=tar)
    echo "ERROR: Missing required tool(s): ${miss[*]}" >&2
    echo -e "       On Debian/Ubuntu install with:\n         sudo apt install$(for c in "${miss[@]}"; do printf ' %s' "${apt_pkg[$c]:-$c}"; done)"
    exit 99
  fi
}

_notice_hash() {
  # hashe
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  elif command -v cksum >/dev/null 2>&1; then
    printf '%s' "$1" | cksum | awk '{print $1"-"$2}'
  else
    # fallback w/ hex
    local len=${#1}
    printf '%s' "$len-$(printf "%s" "$1" | head -c 16 | od -An -tx1 | tr -d " \n")-$(printf "%s" "$1" | tail -c 16 | od -An -tx1 | tr -d " \n")"
  fi
}
_notice_seen_path() {
  local sig="$1"
  local dir="${NOTICE_STATE_DIR:-$SCRIPT_DIR/.state}"
  printf '%s/notice-%s.seen' "$dir" "$sig"
}

show_notice() {
  command -v curl >/dev/null 2>&1 || return 0
  [[ -n ${NOTICE_URL-} ]] || return 0

  local msg
  msg=$(curl -fsSL --connect-timeout 5 --max-time 5 "$NOTICE_URL" 2>/dev/null || true)
  msg=${msg//$'\r'/}
  [[ -n ${msg//[[:space:]]/} ]] || return 0

  local sig seen_file
  sig=$(_notice_hash "$msg")
  seen_file=$(_notice_seen_path "$sig")

  if [[ "$NOTICE_ONCE" == "1" && -z "${NOTICE_FORCE-}" && -f "$seen_file" ]]; then
    return 0
  fi

  notice_popup "YeetPatch Notice" "$msg"

  if [[ "$NOTICE_ONCE" == "1" ]]; then
    mkdir -p "$(dirname "$seen_file")" 2>/dev/null || true
    : >"$seen_file"
  fi
}

# popup ui
notice_popup() {
  local title="${1:-YeetPatch Notice}"
  local text="$2"

  # print regularly without tty
  exec 3<>/dev/tty 2>/dev/null || {
    printf '%s\n\n' "$text"
    return 0
  }

  local oldstty
  oldstty=$(stty -g <&3 || true)
  printf '\e[?1049h\e[2J\e[H\e[?25l' >&3
  stty -echo -icanon time 0 min 1 <&3 2>/dev/null || true

  local rows cols
  read -r rows cols < <(stty size <&3 2>/dev/null || echo "24 80")
  local width=$((cols - 4))
  ((width < 20)) && width=20
  local page=$((rows - 6))
  ((page < 5)) && page=5

  # wrappy if possible
  local wrapped
  if command -v fold >/dev/null 2>&1; then
    wrapped=$(printf '%s\n' "$text" | fold -s -w "$width")
  else
    wrapped="$text"
  fi

  mapfile -t lines <<<"$wrapped"
  local n=${#lines[@]}
  ((n == 0)) && lines=(" ") && n=1
  local offset=0

  _render() {
    printf '\e[H\e[2J' >&3
    printf '%s\n\n' "$title" >&3
    local i end=$((offset + page - 1))
    ((end >= n - 1)) && end=$((n - 1))
    for ((i = offset; i <= end; i++)); do
      printf '  %s\n' "${lines[$i]}" >&3
    done
    for (( ; i < offset + page; i++)); do printf '\n' >&3; done
    printf '\nPress Space or q to continue.\n' >&3
  }

  _render
  while :; do
    local k
    IFS= read -rsn1 -u 3 k || k=""
    case "$k" in
    $'\n' | ' ' | q | Q) break ;; # space/q = continue
    $'\e')                        # handle scroll keys silently
      local k1 k2
      IFS= read -rsn1 -t 0.02 -u 3 k1 || k1=""
      if [[ $k1 == "[" ]]; then
        IFS= read -rsn1 -t 0.02 -u 3 k2 || k2=""
        case "$k2" in
        A) ((offset > 0)) && ((offset--)) ;;        # up
        B) ((offset < n - page)) && ((offset++)) ;; # down
        5)
          IFS= read -rsn1 -t 0.02 -u 3 _ || true # pgup
          ((offset -= page))
          ((offset < 0)) && offset=0
          ;;
        6)
          IFS= read -rsn1 -t 0.02 -u 3 _ || true # pgdn
          ((offset += page))
          ((offset > n - page)) && offset=$((n > page ? n - page : 0))
          ;;
        H) offset=0 ;;                            # home
        F) offset=$((n > page ? n - page : 0)) ;; # end
        esac
      elif [[ $k1 == "O" ]]; then
        IFS= read -rsn1 -t 0.02 -u 3 k2 || k2=""
        case "$k2" in
        M) break ;; # enter (keypad)
        H) offset=0 ;;
        F) offset=$((n > page ? n - page : 0)) ;;
        esac
      fi
      ;;
    esac
    _render
  done

  stty "$oldstty" <&3 2>/dev/null || true
  printf '\e[?25h\e[?1049l' >&3
  exec 3>&- 2>/dev/null || true
}

menu() {
  local title=$1
  shift
  local opts=("$@")
  local n=${#opts[@]}
  ((n > 0)) || {
    echo "ERROR: no options to select." >&2
    return 99
  }

  exec 3<>/dev/tty || {
    echo "ERROR: TTY not available." >&2
    return 98
  }

  local oldstty
  oldstty=$(stty -g <&3 || true)
  printf '\e[?1049h\e[2J\e[H\e[?25l' >&3
  stty -echo -icanon time 0 min 1 <&3 2>/dev/null || true

  local rows cols
  read -r rows cols < <(stty size <&3 2>/dev/null || echo "24 80")
  local page=$((rows - 6))
  ((page < 5)) && page=5

  local selected=0 offset=0 ret=-1 cancel=0

  _render() {
    printf '\e[H\e[2J' >&3
    printf '%s\n' "$title" >&3
    printf 'Use ↑/↓ PgUp/PgDn Home/End, Enter=select, q=quit\n\n' >&3
    local i end=$((offset + page - 1))
    ((end >= n - 1)) && end=$((n - 1))
    for ((i = offset; i <= end; i++)); do
      if ((i == selected)); then
        printf '> \e[7m%s\e[0m\n' "${opts[$i]}" >&3
      else
        printf '  %s\n' "${opts[$i]}" >&3
      fi
    done
    for (( ; i < offset + page; i++)); do printf '\n' >&3; done
  }

  _up() {
    ((selected > 0)) && ((selected--))
    ((selected < offset)) && offset=$selected
  }
  _down() {
    ((selected < n - 1)) && ((selected++))
    ((selected >= offset + page)) && offset=$((selected - page + 1))
  }
  _pgup() {
    selected=$((selected - page))
    ((selected < 0)) && selected=0
    offset=$selected
  }
  _pgdn() {
    selected=$((selected + page))
    ((selected > n - 1)) && selected=$((n - 1))
    offset=$((selected - page + 1))
    ((offset < 0)) && offset=0
  }
  _home() {
    selected=0
    offset=0
  }
  _end() {
    selected=$((n - 1))
    offset=$((n - page))
    ((offset < 0)) && offset=0
  }

  _render
  while :; do
    local k
    IFS= read -rsn1 -u 3 k || k=""
    if [[ -z $k ]]; then
      ret=$selected
      break
    fi

    case "$k" in
    $'\r' | $'\n')
      ret=$selected
      break
      ;;
    ' ')
      ret=$selected
      break
      ;;
    q | Q)
      cancel=1
      break
      ;;
    $'\e')
      local k1 k2
      IFS= read -rsn1 -t 0.02 -u 3 k1 || k1=""
      if [[ $k1 == "[" ]]; then
        IFS= read -rsn1 -t 0.02 -u 3 k2 || k2=""
        case "$k2" in
        A) _up ;;
        B) _down ;;
        H) _home ;;
        F) _end ;;
        5)
          IFS= read -rsn1 -t 0.02 -u 3 _ || true
          _pgup
          ;;
        6)
          IFS= read -rsn1 -t 0.02 -u 3 _ || true
          _pgdn
          ;;
        esac
      elif [[ $k1 == "O" ]]; then
        IFS= read -rsn1 -t 0.02 -u 3 k2 || k2=""
        case "$k2" in
        M)
          ret=$selected
          break
          ;;
        H) _home ;;
        F) _end ;;
        esac
      fi
      ;;
    esac
    _render
  done

  stty "$oldstty" <&3 2>/dev/null || true
  printf '\e[?25h\e[?1049l' >&3
  exec 3>&- 2>/dev/null || true

  ((cancel)) && return 130
  echo "$ret"
  return 0
}

prompt_yn_tty() {
  local prompt="${1:-Proceed?} [y/N] "
  local ans
  if [[ -r /dev/tty && -w /dev/tty ]]; then
    while :; do
      printf '%s' "$prompt" >/dev/tty
      IFS= read -r ans </dev/tty || return 1
      case "${ans,,}" in y | yes) return 0 ;; n | no | '') return 1 ;; esac
    done
  else
    read -r -p "$prompt" ans || return 1
    case "${ans,,}" in y | yes) return 0 ;; *) return 1 ;; esac
  fi
}

normalize_catalog() {
  # normalize_catalog <in.json> <out.json>
  local in="$1" out="$2"
  jq -r '
    if type=="array" then
      [ .[]
        | select(.name and .hash and .link)
        | { name: .name, hash: .hash, link: .link }
      ]
    else [] end
  ' "$in" >"$out"
}

# backup saves
backup_saves() {
  local src=$1 dst_dir=$2
  [[ -z $src ]] && return 0
  [[ -d $src ]] || {
    warn "SAVEGAME_DIR '$src' not found; skipping backup."
    return 0
  }
  mkdir -p "$dst_dir"
  local ts
  ts=$(date +'%Y%m%d_%H%M%S')
  local out="$dst_dir/save_backup_${ts}.tar.gz"
  info "Backing up saves: $src -> $out"
  tar -czf "$out" -C "$(dirname "$src")" "$(basename "$src")"
  echo "   Backup created: $out"
}

# ensure local desync binary exists (download+unpack if missing)
ensure_desync() {
  if [[ -x "$DESYNC_BIN" ]]; then
    info "Using desync: $DESYNC_BIN"
    return 0
  fi
  info "desync not found next to script. Downloading…"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN
  local tgz="$tmpdir/desync.tgz"
  curl -L -# -o "$tgz" "$DESYNC_URL" || die "Failed to download desync from $DESYNC_URL"
  tar -xzf "$tgz" -C "$tmpdir" || die "Failed to extract desync archive"
  local src
  src=$(find "$tmpdir" -maxdepth 2 -type f -name desync | head -n1) || true
  [[ -n $src ]] || die "Archive did not contain a 'desync' binary"
  mv -f "$src" "$DESYNC_BIN"
  chmod +x "$DESYNC_BIN"
  trap - RETURN
  rm -rf "$tmpdir"
  info "desync installed to $DESYNC_BIN"
}

# ----------------------------- UPDATE FLOW ------------------------
update_flow() {
  check_cmds need_cmds_patch

  local path="${1:-$EXE_PATH}"
  if [[ -z $path ]]; then
    echo "USAGE: $0 update /full/path/to/VotV.exe  (or set EXE_PATH in the script)" >&2
    exit 1
  fi
  [[ $(basename "$path") == "VotV.exe" ]] || die "1st arg must be VotV.exe"
  [[ -f $path ]] || die "File not found: $path"
  EXE_PATH="$path"

  GAME_DIR=$(dirname "$EXE_PATH") # inside WindowsNoEditor
  PAK="$GAME_DIR/VotV/Content/Paks/VotV-WindowsNoEditor.pak"
  [[ -f $PAK ]] || {
    echo "[ERROR] Pak file not found: $PAK" >&2
    exit 2
  }

  TMP_MANIFEST=$(mktemp)
  PATCH_TMP=$(mktemp -d)
  cleanup() {
    [[ -f $TMP_MANIFEST ]] && rm -f "$TMP_MANIFEST"
    [[ -d $PATCH_TMP ]] && rm -rf "$PATCH_TMP"
  }
  trap cleanup EXIT ERR INT TERM

  info "Hashing $PAK"
  PAK_SHA=$(sha256sum "$PAK" | awk '{print toupper($1)}')
  printf '   SHA256: %s\n\n' "$PAK_SHA"

  curl -fsSL --retry 5 --retry-delay 2 --retry-connrefused "$MANIFEST_URL" -o "$TMP_MANIFEST"
  CUR_VER=$(jq -r --arg h "$PAK_SHA" '.fileHashMap[$h] // empty' "$TMP_MANIFEST")
  [[ -n $CUR_VER ]] || {
    echo "[ERROR] Hash not recognised in manifest" >&2
    exit 3
  }
  LATEST=$(jq -r '.latest' "$TMP_MANIFEST")
  [[ $CUR_VER == "$LATEST" ]] && {
    echo "Already at latest ($LATEST)."
    exit 0
  }

  PATCH_URL=$(jq -r --arg v "$CUR_VER" '.patches[$v].url // empty' "$TMP_MANIFEST")
  PATCH_SHA=$(jq -r --arg v "$CUR_VER" '.patches[$v].sha256 // empty' "$TMP_MANIFEST")
  [[ $PATCH_URL ]] || {
    echo "[ERROR] No patch available for $CUR_VER" >&2
    exit 4
  }

  cat <<INFO
--- PATCH INFO ----------------------------------------------------
Current build  : $CUR_VER
Upgrade target : $LATEST

Download URL   : $PATCH_URL
File SHA-256   : $PATCH_SHA
-------------------------------------------------------------------
INFO
  local sel
  sel=$(menu "Update $CUR_VER >>> $LATEST?" "Yes" "No") || exit $?
  if ((sel != 0)); then
    echo "Aborted."
    exit 0
  fi

  PATCH_FILE="$PATCH_TMP/patch.7z"
  info "Downloading patch…"
  to_tty_stderr curl -L --progress-bar -o "$PATCH_FILE" "$PATCH_URL"

  echo "$PATCH_SHA  $PATCH_FILE" | sha256sum -c - --status || {
    echo "[ERROR] SHA-256 mismatch!" >&2
    exit 5
  }
  echo "Patch verified."

  mapfile -t EXTRACTED < <(7z l -slt "$PATCH_FILE" | awk -F' = ' '/^Path = /{print $2}')
  TARGET_PARENT=$(dirname "$GAME_DIR")

  info "Extracting to $TARGET_PARENT"
  7z x -y "$PATCH_FILE" "-o$TARGET_PARENT" >/dev/null

  PATCH_SCRIPT=$(find "$TARGET_PARENT" -maxdepth 2 -type f -name apply_patch.sh | head -n1) || true
  [[ -n $PATCH_SCRIPT ]] || {
    echo "[ERROR] apply_patch.sh not found after extraction" >&2
    exit 6
  }
  PATCH_DIR_PATH=$(dirname "$PATCH_SCRIPT")

  info "Running patch script from: $PATCH_DIR_PATH"
  (cd "$PATCH_DIR_PATH" && chmod +x apply_patch.sh hpatchz && bash ./apply_patch.sh)
  local rc=$?

  if ((rc == 0)); then
    info "Cleaning up extracted patch files…"
    for p in "${EXTRACTED[@]}"; do rm -rf -- "$TARGET_PARENT/$p"; done
    echo "Update complete."
  else
    echo "[WARN] apply_patch.sh exited with code $rc; extracted files left in place." >&2
    exit "$rc"
  fi
}

# ----------------------------- INSTALL FLOW ----------------------------
install_flow() {
  check_cmds need_cmds_install
  ensure_desync

  # parse options: -c CACHE_DIR, --no-backup, --catalog URL
  local CACHE_OPT="" DO_BACKUP=1
  while (($#)); do
    case "$1" in
    -c)
      CACHE_OPT="${2:-}"
      [[ -n $CACHE_OPT ]] || die "-c requires a path"
      shift 2
      ;;
    --no-backup)
      DO_BACKUP=0
      shift
      ;;
    --catalog)
      INSTALL_CATALOG_URL="${2:-}"
      [[ -n $INSTALL_CATALOG_URL ]] || die "--catalog requires a URL"
      shift 2
      ;;
    *) die "Unknown option for install: $1" ;;
    esac
  done

  [[ -n $INSTALL_DIR ]] || die "Set INSTALL_DIR at top of script."
  [[ -n $STORE_URL ]] || die "Set STORE_URL at top of script."

  local CACHE_EFF="${CACHE_OPT:-${CACHE_DIR-}}"
  [[ -n ${CACHE_EFF-} ]] && mkdir -p -- "$CACHE_EFF"

  mkdir -p "$INSTALL_DIR"

  local raw tmpnorm
  raw=$(mktemp)
  tmpnorm=$(mktemp)
  trap 'rm -f "$raw" "$tmpnorm"' RETURN

  info "Catalog URL: ${INSTALL_CATALOG_URL:-<unset>}"
  [[ -z $INSTALL_CATALOG_URL ]] && INSTALL_CATALOG_URL="https://votv.dev/patcher_assets/index_manifest.json"

  info "Fetching catalog…"
  curl -fsSL -L --fail --connect-timeout 5 --max-time 90 "$INSTALL_CATALOG_URL" -o "$raw" ||
    die "Failed to fetch catalog"

  normalize_catalog "$raw" "$tmpnorm"

  local count
  count=$(jq 'length' "$tmpnorm" 2>/dev/null || echo 0)
  info "Catalog entries: $count"
  ((count > 0)) || die "Catalog empty or bad format (expected array of {name,hash,link})."

  # build names from normalized array
  mapfile -t labels < <(jq -r '.[] | "\(.name)  [\(.hash[0:8])…]"' "$tmpnorm")

  # select
  local idx
  idx=$(menu "Select a build to install:" "${labels[@]}") || exit $?
  local name hash link
  name=$(jq -r ".[$idx].name" "$tmpnorm")
  hash=$(jq -r ".[$idx].hash" "$tmpnorm")
  link=$(jq -r ".[$idx].link" "$tmpnorm")
  [[ -n $link && $link != "null" ]] || die "Selected entry missing a usable link."

  echo
  cat <<EOF
--- INSTALL SELECTION ------------------------------------------------
Name     : $name
Hash     : $hash
Index URL: $link
Install  : $INSTALL_DIR
Store    : $STORE_URL
Cache    : ${CACHE_DIR:-<none>}
desync   : $DESYNC_BIN
----------------------------------------------------------------------
EOF
  if ! prompt_yn_tty "Proceed with install?"; then
    echo "Aborted."
    exit 0
  fi

  ((DO_BACKUP)) && backup_saves "$SAVEGAME_DIR" "$BACKUPS_DIR"

  # download .caidx
  local workdir caidx
  workdir="$(mktemp -d)"
  trap 'd=${workdir-}; [[ -n $d ]] && rm -rf -- "$d"' RETURN
  caidx="$workdir/index.caidx"
  info "Downloading index (.caidx)…"
  to_tty_stderr curl -L --progress-bar --fail -o "$caidx" "$link" || die "Failed to download index"

  # desync args
  local args=(untar --no-same-owner -i -s "$STORE_URL")
  [[ -n ${CACHE_EFF-} ]] && args+=(-c "$CACHE_EFF")
  args+=("$caidx" "$INSTALL_DIR" -n 16)

  echo
  info "Running: $DESYNC_BIN ${args[*]}"
  to_tty_stderr "$DESYNC_BIN" "${args[@]}"

  echo
  echo "Install complete: $INSTALL_DIR"
}

# ----------------------------------- main ------------------------------------
main() {
  show_notice
  case "${1:-}" in
  update)
    shift
    update_flow "$@"
    ;;
  install)
    shift
    install_flow "$@"
    ;;
  "" | -h | --help | help)
    cat <<USAGE
Usage:
  # Patch existing install
  $0 update /full/path/to/VotV.exe

  # Fresh Install / Version Change
  $0 install [-c CACHE_DIR] [--no-backup] [--catalog URL]

Config (edit at top of script):
  NOTICE_URL            Startup notice text file URL (leave empty to disable)
  INSTALL_DIR           Destination folder for install
  CACHE_DIR             Default cache directory for desync (overridden by -c)
  STORE_URL             desync store URL (required for install)
  SAVEGAME_DIR          Optional source folder to back up (tar.gz)
  INSTALL_CATALOG_URL   Catalog JSON URL (can override with --catalog)
  DESYNC_URL            Where to fetch desync if missing (local ./desync used)

Notes:
  - Arrow keys navigate; Enter selects.
  - curl shows progress bars; desync output is shown verbatim.
  - desync binary is placed next to this script if not present.
USAGE
    ;;
  *)
    echo "Unknown command: $1" >&2
    exit 1
    ;;
  esac
}
main "$@"
