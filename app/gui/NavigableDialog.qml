import QtQuick 2.9
import QtQuick.Controls 2.5
import QtQuick.Controls.Material 2.2

Dialog {
    modal: true
    anchors.centerIn: Overlay.overlay
    padding: 20

    Material.theme: Material.Light
    Material.accent: "#28584A"
    Material.foreground: "#24372F"

    background: Rectangle {
        color: "#FFFEF9"
        radius: 16
        border.color: "#CDD6C7"
        border.width: 1
    }

    onClosed: {
        // We must force focus back to the last item. If we don't,
        // gamepad and keyboard navigation will break after a
        // dialog appears.
        stackView.forceActiveFocus()
    }
}
