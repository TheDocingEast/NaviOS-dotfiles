// modules/NotificationPopup.qml
// Сервисный компонент — принимает уведомления, управляет историей и очередью.
// PopupWindow-ы объявляются СНАРУЖИ (в shell.qml) и подключаются через API:
//
//   API свойства:
//     property var    history       — ListModel уведомлений (read-only alias)
//     property int    unreadCount   — непрочитанных (обновляется через signal)
//     property bool   dndActive     — Do Not Disturb
//
//   API функции:
//     function markAllRead()
//     function clearHistory()
//     function dismissSlot(index)   — закрыть слот вручную (вызывать из popup)
//
//   API сигналы:
//     signal slotActivated(int index, var notif)   — показать popup[index]
//     signal slotDeactivated(int index)            — скрыть popup[index]
//
// Использование в shell.qml:
//   NotificationPopup { id: notifPopup; anchorWindow: bar }
//   // + статически объявленные NotifPopupWindow_0, NotifPopupWindow_1

import QtQuick
import QtQuick.Layouts
import Quickshell
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
    property int autoCloseMs:  4500
    property int maxVisible:   2
    property int popupWidth:   340
    property int topOffset:    58
    property int rightOffset:  12

    // ── DND ───────────────────────────────────────────────────────────────
    property bool dndActive: false

    // ── Ссылка на родительское окно для якорения попапов ─────────────────
    property var anchorWindow: null

    // ── Сигналы для управления внешними PopupWindow ───────────────────────
    signal slotActivated(int slotIdx, var notif)
    signal slotDeactivated(int slotIdx)

    // ── История ───────────────────────────────────────────────────────────
    ListModel { id: historyModel }

    readonly property alias history: historyModel

    // unreadCount — обновляется через счётчик, чтобы избежать polling в binding
    property int unreadCount: 0

    function _recountUnread() {
        var n = 0
        for (var i = 0; i < historyModel.count; i++) {
            if (!historyModel.get(i).read) n++
        }
        unreadCount = n
    }

    function markAllRead() {
        for (var i = 0; i < historyModel.count; i++) {
            historyModel.setProperty(i, "read", true)
        }
        _recountUnread()
    }

    function clearHistory() {
        // Деактивируем все слоты
        for (var i = 0; i < _slotNotifs.length; i++) {
            if (_slotActive[i]) {
                _slotActive[i] = false
                _slotNotifs[i] = null
                slotDeactivated(i)
            }
        }
        _pendingQueue = []
        historyModel.clear()
        unreadCount = 0
    }

    // ── Внутреннее состояние слотов ───────────────────────────────────────
    property var _slotActive: [false, false]
    property var _slotNotifs: [null, null]
    property var _pendingQueue: []

    // Таймеры автозакрытия на уровне сервиса (не зависят от вьюх)
    Timer { id: _closeTimer0; interval: npRoot.autoCloseMs; repeat: false; onTriggered: npRoot.dismissSlot(0) }
    Timer { id: _closeTimer1; interval: npRoot.autoCloseMs; repeat: false; onTriggered: npRoot.dismissSlot(1) }

    function _slotTimer(idx) {
        return idx === 0 ? _closeTimer0 : _closeTimer1
    }

    function _findFreeSlot() {
        for (var i = 0; i < maxVisible; i++) {
            if (!_slotActive[i]) return i
        }
        return -1
    }

    function _enqueue(notif) {
        var slot = _findFreeSlot()
        if (slot >= 0) {
            _activateSlot(slot, notif)
        } else {
            var q = _pendingQueue.slice()
            q.push(notif)
            _pendingQueue = q
        }
    }

    function _activateSlot(idx, notif) {
        var active = _slotActive.slice()
        var notifs = _slotNotifs.slice()
        active[idx] = true
        notifs[idx] = notif
        _slotActive = active
        _slotNotifs = notifs
        _slotTimer(idx).start()
        slotActivated(idx, notif)
    }

    // Публичный метод — вызывается из PopupWindow при закрытии
    function dismissSlot(idx) {
        if (!_slotActive[idx]) return     // guard — уже закрыт
        _slotTimer(idx).stop()

        var active = _slotActive.slice()
        var notifs = _slotNotifs.slice()
        active[idx] = false
        notifs[idx] = null
        _slotActive = active
        _slotNotifs = notifs
        slotDeactivated(idx)

        // Забираем следующее из очереди
        if (_pendingQueue.length > 0) {
            var q = _pendingQueue.slice()
            var next = q.shift()
            _pendingQueue = q
            _activateSlot(idx, next)
        }
    }

    // Геттер для notif в слоте (используется из внешних попапов)
    function getSlotNotif(idx) {
        return _slotNotifs[idx] || null
    }

    function isSlotActive(idx) {
        return _slotActive[idx] || false
    }

    // ── NotificationServer ────────────────────────────────────────────────
    NotificationServer {
        id: notifServer
        // actionsSupported: true позволяет приложениям слать action-кнопки
        actionsSupported: true
        keepOnReload: true

        onNotification: function(notif) {
            // Копируем свойства в plain JS-объект — Notification QObject может быть
            // уничтожен после выхода из обработчика, и его свойства станут недоступны.
            var n = {
                appName: notif.appName,
                appIcon: notif.appIcon,
                summary: notif.summary,
                body: notif.body,
                urgency: notif.urgency,
                image: notif.image,
                actions: notif.actions ? notif.actions.map(function(a) {
                    return { identifier: a.identifier, label: a.label };
                }) : [],
                dismiss: function() { notif.dismiss(); },
                expire: function() { notif.expire(); },
                sendActionInvoked: function(id) { notif.sendActionInvoked(id); }
            }
            historyModel.insert(0, { notif: n, read: false })
            npRoot._recountUnread()

            if (npRoot.dndActive && notif.urgency !== NotificationUrgency.Critical) {
                return
            }
            npRoot._enqueue(n)
        }
    }
}
