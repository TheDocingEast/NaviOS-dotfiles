// modules/NotificationHistory.qml
// Вкладка "Уведомления" внутри ControlMenu.
// Отображает историю + управление DND.
// Данные получает через npService (ссылка на NotificationPopup из shell.qml).
//
// Использование в ControlMenu:
//   NotificationHistory {
//       notifService: notifPopup   // id NotificationPopup
//       fontFamily: ...; colBg: ...; ...
//   }

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: nhRoot

    // ── Тема ─────────────────────────────────────────────────────────────
    property string fontFamily:  "Monaspace Krypton Medium"
    property int    fontSize:    16
    property color  colBg:       "#2e3440"
    property color  colFg:       "#d8dee9"
    property color  colSurface:  "#3b4252"
    property color  colMuted:    "#4c566a"
    property color  colCyan:     "#8fbcbb"
    property color  colBlue:     "#5e81ac"
    property color  colLBlue:    "#81a1c1"
    property color  colGreen:    "#a3be8c"
    property color  colRed:      "#bf616a"
    property color  colYellow:   "#ebcb8b"

    // ── Источник данных (NotificationPopup из shell.qml) ─────────────────
    property var notifService: null

    // Удобные алиасы
    readonly property var   history:     notifService ? notifService.history     : null
    readonly property bool  dndActive:   notifService ? notifService.dndActive   : false
    readonly property int   unreadCount: notifService ? notifService.unreadCount : 0

    // ─────────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Заголовок: DND + счётчик + "Clear all" ───────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: Qt.rgba(0.18, 0.21, 0.25, 0.6)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // DND переключатель
                RowLayout {
                    spacing: 6

                    Text {
                        text: nhRoot.dndActive ? "󰂛" : "󰂚"
                                                font {
                            pixelSize: nhRoot.fontSize + 2
                            family: nhRoot.fontFamily
                        }
                        color: nhRoot.dndActive ? nhRoot.colYellow : nhRoot.colMuted
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        text: "Do Not Disturb"
                                                font {
                            pixelSize: nhRoot.fontSize - 3
                            family: nhRoot.fontFamily
                        }
                        color: nhRoot.dndActive ? nhRoot.colYellow : nhRoot.colMuted
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // Toggle switch
                    Rectangle {
                        id: dndToggle
                        width: 36
                        height: 18
                        radius: 0
                        color: nhRoot.dndActive
                            ? Qt.rgba(0.93, 0.80, 0.55, 0.3)
                            : Qt.rgba(0.30, 0.36, 0.41, 0.6)
                        border.color: nhRoot.dndActive ? nhRoot.colYellow : nhRoot.colMuted
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            id: dndKnob
                            width: 12
                            height: 12
                            anchors.verticalCenter: parent.verticalCenter
                            x: nhRoot.dndActive ? parent.width - width - 3 : 3
                            color: nhRoot.dndActive ? nhRoot.colYellow : nhRoot.colMuted
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (nhRoot.notifService)
                                    nhRoot.notifService.dndActive = !nhRoot.notifService.dndActive
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Счётчик непрочитанных
                Rectangle {
                    visible: nhRoot.unreadCount > 0
                    width: Math.max(20, unreadBadge.implicitWidth + 8)
                    height: 18
                    color: Qt.rgba(0.37, 0.51, 0.67, 0.3)
                    border.color: nhRoot.colBlue
                    border.width: 1

                    Text {
                        id: unreadBadge
                        anchors.centerIn: parent
                        text: nhRoot.unreadCount
                                                font {
                            pixelSize: nhRoot.fontSize - 5
                            family: nhRoot.fontFamily
                            bold: true
                        }
                        color: nhRoot.colLBlue
                    }
                }

                // "Mark all read"
                Text {
                    visible: nhRoot.unreadCount > 0
                    text: "󰄳"
                                        font {
                        pixelSize: nhRoot.fontSize
                        family: nhRoot.fontFamily
                    }
                    color: markMa.containsMouse ? nhRoot.colGreen : nhRoot.colMuted
                    Behavior on color { ColorAnimation { duration: 80 } }

                    MouseArea {
                        id: markMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (nhRoot.notifService) nhRoot.notifService.markAllRead() }
                    }
                }

                // "Clear all"
                Text {
                    text: "󰆴"
                                        font {
                        pixelSize: nhRoot.fontSize
                        family: nhRoot.fontFamily
                    }
                    color: clearMa.containsMouse ? nhRoot.colRed : nhRoot.colMuted
                    Behavior on color { ColorAnimation { duration: 80 } }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (nhRoot.notifService) nhRoot.notifService.clearHistory() }
                    }
                }
            }
        }

        // Разделитель
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: nhRoot.colMuted
            opacity: 0.25
        }

        // ── Список уведомлений ────────────────────────────────────────────
        Item {
            Layout.fillWidth:  true
            Layout.fillHeight: true

            // Пустое состояние
            ColumnLayout {
                anchors.centerIn: parent
                visible: !nhRoot.history || nhRoot.history.count === 0
                spacing: 8

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰂚"
                                        font {
                        pixelSize: 36
                        family: nhRoot.fontFamily
                    }
                    color: nhRoot.colMuted
                    opacity: 0.3
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No notifications"
                                        font {
                        pixelSize: nhRoot.fontSize - 2
                        family: nhRoot.fontFamily
                    }
                    color: nhRoot.colMuted
                    opacity: 0.4
                }
            }

            // Список
            ListView {
                anchors.fill: parent
                model: nhRoot.history
                clip: true
                spacing: 0

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: Rectangle {
                    id: histItem
                    required property var  modelData
                    required property int  index
                    width:  ListView.view.width
                    height: histCol.implicitHeight + 16

                    // Непрочитанные — слегка подсвечены
                    color: modelData.read
                        ? "transparent"
                        : Qt.rgba(0.37, 0.51, 0.67, 0.06)

                    Behavior on color { ColorAnimation { duration: 200 } }

                    // Левый индикатор непрочитанного
                    Rectangle {
                        visible: !modelData.read
                        width: 2
                                                anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        color: nhRoot.colCyan
                    }

                    // Разделитель снизу
                    Rectangle {
                                                anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                        }
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        height: 1
                        color: nhRoot.colMuted
                        opacity: 0.15
                    }

                    RowLayout {
                        id: histCol
                                                anchors {
                            left: parent.left
                            right: parent.right
                            margins: 10
                        }
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // Иконка приложения
                        Item {
                            width: 22
                            height: 22
                            visible: modelData.notif !== undefined

                            Image {
                                id: histIcon
                                anchors.fill: parent
                                source: {
                                    if (!modelData.notif) return ""
                                    if (modelData.notif.image) return modelData.notif.image
                                    var ic = modelData.notif.appIcon || ""
                                    if (!ic) return ""
                                    if (!ic.includes("/")) return "image://icon/" + ic
                                    return "file://" + ic
                                }
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: histIcon.status !== Image.Ready
                                color: nhRoot.colBlue
                                opacity: 0.15

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.notif
                                        ? (modelData.notif.appName || "?")[0].toUpperCase()
                                        : "?"
                                                                        font {
                                        pixelSize: nhRoot.fontSize - 4
                                        family: nhRoot.fontFamily
                                    }
                                    color: nhRoot.colLBlue
                                }
                            }
                        }

                        // Текст
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: modelData.notif ? (modelData.notif.appName || "Unknown") : "Unknown"
                                                                        font {
                                        pixelSize: nhRoot.fontSize - 5
                                        family: nhRoot.fontFamily
                                    }
                                    color: nhRoot.colMuted
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                text: modelData.notif ? (modelData.notif.summary || "") : ""
                                                                font {
                                    pixelSize: nhRoot.fontSize - 3
                                    family: nhRoot.fontFamily
                                    bold: true
                                }
                                color: modelData.read ? nhRoot.colFg : nhRoot.colCyan
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            Text {
                                visible: modelData.notif && modelData.notif.body !== ""
                                text: modelData.notif ? (modelData.notif.body || "") : ""
                                                                font {
                                    pixelSize: nhRoot.fontSize - 5
                                    family: nhRoot.fontFamily
                                }
                                color: nhRoot.colFg
                                opacity: 0.7
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        // Dismiss кнопка
                        Text {
                            text: "✕"
                                                        font {
                                pixelSize: nhRoot.fontSize - 5
                                family: nhRoot.fontFamily
                            }
                            color: dismissMa.containsMouse ? nhRoot.colFg : nhRoot.colMuted
                            opacity: 0.6
                            Behavior on color { ColorAnimation { duration: 80 } }

                            MouseArea {
                                id: dismissMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.notif) modelData.notif.dismiss()
                                    nhRoot.history.remove(index)
                                }
                            }
                        }
                    }

                    // Клик по записи — отметить как прочитанное
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: {
                            nhRoot.history.setProperty(index, "read", true)
                        }
                    }
                }
            }
        }
    }
}
