// modules/BluetoothModule.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth

Item {
    id: root

    // ── Theme ─────────────────────────────────────────────────────────────
    property string fontFamily: "Monaspace Krypton Medium"
    property int    fontSize:   16
    property color  colBg:      "#2e3440"
    property color  colFg:      "#d8dee9"
    property color  colMuted:   "#4c566a"
    property color  colCyan:    "#8fbcbb"
    property color  colBlue:    "#5e81ac"
    property color  colLBlue:   "#81a1c1"
    property color  colGreen:   "#a3be8c"
    property color  colRed:     "#bf616a"
    property color  colYellow:  "#ebcb8b"

    implicitWidth:  parent ? parent.width : 260
    implicitHeight: col.implicitHeight

    // ── BT state ──────────────────────────────────────────────────────────
    readonly property var  adapter:     Bluetooth.defaultAdapter
    readonly property bool btOn:        adapter ? adapter.enabled    : false
    readonly property bool discovering: adapter ? adapter.discovering : false

    // ── Blink timer ───────────────────────────────────────────────────────
    property bool _blink: true
    Timer {
        running:  root.discovering
        repeat:   true
        interval: 550
        onTriggered: root._blink = !root._blink
        onRunningChanged: if (!running) root._blink = true
    }

    // ── Root column ───────────────────────────────────────────────────────
    ColumnLayout {
        id: col
                anchors {
            left: parent.left
            right: parent.right
        }
        spacing: 0

        // ── Header ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin:   12
            Layout.rightMargin:  8
            Layout.topMargin:    10
            Layout.bottomMargin: 6
            spacing: 8

            Text {
                text: "󰂯"
                                font {
                    pixelSize: root.fontSize + 2
                    family: root.fontFamily
                }
                color: root.btOn
                    ? (root.discovering
                        ? (root._blink ? root.colCyan : Qt.rgba(0.56, 0.74, 0.73, 0.25))
                        : root.colCyan)
                    : root.colMuted
            }
            Text {
                text: "Bluetooth"
                                font {
                    pixelSize: root.fontSize
                    family: root.fontFamily
                    bold: true
                }
                color: root.colFg
                Layout.fillWidth: true
            }

            // Scan button
            Item {
                visible: root.btOn
                width: 28
                height: 28
                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: scanHover.containsMouse ? root.colMuted : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                Text {
                    anchors.centerIn: parent
                    text: root.discovering ? "󰅖" : "󰂰"
                                        font {
                        pixelSize: root.fontSize
                        family: root.fontFamily
                    }
                    color: root.discovering ? root.colRed : root.colLBlue
                    ToolTip.visible: scanHover.containsMouse
                    ToolTip.text:    root.discovering ? "Stop scan" : "Scan for devices"
                    ToolTip.delay:   500
                }
                MouseArea {
                    id: scanHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.adapter.discovering = !root.adapter.discovering
                }
            }

            // Power toggle
            Item {
                width: 44
                height: 24
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: root.btOn ? root.colCyan : root.colMuted
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.btOn ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
                }
            }
        }

        // ── Divider ───────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            height: 1
            color: root.colMuted
            opacity: 0.4
        }

        // ── BT off ────────────────────────────────────────────────────────
        Text {
            visible: !root.btOn
            Layout.fillWidth: true
            Layout.topMargin: 14
            Layout.bottomMargin: 14
            horizontalAlignment: Text.AlignHCenter
            text: "Bluetooth is off"
                        font {
                pixelSize: root.fontSize - 2
                family: root.fontFamily
            }
            color: root.colMuted
        }

        // ── Scan indicator ────────────────────────────────────────────────
        RowLayout {
            visible: root.btOn && root.discovering
            Layout.leftMargin: 14
            Layout.topMargin: 6
            Layout.bottomMargin: 2
            spacing: 8

            // Arc spinner через Canvas
            Canvas {
                id: arcCanvas
                width: 16
                height: 16

                property real angle: 0
                NumberAnimation on angle {
                    running: root.discovering
                    loops:   Animation.Infinite
                    from: 0; to: Math.PI * 2
                    duration: 1000
                    easing.type: Easing.Linear
                    onRunningChanged: if (!running) arcCanvas.angle = 0
                }
                onAngleChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    var cx = width  / 2
                    var cy = height / 2
                    var r  = width  / 2 - 2

                    // Track
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                    ctx.strokeStyle = Qt.rgba(0.30, 0.35, 0.41, 0.5)
                    ctx.lineWidth   = 2
                    ctx.lineCap     = "round"
                    ctx.stroke()

                    // Arc — дуга ~240°, вращается
                    var span  = Math.PI * 1.33   // длина дуги
                    var start = angle - Math.PI / 2
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, start, start + span)
                    ctx.strokeStyle = Qt.rgba(0.56, 0.74, 0.73, 1.0)  // colCyan
                    ctx.lineWidth   = 2
                    ctx.lineCap     = "round"
                    ctx.stroke()
                }
            }

            Text {
                text: "Scanning..."
                                font {
                    pixelSize: root.fontSize - 2
                    family: root.fontFamily
                }
                color: root.colMuted
            }
        }

        // ── No devices ────────────────────────────────────────────────────
        Text {
            visible: root.btOn && root.adapter && root.adapter.devices.count === 0
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            horizontalAlignment: Text.AlignHCenter
            text: root.discovering ? "Looking for devices..." : "No devices found"
                        font {
                pixelSize: root.fontSize - 2
                family: root.fontFamily
            }
            color: root.colMuted
        }

        // ── Device list ───────────────────────────────────────────────────
        Repeater {
            model: (root.btOn && root.adapter) ? root.adapter.devices : null

            delegate: Rectangle {
                id: devRow
                required property BluetoothDevice modelData
                readonly property BluetoothDevice dev: modelData

                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                Layout.topMargin: 2
                height: 52
                radius: 7
                color: rowArea.containsMouse
                    ? Qt.rgba(0.3, 0.35, 0.42, 0.55)
                    : dev.connected
                        ? Qt.rgba(0.56, 0.74, 0.73, 0.08)
                        : "transparent"
                Behavior on color { ColorAnimation { duration: 110 } }

                RowLayout {
                                        anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 8
                    }
                    spacing: 10

                    Text {
                        text: iconFor(dev.icon)
                                                font {
                            pixelSize: root.fontSize + 4
                            family: root.fontFamily
                        }
                        color: dev.connected ? root.colCyan : root.colMuted
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: dev.name || "Unknown device"
                                                        font {
                                pixelSize: root.fontSize - 1
                                family: root.fontFamily
                                bold: dev.connected
                            }
                            color: root.colFg
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        RowLayout {
                            spacing: 6
                            Text {
                                text: stateLabel(dev.state)
                                                                font {
                                    pixelSize: root.fontSize - 4
                                    family: root.fontFamily
                                }
                                color: dev.connected ? root.colGreen : root.colMuted
                            }
                            Text {
                                visible: dev.batteryAvailable
                                text: batIcon(dev.battery * 100) + " " + Math.round(dev.battery * 100) + "%"
                                                                font {
                                    pixelSize: root.fontSize - 4
                                    family: root.fontFamily
                                }
                                color: !dev.batteryAvailable ? root.colFg
                                     : dev.battery < 0.20   ? root.colRed
                                     : dev.battery < 0.40   ? root.colYellow
                                     : dev.battery < 0.70   ? root.colGreen
                                     :                        root.colCyan
                            }
                        }
                    }

                    // Quick action button (ЛКМ)
                    Item {
                        width: 28
                        height: 28
                        Rectangle {
                            anchors.fill: parent
                            radius: 5
                            color: actHover.containsMouse ? root.colMuted : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        Text {
                            anchors.centerIn: parent
                                                        font {
                                pixelSize: root.fontSize
                                family: root.fontFamily
                            }
                            text: {
                                if (dev.pairing)   return "󰅖"
                                if (!dev.paired)   return "󰌑"
                                if (dev.connected) return "󰂲"
                                return "󰂱"
                            }
                            color: {
                                if (dev.pairing)   return root.colYellow
                                if (!dev.paired)   return root.colLBlue
                                if (dev.connected) return root.colRed
                                return root.colGreen
                            }
                            ToolTip.visible: actHover.containsMouse
                            ToolTip.delay:   400
                            ToolTip.text: {
                                if (dev.pairing)   return "Cancel pairing"
                                if (!dev.paired)   return "Pair"
                                if (dev.connected) return "Disconnect"
                                return "Connect"
                            }
                        }
                        MouseArea {
                            id: actHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                                                if (dev.pairing)    {
                                    dev.cancelPair()
                                    return
                                }
                                                                if (!dev.paired)    {
                                    dev.pair()
                                    return
                                }
                                if (dev.connected)    dev.disconnect()
                                else                  dev.connect()
                            }
                        }
                    }
                }

                // ── ПКМ — контекстное меню ────────────────────────────────
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.RightButton
                    onClicked: (mouse) => ctxMenu.popup()
                }

                Menu {
                    id: ctxMenu

                    width: 180

                    background: Rectangle {
                        color: root.colBg
                        border.color: root.colMuted
                        border.width: 1
                        radius: 7
                    }

                    // Connect / Disconnect (только если спарено)
                    MenuItem {
                        visible:        dev.paired
                        height:         visible ? 34 : 0
                        text:           dev.connected ? "Disconnect" : "Connect"
                        contentItem: Text {
                            leftPadding: 12
                            text:  parent.text
                                                        font {
                                pixelSize: root.fontSize - 1
                                family: root.fontFamily
                            }
                            color: dev.connected ? root.colRed : root.colGreen
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.hovered ? root.colMuted : "transparent"
                            radius: 5
                            implicitHeight: 34
                        }
                        onTriggered: dev.connected ? dev.disconnect() : dev.connect()
                    }

                    // Trust / Untrust
                    MenuItem {
                        height: 34
                        text:   dev.trusted ? "Untrust" : "Trust"
                        contentItem: Text {
                            leftPadding: 12
                            text:  parent.text
                                                        font {
                                pixelSize: root.fontSize - 1
                                family: root.fontFamily
                            }
                            color: dev.trusted ? root.colYellow : root.colCyan
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.hovered ? root.colMuted : "transparent"
                            radius: 5
                            implicitHeight: 34
                        }
                        onTriggered: dev.trusted = !dev.trusted
                    }

                    MenuSeparator {
                        contentItem: Rectangle {
                            implicitHeight: 1
                            implicitWidth: parent.width
                            color: root.colMuted
                            opacity: 0.4
                        }
                    }

                    // Pair / Forget
                    MenuItem {
                        height: 34
                        text:   dev.paired ? "Forget device" : "Pair"
                        contentItem: Text {
                            leftPadding: 12
                            text:  parent.text
                                                        font {
                                pixelSize: root.fontSize - 1
                                family: root.fontFamily
                            }
                            color: dev.paired ? root.colRed : root.colLBlue
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.hovered ? root.colMuted : "transparent"
                            radius: 5
                            implicitHeight: 34
                        }
                        onTriggered: dev.paired ? dev.forget() : dev.pair()
                    }
                }

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
        }

        Item { height: 8 }
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    function stateLabel(state) {
        switch (state) {
            case BluetoothDeviceState.Connected:     return "Connected"
            case BluetoothDeviceState.Connecting:    return "Connecting..."
            case BluetoothDeviceState.Disconnecting: return "Disconnecting..."
            default:                                 return "Disconnected"
        }
    }

    function batIcon(pct) {
        if (pct >= 90) return "󰁹"
        if (pct >= 70) return "󰂁"
        if (pct >= 50) return "󰁾"
        if (pct >= 30) return "󰁼"
        if (pct >= 10) return "󰁺"
        return "󰂃"
    }

    function iconFor(name) {
        const m = {
            "audio-headset":    "󰋋",
            "audio-headphones": "󰋎",
            "audio-speakers":   "󰓃",
            "input-keyboard":   "󰌌",
            "input-mouse":      "󰍽",
            "input-gaming":     "󰊗",
            "phone":            "󰏲",
            "computer":         "󰨖",
        }
        return m[name] ?? "󰂯"
    }
}