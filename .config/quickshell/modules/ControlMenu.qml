// modules/ControlMenu.qml
// Control Centre — PanelWindow (левый край экрана).
// Открывается: клик на ✦ в топбаре ИЛИ SUPER+SPACE (GlobalShortcut в shell.qml).

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs.modules

PanelWindow {
    id: cc

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

    // ── Сеть ─────────────────────────────────────────────────────────────
    property bool   netConnected: false
    property string netType:      ""
    property string netSSID:      ""
    property string netIP:        ""

    // ── Уведомления ───────────────────────────────────────────────────────
    property var notifService: null
    readonly property int unreadCount: notifService ? notifService.unreadCount : 0

    // ── Позиционирование ──────────────────────────────────────────────────
    // PanelWindow — позиционируется через anchors { left/top/bottom }
    // Ширина фиксирована, высота — весь экран минус бар (через Layout).

    // ── Публичное API ─────────────────────────────────────────────────────
    function toggle() {
        if (visible) {
            closeAnim.restart()
        } else {
            visible = true
        }
    }

    // ── Геометрия ─────────────────────────────────────────────────────────
    anchors { left: true; top: true; bottom: true }
    implicitWidth: 300
    visible: false
    color:   cc.colBg

    // ── Анимация ──────────────────────────────────────────────────────────
    onVisibleChanged: {
        if (visible) {
            contentRect.opacity          = 0
            contentRect.anchors.topMargin = -12
            openAnim.restart()
        }
    }

    ParallelAnimation {
        id: openAnim
                NumberAnimation {
            target: contentRect
            property: "opacity"
            to: 1.0
            duration: 180
            easing.type: Easing.OutCubic
        }
                NumberAnimation {
            target: contentRect
            property: "anchors.topMargin"
            to: 0
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    ParallelAnimation {
        id: closeAnim
                NumberAnimation {
            target: contentRect
            property: "opacity"
            to: 0.0
            duration: 130
            easing.type: Easing.InCubic
        }
                NumberAnimation {
            target: contentRect
            property: "anchors.topMargin"
            to: -12
            duration: 130
            easing.type: Easing.InCubic
        }
        onFinished: cc.visible = false
    }

    // ── Клик вне окна — закрыть ───────────────────────────────────────────
    // ПРИМЕЧАНИЕ: FloatingWindow не имеет встроенного "закрыть при потере фокуса".
    // Используем WlrKeyboardFocus или просто оставляем закрытие по повторному клику на ✦.

    // ══════════════════════════════════════════════════════════════════════
    // ВНУТРЕННЕЕ СОСТОЯНИЕ
    // ══════════════════════════════════════════════════════════════════════

    property int activeTab: 0

    // ── Uptime ────────────────────────────────────────────────────────────
    property string uptimeStr: "--"

    Process {
        id: uptimeProc
        command: ["cat", "/proc/uptime"]
        stdout: SplitParser {
            onRead: data => {
                var secs = parseInt(data.trim().split(" ")[0]) || 0
                var d = Math.floor(secs / 86400)
                var h = Math.floor((secs % 86400) / 3600)
                var m = Math.floor((secs % 3600) / 60)
                if (d > 0)      cc.uptimeStr = d + "d " + h + "h " + m + "m"
                else if (h > 0) cc.uptimeStr = h + "h " + m + "m"
                else            cc.uptimeStr = m + "m"
            }
        }
        Component.onCompleted: running = true
    }

        Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: uptimeProc.running = true
    }

    readonly property string facePath: "file://" + Quickshell.env("HOME") + "/.face"
    property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"

    // ── Power Profiles (нативный QS API) ─────────────────────────────────
    // PowerProfiles.activeProfile — readable/writable PowerProfile enum
    // Значения: PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance
    // PowerProfiles.hasPerformanceProfile — false если Performance недоступен

    function setPowerProfile(profile) {
        PowerProfiles.activeProfile = profile
    }

    // ── Battery ───────────────────────────────────────────────────────────
    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool hasBattery: battery.isLaptopBattery

    // ══════════════════════════════════════════════════════════════════════
    // UI
    // ══════════════════════════════════════════════════════════════════════
    Rectangle {
        id: contentRect
        anchors.fill: parent
        color:   cc.colBg
        border.color: cc.colBlue
        border.width: 1
        clip: true
        opacity: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Tab bar ───────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 42
                color: cc.colBg

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: cc.colMuted
                    opacity: 0.4
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 0

                    Repeater {
                        model: [
                            { icon: "󰋑", label: "Main"    },
                            { icon: "󰂚", label: "Notifs"  },
                            { icon: "󰓅", label: "Perf"    }
                        ]

                        Item {
                            Layout.fillWidth: true
                            height: 42
                            readonly property bool isActive: cc.activeTab === index

                            Rectangle {
                                anchors.fill: parent
                                color: isActive
                                    ? Qt.rgba(0.37, 0.51, 0.67, 0.15)
                                    : tabMa.containsMouse ? Qt.rgba(1,1,1,0.04) : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            Rectangle {
                                visible: isActive
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                height: 2
                                color: cc.colCyan
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 1

                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth:  tabIconTxt.implicitWidth
                                    implicitHeight: tabIconTxt.implicitHeight

                                    Text {
                                        id: tabIconTxt
                                        text: modelData.icon
                                                                                font {
                                            pixelSize: cc.fontSize
                                            family: cc.fontFamily
                                        }
                                        color: isActive ? cc.colCyan : cc.colMuted
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }

                                    // Бейдж непрочитанных (только Notifs)
                                    Rectangle {
                                        visible: index === 1 && cc.unreadCount > 0
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: -3
                                        anchors.rightMargin: -5
                                        width: Math.max(14, badgeTxt.implicitWidth + 4)
                                        height: 14
                                        color: cc.colRed

                                        Text {
                                            id: badgeTxt
                                            anchors.centerIn: parent
                                            text: cc.unreadCount > 9 ? "9+" : cc.unreadCount
                                                                                        font {
                                                pixelSize: 8
                                                family: cc.fontFamily
                                                bold: true
                                            }
                                            color: "#eceff4"
                                        }
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.label
                                                                        font {
                                        pixelSize: cc.fontSize - 5
                                        family: cc.fontFamily
                                    }
                                    color: isActive ? cc.colFg : cc.colMuted
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                            }

                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cc.activeTab = index
                            }
                        }
                    }
                }
            }

            // ── Контент вкладок ───────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ══════════════════════════════════════════════════════════
                // ВКЛАДКА 0: MAIN
                // ══════════════════════════════════════════════════════════
                ScrollView {
                    id: mainScroll
                    anchors.fill: parent
                    visible: cc.activeTab === 0
                    contentWidth: availableWidth
                    clip: true
                    ScrollBar.vertical.policy:   ScrollBar.AsNeeded
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                        width: parent.width
                        spacing: 0

                        // ── Профиль пользователя ──────────────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            height: 80
                            color: Qt.rgba(0.23, 0.27, 0.31, 0.6)
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 14

                                Rectangle {
                                    width: 52
                                    height: 52
                                    color: cc.colMuted
                                    clip: true
                                    radius: 50
                                    
                                    Image {
                                        id: faceImg
                                        anchors.fill: parent
                                        source: cc.facePath
                                        fillMode: Image.PreserveAspectCrop
                                        visible: status === Image.Ready
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: faceImg.status !== Image.Ready
                                        text: "󰀄"
                                                                                font {
                                            pixelSize: 28
                                            family: cc.fontFamily
                                        }
                                        color: cc.colFg
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: cc.userName
                                                                                font {
                                            pixelSize: cc.fontSize
                                            family: cc.fontFamily
                                            bold: true
                                        }
                                        color: cc.colFg
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    RowLayout {
                                        spacing: 6
                                                                                Text {
                                            text: "󰅐"
                                                                                        font {
                                                pixelSize: cc.fontSize - 3
                                                family: cc.fontFamily
                                            }
                                            color: cc.colMuted
                                        }
                                                                                Text {
                                            text: "up " + cc.uptimeStr
                                                                                        font {
                                                pixelSize: cc.fontSize - 3
                                                family: cc.fontFamily
                                            }
                                            color: cc.colMuted
                                        }
                                    }
                                }
                            }
                        }

                        CcDivider {}

                        // ── SystemTray ────────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: trayContent.implicitHeight + 16
                            color: Qt.rgba(0.18, 0.21, 0.25, 0.4)
                            visible: SystemTray.items.count > 0

                            ColumnLayout {
                                id: trayContent
                                                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    margins: 12
                                }
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    text: "󰀻  System Tray"
                                                                        font {
                                        pixelSize: cc.fontSize - 3
                                        family: cc.fontFamily
                                        bold: true
                                    }
                                    color: cc.colMuted
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Repeater {
                                        model: SystemTray.items

                                        delegate: Item {
                                            required property var modelData
                                            width: 28
                                            height: 28

                                            // Иконка — icon это string, прямо Image.source
                                            Image {
                                                id: trayIcon
                                                anchors.fill: parent
                                                anchors.margins: 3
                                                source: modelData.icon
                                                fillMode: Image.PreserveAspectFit
                                                smooth: true
                                                visible: status === Image.Ready
                                            }

                                            // Fallback буква
                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.margins: 2
                                                visible: trayIcon.status !== Image.Ready
                                                color: Qt.rgba(0.37, 0.51, 0.67, 0.2)
                                                border.color: cc.colMuted
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: (modelData.title || "?")[0].toUpperCase()
                                                    font {
                                                        pixelSize: cc.fontSize - 4
                                                        family: cc.fontFamily
                                                        bold: true
                                                    }
                                                    color: cc.colLBlue
                                                }
                                            }

                                            // Hover highlight
                                            Rectangle {
                                                anchors.fill: parent
                                                color: trayItemMa.containsMouse
                                                    ? Qt.rgba(1,1,1,0.08) : "transparent"
                                                border.color: trayItemMa.containsMouse
                                                    ? cc.colMuted : "transparent"
                                                border.width: 1
                                                Behavior on color { ColorAnimation { duration: 80 } }
                                            }

                                            ToolTip.visible: trayItemMa.containsMouse
                                            ToolTip.text:    modelData.tooltipTitle || modelData.title || ""
                                            ToolTip.delay:   500

                                            MouseArea {
                                                id: trayItemMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape:  Qt.PointingHandCursor
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                                onClicked: mouse => {
                                                    if (mouse.button === Qt.LeftButton) {
                                                        // Если только меню — сразу показываем его
                                                        if (modelData.onlyMenu) {
                                                            modelData.display(cc, mouse.x, mouse.y)
                                                        } else {
                                                            modelData.activate()
                                                        }
                                                    } else {
                                                        // ПКМ — платформенное меню через display()
                                                        // display(parentWindow, relativeX, relativeY)
                                                        // parentWindow — FloatingWindow (cc)
                                                        // координаты относительно окна cc
                                                        var pos = trayItemMa.mapToItem(contentRect, mouse.x, mouse.y)
                                                        modelData.display(cc, pos.x, pos.y)
                                                    }
                                                }

                                                onWheel: event => {
                                                    modelData.scroll(event.angleDelta.y > 0 ? 1 : -1, false)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        CcDivider { visible: SystemTray.items.count > 0 }

                        // ── Wi-Fi ─────────────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            height: 56
                            color: Qt.rgba(0.18, 0.21, 0.25, 0.4)

                            RowLayout {
                                                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    margins: 12
                                }
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    text: cc.netConnected ? (cc.netType === "ethernet" ? "󰛳" : "󰖩") : "󰖪"
                                                                        font {
                                        pixelSize: cc.fontSize + 2
                                        family: cc.fontFamily
                                    }
                                    color: cc.netConnected ? cc.colCyan : cc.colMuted
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: cc.netConnected
                                            ? (cc.netType === "ethernet" ? "Ethernet" : cc.netSSID)
                                            : "Disconnected"
                                                                                font {
                                            pixelSize: cc.fontSize - 1
                                            family: cc.fontFamily
                                            bold: true
                                        }
                                        color: cc.netConnected ? cc.colFg : cc.colMuted
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        visible: cc.netConnected && cc.netIP !== ""
                                        text: cc.netIP
                                                                                font {
                                            pixelSize: cc.fontSize - 5
                                            family: cc.fontFamily
                                        }
                                        color: cc.colMuted
                                    }
                                }

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: cc.netConnected ? cc.colGreen : cc.colRed

                                    SequentialAnimation on opacity {
                                        running: !cc.netConnected
                                        loops: Animation.Infinite
                                                                                NumberAnimation {
                                            to: 0.2
                                            duration: 800
                                        }
                                                                                NumberAnimation {
                                            to: 1.0
                                            duration: 800
                                        }
                                    }
                                }
                            }
                        }

                        CcDivider {}

                        // ── Bluetooth ─────────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: btModule.implicitHeight
                            color: Qt.rgba(0.18, 0.21, 0.25, 0.4)

                            BluetoothModule {
                                id: btModule
                                                                anchors {
                                    left: parent.left
                                    right: parent.right
                                }
                                fontFamily: cc.fontFamily
                                fontSize: cc.fontSize
                                colBg: cc.colBg
                                colFg: cc.colFg
                                colMuted: cc.colMuted
                                colCyan: cc.colCyan
                                colBlue: cc.colBlue
                                colLBlue: cc.colLBlue
                                colGreen: cc.colGreen
                                colRed: cc.colRed
                                colYellow: cc.colYellow
                            }
                        }

                        CcDivider {}

                        // ── Battery ───────────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 64
                            visible: cc.hasBattery
                            color: Qt.rgba(0.18, 0.21, 0.25, 0.4)

                            ColumnLayout {
                                                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    margins: 12
                                }
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: {
                                            var p = Math.round(cc.battery.percentage * 100)
                                            var s = cc.battery.state
                                            if (s === UPowerDeviceState.Charging) {
                                                if (p > 80) return "󰂊"
                                                if (p > 60) return "󰂉"
                                                if (p > 40) return "󰂈"
                                                if (p > 20) return "󰂆"
                                                return "󰢜"
                                            }
                                            if (s === UPowerDeviceState.FullyCharged) return "󰁹"
                                            if (p > 80) return "󰂀"
                                            if (p > 60) return "󰁿"
                                            if (p > 40) return "󰁾"
                                            if (p > 20) return "󰁽"
                                            return "󰁻"
                                        }
                                                                                font {
                                            pixelSize: cc.fontSize + 4
                                            family: cc.fontFamily
                                        }
                                        color: cc.battery.percentage <= 0.15 ? cc.colRed
                                             : cc.battery.percentage <= 0.40 ? cc.colYellow
                                             : cc.colGreen
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        RowLayout {
                                            spacing: 6
                                                                                        Text {
                                                text: "Battery"
                                                                                                font {
                                                    pixelSize: cc.fontSize - 1
                                                    family: cc.fontFamily
                                                    bold: true
                                                }
                                                color: cc.colFg
                                            }
                                            Text {
                                                text: Math.round(cc.battery.percentage * 100) + "%"
                                                                                                font {
                                                    pixelSize: cc.fontSize - 1
                                                    family: cc.fontFamily
                                                }
                                                color: cc.battery.percentage <= 0.15 ? cc.colRed
                                                     : cc.battery.percentage <= 0.40 ? cc.colYellow
                                                     : cc.colGreen
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 4
                                            color: cc.colMuted
                                            opacity: 0.5

                                            Rectangle {
                                                width: parent.width * Math.min(cc.battery.percentage, 1.0)
                                                height: parent.height
                                                color: cc.battery.percentage <= 0.15 ? cc.colRed
                                                     : cc.battery.percentage <= 0.40 ? cc.colYellow
                                                     : cc.colGreen
                                                Behavior on width { NumberAnimation { duration: 400 } }
                                            }
                                        }

                                        Text {
                                            text: {
                                                var s = cc.battery.state
                                                if (s === UPowerDeviceState.Charging)     return "Charging"
                                                if (s === UPowerDeviceState.FullyCharged) return "Full"
                                                if (s === UPowerDeviceState.Discharging)  return "On battery"
                                                return ""
                                            }
                                                                                        font {
                                                pixelSize: cc.fontSize - 5
                                                family: cc.fontFamily
                                            }
                                            color: cc.colMuted
                                        }
                                    }
                                }
                            }
                        }

                        CcDivider { visible: cc.hasBattery }

                        // ── Power Profiles ────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: ppContent.implicitHeight + 20
                            color: Qt.rgba(0.18, 0.21, 0.25, 0.4)

                            ColumnLayout {
                                id: ppContent
                                                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    margins: 12
                                }
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                                                        Text {
                                        text: "󱐋"
                                                                                font {
                                            pixelSize: cc.fontSize + 2
                                            family: cc.fontFamily
                                        }
                                        color: cc.colYellow
                                    }
                                                                        Text {
                                        text: "Power Profile"
                                                                                font {
                                            pixelSize: cc.fontSize - 1
                                            family: cc.fontFamily
                                            bold: true
                                        }
                                        color: cc.colFg
                                        Layout.fillWidth: true
                                    }

                                    // Busy spinner убран — PowerProfiles.activeProfile
                                    // обновляется реактивно, задержки нет
                                }

                                // Три кнопки профиля
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Repeater {
                                        model: [
                                            { profile: PowerProfile.PowerSaver,  label: "󰌪 Saver",   color: "#a3be8c" },
                                            { profile: PowerProfile.Balanced,     label: "󰁾 Balance", color: "#81a1c1" },
                                            { profile: PowerProfile.Performance,  label: "󱐋 Perf",    color: "#ebcb8b" }
                                        ]

                                        Item {
                                            Layout.fillWidth: true
                                            height: 28

                                            // Performance недоступен если hasPerformanceProfile = false
                                            readonly property bool unavailable:
                                                modelData.profile === PowerProfile.Performance
                                                && !PowerProfiles.hasPerformanceProfile

                                            readonly property bool isActive:
                                                PowerProfiles.activeProfile === modelData.profile

                                            Rectangle {
                                                anchors.fill: parent
                                                color: isActive
                                                    ? Qt.rgba(
                                                        Qt.color(modelData.color).r,
                                                        Qt.color(modelData.color).g,
                                                        Qt.color(modelData.color).b,
                                                        0.2)
                                                    : ppBtnMa.containsMouse
                                                        ? Qt.rgba(1, 1, 1, 0.05)
                                                        : Qt.rgba(0, 0, 0, 0.15)
                                                border.color: isActive ? modelData.color : cc.colMuted
                                                border.width: 1
                                                opacity: unavailable ? 0.3 : 1.0
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                font.pixelSize: cc.fontSize - 4
                                                font.family: cc.fontFamily
                                                font.bold: isActive
                                                color: isActive ? modelData.color : cc.colMuted
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                            }

                                            MouseArea {
                                                id: ppBtnMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                enabled: !isActive && !unavailable
                                                onClicked: cc.setPowerProfile(modelData.profile)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item { height: 8 }
                    }
                }

                // ══════════════════════════════════════════════════════════
                // ВКЛАДКА 1: УВЕДОМЛЕНИЯ
                // ══════════════════════════════════════════════════════════
                NotificationHistory {
                    anchors.fill: parent
                    visible: cc.activeTab === 1
                    notifService: cc.notifService
                    fontFamily: cc.fontFamily
                    fontSize: cc.fontSize
                    colBg: cc.colBg
                    colFg: cc.colFg
                    colSurface: cc.colSurface
                    colMuted: cc.colMuted
                    colCyan: cc.colCyan
                    colBlue: cc.colBlue
                    colLBlue: cc.colLBlue
                    colGreen: cc.colGreen
                    colRed: cc.colRed
                    colYellow: cc.colYellow
                }

                // ══════════════════════════════════════════════════════════
                // ВКЛАДКА 2: ПРОИЗВОДИТЕЛЬНОСТЬ
                // ══════════════════════════════════════════════════════════
                PerformanceTab {
                    anchors.fill: parent
                    visible:    cc.activeTab === 2
                    isVisible:  cc.activeTab === 2 && cc.visible
                    fontFamily: cc.fontFamily
                    fontSize: cc.fontSize
                    colBg: cc.colBg
                    colFg: cc.colFg
                    colSurface: cc.colSurface
                    colMuted: cc.colMuted
                    colCyan: cc.colCyan
                    colBlue: cc.colBlue
                    colLBlue: cc.colLBlue
                    colGreen: cc.colGreen
                    colRed: cc.colRed
                    colYellow: cc.colYellow
                }
            }
        }
    }

    // ── Переиспользуемые компоненты ───────────────────────────────────────
    component CcDivider: Rectangle {
        Layout.fillWidth: true
        height: 1
        color: cc.colMuted
        opacity: 0.25
    }
}
