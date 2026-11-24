import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

ToolButton {
    id: control
    property string iconSource

    activeFocusOnTab: true

    icon.source: iconSource
    // Size the icon from the button's height rather than its background.
    // Material's background spans the full button width when the content
    // isn't square, so binding the icon to it feeds the button's width back
    // into its own implicit width and the toolbar layout grows without bound.
    icon.width: height / 2.2
    icon.height: height / 2.2

    Layout.preferredHeight: 44
    Layout.preferredWidth: 44
    Layout.alignment: Qt.AlignVCenter

    background: Rectangle {
        radius: 10
        color: control.down ? "#33F2F4DF" : (control.hovered || control.activeFocus ? "#22F2F4DF" : "transparent")
        border.color: control.activeFocus ? "#BDD0C2" : "transparent"
        border.width: 1
    }

    Keys.onReturnPressed: {
        clicked()
    }

    Keys.onEnterPressed: {
        clicked()
    }

    Keys.onRightPressed: {
        nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocus)
    }

    Keys.onLeftPressed: {
        nextItemInFocusChain(false).forceActiveFocus(Qt.TabFocus)
    }
}
