import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {

    // ── Тема ──────────────────────────────────────────────────────────────
    property string fontFamily: "Monaspace Krypton Medium"
    property int    fontSize:   16
    property color  colBg:      "#2e3440"
    property color  colFg:      "#d8dee9"
    property color  colSurface: "#3b4252"
    property color  colMuted:   "#4c566a"
    property color  colCyan:    "#8fbcbb"
    property color  colBlue:    "#5e81ac"
    property color  colLBlue:   "#81a1c1"
    property color  colGreen:   "#a3be8c"
    property color  colRed:     "#bf616a"
    property color  colYellow:  "#ebcb8b"

    // ── Состояние поиска ──────────────────────────────────────────────────
    property string searchQuery:  ""
    property int    highlightIdx: 0

    onSearchQueryChanged: highlightIdx = 0

    // ── Первые 12 приложений для кругового лаунчера ───────────────────────
    // ObjectModel нельзя slice в QML-binding напрямую — используем ScriptModel
    ScriptModel {
        id: featuredModel
        // Берём первые 12 из applications
        values: DesktopEntries.applications.values.slice(0, 12)
    }

    // ── Модель результатов поиска ─────────────────────────────────────────
    ScriptModel {
        id: searchModel
        values: {
            var q = searchQuery.toLowerCase().trim()
            if (q === "") return []
            return DesktopEntries.applications.values.filter(function(e) {
                if (!e || !e.name) return false
                return e.name.toLowerCase().includes(q)
                    || (e.genericName && e.genericName.toLowerCase().includes(q))
                    || (e.id && e.id.toLowerCase().includes(q))
            }).slice(0, 20)
        }
    }

    // ── Функция запуска ───────────────────────────────────────────────────
    function launch(entry) {
        if (!entry) return
        entry.execute()
    }

    // ══════════════════════════════════════════════════════════════════════
    // ГЛАВНОЕ ОКНО — PanelWindow (всегда видимо при запуске через qs -p)
    // ══════════════════════════════════════════════════════════════════════
    PanelWindow {
        id: launcherWin

        // Центрируем на экране
        anchors.left:   false
        anchors.right:  false
        anchors.top:    false
        anchors.bottom: false

        implicitWidth:  540
        implicitHeight: mainCard.implicitHeight

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer:    WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        color: "transparent"

        Rectangle {
            id: mainCard
            anchors.fill: parent
            implicitHeight: mainCol.implicitHeight + 24

            color: Qt.rgba(
                Qt.color(colBg).r,
                Qt.color(colBg).g,
                Qt.color(colBg).b,
                0.97)
            border.color: colBlue
            border.width: 1
            radius: 14
            clip: true

            // Появление
            opacity: 0
            Component.onCompleted: {
                mainCard.opacity = 1
                searchField.forceActiveFocus()
            }
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: mainCol
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 16
                }
                spacing: 0

                // ── Заголовок ──────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 10
                    spacing: 8

                    Text {
                        text: "󰣖"
                        font { pixelSize: fontSize + 2; family: fontFamily }
                        color: colCyan
                    }
                    Text {
                        text: "App Launcher"
                        font { pixelSize: fontSize; family: fontFamily; bold: true }
                        color: colFg
                        Layout.fillWidth: true
                    }
                    Text {
                        text: DesktopEntries.applications.values.length + " apps"
                        font { pixelSize: fontSize - 5; family: fontFamily }
                        color: colMuted
                        opacity: 0.6
                    }
                }

                // Разделитель
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: colMuted
                    opacity: 0.25
                    visible: searchQuery === ""
                }

                // ── Поле поиска ────────────────────────────────────────────
                Rectangle {
                    id: searchBox
                    Layout.fillWidth: true
                    Layout.topMargin:    10
                    Layout.bottomMargin: searchQuery !== "" ? 6 : 10
                    height: 42
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: searchField.activeFocus
                        ? colCyan
                        : Qt.rgba(Qt.color(colMuted).r, Qt.color(colMuted).g, Qt.color(colMuted).b, 0.6)
                    border.width: 1
                    radius: 8
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 8

                        Text {
                            text: "󰍉"
                            font { pixelSize: fontSize + 2; family: fontFamily }
                            color: searchField.activeFocus ? colCyan : colMuted
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        // Placeholder текст
                        Text {
                            visible: searchField.text.length === 0 && !searchField.activeFocus
                            text: "Search applications..."
                            font { pixelSize: fontSize - 2; family: fontFamily }
                            color: colMuted
                            opacity: 0.5
                        }

                        TextInput {
                            id: searchField
                            Layout.fillWidth: true
                            color: colFg
                            selectionColor: colBlue
                            font { pixelSize: fontSize - 2; family: fontFamily }
                            selectByMouse: true

                            onTextChanged: searchQuery = text

                            Keys.onEscapePressed: {
                                if (text.length > 0) {
                                    text = ""
                                } else {
                                    Qt.quit()
                                }
                            }
                            Keys.onReturnPressed: {
                                if (searchModel.values.length > 0) {
                                    var idx = Math.max(0, Math.min(highlightIdx, searchModel.values.length - 1))
                                    launch(searchModel.values[idx])
                                }
                            }
                            Keys.onUpPressed: {
                                if (highlightIdx > 0) highlightIdx--
                                resultsList.positionViewAtIndex(highlightIdx, ListView.Contain)
                            }
                            Keys.onDownPressed: {
                                if (highlightIdx < searchModel.values.length - 1) highlightIdx++
                                resultsList.positionViewAtIndex(highlightIdx, ListView.Contain)
                            }
                        }

                        // Очистить
                        Text {
                            visible: searchField.text.length > 0
                            text: "✕"
                            font { pixelSize: fontSize - 4; family: fontFamily }
                            color: clearBtnMa.containsMouse ? colFg : colMuted
                            Behavior on color { ColorAnimation { duration: 80 } }
                            MouseArea {
                                id: clearBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { searchField.text = ""; searchField.forceActiveFocus() }
                            }
                        }
                    }
                }

                // ── Результаты поиска ──────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    // Высота: max 6 строк × 52px, иначе 0
                    Layout.preferredHeight: searchQuery !== ""
                        ? (searchModel.values.length > 0
                            ? Math.min(searchModel.values.length, 6) * 52 + 6
                            : 44)
                        : 0
                    visible: searchQuery !== ""
                    clip: true

                    Behavior on Layout.preferredHeight {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    // «Ничего не найдено»
                    Text {
                        visible: searchModel.values.length === 0
                        anchors.centerIn: parent
                        text: "No applications found"
                        font { pixelSize: fontSize - 3; family: fontFamily }
                        color: colMuted
                        opacity: 0.5
                    }

                    // Список результатов с анимацией «листания книги»
                    ListView {
                        id: resultsList
                        anchors.fill: parent
                        anchors.bottomMargin: 4
                        model: searchModel
                        clip: true
                        spacing: 2
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        // Анимация листания: новые записи «въезжают» сверху
                        add: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                                NumberAnimation { property: "y"; from: -18; duration: 150; easing.type: Easing.OutCubic }
                            }
                        }
                        displaced: Transition {
                            NumberAnimation { property: "y"; duration: 130; easing.type: Easing.OutCubic }
                        }
                        remove: Transition {
                            ParallelAnimation {
                                NumberAnimation { property: "opacity"; to: 0; duration: 110 }
                                NumberAnimation { property: "y"; to: 16; duration: 110; easing.type: Easing.InCubic }
                            }
                        }

                        delegate: Rectangle {
                            id: resRow
                            required property var  modelData
                            required property int  index

                            width:  resultsList.width
                            height: 50
                            radius: 7
                            color: {
                                if (index === highlightIdx)
                                    return Qt.rgba(Qt.color(colCyan).r, Qt.color(colCyan).g, Qt.color(colCyan).b, 0.12)
                                if (resMa.containsMouse)
                                    return Qt.rgba(1, 1, 1, 0.05)
                                return "transparent"
                            }
                            border.color: index === highlightIdx ? colCyan : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 80 } }

                            // Тонкая линия — «страницы книги»
                            Rectangle {
                                visible: index > 0
                                anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 50 }
                                height: 1
                                color: colMuted
                                opacity: 0.1
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                spacing: 10

                                // Иконка
                                Item {
                                    width: 32; height: 32
                                    Image {
                                        id: resIcon
                                        anchors.fill: parent
                                        source: {
                                            var ic = modelData.icon || ""
                                            if (!ic) return ""
                                            if (ic.startsWith("/")) return "file://" + ic
                                            return "image://icon/" + ic
                                        }
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        visible: status === Image.Ready
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        visible: resIcon.status !== Image.Ready
                                        color: Qt.rgba(0.37, 0.51, 0.67, 0.2)
                                        radius: 6
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.name ? modelData.name[0].toUpperCase() : "?"
                                            font { pixelSize: fontSize - 2; family: fontFamily; bold: true }
                                            color: colLBlue
                                        }
                                    }
                                }

                                // Имя + описание
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: modelData.name || ""
                                        font {
                                            pixelSize: fontSize - 2
                                            family: fontFamily
                                            bold: index === highlightIdx
                                        }
                                        color: index === highlightIdx ? colCyan : colFg
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                    }
                                    Text {
                                        visible: (modelData.genericName || "") !== "" || (modelData.comment || "") !== ""
                                        text: modelData.genericName || modelData.comment || ""
                                        font { pixelSize: fontSize - 5; family: fontFamily }
                                        color: colMuted
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        opacity: 0.7
                                    }
                                }

                                // Стрелка запуска
                                Text {
                                    text: "󰐊"
                                    font { pixelSize: fontSize - 2; family: fontFamily }
                                    color: index === highlightIdx ? colCyan : colMuted
                                    opacity: (resMa.containsMouse || index === highlightIdx) ? 1.0 : 0.25
                                    Behavior on opacity { NumberAnimation { duration: 80 } }
                                    Behavior on color   { ColorAnimation  { duration: 80 } }
                                }
                            }

                            MouseArea {
                                id: resMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: highlightIdx = index
                                onClicked: {
                                    launch(modelData)
                                    Qt.quit()
                                }
                            }
                        }
                    }
                }

                // Нижний отступ
                Item { height: 6 }
            }
        }
    }
}
