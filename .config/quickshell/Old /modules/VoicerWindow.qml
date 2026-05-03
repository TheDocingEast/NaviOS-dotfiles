// modules/VoicerWindow.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

PopupWindow {
    id: root

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

    implicitWidth:  560
    implicitHeight: 420
    color:   "transparent"
    visible: false

    // FocusGrab только с биндингом — никогда не трогать .active руками
    HyprlandFocusGrab {
        id: winFocus
        windows: [root]
        active:    root.visible
        onCleared: root.visible = false
    }
    

    onVisibleChanged: {
        if (visible) {
            mainCard.scale   = 0.94;
            mainCard.opacity = 0;
            showAnim.restart();
        }
    }
    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: mainCard; property: "scale";   to: 1.0; duration: 160; easing.type: Easing.OutCubic }
        NumberAnimation { target: mainCard; property: "opacity"; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: mainCard
        anchors.fill:    parent
        color:           root.colBg
        border.color:    root.colBlue
        border.width:    2
        radius:          10
        transformOrigin: Item.BottomRight
        clip: true

        property int activeTab: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Вкладки ───────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth:   true
                Layout.topMargin:   6
                Layout.leftMargin:  8
                Layout.rightMargin: 8
                spacing: 0

                WinTabBtn { tabText: "󰍬  Синтез";     active: mainCard.activeTab === 0; onClicked: mainCard.activeTab = 0; Layout.fillWidth: true }
                WinTabBtn { tabText: "󰕖  Фразы";      active: mainCard.activeTab === 1; onClicked: mainCard.activeTab = 1; Layout.fillWidth: true }
                WinTabBtn { tabText: "  VirtualMic"; active: mainCard.activeTab === 2; onClicked: mainCard.activeTab = 2; Layout.fillWidth: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.colMuted; opacity: 0.3 }

            // ── Вкладка 0: Синтез ─────────────────────────────────────────
            Item {
                visible:          mainCard.activeTab === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                


                RowLayout {
                    anchors.fill:    parent
                    anchors.margins: 8
                    spacing: 8

                    // Левая панель — список голосов
                    Rectangle {
                        Layout.preferredWidth: 160
                        Layout.fillHeight:     true
                        color:        Qt.rgba(0, 0, 0, 0.15)
                        radius:       6
                        border.color: root.colMuted
                        border.width: 1

                        ColumnLayout {
                            anchors.fill:    parent
                            anchors.margins: 6
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text:           "Голоса"
                                    font.pixelSize: root.fontSize - 4
                                    font.family:    root.fontFamily
                                    color:          root.colLBlue
                                    opacity:        0.8
                                    Layout.fillWidth: true
                                }
                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    color: VoiceChangerService.vcRtActive ? root.colGreen
                                         : VoiceChangerService.vcBusy     ? root.colYellow
                                         : VoiceChangerService.vcReady    ? root.colCyan
                                         :                                   root.colMuted
                                    SequentialAnimation on opacity {
                                        running: VoiceChangerService.vcBusy || VoiceChangerService.vcRtActive
                                        loops:   Animation.Infinite
                                        NumberAnimation { to: 0.2; duration: 600; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                                    }
                                }
                                SmallBtn {
                                    btnText:   VoiceChangerService.vcLoaded ? "󰒲" : "󰒳"
                                    btnActive: !VoiceChangerService.vcBusy && !VoiceChangerService.vcRtActive
                                    onClicked: {
                                        if (VoiceChangerService.vcLoaded) VoiceChangerService.unload();
                                        else VoiceChangerService.load();
                                    }
                                }
                            }

                            Text {
                                text:             VoiceChangerService.vcStatus
                                font.pixelSize:   root.fontSize - 5
                                font.family:      root.fontFamily
                                color:            root.colMuted
                                Layout.fillWidth: true
                                elide:            Text.ElideRight
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: root.colMuted; opacity: 0.3 }

                            ListView {
                                id: voiceListView
                                Layout.fillWidth:  true
                                Layout.fillHeight: true
                                clip:    true
                                spacing: 2
                                model:   VoiceChangerService.voicesList

                                delegate: Rectangle {
                                    width:  voiceListView.width
                                    height: 28
                                    radius: 5
                                    color: VoiceChangerService.currentVoiceIdx === index
                                        ? Qt.rgba(0.37, 0.51, 0.67, 0.3)
                                        : vMouse.containsMouse
                                            ? Qt.rgba(1, 1, 1, 0.05)
                                            : "transparent"
                                    Behavior on color { ColorAnimation { duration: 80 } }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left:           parent.left
                                        anchors.right:          parent.right
                                        anchors.leftMargin:     8
                                        anchors.rightMargin:    8
                                        text:           modelData.name || ("Голос " + (index + 1))
                                        font.pixelSize: root.fontSize - 4
                                        font.family:    root.fontFamily
                                        color: VoiceChangerService.currentVoiceIdx === index
                                            ? root.colFg : root.colMuted
                                        elide: Text.ElideRight
                                    }
                                    MouseArea {
                                        id: vMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape:  Qt.PointingHandCursor
                                        onClicked: {
                                            if (VoiceChangerService.vcReady)
                                                VoiceChangerService.selectVoice(index);
                                        }
                                    }
                                }

                                Text {
                                    visible:            VoiceChangerService.voicesList.length === 0
                                    anchors.centerIn:   parent
                                    text:               "voice/voices.json\nне найден"
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize:     root.fontSize - 5
                                    font.family:        root.fontFamily
                                    color:              root.colMuted
                                    opacity:            0.6
                                }
                            }
                        }
                    }

                    // Правая панель
                    ColumnLayout {
                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        spacing: 8

                        VolRow {
                            id: micVolRow
                            icon:      "󰍬"
                            iconColor: root.colCyan
                            curVal:    VoiceChangerService.vcMicVolume
                            maxVal:    4.0
                            Layout.fillWidth: true
                            onMoved: function(v) {
                                VoiceChangerService.vcMicVolume = v;
                                VoiceChangerService.send({ cmd: "set_mic_volume", volume: v });
                            }
                        }

                        VolRow {
                            id: spkVolRow
                            icon:      "󰋋"
                            iconColor: root.colYellow
                            curVal:    VoiceChangerService.vcSpeakerVolume
                            maxVal:    2.0
                            Layout.fillWidth: true
                            onMoved: function(v) {
                                VoiceChangerService.vcSpeakerVolume = v;
                                VoiceChangerService.send({ cmd: "set_speaker_volume", volume: v });
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colMuted; opacity: 0.25 }

                        // TTS input
                        Rectangle {
                            
                            Layout.fillWidth: true
                            height: 34
                            color:        Qt.rgba(1, 1, 1, 0.04)
                            border.color: vcTextInput.activeFocus ? root.colBlue : root.colMuted
                            border.width: 1
                            radius: 6
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                            Keys.onEscapePressed: Quickshell.quit()

                            Text {
                                anchors.left:           parent.left
                                anchors.right:          parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins:        8
                                text:           "Текст для синтеза..."
                                font.pixelSize: root.fontSize - 3
                                font.family:    root.fontFamily
                                color:          root.colMuted
                                visible: vcTextInput.text.length === 0 && !vcTextInput.activeFocus
                            }
                            TextInput {
                                focus: true
                                id: vcTextInput
                                anchors.left:           parent.left
                                anchors.right:          parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins:        8
                                color:          root.colFg
                                font.pixelSize: root.fontSize - 3
                                font.family:    root.fontFamily
                                enabled:        VoiceChangerService.vcReady && !VoiceChangerService.vcBusy
                                selectByMouse:  true
                                Keys.onReturnPressed: {
                                    if (text.trim().length > 0) {
                                        VoiceChangerService.tts(text.trim(), null);
                                        text = "";
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked:    vcTextInput.forceActiveFocus()
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            BigBtn {
                                btnText:          VoiceChangerService.vcBusy ? "󰔟  Генерирую..." : "󰔊  Синтез"
                                Layout.fillWidth: true
                                btnActive:        VoiceChangerService.vcReady && !VoiceChangerService.vcBusy && vcTextInput.text.trim().length > 0
                                onClicked: {
                                    VoiceChangerService.tts(vcTextInput.text.trim(), null);
                                    vcTextInput.text = "";
                                }
                            }
                            BigBtn {
                                btnText:          "󰆓  Сохранить"
                                Layout.fillWidth: true
                                btnActive:        VoiceChangerService.vcReady && !VoiceChangerService.vcBusy && vcTextInput.text.trim().length > 0
                                onClicked: {
                                    var t  = vcTextInput.text.trim();
                                    var fn = "phrase_" + Date.now() + ".wav";
                                    VoiceChangerService.tts(t, fn);
                                    VoiceChangerService.savePhrase(fn, t);
                                    vcTextInput.text = "";
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.colMuted; opacity: 0.25 }

                        BigBtn {
                            btnText:          VoiceChangerService.vcRtActive ? "⏹  Остановить RT" : "⏺  Realtime"
                            Layout.fillWidth: true
                            btnActive:        VoiceChangerService.vcReady && !VoiceChangerService.vcBusy
                            onClicked:        VoiceChangerService.send({ cmd: VoiceChangerService.vcRtActive ? "rt_stop" : "rt_start" })
                        }

                        Text {
                            Layout.fillWidth: true
                            text: VoiceChangerService.vcRtActive
                                ? "Микрофон → конвертер → VirtualMic"
                                : "Голос → QwenTTS → VirtualMic"
                            font.pixelSize: root.fontSize - 5
                            font.family:    root.fontFamily
                            color:    VoiceChangerService.vcRtActive ? root.colGreen : root.colMuted
                            wrapMode: Text.Wrap
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }

            // ── Вкладка 1: Фразы ──────────────────────────────────────────
            Item {
                visible:           mainCard.activeTab === 1
                Layout.fillWidth:  true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill:    parent
                    anchors.margins: 8
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text:             "Сохранённые фразы"
                            font.pixelSize:   root.fontSize - 3
                            font.family:      root.fontFamily
                            color:            root.colLBlue
                            opacity:          0.8
                            Layout.fillWidth: true
                        }
                        SmallBtn {
                            btnText:   "󰑐"
                            btnActive: true
                            onClicked: VoiceChangerService.refreshPhrases()
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.colMuted; opacity: 0.3 }

                    ListView {
                        id: phraseListView
                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        clip:    true
                        spacing: 3
                        model:   VoiceChangerService.phrasesList

                        delegate: Rectangle {
                            width:  phraseListView.width
                            height: 42
                            radius: 6
                            color:  phraseMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.05)
                                : Qt.rgba(0, 0, 0, 0.1)
                            border.color: root.colMuted
                            border.width: 1

                            RowLayout {
                                anchors.fill:        parent
                                anchors.leftMargin:  8
                                anchors.rightMargin: 6
                                spacing: 6

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text:             modelData.text || modelData.filename
                                        font.pixelSize:   root.fontSize - 4
                                        font.family:      root.fontFamily
                                        color:            root.colFg
                                        Layout.fillWidth: true
                                        elide:            Text.ElideRight
                                    }
                                    Text {
                                        text:           modelData.filename + "  " + modelData.duration + "с"
                                        font.pixelSize: root.fontSize - 6
                                        font.family:    root.fontFamily
                                        color:          root.colMuted
                                    }
                                }
                                SmallBtn {
                                    btnText:   "󰐊"
                                    btnActive: VoiceChangerService.vcLoaded
                                    onClicked: VoiceChangerService.send({ cmd: "play_phrase", filename: modelData.filename })
                                }
                                SmallBtn {
                                    btnText:     "󰆴"
                                    btnActive:   true
                                    dangerColor: true
                                    onClicked:   VoiceChangerService.deletePhrase(modelData.filename)
                                }
                            }

                            MouseArea {
                                id:              phraseMouse
                                anchors.fill:    parent
                                hoverEnabled:    true
                                acceptedButtons: Qt.NoButton
                            }
                        }

                        Text {
                            visible:          VoiceChangerService.phrasesList.length === 0
                            anchors.centerIn: parent
                            text:             "Нет сохранённых фраз"
                            font.pixelSize:   root.fontSize - 3
                            font.family:      root.fontFamily
                            color:            root.colMuted
                            opacity:          0.5
                        }
                    }
                }
            }

            // ── Вкладка 2: VirtualMic ─────────────────────────────────────
            Item {
                visible:           mainCard.activeTab === 2
                Layout.fillWidth:  true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill:    parent
                    anchors.margins: 8
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text:             "VirtualMic (PipeWire null sink)"
                            font.pixelSize:   root.fontSize - 3
                            font.family:      root.fontFamily
                            color:            root.colLBlue
                            opacity:          0.8
                            Layout.fillWidth: true
                        }
                        SmallBtn {
                            btnText:   "󰑐"
                            btnActive: true
                            onClicked: VoiceChangerService.refreshMics()
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.colMuted; opacity: 0.3 }

                    // Строка создания нового mic
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            height: 32
                            color:        Qt.rgba(1, 1, 1, 0.04)
                            border.color: micNameInput.activeFocus ? root.colBlue : root.colMuted
                            border.width: 1
                            radius: 6
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            TextInput {
                                id: micNameInput
                                anchors.left:           parent.left
                                anchors.right:          parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins:        8
                                text:           "VirtualMic"
                                color:          root.colFg
                                font.pixelSize: root.fontSize - 3
                                font.family:    root.fontFamily
                                selectByMouse:  true
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked:    micNameInput.forceActiveFocus()
                            }
                        }

                        BigBtn {
                            btnText:             "  Создать"
                            Layout.preferredWidth: 80
                            btnActive:           micNameInput.text.trim().length > 0
                            onClicked:           VoiceChangerService.createMic(micNameInput.text.trim())
                        }
                    }

                    ListView {
                        id: micListView
                        Layout.fillWidth:  true
                        Layout.fillHeight: true
                        clip:    true
                        spacing: 3
                        model:   VoiceChangerService.micsList

                        delegate: Rectangle {
                            width:  micListView.width
                            height: 36
                            radius: 6
                            color:  micItemMouse.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.05)
                                : Qt.rgba(0, 0, 0, 0.1)
                            border.color: root.colMuted
                            border.width: 1

                            RowLayout {
                                anchors.fill:        parent
                                anchors.leftMargin:  10
                                anchors.rightMargin: 6
                                spacing: 6
                                Text {
                                    text:             " " + modelData
                                    font.pixelSize:   root.fontSize - 3
                                    font.family:      root.fontFamily
                                    color:            root.colFg
                                    Layout.fillWidth: true
                                }
                                SmallBtn {
                                    btnText:     "󰆴"
                                    btnActive:   true
                                    dangerColor: true
                                    onClicked:   VoiceChangerService.deleteMic(modelData)
                                }
                            }

                            MouseArea {
                                id:              micItemMouse
                                anchors.fill:    parent
                                hoverEnabled:    true
                                acceptedButtons: Qt.NoButton
                            }
                        }

                        Text {
                            visible:          VoiceChangerService.micsList.length === 0
                            anchors.centerIn: parent
                            text:             "Нет VirtualMic устройств"
                            font.pixelSize:   root.fontSize - 3
                            font.family:      root.fontFamily
                            color:            root.colMuted
                            opacity:          0.5
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text:    "Sink-и удаляются при перезапуске PipeWire. Для постоянного — /etc/pipewire/pipewire.conf.d/"
                        font.pixelSize: root.fontSize - 6
                        font.family:    root.fontFamily
                        color:          root.colMuted
                        opacity:        0.6
                        wrapMode:       Text.Wrap
                    }
                }
            }
        }
    }

    // ── Компоненты ────────────────────────────────────────────────────────

    component WinTabBtn: Item {
        property string tabText: ""
        property bool   active:  false
        signal clicked
        height: 30

        Rectangle {
            anchors.fill: parent; radius: 6
            color: parent.active ? Qt.rgba(0.37, 0.51, 0.67, 0.25) : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Rectangle {
            visible:        parent.active
            anchors.bottom: parent.bottom
            anchors.left:   parent.left
            anchors.right:  parent.right
            height: 2; radius: 1; color: root.colBlue
        }
        Text {
            anchors.centerIn: parent
            text:             parent.tabText
            font.pixelSize:   root.fontSize - 3
            font.family:      root.fontFamily
            color: parent.active ? root.colFg : root.colMuted
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked:    parent.clicked()
        }
    }

    component SmallBtn: Item {
        property string btnText:     ""
        property bool   btnActive:   true
        property bool   dangerColor: false
        signal clicked
        width: 24; height: 24
        opacity: btnActive ? 1.0 : 0.35

        Rectangle {
            anchors.fill: parent; radius: 5
            color: smMa.containsMouse && parent.btnActive
                ? (parent.dangerColor ? Qt.rgba(0.75, 0.38, 0.41, 0.3) : root.colMuted)
                : "transparent"
            border.color: parent.dangerColor ? root.colRed : root.colMuted
            border.width: 1
            opacity: smMa.containsMouse ? 1.0 : 0.4
            Behavior on color { ColorAnimation { duration: 80 } }
        }
        Text {
            anchors.centerIn: parent
            text:             parent.btnText
            font.pixelSize:   root.fontSize - 3
            font.family:      root.fontFamily
            color: parent.dangerColor ? root.colRed : root.colFg
        }
        MouseArea {
            id:           smMa
            anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            enabled:      parent.btnActive
            onClicked:    parent.clicked()
        }
    }

    component BigBtn: Item {
        property string btnText:   ""
        property bool   btnActive: true
        signal clicked
        // width задаётся снаружи через Layout.fillWidth или Layout.preferredWidth
        height:  28
        opacity: btnActive ? 1.0 : 0.35

        Rectangle {
            anchors.fill: parent; radius: 6
            color: bgMa.containsMouse && parent.btnActive ? root.colMuted : "transparent"
            border.color: root.colMuted; border.width: 1
            opacity: bgMa.containsMouse ? 1.0 : 0.35
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        Text {
            anchors.centerIn: parent
            text:             parent.btnText
            font.pixelSize:   root.fontSize - 3
            font.family:      root.fontFamily
            color:            root.colFg
        }
        MouseArea {
            id:           bgMa
            anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            enabled:      parent.btnActive
            onClicked:    parent.clicked()
        }
    }

    // VolumeRow: id вместо parent-цепочки
    component VolRow: Item {
        id: volRowRoot
        property string icon:      "󰕾"
        property color  iconColor: root.colCyan
        property real   curVal:    1.0
        property real   maxVal:    2.0
        signal moved(real v)
        height: 20

        RowLayout {
            anchors.fill: parent
            spacing: 6

            Text {
                text:           volRowRoot.icon
                font.pixelSize: root.fontSize
                font.family:    root.fontFamily
                color:          volRowRoot.iconColor
            }
            Rectangle {
                Layout.fillWidth: true
                height: 4; radius: 2
                color:  root.colMuted

                Rectangle {
                    width:  parent.width * Math.min(volRowRoot.curVal / volRowRoot.maxVal, 1.0)
                    height: parent.height
                    radius: parent.radius
                    color:  volRowRoot.iconColor
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    function calc(mx) {
                        return Math.round(Math.max(0, Math.min(volRowRoot.maxVal, (mx / width) * volRowRoot.maxVal)) * 10) / 10;
                    }
                    onClicked:         volRowRoot.moved(calc(mouse.x))
                    onPositionChanged: { if (pressed) volRowRoot.moved(calc(mouse.x)); }
                }
            }
            Text {
                text:                volRowRoot.curVal.toFixed(1) + "x"
                font.pixelSize:      root.fontSize - 4
                font.family:         root.fontFamily
                color:               root.colFg
                Layout.minimumWidth: 30
            }
        }
    }
}
