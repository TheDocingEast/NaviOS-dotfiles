// modules/CalendarModule.qml
import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: calPopup

    // ── Theme ─────────────────────────────────────────────────────────────
    property string fontFamily: "Monaspace Krypton Medium"
    property int    fontSize:   16
    property color  colBg:      "#2e3440"
    property color  colFg:      "#d8dee9"
    property color  colMuted:   "#4c566a"
    property color  colCyan:    "#8fbcbb"
    property color  colBlue:    "#5e81ac"
    property color  colLBlue:   "#81a1c1"
    property color  colRed:     "#bf616a"

    // ── State ─────────────────────────────────────────────────────────────
    property int viewYear:  _today.getFullYear()
    property int viewMonth: _today.getMonth()
    property date _today:   new Date()

    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: calPopup._today = new Date()
    }

    width:   280
    height:  contentRect.implicitHeight
    color:   "transparent"
    visible: false

    // ── Анимация появления ────────────────────────────────────────────────
    onVisibleChanged: {
        if (visible) {
            contentRect.scale   = 0.94
            contentRect.opacity = 0
            appearAnim.restart()
        }
    }
    ParallelAnimation {
        id: appearAnim
        NumberAnimation { target: contentRect; property: "scale";   to: 1.0; duration: 160; easing.type: Easing.OutCubic }
        NumberAnimation { target: contentRect; property: "opacity"; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: contentRect
        anchors.fill: parent
        implicitHeight: calCol.implicitHeight + 24
        color:        calPopup.colBg
        border.color: calPopup.colBlue
        border.width: 2
        radius:       10
        transformOrigin: Item.Top

        ColumnLayout {
            id: calCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8

            // ── Крупное время ─────────────────────────────────────────────
            Text {
                id: bigClock
                Layout.alignment: Qt.AlignHCenter
                font { pixelSize: calPopup.fontSize + 22; family: calPopup.fontFamily; bold: true }
                color: calPopup.colFg
                text: Qt.formatDateTime(new Date(), "HH:mm")
                Timer {
                    interval: 1000; running: calPopup.visible; repeat: true
                    onTriggered: bigClock.text = Qt.formatDateTime(new Date(), "HH:mm")
                }
            }

            // ── Дата текстом ──────────────────────────────────────────────
            Text {
                Layout.alignment: Qt.AlignHCenter
                font { pixelSize: calPopup.fontSize - 2; family: calPopup.fontFamily }
                color: calPopup.colFg
                text: Qt.formatDateTime(calPopup._today, "dddd, d MMMM yyyy")
            }

            // ── Divider ───────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1; color: calPopup.colMuted; opacity: 0.4
            }

            // ── Навигация по месяцам ──────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                NavBtn {
                    btnText: "󰍞"
                    onClicked: {
                        if (calPopup.viewMonth === 0) { calPopup.viewMonth = 11; calPopup.viewYear-- }
                        else calPopup.viewMonth--
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: monthName(calPopup.viewMonth) + "  " + calPopup.viewYear
                    font { pixelSize: calPopup.fontSize; family: calPopup.fontFamily; bold: true }
                    color: calPopup.colFg
                }

                NavBtn {
                    btnText: "󰍟"
                    onClicked: {
                        if (calPopup.viewMonth === 11) { calPopup.viewMonth = 0; calPopup.viewYear++ }
                        else calPopup.viewMonth++
                    }
                }

                NavBtn {
                    btnText:  "󰋮"
                    btnColor: (calPopup.viewMonth === calPopup._today.getMonth() &&
                               calPopup.viewYear  === calPopup._today.getFullYear())
                              ? calPopup.colMuted : calPopup.colCyan
                    onClicked: {
                        calPopup.viewMonth = calPopup._today.getMonth()
                        calPopup.viewYear  = calPopup._today.getFullYear()
                    }
                }
            }

            // ── Заголовок дней недели ─────────────────────────────────────
            Row {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    width: 28
                    horizontalAlignment: Text.AlignHCenter
                    text:  "Wk"
                    font { pixelSize: calPopup.fontSize - 5; family: calPopup.fontFamily; bold: true }
                    color: calPopup.colMuted
                }
                Repeater {
                    model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                    Text {
                        width: (calCol.width - 24 - 28) / 7
                        horizontalAlignment: Text.AlignHCenter
                        text:  modelData
                        font { pixelSize: calPopup.fontSize - 4; family: calPopup.fontFamily; bold: true }
                        color: calPopup.colFg
                    }
                }
            }

            // ── Сетка ─────────────────────────────────────────────────────
            Column {
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: 6
                    delegate: Row {
                        id: weekRow
                        property int wi: index
                        property int shift: {
                            var d = new Date(calPopup.viewYear, calPopup.viewMonth, 1)
                            return (d.getDay() + 6) % 7
                        }
                        property int dim: new Date(calPopup.viewYear, calPopup.viewMonth + 1, 0).getDate()
                        property int firstCellDay: wi * 7 - shift + 1
                        property bool hasAny: firstCellDay <= dim && (firstCellDay + 6) >= 1

                        visible: hasAny
                        spacing: 0

                        // Номер недели
                        Text {
                            width:  28
                            height: 26
                            verticalAlignment:   Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: "W" + isoWeek(new Date(calPopup.viewYear, calPopup.viewMonth,
                                                         Math.max(1, weekRow.firstCellDay)))
                            font { pixelSize: calPopup.fontSize - 5; family: calPopup.fontFamily }
                            color: calPopup.colMuted
                        }

                        Repeater {
                            model: 7
                            delegate: Item {
                                property int  cellDay:   weekRow.firstCellDay + index
                                property bool inMonth:   cellDay >= 1 && cellDay <= weekRow.dim
                                property bool isToday:   inMonth &&
                                    cellDay            === calPopup._today.getDate() &&
                                    calPopup.viewMonth === calPopup._today.getMonth() &&
                                    calPopup.viewYear  === calPopup._today.getFullYear()

                                width:  (calCol.width - 24 - 28) / 7
                                height: 26

                                Rectangle {
                                    visible: isToday
                                    anchors.centerIn: parent
                                    width: 24; height: 24; radius: 12
                                    color: Qt.rgba(0.37, 0.51, 0.67, 0.30)
                                    border.color: calPopup.colBlue
                                    border.width: 1
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: inMonth
                                    text: cellDay
                                    font {
                                        pixelSize: calPopup.fontSize - 3
                                        family:    calPopup.fontFamily
                                        bold:      isToday
                                    }
                                    color: isToday ? calPopup.colLBlue : calPopup.colFg
                                }
                            }
                        }
                    }
                }
            }

            Item { height: 0 }
        }
    }

    // ── NavBtn ────────────────────────────────────────────────────────────
    component NavBtn: Item {
        width: 28; height: 28
        property string btnText:  ""
        property color  btnColor: calPopup.colFg
        signal clicked()

        Rectangle {
            anchors.fill: parent; radius: 6
            color: ma.containsMouse ? calPopup.colMuted : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        Text {
            anchors.centerIn: parent
            text:  parent.btnText
            font { pixelSize: calPopup.fontSize; family: calPopup.fontFamily }
            color: parent.btnColor
        }
        MouseArea {
            id: ma; anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    function monthName(m) {
        return ["January","February","March","April","May","June",
                "July","August","September","October","November","December"][m]
    }

    function isoWeek(d) {
        var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7))
        var y = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil((((t - y) / 86400000) + 1) / 7)
    }
}