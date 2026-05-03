// modules/PerformanceTab.qml
// Вкладка "Производительность" в ControlMenu.
//
// Источники данных:
//   CPU usage   — /proc/stat (delta между опросами)
//   RAM usage   — /proc/meminfo
//   CPU temp    — /sys/class/hwmon/*/temp*_input (hwmon, универсально)
//   GPU usage   — /sys/class/hwmon/*/pwm* не подходит;
//                 используем /sys/kernel/debug/dri/*/clients — только root.
//                 Реальный fallback: читаем /sys/class/drm/*/device/power/runtime_status
//                 и /sys/class/hwmon для температуры GPU.
//
// Стратегия поиска hwmon:
//   1. Читаем /sys/class/hwmon/hwmon*/name
//   2. По имени определяем: coretemp/k10temp/zenpower → CPU, amdgpu/nouveau/nvidia → GPU
//   3. Читаем соответствующие temp*_input файлы (в милликельвинах или милли°C)
//
// ВАЖНОЕ ПРИМЕЧАНИЕ по GPU usage%:
//   /sys/class/drm не предоставляет usage% без привилегий или platform-specific файлов.
//   Для NVIDIA — /sys/class/drm/card*/device/gpu_busy_percent (только NVIDIA через nouveau)
//   Для AMD   — /sys/class/drm/card*/device/gpu_busy_percent (amdgpu)
//   Путь одинаков по имени, но существует только на поддерживаемом GPU.
//   Мы пробуем этот путь; если файл не существует — показываем "N/A".
//   Это не хардкод nvidia-smi, это чтение sysfs — работает на любом ядре.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: perfRoot

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

    // ══════════════════════════════════════════════════════════════════════
    // ДАННЫЕ
    // ══════════════════════════════════════════════════════════════════════

    // ── CPU ───────────────────────────────────────────────────────────────
    property int  cpuUsage:   0
    property real cpuTempRaw: 0          // °C
    property string cpuTemp:  "--"
    property string cpuName:  "CPU"

    property var _lastCpuIdle:  0
    property var _lastCpuTotal: 0

    Process {
        id: cpuStatProc
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
                if (perfRoot._lastCpuTotal > 0) {
                    var td = total - perfRoot._lastCpuTotal
                    var id = idleT - perfRoot._lastCpuIdle
                    if (td > 0) perfRoot.cpuUsage = Math.round(100 * (td - id) / td)
                }
                perfRoot._lastCpuTotal = total
                perfRoot._lastCpuIdle  = idleT
            }
        }
    }

    // ── RAM ───────────────────────────────────────────────────────────────
    property int    ramUsage:  0
    property int    ramTotalMB: 0
    property int    ramUsedMB:  0
    property string ramLabel:  "--"

    Process {
        id: memProc
        command: ["cat", "/proc/meminfo"]
        stdout: SplitParser {
            property int _total: 0
            property int _avail: 0
            onRead: data => {
                if (!data) return
                if (data.startsWith("MemTotal:")) {
                    _total = parseInt(data.split(/\s+/)[1]) || 1
                    perfRoot.ramTotalMB = Math.round(_total / 1024)
                } else if (data.startsWith("MemAvailable:")) {
                    _avail = parseInt(data.split(/\s+/)[1]) || 0
                    if (_total > 0) {
                        var usedKB = _total - _avail
                        perfRoot.ramUsage  = Math.round(100 * usedKB / _total)
                        perfRoot.ramUsedMB = Math.round(usedKB / 1024)
                        perfRoot.ramLabel  = perfRoot.ramUsedMB + " / " + perfRoot.ramTotalMB + " MB"
                    }
                }
            }
        }
    }

    // ── Температуры (hwmon) ───────────────────────────────────────────────
    // Шаг 1: перечислить hwmon-устройства и найти нужные пути
    property bool   hwmonReady:   false
    property string cpuTempPath:  ""     // напр. /sys/class/hwmon/hwmon2/temp1_input
    property string gpuTempPath:  ""
    property string gpuNameRaw:   ""

    // Ищем hwmon-сенсоры однократно при запуске
    Process {
        id: hwmonFindProc
        // Выводим: "имя_устройства:путь_к_hwmon" для каждого hwmon
        command: ["sh", "-c",
            "for d in /sys/class/hwmon/hwmon*; do " +
            "n=$(cat $d/name 2>/dev/null); " +
            "echo \"$n:$d\"; " +
            "done"]
        stdout: SplitParser {
            onRead: data => {
                if (!data || !data.includes(":")) return
                var parts = data.trim().split(":")
                if (parts.length < 2) return
                var name = parts[0].toLowerCase()
                var dir  = parts[1]

                // CPU температурные сенсоры
                var isCpuSensor = name === "coretemp"    // Intel
                    || name === "k10temp"                 // AMD Ryzen
                    || name === "zenpower"                // AMD Ryzen (alt)
                    || name === "cpu_thermal"             // ARM/embedded
                if (isCpuSensor && perfRoot.cpuTempPath === "") {
                    perfRoot.cpuTempPath = dir + "/temp1_input"
                    perfRoot.cpuName = name === "coretemp" ? "Intel CPU"
                                     : name === "k10temp"  ? "AMD CPU"
                                     : "CPU"
                }

                // GPU температурные сенсоры
                var isGpuSensor = name === "amdgpu"
                    || name === "nouveau"
                    || name.startsWith("nvidia")
                    || name === "radeon"
                if (isGpuSensor && perfRoot.gpuTempPath === "") {
                    perfRoot.gpuTempPath = dir + "/temp1_input"
                    perfRoot.gpuNameRaw  = name
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                perfRoot.hwmonReady = true
                // После обнаружения — ищем путь к gpu_busy_percent
                if (perfRoot.gpuTempPath !== "") {
                    gpuBusyFindProc.running = true
                }
            }
        }
        Component.onCompleted: running = true
    }

    // ── GPU usage% (sysfs gpu_busy_percent) ───────────────────────────────
    property int    gpuUsage:    0
    property string gpuTemp:     "--"
    property string gpuName:     "GPU"
    property bool   gpuAvail:    false      // true если любой источник GPU% найден
    property string gpuBusyPath: ""

    // Режим получения GPU%:
    //   "sysfs"  — /sys/class/drm/.../gpu_busy_percent (AMD / nouveau)
    //   "nvidia" — nvidia-settings -q GPUUtilization    (проприетарный NVIDIA)
    //   ""       — не определён (поиск ещё идёт)
    property string gpuUsageMode: ""

    // Опциональный флаг: разрешить fallback через nvidia-settings.
    // Установить в true если используется проприетарный драйвер NVIDIA.
    // По умолчанию true — пробуем автоматически после провала sysfs.
    property bool enableNvidiaSettings: true

    // Ищем gpu_busy_percent для всех DRM-карт (sysfs — AMD / nouveau)
    Process {
        id: gpuBusyFindProc
        command: ["sh", "-c",
            "for f in /sys/class/drm/card*/device/gpu_busy_percent; do " +
            "[ -r \"$f\" ] && echo \"$f\" && break; " +
            "done"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim()
                if (p !== "") {
                    perfRoot.gpuBusyPath   = p
                    perfRoot.gpuAvail      = true
                    perfRoot.gpuUsageMode  = "sysfs"
                    perfRoot.gpuName       = perfRoot.gpuNameRaw !== ""
                        ? perfRoot.gpuNameRaw.toUpperCase()
                        : "GPU"
                }
            }
        }
        onRunningChanged: {
            if (!running && perfRoot.gpuBusyPath === "") {
                // sysfs не нашёл — пробуем nvidia-settings если разрешено
                if (perfRoot.enableNvidiaSettings) {
                    nvidiaCheckProc.running = true
                }
            }
        }
    }

    // ── NVIDIA fallback: проверяем наличие nvidia-settings ────────────────
    // nvidia-settings -q GPUUtilization возвращает строку вида:
    //   Attribute 'GPUUtilization' (hostname:0[gpu:0]): graphics=5, memory=3, ...
    // Парсим поле graphics=N
    Process {
        id: nvidiaCheckProc
        // Сначала проверяем что nvidia-settings вообще есть
        command: ["sh", "-c", "command -v nvidia-settings && echo found || echo missing"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "found" || data.trim().endsWith("nvidia-settings")) {
                    perfRoot.gpuAvail     = true
                    perfRoot.gpuUsageMode = "nvidia"
                    perfRoot.gpuName      = "NVIDIA GPU"
                    console.log("[Perf] GPU mode: nvidia-settings fallback")
                }
            }
        }
        onRunningChanged: {
            if (!running && perfRoot.gpuUsageMode === "") {
                // Ни sysfs, ни nvidia-settings не доступны
                console.log("[Perf] GPU usage: no source available")
            }
        }
    }

    // Читаем GPU utilization через nvidia-settings
    Process {
        id: nvidiaUsageProc
        command: ["nvidia-settings", "-q", "GPUUtilization", "-t"]
        // -t = terse output: "graphics=5, memory=3, video=0, PCIe=0"
        stdout: SplitParser {
            onRead: data => {
                var m = data.match(/graphics=(\d+)/)
                if (m) perfRoot.gpuUsage = parseInt(m[1])
            }
        }
    }

    // Читаем температуру NVIDIA через nvidia-settings
    // (gpuTempProc читает hwmon — для NVIDIA проп. драйвера он тоже работает
    //  через /sys/class/hwmon/hwmon*/name="nvidia", поэтому отдельного
    //  nvidia-settings -q GPUCoreTemp не нужно — hwmon покрывает оба случая)

    // ── Процессы чтения температур и GPU% ────────────────────────────────
    Process {
        id: cpuTempProc
        command: ["cat", perfRoot.cpuTempPath !== "" ? perfRoot.cpuTempPath : "/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                var v = parseInt(data.trim())
                if (!isNaN(v)) {
                    // hwmon возвращает милли°C (1000 = 1°C)
                    var deg = v > 1000 ? Math.round(v / 1000) : v
                    perfRoot.cpuTempRaw = deg
                    perfRoot.cpuTemp    = deg + "°C"
                }
            }
        }
    }

    Process {
        id: gpuTempProc
        command: ["cat", perfRoot.gpuTempPath !== "" ? perfRoot.gpuTempPath : "/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                var v = parseInt(data.trim())
                if (!isNaN(v)) {
                    var deg = v > 1000 ? Math.round(v / 1000) : v
                    perfRoot.gpuTemp = deg + "°C"
                }
            }
        }
    }

    Process {
        id: gpuUsageProc
        command: ["cat", perfRoot.gpuBusyPath !== "" ? perfRoot.gpuBusyPath : "/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                var v = parseInt(data.trim())
                if (!isNaN(v)) perfRoot.gpuUsage = v
            }
        }
    }

    // ── Таймер опроса ─────────────────────────────────────────────────────
    // Запускаем только когда вкладка видима — экономим ресурсы
    property bool isVisible: false

    Timer {
        id: pollTimer
        interval: 1500
        running:  perfRoot.isVisible
        repeat:   true
        onTriggered: {
            cpuStatProc.running = true
            memProc.running     = true
            if (perfRoot.cpuTempPath !== "") cpuTempProc.running = true
            if (perfRoot.gpuTempPath !== "") gpuTempProc.running = true
            // GPU usage — выбираем источник
            if (perfRoot.gpuUsageMode === "sysfs") {
                gpuUsageProc.running = true
            } else if (perfRoot.gpuUsageMode === "nvidia") {
                nvidiaUsageProc.running = true
            }
        }
    }

    // Первый запрос — сразу при появлении вкладки
    onIsVisibleChanged: {
        if (isVisible && perfRoot.hwmonReady) {
            cpuStatProc.running = true
            memProc.running     = true
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // UI
    // ══════════════════════════════════════════════════════════════════════
    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        ScrollBar.vertical.policy:   ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: parent.width
            spacing: 0

            // ── Заголовок ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 36
                color: Qt.rgba(0.18, 0.21, 0.25, 0.6)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10

                    Text {
                        text: "󰓅  Performance"
                                                font {
                            pixelSize: perfRoot.fontSize - 1
                            family: perfRoot.fontFamily
                            bold: true
                        }
                        color: perfRoot.colFg
                    }

                    Item { Layout.fillWidth: true }

                    // Индикатор опроса
                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: perfRoot.colGreen
                        opacity: pollTimer.running ? 1.0 : 0.3

                        SequentialAnimation on opacity {
                            running: pollTimer.running
                            loops: Animation.Infinite
                                                        NumberAnimation {
                                to: 0.3
                                duration: 600
                            }
                                                        NumberAnimation {
                                to: 1.0
                                duration: 600
                            }
                        }
                    }
                }
            }

            // Разделитель
                        Rectangle {
                Layout.fillWidth: true
                height: 1
                color: perfRoot.colMuted
                opacity: 0.2
            }

            // ── Диаграммы: CPU / RAM / GPU ────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: gaugesRow.implicitHeight + 24
                color: Qt.rgba(0.18, 0.21, 0.25, 0.4)

                RowLayout {
                    id: gaugesRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: 10
                    }
                    spacing: 0

                    // CPU gauge
                    PerfGauge {
                        Layout.fillWidth: true
                        size:       72
                        value:      perfRoot.cpuUsage
                        label:      perfRoot.cpuName
                        valueText:  perfRoot.cpuUsage + "%"
                        subText:    perfRoot.cpuTemp
                        gaugeColor: perfRoot.cpuUsage > 85 ? perfRoot.colRed
                                  : perfRoot.cpuUsage > 60 ? perfRoot.colYellow
                                  : perfRoot.colCyan
                        fontFamily: perfRoot.fontFamily
                        fontSize:   perfRoot.fontSize
                        colBg:      perfRoot.colBg
                        colFg:      perfRoot.colFg
                        colMuted:   perfRoot.colMuted
                    }

                    // RAM gauge
                    PerfGauge {
                        Layout.fillWidth: true
                        size:       72
                        value:      perfRoot.ramUsage
                        label:      "RAM"
                        valueText:  perfRoot.ramUsage + "%"
                        subText:    perfRoot.ramUsedMB > 0
                                        ? perfRoot.ramUsedMB + "M"
                                        : "--"
                        gaugeColor: perfRoot.ramUsage > 85 ? perfRoot.colRed
                                  : perfRoot.ramUsage > 65 ? perfRoot.colYellow
                                  : perfRoot.colLBlue
                        fontFamily: perfRoot.fontFamily
                        fontSize:   perfRoot.fontSize
                        colBg:      perfRoot.colBg
                        colFg:      perfRoot.colFg
                        colMuted:   perfRoot.colMuted
                    }

                    // GPU gauge (только если доступен)
                    PerfGauge {
                        Layout.fillWidth: true
                        size:       72
                        value:      perfRoot.gpuAvail ? perfRoot.gpuUsage : 0
                        label:      perfRoot.gpuName
                        valueText:  perfRoot.gpuAvail ? perfRoot.gpuUsage + "%" : "N/A"
                        subText:    perfRoot.gpuTemp
                        gaugeColor: !perfRoot.gpuAvail           ? perfRoot.colMuted
                                  : perfRoot.gpuUsage > 85       ? perfRoot.colRed
                                  : perfRoot.gpuUsage > 60       ? perfRoot.colYellow
                                  : perfRoot.colGreen
                        fontFamily: perfRoot.fontFamily
                        fontSize:   perfRoot.fontSize
                        colBg:      perfRoot.colBg
                        colFg:      perfRoot.colFg
                        colMuted:   perfRoot.colMuted
                    }
                }
            }

            // Разделитель
                        Rectangle {
                Layout.fillWidth: true
                height: 1
                color: perfRoot.colMuted
                opacity: 0.2
            }

            // ── Детальная информация: текстовые строки ────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: detailCol.implicitHeight + 16
                color: "transparent"

                ColumnLayout {
                    id: detailCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 12
                        topMargin: 8
                    }
                    spacing: 8

                    // CPU строка
                    PerfDetailRow {
                        label: "CPU"
                        value: perfRoot.cpuUsage + "%"
                        extra: perfRoot.cpuTemp !== "--" ? "  " + perfRoot.cpuTemp : ""
                        barValue: perfRoot.cpuUsage
                        barColor: perfRoot.cpuUsage > 85 ? perfRoot.colRed
                                : perfRoot.cpuUsage > 60 ? perfRoot.colYellow
                                : perfRoot.colCyan
                        fontFamily: perfRoot.fontFamily
                        fontSize:   perfRoot.fontSize
                        colFg:      perfRoot.colFg
                        colMuted:   perfRoot.colMuted
                        colBg:      perfRoot.colBg
                    }

                    // RAM строка
                    PerfDetailRow {
                        label: "RAM"
                        value: perfRoot.ramUsage + "%"
                        extra: perfRoot.ramLabel !== "--"
                            ? "  " + perfRoot.ramLabel
                            : ""
                        barValue: perfRoot.ramUsage
                        barColor: perfRoot.ramUsage > 85 ? perfRoot.colRed
                                : perfRoot.ramUsage > 65 ? perfRoot.colYellow
                                : perfRoot.colLBlue
                        fontFamily: perfRoot.fontFamily
                        fontSize:   perfRoot.fontSize
                        colFg:      perfRoot.colFg
                        colMuted:   perfRoot.colMuted
                        colBg:      perfRoot.colBg
                    }

                    // GPU строка
                    PerfDetailRow {
                        label: perfRoot.gpuName
                        value: perfRoot.gpuAvail ? perfRoot.gpuUsage + "%" : "N/A"
                        extra: perfRoot.gpuTemp !== "--"
                            ? "  " + perfRoot.gpuTemp
                            : ""
                        barValue: perfRoot.gpuAvail ? perfRoot.gpuUsage : 0
                        barColor: !perfRoot.gpuAvail         ? perfRoot.colMuted
                                : perfRoot.gpuUsage > 85     ? perfRoot.colRed
                                : perfRoot.gpuUsage > 60     ? perfRoot.colYellow
                                : perfRoot.colGreen
                        fontFamily: perfRoot.fontFamily
                        fontSize:   perfRoot.fontSize
                        colFg:      perfRoot.gpuAvail ? perfRoot.colFg : perfRoot.colMuted
                        colMuted:   perfRoot.colMuted
                        colBg:      perfRoot.colBg
                    }
                }
            }

            // Разделитель
                        Rectangle {
                Layout.fillWidth: true
                height: 1
                color: perfRoot.colMuted
                opacity: 0.2
            }

            // ── Топ процессов по CPU ───────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: topProcCol.implicitHeight + 16
                color: Qt.rgba(0.18, 0.21, 0.25, 0.3)

                ColumnLayout {
                    id: topProcCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 10
                        topMargin: 8
                    }
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "󰋊  Top Processes"
                                                        font {
                                pixelSize: perfRoot.fontSize - 3
                                family: perfRoot.fontFamily
                                bold: true
                            }
                            color: perfRoot.colMuted
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "󰑐"
                                                        font {
                                pixelSize: perfRoot.fontSize - 3
                                family: perfRoot.fontFamily
                            }
                            color: topProcRefreshMa.containsMouse ? perfRoot.colCyan : perfRoot.colMuted
                            Behavior on color { ColorAnimation { duration: 80 } }

                            RotationAnimation on rotation {
                                running: topProcFetchProc.running
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 800
                            }

                            MouseArea {
                                id: topProcRefreshMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: topProcFetchProc.running = true
                            }
                        }
                    }

                    // Список топ-5 процессов
                    Repeater {
                        model: topProcModel

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: modelData.name
                                                                font {
                                    pixelSize: perfRoot.fontSize - 5
                                    family: perfRoot.fontFamily
                                }
                                color: perfRoot.colFg
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.cpu + "%"
                                                                font {
                                    pixelSize: perfRoot.fontSize - 5
                                    family: perfRoot.fontFamily
                                    bold: true
                                }
                                color: parseFloat(modelData.cpu) > 50 ? perfRoot.colRed
                                     : parseFloat(modelData.cpu) > 20 ? perfRoot.colYellow
                                     : perfRoot.colCyan
                                Layout.preferredWidth: 40
                                horizontalAlignment: Text.AlignRight
                            }

                            Text {
                                text: modelData.mem + "M"
                                                                font {
                                    pixelSize: perfRoot.fontSize - 5
                                    family: perfRoot.fontFamily
                                }
                                color: perfRoot.colMuted
                                Layout.preferredWidth: 42
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    Item { height: 2 }
                }
            }

            Item { height: 8 }
        }
    }

    // ── Топ процессов — данные ────────────────────────────────────────────
    ListModel { id: topProcModel }

    Process {
        id: topProcFetchProc
        // ps: PID, %CPU, RSS(KB), COMMAND — сортировка по CPU desc, топ-5
        command: ["sh", "-c",
            "ps -eo comm,pcpu,rss --sort=-pcpu --no-headers | head -5"]
        stdout: SplitParser {
            property var _lines: []
            onRead: data => {
                var t = data.trim()
                if (t) _lines.push(t)
            }
        }
        onRunningChanged: {
            if (!running) {
                topProcModel.clear()
                var lines = stdout._lines || []
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(/\s+/)
                    if (parts.length >= 3) {
                        topProcModel.append({
                            name: parts[0].substring(0, 18),
                            cpu:  parseFloat(parts[1]).toFixed(1),
                            mem:  Math.round(parseInt(parts[2]) / 1024)
                        })
                    }
                }
                stdout._lines = []
            }
        }
        Component.onCompleted: running = true
    }

    // Обновляем топ процессов каждые 5 секунд (реже чем метрики)
    Timer {
        interval: 5000
        running:  perfRoot.isVisible
        repeat:   true
        onTriggered: topProcFetchProc.running = true
    }

    // ── Переиспользуемая строка детальной информации ──────────────────────
    component PerfDetailRow: Item {
        property string label:      ""
        property string value:      ""
        property string extra:      ""
        property real   barValue:   0
        property color  barColor:   "#8fbcbb"
        property string fontFamily: "Monaspace Krypton Medium"
        property int    fontSize:   16
        property color  colFg:      "#d8dee9"
        property color  colMuted:   "#4c566a"
        property color  colBg:      "#2e3440"

        Layout.fillWidth: true
        implicitHeight: 28

        ColumnLayout {
            anchors.fill: parent
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: label
                                        font {
                        pixelSize: fontSize - 4
                        family: fontFamily
                    }
                    color: colMuted
                    Layout.preferredWidth: 48
                }

                Text {
                    text: value
                                        font {
                        pixelSize: fontSize - 4
                        family: fontFamily
                        bold: true
                    }
                    color: barColor
                }

                Text {
                    text: extra
                                        font {
                        pixelSize: fontSize - 5
                        family: fontFamily
                    }
                    color: colMuted
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            // Прогресс-бар
            Rectangle {
                Layout.fillWidth: true
                height: 3
                color: Qt.rgba(
                    Qt.color(colMuted).r,
                    Qt.color(colMuted).g,
                    Qt.color(colMuted).b,
                    0.25)

                Rectangle {
                    height: parent.height
                    width:  parent.width * Math.max(0, Math.min(barValue, 100)) / 100
                    color:  barColor
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
