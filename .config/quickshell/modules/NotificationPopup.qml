// modules/NotificationPopup.qml
// Попапы входящих уведомлений. Объявляется внутри PanelWindow (bar) в shell.qml.
//
// Архитектура:
//   - NotificationServer принимает уведомления
//   - Максимум maxVisible попапов показываются одновременно через Repeater
//   - Очередь ожидающих хранится в pendingQueue
//   - Все PopupWindow объявлены статически (динамический createObject не работает в QS)
//   - История хранится в historyModel (ListModel), доступна снаружи
//
// API:
//   property var    history        — ListModel уведомлений
//   property int    unreadCount    — число непрочитанных
//   property bool   dndActive      — Do Not Disturb
//   function markAllRead()
//   function clearHistory()

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Item {
    id: npRoot

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

    // ── Настройки ─────────────────────────────────────────────────────────
    property int autoCloseMs: 4000
    property int maxVisible:  2
    property int popupWidth:  340
    property int topOffset:   58
    property int rightOffset: 12

    // ── DND ───────────────────────────────────────────────────────────────
    property bool dndActive: false

    // ── История ───────────────────────────────────────────────────────────
    ListModel { id: historyModel }

    readonly property alias history: historyModel

    readonly property int unreadCount: {
        var n = 0
        for (var i = 0; i < historyModel.count; i++) {
            if (!historyModel.get(i).read) n++
        }
        return n
    }

    function markAllRead() {
        for (var i = 0; i < historyModel.count; i++) {
            historyModel.setProperty(i, "read", true)
        }
    }

    function clearHistory() {
        // Скрываем все активные слоты
        for (var i = 0; i < maxVisible; i++) {
            slots.setProperty(i, "active", false)
            slots.setProperty(i, "notif", null)
        }
        pendingQueue = []
        historyModel.clear()
    }

    // ── Слоты попапов (статический список, максимум maxVisible) ───────────
    // Каждый слот — объект { active: bool, notif: object }
    ListModel {
        id: slots
        Component.onCompleted: {
            for (var i = 0; i < npRoot.maxVisible; i++) {
                slots.append({ active: false, notif: null })
            }
        }
    }

    // ── Очередь ───────────────────────────────────────────────────────────
    property var pendingQueue: []

    function enqueue(notif) {
        // Найти свободный слот
        for (var i = 0; i < slots.count; i++) {
            if (!slots.get(i).active) {
                slots.setProperty(i, "notif", notif)
                slots.setProperty(i, "active", true)
                return
            }
        }
        // Нет свободных — в очередь
        var q = pendingQueue.slice()
        q.push(notif)
        pendingQueue = q
    }

    function onSlotClosed(index) {
        slots.setProperty(index, "active", false)
        slots.setProperty(index, "notif", null)
        // Забираем следующее из очереди
        if (pendingQueue.length > 0) {
            var q = pendingQueue.slice()
            var next = q.shift()
            pendingQueue = q
            slots.setProperty(index, "notif", next)
            slots.setProperty(index, "active", true)
        }
    }

    // ── NotificationServer ────────────────────────────────────────────────
    NotificationServer {
        id: notifServer
        keepOnReload: true

        onNotification: function(notif) {
            // Сохраняем в историю
            historyModel.insert(0, { notif: notif, read: false })

            // DND: показываем попап только для Critical или если DND выключен
            if (npRoot.dndActive && notif.urgency !== NotificationUrgency.Critical) {
                return
            }
            npRoot.enqueue(notif)
        }
    }

    // ── Попапы (статически объявленные, управляются через slots) ──────────
    // Repeater создаёт maxVisible PopupWindow-ов, каждый биндится на слот
    // ПРИМЕЧАНИЕ: PopupWindow должен быть top-level объектом в QS.
    // Размещаем их как дочерние элементы bar (PanelWindow) через anchor.window.
    // anchor.window пробрасывается снаружи через свойство anchorWindow.
    property var anchorWindow: null

    Repeater {
        model: slots

        // Каждый делегат — один PopupWindow
        delegate: PopupWindow {
            id: popupWin

            // Данные из модели
            property var  notif:  model.notif
            property bool active: model.active
            property int  slotIndex: index

            // Привязываем к bar
            anchor.window: npRoot.anchorWindow

            // Позиция: правый верхний угол, стек сверху вниз
            // ПРИМЕЧАНИЕ: anchor.rect — позиция относительно anchor.window
            // index=0 самый верхний, index=1 ниже
            anchor.rect.x: npRoot.anchorWindow
                ? npRoot.anchorWindow.width - npRoot.popupWidth - npRoot.rightOffset
                : 0
            anchor.rect.y: npRoot.topOffset + index * 120

            implicitWidth:  npRoot.popupWidth
            implicitHeight: popupContent.implicitHeight + 2

            visible: active && notif !== null
            color: "transparent"

            // ── Автозакрытие ──────────────────────────────────────────────
            Timer {
                id: autoTimer
                interval: npRoot.autoCloseMs
                running: popupWin.visible
                repeat: false
                onTriggered: {
                    if (popupWin.notif) popupWin.notif.expire()
                    npRoot.onSlotClosed(popupWin.slotIndex)
                }
            }

            // ── Содержимое ────────────────────────────────────────────────
            Rectangle {
                id: popupContent
                anchors.fill: parent
                implicitHeight: contentLayout.implicitHeight + 20

                color: Qt.rgba(
                    Qt.color(npRoot.colSurface).r,
                    Qt.color(npRoot.colSurface).g,
                    Qt.color(npRoot.colSurface).b,
                    0.97)

                border.color: {
                    if (!popupWin.notif) return npRoot.colMuted
                    if (popupWin.notif.urgency === NotificationUrgency.Critical) return npRoot.colRed
                    if (popupWin.notif.urgency === NotificationUrgency.Low) return npRoot.colMuted
                    return npRoot.colBlue
                }
                border.width: 1

                // Анимация появления
                opacity: 0
                NumberAnimation on opacity {
                    running: popupWin.visible
                    from: 0
                    to: 1
                    duration: 160
                    easing.type: Easing.OutCubic
                }

                ColumnLayout {
                    id: contentLayout
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 10
                    }
                    spacing: 6

                    // Заголовок: иконка + приложение + заголовок + закрыть
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Иконка приложения
                        Item {
                            width: 24
                            height: 24
                            visible: popupWin.notif !== null

                            Image {
                                id: appIcon
                                anchors.fill: parent
                                source: {
                                    if (!popupWin.notif) return ""
                                    var ic = popupWin.notif.appIcon || ""
                                    if (ic === "") return ""
                                    if (ic.startsWith("/")) return "file://" + ic
                                    return "image://icon/" + ic
                                }
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                            }

                            // Fallback
                            Rectangle {
                                anchors.fill: parent
                                visible: !appIcon.visible
                                color: Qt.rgba(0.37, 0.51, 0.67, 0.2)

                                Text {
                                    anchors.centerIn: parent
                                    text: popupWin.notif
                                        ? (popupWin.notif.appName || "?")[0].toUpperCase()
                                        : "?"
                                    font.pixelSize: npRoot.fontSize - 4
                                    font.family: npRoot.fontFamily
                                    font.bold: true
                                    color: npRoot.colLBlue
                                }
                            }
                        }

                        // Текст
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: popupWin.notif ? (popupWin.notif.appName || "") : ""
                                font.pixelSize: npRoot.fontSize - 5
                                font.family: npRoot.fontFamily
                                color: npRoot.colMuted
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: popupWin.notif ? (popupWin.notif.summary || "") : ""
                                font.pixelSize: npRoot.fontSize - 2
                                font.family: npRoot.fontFamily
                                font.bold: true
                                color: npRoot.colFg
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Закрыть
                        Text {
                            text: "✕"
                            font.pixelSize: npRoot.fontSize - 4
                            font.family: npRoot.fontFamily
                            color: closeMa.containsMouse ? npRoot.colFg : npRoot.colMuted

                            MouseArea {
                                id: closeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    autoTimer.stop()
                                    if (popupWin.notif) popupWin.notif.dismiss()
                                    npRoot.onSlotClosed(popupWin.slotIndex)
                                }
                            }
                        }
                    }

                    // Тело
                    Text {
                        visible: popupWin.notif !== null && popupWin.notif.body !== ""
                        text: popupWin.notif ? (popupWin.notif.body || "") : ""
                        Layout.fillWidth: true
                        font.pixelSize: npRoot.fontSize - 4
                        font.family: npRoot.fontFamily
                        color: npRoot.colFg
                        opacity: 0.85
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    // Действия
                    // ПРИМЕЧАНИЕ: NotificationAction не имеет метода invoke().
                    // Правильный вызов: notification.sendActionInvoked(action.identifier)
                    // Ref: https://quickshell.org/docs/v0.2.1/types/Quickshell.Services.Notifications/Notification/
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: popupWin.notif !== null
                            && popupWin.notif.actions !== undefined
                            && popupWin.notif.actions.length > 0

                        Repeater {
                            model: popupWin.notif ? popupWin.notif.actions : []

                            delegate: Item {
                                required property var modelData
                                Layout.fillWidth: true
                                height: 22

                                Rectangle {
                                    anchors.fill: parent
                                    color: actMa.containsMouse
                                        ? Qt.rgba(0.37, 0.51, 0.67, 0.25)
                                        : Qt.rgba(0.37, 0.51, 0.67, 0.10)
                                    border.color: npRoot.colBlue
                                    border.width: 1
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label || modelData.identifier || ""
                                    font.pixelSize: npRoot.fontSize - 5
                                    font.family: npRoot.fontFamily
                                    color: npRoot.colLBlue
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: actMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        autoTimer.stop()
                                        if (popupWin.notif) {
                                            popupWin.notif.sendActionInvoked(modelData.identifier)
                                        }
                                        npRoot.onSlotClosed(popupWin.slotIndex)
                                    }
                                }
                            }
                        }
                    }

                    // Прогресс-бар таймера
                    Rectangle {
                        Layout.fillWidth: true
                        height: 2
                        color: npRoot.colMuted
                        opacity: 0.3

                        property real elapsed: 0

                        Timer {
                            interval: 80
                            running: autoTimer.running
                            repeat: true
                            onTriggered: parent.elapsed = Math.min(parent.elapsed + 80, npRoot.autoCloseMs)
                        }

                        onVisibleChanged: if (!visible) elapsed = 0

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: parent.width * (1.0 - parent.elapsed / npRoot.autoCloseMs)
                            color: popupWin.notif && popupWin.notif.urgency === NotificationUrgency.Critical
                                ? npRoot.colRed
                                : npRoot.colCyan
                        }
                    }

                    Item { height: 2 }
                }

                // Hover — пауза таймера
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: autoTimer.running = false
                    onExited: autoTimer.running = popupWin.visible
                    z: -1
                }
            }
        }
    }
}
