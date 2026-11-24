import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Controls.Material 2.2

import AppModel 1.0
import ComputerManager 1.0
import SdlGamepadKeyNavigation 1.0

CenteredGridView {
    property int computerIndex
    property AppModel appModel : createModel()
    property bool activated
    property bool showHiddenGames
    property bool showGames

    id: appGrid
    focus: true
    activeFocusOnTab: true
    topMargin: 28
    bottomMargin: 24
    cellWidth: 244; cellHeight: 324;

    function computerLost()
    {
        // Go back to the PC view on PC loss
        stackView.pop()
    }

    Component.onCompleted: {
        // Don't show any highlighted item until interacting with them.
        // We do this here instead of onActivated to avoid losing the user's
        // selection when backing out of a different page of the app.
        currentIndex = -1
    }

    StackView.onActivated: {
        appModel.computerLost.connect(computerLost)
        activated = true

        // Highlight the first item if a gamepad is connected
        if (currentIndex === -1 && SdlGamepadKeyNavigation.getConnectedGamepads() > 0) {
            currentIndex = 0
        }

        if (!showGames && !showHiddenGames) {
            // Check if there's a direct launch app
            var directLaunchAppIndex = model.getDirectLaunchAppIndex();
            if (directLaunchAppIndex >= 0) {
                // Start the direct launch app if nothing else is running
                currentIndex = directLaunchAppIndex
                currentItem.launchOrResumeSelectedApp(false)

                // Set showGames so we will not loop when the stream ends
                showGames = true
            }
        }
    }

    StackView.onDeactivating: {
        appModel.computerLost.disconnect(computerLost)
        activated = false
    }

    function createModel()
    {
        var model = Qt.createQmlObject('import AppModel 1.0; AppModel {}', parent, '')
        model.initialize(ComputerManager, computerIndex, showHiddenGames)
        return model
    }

    model: appModel

    delegate: NavigableItemDelegate {
        id: appCardDelegate
        width: 226; height: 306;
        grid: appGrid
        padding: 0

        property alias appContextMenu: appContextMenuLoader.item
        property alias appNameText: appNameTextLoader.item

        // Dim the app if it's hidden
        opacity: model.hidden ? 0.4 : 1.0

        background: Rectangle {
            radius: 16
            color: appCardDelegate.down ? "#EDF2E7" : (appCardDelegate.hovered || appCardDelegate.highlighted ? "#F9FAF3" : "#FFFEF9")
            border.color: (appCardDelegate.hovered || appCardDelegate.highlighted)
                          ? "#28584A"
                          : (model.running ? "#2A6F56" : "#E1E6DC")
            border.width: (appCardDelegate.hovered || appCardDelegate.highlighted || model.running) ? 2 : 1

            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        Rectangle {
            id: artFrame
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            height: 232
            radius: 11
            clip: true
            color: "#EDF2E7"
            border.color: "#E1E6DC"
            border.width: 1

            Image {
                property bool isPlaceholder: false

                id: appIcon
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: model.boxart
                visible: !isPlaceholder

                onSourceSizeChanged: {
                    // Nearly all of Nvidia's official box art does not match the dimensions of placeholder
                    // images, however the one known exception is Overcooked. Therefore, we only execute
                    // the image size checks if this is not an app collector game. We know the officially
                    // supported games all have box art, so this check is not required.
                    if (!model.isAppCollectorGame &&
                        ((sourceSize.width === 130 && sourceSize.height === 180) || // GFE 2.0 placeholder image
                         (sourceSize.width === 628 && sourceSize.height === 888) || // GFE 3.0 placeholder image
                         (sourceSize.width === 200 && sourceSize.height === 266)))  // Our no_app_image.png
                    {
                        isPlaceholder = true
                    }
                    else
                    {
                        isPlaceholder = false
                    }
                }

                // Display a tooltip with the full name if it's truncated
                ToolTip.text: model.name
                ToolTip.delay: 1000
                ToolTip.timeout: 5000
                ToolTip.visible: (appCardDelegate.hovered || appCardDelegate.highlighted) && (!appNameText || appNameText.truncated)
            }

            // Styled NovaLinG Sage artwork when host has no box art
            Rectangle {
                anchors.fill: parent
                visible: appIcon.isPlaceholder
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#28584A" }
                    GradientStop { position: 1.0; color: "#193930" }
                }

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: model.running ? 16 : 44
                    source: "qrc:/res/moonlight.svg"
                    sourceSize.width: 52
                    sourceSize.height: 52
                    opacity: 0.9
                }
            }

            // Running status badge
            Rectangle {
                visible: model.running
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 8
                radius: 10
                height: 22
                width: runningBadgeLabel.implicitWidth + 18
                color: "#28584A"
                border.color: "#BDD0C2"
                border.width: 1
                z: 2

                Label {
                    id: runningBadgeLabel
                    anchors.centerIn: parent
                    text: "● 실행 중"
                    color: "#F2F4DF"
                    font.pointSize: 8.5
                    font.bold: true
                }
            }

            Loader {
                active: model.running
                asynchronous: true
                anchors.fill: parent
                z: 3

                sourceComponent: Item {
                    Rectangle {
                        anchors.fill: parent
                        color: "#5516241E"
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 14

                        RoundButton {
                            // Don't steal focus from the toolbar buttons
                            focusPolicy: Qt.NoFocus

                            implicitWidth: 68
                            implicitHeight: 68

                            icon.source: "qrc:/res/play_arrow_FILL1_wght700_GRAD200_opsz48.svg"
                            icon.width: 40
                            icon.height: 40

                            onClicked: {
                                launchOrResumeSelectedApp(true)
                            }

                            ToolTip.text: qsTr("Resume Game")
                            ToolTip.delay: 1000
                            ToolTip.timeout: 3000
                            ToolTip.visible: hovered

                            Material.background: "#28584A"
                        }

                        RoundButton {
                            // Don't steal focus from the toolbar buttons
                            focusPolicy: Qt.NoFocus

                            implicitWidth: 68
                            implicitHeight: 68

                            icon.source: "qrc:/res/stop_FILL1_wght700_GRAD200_opsz48.svg"
                            icon.width: 36
                            icon.height: 36

                            onClicked: {
                                doQuitGame()
                            }

                            ToolTip.text: qsTr("Quit Game")
                            ToolTip.delay: 1000
                            ToolTip.timeout: 3000
                            ToolTip.visible: hovered

                            Material.background: "#AF5948"
                        }
                    }
                }
            }

            Loader {
                id: appNameTextLoader
                active: appIcon.isPlaceholder

                // This loader is not asynchronous to avoid noticeable differences
                // in the time in which the text loads for each game.

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: model.running ? 92 : 120

                sourceComponent: Label {
                    id: appNameText
                    text: model.name
                    color: "#F2F4DF"
                    font.pointSize: 15
                    font.bold: true
                    leftPadding: 14
                    rightPadding: 14
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                }
            }
        }

        // Bottom Card Footer: Always show clean app title + launch indicator
        Item {
            anchors.top: artFrame.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            Label {
                anchors.left: parent.left
                anchors.right: launchBadge.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: model.name
                color: "#24372F"
                font.pointSize: 11
                font.bold: true
                elide: Text.ElideRight
            }

            Rectangle {
                id: launchBadge
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                radius: 8
                height: 26
                width: launchBadgeLabel.implicitWidth + 16
                color: model.running ? "#E6F3EC" : "#EDF2E7"
                border.color: "#BDD0C2"
                border.width: 1

                Label {
                    id: launchBadgeLabel
                    anchors.centerIn: parent
                    text: model.running ? "이어하기" : "실행 ▶"
                    color: "#28584A"
                    font.pointSize: 9
                    font.bold: true
                }
            }
        }

        function launchOrResumeSelectedApp(quitExistingApp)
        {
            var runningId = appModel.getRunningAppId()
            if (runningId !== 0 && runningId !== model.appid) {
                if (quitExistingApp) {
                    quitAppDialog.appName = appModel.getRunningAppName()
                    quitAppDialog.segueToStream = true
                    quitAppDialog.nextAppName = model.name
                    quitAppDialog.nextAppIndex = index
                    quitAppDialog.open()
                }

                return
            }

            var component = Qt.createComponent("StreamSegue.qml")
            var segue = component.createObject(stackView, {
                                                   "appName": model.name,
                                                   "session": appModel.createSessionForApp(index),
                                                   "isResume": runningId === model.appid
                                               })
            stackView.push(segue)
        }

        onClicked: {
            // Only allow clicking on the box art for non-running games.
            // For running games, buttons will appear to resume or quit which
            // will handle starting the game and clicks on the box art will
            // be ignored.
            if (!model.running) {
                launchOrResumeSelectedApp(true)
            }
        }

        onPressAndHold: {
            // popup() ensures the menu appears under the mouse cursor
            if (appContextMenu.popup) {
                appContextMenu.popup()
            }
            else {
                // Qt 5.9 doesn't have popup()
                appContextMenu.open()
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton;
            onClicked: {
                parent.pressAndHold()
            }
        }

        Keys.onReturnPressed: {
            // Open the app context menu if activated via the gamepad or keyboard
            // for running games. If the game isn't running, the above onClicked
            // method will handle the launch.
            if (model.running) {
                // This will be keyboard/gamepad driven so use
                // open() instead of popup()
                appContextMenu.open()
            }
        }

        Keys.onEnterPressed: {
            // Open the app context menu if activated via the gamepad or keyboard
            // for running games. If the game isn't running, the above onClicked
            // method will handle the launch.
            if (model.running) {
                // This will be keyboard/gamepad driven so use
                // open() instead of popup()
                appContextMenu.open()
            }
        }

        Keys.onMenuPressed: {
            // This will be keyboard/gamepad driven so use open() instead of popup()
            appContextMenu.open()
        }

        function doQuitGame() {
            quitAppDialog.appName = appModel.getRunningAppName()
            quitAppDialog.segueToStream = false
            quitAppDialog.open()
        }

        Loader {
            id: appContextMenuLoader
            asynchronous: true
            sourceComponent: NavigableMenu {
                id: appContextMenu
                initiator: appContextMenuLoader.parent
                NavigableMenuItem {
                    text: model.running ? qsTr("Resume Game") : qsTr("Launch Game")
                    onTriggered: launchOrResumeSelectedApp(true)
                }
                NavigableMenuItem {
                    text: qsTr("Quit Game")
                    onTriggered: doQuitGame()
                    visible: model.running
                }
                NavigableMenuItem {
                    checkable: true
                    checked: model.directLaunch
                    text: qsTr("Direct Launch")
                    onTriggered: appModel.setAppDirectLaunch(model.index, !model.directLaunch)
                    enabled: !model.hidden

                    ToolTip.text: qsTr("Launch this app immediately when the host is selected, bypassing the app selection grid.")
                    ToolTip.delay: 1000
                    ToolTip.timeout: 3000
                    ToolTip.visible: hovered
                }
                NavigableMenuItem {
                    checkable: true
                    checked: model.hidden
                    text: qsTr("Hide Game")
                    onTriggered: appModel.setAppHidden(model.index, !model.hidden)
                    enabled: model.hidden || (!model.running && !model.directLaunch)

                    ToolTip.text: qsTr("Hide this game from the app grid. To access hidden games, right-click on the host and choose %1.").arg(qsTr("View All Apps"))
                    ToolTip.delay: 1000
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        visible: appGrid.count === 0
        width: Math.min(parent.width - 64, emptyAppsLabel.implicitWidth + 56)
        height: emptyAppsLabel.implicitHeight + 44
        radius: 16
        color: "#FFFEF9"
        border.color: "#E1E6DC"
        border.width: 1

        Label {
            id: emptyAppsLabel
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 36)
            color: "#5F7065"
            text: qsTr("This computer doesn't seem to have any applications or some applications are hidden")
            font.pointSize: 13
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
        }
    }

    NavigableMessageDialog {
        id: quitAppDialog
        property string appName : ""
        property bool segueToStream : false
        property string nextAppName: ""
        property int nextAppIndex: 0
        text:qsTr("Are you sure you want to quit %1? Any unsaved progress will be lost.").arg(appName)
        standardButtons: Dialog.Yes | Dialog.No

        function quitApp() {
            var component = Qt.createComponent("QuitSegue.qml")
            var params = {"appName": appName, "quitRunningAppFn": function() { appModel.quitRunningApp() }}
            if (segueToStream) {
                // Store the session and app name if we're going to stream after
                // successfully quitting the old app.
                params.nextAppName = nextAppName
                params.nextSession = appModel.createSessionForApp(nextAppIndex)
            }
            else {
                params.nextAppName = null
                params.nextSession = null
            }

            stackView.push(component.createObject(stackView, params))
        }

        onAccepted: quitApp()
    }

    ScrollBar.vertical: ScrollBar {}
}
