import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Fusion
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    // ── Обязательное свойство из WlSessionLockSurface ────────────
    required property var context

    // ── Palette (Nord / твой SDDM конфиг) ────────────────────────
    readonly property color textPrimary:   "#ffffff"
    readonly property color textSecondary: "#99aab5"
    readonly property color accent:        "#cde4ef"

    // ── Font ──────────────────────────────────────────────────────
    FontLoader {
        id: mainFont
        source: Quickshell.shellPath("font/MonaspaceKrypton-Regular.otf")
    }

    // ── Читаем текущие обои через симлинк ─────────────────────────
    property string wallpaperPath: ""
    property bool   wallpaperIsGif: false

    Process {
        id: wallpaperProc
        command: ["readlink", "-f",
            Quickshell.env("HOME") + "/.config/hypr/wallpaper/current"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim()
                if (p) {
                    root.wallpaperPath  = p
                    root.wallpaperIsGif = p.toLowerCase().endsWith(".gif")
                }
            }
        }
    }

    // ── Базовый фон ───────────────────────────────────────────────
    color: "#05080c"

    // ── Статичная картинка (jpg / png / webp) ─────────────────────
    Image {
        anchors.fill: parent
        source: (!root.wallpaperIsGif && root.wallpaperPath)
            ? "file://" + root.wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
        visible: !root.wallpaperIsGif && status === Image.Ready
        asynchronous: true
    }

    // ── GIF ───────────────────────────────────────────────────────
    AnimatedImage {
        anchors.fill: parent
        source: (root.wallpaperIsGif && root.wallpaperPath)
            ? "file://" + root.wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
        playing: true
        visible: root.wallpaperIsGif && status === Image.Ready
        asynchronous: true
    }

    // ── Градиент снизу ────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        z: -1
        gradient: Gradient {
            GradientStop { position: 0.0;  color: "#00000000" }
            GradientStop { position: 0.55; color: "#00000000" }
            GradientStop { position: 1.0;  color: "#cc05080c" }
        }
    }

    // ══════════════════════════════════════════════════════════════
    // КОНТЕНТ
    // ══════════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent

        // ── ЧАСЫ + ДАТА (верхний центр) ───────────────────────────
        Column {
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.11
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Text {
                id: clockText
                anchors.horizontalCenter: parent.horizontalCenter
                renderType: Text.NativeRendering
                font.family: mainFont.name
                font.pixelSize: parent.parent.width * 0.094
                font.weight: Font.Thin
                color: root.textPrimary
                layer.enabled: true
                layer.effect: DropShadow {
                    color: "#60000000"; radius: 20
                    samples: 31; verticalOffset: 5; transparentBorder: true
                }

                property var date: new Date()
                text: {
                    const h = date.getHours().toString().padStart(2, '0')
                    const m = date.getMinutes().toString().padStart(2, '0')
                    return h + ":" + m
                }

                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: clockText.date = new Date()
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                renderType: Text.NativeRendering
                font.family: mainFont.name
                font.pixelSize: parent.parent.width * 0.0094
                font.letterSpacing: parent.parent.width * 0.006
                font.weight: Font.DemiBold
                color: root.textPrimary
                opacity: 0.85
                layer.enabled: true
                layer.effect: DropShadow {
                    color: "#55ffffff"; radius: 10
                    samples: 25; verticalOffset: 0; transparentBorder: true
                }
                property var date: new Date()
                text: Qt.formatDate(date, "dddd, MMMM d").toUpperCase()
                Timer {
                    interval: 60000; running: true; repeat: true
                    onTriggered: parent.date = new Date()
                }
            }
        }

        // ── ПОЛЕ ПАРОЛЯ (центр + смещение вниз) ──────────────────
        Item {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: parent.height * 0.12
            width: parent.width * 0.21
            height: 140

            Column {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width

                // Имя пользователя
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "USER"
                        renderType: Text.NativeRendering
                        font.family: mainFont.name
                        font.pixelSize: 11
                        font.letterSpacing: 4
                        color: root.textSecondary
                        opacity: 0.8
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (Quickshell.env("USER") || "USER").toUpperCase()
                        renderType: Text.NativeRendering
                        font.family: mainFont.name
                        font.pixelSize: 17
                        font.letterSpacing: 3
                        font.weight: Font.Bold
                        color: root.textPrimary
                    }
                }

                // Поле ввода пароля
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: 50

                    TextField {
                        id: passwordBox
                        anchors.fill: parent

                        // ── Стиль — прозрачный, только текст по центру ──
                        background: Item {}
                        leftPadding: 0; rightPadding: 0
                        topPadding: 0;  bottomPadding: 0

                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "✦"
                        inputMethodHints: Qt.ImhSensitiveData
                        renderType: Text.NativeRendering

                        font.family: mainFont.name
                        font.pixelSize: 30
                        font.letterSpacing: 8
                        color: root.textPrimary

                        focus: true
                        enabled: !root.context.unlockInProgress
                        cursorVisible: false
                        cursorDelegate: Item { width: 0; height: 0 }

                        // Синхронизируем с LockContext (для multi-monitor)
                        onTextChanged: root.context.currentText = this.text

                        Connections {
                            target: root.context
                            function onCurrentTextChanged() {
                                if (passwordBox.text !== root.context.currentText)
                                    passwordBox.text = root.context.currentText
                            }
                        }

                        onAccepted: root.context.tryUnlock()

                        // Placeholder "PASSWORD"
                        Text {
                            anchors.centerIn: parent
                            text: root.context.unlockInProgress ? "..." : "PASSWORD"
                            renderType: Text.NativeRendering
                            font.family: mainFont.name
                            font.pixelSize: 13
                            font.letterSpacing: 6
                            color: root.textSecondary
                            opacity: passwordBox.text.length === 0 ? 0.6 : 0.0
                            Behavior on opacity {
                                NumberAnimation { duration: 400; easing.type: Easing.InOutSine }
                            }
                        }

                        // Мигающий курсор
                        Rectangle {
                            width: 2; height: parent.height * 0.65
                            anchors.verticalCenter: parent.verticalCenter
                            x: passwordBox.cursorRectangle.x - 1
                            visible: passwordBox.activeFocus && passwordBox.text.length > 0
                        }

                        // Анимация встряски при ошибке
                        SequentialAnimation {
                            id: errorShake
                            running: root.context.showFailure
                            NumberAnimation { target: passwordBox; property: "x"; to: -12; duration: 50 }
                            NumberAnimation { target: passwordBox; property: "x"; to:  12; duration: 50 }
                            NumberAnimation { target: passwordBox; property: "x"; to: -12; duration: 50 }
                            NumberAnimation { target: passwordBox; property: "x"; to:  12; duration: 50 }
                            NumberAnimation { target: passwordBox; property: "x"; to:  0;  duration: 50 }
                        }
                    }

                    // Подчёркивание
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 1
                        width: passwordBox.activeFocus ? parent.width : parent.width * 0.3
                        color: root.context.showFailure ? "#ff4444" : root.textPrimary
                        opacity: passwordBox.activeFocus ? 0.8 : 0.2
                        Behavior on width  { NumberAnimation { duration: 350; easing.type: Easing.OutQuart } }
                        Behavior on opacity { NumberAnimation { duration: 350 } }
                        Behavior on color  { ColorAnimation { duration: 200 } }
                    }
                }

                // Сообщение об ошибке
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.context.showFailure
                    text: "Incorrect password"
                    renderType: Text.NativeRendering
                    font.family: mainFont.name
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    color: "#ff6b6b"
                    opacity: 0.9
                }
            }
        }

        // ── ПИТАНИЕ (нижний правый угол) ──────────────────────────
        Item {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 80
            anchors.margins: 50

            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 24

                Text {
                    text: "REBOOT"
                    renderType: Text.NativeRendering
                    font.family: mainFont.name
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    color: rebootMa.containsMouse ? root.textPrimary : root.textSecondary
                    scale: rebootMa.containsMouse ? 1.12 : 1.0
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                    MouseArea {
                        id: rebootMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                    }
                }

                Text {
                    text: "SHUTDOWN"
                    renderType: Text.NativeRendering
                    font.family: mainFont.name
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    color: powerMa.containsMouse ? "#ff6b6b" : root.textSecondary
                    scale: powerMa.containsMouse ? 1.12 : 1.0
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                    MouseArea {
                        id: powerMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                    }
                }
            }
        }
    }
}
