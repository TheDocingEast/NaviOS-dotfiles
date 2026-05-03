// modules/CalendarModule.qml
// Попап от топбара. Вкладки: Calendar | Weather | Timer
//
// Фаза 6 — расширения:
//   Calendar: выбранный день → погода на день (из forecast[]) + праздники (Nager.Date API)
//   Weather:  текущая погода + ветер (скорость + направление) + 7-дневный прогноз
//   Timer:    установка mm:ss, старт/пауза/сброс, уведомление через NotificationServer

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

PopupWindow {
    id: calPopup

    // ── Тема ─────────────────────────────────────────────────────────────
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

    // ── Weather singleton (пробрасывается из shell.qml) ───────────────────
    property var weatherService: null
    readonly property var wx: weatherService

    // ── Состояние календаря ───────────────────────────────────────────────
    property date   _today:     new Date()
    property int    viewYear:   _today.getFullYear()
    property int    viewMonth:  _today.getMonth()   // 0-based

    // Выбранный день (для прогноза и праздников)
    property int    selDay:     _today.getDate()
    property int    selMonth:   _today.getMonth()
    property int    selYear:    _today.getFullYear()

    // ── Вкладки ───────────────────────────────────────────────────────────
    property int activeTab: 0   // 0=Calendar, 1=Weather, 2=Timer

    // ── Геометрия ─────────────────────────────────────────────────────────
    width:   310
    height:  contentRect.implicitHeight
    color:   "transparent"
    visible: false

    onVisibleChanged: {
        if (visible) {
            contentRect.scale   = 0.94
            contentRect.opacity = 0
            appearAnim.restart()
            // Загружаем праздники при открытии если ещё не загружены
            if (holidays.count === 0) fetchHolidays(selYear)
        }
    }

    // Обновляем "сегодня" каждую минуту
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: calPopup._today = new Date()
    }

    // ── Анимация появления ────────────────────────────────────────────────
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

    // ══════════════════════════════════════════════════════════════════════
    // ПРАЗДНИКИ (Nager.Date API)
    // ══════════════════════════════════════════════════════════════════════
    // ListModel: { date: "YYYY-MM-DD", name: "...", localName: "..." }
    ListModel { id: holidays }
    property int _holidaysYear: -1   // год, для которого уже загружены данные

    function fetchHolidays(year) {
        // Не перезагружаем если год тот же
        if (year === _holidaysYear) return
        if (!wx || !wx.countryCode || wx.countryCode === "") return

        var url = "https://date.nager.at/api/v3/PublicHolidays/"
            + year + "/" + wx.countryCode

        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                console.warn("[Calendar] Nager.Date failed:", xhr.status, url)
                return
            }
            try {
                var arr = JSON.parse(xhr.responseText)
                holidays.clear()
                for (var i = 0; i < arr.length; i++) {
                    holidays.append({
                        date:      arr[i].date,           // "YYYY-MM-DD"
                        name:      arr[i].name,
                        localName: arr[i].localName || arr[i].name
                    })
                }
                _holidaysYear = year
            } catch(e) {
                console.warn("[Calendar] Nager.Date parse error:", e)
            }
        }
        xhr.send()
    }

    // Праздники для выбранного дня
    function holidaysForDay(y, m, d) {
        var iso = y + "-"
            + String(m + 1).padStart(2, "0") + "-"
            + String(d).padStart(2, "0")
        var result = []
        for (var i = 0; i < holidays.count; i++) {
            if (holidays.get(i).date === iso)
                result.push(holidays.get(i).localName)
        }
        return result
    }

    // При смене года в навигации — перегружаем праздники
    onViewYearChanged: fetchHolidays(viewYear)

    // Когда countryCode появится — загружаем
    Connections {
        target: calPopup.wx
        enabled: calPopup.wx !== null
        function onCountryCodeChanged() {
            if (calPopup.wx.countryCode !== "") {
                holidays.clear()
                calPopup._holidaysYear = -1
                calPopup.fetchHolidays(calPopup.viewYear)
            }
        }
    }

    // ── Прогноз погоды на выбранный день ─────────────────────────────────
    readonly property var selForecast: {
        if (!wx || !wx.forecast || wx.forecast.length === 0) return null
        var iso = selYear + "-"
            + String(selMonth + 1).padStart(2, "0") + "-"
            + String(selDay).padStart(2, "0")
        for (var i = 0; i < wx.forecast.length; i++) {
            if (wx.forecast[i].date === iso) return wx.forecast[i]
        }
        return null
    }

    // ── Вспомогательные функции ───────────────────────────────────────────
    function monthName(m) {
        return ["January","February","March","April","May","June",
                "July","August","September","October","November","December"][m]
    }

    function shortMonthName(m) {
        return ["Jan","Feb","Mar","Apr","May","Jun",
                "Jul","Aug","Sep","Oct","Nov","Dec"][m]
    }

    function isoWeek(d) {
        var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7))
        var y = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
        return Math.ceil((((t - y) / 8.64e7) + 1) / 7)
    }

    // ══════════════════════════════════════════════════════════════════════
    // UI
    // ══════════════════════════════════════════════════════════════════════
    Rectangle {
        id: contentRect
        anchors.fill: parent
        implicitHeight: mainCol.implicitHeight + 16
        color:   calPopup.colBg
        border.color: calPopup.colBlue
        border.width: 1
        transformOrigin: Item.Top
        clip: true

        ColumnLayout {
            id: mainCol
            spacing: 0
                        anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }

            // ── Tab bar ───────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                Layout.topMargin: 4

                Repeater {
                    model: [
                        { icon: "󰸗", label: "Calendar" },
                        { icon: "󰖐", label: "Weather"  },
                        { icon: "󱎫", label: "Timer"    }
                    ]

                    Item {
                        Layout.fillWidth: true
                        height: 34
                        readonly property bool isActive: calPopup.activeTab === index

                        Rectangle {
                            anchors.fill: parent
                            color: isActive
                                ? Qt.rgba(0.37, 0.51, 0.67, 0.15)
                                : tabMa.containsMouse ? Qt.rgba(1,1,1,0.04) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        Rectangle {
                            visible: isActive
                                                        anchors {
                                bottom: parent.bottom
                                left: parent.left
                                right: parent.right
                            }
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            height: 2
                            color: calPopup.colCyan
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: modelData.icon
                                                                font {
                                    pixelSize: calPopup.fontSize - 1
                                    family: calPopup.fontFamily
                                }
                                color: isActive ? calPopup.colCyan : calPopup.colMuted
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                text: modelData.label
                                                                font {
                                    pixelSize: calPopup.fontSize - 4
                                    family: calPopup.fontFamily
                                    bold: isActive
                                }
                                color: isActive ? calPopup.colFg : calPopup.colMuted
                                Behavior on color { ColorAnimation { duration: 100 } }
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

            // Разделитель
                        Rectangle {
                Layout.fillWidth: true
                height: 1
                color: calPopup.colMuted
                opacity: 0.3
                Layout.topMargin: 4
            }

            // ══════════════════════════════════════════════════════════════
            // ВКЛАДКА 0: CALENDAR
            // ══════════════════════════════════════════════════════════════
            ColumnLayout {
                visible: calPopup.activeTab === 0
                Layout.fillWidth: true
                spacing: 6
                Layout.topMargin: 8

                // Большие часы
                Text {
                    id: bigClock
                    Layout.alignment: Qt.AlignHCenter
                    color: calPopup.colFg
                    text: Qt.formatDateTime(new Date(), "HH:mm")
                                        font {
                        pixelSize: calPopup.fontSize + 18
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
                    text: Qt.formatDateTime(calPopup._today, "dddd, d MMMM yyyy")
                    color: calPopup.colMuted
                                        font {
                        pixelSize: calPopup.fontSize - 3
                        family: calPopup.fontFamily
                    }
                }

                                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: calPopup.colMuted
                    opacity: 0.3
                }

                // Навигация по месяцу
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    CalNavBtn {
                        btnText: "󰍞"
                        onClicked: {
                                                        if (calPopup.viewMonth === 0) {
                                calPopup.viewMonth = 11
                                calPopup.viewYear--
                            }
                            else calPopup.viewMonth--
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: calPopup.monthName(calPopup.viewMonth) + "  " + calPopup.viewYear
                        color: calPopup.colFg
                                                font {
                            pixelSize: calPopup.fontSize - 1
                            family: calPopup.fontFamily
                            bold: true
                        }
                    }

                    CalNavBtn {
                        btnText: "󰍟"
                        onClicked: {
                                                        if (calPopup.viewMonth === 11) {
                                calPopup.viewMonth = 0
                                calPopup.viewYear++
                            }
                            else calPopup.viewMonth++
                        }
                    }

                    CalNavBtn {
                        btnText: "󰋮"
                        btnColor: (calPopup.viewMonth === calPopup._today.getMonth()
                            && calPopup.viewYear === calPopup._today.getFullYear())
                            ? calPopup.colMuted : calPopup.colCyan
                        onClicked: {
                            calPopup.viewMonth = calPopup._today.getMonth()
                            calPopup.viewYear  = calPopup._today.getFullYear()
                        }
                    }
                }

                // Дни недели — заголовки
                Row {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        width: 26
                        horizontalAlignment: Text.AlignHCenter
                        text: "Wk"
                        color: calPopup.colMuted
                                                font {
                            pixelSize: calPopup.fontSize - 6
                            family: calPopup.fontFamily
                            bold: true
                        }
                    }

                    Repeater {
                        model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                        Text {
                            width: (mainCol.width - 20 - 26) / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: (index >= 5) ? calPopup.colMuted : calPopup.colFg
                                                        font {
                                pixelSize: calPopup.fontSize - 5
                                family: calPopup.fontFamily
                                bold: true
                            }
                        }
                    }
                }

                // Сетка дней
                Column {
                    Layout.fillWidth: true
                    spacing: 1

                    Repeater {
                        model: 6
                        delegate: Row {
                            id: weekRow
                            property int wi:           index
                                                        property int shift:        {
                                var d = new Date(calPopup.viewYear, calPopup.viewMonth, 1)
                                return (d.getDay() + 6) % 7
                            }
                            property int dim:          new Date(calPopup.viewYear, calPopup.viewMonth + 1, 0).getDate()
                            property int firstCellDay: wi * 7 - shift + 1
                            property bool hasAny:      firstCellDay <= dim && (firstCellDay + 6) >= 1

                            visible: hasAny
                            spacing: 0

                            // Номер недели
                            Text {
                                width: 26
                                height: 24
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: "W" + isoWeek(new Date(calPopup.viewYear, calPopup.viewMonth, Math.max(1, weekRow.firstCellDay)))
                                color: calPopup.colMuted
                                                                font {
                                    pixelSize: calPopup.fontSize - 6
                                    family: calPopup.fontFamily
                                }
                            }

                            Repeater {
                                model: 7
                                delegate: Item {
                                    property int  cellDay:  weekRow.firstCellDay + index
                                    property bool inMonth:  cellDay >= 1 && cellDay <= weekRow.dim
                                    property bool isToday:  inMonth && cellDay === calPopup._today.getDate()
                                        && calPopup.viewMonth === calPopup._today.getMonth()
                                        && calPopup.viewYear  === calPopup._today.getFullYear()
                                    property bool isSel:    inMonth && cellDay === calPopup.selDay
                                        && calPopup.viewMonth === calPopup.selMonth
                                        && calPopup.viewYear  === calPopup.selYear
                                    property bool isWeekend: index >= 5
                                    property bool hasHoliday: {
                                        if (!inMonth) return false
                                        var iso = calPopup.viewYear + "-"
                                            + String(calPopup.viewMonth + 1).padStart(2,"0") + "-"
                                            + String(cellDay).padStart(2,"0")
                                        for (var i = 0; i < holidays.count; i++) {
                                            if (holidays.get(i).date === iso) return true
                                        }
                                        return false
                                    }

                                    width:  (mainCol.width - 20 - 26) / 7
                                    height: 24

                                    // Фон выбранного дня
                                    Rectangle {
                                        visible: isSel && !isToday
                                        anchors.centerIn: parent
                                        width: 22
                                        height: 22
                                        color: Qt.rgba(0.56, 0.63, 0.69, 0.2)
                                        border.color: calPopup.colMuted
                                        border.width: 1
                                    }

                                    // Фон сегодня
                                    Rectangle {
                                        visible: isToday
                                        anchors.centerIn: parent
                                        width: 22
                                        height: 22
                                        color: Qt.rgba(0.37, 0.51, 0.67, 0.3)
                                        border.color: calPopup.colBlue
                                        border.width: 1
                                    }

                                    // Точка праздника
                                    Rectangle {
                                        visible: inMonth && hasHoliday
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottomMargin: 1
                                        width: 3
                                        height: 3
                                        radius: 1.5
                                        color: calPopup.colYellow
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: inMonth
                                        text: cellDay
                                        color: isToday   ? calPopup.colLBlue
                                             : isSel     ? calPopup.colCyan
                                             : isWeekend ? Qt.rgba(0.75,0.78,0.82,0.6)
                                             : calPopup.colFg
                                                                                font {
                                            pixelSize: calPopup.fontSize - 4
                                            family: calPopup.fontFamily
                                            bold: isToday || isSel
                                        }
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: inMonth
                                        onClicked: {
                                            calPopup.selDay   = cellDay
                                            calPopup.selMonth = calPopup.viewMonth
                                            calPopup.selYear  = calPopup.viewYear
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: calPopup.colMuted
                    opacity: 0.25
                }

                // ── Детали выбранного дня ──────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Layout.bottomMargin: 4

                    // Заголовок дня
                    Text {
                        text: {
                            var d = new Date(calPopup.selYear, calPopup.selMonth, calPopup.selDay)
                            return Qt.formatDateTime(d, "dddd, d ") + calPopup.shortMonthName(calPopup.selMonth) + " " + calPopup.selYear
                        }
                                                font {
                            pixelSize: calPopup.fontSize - 3
                            family: calPopup.fontFamily
                            bold: true
                        }
                        color: calPopup.colCyan
                    }

                    // Праздники
                    Repeater {
                        model: calPopup.holidaysForDay(calPopup.selYear, calPopup.selMonth, calPopup.selDay)
                        RowLayout {
                            spacing: 4
                            Text {
                                text: "󰈽"
                                                                font {
                                    pixelSize: calPopup.fontSize - 4
                                    family: calPopup.fontFamily
                                }
                                color: calPopup.colYellow
                            }
                            Text {
                                text: modelData
                                                                font {
                                    pixelSize: calPopup.fontSize - 4
                                    family: calPopup.fontFamily
                                }
                                color: calPopup.colYellow
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Погода на выбранный день (из forecast)
                    RowLayout {
                        visible: calPopup.selForecast !== null
                        spacing: 8

                        Text {
                            text: calPopup.selForecast ? calPopup.selForecast.icon : ""
                            font.pixelSize: calPopup.fontSize + 4
                        }

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: calPopup.selForecast
                                    ? calPopup.selForecast.tempMax + "° / " + calPopup.selForecast.tempMin + "°  " + calPopup.selForecast.desc
                                    : ""
                                                                font {
                                    pixelSize: calPopup.fontSize - 3
                                    family: calPopup.fontFamily
                                    bold: true
                                }
                                color: calPopup.colFg
                            }
                            Text {
                                text: calPopup.selForecast
                                    ? "󰈐 " + calPopup.selForecast.windMax + " m/s  󰖎 " + calPopup.selForecast.precipSum + " mm"
                                    : ""
                                                                font {
                                    pixelSize: calPopup.fontSize - 5
                                    family: calPopup.fontFamily
                                }
                                color: calPopup.colMuted
                            }
                        }
                    }

                    // Нет данных прогноза для этого дня
                    Text {
                        visible: calPopup.selForecast === null && calPopup.wx !== null
                        text: "No forecast data for this day"
                                                font {
                            pixelSize: calPopup.fontSize - 5
                            family: calPopup.fontFamily
                        }
                        color: calPopup.colMuted
                        opacity: 0.6
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════
            // ВКЛАДКА 1: WEATHER
            // ══════════════════════════════════════════════════════════════
            ColumnLayout {
                visible: calPopup.activeTab === 1
                Layout.fillWidth: true
                spacing: 0
                Layout.topMargin: 10

                // Нет данных
                Text {
                    visible: calPopup.wx === null || !calPopup.wx.ready
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 20
                    Layout.bottomMargin: 20
                    text: calPopup.wx && calPopup.wx.loading ? "󰑐  Loading…" : "Weather unavailable"
                    color: calPopup.colMuted
                                        font {
                        pixelSize: calPopup.fontSize - 2
                        family: calPopup.fontFamily
                    }
                }

                // Есть данные
                ColumnLayout {
                    visible: calPopup.wx !== null && calPopup.wx.ready
                    Layout.fillWidth: true
                    spacing: 10

                    // Город
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: calPopup.wx ? (calPopup.wx.cityName + ", " + calPopup.wx.country) : ""
                        color: calPopup.colMuted
                                                font {
                            pixelSize: calPopup.fontSize - 3
                            family: calPopup.fontFamily
                        }
                    }

                    // Главный блок: иконка + температура + описание
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12

                        Text {
                            text: calPopup.wx ? calPopup.wx.icon : ""
                            font.pixelSize: calPopup.fontSize + 28
                        }

                        ColumnLayout {
                            spacing: 2

                            Text {
                                text: calPopup.wx ? calPopup.wx.temperature : "--"
                                color: {
                                    if (!calPopup.wx) return calPopup.colFg
                                    var t = parseInt(calPopup.wx.temperature)
                                    return t >= 30 ? calPopup.colRed
                                         : t >= 20 ? calPopup.colYellow
                                         : t >= 10 ? calPopup.colCyan
                                         : calPopup.colLBlue
                                }
                                                                font {
                                    pixelSize: calPopup.fontSize + 18
                                    family: calPopup.fontFamily
                                    bold: true
                                }
                            }

                            Text {
                                text: calPopup.wx ? calPopup.wx.description : ""
                                color: calPopup.colMuted
                                                                font {
                                    pixelSize: calPopup.fontSize - 4
                                    family: calPopup.fontFamily
                                }
                            }
                        }
                    }

                    // Плашки: влажность / ветер / направление
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [
                                { icon: "󰖝", label: "Humidity",  value: calPopup.wx ? calPopup.wx.humidity  : "--" },
                                { icon: "󰈐", label: "Wind",      value: calPopup.wx ? calPopup.wx.windSpeed : "--" },
                                { icon: "󰆞", label: "Direction", value: calPopup.wx ? calPopup.wx.windDir   : "--" }
                            ]

                            Rectangle {
                                Layout.fillWidth: true
                                height: 52
                                color: Qt.rgba(0.18, 0.21, 0.25, 0.5)
                                border.color: calPopup.colMuted
                                border.width: 1
                                opacity: 0.8

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.icon
                                                                                font {
                                            pixelSize: calPopup.fontSize + 2
                                            family: calPopup.fontFamily
                                        }
                                        color: calPopup.colCyan
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.value
                                                                                font {
                                            pixelSize: calPopup.fontSize - 4
                                            family: calPopup.fontFamily
                                            bold: true
                                        }
                                        color: calPopup.colFg
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.label
                                                                                font {
                                            pixelSize: calPopup.fontSize - 6
                                            family: calPopup.fontFamily
                                        }
                                        color: calPopup.colMuted
                                    }
                                }
                            }
                        }
                    }

                                        Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: calPopup.colMuted
                        opacity: 0.25
                    }

                    // 7-дневный прогноз
                    Text {
                        text: "7-Day Forecast"
                                                font {
                            pixelSize: calPopup.fontSize - 4
                            family: calPopup.fontFamily
                            bold: true
                        }
                        color: calPopup.colMuted
                        Layout.leftMargin: 2
                    }

                    // Прокручиваемая лента прогноза
                    ScrollView {
                        Layout.fillWidth: true
                        implicitHeight: forecastRow.implicitHeight + 4
                        ScrollBar.horizontal.policy: ScrollBar.AsNeeded
                        ScrollBar.vertical.policy:   ScrollBar.AlwaysOff
                        clip: true

                        Row {
                            id: forecastRow
                            spacing: 4

                            Repeater {
                                model: calPopup.wx ? calPopup.wx.forecast : []

                                Rectangle {
                                    width: 56
                                    height: forecastItemCol.implicitHeight + 10
                                    color: Qt.rgba(0.18, 0.21, 0.25, 0.5)
                                    border.color: calPopup.colMuted
                                    border.width: 1

                                    ColumnLayout {
                                        id: forecastItemCol
                                                                                anchors {
                                            left: parent.left
                                            right: parent.right
                                            verticalCenter: parent.verticalCenter
                                        }
                                        anchors.margins: 4
                                        spacing: 2

                                        // День недели
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: {
                                                var d = new Date(modelData.date)
                                                return ["Su","Mo","Tu","We","Th","Fr","Sa"][d.getDay()]
                                            }
                                                                                        font {
                                                pixelSize: calPopup.fontSize - 6
                                                family: calPopup.fontFamily
                                                bold: true
                                            }
                                            color: calPopup.colMuted
                                        }

                                        // Иконка погоды
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData.icon
                                            font.pixelSize: calPopup.fontSize + 2
                                        }

                                        // Макс / Мин
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData.tempMax + "°"
                                                                                        font {
                                                pixelSize: calPopup.fontSize - 4
                                                family: calPopup.fontFamily
                                                bold: true
                                            }
                                            color: calPopup.colFg
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData.tempMin + "°"
                                                                                        font {
                                                pixelSize: calPopup.fontSize - 5
                                                family: calPopup.fontFamily
                                            }
                                            color: calPopup.colMuted
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Кнопка Refresh
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: refreshTxt.implicitWidth + 20
                        height: 26
                        Layout.bottomMargin: 4

                        Rectangle {
                            anchors.fill: parent
                            color: refreshMa.containsMouse ? Qt.rgba(0.37,0.51,0.67,0.2) : "transparent"
                            border.color: calPopup.colMuted
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        Text {
                            id: refreshTxt
                            anchors.centerIn: parent
                            text: "󰑓  Refresh"
                            color: refreshMa.containsMouse ? calPopup.colCyan : calPopup.colFg
                                                        font {
                                pixelSize: calPopup.fontSize - 3
                                family: calPopup.fontFamily
                            }
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                            id: refreshMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (calPopup.wx) calPopup.wx.refresh() }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════
            // ВКЛАДКА 2: TIMER
            // ══════════════════════════════════════════════════════════════
            ColumnLayout {
                visible: calPopup.activeTab === 2
                Layout.fillWidth: true
                spacing: 12
                Layout.topMargin: 12
                Layout.bottomMargin: 8

                // ── Состояние таймера ─────────────────────────────────────
                // Общее время в секундах (устанавливается через спиннеры)
                property int  totalSecs:   300   // 5 минут по умолчанию
                property int  remaining:   300
                property bool running_:    false
                property bool finished:    false

                // Минуты и секунды для спиннеров
                property int setMins: 5
                property int setSecs: 0

                id: timerTab

                function reset() {
                    timerTab.running_  = false
                    timerTab.finished  = false
                    timerTab.totalSecs = timerTab.setMins * 60 + timerTab.setSecs
                    timerTab.remaining = timerTab.totalSecs
                }

                function startPause() {
                    if (timerTab.finished) {
                        timerTab.reset()
                        return
                    }
                    timerTab.running_ = !timerTab.running_
                }

                // Тик таймера
                Timer {
                    interval: 1000
                    running:  timerTab.running_
                    repeat:   true
                    onTriggered: {
                        if (timerTab.remaining <= 0) {
                            timerTab.running_  = false
                            timerTab.finished  = true
                            timerNotifServer.createNotification()
                            return
                        }
                        timerTab.remaining--
                    }
                }

                // NotificationServer для таймера
                // ПРИМЕЧАНИЕ: создаём уведомление через отдельный мини-сервер,
                // чтобы не путать с NotificationPopup в shell.qml.
                // Оба сервера зарегистрированы под одним D-Bus именем — QS сам
                // обрабатывает мультиплексирование.
                // Если возникнет конфликт имён — убрать этот сервер и дёргать
                // notifPopup.showLocalNotification() через сигнал/свойство.
                NotificationServer {
                    id: timerNotifServer
                    // Только для отправки — не принимаем внешние уведомления
                    // ПРИМЕЧАНИЕ: API создания уведомления самим QS — через
                    // Notification { } объект или через D-Bus напрямую.
                    // В QS v0.2.1 встроенного API "send notification" нет —
                    // используем Process + notify-send как надёжный fallback.
                    function createNotification() {
                        timerNotifyProc.running = true
                    }
                }

                Process {
                    id: timerNotifyProc
                    command: [
                        "notify-send",
                        "--app-name=Quickshell Timer",
                        "--urgency=normal",
                        "--icon=alarm-timer",
                        "Timer finished",
                        timerTab.setMins + "m " + timerTab.setSecs + "s elapsed"
                    ]
                }

                // Форматирование времени
                function fmt(s) {
                    var m = Math.floor(s / 60)
                    var sc = s % 60
                    return String(m).padStart(2,"0") + ":" + String(sc).padStart(2,"0")
                }

                // ── Большой дисплей ───────────────────────────────────────
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth:  timerDisplay.implicitWidth + 32
                    implicitHeight: timerDisplay.implicitHeight + 16

                    Rectangle {
                        anchors.fill: parent
                        color: timerTab.finished
                            ? Qt.rgba(0.75, 0.38, 0.41, 0.15)
                            : Qt.rgba(0.18, 0.21, 0.25, 0.6)
                        border.color: timerTab.finished ? calPopup.colRed
                                    : timerTab.running_ ? calPopup.colCyan
                                    : calPopup.colMuted
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                    }

                    Text {
                        id: timerDisplay
                        anchors.centerIn: parent
                        text: timerTab.fmt(timerTab.remaining)
                                                font {
                            pixelSize: calPopup.fontSize + 22
                            family: calPopup.fontFamily
                            bold: true
                        }
                        color: timerTab.finished ? calPopup.colRed
                             : timerTab.remaining < 10 && timerTab.running_ ? calPopup.colYellow
                             : calPopup.colFg
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                // Прогресс-бар
                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    color: Qt.rgba(0.30, 0.36, 0.41, 0.5)

                    Rectangle {
                        height: parent.height
                        width: timerTab.totalSecs > 0
                            ? parent.width * timerTab.remaining / timerTab.totalSecs
                            : 0
                        color: timerTab.finished ? calPopup.colRed
                             : timerTab.remaining < timerTab.totalSecs * 0.2 ? calPopup.colYellow
                             : calPopup.colCyan
                        Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.Linear } }
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }

                // ── Спиннеры установки времени ────────────────────────────
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4
                    enabled: !timerTab.running_ && !timerTab.finished

                    // Минуты
                    TimerSpinner {
                        label: "min"
                        value: timerTab.setMins
                        minVal: 0
                        maxVal: 99
                        onPicked: v => {
                            timerTab.setMins = v
                            if (!timerTab.running_) timerTab.reset()
                        }
                        fontFamily: calPopup.fontFamily
                        fontSize: calPopup.fontSize
                        colFg: calPopup.colFg
                        colMuted: calPopup.colMuted
                        colCyan: calPopup.colCyan
                        colBg: calPopup.colBg
                    }

                    Text {
                        text: ":"
                                                font {
                            pixelSize: calPopup.fontSize + 4
                            family: calPopup.fontFamily
                            bold: true
                        }
                        color: calPopup.colMuted
                    }

                    // Секунды
                    TimerSpinner {
                        label: "sec"
                        value: timerTab.setSecs
                        minVal: 0
                        maxVal: 59
                        onPicked: v => {
                            timerTab.setSecs = v
                            if (!timerTab.running_) timerTab.reset()
                        }
                        fontFamily: calPopup.fontFamily
                        fontSize: calPopup.fontSize
                        colFg: calPopup.colFg
                        colMuted: calPopup.colMuted
                        colCyan: calPopup.colCyan
                        colBg: calPopup.colBg
                    }
                }

                // ── Кнопки управления ─────────────────────────────────────
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    // Старт / Пауза / Снова
                    CalBtn {
                        btnText: timerTab.finished ? "󰑐  Again"
                               : timerTab.running_ ? "󰏤  Pause"
                               : "󰐊  Start"
                        btnColor: timerTab.finished ? calPopup.colYellow
                                : timerTab.running_ ? calPopup.colCyan
                                : calPopup.colGreen
                        width: 100
                        height: 32
                        onClicked: timerTab.startPause()
                        fontFamily: calPopup.fontFamily
                        fontSize: calPopup.fontSize
                        colMuted: calPopup.colMuted
                    }

                    // Сброс
                    CalBtn {
                        btnText: "󰐗  Reset"
                        btnColor: calPopup.colMuted
                        width: 80
                        height: 32
                        enabled: timerTab.running_ || timerTab.remaining !== timerTab.totalSecs
                        onClicked: timerTab.reset()
                        fontFamily: calPopup.fontFamily
                        fontSize: calPopup.fontSize
                        colMuted: calPopup.colMuted
                    }
                }

                // Статус
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: timerTab.finished ? "󰀦  Done!" : ""
                                        font {
                        pixelSize: calPopup.fontSize - 2
                        family: calPopup.fontFamily
                        bold: true
                    }
                    color: calPopup.colYellow
                    Layout.bottomMargin: 2
                }
            }

            Item { height: 6 }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ПЕРЕИСПОЛЬЗУЕМЫЕ КОМПОНЕНТЫ
    // ══════════════════════════════════════════════════════════════════════

    // Кнопка навигации календаря
    component CalNavBtn: Item {
        property string btnText:  ""
        property color  btnColor: calPopup.colFg
        signal clicked()

        width: 26
        height: 26

        Rectangle {
            anchors.fill: parent
            color: navMa.containsMouse ? calPopup.colMuted : "transparent"
            opacity: 0.4
            Behavior on color { ColorAnimation { duration: 80 } }
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
            id: navMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    // Универсальная кнопка
    component CalBtn: Item {
        property string btnText:   ""
        property color  btnColor:  calPopup.colCyan
        property string fontFamily: calPopup.fontFamily
        property int    fontSize:   calPopup.fontSize
        property color  colMuted:   calPopup.colMuted
        signal clicked()

        Rectangle {
            anchors.fill: parent
            color: btnMa.containsMouse
                ? Qt.rgba(Qt.color(parent.btnColor).r, Qt.color(parent.btnColor).g, Qt.color(parent.btnColor).b, 0.2)
                : Qt.rgba(0, 0, 0, 0.2)
            border.color: parent.enabled ? parent.btnColor : parent.colMuted
            border.width: 1
            opacity: parent.enabled ? 1.0 : 0.4
            Behavior on color { ColorAnimation { duration: 80 } }
        }

        Text {
            anchors.centerIn: parent
            text: parent.btnText
                        font {
                pixelSize: parent.fontSize - 4
                family: parent.fontFamily
                bold: true
            }
            color: parent.enabled ? parent.btnColor : parent.colMuted
        }

        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: parent.enabled
            onClicked: parent.clicked()
        }
    }

    // Спиннер для таймера (▲ значение ▼)
    component TimerSpinner: Item {
        property int    value:      0
        property int    minVal:     0
        property int    maxVal:     99
        property string label:      ""
        property string fontFamily: calPopup.fontFamily
        property int    fontSize:   calPopup.fontSize
        property color  colFg:      calPopup.colFg
        property color  colMuted:   calPopup.colMuted
        property color  colCyan:    calPopup.colCyan
        property color  colBg:      calPopup.colBg

        signal picked(int v)

        // Явные размеры вместо implicit* — избегаем переопределения
        // implicitWidth/implicitHeight базового Item (варнинг Qt)
        width:  52
        height: spinnerCol.height

        ColumnLayout {
            id: spinnerCol
            width: parent.width
            spacing: 2

            // ▲
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "▲"
                                font {
                    pixelSize: fontSize - 4
                    family: fontFamily
                }
                color: upMa.containsMouse ? colCyan : colMuted
                Behavior on color { ColorAnimation { duration: 80 } }

                MouseArea {
                    id: upMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                                                if (value < maxVal) {
                            value++
                            picked(value)
                        }
                    }
                    // Удержание — ускоренное изменение
                    onPressAndHold: holdTimer.start()
                    onReleased: holdTimer.stop()
                    Timer {
                        id: holdTimer
                        interval: 80
                        repeat: true
                        onTriggered: { if (value < maxVal) { value++; picked(value) } else stop() }
                    }
                }
            }

            // Значение
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 46
                height: 32
                color: Qt.rgba(0.18, 0.21, 0.25, 0.6)
                border.color: colMuted
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: String(value).padStart(2, "0")
                                        font {
                        pixelSize: fontSize + 2
                        family: fontFamily
                        bold: true
                    }
                    color: colFg
                }
            }

            // Подпись
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: label
                                font {
                    pixelSize: fontSize - 6
                    family: fontFamily
                }
                color: colMuted
            }

            // ▼
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "▼"
                                font {
                    pixelSize: fontSize - 4
                    family: fontFamily
                }
                color: downMa.containsMouse ? colCyan : colMuted
                Behavior on color { ColorAnimation { duration: 80 } }

                MouseArea {
                    id: downMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                                                if (value > minVal) {
                            value--
                            picked(value)
                        }
                    }
                    onPressAndHold: holdTimerDown.start()
                    onReleased: holdTimerDown.stop()
                    Timer {
                        id: holdTimerDown
                        interval: 80
                        repeat: true
                        onTriggered: { if (value > minVal) { value--; picked(value) } else stop() }
                    }
                }
            }
        }
    }
}
