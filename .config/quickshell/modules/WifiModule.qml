// modules/WifiModule.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PopupWindow {
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

    // ── Network state (пробрасывается из shell.qml) ───────────────────────
    property bool   netConnected: false
    property string netType:      ""   // "wifi" | "ethernet" | ""
    property string netSSID:      ""
    property string netIP:        ""

    // ── Internal state ────────────────────────────────────────────────────
    property bool   scanning:     false
    property var    networks:     []
    property string connectingTo: ""
    property string errorMsg:     ""

    // ── Размер / стиль — идентично CalendarModule ─────────────────────────
    width:   320
    height:  contentRect.implicitHeight
    color:   "transparent"
    visible: false

    onVisibleChanged: {
        if (visible) {
            contentRect.scale   = 0.94
            contentRect.opacity = 0
            appearAnim.restart()
            startScan()
            pwdRow.visible    = false
            pwdRow.targetSSID = ""
            pwdInput.text     = ""
            errorMsg          = ""
        }
    }

    ParallelAnimation {
        id: appearAnim
        NumberAnimation { target: contentRect; property: "scale";   to: 1; duration: 160; easing.type: Easing.OutCubic }
        NumberAnimation { target: contentRect; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
    }

    // ── Processes ─────────────────────────────────────────────────────────
    Process {
        id: scanProc
        command: ["sh", "-c",
            "nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE dev wifi list 2>/dev/null | sort -t: -k2 -rn"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data || !data.trim()) return
                var parts = data.trim().split(":")
                if (parts.length < 4) return
                var ssid = parts[0]
                if (!ssid) return
                var signal   = parseInt(parts[1]) || 0
                var security = parts[2] || ""
                var active   = parts[3] === "*"
                var cur = root.networks.slice()
                if (!cur.some(n => n.ssid === ssid)) {
                    cur.push({ ssid, signal, security, active })
                    root.networks = cur
                }
            }
        }

        onRunningChanged: {
            if (!running) root.scanning = false
        }
    }

    Process {
        id: connectProc
        running: false
        onRunningChanged: {
            if (!running) {
                root.connectingTo = ""
                startScan()
            }
        }
        stderr: SplitParser {
            onRead: (data) => {
                if (data && data.trim()) root.errorMsg = data.trim()
            }
        }
    }

    Process {
        id: disconnectProc
        command: ["sh", "-c",
            "nmcli dev disconnect $(nmcli -t -f DEVICE,TYPE,STATE dev | grep ':connected' | cut -d: -f1 | head -1)"]
        running: false
        onRunningChanged: {
            if (!running) startScan()
        }
    }

    Process {
        id: ipRefreshProc
        command: ["sh", "-c", "hostname -i | awk '{print $1}'"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                if (data && data.trim()) root.netIP = data.trim()
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    function startScan() {
        root.networks = []
        root.errorMsg = ""
        if (root.netType === "wifi" || !root.netConnected) {
            root.scanning = true
            scanProc.running = true
        }
        if (root.netType === "ethernet") {
            ipRefreshProc.running = true
        }
    }

    function connectTo(ssid, pwd) {
        root.connectingTo = ssid
        root.errorMsg = ""
        connectProc.command = pwd
            ? ["sh", "-c", "nmcli dev wifi connect " + JSON.stringify(ssid) + " password " + JSON.stringify(pwd)]
            : ["sh", "-c", "nmcli dev wifi connect " + JSON.stringify(ssid)]
        connectProc.running = true
    }

    function signalIcon(sig) {
        if (sig > 75) return "󰤨"
        if (sig > 50) return "󰤥"
        if (sig > 25) return "󰤢"
        return "󰤟"
    }

    // ── UI ────────────────────────────────────────────────────────────────
    Rectangle {
        id: contentRect
        anchors.fill: parent
        implicitHeight: mainCol.implicitHeight + 16
        color:        root.colBg
        border.color: root.colBlue
        border.width: 2
        radius:       10
        transformOrigin: Item.Top
        clip: true

        ColumnLayout {
            id: mainCol
            spacing: 8
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }

            // ── Заголовок ─────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: {
                        if (!root.netConnected)          return "󰖪  Network"
                        if (root.netType === "ethernet") return "󰛳  Ethernet"
                        return "󰖩  Wi-Fi"
                    }
                    font { pixelSize: root.fontSize; family: root.fontFamily; bold: true }
                    color: root.netConnected ? root.colCyan : root.colMuted
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: root.netType === "wifi" || !root.netConnected
                    text: root.scanning ? "󰑐" : "󰑓"
                    font { pixelSize: root.fontSize; family: root.fontFamily }
                    color: refreshMa.containsMouse ? root.colLBlue : root.colMuted

                    RotationAnimation on rotation {
                        running: root.scanning
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 900
                    }

                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startScan()
                    }
                }
            }

            // ── Divider ───────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1; color: root.colMuted; opacity: 0.35
            }

            // ══════════════════════════════════════════════════════════════
            // ETHERNET
            // ══════════════════════════════════════════════════════════════
            ColumnLayout {
                visible: root.netConnected && root.netType === "ethernet"
                Layout.fillWidth: true
                spacing: 10

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14

                    Text {
                        text: "󰛳"
                        font { pixelSize: root.fontSize + 24; family: root.fontFamily }
                        color: root.colGreen
                    }

                    ColumnLayout {
                        spacing: 3

                        Text {
                            text: "Connected"
                            font { pixelSize: root.fontSize; family: root.fontFamily; bold: true }
                            color: root.colGreen
                        }

                        Text {
                            visible: root.netIP !== ""
                            text: root.netIP
                            font { pixelSize: root.fontSize - 3; family: root.fontFamily }
                            color: root.colFg
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1; color: root.colMuted; opacity: 0.35
                }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    width:  discEthLabel.implicitWidth + 24
                    height: 28

                    Rectangle {
                        anchors.fill: parent; radius: 6
                        color: discEthMa.containsMouse
                            ? Qt.rgba(root.colRed.r, root.colRed.g, root.colRed.b, 0.2)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    Text {
                        id: discEthLabel
                        anchors.centerIn: parent
                        text: "󰅖  Disconnect"
                        font { pixelSize: root.fontSize - 2; family: root.fontFamily }
                        color: discEthMa.containsMouse ? root.colRed : root.colMuted
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: discEthMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: disconnectProc.running = true
                    }
                }

                Item { height: 4 }
            }

            // ══════════════════════════════════════════════════════════════
            // WIFI — активное подключение
            // ══════════════════════════════════════════════════════════════
            Rectangle {
                visible: root.netConnected && root.netType === "wifi"
                Layout.fillWidth: true
                height: connRow.implicitHeight + 12
                radius: 6
                color:  Qt.rgba(root.colGreen.r, root.colGreen.g, root.colGreen.b, 0.08)
                border.color: root.colGreen; border.width: 1

                RowLayout {
                    id: connRow
                    anchors { left: parent.left; right: parent.right;
                              verticalCenter: parent.verticalCenter; margins: 10 }
                    spacing: 8

                    Text {
                        text: signalIcon(100)
                        font { pixelSize: root.fontSize + 2; family: root.fontFamily }
                        color: root.colGreen
                    }

                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: root.netSSID || "Connected"
                            font { pixelSize: root.fontSize - 1; family: root.fontFamily; bold: true }
                            color: root.colFg; elide: Text.ElideRight
                        }

                        Text {
                            visible: root.netIP !== ""
                            text: root.netIP
                            font { pixelSize: root.fontSize - 5; family: root.fontFamily }
                            color: root.colMuted
                        }
                    }

                    Text {
                        text: "󰅖"
                        font { pixelSize: root.fontSize; family: root.fontFamily }
                        color: discWifiMa.containsMouse ? root.colRed : root.colMuted
                        Behavior on color { ColorAnimation { duration: 100 } }

                        MouseArea {
                            id: discWifiMa
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: disconnectProc.running = true
                        }
                    }
                }
            }

            // ── Нет соединения ────────────────────────────────────────────
            Text {
                visible: !root.netConnected
                Layout.alignment: Qt.AlignHCenter
                text: "󰖪  No connection"
                font { pixelSize: root.fontSize - 1; family: root.fontFamily }
                color: root.colRed
            }

            // ── Список Wi-Fi сетей ────────────────────────────────────────
            ColumnLayout {
                visible: root.netType === "wifi" || !root.netConnected
                Layout.fillWidth: true
                spacing: 2

                Text {
                    visible: root.scanning && root.networks.length === 0
                    Layout.alignment: Qt.AlignHCenter
                    text: "Scanning…"
                    font { pixelSize: root.fontSize - 2; family: root.fontFamily }
                    color: root.colMuted
                }

                Text {
                    visible: !root.scanning && root.networks.length === 0
                    Layout.alignment: Qt.AlignHCenter
                    text: "No networks found"
                    font { pixelSize: root.fontSize - 2; family: root.fontFamily }
                    color: root.colMuted
                }

                Repeater {
                    model: root.networks.slice(0, 8)

                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        height: netRow.implicitHeight + 10
                        radius: 6
                        color: {
                            if (modelData.active)
                                return Qt.rgba(root.colGreen.r, root.colGreen.g, root.colGreen.b, 0.08)
                            if (netItemMa.containsMouse)
                                return Qt.rgba(1, 1, 1, 0.05)
                            return "transparent"
                        }
                        border.color: modelData.active ? root.colGreen : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }

                        RowLayout {
                            id: netRow
                            anchors { left: parent.left; right: parent.right;
                                      verticalCenter: parent.verticalCenter; margins: 8 }
                            spacing: 8

                            Text {
                                text: signalIcon(modelData.signal)
                                font { pixelSize: root.fontSize; family: root.fontFamily }
                                color: modelData.active      ? root.colGreen
                                     : modelData.signal > 66 ? root.colCyan
                                     : modelData.signal > 33 ? root.colYellow
                                     : root.colRed
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.ssid
                                font { pixelSize: root.fontSize - 2; family: root.fontFamily;
                                       bold: modelData.active }
                                color: modelData.active ? root.colGreen : root.colFg
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: modelData.security !== "" && modelData.security !== "--"
                                text: "󰌾"
                                font { pixelSize: root.fontSize - 4; family: root.fontFamily }
                                color: root.colMuted
                            }

                            Text {
                                visible: root.connectingTo === modelData.ssid
                                text: "󰑐"
                                font { pixelSize: root.fontSize - 2; family: root.fontFamily }
                                color: root.colYellow
                                RotationAnimation on rotation {
                                    running: root.connectingTo !== ""
                                    loops: Animation.Infinite
                                    from: 0; to: 360; duration: 900
                                }
                            }

                            Text {
                                text: modelData.signal + "%"
                                font { pixelSize: root.fontSize - 5; family: root.fontFamily }
                                color: root.colMuted
                                Layout.minimumWidth: 32
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        MouseArea {
                            id: netItemMa
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.active) return
                                var secured = modelData.security !== "" && modelData.security !== "--"
                                if (secured) {
                                    pwdRow.targetSSID = modelData.ssid
                                    pwdRow.visible    = true
                                    pwdInput.text     = ""
                                    Qt.callLater(() => {
                                        root.requestActivate()
                                        pwdInput.forceActiveFocus()
                                    })
                                } else {
                                    root.connectTo(modelData.ssid, "")
                                }
                            }
                        }
                    }
                }
            }

            // ── Ввод пароля ───────────────────────────────────────────────
            Rectangle {
                id: pwdRow
                property string targetSSID: ""
                visible: false
                Layout.fillWidth: true
                height: pwdLayout.implicitHeight + 12
                radius: 6
                color:  Qt.rgba(root.colBlue.r, root.colBlue.g, root.colBlue.b, 0.10)
                border.color: root.colBlue; border.width: 1

                RowLayout {
                    id: pwdLayout
                    anchors { left: parent.left; right: parent.right;
                              verticalCenter: parent.verticalCenter; margins: 8 }
                    spacing: 6

                    Text {
                        text: "󰌾"
                        font { pixelSize: root.fontSize - 2; family: root.fontFamily }
                        color: root.colLBlue
                    }

                    TextInput {
                        id: pwdInput
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        focus: true
                        font { pixelSize: root.fontSize - 2; family: root.fontFamily }
                        color: root.colFg
                        selectionColor: root.colBlue

                        Keys.onReturnPressed: {
                            root.connectTo(pwdRow.targetSSID, pwdInput.text)
                            pwdRow.visible = false; pwdInput.text = ""
                        }
                        Keys.onEscapePressed: {
                            pwdRow.visible = false; pwdInput.text = ""
                        }
                    }

                    Item {
                        width: 28; height: 28

                        Rectangle {
                            anchors.fill: parent; radius: 6
                            color: connectBtnMa.containsMouse ? root.colBlue : root.colMuted
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        Text {
                            anchors.centerIn: parent; text: "󰌑"
                            font { pixelSize: root.fontSize; family: root.fontFamily }
                            color: root.colFg
                        }

                        MouseArea {
                            id: connectBtnMa
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.connectTo(pwdRow.targetSSID, pwdInput.text)
                                pwdRow.visible = false; pwdInput.text = ""
                            }
                        }
                    }

                    Text {
                        text: "󰅖"
                        font { pixelSize: root.fontSize; family: root.fontFamily }
                        color: cancelMa.containsMouse ? root.colRed : root.colMuted
                        Behavior on color { ColorAnimation { duration: 100 } }

                        MouseArea {
                            id: cancelMa
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { pwdRow.visible = false; pwdInput.text = "" }
                        }
                    }
                }
            }

            // ── Ошибка ────────────────────────────────────────────────────
            Text {
                visible: root.errorMsg !== ""
                Layout.fillWidth: true
                text: "󰀦  " + root.errorMsg
                font { pixelSize: root.fontSize - 4; family: root.fontFamily }
                color: root.colRed
                wrapMode: Text.WordWrap
            }

            Item { height: 0 }
        }
    }
}
