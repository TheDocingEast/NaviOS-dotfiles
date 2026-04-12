// Standalone wallpaper selector — запускается отдельно:
//   quickshell -c hyprquickpaper
// Биндинг в hyprland.conf:
//   bind = SUPER, R, exec, quickshell -c hyprquickpaper
// Зависимости: imagemagick (для cache.sh), jq (для config.json)

import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: main

    // ── Nord palette ──────────────────────────────────────────────
    readonly property color colBg: "#2e3440"
    readonly property color colFg: "#d8dee9"
    readonly property color colAccent: "#d8dee9"
    readonly property color colMuted: "#4c566a"
    readonly property color colSurface: "#3b4252"
    readonly property color colCyan: "#8fbcbb"
    readonly property color colBlue: "#81a1c1"
    readonly property color colRed: "#bf616a"
    readonly property color colGreen: "#a3be8c"
    readonly property string fontFamily: "Monaspace Krypton Medium"

    implicitHeight: 300
    implicitWidth: Screen.width
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 1
    anchors {
        bottom: true
        left: true
        right: true
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    // ── Запустить cache.sh при старте ────────────────────────────
    Component.onCompleted: {
        Quickshell.execDetached(["bash", Quickshell.shellPath("cache.sh"), Quickshell.shellDir]);
    }

    // ── Читаем config.json ────────────────────────────────────────
    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs

            property string wallpaper_path
            property string cache_path
            property int number_of_pictures: 6
        }

    }

    // ── Список обоев через FolderListModel ────────────────────────
    FolderListModel {
        id: folderModel

        folder: "file://" + configs.wallpaper_path
        showDirs: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif"]
        sortField: FolderListModel.Name
    }



    // ── Горизонтальный список ─────────────────────────────────────
    ListView {
        id: list

        property int selectedIndex: 0
        readonly property real tileWidth: width / configs.number_of_pictures - spacing

        function clampIndex(i) {
            return Math.max(0, Math.min(i, count - 1));
        }

        function activateCurrent() {
            const path = folderModel.get(selectedIndex, "filePath");
            if (!path)
                return ;

            Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), path]);
            Qt.quit();
        }

        function clampX(x) {
            return Math.max(0, Math.min(x, contentWidth - width));
        }

        function ensureVisibleAnimated(i) {
            const step = tileWidth + spacing;
            const itemStart = i * step;
            const itemEnd = itemStart + tileWidth + 20;
            if (itemStart < contentX)
                contentX = clampX(itemStart);
            else if (itemEnd > contentX + width)
                contentX = clampX(itemStart - (width - step));
        }

        anchors.fill: parent
        focus: true
        model: folderModel
        orientation: ListView.Horizontal
        clip: true
        anchors.bottomMargin: -10
        cacheBuffer: width * 2
        // ── Клавиши ───────────────────────────────────────────────
        Keys.onPressed: function(event) {
            const step = 1;
            const big = configs.number_of_pictures;
            switch (event.key) {
            case Qt.Key_J:
                list.selectedIndex = list.clampIndex(list.selectedIndex + step);
                list.ensureVisibleAnimated(list.selectedIndex);
                break;
            case Qt.Key_K:
                list.selectedIndex = list.clampIndex(list.selectedIndex - step);
                list.ensureVisibleAnimated(list.selectedIndex);
                break;
            case Qt.Key_D:
                list.selectedIndex = list.clampIndex(list.selectedIndex + big);
                list.ensureVisibleAnimated(list.selectedIndex);
                break;
            case Qt.Key_U:
                list.selectedIndex = list.clampIndex(list.selectedIndex - big);
                list.ensureVisibleAnimated(list.selectedIndex);
                break;
            case Qt.Key_Right:
                list.selectedIndex = list.clampIndex(list.selectedIndex + step);
                list.ensureVisibleAnimated(list.selectedIndex);
                break;
            case Qt.Key_Left:
                list.selectedIndex = list.clampIndex(list.selectedIndex - step);
                list.ensureVisibleAnimated(list.selectedIndex);
                break;
            case Qt.Key_Space:
            case Qt.Key_Return:
                list.activateCurrent();
                break;
            case Qt.Key_Escape:
                Qt.quit();
                break;
            default:
                return ;
            }
            event.accepted = true;
        }

        Behavior on contentX {
            SmoothedAnimation {
                id: scrollAnim

                duration: 120
            }

        }
        
        // ── Delegate ──────────────────────────────────────────────
        delegate: Item {
            readonly property bool active: index === list.selectedIndex
                        transform: Shear {
                yFactor: 0.1
                xFactor: -0.1
            }
            
            width: list.tileWidth
            height: list.height 
            layer.live: true

            Behavior on width {
                PropertyAnimation {
                    duration: 120
                }
            }
            Behavior on height {
                PropertyAnimation {
                    duration: 120
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 6
                width: 40
                height: 20
                radius: 4
                color: colBg
                visible: fileName.toLowerCase().endsWith(".gif")
                z: 3

                Text {
                    anchors.centerIn: parent
                    text: "GIF"
                    color: "#8fbcbb"
                    font.pixelSize: 14
                    font.bold: true
                    font.family: main.fontFamily
                }

            }

            // Thumbnail
            Image {
                id: img
                
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                smooth: true
                source: "file://" + configs.cache_path + fileName
                sourceSize.width: width
                sourceSize.height: height
                onStatusChanged: {
                    if (status === Image.Error)
                        retryTimer.start();

                }

                // Retry если ещё кешируется
                Timer {
                    id: retryTimer

                    interval: 1500
                    repeat: false
                    onTriggered: {
                        const s = img.source;
                        img.source = "";
                        img.source = s;
                    }
                }

                // Placeholder
                Rectangle {
                    anchors.fill: parent
                    visible: img.status !== Image.Ready
                    color: main.colSurface

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: img.status === Image.Error ? "Caching..." : "Loading..."
                            color: main.colMuted
                            font.pixelSize: 12
                            font.family: main.fontFamily
                        }

                    }

                }

            }

            // Тёмный оверлей на неактивных
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, active ? 0 : 0.45)

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }

                }

            }

            // Рамка активного
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: active ? 3 : 0
                border.color: colAccent
                visible: active

                Behavior on border.width {
                    NumberAnimation {
                        duration: 80
                    }

                }

            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    list.selectedIndex = index;
                    list.activateCurrent();
                }
                onWheel: function(wheel) {
                    list.contentX = list.clampX(list.contentX - wheel.angleDelta.y * 2);
                    wheel.accepted = false;
                }
            }

        }

    }

}
