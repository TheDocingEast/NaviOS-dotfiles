import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Niri 0.1
import qs.modules
import qs.services

ShellRoot {
    id: root

    // ── Тема (Nord) ───────────────────────────────────────────────────────────
    property color colBg:        "#2e3440"
    property color colFg:        "#e5e9f0"
    property color colSurface:   "#3b4252"
    property color colAccent:    "#d8dee9"
    property color colMuted:     "#4c566a"
    property color colCyan:      "#8fbcbb"
    property color colPurple:    "#ad8ee6"
    property color colRed:       "#bf616a"
    property color colYellow:    "#ebcb8b"
    property color colBlue:      "#5e81ac"
    property color colLightBlue: "#81a1c1"
    property color colGreen:     "#a3be8c"
    property color colBrown:     "#b48ead"

    property string fontFamily: "Monaspace Krypton Medium"
    property int    fontSize:   16

    // ── Niri IPC ──────────────────────────────────────────────────────────────
    Niri {
        id: niri
        Component.onCompleted: connect()
        onErrorOccurred: function(error) {
            console.error("Niri IPC error:", error)
        }
    }

    // ── Активное окно и раскладка из niri ────────────────────────────────────
    readonly property string activeWindow:    niri.focusedWindow?.title  ?? ""
    readonly property string activeWindowApp: niri.focusedWindow?.appId  ?? ""

    // Раскладка — через sendRawAction + rawEventReceived
    // niri шлёт KeyboardLayoutsChanged / KeyboardLayoutChanged в event stream
    property string keyboardLayout: "EN"

    // Раскладка — событие rawEventReceived + poll при старте
    Connections {
        target: niri
        function onRawEventReceived(event) {
            if (event.hasOwnProperty("KeyboardLayoutChanged")
             || event.hasOwnProperty("KeyboardLayoutsChanged")) {
                layoutProc.running = false
                layoutProc.running = true
            }
        }
    }

    Process {
        id: layoutProc
        command: ["niri", "msg", "-j", "keyboard-layouts"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                if (!data || !data.trim()) return
                try {
                    var obj = JSON.parse(data.trim())
                    var kl    = obj["keyboard_layouts"] ?? obj
                    var names = kl["names"] ?? []
                    var idx   = kl["current_idx"] ?? 0
                    var name  = (names[idx] ?? "").toLowerCase()
                    root.keyboardLayout = (name.indexOf("russian") !== -1 || name === "ru") ? "RU" : "EN"
                } catch(e) {
                    console.warn("keyboard-layouts parse error:", e)
                }
            }
        }
    }

    // ── Системное состояние ───────────────────────────────────────────────────
    property int    cpuUsage:    0
    property int    memUsage:    0
    property int    diskUsage:   0
    property int    gpuUsage:    0
    property string networkSSID: ""
    property string networkType: ""
    property string networkIP:   ""
    property bool   networkConnected: false

    property var lastCpuIdle:  0
    property var lastCpuTotal: 0

    QtObject {
        id: volume
        property int level: 50
        onLevelChanged: {
            volumeSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", level + "%"]
            volumeSetProc.running = true
        }
    }

    // ── Процессы опроса ───────────────────────────────────────────────────────
    Process {
        id: cpuProc
        command: ["cat", "/proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data || !data.startsWith("cpu ")) return
                var p = data.trim().split(/\s+/)
                var user = parseInt(p[1])||0, nice = parseInt(p[2])||0
                var sys  = parseInt(p[3])||0, idle = parseInt(p[4])||0
                var iow  = parseInt(p[5])||0, irq  = parseInt(p[6])||0
                var sirq = parseInt(p[7])||0
                var total = user+nice+sys+idle+iow+irq+sirq
                var idleT = idle+iow
                if (root.lastCpuTotal > 0) {
                    var td = total - root.lastCpuTotal
                    var id = idleT - root.lastCpuIdle
                    if (td > 0) root.cpuUsage = Math.round(100*(td-id)/td)
                }
                root.lastCpuTotal = total; root.lastCpuIdle = idleT
            }
        }
    }

    Process {
        id: memProc
        command: ["cat", "/proc/meminfo"]
        stdout: SplitParser {
            property int memTotal: 0
            onRead: data => {
                if (!data) return
                if (data.startsWith("MemTotal:"))
                    memTotal = parseInt(data.split(/\s+/)[1]) || 1
                else if (data.startsWith("MemAvailable:")) {
                    var avail = parseInt(data.split(/\s+/)[1]) || 0
                    if (memTotal > 0)
                        root.memUsage = Math.round(100*(memTotal-avail)/memTotal)
                }
            }
        }
    }

    Process {
        id: diskProc
        command: ["df", "--output=pcent", "/"]
        stdout: SplitParser {
            onRead: data => {
                var v = parseInt(data.replace('%','').trim())
                if (!isNaN(v)) root.diskUsage = v
            }
        }
    }

    Process {
        id: gpuProc
        command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits"]
        stdout: SplitParser {
            onRead: data => { if (data && data.trim()) root.gpuUsage = parseInt(data.trim())||0 }
        }
    }

    Process {
        id: volGetProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                var m = data.match(/Volume:\s*([\d.]+)/)
                if (m) volume.level = Math.round(parseFloat(m[1])*100)
            }
        }
    }

    Process { id: volumeSetProc }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev | grep ':connected'"]
        stdout: SplitParser {
            onRead: data => {
                if (!data || !data.trim()) { root.networkConnected = false; return }
                var parts = data.trim().split(':')
                if (parts.length >= 4 && (parts[1]==='ethernet'||parts[1]==='wifi') && parts[2]==='connected') {
                    root.networkConnected = true
                    root.networkType = parts[1]
                    if (parts[1]==='ethernet') ipProc.running = true
                    else root.networkSSID = parts[3]
                }
            }
        }
    }

    Process {
        id: ipProc
        command: ["sh", "-c", "hostname -i | awk '{print $1}'"]
        stdout: SplitParser {
            onRead: data => { if (data.trim()) root.networkIP = data.trim() }
        }
    }

    // ── Таймеры ───────────────────────────────────────────────────────────────
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            cpuProc.running    = true
            memProc.running    = true
            gpuProc.running    = true
            diskProc.running   = true
            volGetProc.running = true
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: layoutProc.running = true
    }

    Timer {
        interval: 3000; running: true; repeat: true
        onTriggered: netProc.running = true
    }

    Component.onCompleted: layoutProc.running = true

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // ── NotifCard — визуальная карточка уведомления ─────────────────────────
    // Используется в статических PopupWindow (notifWin0, notifWin1)
    component NotifCard: Rectangle {
        id: cardRoot
        property var  notif:        null
        property var  service:      null   // ссылка на NotificationPopup
        property int  slotIndex:    0
        property int  autoCloseMs:  4500
        property bool popupVisible: false
        property bool replyVisible: false
        onReplyVisibleChanged: if (replyVisible) Qt.callLater(function() { if (replyInput) replyInput.forceActiveFocus() })

        implicitHeight: cardLayout.implicitHeight + 20
        color: service ? Qt.rgba(
            Qt.color(service.colSurface).r,
            Qt.color(service.colSurface).g,
            Qt.color(service.colSurface).b,
            0.97) : "#3b4252"

        border.color: {
            if (!notif || !service) return service ? service.colMuted : "#4c566a"
            if (notif.urgency === NotificationUrgency.Critical) return service.colRed
            if (notif.urgency === NotificationUrgency.Low)      return service.colMuted
            return service.colBlue
        }
        border.width: 1

        // Анимация появления
        opacity: 0
        NumberAnimation on opacity {
            running: popupVisible && notif !== null
            from: 0; to: 1
            duration: 160; easing.type: Easing.OutCubic
        }

        // ── Автозакрытие (таймер на уровне сервиса, не во вьюхе) ────────
        // cardAutoTimer используется только для прогресс-бара.
        Timer {
            id: cardAutoTimer
            interval: cardRoot.autoCloseMs
            running: cardRoot.popupVisible && cardRoot.notif !== null
            repeat: false
        }

        // ── Прогресс-бар таймера ──────────────────────────────────────────
        property real timerElapsed: 0
        Timer {
            interval: 80
            running: cardAutoTimer.running
            repeat: true
            onTriggered: cardRoot.timerElapsed = Math.min(cardRoot.timerElapsed + 80, cardRoot.autoCloseMs)
        }
        onPopupVisibleChanged: if (!popupVisible) timerElapsed = 0

        // ── Reply action ───────────────────────────────────────────────
        function _sendReply(text) {
            if (!cardRoot.notif) return
            var replyId = null
            var acts = cardRoot.notif.actions
            if (acts) {
                for (var i = 0; i < acts.length; i++) {
                    var id = acts[i].identifier
                    if (id === "mailReply" || id === "Reply" || id === "reply" || id === "INLINE_REPLY") {
                        replyId = id
                        break
                    }
                }
            }
            if (replyId)
                cardRoot.notif.sendActionInvoked(replyId)
            if (cardRoot.service)
                cardRoot.service.dismissSlot(cardRoot.slotIndex)
            cardRoot.replyVisible = false
        }

        // Hover — пауза таймера сервиса
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: {
                cardAutoTimer.running = false
                if (cardRoot.service)
                    cardRoot.service._slotTimer(cardRoot.slotIndex).running = false
            }
            onExited: {
                var shouldRun = cardRoot.popupVisible && cardRoot.notif !== null
                cardAutoTimer.running = shouldRun
                if (cardRoot.service)
                    cardRoot.service._slotTimer(cardRoot.slotIndex).running = shouldRun
            }
            z: -1
        }

        ColumnLayout {
            id: cardLayout
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 6

            // ── Заголовок: иконка + имя + summary + закрыть ──────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Иконка
                Item {
                    width: 24; height: 24
                    visible: cardRoot.notif !== null
                    Image {
                        id: cardIcon
                        anchors.fill: parent
                        source: {
                            if (!cardRoot.notif) return ""
                            var ic = cardRoot.notif.appIcon || ""
                            if (!ic) return ""
                            if (ic.startsWith("/")) return "file://" + ic
                            return "image://icon/" + ic
                        }
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: cardRoot.notif !== null && !cardIcon.visible
                        color: Qt.rgba(0.37, 0.51, 0.67, 0.2)
                        Text {
                            anchors.centerIn: parent
                            text: cardRoot.notif ? (cardRoot.notif.appName || "?")[0].toUpperCase() : "?"
                            font.pixelSize: cardRoot.service ? cardRoot.service.fontSize - 4 : 12
                            font.family:    cardRoot.service ? cardRoot.service.fontFamily : ""
                            font.bold: true
                            color: cardRoot.service ? cardRoot.service.colLBlue : "#81a1c1"
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Text {
                        text: cardRoot.notif ? (cardRoot.notif.appName || "") : ""
                        font.pixelSize: cardRoot.service ? cardRoot.service.fontSize - 5 : 11
                        font.family:    cardRoot.service ? cardRoot.service.fontFamily : ""
                        color: cardRoot.service ? cardRoot.service.colMuted : "#4c566a"
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Text {
                        text: cardRoot.notif ? (cardRoot.notif.summary || "") : ""
                        font.pixelSize: cardRoot.service ? cardRoot.service.fontSize - 2 : 14
                        font.family:    cardRoot.service ? cardRoot.service.fontFamily : ""
                        font.bold: true
                        color: cardRoot.service ? cardRoot.service.colFg : "#d8dee9"
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }

                // Закрыть
                Item {
                    width: 20; height: 20
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: cardRoot.service ? cardRoot.service.fontSize - 4 : 12
                        font.family:    cardRoot.service ? cardRoot.service.fontFamily : ""
                        color: closeMa.containsMouse
                            ? (cardRoot.service ? cardRoot.service.colFg : "#d8dee9")
                            : (cardRoot.service ? cardRoot.service.colMuted : "#4c566a")
                    }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (cardRoot.notif) cardRoot.notif.dismiss()
                            if (cardRoot.service) cardRoot.service.dismissSlot(cardRoot.slotIndex)
                        }
                    }
                }
            }

            // ── Тело ─────────────────────────────────────────────────────
            Text {
                visible: cardRoot.notif !== null && (cardRoot.notif.body || "") !== ""
                text: cardRoot.notif ? (cardRoot.notif.body || "") : ""
                Layout.fillWidth: true
                font.pixelSize: cardRoot.service ? cardRoot.service.fontSize - 4 : 12
                font.family:    cardRoot.service ? cardRoot.service.fontFamily : ""
                color: cardRoot.service ? cardRoot.service.colFg : "#d8dee9"
                opacity: 0.85
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            // ── Действия (от приложения) ──────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: cardRoot.notif !== null
                    && cardRoot.notif.actions !== undefined
                    && cardRoot.notif.actions.length > 0

                Repeater {
                    model: cardRoot.notif ? cardRoot.notif.actions : []
                    delegate: Item {
                        required property var modelData
                        Layout.fillWidth: true; height: 22
                        Rectangle {
                            anchors.fill: parent
                            color: actMa2.containsMouse
                                ? Qt.rgba(0.37, 0.51, 0.67, 0.25)
                                : Qt.rgba(0.37, 0.51, 0.67, 0.10)
                            border.color: cardRoot.service ? cardRoot.service.colBlue : "#5e81ac"
                            border.width: 1
                        }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label || modelData.identifier || ""
                            font.pixelSize: cardRoot.service ? cardRoot.service.fontSize - 5 : 11
                            font.family:    cardRoot.service ? cardRoot.service.fontFamily : ""
                            color: cardRoot.service ? cardRoot.service.colLBlue : "#81a1c1"
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: actMa2
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (cardRoot.notif)
                                    cardRoot.notif.sendActionInvoked(modelData.identifier)
                                if (cardRoot.service) cardRoot.service.dismissSlot(cardRoot.slotIndex)
                            }
                        }
                    }
                }
            }

            // ── Messenger quick actions ──────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                // Mark as read
                Item {
                    Layout.fillWidth: true; height: 22
                    Rectangle {
                        anchors.fill: parent
                        color: markReadMa.containsMouse
                            ? Qt.rgba(0.56, 0.75, 0.63, 0.20)
                            : Qt.rgba(0.56, 0.75, 0.63, 0.06)
                        border.color: cardRoot.service ? cardRoot.service.colGreen : "#a3be8c"
                        border.width: 1
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "󰄳 Mark as read"
                        font.pixelSize: cardRoot.service ? cardRoot.service.fontSize - 5 : 11
                        font.family:    cardRoot.service ? cardRoot.service.fontFamily : ""
                        color: cardRoot.service ? cardRoot.service.colGreen : "#a3be8c"
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: markReadMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (cardRoot.notif) cardRoot.notif.dismiss()
                            if (cardRoot.service) cardRoot.service.dismissSlot(cardRoot.slotIndex)
                        }
                    }
                }

                // Reply here
                Item {
                    Layout.fillWidth: true; height: 22
                    Rectangle {
                        anchors.fill: parent
                        color: replyBtnMa.containsMouse
                            ? Qt.rgba(0.56, 0.69, 0.82, 0.20)
                            : Qt.rgba(0.56, 0.69, 0.82, 0.06)
                        border.color: cardRoot.service ? cardRoot.service.colCyan : "#8fbcbb"
                        border.width: 1
                    }
                    Text {
                        anchors.centerIn: parent
                        text: cardRoot.replyVisible ? "✕ Cancel" : "󰑗 Reply here"
                        font.pixelSize: cardRoot.service ? cardRoot.service.fontSize - 5 : 11
                        font.family:    cardRoot.service ? cardRoot.service.fontFamily : ""
                        color: cardRoot.service ? cardRoot.service.colCyan : "#8fbcbb"
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: replyBtnMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cardRoot.replyVisible = !cardRoot.replyVisible
                    }
                }
            }

            // ── Reply input ──────────────────────────────────────────────
            Rectangle {
                visible: cardRoot.replyVisible
                Layout.fillWidth: true
                implicitHeight: replyRow.implicitHeight + 8
                color: Qt.rgba(0.18, 0.21, 0.25, 0.6)
                border.color: cardRoot.service ? cardRoot.service.colMuted : "#4c566a"
                border.width: 1

                RowLayout {
                    id: replyRow
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    TextInput {
                        id: replyInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        font.pixelSize: cardRoot.service ? cardRoot.service.fontSize - 4 : 12
                        font.family:    cardRoot.service ? cardRoot.service.fontFamily : ""
                        color: cardRoot.service ? cardRoot.service.colFg : "#d8dee9"
                        clip: true
                        focus: true
                        onAccepted: {
                            if (text.trim() !== "") {
                                cardRoot._sendReply(text.trim())
                                text = ""
                            }
                        }
                    }

                    Item {
                        implicitWidth: sendTxt.implicitWidth
                        implicitHeight: sendTxt.implicitHeight
                        Text {
                            id: sendTxt
                            text: ""
                            font.pixelSize: cardRoot.service ? cardRoot.service.fontSize : 14
                            font.family:    cardRoot.service ? cardRoot.service.fontFamily : ""
                            color: sendMa.containsMouse
                                ? (cardRoot.service ? cardRoot.service.colCyan : "#8fbcbb")
                                : (cardRoot.service ? cardRoot.service.colMuted : "#4c566a")
                        }
                        MouseArea {
                            id: sendMa
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (replyInput.text.trim() !== "") {
                                    cardRoot._sendReply(replyInput.text.trim())
                                    replyInput.text = ""
                                }
                            }
                        }
                    }
                }
            }

            // ── Таймер-полоска ────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: 2
                color: cardRoot.service ? cardRoot.service.colMuted : "#4c566a"
                opacity: 0.3
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: cardRoot.autoCloseMs > 0
                        ? parent.width * (1.0 - cardRoot.timerElapsed / cardRoot.autoCloseMs)
                        : 0
                    color: (cardRoot.notif && cardRoot.notif.urgency === NotificationUrgency.Critical)
                        ? (cardRoot.service ? cardRoot.service.colRed    : "#bf616a")
                        : (cardRoot.service ? cardRoot.service.colCyan   : "#8fbcbb")
                }
            }

            Item { height: 2 }
        }
    }

    // ── BorderFillRect ────────────────────────────────────────────────────────
    component BorderFillRect: Item {
        id: bfr
        property real value:  0
        property real radius: 20
        property string label: ""
        property int thick: 4
        property real animValue: 0
        readonly property color fillColor: animValue > 80 ? "#bf616a"
                                         : animValue > 55 ? "#ebcb8b" : "#8fbcbb"
        readonly property int fs: width / 4
        onValueChanged: animValue = Math.max(0, Math.min(100, value))
        Component.onCompleted: animValue = Math.max(0, Math.min(100, value))

        Canvas {
            id: canvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d"); ctx.reset()
                var t = bfr.thick, r = Math.min(bfr.radius, (width-t)/2, (height-t)/2)
                var w = width-t, h = height-t, x = t/2, y = t/2
                var perim = 2*(w-2*r)+2*(h-2*r)+2*Math.PI*r
                var filled = perim*Math.max(0,Math.min(100,bfr.animValue))/400
                function path(c) {
                    c.beginPath(); c.moveTo(w/2,y+h)
                    c.lineTo(x+r,y+h); c.arcTo(x,y+h,x,y+h-r,r)
                    c.lineTo(x,y+r);   c.arcTo(x,y,x+r,y,r)
                    c.lineTo(x+w-r,y); c.arcTo(x+w,y,x+w,y+r,r)
                    c.lineTo(x+w,y+h-r); c.arcTo(x+w,y+h,x+w-r,y+h,r)
                    c.closePath()
                }
                ctx.save(); path(ctx)
                ctx.strokeStyle="rgba(255,255,255,0.08)"; ctx.lineWidth=t; ctx.setLineDash([]); ctx.stroke(); ctx.restore()
                if (filled>0) {
                    ctx.save(); path(ctx)
                    ctx.strokeStyle=bfr.fillColor; ctx.lineWidth=t; ctx.lineCap="round"
                    ctx.setLineDash([filled,perim+1]); ctx.stroke(); ctx.restore()
                }
            }
            Connections {
                target: bfr
                function onAnimValueChanged() { canvas.requestPaint() }
                function onFillColorChanged()  { canvas.requestPaint() }
            }
        }
        ColumnLayout {
            anchors.centerIn: parent; spacing: 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: bfr.label !== ""; text: bfr.label; color: bfr.fillColor
                font { pixelSize: bfr.fs-2; family: "Monaspace Krypton Medium" }
            }
        }
        Behavior on animValue { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
    }


    // ── Notification service — SINGLETON at ShellRoot level ──────────────────
    // NotificationServer регистрирует D-Bus сервис. Должен быть ОДИН экземпляр.
    // Размещаем вне Variants, чтобы он не дублировался на каждом мониторе.
    NotificationPopup {
        id: notifPopup
        fontFamily: root.fontFamily; fontSize: root.fontSize
        colBg: root.colBg; colFg: root.colFg; colSurface: root.colSurface
        colMuted: root.colMuted; colCyan: root.colCyan; colBlue: root.colBlue
        colLBlue: root.colLightBlue; colGreen: root.colGreen
        colRed: root.colRed; colYellow: root.colYellow
    }

    // ── Notification popup windows ────────────────────────────────────
    // PopupWindow несовместим с PanelWindow (layer-surface) на Niri —
    // xdg-popup требует xdg_surface родителя. Используем PanelWindow
    // с aboveWindows: true (LayerTop) и top-right anchors.
    // Screen выбирается динамически — на каком экране курсор.

    function _cursorScreen() {
        if (!Quickshell.cursor || Quickshell.screens.length === 0)
            return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        var cp = Quickshell.cursor.position
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var s = Quickshell.screens[i], g = s.geometry
            if (cp.x >= g.x && cp.x < g.x + g.width && cp.y >= g.y && cp.y < g.y + g.height)
                return s
        }
        return Quickshell.screens[0]
    }

    Connections {
        target: notifPopup
        function onSlotActivated(slotIdx, n) {
            var sc = _cursorScreen()
            if (slotIdx === 0) {
                notifWin0.screen = sc
                notifWin0.currentNotif = n
                notifWin0.visible = true
            } else if (slotIdx === 1) {
                notifWin1.screen = sc
                notifWin1.currentNotif = n
                notifWin1.visible = true
            }
        }
        function onSlotDeactivated(slotIdx) {
            if (slotIdx === 0) notifWin0.visible = false
            else if (slotIdx === 1) notifWin1.visible = false
        }
    }

    PanelWindow {
        id: notifWin0
        property var currentNotif: null
        screen: _cursorScreen()
        visible: false
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: notifCard0.replyVisible
        anchors.top: true
        anchors.right: true
        margins.top: notifPopup.topOffset
        margins.right: notifPopup.rightOffset
        implicitWidth: notifPopup.popupWidth
        implicitHeight: notifCard0.implicitHeight + 2

        NotifCard {
            id: notifCard0
            anchors.fill: parent
            notif: notifWin0.currentNotif
            service: notifPopup
            slotIndex: 0
            autoCloseMs: notifPopup.autoCloseMs
            popupVisible: notifWin0.visible
        }
    }

    PanelWindow {
        id: notifWin1
        property var currentNotif: null
        screen: _cursorScreen()
        visible: false
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        aboveWindows: true
        focusable: notifCard1.replyVisible
        anchors.top: true
        anchors.right: true
        margins.top: notifPopup.topOffset + 130
        margins.right: notifPopup.rightOffset
        implicitWidth: notifPopup.popupWidth
        implicitHeight: notifCard1.implicitHeight + 2

        NotifCard {
            id: notifCard1
            anchors.fill: parent
            notif: notifWin1.currentNotif
            service: notifPopup
            slotIndex: 1
            autoCloseMs: notifPopup.autoCloseMs
            popupVisible: notifWin1.visible
        }
    }

    // ── Бар на каждом мониторе ────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            property var modelData
            screen: modelData
            implicitHeight: 50
            color: root.colBg
            anchors { top: true; left: true; right: true }

            ControlMenu {
                id: controlMenu
                fontFamily: root.fontFamily; fontSize: root.fontSize
                colBg: root.colBg; colFg: root.colFg; colSurface: root.colSurface
                colMuted: root.colMuted; colCyan: root.colCyan; colBlue: root.colBlue
                colLBlue: root.colLightBlue; colGreen: root.colGreen
                colRed: root.colRed; colYellow: root.colYellow
                netConnected: root.networkConnected; netType: root.networkType
                netSSID: root.networkSSID; netIP: root.networkIP
                notifService: notifPopup
            }


            CalendarModule {
                id: calendarPopup; anchor.window: bar
                anchor.rect.x: 0; anchor.rect.y: bar.implicitHeight
                fontFamily: root.fontFamily; fontSize: root.fontSize
                colBg: root.colBg; colFg: root.colFg; colMuted: root.colMuted
                colCyan: root.colCyan; colBlue: root.colBlue
                colLBlue: root.colLightBlue; colGreen: root.colGreen
                colRed: root.colRed; colYellow: root.colYellow
                weatherService: Weather
            }

            WifiModule {
                id: wifiPopup; anchor.window: bar
                anchor.rect.x: bar.width-width-8; anchor.rect.y: bar.implicitHeight
                fontFamily: root.fontFamily; fontSize: root.fontSize
                colBg: root.colBg; colFg: root.colFg; colMuted: root.colMuted
                colCyan: root.colCyan; colBlue: root.colBlue
                colLBlue: root.colLightBlue; colGreen: root.colGreen
                colRed: root.colRed; colYellow: root.colYellow
                netConnected: root.networkConnected; netType: root.networkType
                netSSID: root.networkSSID; netIP: root.networkIP
            }

            SoundModule {
                id: soundPopup; anchor.window: bar
                anchor.rect.x: bar.width-width-8; anchor.rect.y: bar.implicitHeight
                fontFamily: root.fontFamily; fontSize: root.fontSize
                colBg: root.colBg; colFg: root.colFg; colMuted: root.colMuted
                colCyan: root.colCyan; colBlue: root.colBlue
                colLBlue: root.colLightBlue; colGreen: root.colGreen
                colRed: root.colRed; colYellow: root.colYellow
                volLevel: volume.level
                onVolChanged: lvl => { volume.level = lvl }
                barHovered: volHover.containsMouse
            }

            VoicerWindow {
                id: voicerPopup; anchor.window: bar
                anchor.rect.x: bar.width-width-8; anchor.rect.y: bar.implicitHeight
                fontFamily: root.fontFamily; fontSize: root.fontSize
                colBg: root.colBg; colFg: root.colFg; colMuted: root.colMuted
                colCyan: root.colCyan; colBlue: root.colBlue
                colLBlue: root.colLightBlue; colGreen: root.colGreen
                colRed: root.colRed; colYellow: root.colYellow
            }

            Rectangle {
                anchors.fill: parent; color: root.colBg

                RowLayout {
                    anchors.fill: parent; spacing: 0

                    // ── LEFT ──────────────────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: parent.height
                        color: "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 6; spacing: 2
                            Text {
                                text: "✦"
                                color: ctrlMa.containsMouse ? root.colLightBlue : root.colCyan
                                font.pixelSize: 22; font.family: root.fontFamily
                                Behavior on color { ColorAnimation { duration: 120 } }
                                MouseArea {
                                    id: ctrlMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controlMenu.toggle()
                                }
                            }
                            Text {
                                visible: notifPopup.unreadCount > 0
                                text: notifPopup.unreadCount > 99 ? "󰂚 99+" : "󰂚 " + notifPopup.unreadCount
                                color: notifPopup.unreadCount > 0 ? root.colCyan : root.colMuted
                                font.pixelSize: root.fontSize - 2; font.family: root.fontFamily; font.bold: true
                                Layout.leftMargin: 4
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: controlMenu.toggle()
                                }
                            }
                            ColumnLayout {
                                Layout.preferredHeight: parent.height; spacing: 0
                                Text {
                                    text: Qt.formatDateTime(clock.date, "ddd/dd.MM.yy")
                                    color: clockMa.containsMouse ? root.colLightBlue : root.colFg
                                    font.pixelSize: root.fontSize-4; font.family: root.fontFamily; font.bold: true
                                    Layout.leftMargin: 8; elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                                Text {
                                    text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                                    color: clockMa.containsMouse ? root.colLightBlue : root.colFg
                                    font.pixelSize: root.fontSize; font.family: root.fontFamily; font.bold: true
                                    Layout.leftMargin: 8; elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                                MouseArea {
                                    id: clockMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendarPopup.visible = !calendarPopup.visible
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.preferredHeight: parent.height; spacing: 0
                                Text {
                                    text: root.activeWindowApp; Layout.fillWidth: true
                                    color: root.colBlue
                                    font.pixelSize: root.fontSize-4; font.family: root.fontFamily; font.bold: true
                                    Layout.leftMargin: 8; elide: Text.ElideRight
                                }
                                Text {
                                    text: root.activeWindow; Layout.fillWidth: true
                                    color: root.colLightBlue
                                    font.pixelSize: root.fontSize; font.family: root.fontFamily; font.bold: true
                                    Layout.leftMargin: 8; elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // ── CENTER: Workspaces ─────────────────────────────────────
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: parent.height
                        Layout.preferredWidth: 270
                        color: "transparent"
                        Workspaces {
                            anchors.centerIn: parent
                            screenName:   bar.screen ? bar.screen.name : ""
                            niriInstance: niri
                            fontFamily:   root.fontFamily; fontSize:    root.fontSize
                            colActive:    root.colLightBlue; colOccupied: root.colFg
                            colEmpty:     root.colMuted;     colBar:      root.colBlue
                            colBg:        root.colBg;        colSurface:  root.colSurface
                            colMuted:     root.colMuted
                        }
                    }

                    // ── RIGHT ─────────────────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignRight
                        Layout.preferredHeight: parent.height-6; color: "transparent"

                        RowLayout {
                            anchors.fill: parent; anchors.margins: 4; spacing: 10
                            Item { Layout.fillWidth: true }

                            // Battery
                            Text {
                                readonly property UPowerDevice bat: UPower.displayDevice
                                visible: bat.isLaptopBattery
                                text: {
                                    if (!bat.isLaptopBattery) return ""
                                    var p = Math.round(bat.percentage*100)
                                    var s = bat.state
                                    if (s===UPowerDeviceState.Charging)
                                        return (p>80?"󰂊":p>60?"󰂉":p>40?"󰂈":p>20?"󰂆":"󰢜")+" "+p+"%"
                                    if (s===UPowerDeviceState.FullyCharged) return "󰁹 "+p+"%"
                                    return (p>80?"󰂀":p>60?"󰁿":p>40?"󰁾":p>20?"󰁽":"󰁻")+" "+p+"%"
                                }
                                color: bat.percentage<=0.15 ? root.colRed
                                     : bat.percentage<=0.40 ? root.colYellow : root.colGreen
                                font.pixelSize: root.fontSize; font.family: root.fontFamily; font.bold: true
                            }

                            // Network
                            Text {
                                text: !root.networkConnected ? "󰖪 Disconnected"
                                    : root.networkType==="ethernet" ? "󰛳 "+root.networkIP
                                    : "󰖩 "+root.networkSSID
                                color: root.networkConnected ? root.colCyan : root.colRed
                                font.pixelSize: root.fontSize; font.family: root.fontFamily; font.bold: true
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: wifiPopup.visible = !wifiPopup.visible
                                }
                            }

                            BorderFillRect { width:60; height:35; radius:30; value: root.cpuUsage; label:"CPU" }
                            BorderFillRect { width:60; height:35; radius:30; value: root.memUsage; label:"RAM" }
                            BorderFillRect { width:60; height:35; radius:30; value: root.gpuUsage; label:"GPU" }

                            // Volume
                            Item {
                                implicitWidth: volTxt.implicitWidth; implicitHeight: volTxt.implicitHeight
                                Text {
                                    id: volTxt
                                    text: (volume.level===0?"󰝟":volume.level<50?"󰖀":"󰕾")+" "+volume.level+"%"
                                    color: volume.level>90?root.colRed:volume.level>50?root.colYellow:root.colCyan
                                    font.pixelSize: root.fontSize; font.family: root.fontFamily; font.bold: true
                                }
                                MouseArea {
                                    id: volHover; anchors.fill: parent; hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    onEntered: { soundPopup.visible=true; soundPopup.barHovered=true }
                                    onExited:  { soundPopup.barHovered=false }
                                    onWheel: ev => {
                                        volume.level = ev.angleDelta.y>0
                                            ? Math.min(100,volume.level+5)
                                            : Math.max(0,volume.level-5)
                                        ev.accepted=true
                                    }
                                }
                            }

                            // Keyboard layout — переключение через sendRawAction
                            Text {
                                text: "󰌌 "+root.keyboardLayout
                                color: root.colCyan
                                font.pixelSize: root.fontSize; font.family: root.fontFamily; font.bold: true
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: niri.sendRawAction({ "SwitchLayout": { "layout": "Next" } })
                                }
                            }

                            // Voice Changer
                            Text {
                                text: VoiceChangerService.vcRtActive?"󰍬":VoiceChangerService.vcBusy?"󰔟":VoiceChangerService.vcLoaded?"󰍬":"󰍭"
                                color: VoiceChangerService.vcRtActive?root.colGreen:VoiceChangerService.vcBusy?root.colYellow:VoiceChangerService.vcLoaded?root.colCyan:root.colMuted
                                font.pixelSize: root.fontSize; font.family: root.fontFamily; font.bold: true
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: voicerPopup.visible = !voicerPopup.visible
                                }
                            }

                            // Power menu
                            Item {
                                implicitWidth: pwrTxt.implicitWidth; implicitHeight: pwrTxt.implicitHeight
                                Text {
                                    id: pwrTxt; text: "⏻"
                                    color: pwrMa.containsMouse ? root.colRed : Qt.rgba(0.75,0.38,0.41,0.7)
                                    font.pixelSize: root.fontSize+2; font.family: root.fontFamily
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                                MouseArea {
                                    id: pwrMa; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: miniPowerMenu.visible = !miniPowerMenu.visible
                                }

                                PopupWindow {
                                    id: miniPowerMenu; visible: false
                                    anchor.window: bar
                                    anchor.rect.x: bar.width-width-4; anchor.rect.y: bar.implicitHeight
                                    width: 130; height: pwrCol.implicitHeight+8; color: "transparent"

                                    Rectangle {
                                        anchors.fill: parent; color: root.colBg
                                        border.color: root.colMuted; border.width: 1

                                        Column {
                                            id: pwrCol
                                            anchors { left: parent.left; right: parent.right; top: parent.top }
                                            anchors.margins: 4; anchors.topMargin: 4; spacing: 2

                                            Repeater {
                                                model: [
                                                    { icon:"󰍁", label:"Lock",
                                                      fn: ()=>Quickshell.execDetached(["loginctl","lock-session"]), danger:false },
                                                    { icon:"󰤄", label:"Suspend",
                                                      fn: ()=>Quickshell.execDetached(["systemctl","suspend"]), danger:false },
                                                    { icon:"󰒲", label:"Hibernate",
                                                      fn: ()=>Quickshell.execDetached(["systemctl","hibernate"]), danger:false },
                                                    { icon:"󰈆", label:"Logout",
                                                      fn: ()=>niri.sendRawAction({"Quit":{"skip_confirmation":true}}), danger:true },
                                                    { icon:"󰜉", label:"Reboot",
                                                      fn: ()=>Quickshell.execDetached(["systemctl","reboot"]), danger:true },
                                                    { icon:"󰐥", label:"Shutdown",
                                                      fn: ()=>Quickshell.execDetached(["systemctl","poweroff"]), danger:true }
                                                ]
                                                Rectangle {
                                                    width: pwrCol.width; height: 28
                                                    color: pma.containsMouse
                                                        ? (modelData.danger?Qt.rgba(0.75,0.38,0.41,0.2):Qt.rgba(1,1,1,0.06))
                                                        : "transparent"
                                                    Behavior on color { ColorAnimation { duration: 60 } }
                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                                                        Text { text: modelData.icon; color: modelData.danger?root.colRed:root.colFg
                                                               font { pixelSize: root.fontSize-1; family: root.fontFamily } }
                                                        Text { text: modelData.label; Layout.fillWidth: true
                                                               color: modelData.danger?root.colRed:root.colFg
                                                               font { pixelSize: root.fontSize-3; family: root.fontFamily } }
                                                    }
                                                    MouseArea {
                                                        id: pma; anchors.fill: parent; hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: { miniPowerMenu.visible=false; Qt.callLater(modelData.fn) }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
