// Standalone wallpaper selector — запускается отдельно:
//   quickshell -c hyprquickpaper
// Биндинг в hyprland.conf:
//   bind = SUPER, R, exec, quickshell -c hyprquickpaper
// Зависимости: imagemagick (cache.sh), jq (config.json), python3 (wallpaper_search.py)
// config.json: { "wallpaper_path": "...", "cache_path": "...", "number_of_pictures": 6 }

import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: main

    // ── Палитра (совпадает с основным шеллом) ─────────────────────
    readonly property color colBg: "#2e3440"
    readonly property color colFg: "#e5e9f0"
    readonly property color colAccent: "#d8dee9"
    readonly property color colMuted: "#4c566a"
    readonly property color colSurface: "#3b4252"
    readonly property color colCyan: "#8fbcbb"
    readonly property color colBlue: "#5e81ac"
    readonly property color colLightBlue: "#81a1c1"
    readonly property color colRed: "#bf616a"
    readonly property color colGreen: "#a3be8c"
    readonly property color colYellow: "#ebcb8b"
    readonly property string fontFamily: "Monaspace Krypton Medium"
    readonly property int fontSize: 16

    // Наклон — одно место для всего UI
    // Тайлы используют xFactor: -0.2, yFactor: 0.15
    // Кнопки и строка поиска — только xFactor: -0.2
    readonly property real shearX: -0.2
    readonly property real shearY: 0.15

    // ── Состояние ─────────────────────────────────────────────────
    property bool onlineTab: false

    implicitHeight: 400
    implicitWidth: Screen.width
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 1
    anchors {
        bottom: true
        left: true
        right: true
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted: {
        Quickshell.execDetached(["bash", Quickshell.shellPath("cache.sh"), Quickshell.shellDir]);
    }

    // ── config.json ───────────────────────────────────────────────
    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs

            property string wallpaper_path
            property string cache_path
            property int number_of_pictures: 6
        }
    }

    // ── Локальная модель ──────────────────────────────────────────
    FolderListModel {
        id: folderModel

        folder: "file://" + configs.wallpaper_path
        showDirs: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif"]
        sortField: FolderListModel.Name
    }

    // ── Wallpaperflare через Python-скрипт ────────────────────────
    WallpaperApi {
        id: api
        shellDir: Quickshell.shellDir
    }

    // ── Верхняя панель ────────────────────────────────────────────
    Column {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        // ── Строка кнопок ─────────────────────────────────────────
        Item {
            width: parent.width
            height: 54

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 36
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16

                // Кнопка Local
                Item {
                    width: 110
                    height: 38
                    transform: Shear {
                        xFactor: main.shearX
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: !main.onlineTab ? main.colBlue : main.colMuted
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            // Компенсация наклона — текст остаётся прямым
                            transform: Shear {
                                xFactor: -main.shearX
                            }
                            text: "Local"
                            color: !main.onlineTab ? main.colFg : main.colAccent
                            font.pixelSize: main.fontSize
                            font.family: main.fontFamily
                            font.bold: !main.onlineTab
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            main.onlineTab = false;
                            list.selectedIndex = 0;
                            list.forceActiveFocus();
                        }
                    }
                }

                // Кнопка Online
                Item {
                    width: 110
                    height: 38
                    transform: Shear {
                        xFactor: main.shearX
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: main.onlineTab ? main.colCyan : main.colMuted
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            transform: Shear {
                                xFactor: -main.shearX
                            }
                            text: "Online"
                            color: main.onlineTab ? main.colBg : main.colAccent
                            font.pixelSize: main.fontSize
                            font.family: main.fontFamily
                            font.bold: main.onlineTab
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            main.onlineTab = true;
                            list.selectedIndex = 0;
                            searchInput.forceActiveFocus();
                        }
                    }
                }

                // Индикатор загрузки
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: api.loading
                    text: "Searching..."
                    color: main.colMuted
                    font.pixelSize: main.fontSize - 2
                    font.family: main.fontFamily
                }

                // Сообщение об ошибке
                Text {
                    id: errorText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    color: main.colRed
                    font.pixelSize: main.fontSize - 2
                    font.family: main.fontFamily

                    Connections {
                        target: api
                        function onErrorOccurred(msg) {
                            errorText.text = msg;
                            errorClear.restart();
                        }
                        function onSearchStarted() {
                            errorText.text = "";
                        }
                    }

                    Timer {
                        id: errorClear
                        interval: 4000
                        onTriggered: errorText.text = ""
                    }
                }
            }
        }

        // ── Поисковая строка (только Online) ─────────────────────
        Item {
            width: parent.width
            height: main.onlineTab ? 46 : 0
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: 150
                }
            }

            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 36
                anchors.rightMargin: 36
                height: 36

                transform: Shear {
                    xFactor: main.shearX
                }

                Rectangle {
                    anchors.fill: parent
                    color: main.colSurface
                    border.width: searchInput.activeFocus ? 1 : 0
                    border.color: main.colCyan
                    Behavior on border.width {
                        NumberAnimation {
                            duration: 100
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            // Текст иконки поиска — компенсируем наклон
                            transform: Shear {
                                xFactor: -main.shearX
                            }
                            text: "⌕"
                            color: main.colMuted
                            font.pixelSize: 20
                        }

                        TextInput {
                            id: searchInput
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 44
                            color: main.colFg
                            font.pixelSize: main.fontSize - 2
                            font.family: main.fontFamily
                            selectionColor: main.colBlue
                            clip: true
                            enabled: main.onlineTab

                            Text {
                                anchors.fill: parent
                                visible: searchInput.text === "" && !searchInput.activeFocus
                                text: "Search wallpaperflare..."
                                color: main.colMuted
                                font.pixelSize: main.fontSize - 2
                                font.family: main.fontFamily
                            }

                            Keys.onReturnPressed: {
                                const q = text.trim();
                                if (q !== "")
                                    api.search(q);
                            }
                            // Esc — выход, Tab — переключить вкладку
                            Keys.onEscapePressed: Qt.quit()
                            Keys.onTabPressed: {
                                main.onlineTab = false;
                                list.selectedIndex = 0;
                                list.forceActiveFocus();
                            }
                            // Стрелки из поля поиска передаём в список
                            Keys.onLeftPressed: {
                                list.selectedIndex = list.clampIndex(list.selectedIndex - 1);
                                list.ensureVisibleAnimated(list.selectedIndex);
                            }
                            Keys.onRightPressed: {
                                list.selectedIndex = list.clampIndex(list.selectedIndex + 1);
                                list.ensureVisibleAnimated(list.selectedIndex);
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Горизонтальный список ─────────────────────────────────────
    ListView {
        id: list

        property int selectedIndex: 0
        readonly property real tileWidth: width / configs.number_of_pictures - spacing

        function clampIndex(i) {
            return Math.max(0, Math.min(i, count - 1));
        }

        function activateCurrent() {
            if (main.onlineTab) {
                const item = api.model.get(selectedIndex);
                if (!item || !item.apiUrl)
                    return;
                // Передаём прямой URL картинки — commands.sh должен уметь скачать его
                Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), item.apiUrl]);
            } else {
                const path = folderModel.get(selectedIndex, "filePath");
                if (!path)
                    return;
                Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), path]);
            }
            Qt.quit();
        }

        function clampX(x) {
            return Math.max(0, Math.min(x, contentWidth - width));
        }

        function ensureVisibleAnimated(i) {
            const step = tileWidth + spacing;
            const itemStart = i * step;
            const itemEnd = itemStart + tileWidth + 20;
            if (itemStart < contentX)
                contentX = clampX(itemStart);
            else if (itemEnd > contentX + width)
                contentX = clampX(itemStart - (width - step));
        }

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -10

        // focus управляется явно — не конкурирует с searchInput
        focus: !main.onlineTab || !searchInput.activeFocus
        model: main.onlineTab ? api.model : folderModel
        orientation: ListView.Horizontal
        clip: true
        cacheBuffer: width * 2

        // ── Клавиши ───────────────────────────────────────────────
        Keys.onPressed: function (event) {
            const step = 1;
            const big = configs.number_of_pictures;
            switch (event.key) {
            case Qt.Key_J:
            case Qt.Key_Right:
                list.selectedIndex = list.clampIndex(list.selectedIndex + step);
                list.ensureVisibleAnimated(list.selectedIndex);
                break;
            case Qt.Key_K:
            case Qt.Key_Left:
                list.selectedIndex = list.clampIndex(list.selectedIndex - step);
                list.ensureVisibleAnimated(list.selectedIndex);
                break;
            case Qt.Key_D:
                list.selectedIndex = list.clampIndex(list.selectedIndex + big);
                list.ensureVisibleAnimated(list.selectedIndex);
                break;
            case Qt.Key_U:
                list.selectedIndex = list.clampIndex(list.selectedIndex - big);
                list.ensureVisibleAnimated(list.selectedIndex);
                break;
            case Qt.Key_Tab:
                main.onlineTab = !main.onlineTab;
                list.selectedIndex = 0;
                if (main.onlineTab)
                    searchInput.forceActiveFocus();
                else
                    list.forceActiveFocus();
                break;
            case Qt.Key_Return:
            case Qt.Key_Space:
                list.activateCurrent();
                break;
            case Qt.Key_Escape:
                Qt.quit();
                break;
            default:
                return;
            }
            event.accepted = true;
        }

        Behavior on contentX {
            SmoothedAnimation {
                duration: 120
            }
        }

        // ── Delegate ──────────────────────────────────────────────
        delegate: Item {
            readonly property bool active: index === list.selectedIndex
            readonly property bool isOnline: main.onlineTab
            readonly property string thumbSource: isOnline ? (model.apiThumb || "") : ("file://" + configs.cache_path + (model.fileName || ""))
            readonly property string displayName: isOnline ? (model.apiTitle || "") : (model.fileName || "")

            // Больший наклон — соответствует shearX/shearY
            transform: Shear {
                xFactor: main.shearX
                yFactor: main.shearY
            }

            width: list.tileWidth
            height: list.height
            layer.live: true

            Behavior on width {
                PropertyAnimation {
                    duration: 120
                }
            }
            Behavior on height {
                PropertyAnimation {
                    duration: 120
                }
            }

            // GIF-бейдж
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 6
                width: 44
                height: 20
                color: main.colBg
                visible: !isOnline && displayName.toLowerCase().endsWith(".gif")
                z: 3

                Text {
                    anchors.centerIn: parent
                    text: "GIF"
                    color: main.colCyan
                    font.pixelSize: 11
                    font.bold: true
                    font.family: main.fontFamily
                }
            }

            // Thumbnail
            Image {
                id: img

                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                smooth: true
                source: thumbSource
                sourceSize.width: width
                sourceSize.height: height

                onStatusChanged: {
                    if (status === Image.Error)
                        retryTimer.start();
                }

                Timer {
                    id: retryTimer
                    interval: 1500
                    repeat: false
                    onTriggered: {
                        const s = img.source;
                        img.source = "";
                        img.source = s;
                    }
                }

                // Placeholder
                Rectangle {
                    anchors.fill: parent
                    visible: img.status !== Image.Ready
                    color: main.colSurface

                    Text {
                        anchors.centerIn: parent
                        text: img.status === Image.Error ? (isOnline ? "No image" : "Caching...") : "Loading..."
                        color: main.colMuted
                        font.pixelSize: main.fontSize - 4
                        font.family: main.fontFamily
                    }
                }
            }

            // Оверлей неактивных
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, active ? 0 : 0.45)
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }

            // Рамка активного
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: active ? 3 : 0
                border.color: main.colAccent
                visible: active
                Behavior on border.width {
                    NumberAnimation {
                        duration: 80
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    list.selectedIndex = index;
                    list.activateCurrent();
                }
                onWheel: function (wheel) {
                    list.contentX = list.clampX(list.contentX - wheel.angleDelta.y * 2);
                    wheel.accepted = false;
                }
            }
        }
    }
}
