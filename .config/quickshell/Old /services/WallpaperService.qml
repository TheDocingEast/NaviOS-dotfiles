pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string wallpaperDir: Quickshell.env("HOME") + "/.config/hypr/wallpaper"
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/wallpaper-selector"

    property var wallpapers: []
    property string currentWallpaper: ""
    property bool loading: false

    signal wallpaperSet(string name)

    // ── Генерация тумбнейлов (ImageMagick) ────────────────────────
    Process {
        id: thumbProc
        command: [
            "bash", "-c",
            `mkdir -p "${root.cacheDir}" && ` +
            `find "${root.wallpaperDir}" -maxdepth 1 -type f ` +
            `\\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \\) | ` +
            `while read f; do ` +
            `  name=$(basename "$f"); base="${root.cacheDir}/$\{name%.*}.png"; ` +
            `  [ ! -f "$base" ] && convert "$f" -thumbnail 400x400^ -gravity center -extent 400x400 "$base" 2>/dev/null || true; ` +
            `done`
        ]
        onRunningChanged: {
            if (!running)
                listProc.running = true
        }
    }

    // ── Список файлов ─────────────────────────────────────────────
    Process {
        id: listProc
        command: [
            "bash", "-c",
            `find "${root.wallpaperDir}" -maxdepth 1 -type f ` +
            `\\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \\) ` +
            `-printf "%f\\n" | sort`
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n").filter(l => l.length > 0)
                root.wallpapers = lines
                root.loading = false
            }
        }
    }

    // ── Установка обоев ───────────────────────────────────────────
    Process {
        id: setProc
        property string targetPath: ""
        onRunningChanged: {
            if (!running && exitCode === 0)
                root.currentWallpaper = targetPath
        }
    }

    Process {
        id: notifyProc
    }

    // ── Public API ────────────────────────────────────────────────
    function refresh() {
        root.loading = true
        root.wallpapers = []
        thumbProc.running = true
    }

    function setWallpaper(filename) {
        const fullPath = root.wallpaperDir + "/" + filename
        setProc.targetPath = fullPath
        setProc.command = [
            "bash", "-c",
            `if command -v swww &>/dev/null; then
                swww img "${fullPath}" --transition-type random --transition-step 10 --transition-fps 60
            elif command -v awww &>/dev/null; then
                awww img "${fullPath}" --transition-type random --transition-step 10 --transition-fps 60
            elif command -v hyprctl &>/dev/null; then
                hyprctl hyprpaper preload "${fullPath}" && hyprctl hyprpaper wallpaper ",${fullPath}"
            elif command -v swaybg &>/dev/null; then
                pkill swaybg; swaybg -i "${fullPath}" -m fill &
            fi
            echo "${fullPath}" > "${root.wallpaperDir}/.current_wallpaper"
            ln -sf "${fullPath}" "${root.wallpaperDir}/current"`
        ]
        setProc.running = true

        notifyProc.command = ["notify-send", "-t", "2000", "Wallpaper Changed", filename]
        notifyProc.running = true

        root.wallpaperSet(filename)
    }

    function thumbnailPath(filename) {
        return root.cacheDir + "/" + filename.replace(/\.[^.]+$/, "") + ".png"
    }

    Component.onCompleted: refresh()
}
