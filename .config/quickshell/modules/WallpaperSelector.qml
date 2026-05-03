import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Wallpaper picker — FloatingWindow.
// Открывается/закрывается через toggle().
// Цвета принимаются снаружи, как в CalendarModule, WifiModule и др.
FloatingWindow {
    id: root

    // ── Theme props (пробрасываются из ShellRoot) ─────────────────
    property string fontFamily: "sans-serif"
    property int fontSize: 14
    property color colBg: "#2e3440"
    property color colFg: "#d8dee9"
    property color colMuted: "#4c566a"
    property color colCyan: "#8fbcbb"
    property color colBlue: "#5e81ac"
    property color colLBlue: "#81a1c1"
    property color colGreen: "#a3be8c"
    property color colRed: "#bf616a"
    property color colYellow: "#ebcb8b"

    // ── Public API ────────────────────────────────────────────────
    function toggle() {
        if (visible)
            _close()
        else
            _open()
    }

    function _open() {
        visible = true
        WallpaperService.refresh()
        searchField.text = ""
        searchField.forceActiveFocus()
    }

    function _close() {
        visible = false
    }

    // ── Window props ──────────────────────────────────────────────
    visible: false
    title: "Wallpaper Selector"
    width: 920
    height: 260
    color: root.colBg

    // ── Root item — ловит Escape ──────────────────────────────────
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root._close()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // ── Header ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰸉  Wallpapers"
                    color: root.colCyan
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                    font.bold: true
                }

                // Фильтр
                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: 5
                    color: root.colMuted
                    border.color: root.colLBlue
                    border.width: searchField.activeFocus ? 1 : 0

                    TextInput {
                        id: searchField
                        anchors.fill: parent
                        anchors.margins: 5
                        color: root.colFg
                        font.pixelSize: root.fontSize - 2
                        font.family: root.fontFamily
                        clip: true

                        Text {
                            anchors.fill: parent
                            text: "Filter..."
                            color: root.colMuted
                            font.pixelSize: root.fontSize - 2
                            font.family: root.fontFamily
                            visible: !searchField.text && !searchField.activeFocus
                        }

                        Keys.onEscapePressed: root._close()
                        Keys.onReturnPressed: {
                            if (wallpaperGrid.currentIndex >= 0 && wallpaperGrid.currentIndex < filteredModel.count) {
                                WallpaperService.setWallpaper(filteredModel.get(wallpaperGrid.currentIndex).name)
                                root._close()
                            }
                        }
                        Keys.onLeftPressed:  wallpaperGrid.moveCurrentIndexLeft()
                        Keys.onRightPressed: wallpaperGrid.moveCurrentIndexRight()
                    }
                }

                // Обновить тумбнейлы
                Rectangle {
                    width: 26
                    height: 26
                    radius: 5
                    color: refreshMa.containsMouse ? root.colLBlue : root.colMuted

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        color: root.colFg
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                    }
                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WallpaperService.refresh()
                    }
                    Behavior on color { ColorAnimation { duration: 80 } }
                }

                // Закрыть
                Rectangle {
                    width: 26
                    height: 26
                    radius: 5
                    color: closeMa.containsMouse ? root.colRed : root.colMuted

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        color: root.colFg
                        font.pixelSize: root.fontSize
                        font.family: root.fontFamily
                    }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._close()
                    }
                    Behavior on color { ColorAnimation { duration: 80 } }
                }
            }

            // ── Grid ──────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Loading
                Text {
                    anchors.centerIn: parent
                    visible: WallpaperService.loading
                    text: "Generating thumbnails..."
                    color: root.colMuted
                    font.pixelSize: root.fontSize
                    font.family: root.fontFamily
                }

                // Empty
                Text {
                    anchors.centerIn: parent
                    visible: !WallpaperService.loading && filteredModel.count === 0
                    text: "No wallpapers found in\n" + WallpaperService.wallpaperDir
                    color: root.colMuted
                    font.pixelSize: root.fontSize - 2
                    font.family: root.fontFamily
                    horizontalAlignment: Text.AlignHCenter
                }

                ListModel { id: filteredModel }

                Connections {
                    target: WallpaperService
                    function onWallpapersChanged() { rebuildFilter() }
                }
                Connections {
                    target: searchField
                    function onTextChanged() { rebuildFilter() }
                }

                function rebuildFilter() {
                    filteredModel.clear()
                    const q = searchField.text.toLowerCase()
                    for (const wp of WallpaperService.wallpapers) {
                        if (!q || wp.toLowerCase().includes(q))
                            filteredModel.append({ name: wp })
                    }
                }

                ScrollView {
                    anchors.fill: parent
                    contentWidth: wallpaperGrid.contentWidth
                    contentHeight: wallpaperGrid.cellHeight
                    clip: true

                    ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                    GridView {
                        id: wallpaperGrid
                        width: Math.max(contentWidth, filteredModel.count * cellWidth)
                        height: cellHeight
                        model: filteredModel
                        cellWidth: 178
                        cellHeight: 120
                        clip: false
                        flow: GridView.FlowLeftToRight
                        contentHeight: cellHeight

                    delegate: Item {
                        width: wallpaperGrid.cellWidth
                        height: wallpaperGrid.cellHeight

                        property string filename: model.name
                        readonly property bool isCurrent:
                            WallpaperService.currentWallpaper.endsWith("/" + model.name)

                        Rectangle {
                            id: card
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 7
                            clip: true
                            border.color: isCurrent ? root.colCyan
                                        : wallpaperGrid.currentIndex === index ? root.colLBlue
                                        : "transparent"
                            border.width: isCurrent ? 2 : (wallpaperGrid.currentIndex === index ? 1 : 0)
                            color: root.colMuted

                            // Превью
                            Image {
                                id: thumb
                                anchors.fill: parent
                                anchors.margins: card.border.width
                                source: "file://" + WallpaperService.thumbnailPath(model.name)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true

                                // Placeholder пока грузится
                                Rectangle {
                                    anchors.fill: parent
                                    visible: thumb.status !== Image.Ready
                                    color: root.colBg
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰸉"
                                        color: root.colMuted
                                        font.pixelSize: 26
                                    }
                                }
                            }

                            // Подпись
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 20
                                color: Qt.rgba(
                                    root.colBg.r, root.colBg.g, root.colBg.b, 0.75)

                                Text {
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    text: model.name
                                    color: root.colFg
                                    font.pixelSize: root.fontSize - 6
                                    font.family: root.fontFamily
                                    elide: Text.ElideMiddle
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            // ✓ на текущем
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 3
                                width: 14
                                height: 14
                                radius: 7
                                color: root.colCyan
                                visible: isCurrent

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: root.colBg
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }

                            // Hover overlay
                            Rectangle {
                                anchors.fill: parent
                                color: delegateMa.containsMouse
                                    ? Qt.rgba(root.colLBlue.r, root.colLBlue.g, root.colLBlue.b, 0.18)
                                    : "transparent"
                                radius: card.radius
                            }

                            MouseArea {
                                id: delegateMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: wallpaperGrid.currentIndex = index
                                onClicked: {
                                    WallpaperService.setWallpaper(model.name)
                                    root._close()
                                }
                            }
                        }
                    }
                    }   // GridView
                }   // ScrollView
            }   // Item (grid container)

            // ── Status bar ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: WallpaperService.loading
                        ? "Generating thumbnails..."
                        : filteredModel.count + " wallpaper" + (filteredModel.count !== 1 ? "s" : "")
                    color: root.colMuted
                    font.pixelSize: root.fontSize - 4
                    font.family: root.fontFamily
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: WallpaperService.currentWallpaper !== ""
                    text: "Current: " + WallpaperService.currentWallpaper.split("/").pop()
                    color: root.colMuted
                    font.pixelSize: root.fontSize - 4
                    font.family: root.fontFamily
                    elide: Text.ElideLeft
                    Layout.maximumWidth: 320
                }
            }
        }
    }
}
