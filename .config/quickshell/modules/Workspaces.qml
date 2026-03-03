import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// ── Workspaces widget ─────────────────────────────────────────────────────────
// Auto-detects running WM: Hyprland or i3
// Usage: Workspaces { fontFamily: ...; fontSize: ...; colActive: ...; ... }
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: workspacesRoot

    // ── Theming props (pass from parent) ──────────────────────────────────────
    property string fontFamily: "Monaspace Krypton Medium"
    property int fontSize: 16
    property color colActive: "#81a1c1"    // active workspace number
    property color colOccupied: "#d8dee9"    // has windows but not focused
    property color colEmpty: "#4c566a"    // no windows
    property color colBar: "#5e81ac"    // underline for active
    property color colBg: "#2e3440"    // bar background (for underline off)

    implicitWidth: wsLoader.item ? wsLoader.item.implicitWidth : 0
    implicitHeight: wsLoader.item ? wsLoader.item.implicitHeight : 50

    Layout.fillHeight: true
    Layout.fillWidth: false
    Layout.preferredWidth: implicitWidth
    Layout.alignment: Qt.AlignVCenter

    // ── Loader: pick correct implementation ───────────────────────────────────
    Loader {
        id: wsLoader
        anchors.fill: parent

        sourceComponent: {
            if (WMDetector.isHyprland)
                return hyprlandWS;
            if (WMDetector.isI3)
                return i3WS;
            return hyprlandWS;  // fallback
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Hyprland implementation
    // ══════════════════════════════════════════════════════════════════════════
    Component {
        id: hyprlandWS

        RowLayout {
            id: wsRow
            spacing: 2

            Repeater {
                readonly property int maxOccupied: {
                    let max = 0;
                    const ws = Hyprland.workspaces.values;
                    for (let i = 0; i < ws.length; i++) {
                        if (ws[i].id > max)
                            max = ws[i].id;
                    }
                    return max;
                }
                readonly property int maxModel: Math.max(maxOccupied, Hyprland.focusedWorkspace?.id ?? 0)
                model: maxModel

                Rectangle {
                    Layout.preferredHeight: 30
                    color: "transparent"

                    readonly property int wsId: index + 1
                    readonly property var workspace: Hyprland.workspaces.values.find(ws => ws.id === wsId) ?? null
                    readonly property bool isActive: Hyprland.focusedWorkspace?.id === wsId
                    readonly property bool hasWindows: workspace !== null
                    readonly property bool shouldShow: hasWindows || isActive || wsId === parent.maxModel

                    visible: shouldShow
                    Layout.preferredWidth: shouldShow ? 30 : 0

                    Text {
                        text: parent.wsId
                        color: parent.isActive ? colActive : parent.hasWindows ? colOccupied : colEmpty
                        font.pixelSize: fontSize
                        font.family: fontFamily
                        font.bold: true
                        anchors.centerIn: parent
                    }

                    Rectangle {
                        width: 20
                        height: 3
                        color: parent.isActive ? colBar : colBg
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Hyprland.dispatch("workspace " + parent.wsId)
                    }
                }
            }
        }
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
    // В Workspaces.qml временно добавь
    Component.onCompleted: {
        console.log("WMDetector.name =", WMDetector.name);
        console.log("WMDetector.isI3 =", WMDetector.isI3);
    }
}
