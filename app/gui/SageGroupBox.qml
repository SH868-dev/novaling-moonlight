import QtQuick 2.9
import QtQuick.Controls 2.2

GroupBox {
    id: root
    topPadding: 44
    leftPadding: 18
    rightPadding: 18
    bottomPadding: 16
    font.pointSize: 12

    background: Rectangle {
        color: "#FFFEF9"
        radius: 14
        border.color: "#E1E6DC"
        border.width: 1

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            y: 36
            height: 1
            color: "#EDF2E7"
        }
    }

    label: Label {
        x: 18
        y: 11
        width: root.availableWidth
        text: root.title
        color: "#28584A"
        font.pointSize: 12
        font.bold: true
        elide: Text.ElideRight
    }
}
