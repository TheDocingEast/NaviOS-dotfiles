import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.modules
import qs.services

ShellRoot {
    id: root

    // ══════════════════════════════════════════════════════════════════════
    // ТЕМА (Nord palette)
    // ══════════════════════════════════════════════════════════════════════
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

    // ══════════════════════════════════════════════════════════════════════
    // СИСТЕМНОЕ СОСТОЯНИЕ
    // ══════════════════════════════════════════════════════════════════════
    property int    cpuUsage:        0
    property int    memUsage:        0
    property int    diskUsage:       0
    property int    gpuUsage:        0
    property string activeWindow:    ""
    property string activeWindowApp: ""
    property string keyboardLayout:  ""
    property string networkSSID:     ""
    property string networkType:     ""
    property string networkIP:       ""
    property bool   networkConnected: false

    property var keyboardLayouts: ({
        "Russian":      "RU",
        "English (US)": "EN"
    })

    // ── CPU delta tracking ────────────────────────────────────────────────
    property var lastCpuIdle:  0
    property var lastCpuTotal: 0

    // ── Volume (единственный источник истины) ─────────────────────────────
    QtObject {
        id: volume
        property int level: 50
        onLevelChanged: {
            volumeSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", level + "%"]
            volumeSetProc.running = true
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ПРОЦЕССЫ СБОРА ДАННЫХ
    // ══════════════════════════════════════════════════════════════════════

    // CPU — читаем /proc/stat напрямую, без shell
    Process {
        id: cpuProc
        command: ["cat", "/proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data || !data.startsWith("cpu ")) return
                var p = data.trim().split(/\s+/)
                var user    = parseInt(p[1]) || 0
                var nice    = parseInt(p[2]) || 0
                var system  = parseInt(p[3]) || 0
                var idle    = parseInt(p[4]) || 0
                var iowait  = parseInt(p[5]) || 0
                var irq     = parseInt(p[6]) || 0
                var softirq = parseInt(p[7]) || 0
                var total   = user + nice + system + idle + iowait + irq + softirq
                var idleT   = idle + iowait
                if (root.lastCpuTotal > 0) {
                    var td = total - root.lastCpuTotal
                    var id = idleT - root.lastCpuIdle
                    if (td > 0) root.cpuUsage = Math.round(100 * (td - id) / td)
                }
                root.lastCpuTotal = total
                root.lastCpuIdle  = idleT
            }
        }
    }

    // RAM — читаем /proc/meminfo напрямую
    Process {
        id: memProc
        command: ["cat", "/proc/meminfo"]
        stdout: SplitParser {
            property int memTotal: 0
            property int memAvail: 0
            onRead: data => {
                if (!data) return
                if (data.startsWith("MemTotal:")) {
                    memTotal = parseInt(data.split(/\s+/)[1]) || 1
                } else if (data.startsWith("MemAvailable:")) {
                    memAvail = parseInt(data.split(/\s+/)[1]) || 0
                    if (memTotal > 0)
                        root.memUsage = Math.round(100 * (memTotal - memAvail) / memTotal)
                }
            }
        }
    }

    // Диск — df быстро и без shell для одной точки монтирования
    Process {
        id: diskProc
        command: ["df", "--output=pcent", "/"]
        stdout: SplitParser {
            onRead: data => {
                var v = parseInt(data.replace('%', '').trim())
                if (!isNaN(v)) root.diskUsage = v
            }
        }
    }

    Process {
        id: gpuProc

        command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim())
                    gpuUsage = data.trim();
            }
        }
    }

    // Громкость — получить текущее значение
    Process {
        id: volGetProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                var m = data.match(/Volume:\s*([\d.]+)/)
                if (m) volume.level = Math.round(parseFloat(m[1]) * 100)
            }
        }
    }

    Process { id: volumeSetProc }

    // Сеть — nmcli (медленнее, реже)
    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev | grep ':connected'"]
        stdout: SplitParser {
            onRead: data => {
                if (!data || !data.trim()) {
                    root.networkConnected = false
                    root.networkSSID = ""
                    root.networkType = ""
                    return
                }
                var parts = data.trim().split(':')
                if (parts.length >= 4
                    && (parts[1] === 'ethernet' || parts[1] === 'wifi')
                    && parts[2] === 'connected') {
                    root.networkConnected = true
                    root.networkType = parts[1]
                    if (parts[1] === 'ethernet') ipProc.running = true
                    else root.networkSSID = parts[3]
                }
            }
        }
        onRunningChanged: {
            if (!running && !networkConnected) {
                // Нет строки connected — отключены
                root.networkConnected = false
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

    // Активное окно — только через Hyprland events, не по таймеру
    Process {
        id: windowProc
        command: ["sh", "-c", "hyprctl activewindow -j"]
        stdout: SplitParser {
            property string _buf: ""
            onRead: data => { _buf += data }
        }
        onRunningChanged: {
            if (!running) {
                try {
                    var w = JSON.parse(stdout._buf || "{}")
                    root.activeWindow    = w.title || ""
                    root.activeWindowApp = w.class  || ""
                } catch(e) {}
                stdout._buf = ""
            }
        }
    }

    // Клавиатурная раскладка
    Process {
        id: keyboardProc
        command: WMDetector.isI3
            ? ["xkblayout-state", "print", "%s"]
            : ["sh", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main==true) | .active_keymap'"]
        stdout: SplitParser {
            onRead: data => {
                var raw = data.trim()
                if (!raw) return
                if (WMDetector.isI3) {
                    root.keyboardLayout = ({ "us": "EN", "ru": "RU" })[raw] ?? raw.toUpperCase()
                } else {
                    root.keyboardLayout = root.keyboardLayouts[raw] ?? raw
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ТАЙМЕРЫ ОПРОСА
    // ══════════════════════════════════════════════════════════════════════

    // Быстрые метрики: CPU / RAM / Disk / Vol — раз в секунду
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running  = true
            memProc.running  = true
            gpuProc.running = true;
            diskProc.running = true
            volGetProc.running = true
        }
    }

    // Сеть — раз в 3 секунды (меняется редко)
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: netProc.running = true
    }

    // i3: раскладка по таймеру (X11 не шлёт события)
    Timer {
        interval: 500
        running: WMDetector.isI3
        repeat: true
        onTriggered: keyboardProc.running = true
    }

    // ── Hyprland events → обновление окна + раскладки ─────────────────────
    Connections {
        target: Hyprland
        enabled: WMDetector.isHyprland
        function onRawEvent(event) {
            windowProc.running   = true
            keyboardProc.running = true
        }
    }

    // ── Системные часы ────────────────────────────────────────────────────
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // ══════════════════════════════════════════════════════════════════════
    // ГЛОБАЛЬНЫЕ ХОТКЕИ
    // ══════════════════════════════════════════════════════════════════════

    // bind = SUPER, R, global, quickshell:wallpaperToggle
    GlobalShortcut {
        appid: "quickshell"
        name: "wallpaperToggle"
        description: "Toggle wallpaper selector"
        onPressed: wallpaperSelector.toggle()
    }

    // bind = SUPER, SPACE, global, quickshell:controlCentre
    // ПРИМЕЧАНИЕ: Variants создаёт отдельный ControlMenu на каждый монитор.
    // controlMenu — id доступен только внутри Variants-делегата.
    // GlobalShortcut объявлен вне Variants → прямой доступ к controlMenu невозможен.
    // Решение: шлём Hyprland-событие через IPC, bar-делегат его ловит и вызывает toggle().
    // Простой fallback — хоткей зарегистрирован, но toggle реализован через
    // onRawEvent в Connections внутри Variants (см. bar → Connections target: Hyprland).
    GlobalShortcut {
        appid: "quickshell"
        name: "controlCentre"
        description: "Toggle Control Centre"
        onPressed: Hyprland.dispatch("exec true")   // триггер — Connections onRawEvent не подходит
        // TODO: после подтверждения API Quickshell.Ipc — использовать IpcHandler для
        // межкомпонентной связи вместо Hyprland.dispatch.
        // Альтернатива: вынести ControlMenu за пределы Variants (один экземпляр).
    }

    // bind = SUPER, L, global, quickshell:lock
    GlobalShortcut {
        appid: "quickshell"
        name: "lock"
        onPressed: Quickshell.execDetached([
            "qs", "-p", Quickshell.env("HOME") + "/.config/quickshell/lockScreen"
        ])
    }

    // ══════════════════════════════════════════════════════════════════════
    // СЕРВИСЫ (синглтоны)
    // ══════════════════════════════════════════════════════════════════════

    WallpaperSelector {
        id: wallpaperSelector
        fontFamily: root.fontFamily
        fontSize: root.fontSize
        colBg: root.colBg
        colFg: root.colFg
        colMuted: root.colMuted
        colCyan: root.colCyan
        colBlue: root.colBlue
        colLBlue: root.colLightBlue
        colGreen: root.colGreen
        colRed: root.colRed
        colYellow: root.colYellow
    }

    // ══════════════════════════════════════════════════════════════════════
    // МОНИТОРЫ — бар на каждом экране
    // ══════════════════════════════════════════════════════════════════════
    Variants {
        id: barVariants
        model: Quickshell.screens

        PanelWindow {
            id: bar
            property var modelData
            screen: modelData
            implicitHeight: 50
            color: root.colBg
                        anchors {
                top: true
                left: true
                right: true
            }

            // ── Control Centre (PanelWindow, один на монитор) ────────────
            ControlMenu {
                id: controlMenu
                fontFamily: root.fontFamily
                fontSize: root.fontSize
                colBg: root.colBg
                colFg: root.colFg
                colSurface: root.colSurface
                colMuted: root.colMuted
                colCyan: root.colCyan
                colBlue: root.colBlue
                colLBlue: root.colLightBlue
                colGreen: root.colGreen
                colRed: root.colRed
                colYellow: root.colYellow
                netConnected: root.networkConnected
                netType: root.networkType
                netSSID: root.networkSSID
                netIP: root.networkIP
                notifService: notifPopup
            }

            // ── Уведомления — попапы (один экземпляр на монитор) ─────────
            // NotificationPopup содержит статические PopupWindow-слоты.
            // anchorWindow: bar — PopupWindow-ы якорятся к этому PanelWindow.
            NotificationPopup {
                id: notifPopup
                anchorWindow: bar
                fontFamily: root.fontFamily
                fontSize: root.fontSize
                colBg: root.colBg
                colFg: root.colFg
                colSurface: root.colSurface
                colMuted: root.colMuted
                colCyan: root.colCyan
                colBlue: root.colBlue
                colLBlue: root.colLightBlue
                colGreen: root.colGreen
                colRed: root.colRed
                colYellow: root.colYellow
            }

            // ── Calendar popup ────────────────────────────────────────────
            CalendarModule {
                id: calendarPopup
                anchor.window: bar
                anchor.rect.x: 0
                anchor.rect.y: bar.implicitHeight
                fontFamily: root.fontFamily
                fontSize: root.fontSize
                colBg: root.colBg
                colFg: root.colFg
                colMuted: root.colMuted
                colCyan: root.colCyan
                colBlue: root.colBlue
                colLBlue: root.colLightBlue
                colGreen: root.colGreen
                colRed: root.colRed
                colYellow: root.colYellow
                weatherService: Weather   // явный проброс singleton-а
            }

            // ── Wi-Fi popup ───────────────────────────────────────────────
            WifiModule {
                id: wifiPopup
                anchor.window: bar
                anchor.rect.x: bar.width - width - 8
                anchor.rect.y: bar.implicitHeight
                fontFamily: root.fontFamily
                fontSize: root.fontSize
                colBg: root.colBg
                colFg: root.colFg
                colMuted: root.colMuted
                colCyan: root.colCyan
                colBlue: root.colBlue
                colLBlue: root.colLightBlue
                colGreen: root.colGreen
                colRed: root.colRed
                colYellow: root.colYellow
                netConnected: root.networkConnected
                netType: root.networkType
                netSSID: root.networkSSID
                netIP: root.networkIP
            }

            // ── Sound popup ───────────────────────────────────────────────
            SoundModule {
                id: soundPopup
                anchor.window: bar
                anchor.rect.x: bar.width - width - 8
                anchor.rect.y: bar.implicitHeight
                fontFamily: root.fontFamily
                fontSize: root.fontSize
                colBg: root.colBg
                colFg: root.colFg
                colMuted: root.colMuted
                colCyan: root.colCyan
                colBlue: root.colBlue
                colLBlue: root.colLightBlue
                colGreen: root.colGreen
                colRed: root.colRed
                colYellow: root.colYellow
                volLevel: volume.level
                onVolChanged: lvl => { volume.level = lvl }
                barHovered: volHover.containsMouse
            }

            // ── Voicer popup ──────────────────────────────────────────────
            VoicerWindow {
                id: voicerPopup
                anchor.window: bar
                anchor.rect.x: bar.width - width - 8
                anchor.rect.y: bar.implicitHeight
                fontFamily: root.fontFamily
                fontSize: root.fontSize
                colBg: root.colBg
                colFg: root.colFg
                colMuted: root.colMuted
                colCyan: root.colCyan
                colBlue: root.colBlue
                colLBlue: root.colLightBlue
                colGreen: root.colGreen
                colRed: root.colRed
                colYellow: root.colYellow
            }

            component BorderFillRect: Item {
                id: bfr

                property real value: 0 // 0–100
                property real radius: 20
                property string label: ""
                property int thick: 4 // толщина рамки в px
                // Анимируем отдельное свойство — Canvas перерисовывается по onAnimValueChanged
                property real animValue: 0
                // Цвет по порогам
                readonly property color fillColor: animValue > 80 ? "#bf616a" : animValue > 55 ? "#ebcb8b" : "#8fbcbb"

                readonly property int fs: width / 4

                onValueChanged: animValue = Math.max(0, Math.min(100, value))
                Component.onCompleted: animValue = Math.max(0, Math.min(100, value))

                Canvas {
                    id: canvas

                    anchors.fill: parent
                    // Перерисовка при изменении анимированного значения или цвета
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset() 

                        var t = bfr.thick
                        // Ограничиваем радиус, чтобы он не схлопнул фигуру
                        var r = Math.min(bfr.radius, (width - t) / 2, (height - t) / 2)
                        var w = width - t
                        var h = height - t
                        var x = t / 2
                        var y = t / 2
                        

                        // 1. Точный периметр (2 стороны + 2 высоты + окружность)
                        var perimeter = 2 * (w - 2 * r) + 2 * (h - 2 * r) + (2 * Math.PI * r)
                        
                        // 2. Рассчитываем заполнение строго от 0 до perimeter
                        var progress = Math.max(0, Math.min(100, bfr.animValue))
                        var filled = (perimeter * progress) / 400

                        function createRoundedPath(c) {
                            c.beginPath()
                            c.moveTo(w / 2, y + h)
                            c.lineTo(x + r, y + h)
                            c.arcTo(x, y + h, x, y + h - r, r)
                            c.lineTo(x, y + r)
                            c.arcTo(x, y, x + r, y, r)
                            c.lineTo(x + w - r, y)
                            c.arcTo(x + w, y, x + w, y + r, r)
                            c.lineTo(x + w, y + h - r)
                            c.arcTo(x + w, y + h, x + w - r, y + h, r)
                            c.closePath()
                        }

                        // Отрисовка фона
                        ctx.save()
                        createRoundedPath(ctx)
                        ctx.strokeStyle = "rgba(255, 255, 255, 0.08)"
                        ctx.lineWidth = t
                        ctx.setLineDash([]) // Убираем пунктир для фона
                        ctx.stroke()
                        ctx.restore()

                        // Отрисовка прогресса
                        if (filled > 0) {
                            ctx.save()
                            createRoundedPath(ctx)
                            ctx.strokeStyle = bfr.fillColor
                            ctx.lineWidth = t
                            ctx.lineCap = "round"
                            // Устанавливаем Dash: [длина закраски, длина пустоты]
                            // Пустота должна быть не меньше периметра, чтобы не было повторов
                            ctx.setLineDash([filled, perimeter + 1]) 
                            ctx.stroke()
                            ctx.restore()
                        }
                    }


                    // Перерисовка при изменении animValue или fillColor
                    Connections {
                        function onAnimValueChanged() {
                            canvas.requestPaint();
                        }

                        function onFillColorChanged() {
                            canvas.requestPaint();
                        }

                        target: bfr
                    }

                }

                // Текст по центру
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Math.round(bfr.animValue) + "%"
                        color: bfr.fillColor
                        visible: false

                        font {
                            pixelSize: fs
                            family: "Monaspace Krypton Medium"
                            bold: true
                        }

                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: bfr.label !== ""
                        text: bfr.label
                        color: bfr.fillColor

                        font {
                            pixelSize: fs - 2
                            family: "Monaspace Krypton Medium"
                        }

                    }

                }

                Behavior on animValue {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // (Power menu переехал в ControlMenu — Фаза 3)

            // ══════════════════════════════════════════════════════════════
            // БАР: КОНТЕНТ
            // ══════════════════════════════════════════════════════════════
            Rectangle {
                anchors.fill: parent
                color: root.colBg

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    // ── LEFT: Логотип + Часы + Активное окно ─────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: parent.height
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 2

                            // Логотип — открывает Control Centre
                            Text {
                                text: "✦"
                                color: controlMouse.containsMouse ? root.colLightBlue : root.colCyan
                                font.pixelSize: 22
                                font.family: root.fontFamily

                                Behavior on color { ColorAnimation { duration: 120 } }

                                MouseArea {
                                    id: controlMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controlMenu.toggle()
                                }
                            }

                            // Часы — открывают календарь
                            ColumnLayout {
                                Layout.preferredHeight: parent.height
                                spacing: 0

                                Text {
                                    text: Qt.formatDateTime(clock.date, "ddd/dd.MM.yy")
                                    color: clockMouse.containsMouse ? root.colLightBlue : root.colFg
                                    font.pixelSize: root.fontSize - 4
                                    font.family: root.fontFamily
                                    font.bold: true
                                    Layout.leftMargin: 8
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                Text {
                                    text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                                    color: clockMouse.containsMouse ? root.colLightBlue : root.colFg
                                    font.pixelSize: root.fontSize
                                    font.family: root.fontFamily
                                    font.bold: true
                                    Layout.leftMargin: 8
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                MouseArea {
                                    id: clockMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendarPopup.visible = !calendarPopup.visible
                                }
                            }

                            // Активное окно
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: parent.height
                                spacing: 0

                                Text {
                                    text: root.activeWindowApp
                                    Layout.fillWidth: true
                                    color: root.colBlue
                                    font.pixelSize: root.fontSize - 4
                                    font.family: root.fontFamily
                                    font.bold: true
                                    Layout.leftMargin: 8
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: root.activeWindow
                                    Layout.fillWidth: true
                                    color: root.colLightBlue
                                    font.pixelSize: root.fontSize
                                    font.family: root.fontFamily
                                    font.bold: true
                                    Layout.leftMargin: 8
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // ── CENTER: Воркспейсы ────────────────────────────────
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: parent.height
                        Layout.preferredWidth: 260
                        color: "transparent"

                        RowLayout {
                            anchors.centerIn: parent

                            Workspaces {
                                fontFamily: root.fontFamily
                                fontSize:   root.fontSize
                                colActive:  root.colLightBlue
                                colOccupied: root.colFg
                                colEmpty:   root.colMuted
                                colBar:     root.colBlue
                                colBg:      root.colBg
                            }
                        }
                    }

                    // ── RIGHT: Метрики + Трей + Контролы ─────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredHeight: parent.height - 6
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 10

                            Item { Layout.fillWidth: true }

                            // ── Battery (только если есть) ────────────────
                            Text {
                                id: batteryLabel
                                readonly property UPowerDevice bat: UPower.displayDevice

                                visible: bat.isLaptopBattery
                                text: {
                                    if (!bat.isLaptopBattery) return ""
                                    var p = Math.round(bat.percentage * 100)
                                    var s = bat.state
                                    if (s === UPowerDeviceState.Charging) {
                                        if (p > 80) return "󰂊 " + p + "%"
                                        if (p > 60) return "󰂉 " + p + "%"
                                        if (p > 40) return "󰂈 " + p + "%"
                                        if (p > 20) return "󰂆 " + p + "%"
                                        return "󰢜 " + p + "%"
                                    }
                                    if (s === UPowerDeviceState.FullyCharged) return "󰁹 " + p + "%"
                                    if (p > 80) return "󰂀 " + p + "%"
                                    if (p > 60) return "󰁿 " + p + "%"
                                    if (p > 40) return "󰁾 " + p + "%"
                                    if (p > 20) return "󰁽 " + p + "%"
                                    return "󰁻 " + p + "%"
                                }
                                color: bat.percentage <= 0.15 ? root.colRed
                                     : bat.percentage <= 0.40 ? root.colYellow
                                     : root.colGreen
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                            }

                            // (SystemTray перенесён в ControlMenu → вкладка Main)

                            // ── Wi-Fi ─────────────────────────────────────
                            Text {
                                text: {
                                    if (!root.networkConnected) return "󰖪 Disconnected"
                                    if (root.networkType === "ethernet") return "󰛳 " + root.networkIP
                                    return "󰖩 " + root.networkSSID
                                }
                                color: root.networkConnected ? root.colCyan : root.colRed
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: wifiPopup.visible = !wifiPopup.visible
                                }
                            }

                            // ── CPU ───────────────────────────────────────
                            BorderFillRect {
                                width: 60
                                height: 35
                                radius: 30
                                value: root.cpuUsage
                                label: "CPU"
                            }

                            // ── RAM ───────────────────────────────────────
                            BorderFillRect {
                                width: 60
                                height: 35
                                radius: 30
                                value: root.memUsage
                                label: "RAM"
                            }

                            // ── GPU ───────────────────────────────────────
                            BorderFillRect {
                                width: 60
                                height: 35
                                radius: 30
                                value: root.gpuUsage
                                label: "GPU"
                            }

                            // ── Volume ────────────────────────────────────
                            Item {
                                id: volWidget
                                implicitWidth:  volLabel.implicitWidth
                                implicitHeight: volLabel.implicitHeight

                                Text {
                                    id: volLabel
                                    text: {
                                        var icon = volume.level === 0 ? "󰝟"
                                                 : volume.level < 50  ? "󰖀"
                                                 : "󰕾"
                                        return icon + " " + volume.level + "%"
                                    }
                                    color: volume.level > 90 ? root.colRed
                                         : volume.level > 50 ? root.colYellow
                                         : root.colCyan
                                    font.pixelSize: root.fontSize
                                    font.family: root.fontFamily
                                    font.bold: true
                                }

                                MouseArea {
                                    id: volHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    onEntered: {
                                        soundPopup.visible    = true
                                        soundPopup.barHovered = true
                                    }
                                    onExited: {
                                        soundPopup.barHovered = false
                                    }
                                    onWheel: event => {
                                        if (event.angleDelta.y > 0)
                                            volume.level = Math.min(100, volume.level + 5)
                                        else
                                            volume.level = Math.max(0, volume.level - 5)
                                        event.accepted = true
                                    }
                                }
                            }

                            // ── Клавиатура ────────────────────────────────
                            Text {
                                text: "󰌌 " + root.keyboardLayout
                                color: root.colCyan
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                            }

                            // ── Voice Changer ─────────────────────────────
                            Text {
                                text: VoiceChangerService.vcRtActive ? "󰍬"
                                    : VoiceChangerService.vcBusy     ? "󰔟"
                                    : VoiceChangerService.vcLoaded   ? "󰍬"
                                    : "󰍭"
                                color: VoiceChangerService.vcRtActive ? root.colGreen
                                     : VoiceChangerService.vcBusy     ? root.colYellow
                                     : VoiceChangerService.vcLoaded   ? root.colCyan
                                     : root.colMuted
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: voicerPopup.visible = !voicerPopup.visible
                                }
                            }

                            // ── Power — мини-меню быстрых действий ────────
                            Item {
                                id: powerBtnItem
                                implicitWidth:  powerTxt.implicitWidth
                                implicitHeight: powerTxt.implicitHeight

                                Text {
                                    id: powerTxt
                                    text: "⏻"
                                    color: powerMouse.containsMouse ? root.colRed : Qt.rgba(0.75, 0.38, 0.41, 0.7)
                                    font.pixelSize: root.fontSize + 2
                                    font.family: root.fontFamily
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                MouseArea {
                                    id: powerMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: miniPowerMenu.visible = !miniPowerMenu.visible
                                }

                                // Мини-попап питания
                                PopupWindow {
                                    id: miniPowerMenu
                                    visible: false
                                    anchor.window: bar
                                    anchor.rect.x: bar.width - width - 4
                                    anchor.rect.y: bar.implicitHeight
                                    width: 130
                                    height: powerMenuCol.implicitHeight + 8
                                    color: "transparent"

                                    Rectangle {
                                        anchors.fill: parent
                                        color: root.colBg
                                        border.color: root.colMuted
                                        border.width: 1

                                        Column {
                                            id: powerMenuCol
                                                                                        anchors {
                                                left: parent.left
                                                right: parent.right
                                                top: parent.top
                                            }
                                            anchors.margins: 4
                                            anchors.topMargin: 4
                                            spacing: 2

                                            Repeater {
                                                model: [
                                                    { icon: "󰍁", label: "Lock",      cmd: ["loginctl", "lock-session"],    danger: false },
                                                    { icon: "󰤄", label: "Suspend",   cmd: ["systemctl", "suspend"],        danger: false },
                                                    { icon: "󰒲", label: "Hibernate", cmd: ["systemctl", "hibernate"],      danger: false },
                                                    { icon: "󰈆", label: "Logout",    cmd: ["hyprctl", "dispatch", "exit"], danger: true  },
                                                    { icon: "󰜉", label: "Reboot",    cmd: ["systemctl", "reboot"],         danger: true  },
                                                    { icon: "󰐥", label: "Shutdown",  cmd: ["systemctl", "poweroff"],       danger: true  }
                                                ]

                                                Rectangle {
                                                    width: powerMenuCol.width
                                                    height: 28
                                                    color: pwrItemMa.containsMouse
                                                        ? (modelData.danger ? Qt.rgba(0.75,0.38,0.41,0.2) : Qt.rgba(1,1,1,0.06))
                                                        : "transparent"
                                                    Behavior on color { ColorAnimation { duration: 60 } }

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 8
                                                        anchors.rightMargin: 8
                                                        spacing: 6

                                                        Text {
                                                            text: modelData.icon
                                                                                                                        font {
                                                                pixelSize: root.fontSize - 1
                                                                family: root.fontFamily
                                                            }
                                                            color: modelData.danger ? root.colRed : root.colFg
                                                        }
                                                        Text {
                                                            text: modelData.label
                                                                                                                        font {
                                                                pixelSize: root.fontSize - 3
                                                                family: root.fontFamily
                                                            }
                                                            color: modelData.danger ? root.colRed : root.colFg
                                                            Layout.fillWidth: true
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: pwrItemMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            miniPowerMenu.visible = false
                                                            Qt.callLater(() => Quickshell.execDetached(modelData.cmd))
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

}
