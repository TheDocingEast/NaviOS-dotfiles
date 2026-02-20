import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.DBusMenu
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower

import "modules"

ShellRoot {
    id: root

    // ── Theme ─────────────────────────────────────────────────────────────
    property color colBg: "#141c26"
    property color colFg: "#d8dee9"
    property color colMuted: "#4c566a"
    property color colCyan: "#8fbcbb"
    property color colPurple: "#ad8ee6"
    property color colRed: "#bf616a"
    property color colYellow: "#ebcb8b"
    property color colBlue: "#5e81ac"
    property color colGreen: "#a3be8c"
    property color colBrown: "#b48ead"

    // ── Font ──────────────────────────────────────────────────────────────
    property string fontFamily: "Monaspace Krypton Medium"
    property int fontSize: 16

    // ── State ─────────────────────────────────────────────────────────────
    property string kernelVersion: "Linux"
    property int cpuUsage: 0
    property int memUsage: 0
    property int diskUsage: 0
    property string activeWindow: ""
    property int batteryPercent: 0
    property string batteryState: "discharging"

    // ── CPU delta tracking ────────────────────────────────────────────────
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0

    // ── GPU delta tracking ────────────────────────────────────────────────
    property var gpuUsage: 0

    // ── Volume (single source of truth) ───────────────────────────────────
    QtObject {
        id: volume
        property int level: 50
        onLevelChanged: {
            volumeSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", level + "%"];
            volumeSetProc.running = true;
        }
    }

    // ── Network Connection ────────────────────────────────────────────────
    property string networkSSID: ""
    property string networkType: ""
    property string networkIP: ""
    property bool networkConnected: false

    // ── Processes ─────────────────────────────────────────────────────────

    Process {
        id: kernelProc
        command: ["uname", "-n"]
        stdout: SplitParser {
            onRead: data => {
                if (data)
                    kernelVersion = data.trim();
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
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
        Component.onCompleted: running = true
    }

    Process {
        id: gpuProc
        command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim())
                    gpuUsage = data.trim();
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: memProc
        command: ["sh", "-c", "free | grep Mem"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var p = data.trim().split(/\s+/);
                var tot = parseInt(p[1]) || 1;
                var used = parseInt(p[2]) || 0;
                memUsage = Math.round(100 * used / tot);
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: diskProc
        command: ["sh", "-c", "df / | tail -1"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var p = data.trim().split(/\s+/);
                diskUsage = parseInt((p[4] || "0%").replace('%', '')) || 0;
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: volGetProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                if (!data)
                    return;
                var m = data.match(/Volume:\s*([\d.]+)/);
                if (m)
                    volume.level = Math.round(parseFloat(m[1]) * 100);
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: volumeSetProc
        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "50%"]
    }

    Process {
        id: windowProc
        command: ["sh", "-c", "hyprctl activewindow -j | jq -r '.title // empty'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim())
                    activeWindow = data.trim();
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev | grep connected"]
        stdout: SplitParser {
            onRead: data => {
                if (!data || !data.trim()) {
                    networkConnected = false;
                    networkSSID = "";
                    networkType = "";
                    return;
                }

                var parts = data.trim().split(':');
                if (parts.length >= 4 && (parts[1] === 'ethernet' || parts[1] === 'wifi') && (parts[2] === 'подключено' || parts[2] === 'connected')) {
                    networkConnected = true;
                    if (parts[1] === 'ethernet') {
                        ipProc.running = true;
                    } else {
                        networkSSID = parts[3];
                    }
                    networkType = parts[1];
                }
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        id: ipProc
        command: ["sh", "-c", "hostname -i | awk '{print $1}'"]
        stdout: SplitParser {
            onRead: data => {
                if (data && data.trim()) {
                    networkIP = data.trim();
                }
            }
        }
    }

    // ── Timers ────────────────────────────────────────────────────────────

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

    // Window / layout — on Hyprland events
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            windowProc.running = true;
        }
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

    // ── Bar ───────────────────────────────────────────────────────────────

    ControlMenu {
        id: controlMenu
        screen: Quickshell.screens[0]  // первый экран
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 50
            color: root.colBg

            // ── Volume OSD popup ──────────────────────────────────────────
            PopupWindow {
                id: volOsd
                anchor.window: bar
                anchor.rect.x: bar.width - width
                anchor.rect.y: bar.implicitHeight
                width: 180
                height: 40
                color: "transparent"
                visible: false

                Timer {
                    id: osdHide
                    interval: 1500
                    repeat: false
                    onTriggered: volOsd.visible = false
                }

                function show() {
                    visible = true;
                    osdHide.restart();
                }

                Rectangle {
                    anchors.fill: parent
                    color: colBg

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: volume.level === 0 ? "󰝟" : volume.level < 50 ? "󰖀" : "󰕾"
                            color: root.colPurple
                            font.pixelSize: 16
                            font.family: root.fontFamily
                        }

                        Rectangle {
                            width: 90
                            height: 6
                            radius: 3
                            color: root.colMuted
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: parent.width * (volume.level / 100)
                                height: parent.height
                                radius: parent.radius
                                color: root.colPurple
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 80
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: volume.level + "%"
                            color: root.colFg
                            font.pixelSize: 12
                            font.family: root.fontFamily
                        }
                    }
                }
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

                            Item {
                                width: 8
                            }

                            Repeater {
                                readonly property int maxOccupied: {
                                    let max = 0;
                                    const ws = Hyprland.workspaces.values;
                                    for (let i = 0; i < ws.length; i++) {
                                        if (ws[i].id > max)
                                            max = ws[i].id;
                                    }
                                    return max;
                                }

                                readonly property int maxModel: Math.max(maxOccupied, Hyprland.focusedWorkspace?.id ?? 0)

                                model: maxModel

                                Rectangle {
                                    Layout.preferredHeight: parent.height
                                    color: "transparent"

                                    readonly property int wsId: index + 1
                                    readonly property var workspace: Hyprland.workspaces.values.find(ws => ws.id === wsId) ?? null
                                    readonly property bool isActive: Hyprland.focusedWorkspace?.id === wsId
                                    readonly property bool hasWindows: workspace !== null

                                    readonly property bool shouldShow: hasWindows || isActive || wsId === parent.maxModel

                                    visible: shouldShow
                                    Layout.preferredWidth: shouldShow ? 30 : 0

                                    Text {
                                        text: parent.wsId
                                        color: parent.isActive ? root.colCyan : parent.hasWindows ? root.colFg : root.colMuted
                                        font.pixelSize: root.fontSize
                                        font.family: root.fontFamily
                                        font.bold: true
                                        anchors.centerIn: parent
                                    }

                                    Rectangle {
                                        width: 20
                                        height: 3
                                        color: parent.isActive ? root.colPurple : root.colBg
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 100
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: Hyprland.dispatch("workspace " + parent.wsId)
                                    }
                                }
                            }

                            // Active window
                            Text {
                                text: activeWindow
                                Layout.fillWidth: true
                                color: root.colBrown
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                                Layout.leftMargin: 8
                                elide: Text.ElideRight
                                maximumLineCount: 1
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

                        RowLayout {
                            anchors.centerIn: parent

                            Text {
                                id: clockText
                                text: Qt.formatDateTime(clock.date, "ddd dd.MM.yyyy HH:mm")
                                color: root.colCyan
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                            }

                            Repeater {
                                model: SystemTray.items

                                Item {
                                    required property SystemTrayItem modelData
                                    width: 28
                                    height: 28
                                    visible: false

                                    // Фон при наведении
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

                                        // Выделение для NeedsAttention
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

                                        onClicked: event => {
                                            if (event.button === Qt.LeftButton) {
                                                parent.modelData.activate();
                                            } else if (parent.modelData.hasMenu) {
                                                ctxMenu.open();
                                            }
                                        }

                                        ToolTip {
                                            visible: mouse.containsMouse
                                            delay: 500
                                            text: parent.parent.modelData.tooltipTitle || parent.parent.modelData.title
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ═══════════════════════════════════════════════════════════
                    // RIGHT BOX: System stats
                    // ═══════════════════════════════════════════════════════════
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        Layout.preferredHeight: parent.height

                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6
                            Item {
                                Layout.fillWidth: true
                            }

                            // Kernel
                            Text {
                                text: " " + kernelVersion
                                color: root.colBrown
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                                Layout.rightMargin: 8
                            }

                            // Network
                            Text {
                                text: {
                                    if (!networkConnected)
                                        return "󰖪";
                                    if (networkType === "ethernet")
                                        return "󰈀 " + networkIP;
                                    return "󰖨 " + networkSSID;
                                }
                                color: networkConnected ? root.colCyan : root.colRed
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                                Layout.rightMargin: 8
                            }

                            // CPU
                            Text {
                                text: "CPU: " + cpuUsage + "%"
                                color: cpuUsage > 80 ? root.colRed : cpuUsage > 50 ? root.colYellow : root.colCyan
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                                Layout.rightMargin: 8
                            }

                            // GPU

                            Rectangle {
                                Layout.rightMargin: 8
                                color: btop.containsMouse ? root.colMuted : "transparent"
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 24
                                Text {
                                    text: "GPU: " + gpuUsage + "%"
                                    anchors.centerIn: parent
                                    color: gpuUsage > 80 ? root.colRed : gpuUsage > 50 ? root.colYellow : root.colCyan
                                    font.pixelSize: root.fontSize
                                    font.family: root.fontFamily
                                    font.bold: true

                                    MouseArea {
                                        id: btop
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["kitty", "btop"])
                                    }
                                }
                            }

                            // Memory
                            Text {
                                text: "RAM: " + memUsage + "%"
                                color: memUsage > 80 ? root.colRed : memUsage > 60 ? root.colYellow : root.colCyan
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                                Layout.rightMargin: 8
                            }

                            // Disk
                            Text {
                                text: "DISK (/): " + diskUsage + "%"
                                color: diskUsage > 90 ? root.colRed : diskUsage > 70 ? root.colYellow : root.colCyan
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                                Layout.rightMargin: 8
                            }

                            // Battery
                            Text {
                                readonly property var battery: UPower.displayDevice
                                text: {
                                    if (battery.onBattery) {
                                        const s = battery.state;
                                        if (s === UPowerDeviceState.Charging)
                                            return "󰂄";
                                        if (s === UPowerDeviceState.FullyCharged)
                                            return "󰁹";
                                        const p = battery.percentage;
                                        if (p > 80)
                                            return "󰂀";
                                        if (p > 60)
                                            return "󰁿";
                                        if (p > 40)
                                            return "󰁾";
                                        if (p > 20)
                                            return "󰁽";
                                        return "󰁺";
                                    }
                                }
                                color: batteryPercent <= 15 ? root.colRed : batteryPercent <= 40 ? root.colYellow : root.colGreen
                                font.pixelSize: root.fontSize
                                font.family: root.fontFamily
                                font.bold: true
                                Layout.rightMargin: 8
                            }

                            // Volume
                            Item {
                                id: volWidget
                                implicitWidth: volLabel.implicitWidth
                                implicitHeight: volLabel.implicitHeight

                                Layout.rightMargin: 8

                                Text {
                                    id: volLabel
                                    text: {
                                        var icon = volume.level === 0 ? "󰝟" : volume.level < 50 ? "󰖀" : "󰕾";
                                        return icon + " " + volume.level + "%";
                                    }
                                    color: volume.level > 90 ? colRed : volume.level > 50 ? colYellow : colCyan
                                    font.pixelSize: root.fontSize
                                    font.family: root.fontFamily
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton
                                    onWheel: event => {
                                        if (event.angleDelta.y > 0)
                                            volume.level = Math.min(100, volume.level + 5);
                                        else
                                            volume.level = Math.max(0, volume.level - 5);
                                        volOsd.show();
                                        event.accepted = true;
                                    }
                                }
                            }

                            // Power menu button
                            Rectangle {
                                id: powerBtn
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.rightMargin: 4
                                color: powerMouse.containsMouse ? root.colMuted : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "⏻"
                                    color: root.colRed
                                    font.pixelSize: 18
                                    font.family: root.fontFamily
                                }

                                MouseArea {
                                    id: powerMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: powerMenu.visible = !powerMenu.visible
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
                                            model: [
                                                {
                                                    label: "Lock",
                                                    cmd: "hyprlock"
                                                },
                                                {
                                                    label: "Logout",
                                                    cmd: "hyprctl dispatch exit"
                                                },
                                                {
                                                    label: "Shutdown",
                                                    cmd: "systemctl poweroff"
                                                },
                                                {
                                                    label: "Reboot",
                                                    cmd: "systemctl reboot"
                                                }
                                            ]

                                            Rectangle {
                                                width: parent.width - 8
                                                height: (powerMenu.height - 10) / 4
                                                color: itemMouse.containsMouse ? root.colMuted : "transparent"
                                                anchors.horizontalCenter: parent.horizontalCenter

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 80
                                                    }
                                                }

                                                Row {
                                                    anchors.centerIn: parent

                                                    Text {
                                                        text: modelData.label
                                                        horizontalAlignment: Text.AlignLeft
                                                        color: root.colFg
                                                        font.pixelSize: 14
                                                        font.family: root.fontFamily
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
