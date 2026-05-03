// modules/SoundModule.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io

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

    property int volLevel: 50
    signal volChanged(int newLevel)

    property bool barHovered:   false
    property bool panelHovered: false

    onBarHoveredChanged:   _checkHide()
    onPanelHoveredChanged: _checkHide()

    function _checkHide() {
        if (!barHovered && !panelHovered) hideTimer.restart();
        else                              hideTimer.stop();
    }

    Timer {
        id: hideTimer
        interval: 150
        onTriggered: root.visible = false
    }

    readonly property var spotify: {
        var players = Mpris.players.values;
        for (var i = 0; i < players.length; i++) {
            var p = players[i];
            var dbus  = (p.dbusName     || "").toLowerCase();
            var ident = (p.identity     || "").toLowerCase();
            var de    = (p.desktopEntry || "").toLowerCase();
            if (dbus.includes("spotify") || ident.includes("spotify") || de.includes("spotify"))
                return p;
        }
        return null;
    }

    readonly property bool hasPlayer: spotify !== null
    readonly property bool playing:   hasPlayer && spotify.playbackState === MprisPlaybackState.Playing

    width:   320
    height:  card.implicitHeight
    color:   "transparent"
    visible: false

    onVisibleChanged: {
        if (visible) {
            card.scale   = 0.94;
            card.opacity = 0;
            anim.restart();
        }
    }
    ParallelAnimation {
        id: anim
                NumberAnimation {
            target: card
            property: "scale"
            to: 1.0
            duration: 160
            easing.type: Easing.OutCubic
        }
                NumberAnimation {
            target: card
            property: "opacity"
            to: 1.0
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        interval: 1000
        running:  root.visible && root.playing
        repeat:   true
        onTriggered: { if (root.spotify) root.spotify.positionChanged(); }
    }

    Rectangle {
        id: card
        anchors.fill:    parent
        implicitHeight:  panelCol.implicitHeight + 24
        color:           root.colBg
        border.color:    root.colBlue
        border.width:    2
        radius:          10
        transformOrigin: Item.TopRight

        MouseArea {
            anchors.fill:            parent
            hoverEnabled:            true
            acceptedButtons:         Qt.NoButton
            propagateComposedEvents: true
            z: 999
                        onEntered: {
                root.panelHovered = true
                root._checkHide()
            }
                        onExited:  {
                root.panelHovered = false
                root._checkHide()
            }
        }

        ColumnLayout {
            id: panelCol
            anchors.left:    parent.left
            anchors.right:   parent.right
            anchors.top:     parent.top
            anchors.margins: 14
            spacing: 10

            // ── Громкость ─────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: root.volLevel === 0 ? "󰝟" : root.volLevel < 50 ? "󰖀" : "󰕾"
                    font.pixelSize: root.fontSize + 2
                    font.family:    root.fontFamily
                    color: root.volLevel > 90 ? root.colRed : root.volLevel > 50 ? root.colYellow : root.colCyan
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color:  root.colMuted
                    Rectangle {
                        width:  parent.width * (root.volLevel / 100)
                        height: parent.height
                        radius: parent.radius
                        color:  root.volLevel > 90 ? root.colRed : root.volLevel > 50 ? root.colYellow : root.colCyan
                        Behavior on width { NumberAnimation { duration: 80 } }
                    }
                    MouseArea {
                        anchors.fill:  parent
                        cursorShape:   Qt.PointingHandCursor
                        onClicked: {
                            root.volChanged(Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100))));
                        }
                        onPositionChanged: {
                            if (pressed)
                                root.volChanged(Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100))));
                        }
                    }
                }
                Text {
                    text:           root.volLevel + "%"
                    font.pixelSize: root.fontSize - 2
                    font.family:    root.fontFamily
                    color:          root.colFg
                    Layout.minimumWidth: 36
                }
            }

                        Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.colMuted
                opacity: 0.35
            }

            // ── Spotify ───────────────────────────────────────────────────
            Text {
                visible:            !root.hasPlayer
                Layout.alignment:   Qt.AlignHCenter
                Layout.bottomMargin: 4
                text:           "󰓇  Spotify not running"
                font.pixelSize: root.fontSize - 1
                font.family:    root.fontFamily
                color:          root.colMuted
            }

            RowLayout {
                visible:          root.hasPlayer
                Layout.fillWidth: true
                spacing:          12

                Rectangle {
                    width: 64
                    height: 64
                    radius: 10
                    color: root.colMuted
                    clip: true
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        clip: true
                        color: "transparent"
                        Image {
                            id:           coverImg
                            anchors.fill: parent
                            source:       root.hasPlayer ? (root.spotify.trackArtUrl || "") : ""
                            fillMode:     Image.PreserveAspectCrop
                            visible:      status === Image.Ready
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible:          coverImg.status !== Image.Ready
                        text:             "󰓇"
                        font.pixelSize:   30
                        font.family:      root.fontFamily
                        color:            root.colFg
                    }
                    Rectangle {
                        visible: root.playing
                        anchors.bottom:   parent.bottom
                        anchors.right:    parent.right
                        anchors.margins:  4
                        width: 8
                        height: 8
                        radius: 4
                        color: root.colGreen
                        SequentialAnimation on opacity {
                            running: root.playing
                            loops: Animation.Infinite
                                                        NumberAnimation {
                                to: 0.2
                                duration: 800
                                easing.type: Easing.InOutSine
                            }
                                                        NumberAnimation {
                                to: 1.0
                                duration: 800
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text:           root.hasPlayer ? (root.spotify.trackTitle || "Unknown Track") : ""
                        font.pixelSize: root.fontSize
                        font.family:    root.fontFamily
                        font.bold:      true
                        color:          root.colFg
                        elide:          Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text:           root.hasPlayer ? (root.spotify.trackArtist || "Unknown Artist") : ""
                        font.pixelSize: root.fontSize - 3
                        font.family:    root.fontFamily
                        color:          root.colCyan
                        elide:          Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text:           root.hasPlayer ? (root.spotify.trackAlbum || "") : ""
                        font.pixelSize: root.fontSize - 4
                        font.family:    root.fontFamily
                        color:          root.colMuted
                        elide:          Text.ElideRight
                    }
                    RowLayout {
                        spacing: 6
                        visible: root.hasPlayer
                        Text {
                            visible:        root.hasPlayer && root.spotify.shuffleSupported
                            text:           "󰒝"
                            font.pixelSize: root.fontSize - 2
                            font.family:    root.fontFamily
                            color: root.spotify && root.spotify.shuffle ? root.colGreen : root.colMuted
                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: { if (root.spotify) root.spotify.shuffle = !root.spotify.shuffle; }
                            }
                        }
                        Text {
                            visible: root.hasPlayer && root.spotify.loopSupported
                            text: {
                                if (!root.spotify) return "󰑗";
                                var s = root.spotify.loopState;
                                if (s === MprisLoopState.Track)    return "󰑘";
                                if (s === MprisLoopState.Playlist)  return "󰑖";
                                return "󰑗";
                            }
                            font.pixelSize: root.fontSize - 2
                            font.family:    root.fontFamily
                            color: root.spotify && root.spotify.loopState !== MprisLoopState.None
                                ? root.colGreen : root.colMuted
                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    if (!root.spotify) return;
                                    var s = root.spotify.loopState;
                                    if (s === MprisLoopState.None)          root.spotify.loopState = MprisLoopState.Playlist;
                                    else if (s === MprisLoopState.Playlist) root.spotify.loopState = MprisLoopState.Track;
                                    else                                     root.spotify.loopState = MprisLoopState.None;
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id:               progressBar
                visible:          root.hasPlayer
                Layout.fillWidth: true
                height: 4
                radius: 2
                color:  root.colMuted
                readonly property real ratio: (root.hasPlayer && root.spotify && root.spotify.lengthSupported && root.spotify.length > 0)
                    ? Math.min(root.spotify.position / root.spotify.length, 1.0) : 0.0
                Rectangle {
                    width:  progressBar.ratio * parent.width
                    height: parent.height
                    radius: parent.radius
                    color:  root.colCyan
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.Linear } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        if (root.hasPlayer && root.spotify.positionSupported && root.spotify.canSeek)
                            root.spotify.position = (mouse.x / width) * root.spotify.length;
                    }
                }
            }

            RowLayout {
                visible:          root.hasPlayer && root.spotify.lengthSupported
                Layout.fillWidth: true
                Layout.topMargin: -6
                Text {
                    id:             posText
                    text:           root.hasPlayer ? formatTime(root.spotify.position) : "0:00"
                    font.pixelSize: root.fontSize - 5
                    font.family:    root.fontFamily
                    color:          root.colFg
                    Connections {
                        target: root.spotify
                        function onPositionChanged() {
                            posText.text = root.hasPlayer ? formatTime(root.spotify.position) : "0:00";
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text:           root.hasPlayer ? formatTime(root.spotify.length) : "0:00"
                    font.pixelSize: root.fontSize - 5
                    font.family:    root.fontFamily
                    color:          root.colFg
                }
            }

            RowLayout {
                visible:          root.hasPlayer
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                CtrlBtn {
                    btnText:   "󰒮"
                    btnActive: root.hasPlayer && root.spotify.canGoPrevious
                    onClicked: { if (root.spotify) root.spotify.previous(); }
                }
                CtrlBtn {
                    btnText:   root.playing ? "󰏤" : "󰐊"
                    btnSize:   root.fontSize + 8
                    btnW:      44
                    btnH: 44
                    btnRadius: 22
                    btnActive: root.hasPlayer && root.spotify.canTogglePlaying
                    onClicked: { if (root.spotify) root.spotify.togglePlaying(); }
                }
                CtrlBtn {
                    btnText:   "󰒭"
                    btnActive: root.hasPlayer && root.spotify.canGoNext
                    onClicked: { if (root.spotify) root.spotify.next(); }
                }
            }

            Item { height: 0 }
        }
    }

    component CtrlBtn: Item {
        property string btnText:   ""
        property int    btnSize:   root.fontSize + 4
        property int    btnW:      36
        property int    btnH:      36
        property int    btnRadius: 8
        property bool   btnActive: true
        signal clicked

        width:   btnW < 0 ? parent.width : btnW
        height:  btnH
        opacity: btnActive ? 1.0 : 0.35

        Rectangle {
            anchors.fill:  parent
            radius:        parent.btnRadius
            color:         ma.containsMouse && parent.btnActive ? root.colMuted : "transparent"
            border.color:  root.colMuted
            border.width:  1
            opacity:       ma.containsMouse ? 1.0 : 0.3
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        Text {
            anchors.centerIn: parent
            text:             parent.btnText
            font.pixelSize:   parent.btnSize
            font.family:      root.fontFamily
            color:            root.colFg
        }
        MouseArea {
            id:           ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            enabled:      parent.btnActive
            onClicked:    parent.clicked()
        }
    }

    function formatTime(sec) {
        var s = Math.floor(sec);
        var m = Math.floor(s / 60);
        s = s % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
}
