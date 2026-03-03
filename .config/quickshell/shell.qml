import "./modules"
import "./services"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.DBusMenu
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    // ── Processes ─────────────────────────────────────────────────────────
    // ── Timers ────────────────────────────────────────────────────────────
    // ── Bar ───────────────────────────────────────────────────────────────

    id: root

    // ── Theme ─────────────────────────────────────────────────────────────
    property color colBg: "#2e3440"
    property color colFg: "#d8dee9"
    property color colMuted: "#4c566a"
    property color colCyan: "#8fbcbb"
    property color colPurple: "#ad8ee6"
    property color colRed: "#bf616a"
    property color colYellow: "#ebcb8b"
    property color colBlue: "#5e81ac"
    property color colLightBlue: "#81a1c1"
    property color colGreen: "#a3be8c"
    property color colBrown: "#b48ead"
    // ── Font ──────────────────────────────────────────────────────────────
    property string fontFamily: "Monaspace Krypton Medium"
    property int fontSize: 16
    // ── State ─────────────────────────────────────────────────────────────
    property string kernelVersion: "unknown"
    property int cpuUsage: 0
    property int memUsage: 0
    property int diskUsage: 0
    property string activeWindow: ""
    property string activeWindowApp: ""
    property int batteryPercent: 0
    property string batteryState: "discharging"
    property var keyboardLayouts: {
        "Russian": "RU",
        "English (US)": "EN"
    }
    property string keyboardLayout: ""
    // ── CPU delta tracking ────────────────────────────────────────────────
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0
    // ── GPU delta tracking ────────────────────────────────────────────────
    property var gpuUsage: 0
    // ── Network Connection ────────────────────────────────────────────────
    property string networkSSID: ""
    property string networkType: ""
    property string networkIP: ""
    property bool networkConnected: false
    // Weather
    property var weatherService: weather

    // ── Volume (single source of truth) ───────────────────────────────────
    QtObject {
        id: volume

        property int level: 50

        onLevelChanged: {
            volumeSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", level + "%"];
            volumeSetProc.running = true;
        }
    }

    Process {
        id: kernelProc

        command: ["uname", "-n"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                if (data)
                    kernelVersion = data.trim();

            }
        }

    }

    Process {
        id: cpuProc

        command: ["sh", "-c", "head -1 /proc/stat"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                var p = data.trim().split(/\s+/);
                var user = parseInt(p[1]) || 0;
                var nice = parseInt(p[2]) || 0;
                var system = parseInt(p[3]) || 0;
                var idle = parseInt(p[4]) || 0;
                var iowait = parseInt(p[5]) || 0;
                var irq = parseInt(p[6]) || 0;
                var softirq = parseInt(p[7]) || 0;
                var total = user + nice + system + idle + iowait + irq + softirq;
                var idleTime = idle + iowait;
                if (lastCpuTotal > 0) {
                    var td = total - lastCpuTotal;
                    var id = idleTime - lastCpuIdle;
                    if (td > 0)
                        cpuUsage = Math.round(100 * (td - id) / td);

                }
                lastCpuTotal = total;
                lastCpuIdle = idleTime;
            }
        }

    }

    Process {
        id: gpuProc

        command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                if (data && data.trim())
                    gpuUsage = data.trim();

            }
        }

    }

    Process {
        id: memProc

        command: ["sh", "-c", "free | grep Mem"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                var p = data.trim().split(/\s+/);
                var tot = parseInt(p[1]) || 1;
                var used = parseInt(p[2]) || 0;
                memUsage = Math.round(100 * used / tot);
            }
        }

    }

    Process {
        id: diskProc

        command: ["sh", "-c", "df / | tail -1"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                var p = data.trim().split(/\s+/);
                diskUsage = parseInt((p[4] || "0%").replace('%', '')) || 0;
            }
        }

    }

    Process {
        id: volGetProc

        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                var m = data.match(/Volume:\s*([\d.]+)/);
                if (m)
                    volume.level = Math.round(parseFloat(m[1]) * 100);

            }
        }

    }

    Process {
        id: volumeSetProc

        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "50%"]
    }

    Process {
        id: windowProc

        command: ["sh", "-c", "hyprctl activewindow -j | jq -r '.title // empty'"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                if (data && data.trim())
                    activeWindow = data.trim();

            }
        }

    }

    Process {
        id: windowAppProc

        command: ["sh", "-c", "hyprctl activewindow -j | jq -r '.class // empty'"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                if (data && data.trim())
                    activeWindowApp = data.trim();

            }
        }

    }

    Process {
        id: keyboardProc

        // Hyprland: читаем активную раскладку через hyprctl
        // i3/X11:   xkblayout-state возвращает только активную раскладку: "us" или "ru"
        command: WMDetector.isI3 ? ["xkblayout-state", "print", "%s"] : ["sh", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap'"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                if (!data || !data.trim())
                    return ;

                var raw = data.trim();
                if (WMDetector.isI3) {
                    var i3map = {
                        "us": "EN",
                        "ru": "RU"
                    };
                    keyboardLayout = i3map[raw] ?? raw.toUpperCase();
                } else {
                    // hyprctl возвращает полное название: "English (US)", "Russian"
                    keyboardLayout = keyboardLayouts[raw] ?? raw;
                }
            }
        }

    }

    Process {
        id: netProc

        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev | grep connected"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                if (!data || !data.trim()) {
                    networkConnected = false;
                    networkSSID = "";
                    networkType = "";
                    return ;
                }
                var parts = data.trim().split(':');
                if (parts.length >= 4 && (parts[1] === 'ethernet' || parts[1] === 'wifi') && parts[2] === 'connected') {
                    networkConnected = true;
                    if (parts[1] === 'ethernet')
                        ipProc.running = true;
                    else
                        networkSSID = parts[3];
                    networkType = parts[1];
                }
            }
        }

    }

    Process {
        id: ipProc

        command: ["sh", "-c", "hostname -i | awk '{print $1}'"]

        stdout: SplitParser {
            onRead: (data) => {
                if (data && data.trim())
                    networkIP = data.trim();

            }
        }

    }

    // Fast stats: CPU / mem / disk / volume — every second
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running = true;
            memProc.running = true;
            diskProc.running = true;
            volGetProc.running = true;
            gpuProc.running = true;
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    // Battery — every 30 s (changes slowly)
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            netProc.running = true;
        }
    }

    // Window / layout — on Hyprland events (только для Hyprland)
    Connections {
        function onRawEvent(event) {
            windowProc.running = true;
            windowAppProc.running = true;
            keyboardProc.running = true;
        }

        target: Hyprland
        enabled: WMDetector.isHyprland
    }

    // Keyboard layout poll для i3 (X11 не шлёт события — полим каждые 500ms)
    Timer {
        interval: 500
        running: WMDetector.isI3
        repeat: true
        onTriggered: keyboardProc.running = true
    }

    // Window / layout backup poll
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            windowProc.running = true;
        }
    }

    Variants {
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

            ControlMenu {
                id: controlMenu

                screen: Quickshell.screens[0] // первый экран
            }

            Weather {
                id: weather
            }

            // ── Bar content ───────────────────────────────────────────────
            Rectangle {
                anchors.fill: parent
                color: root.colBg

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    // ═══════════════════════════════════════════════════════════
                    // LEFT BOX: Workspaces + Layout + Window
                    // ═══════════════════════════════════════════════════════════
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignLeft
                        Layout.preferredHeight: parent.height
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2

                            // Logo
                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                color: "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "✦"
                                    color: root.colCyan
                                    font.pixelSize: 25
                                    font.family: root.fontFamily

                                    MouseArea {
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        anchors.fill: parent
                                        onClicked: controlMenu.visible = !controlMenu.visible
                                    }

                                }

                            }

                            Workspaces {
                                fontFamily: root.fontFamily
                                fontSize: root.fontSize
                                colActive: root.colLightBlue
                                colOccupied: root.colFg
                                colEmpty: root.colMuted
                                colBar: root.colBlue
                                colBg: root.colBg
                            }

                            ColumnLayout {
                                Layout.preferredHeight: parent.height
                                Layout.fillWidth: true
                                spacing: 0

                                // Active window app
                                Text {
                                    text: activeWindowApp
                                    Layout.fillWidth: true
                                    color: colBlue
                                    font.pixelSize: fontSize - 4
                                    font.family: fontFamily
                                    font.bold: true
                                    Layout.leftMargin: 8
                                    elide: Text.ElideRight
                                }

                                // Active window
                                Text {
                                    text: activeWindow
                                    Layout.fillWidth: true
                                    color: colLightBlue
                                    font.pixelSize: fontSize
                                    font.family: fontFamily
                                    font.bold: true
                                    Layout.leftMargin: 8
                                    elide: Text.ElideRight
                                }

                            }

                        }

                    }

                    // ═══════════════════════════════════════════════════════════
                    // CENTER BOX: Clock
                    // ═══════════════════════════════════════════════════════════
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: parent.height
                        Layout.preferredWidth: 260
                        color: "transparent"

                        // Календарь — объявлен здесь, якорится к bar
                        CalendarModule {
                            id: calendarPopup

                            anchor.window: bar
                            // Центрируем под часами: x = середина бара минус половина ширины попапа
                            anchor.rect.x: (bar.width - width) / 2
                            anchor.rect.y: bar.implicitHeight
                            // Передаём тему из root
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

                        RowLayout {
                            anchors.centerIn: parent

                            // ── Часы — теперь кликабельны ────────────────────────────────────
                            Text {
                                id: clockText

                                text: Qt.formatDateTime(clock.date, "ddd/dd.MM.yy HH:mm")
                                color: clockMouse.containsMouse ? colLightBlue : colFg
                                font.pixelSize: fontSize
                                font.family: fontFamily
                                font.bold: true

                                MouseArea {
                                    id: clockMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calendarPopup.visible = !calendarPopup.visible
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }

                                }

                            }

                            Repeater {
                                model: SystemTray.items

                                Item {
                                    required property SystemTrayItem modelData

                                    width: 28
                                    height: 28
                                    visible: false

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 5
                                        color: mouse.containsMouse ? "#22ffffff" : "transparent"

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 100
                                            }

                                        }

                                    }

                                    IconImage {
                                        anchors.centerIn: parent
                                        source: modelData.icon
                                        width: 20
                                        height: 20
                                        layer.enabled: modelData.status === Status.NeedsAttention
                                    }

                                    QsMenuAnchor {
                                        id: ctxMenu

                                        menu: parent.modelData.menu
                                    }

                                    MouseArea {
                                        id: mouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: (event) => {
                                            if (event.button === Qt.LeftButton)
                                                parent.modelData.activate();
                                            else if (parent.modelData.hasMenu)
                                                ctxMenu.open();
                                        }

                                        ToolTip {
                                            visible: mouse.containsMouse
                                            delay: 500
                                            text: parent.parent.modelData.tooltipTitle || parent.parent.modelData.title
                                        }

                                    }

                                }

                            }

                            // Battery
                            Text {
                                readonly property UPowerDevice battery: UPower.displayDevice

                                text: {
                                    if (battery.isLaptopBattery) {
                                        const s = battery.state;
                                        const p = Math.round(battery.percentage * 100);
                                        if (s === UPowerDeviceState.Charging) {
                                            if (p > 80)
                                                return " " + p + "%";

                                            if (p > 60)
                                                return " " + p + "%";

                                            if (p > 40)
                                                return " " + p + "%";

                                            if (p > 20)
                                                return " " + p + "%";

                                            return " " + p + "%";
                                        }
                                        if (s === UPowerDeviceState.FullyCharged)
                                            return " " + p + "%";

                                        if (p > 80)
                                            return " " + p + "%";

                                        if (p > 60)
                                            return " " + p + "%";

                                        if (p > 40)
                                            return " " + p + "%";

                                        if (p > 20)
                                            return " " + p + "%";

                                        return " " + p + "%";
                                    }
                                }
                                color: battery.percentage <= 0.15 ? colRed : battery.percentage <= 0.4 ? colYellow : colGreen
                                font.pixelSize: fontSize
                                font.family: fontFamily
                                font.bold: true
                                Layout.leftMargin: 4
                            }

                        }

                    }

                    // ═══════════════════════════════════════════════════════════
                    // RIGHT BOX: System stats
                    // ═══════════════════════════════════════════════════════════
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredHeight: parent.height - 6
                        color: "transparent"

                        RowLayout {
                            // Volume
                            // Заменить существующий Volume Item в RIGHT BOX на этот блок:

                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Item {
                                Layout.fillWidth: true
                            }

                            // Kernel
                            Text {
                                text: " " + kernelVersion
                                color: colBrown
                                font.pixelSize: fontSize
                                font.family: fontFamily
                                font.bold: true
                                Layout.rightMargin: 8
                            }

                            WifiModule {
    id: wifiPopup
    anchor.window: bar
    anchor.rect.x: bar.width - width - 8
    anchor.rect.y: bar.implicitHeight
    fontFamily: root.fontFamily;  fontSize: root.fontSize
    colBg: root.colBg;    colFg: root.colFg;     colMuted: root.colMuted
    colCyan: root.colCyan; colBlue: root.colBlue; colLBlue: root.colLightBlue
    colGreen: root.colGreen; colRed: root.colRed; colYellow: root.colYellow
    netConnected: root.networkConnected
    netType:      root.networkType
    netSSID:      root.networkSSID
    netIP:        root.networkIP
}

Text {
    text: {
        if (!networkConnected) return "󰖪 Disconnected"
        if (networkType === "ethernet") return "󰛳 " + networkIP
        return "󰖩 " + networkSSID
    }
    color: networkConnected ? colCyan : colRed
    font.pixelSize: fontSize; font.family: fontFamily; font.bold: true
    Layout.rightMargin: 8

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: wifiPopup.visible = !wifiPopup.visible
    }
}

                            // CPU
                            Text {
                                text: "CPU: " + cpuUsage + "%"
                                color: cpuUsage > 80 ? colRed : cpuUsage > 50 ? colYellow : colCyan
                                font.pixelSize: fontSize
                                font.family: fontFamily
                                font.bold: true
                                Layout.rightMargin: 8
                            }

                            // GPU
                            Text {
                                text: "GPU: " + gpuUsage + "%"
                                color: gpuUsage > 80 ? colRed : gpuUsage > 50 ? colYellow : colCyan
                                font.pixelSize: fontSize
                                font.family: fontFamily
                                font.bold: true
                                Layout.rightMargin: 8

                                MouseArea {
                                    id: btop

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["kitty", "btop"])
                                }

                            }

                            // Memory
                            Text {
                                text: "RAM: " + memUsage + "%"
                                color: memUsage > 80 ? colRed : memUsage > 60 ? colYellow : colCyan
                                font.pixelSize: fontSize
                                font.family: fontFamily
                                font.bold: true
                                Layout.rightMargin: 8
                            }

                            // Disk
                            Text {
                                visible: false
                                text: "DISK (/): " + diskUsage + "%"
                                color: diskUsage > 90 ? colRed : diskUsage > 70 ? colYellow : colCyan
                                font.pixelSize: fontSize
                                font.family: fontFamily
                                font.bold: true
                                Layout.rightMargin: 8
                            }

                            Item {
                                id: volWidget

                                implicitWidth: volLabel.implicitWidth
                                implicitHeight: volLabel.implicitHeight
                                Layout.rightMargin: 8

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
                                    onVolChanged: (lvl) => {
                                        volume.level = lvl;
                                    }
                                    // Пробрасываем hover с кнопки в модуль
                                    barHovered: volHover.containsMouse
                                }

                                Text {
                                    id: volLabel

                                    text: {
                                        var icon = volume.level === 0 ? "󰝟" : volume.level < 50 ? "󰖀" : "󰕾";
                                        return icon + " " + volume.level + "%";
                                    }
                                    color: volume.level > 90 ? colRed : volume.level > 50 ? colYellow : colCyan
                                    font.pixelSize: fontSize
                                    font.family: fontFamily
                                    font.bold: true
                                }

                                MouseArea {
                                    id: volHover

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    onEntered: {
                                        soundPopup.visible = true;
                                        soundPopup.barHovered = true;
                                    }
                                    onExited: {
                                        soundPopup.barHovered = false;
                                    }
                                    onWheel: (event) => {
                                        if (event.angleDelta.y > 0)
                                            volume.level = Math.min(100, volume.level + 5);
                                        else
                                            volume.level = Math.max(0, volume.level - 5);
                                        event.accepted = true;
                                    }
                                }

                            }

                            Text {
                                text: "󰌌 " + keyboardLayout
                                color: colCyan
                                font.pixelSize: fontSize
                                font.family: fontFamily
                                font.bold: true
                                Layout.rightMargin: 8
                            }

                            // Power menu button
                            Rectangle {
                                id: powerBtn

                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.rightMargin: 4
                                color: powerMouse.containsMouse ? root.colMuted : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "⏻"
                                    color: colRed
                                    font.pixelSize: fontSize + 4
                                    font.family: fontFamily
                                }

                                MouseArea {
                                    id: powerMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: powerMenu.visible = !powerMenu.visible
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }

                                }

                            }

                            PopupWindow {
                                id: powerMenu

                                visible: false
                                anchor.window: bar
                                anchor.rect.x: bar.width - width
                                anchor.rect.y: bar.implicitHeight
                                width: 120
                                height: 120
                                color: "transparent"

                                Rectangle {
                                    anchors.fill: parent
                                    color: colBg

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 5

                                        Repeater {
                                            model: [{
                                                "label": "Lock",
                                                "cmd": "hyprlock"
                                            }, {
                                                "label": "Logout",
                                                "cmd": "sh -c '[ \"$XDG_CURRENT_DESKTOP\" = \"Hyprland\" ] && hyprctl dispatch exit || i3-msg exit'"
                                            }, {
                                                "label": "Shutdown",
                                                "cmd": "systemctl poweroff"
                                            }, {
                                                "label": "Reboot",
                                                "cmd": "systemctl reboot"
                                            }]

                                            Rectangle {
                                                width: parent.width - 8
                                                height: (powerMenu.height - 10) / 4
                                                color: itemMouse.containsMouse ? colMuted : "transparent"
                                                anchors.horizontalCenter: parent.horizontalCenter

                                                Row {
                                                    anchors.centerIn: parent

                                                    Text {
                                                        text: modelData.label
                                                        horizontalAlignment: Text.AlignLeft
                                                        color: colFg
                                                        font.pixelSize: fontSize
                                                        font.family: fontFamily
                                                        font.bold: true
                                                    }

                                                }

                                                MouseArea {
                                                    id: itemMouse

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        powerMenu.visible = false;
                                                        Hyprland.dispatch("exec " + modelData.cmd);
                                                    }
                                                }

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 80
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
