import Quickshell
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
        color: "#141c26"
        Grid {
            columns: 3
            spacing: 3
            Rectangle {
                width: 100
                height: 100
                anchors.left: controlMenu.right
                anchors.margins: 2
                clip: true

                Image {
                    id: avatar
                    anchors.fill: parent
                    source: "file:///home/thedocingeast/.face"
                }
            }

            Rectangle {
                color: "blue"
                width: 100
                height: 100
            }
            Rectangle {
                color: "cyan"
                width: 100
                height: 100
            }
            Rectangle {
                color: "magenta"
                width: 100
                height: 100
            }
        }
    }
}
