pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: wmDetector

    property string name: "unknown"
    readonly property bool isHyprland: name === "hyprland"
    readonly property bool isI3: name === "i3"

    property var _proc: Process {
        command: ["sh", "-c", "echo ${XDG_CURRENT_DESKTOP:-}:${DESKTOP_SESSION:-}"]
        stdout: SplitParser {
            onRead: data => {
                var s = data.trim().toLowerCase();
                if (s.indexOf("hyprland") !== -1)
                    wmDetector.name = "hyprland";
                else if (s.indexOf("i3") !== -1)
                    wmDetector.name = "i3";
            }
        }
        Component.onCompleted: running = true
    }
}
