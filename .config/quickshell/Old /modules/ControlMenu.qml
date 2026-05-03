import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "./modules"

PanelWindow {
    id: controlMenu

    property var screen

    anchors {
        left: true
        top: true
        bottom: true
    }
    implicitWidth: 300
    visible: false

    Rectangle {
        anchors.fill: parent
        color: colBg

        // Scrollable content for when more modules are added
        ScrollView {
            anchors.fill: parent
            anchors.margins: 10
            contentWidth: availableWidth
            clip: true

            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.width
                spacing: 8

                // ── Border card wrapper ───────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: btModule.implicitHeight
                    border.color: colBlue
                    border.width: 2
                    color: "transparent"
                    radius: 8

                    BluetoothModule {
                        id: btModule
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        // Pass theme from shell root
                        fontFamily: root.fontFamily
                        fontSize: root.fontSize
                        colBg: root.colBg
                        colFg: root.colFg
                        colMuted: root.colMuted
                        colCyan: root.colCyan
                        colBlue: root.colBlue
                        colLBlue: root.colLightBlue
                        colGreen: root.colGreen
                        colRed: root.colRed
                        colYellow: root.colYellow
                    }
                }

                // ── More modules here in the future ───────────────────────
            }
        }
    }
}
