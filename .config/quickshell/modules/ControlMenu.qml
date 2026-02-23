import Quickshell
import Quickshell.Wayland
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick

PanelWindow {
    id: controlMenu

    property var screen  // передаём снаружи

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

        ColumnLayout {
            spacing: 2
            anchors.fill: parent

            Rectangle {
                Layout.margins: 10
                Layout.preferredHeight: parent.height - 20
                Layout.preferredWidth: parent.width - 20
                border.color: colBlue
                border.width: 4
                color: "transparent"
                radius: 6
            }
        }
    }
}
