// modules/CalendarModule.qml
import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: calPopup

    // ── Theme ─────────────────────────────────────────────────────────────
    property string fontFamily: "Monaspace Krypton Medium"
    property int fontSize: 16
    property color colBg: "#2e3440"
    property color colFg: "#d8dee9"
    property color colMuted: "#4c566a"
    property color colCyan: "#8fbcbb"
    property color colBlue: "#5e81ac"
    property color colLBlue: "#81a1c1"
    property color colGreen: "#a3be8c"
    property color colRed: "#bf616a"
    property color colYellow: "#ebcb8b"
    // ── Calendar state ────────────────────────────────────────────────────
    property int viewYear: _today.getFullYear()
    property int viewMonth: _today.getMonth()
    property date _today: new Date()
    // ── Tab state ─────────────────────────────────────────────────────────
    property int activeTab: 0
    // ── Weather — глобальный id из shell.qml ──────────────────────────────
    // Не пробрасываем через свойство — обращаемся напрямую по id "weather"
    // который объявлен в ShellRoot { Weather { id: weather } }
    readonly property var wx: typeof weather !== "undefined" ? weather : null

    function monthName(m) {
        return ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"][m];
    }

    function isoWeek(d) {
        var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        var y = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil((((t - y) / 8.64e+07) + 1) / 7);
    }

    width: 300
    height: contentRect.implicitHeight
    color: "transparent"
    visible: false
    onVisibleChanged: {
        if (visible) {
            contentRect.scale = 0.94;
            contentRect.opacity = 0;
            appearAnim.restart();
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: calPopup._today = new Date()
    }

    ParallelAnimation {
        id: appearAnim

        NumberAnimation {
            target: contentRect
            property: "scale"
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: contentRect
            property: "opacity"
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }

    }

    Rectangle {
        id: contentRect

        anchors.fill: parent
        implicitHeight: mainCol.implicitHeight + 16
        color: calPopup.colBg
        border.color: calPopup.colBlue
        border.width: 2
        radius: 10
        transformOrigin: Item.Top
        clip: true

        ColumnLayout {
            id: mainCol

            spacing: 8

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }

            // ── Tab bar ───────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: ["󰸗  Calendar", "󰖐  Weather"]

                    delegate: Item {
                        property bool isActive: calPopup.activeTab === index

                        Layout.fillWidth: true
                        height: 30

                        Rectangle {
                            anchors.fill: parent
                            color: isActive ? Qt.rgba(0.37, 0.51, 0.67, 0.2) : tabMa.containsMouse ? Qt.rgba(0.3, 0.35, 0.42, 0.3) : "transparent"
                            radius: 6

                            Rectangle {
                                visible: isActive
                                height: 2
                                radius: 1
                                color: calPopup.colBlue

                                anchors {
                                    bottom: parent.bottom
                                    left: parent.left
                                    right: parent.right
                                    leftMargin: 8
                                    rightMargin: 8
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }

                            }

                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: isActive ? calPopup.colFg : calPopup.colMuted

                            font {
                                pixelSize: calPopup.fontSize - 3
                                family: calPopup.fontFamily
                                bold: isActive
                            }

                        }

                        MouseArea {
                            id: tabMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calPopup.activeTab = index
                        }

                    }

                }

            }

            // ── Divider ───────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: calPopup.colMuted
                opacity: 0.35
            }

            // ══════════════════════════════════════════════════════════════
            // TAB 0: Calendar
            // ══════════════════════════════════════════════════════════════
            ColumnLayout {
                visible: calPopup.activeTab === 0
                Layout.fillWidth: true
                spacing: 8

                Text {
                    id: bigClock

                    Layout.alignment: Qt.AlignHCenter
                    color: calPopup.colFg
                    text: Qt.formatDateTime(new Date(), "HH:mm")

                    font {
                        pixelSize: calPopup.fontSize + 20
                        family: calPopup.fontFamily
                        bold: true
                    }

                    Timer {
                        interval: 1000
                        running: calPopup.visible && calPopup.activeTab === 0
                        repeat: true
                        onTriggered: bigClock.text = Qt.formatDateTime(new Date(), "HH:mm")
                    }

                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    color: calPopup.colFg
                    text: Qt.formatDateTime(calPopup._today, "dddd, d MMMM yyyy")

                    font {
                        pixelSize: calPopup.fontSize - 2
                        family: calPopup.fontFamily
                    }

                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: calPopup.colMuted
                    opacity: 0.35
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    NavBtn {
                        btnText: "󰍞"
                        onClicked: {
                            if (calPopup.viewMonth === 0) {
                                calPopup.viewMonth = 11;
                                calPopup.viewYear--;
                            } else {
                                calPopup.viewMonth--;
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: monthName(calPopup.viewMonth) + "  " + calPopup.viewYear
                        color: calPopup.colFg

                        font {
                            pixelSize: calPopup.fontSize
                            family: calPopup.fontFamily
                            bold: true
                        }

                    }

                    NavBtn {
                        btnText: "󰍟"
                        onClicked: {
                            if (calPopup.viewMonth === 11) {
                                calPopup.viewMonth = 0;
                                calPopup.viewYear++;
                            } else {
                                calPopup.viewMonth++;
                            }
                        }
                    }

                    NavBtn {
                        btnText: "󰋮"
                        btnColor: (calPopup.viewMonth === calPopup._today.getMonth() && calPopup.viewYear === calPopup._today.getFullYear()) ? calPopup.colMuted : calPopup.colCyan
                        onClicked: {
                            calPopup.viewMonth = calPopup._today.getMonth();
                            calPopup.viewYear = calPopup._today.getFullYear();
                        }
                    }

                }

                Row {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        width: 28
                        horizontalAlignment: Text.AlignHCenter
                        text: "Wk"
                        color: calPopup.colMuted

                        font {
                            pixelSize: calPopup.fontSize - 5
                            family: calPopup.fontFamily
                            bold: true
                        }

                    }

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                        Text {
                            width: (mainCol.width - 24 - 28) / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: calPopup.colFg

                            font {
                                pixelSize: calPopup.fontSize - 4
                                family: calPopup.fontFamily
                                bold: true
                            }

                        }

                    }

                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: 6

                        delegate: Row {
                            id: weekRow

                            property int wi: index
                            property int shift: {
                                var d = new Date(calPopup.viewYear, calPopup.viewMonth, 1);
                                return (d.getDay() + 6) % 7;
                            }
                            property int dim: new Date(calPopup.viewYear, calPopup.viewMonth + 1, 0).getDate()
                            property int firstCellDay: wi * 7 - shift + 1
                            property bool hasAny: firstCellDay <= dim && (firstCellDay + 6) >= 1

                            visible: hasAny
                            spacing: 0

                            Text {
                                width: 28
                                height: 26
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: "W" + isoWeek(new Date(calPopup.viewYear, calPopup.viewMonth, Math.max(1, weekRow.firstCellDay)))
                                color: calPopup.colMuted

                                font {
                                    pixelSize: calPopup.fontSize - 5
                                    family: calPopup.fontFamily
                                }

                            }

                            Repeater {
                                model: 7

                                delegate: Item {
                                    property int cellDay: weekRow.firstCellDay + index
                                    property bool inMonth: cellDay >= 1 && cellDay <= weekRow.dim
                                    property bool isToday: inMonth && cellDay === calPopup._today.getDate() && calPopup.viewMonth === calPopup._today.getMonth() && calPopup.viewYear === calPopup._today.getFullYear()

                                    width: (mainCol.width - 24 - 28) / 7
                                    height: 26

                                    Rectangle {
                                        visible: isToday
                                        anchors.centerIn: parent
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: Qt.rgba(0.37, 0.51, 0.67, 0.3)
                                        border.color: calPopup.colBlue
                                        border.width: 1
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: inMonth
                                        text: cellDay
                                        color: isToday ? calPopup.colLBlue : calPopup.colFg

                                        font {
                                            pixelSize: calPopup.fontSize - 3
                                            family: calPopup.fontFamily
                                            bold: isToday
                                        }

                                    }

                                }

                            }

                        }

                    }

                }

            }

            // ══════════════════════════════════════════════════════════════
            // TAB 1: Weather
            // ══════════════════════════════════════════════════════════════
            ColumnLayout {
                visible: calPopup.activeTab === 1
                Layout.fillWidth: true
                spacing: 12

                Text {
                    visible: calPopup.wx === null
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 16
                    Layout.bottomMargin: 16
                    text: "Weather unavailable"
                    color: calPopup.colFg

                    font {
                        pixelSize: calPopup.fontSize - 1
                        family: calPopup.fontFamily
                    }

                }

                ColumnLayout {
                    visible: calPopup.wx !== null
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: calPopup.wx ? (calPopup.wx.cityName + ", " + calPopup.wx.country) : ""
                        color: calPopup.colFg

                        font {
                            pixelSize: calPopup.fontSize - 2
                            family: calPopup.fontFamily
                        }

                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Text {
                            text: calPopup.wx ? calPopup.wx.icon : ""
                            font.pixelSize: calPopup.fontSize + 20
                        }

                        Text {
                            text: calPopup.wx ? calPopup.wx.temperature : "--"
                            color: {
                                if (!calPopup.wx)
                                    return calPopup.colFg;

                                var t = parseInt(calPopup.wx.temperature);
                                if (t >= 30)
                                    return calPopup.colRed;

                                if (t >= 20)
                                    return calPopup.colYellow;

                                if (t >= 10)
                                    return calPopup.colCyan;

                                return calPopup.colLBlue;
                            }

                            font {
                                pixelSize: calPopup.fontSize + 20
                                family: calPopup.fontFamily
                                bold: true
                            }

                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        height: 1
                        color: calPopup.colMuted
                        opacity: 0.35
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 0

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰖝"
                                color: calPopup.colCyan

                                font {
                                    pixelSize: calPopup.fontSize + 4
                                    family: calPopup.fontFamily
                                }

                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: calPopup.wx ? calPopup.wx.humidity : "--"
                                color: calPopup.colFg

                                font {
                                    pixelSize: calPopup.fontSize - 1
                                    family: calPopup.fontFamily
                                    bold: true
                                }

                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Humidity"
                                color: calPopup.colFg

                                font {
                                    pixelSize: calPopup.fontSize - 4
                                    family: calPopup.fontFamily
                                }

                            }

                        }

                        Rectangle {
                            width: 1
                            height: 48
                            color: calPopup.colMuted
                            opacity: 0.35
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰈐"
                                color: calPopup.colLBlue

                                font {
                                    pixelSize: calPopup.fontSize + 4
                                    family: calPopup.fontFamily
                                }

                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: calPopup.wx ? calPopup.wx.windSpeed : "--"
                                color: calPopup.colFg

                                font {
                                    pixelSize: calPopup.fontSize - 1
                                    family: calPopup.fontFamily
                                    bold: true
                                }

                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Wind"
                                color: calPopup.colFg

                                font {
                                    pixelSize: calPopup.fontSize - 4
                                    family: calPopup.fontFamily
                                }

                            }

                        }

                    }

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        width: refreshBtn.implicitWidth + 16
                        height: 26

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: refreshMa.containsMouse ? Qt.rgba(0.37, 0.51, 0.67, 0.25) : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }

                            }

                        }

                        Text {
                            id: refreshBtn

                            anchors.centerIn: parent
                            text: "󰑓  Refresh"
                            color: refreshMa.containsMouse ? calPopup.colCyan : calPopup.colFg

                            font {
                                pixelSize: calPopup.fontSize - 3
                                family: calPopup.fontFamily
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }

                            }

                        }

                        MouseArea {
                            id: refreshMa

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (calPopup.wx) {
                                    calPopup.wx.fetchLocation();
                                }
                            }
                        }

                    }

                }

                Item {
                    height: 4
                }

            }

            Item {
                height: 0
            }

        }

    }

    // ── NavBtn ────────────────────────────────────────────────────────────
    component NavBtn: Item {
        property string btnText: ""
        property color btnColor: calPopup.colFg

        signal clicked()

        width: 28
        height: 28

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: ma.containsMouse ? calPopup.colMuted : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 100
                }

            }

        }

        Text {
            anchors.centerIn: parent
            text: parent.btnText
            color: parent.btnColor

            font {
                pixelSize: calPopup.fontSize
                family: calPopup.fontFamily
            }

        }

        MouseArea {
            id: ma

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }

    }

}
