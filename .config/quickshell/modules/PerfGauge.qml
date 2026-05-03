// modules/PerfGauge.qml
// Переиспользуемая круговая диаграмма загрузки.
// Отображает: дугу прогресса + центральный текст (% или значение) + подпись снизу.
//
// Использование:
//   PerfGauge {
//       size:      80
//       value:     cpuUsage        // 0–100
//       label:     "CPU"
//       valueText: cpuUsage + "%"
//       subText:   cpuTemp + "°C"  // необязательно
//       color:     "#8fbcbb"
//   }

import QtQuick

Item {
    id: gauge

    property real   value:     0      // 0–100
    property int    size:      80
    property string label:     ""
    property string valueText: Math.round(value) + "%"
    property string subText:   ""     // температура или доп. инфо
    property color  gaugeColor: "#8fbcbb"
    property string fontFamily: "Monaspace Krypton Medium"
    property int    fontSize:   16
    property color  colBg:      "#2e3440"
    property color  colFg:      "#d8dee9"
    property color  colMuted:   "#4c566a"

    implicitWidth:  size
    implicitHeight: size + labelText.implicitHeight + (subText !== "" ? subText_t.implicitHeight : 0) + 6

    // Анимация значения
    property real animValue: 0
    Behavior on animValue { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    onValueChanged: animValue = Math.max(0, Math.min(100, value))
    Component.onCompleted: animValue = Math.max(0, Math.min(100, value))

    // ── Кольцо ───────────────────────────────────────────────────────────
    Canvas {
        id: canvas
        width:  gauge.size
        height: gauge.size
        anchors.horizontalCenter: parent.horizontalCenter

        // Перерисовываем при изменении animValue
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var cx   = width  / 2
            var cy   = height / 2
            var r    = Math.min(cx, cy) - 6   // радиус, отступ под толщину
            var thick = 6                      // толщина дуги

            // ── Фоновое кольцо ────────────────────────────────────────────
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.strokeStyle = Qt.rgba(
                Qt.color(gauge.colMuted).r,
                Qt.color(gauge.colMuted).g,
                Qt.color(gauge.colMuted).b,
                0.3)
            ctx.lineWidth   = thick
            ctx.lineCap     = "butt"
            ctx.stroke()

            // ── Дуга прогресса ────────────────────────────────────────────
            // Начало: -90° (верх), по часовой стрелке
            var startAngle = -Math.PI / 2
            var endAngle   = startAngle + (Math.PI * 2 * gauge.animValue / 100)

            if (gauge.animValue > 0) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, startAngle, endAngle)
                ctx.strokeStyle = gauge.gaugeColor
                ctx.lineWidth   = thick
                ctx.lineCap     = "round"
                ctx.stroke()

                // ── Подсветка: тонкое внутреннее кольцо при высокой нагрузке
                if (gauge.animValue > 75) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, r - thick - 2, startAngle, endAngle)
                    ctx.strokeStyle = Qt.rgba(
                        Qt.color(gauge.gaugeColor).r,
                        Qt.color(gauge.gaugeColor).g,
                        Qt.color(gauge.gaugeColor).b,
                        0.15)
                    ctx.lineWidth = 2
                    ctx.lineCap   = "round"
                    ctx.stroke()
                }
            }
        }

        // Перерисовка при изменении анимированного значения или цвета
        Connections {
            target: gauge
            function onAnimValueChanged() { canvas.requestPaint() }
            function onGaugeColorChanged() { canvas.requestPaint() }
        }

        // ── Центральный текст ─────────────────────────────────────────────
        Column {
            anchors.centerIn: parent
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: gauge.valueText
                font {
                    pixelSize: gauge.size < 70 ? gauge.fontSize - 3 : gauge.fontSize - 1
                    family:    gauge.fontFamily
                    bold:      true
                }
                color: gauge.gaugeColor
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: gauge.subText !== ""
                text:    gauge.subText
                font {
                    pixelSize: gauge.size < 70 ? gauge.fontSize - 6 : gauge.fontSize - 5
                    family:    gauge.fontFamily
                }
                color: gauge.colMuted
            }
        }
    }

    // ── Подпись снизу ─────────────────────────────────────────────────────
    Text {
        id: labelText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: canvas.bottom
        anchors.topMargin: 4
        text: gauge.label
                font {
            pixelSize: gauge.fontSize - 4
            family: gauge.fontFamily
        }
        color: gauge.colMuted
    }

    // Пустой элемент для высоты subText
    Text {
        id: subText_t
        visible: false
        text: gauge.subText !== "" ? "X" : ""
                font {
            pixelSize: gauge.fontSize - 5
            family: gauge.fontFamily
        }
    }
}
