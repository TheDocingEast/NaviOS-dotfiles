import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Niri 0.1

Item {
    id: workspacesRoot

    property string fontFamily:  "Monaspace Krypton Medium"
    property int    fontSize:    16
    property color  colActive:   "#81a1c1"
    property color  colOccupied: "#d8dee9"
    property color  colEmpty:    "#4c566a"
    property color  colBar:      "#5e81ac"
    property color  colBg:       "#2e3440"
    property color  colSurface:  "#3b4252"
    property color  colMuted:    "#4c566a"

    property string screenName:   ""
    property var    niriInstance: null

    implicitWidth:  260
    implicitHeight: 50
    Layout.fillHeight: true
    Layout.preferredWidth: 260
    Layout.alignment: Qt.AlignVCenter

    readonly property var appIcons: ({
        "steam":"󰓓","telegram-desktop":"","org.telegram.desktop":"",
        "discord":"","vesktop":"󰙯","firefox":"󰈹","chromium":"",
        "google-chrome":"","brave-browser":"󰖟","code":"󰨞","code-oss":"󰨞",
        "pycharm":"","idea":"","clion":"","foot":"","ghostty":"",
        "org.wezfurlong.wezterm":"","kitty":"","konsole":"",
        "thunar":"󰉋","org.gnome.nautilus":"󰉋","nemo":"󰉋","dolphin":"󰉋",
        "spotify":"󰓇","mpv":"","vlc":"󰕼","com.obsproject.studio":"󰐌",
        "gimp":"","inkscape":"","blender":"󰂫","krita":"","slack":"󰒱",
        "zoom":"󰍫","thunderbird":"󰇮","libreoffice-writer":"󰈙",
        "virtualbox":"󰡨","obsidian":"󱓩","prusa-slicer":"",
    })

    // hasWindows — проверяем через activeWindowId воркспейса
    // (workspaceModel не итерируется в JS, windows тоже)
    // Используем isActive как прокси — если воркспейс active (не просто focused),
    // значит на нём есть контекст. Для hasWindows используем model.activeWindowId.
    function wsHasWindows(wsModel) {
        // activeWindowId > 0 означает что на воркспейсе есть активное окно
        return (wsModel.activeWindowId ?? 0) > 0
    }

    Item {
        width: 260
        height: 50

        ScrollView {
            id: wsRow
            anchors.fill: parent
            contentWidth: wsRowLayout.implicitWidth
            contentHeight: height
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy:   ScrollBar.AlwaysOff
            clip: true

            RowLayout {
                id: wsRowLayout
                height: parent.height
                spacing: 2

                Repeater {
                    // WorkspaceModel поддерживает Repeater напрямую
                    model: niriInstance ? niriInstance.workspaces : null

                    delegate: Rectangle {
                        id: wsItem

                        // Фильтрация по монитору через visible + нулевой размер
                        readonly property bool matchesScreen:
                            workspacesRoot.screenName === "" ||
                            (model.output ?? "").toLowerCase() === workspacesRoot.screenName.toLowerCase()

                        readonly property bool isActive:   model.isFocused   ?? false
                        readonly property bool hasWindows: (model.activeWindowId ?? 0) > 0

                        visible:                matchesScreen
                        Layout.preferredHeight: matchesScreen ? 30 : 0
                        Layout.preferredWidth:  matchesScreen ? (isActive ? 60 : 30) : 0

                        color: "transparent"
                        clip:  true

                        Behavior on Layout.preferredWidth {
                            NumberAnimation { duration: 300; easing.type: Easing.InOutCubic }
                        }

                        onIsActiveChanged: {
                            if (isActive && matchesScreen) {
                                var center = x + width / 2
                                var target = center - wsRow.width / 2
                                var clamped = Math.max(0, Math.min(target,
                                    wsRow.contentItem.contentWidth - wsRow.width))
                                scrollAnim.to = clamped
                                scrollAnim.start()
                            }
                        }

                        Rectangle {
                            height: 30
                            width: wsItem.isActive ? 60 : 30
                            anchors.centerIn: parent
                            radius: 20
                            color: wsItem.isActive ? workspacesRoot.colBar : workspacesRoot.colSurface
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.InOutCubic } }
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        Text {
                            readonly property bool hasIcon: false  // иконки без .get() недоступны — отключено
                            readonly property string label: {
                                var name = model.name ?? ""
                                return name.length > 0 ? name : model.index.toString()
                            }

                            text: label
                            color: wsItem.isActive   ? workspacesRoot.colBg
                                 : wsItem.hasWindows ? workspacesRoot.colOccupied
                                 : workspacesRoot.colEmpty
                            font.pixelSize: workspacesRoot.fontSize
                            font.family: workspacesRoot.fontFamily
                            font.bold: true
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (niriInstance)
                                    niriInstance.focusWorkspaceById(model.id)
                            }
                        }
                    }
                }
            }

            NumberAnimation {
                id: scrollAnim
                target: wsRow.contentItem
                property: "contentX"
                duration: 800
                easing.type: Easing.InOutBack
            }
        }

        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 32
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: workspacesRoot.colBg }
                GradientStop { position: 0.6; color: "transparent" }
            }
        }

        Rectangle {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 32
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: workspacesRoot.colBg }
            }
        }
    }
}
