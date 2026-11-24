import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2

Menu {
    property var initiator

    Material.theme: Material.Light
    Material.accent: "#28584A"
    Material.foreground: "#24372F"

    background: Rectangle {
        implicitWidth: 210
        color: "#FFFEF9"
        radius: 12
        border.color: "#CDD6C7"
        border.width: 1
    }

    onOpened: {
        // If the initiating object currently has keyboard focus,
        // give focus to the first visible and enabled menu item
        if (initiator.focus) {
            for (var i = 0; i < count; i++) {
                var item = itemAt(i)
                if (item.visible && item.enabled) {
                    item.forceActiveFocus(Qt.TabFocusReason)
                    break
                }
            }
        }
    }
}
