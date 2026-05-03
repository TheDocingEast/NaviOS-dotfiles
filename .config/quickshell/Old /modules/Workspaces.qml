import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// ── Workspaces widget ─────────────────────────────────────────────────────────
// Auto-detects running WM: Hyprland or i3
// Usage: Workspaces { fontFamily: ...; fontSize: ...; colActive: ...; ... }
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: workspacesRoot

    // ── Theming props (pass from parent) ──────────────────────────────────────
    property string fontFamily: "Monaspace Krypton Medium"
    property int fontSize: 16
    property color colActive: "#81a1c1"
    property color colOccupied: "#d8dee9"
    property color colEmpty: "#4c566a"
    property color colBar: "#5e81ac"
    property color colBg: "#2e3440"

    implicitWidth: 250
    implicitHeight: 50

    Layout.fillHeight: true
    Layout.fillWidth: false
    Layout.preferredWidth: 250
    Layout.alignment: Qt.AlignVCenter

    // ── wsId → windowClass map, обновляется через hyprctl ────────────────────
    property var wsClassMap: ({})

    Process {
        id: clientsProc
        command: ["sh", "-c", "hyprctl clients -j | jq -r '.[] | \"\\(.workspace.id) \\(.class)\"'"]
        running: true

        stdout: SplitParser {
            onRead: (data) => {
                if (!data || !data.trim()) return;
                const parts = data.trim().split(" ");
                if (parts.length >= 2) {
                    const map = workspacesRoot.wsClassMap;
                    // Только первое окно на workspace
                    if (!map[parts[0]]) {
                        map[parts[0]] = parts.slice(1).join(" ").toLowerCase();
                        workspacesRoot.wsClassMap = Object.assign({}, map);
                    }
                }
            }
        }
    }

    // Перезапускаем при смене активного окна
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            workspacesRoot.wsClassMap = {};
            clientsProc.running = false;
            clientsProc.running = true;
        }
    }

    // ── App icon mapping (windowClass → Nerd Font icon) ───────────────────────
    readonly property var appIcons: ({
        "steam":            "󰓓",
        "telegram":         "",
        "discord":          "",
        "vesktop":          "󰙯",
        "firefox":          "󰈹",
        "chromium":         "",
        "google-chrome":    "",
        "brave":            "󰖟",
        "code":             "󰨞",
        "jetbrains":        "",
        "pycharm":          "",
        "idea":             "",
        "clion":            "",
        "tty":              "",
        "alacritty":        "",
        "foot":             "",
        "wezterm":          "",
        "konsole":          "",
        "thunar":           "󰉋",
        "nautilus":         "󰉋",
        "nemo":             "󰉋",
        "dolphin":          "󰉋",
        "spotify":          "󰓇",
        "mpv":              "",
        "vlc":              "󰕼",
        "obs":              "󰐌",
        "gimp":             "",
        "inkscape":         "",
        "blender":          "󰂫",
        "krita":            "",
        "figma":            "",
        "slack":            "󰒱",
        "zoom":             "󰍫",
        "thunderbird":      "󰇮",
        "libreoffice":      "󰈙",
        "soffice":          "󰈙",
        "postman":          "󰛮",
        "insomnia":         "󰛮",
        "docker":           "󰡨",
        "virtualbox":       "󰡨",
        "lutris":           "󰺵",
        "heroic":           "󰺵",
        "minecraft":        "󰍳",
        "github":           "󰊤",
        "obsidian":         "󱓩",
        "torrent":          "󰇚",
        "prusa":            "",
        "orca":             "",
    })

    // ── Resolve icon by wsId ──────────────────────────────────────────────────
    function getWorkspaceIcon(wsId) {
        const cls = wsClassMap[wsId.toString()];
        if (!cls) return "";
        if (appIcons[cls]) return appIcons[cls];
        for (const key in appIcons) {
            if (cls.includes(key)) return appIcons[key];
        }
        return "";
    }

    // ── Loader: pick correct implementation ───────────────────────────────────
    Loader {
        id: wsLoader
        anchors.fill: parent
        sourceComponent: {
            if (WMDetector.isHyprland) return hyprlandWS;
            if (WMDetector.isI3)       return i3WS;
            return hyprlandWS;
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Hyprland implementation
    // ══════════════════════════════════════════════════════════════════════════
    Component {
        id: hyprlandWS

        Item {
            width: 250
            height: 50
            implicitWidth: 250
            implicitHeight: 50

            ScrollView {
                id: wsRow
                anchors.fill: parent
                contentWidth: wsRowLayout.implicitWidth
                contentHeight: height
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                clip: true

                RowLayout {
                    id: wsRowLayout
                    height: parent.height
                    spacing: 2
                    Layout.leftMargin: 2
                    Layout.rightMargin: 2

                    Repeater {
                        readonly property int maxOccupied: {
                            let max = 0;
                            const ws = Hyprland.workspaces.values;
                            for (let i = 0; i < ws.length; i++) {
                                if (ws[i].id > max) max = ws[i].id;
                            }
                            return max;
                        }
                        readonly property int maxModel: Math.max(maxOccupied, Hyprland.focusedWorkspace?.id ?? 0)
                        model: maxModel

                        Rectangle {
                            id: wsItem
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: shouldShow ? 30 : 0
                            color: "transparent"

                            readonly property int wsId: index + 1
                            readonly property var workspace: Hyprland.workspaces.values.find(ws => ws.id === wsId) ?? null
                            readonly property bool isActive: Hyprland.focusedWorkspace?.id === wsId
                            readonly property bool hasWindows: workspace !== null
                            readonly property bool shouldShow: hasWindows || isActive || wsId === parent.maxModel

                            visible: shouldShow

                            onIsActiveChanged: {
                                if (isActive) {
                                    var itemCenter = x + width / 2;
                                    var targetX = itemCenter - wsRow.width / 2;
                                    var clamped = Math.max(0, Math.min(targetX, wsRow.contentItem.contentWidth - wsRow.width));
                                    scrollAnim.to = clamped;
                                    scrollAnim.start();
                                }
                            }

                            states: [
                                State {
                                    name: "active"
                                    when: wsItem.isActive
                                    PropertyChanges {
                                        target: wsItem
                                        Layout.leftMargin: 18
                                        Layout.rightMargin: 18
                                    }
                                    PropertyChanges {
                                        target: innerRect
                                        width: 60
                                        color: colBar
                                    }
                                },
                                State {
                                    name: "inactive"
                                    when: !wsItem.isActive
                                    PropertyChanges {
                                        target: wsItem
                                        Layout.leftMargin: 0.5
                                        Layout.rightMargin: 0.5
                                    }
                                    PropertyChanges {
                                        target: innerRect
                                        width: 30
                                        color: colSurface
                                    }
                                }
                            ]

                            transitions: Transition {
                                NumberAnimation {
                                    properties: "Layout.leftMargin, Layout.rightMargin, width"
                                    duration: 300
                                    easing.type: Easing.InOutCubic
                                }
                                ColorAnimation {
                                    duration: 300
                                    easing.type: Easing.InOutCubic
                                }
                            }

                            Rectangle {
                                id: innerRect
                                height: 30
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                radius:20
                            }

                            Text {
                                id: wsLabel
                                readonly property string icon: {
                                    // реактивная зависимость на wsClassMap
                                    const _dep = workspacesRoot.wsClassMap;
                                    return workspacesRoot.getWorkspaceIcon(parent.wsId);
                                }
                                readonly property bool hasIcon: icon !== ""

                                text: hasIcon ? icon : parent.wsId.toString()
                                color: parent.isActive ? colBg : parent.hasWindows ? colMuted : colEmpty
                                font.pixelSize: fontSize
                                font.family: hasIcon ? "Symbols Nerd Font Mono" : fontFamily
                                font.bold: !hasIcon
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: Hyprland.dispatch("workspace " + parent.wsId)
                            }
                        }
                    }
                } // RowLayout

                NumberAnimation {
                    id: scrollAnim
                    target: wsRow.contentItem
                    property: "contentX"
                    duration: 800
                    easing.type: Easing.InOutBack
                }
            } // ScrollView

            // Затемнение левого края
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 32
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: colBg }
                    GradientStop { position: 0.5; color: "transparent" }
                }
            }

            // Затемнение правого края
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 32
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.3; color: colBg }
                }
            }
        } // Item
    }

    // ══════════════════════════════════════════════════════════════════════════
    // i3 implementation
    // ══════════════════════════════════════════════════════════════════════════
    Component {
        id: i3WS

        WorkspacesI3 {
            fontFamily: workspacesRoot.fontFamily
            fontSize: workspacesRoot.fontSize
            colActive: workspacesRoot.colActive
            colOccupied: workspacesRoot.colOccupied
            colEmpty: workspacesRoot.colEmpty
            colBar: workspacesRoot.colBar
            colBg: workspacesRoot.colBg
        }
    }

    Component.onCompleted: {
        console.log("WMDetector.name =", WMDetector.name);
        console.log("WMDetector.isI3 =", WMDetector.isI3);
    }
}
