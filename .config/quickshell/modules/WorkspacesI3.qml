import Quickshell
import Quickshell.I3
import QtQuick
import QtQuick.Layouts

Item {
    id: i3Root

    property string fontFamily:  "Monaspace Krypton Medium"
    property int    fontSize:    16
    property color  colActive:   "#81a1c1"
    property color  colOccupied: "#d8dee9"
    property color  colEmpty:    "#4c566a"
    property color  colBar:      "#5e81ac"
    property color  colBg:       "#2e3440"

    implicitWidth:  wsRow.implicitWidth
    implicitHeight: wsRow.implicitHeight

    Layout.fillHeight:     true
    Layout.fillWidth:      false
    Layout.preferredWidth: implicitWidth
    Layout.alignment:      Qt.AlignVCenter

    RowLayout {
        id: wsRow
        anchors.fill: parent
        spacing: 2

        Repeater {
            model: I3.workspaces

            Rectangle {
                required property I3Workspace modelData

                readonly property bool isActive:  modelData.focused
                readonly property bool isVisible: modelData.visible
                readonly property bool isUrgent:  modelData.urgent

                Layout.preferredWidth: 30
                Layout.fillHeight:     true
                color: "transparent"

                Text {
                    text:           modelData.num
                    color:          isActive  ? colActive
                                  : isUrgent  ? "#bf616a"
                                  : isVisible ? colOccupied
                                  :             colEmpty
                    font.pixelSize: fontSize
                    font.family:    fontFamily
                    font.bold:      true
                    anchors.centerIn: parent
                }

                Rectangle {
                    width:  20
                    height: 3
                    color:  isActive ? colBar : colBg
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom:           parent.bottom
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked:    I3.dispatch("workspace number " + modelData.num)
                }
            }
        }
    }
}
