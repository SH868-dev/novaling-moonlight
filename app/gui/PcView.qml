import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

import ComputerModel 1.0

import ComputerManager 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0

CenteredGridView {
    property ComputerModel computerModel : createModel()

    id: pcGrid
    focus: true
    activeFocusOnTab: true
    topMargin: 28
    bottomMargin: 24
    cellWidth: 336; cellHeight: 244;
    objectName: qsTr("Computers")

    Component.onCompleted: {
        // Don't show any highlighted item until interacting with them.
        // We do this here instead of onActivated to avoid losing the user's
        // selection when backing out of a different page of the app.
        currentIndex = -1
    }

    // Note: Any initialization done here that is critical for streaming must
    // also be done in CliStartStreamSegue.qml, since this code does not run
    // for command-line initiated streams.
    StackView.onActivated: {
        // Setup signals on CM
        ComputerManager.computerAddCompleted.connect(addComplete)

        // Highlight the first item if a gamepad is connected
        if (currentIndex === -1 && SdlGamepadKeyNavigation.getConnectedGamepads() > 0) {
            currentIndex = 0
        }
    }

    StackView.onDeactivating: {
        ComputerManager.computerAddCompleted.disconnect(addComplete)
    }

    function pairingComplete(error)
    {
        // Close the PIN dialog
        pairDialog.close()

        // Display a failed dialog if we got an error
        if (error !== undefined) {
            errorDialog.text = error
            errorDialog.helpText = ""
            errorDialog.open()
        }
    }

    function addComplete(success, detectedPortBlocking)
    {
        if (!success) {
            errorDialog.text = qsTr("Unable to connect to the specified PC.")

            if (detectedPortBlocking) {
                errorDialog.text += "\n\n" + qsTr("This PC's Internet connection is blocking Moonlight. Streaming over the Internet may not work while connected to this network.")
            }
            else {
                errorDialog.helpText = qsTr("Click the Help button for possible solutions.")
            }

            errorDialog.open()
        }
    }

    function createModel()
    {
        var model = Qt.createQmlObject('import ComputerModel 1.0; ComputerModel {}', parent, '')
        model.initialize(ComputerManager)
        model.pairingCompleted.connect(pairingComplete)
        model.connectionTestCompleted.connect(testConnectionDialog.connectionTestComplete)
        return model
    }

    Rectangle {
        anchors.centerIn: parent
        visible: pcGrid.count === 0
        width: Math.min(parent.width - 64, emptyStateRow.implicitWidth + 56)
        height: emptyStateRow.implicitHeight + 48
        radius: 16
        color: "#FFFEF9"
        border.color: "#E1E6DC"
        border.width: 1

        Row {
            id: emptyStateRow
            anchors.centerIn: parent
            spacing: 14

            BusyIndicator {
                id: searchSpinner
                visible: StreamingPreferences.enableMdns
                running: visible
                width: 34
                height: 34
                anchors.verticalCenter: parent.verticalCenter
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                elide: Label.ElideRight
                color: "#24372F"
                text: StreamingPreferences.enableMdns ? qsTr("Searching for compatible hosts on your local network...")
                                                      : qsTr("Automatic PC discovery is disabled. Add your PC manually.")
                font.pointSize: 13
                font.bold: true
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
            }
        }
    }

    model: computerModel

    delegate: NavigableItemDelegate {
        id: pcCardDelegate
        width: 316; height: 224;
        grid: pcGrid
        padding: 0

        property alias pcContextMenu : pcContextMenuLoader.item

        background: Rectangle {
            radius: 16
            color: pcCardDelegate.down ? "#EDF2E7" : (pcCardDelegate.hovered || pcCardDelegate.highlighted ? "#F9FAF3" : "#FFFEF9")
            border.color: (pcCardDelegate.hovered || pcCardDelegate.highlighted)
                          ? "#28584A"
                          : (model.online ? "#BDD0C2" : "#E1E6DC")
            border.width: (pcCardDelegate.hovered || pcCardDelegate.highlighted) ? 2 : 1
            opacity: model.online || model.statusUnknown ? 1.0 : 0.82

            Behavior on border.color { ColorAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // Top Row: Icon Badge + Semantic Status Pill
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    id: pcIconBadge
                    width: 48
                    height: 48
                    radius: 12
                    color: model.online ? "#EDF2E7" : "#F0F1EB"
                    border.color: model.online ? "#BDD0C2" : "#E1E6DC"
                    border.width: 1

                    Image {
                        id: pcIcon
                        anchors.centerIn: parent
                        visible: !model.statusUnknown
                        source: "qrc:/res/desktop_windows-48px.svg"
                        sourceSize.width: 26
                        sourceSize.height: 26
                        opacity: model.online ? 1.0 : 0.45
                    }

                    BusyIndicator {
                        id: statusUnknownSpinner
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        visible: model.statusUnknown
                        running: visible
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    id: statusPill
                    radius: 13
                    height: 26
                    Layout.preferredWidth: statusRow.implicitWidth + 20
                    color: model.statusUnknown
                           ? "#EDF2E7"
                           : (!model.online
                              ? "#EFEFE8"
                              : (!model.paired
                                 ? "#FEF3C7"
                                 : (model.busy ? "#EDF2E7" : "#E6F3EC")))
                    border.color: model.statusUnknown
                                  ? "#BDD0C2"
                                  : (!model.online
                                     ? "#DCE1D7"
                                     : (!model.paired
                                        ? "#F59E0B"
                                        : "#BDD0C2"))
                    border.width: 1

                    Row {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 7
                            height: 7
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !model.statusUnknown && (model.paired || !model.online)
                            color: !model.online ? "#8A978B" : (model.busy ? "#28584A" : "#2A6F56")
                        }

                        Image {
                            id: stateIcon
                            width: 13
                            height: 13
                            sourceSize.width: 13
                            sourceSize.height: 13
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !model.statusUnknown && model.online && !model.paired
                            source: "qrc:/res/baseline-lock-24px.svg"
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pointSize: 9.5
                            font.bold: true
                            color: model.statusUnknown
                                   ? "#5F7065"
                                   : (!model.online
                                      ? "#8A978B"
                                      : (!model.paired
                                         ? "#92400E"
                                         : (model.busy ? "#28584A" : "#2A6F56")))
                            text: model.statusUnknown
                                  ? "..."
                                  : (!model.online
                                     ? qsTr("Offline")
                                     : (!model.paired
                                        ? qsTr("Unpaired")
                                        : (model.busy ? "Streaming" : qsTr("Online"))))
                        }
                    }
                }
            }

            // Middle: Host Name & Contextual Hint
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Label {
                    id: pcNameText
                    text: model.name
                    Layout.fillWidth: true
                    color: "#24372F"
                    font.pointSize: 16
                    font.bold: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Label {
                    Layout.fillWidth: true
                    color: "#5F7065"
                    font.pointSize: 9.5
                    elide: Text.ElideRight
                    text: model.statusUnknown
                          ? "호스트 상태를 확인하는 중입니다..."
                          : (!model.online
                             ? (model.wakeable ? "오프라인 · 우클릭으로 원격 켜기(WoL) 가능" : "오프라인 · 우클릭으로 옵션 확인")
                             : (!model.paired
                                ? "클릭하여 4자리 PIN으로 기기 연결"
                                : (model.busy ? "원격 세션 실행 중 · 클릭하여 이어하기" : "연결 준비 완료 · 클릭하여 앱 런처 열기")))
                }
            }

            // Bottom Action Bar
            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 10
                color: (model.online && model.paired)
                       ? (pcCardDelegate.hovered || pcCardDelegate.highlighted ? "#1F473B" : "#28584A")
                       : (model.online ? "#EDF2E7" : "#F3F4EE")
                border.color: (model.online && model.paired)
                              ? "#28584A"
                              : (model.online ? "#BDD0C2" : "#E1E6DC")
                border.width: 1

                Label {
                    anchors.centerIn: parent
                    font.pointSize: 10.5
                    font.bold: true
                    color: (model.online && model.paired)
                           ? "#F2F4DF"
                           : (model.online ? "#28584A" : "#5F7065")
                    text: model.statusUnknown
                          ? "확인 중..."
                          : (!model.online
                             ? (model.wakeable ? "원격 켜기 (WoL) / 메뉴" : "옵션 보기")
                             : (!model.paired
                                ? "PIN 페어링 시작"
                                : (model.busy ? "세션 열기 →" : "접속하기 →")))
                }
            }
        }

        // Display a tooltip with the full name if it's truncated
        ToolTip.text: model.name
        ToolTip.delay: 1000
        ToolTip.timeout: 5000
        ToolTip.visible: (hovered || highlighted) && pcNameText.truncated

        Loader {
            id: pcContextMenuLoader
            asynchronous: true
            sourceComponent: NavigableMenu {
                id: pcContextMenu
                initiator: pcContextMenuLoader.parent
                MenuItem {
                    text: qsTr("PC Status: %1").arg(model.online ? qsTr("Online") : qsTr("Offline"))
                    font.bold: true
                    enabled: false
                }
                NavigableMenuItem {
                    text: qsTr("View All Apps")
                    onTriggered: {
                        var component = Qt.createComponent("AppView.qml")
                        var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name, "showHiddenGames": true})
                        stackView.push(appView)
                    }
                    visible: model.online && model.paired
                }
                NavigableMenuItem {
                    text: qsTr("Wake PC")
                    onTriggered: computerModel.wakeComputer(index)
                    visible: !model.online && model.wakeable
                }
                NavigableMenuItem {
                    text: qsTr("Test Network")
                    onTriggered: {
                        computerModel.testConnectionForComputer(index)
                        testConnectionDialog.open()
                    }
                }

                NavigableMenuItem {
                    text: qsTr("Rename PC")
                    onTriggered: {
                        renamePcDialog.pcIndex = index
                        renamePcDialog.originalName = model.name
                        renamePcDialog.open()
                    }
                }
                NavigableMenuItem {
                    text: qsTr("Delete PC")
                    onTriggered: {
                        deletePcDialog.pcIndex = index
                        deletePcDialog.pcName = model.name
                        deletePcDialog.open()
                    }
                }
                NavigableMenuItem {
                    text: qsTr("View Details")
                    onTriggered: {
                        showPcDetailsDialog.pcDetails = model.details
                        showPcDetailsDialog.open()
                    }
                }
            }
        }

        onClicked: {
            if (model.online) {
                if (!model.serverSupported) {
                    errorDialog.text = qsTr("The version of GeForce Experience on %1 is not supported by this build of Moonlight. You must update Moonlight to stream from %1.").arg(model.name)
                    errorDialog.helpText = ""
                    errorDialog.open()
                }
                else if (model.paired) {
                    // go to game view
                    var component = Qt.createComponent("AppView.qml")
                    var appView = component.createObject(stackView, {"computerIndex": index, "objectName": model.name})
                    stackView.push(appView)
                }
                else {
                    var pin = computerModel.generatePinString()

                    // Kick off pairing in the background
                    computerModel.pairComputer(index, pin)

                    // Display the pairing dialog
                    pairDialog.pin = pin
                    pairDialog.open()
                }
            } else if (!model.online) {
                // Using open() here because it may be activated by keyboard
                pcContextMenu.open()
            }
        }

        onPressAndHold: {
            // popup() ensures the menu appears under the mouse cursor
            if (pcContextMenu.popup) {
                pcContextMenu.popup()
            }
            else {
                // Qt 5.9 doesn't have popup()
                pcContextMenu.open()
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton;
            onClicked: {
                parent.pressAndHold()
            }
        }

        Keys.onMenuPressed: {
            // We must use open() here so the menu is positioned on
            // the ItemDelegate and not where the mouse cursor is
            pcContextMenu.open()
        }

        Keys.onDeletePressed: {
            deletePcDialog.pcIndex = index
            deletePcDialog.pcName = model.name
            deletePcDialog.open()
        }
    }

    ErrorMessageDialog {
        id: errorDialog

        // Using Setup-Guide here instead of Troubleshooting because it's likely that users
        // will arrive here by forgetting to enable GameStream or not forwarding ports.
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide"
    }

    NavigableDialog {
        id: pairDialog
        closePolicy: Popup.CloseOnEscape

        // don't allow edits to the rest of the window while open
        property string pin : "0000"
        standardButtons: Dialog.Cancel
        onRejected: {
            // FIXME: We should interrupt pairing here
        }

        ColumnLayout {
            spacing: 14
            Layout.minimumWidth: 360

            Label {
                text: "PIN 페어링"
                color: "#28584A"
                font.pointSize: 13
                font.bold: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                Repeater {
                    model: 4
                    Rectangle {
                        width: 56
                        height: 64
                        radius: 12
                        color: "#EDF2E7"
                        border.color: "#BDD0C2"
                        border.width: 1.5

                        Label {
                            anchors.centerIn: parent
                            text: pairDialog.pin.length > index ? pairDialog.pin.charAt(index) : "•"
                            color: "#28584A"
                            font.pointSize: 22
                            font.bold: true
                        }
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: 380
                color: "#24372F"
                wrapMode: Text.Wrap
                text: qsTr("Please enter %1 on your host PC. This dialog will close when pairing is completed.").arg(pairDialog.pin)
            }

            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: 380
                color: "#5F7065"
                font.pointSize: 9.5
                wrapMode: Text.Wrap
                text: "호스트 PC의 NovaLinG [원격 접속] 탭 또는 웹 콘솔에서 위 4자리 숫자를 입력해 승인하세요."
            }
        }
    }

    NavigableMessageDialog {
        id: deletePcDialog
        // don't allow edits to the rest of the window while open
        property int pcIndex : -1
        property string pcName : ""
        text: qsTr("Are you sure you want to remove '%1'?").arg(pcName)
        standardButtons: Dialog.Yes | Dialog.No

        onAccepted: {
            computerModel.deleteComputer(pcIndex)
        }
    }

    NavigableMessageDialog {
        id: testConnectionDialog
        closePolicy: Popup.CloseOnEscape
        standardButtons: Dialog.Ok

        onAboutToShow: {
            testConnectionDialog.text = qsTr("Moonlight is testing your network connection to determine if any required ports are blocked.") + "\n\n" + qsTr("This may take a few seconds…")
            showSpinner = true
        }

        function connectionTestComplete(result, blockedPorts)
        {
            if (result === -1) {
                text = qsTr("The network test could not be performed because none of Moonlight's connection testing servers were reachable from this PC. Check your Internet connection or try again later.")
                imageSrc = "qrc:/res/baseline-warning-24px.svg"
            }
            else if (result === 0) {
                text = qsTr("This network does not appear to be blocking Moonlight. If you still have trouble connecting, check your PC's firewall settings.") + "\n\n" + qsTr("If you are trying to stream over the Internet, install the Moonlight Internet Hosting Tool on your gaming PC and run the included Internet Streaming Tester to check your gaming PC's Internet connection.")
                imageSrc = "qrc:/res/baseline-check_circle_outline-24px.svg"
            }
            else {
                text = qsTr("Your PC's current network connection seems to be blocking Moonlight. Streaming over the Internet may not work while connected to this network.") + "\n\n" + qsTr("The following network ports were blocked:") + "\n"
                text += blockedPorts
                imageSrc = "qrc:/res/baseline-error_outline-24px.svg"
            }

            // Stop showing the spinner and show the image instead
            showSpinner = false
        }
    }

    NavigableDialog {
        id: renamePcDialog
        property string label: qsTr("Enter the new name for this PC:")
        property string originalName
        property int pcIndex : -1;

        standardButtons: Dialog.Ok | Dialog.Cancel

        onOpened: {
            // Force keyboard focus on the textbox so keyboard navigation works
            editText.forceActiveFocus()
        }

        onClosed: {
            editText.clear()
        }

        onAccepted: {
            if (editText.text) {
                computerModel.renameComputer(pcIndex, editText.text)
            }
        }

        ColumnLayout {
            Label {
                text: renamePcDialog.label
                font.bold: true
            }

            TextField {
                id: editText
                placeholderText: renamePcDialog.originalName
                Layout.fillWidth: true
                focus: true

                Keys.onReturnPressed: {
                    renamePcDialog.accept()
                }

                Keys.onEnterPressed: {
                    renamePcDialog.accept()
                }
            }
        }
    }

    NavigableMessageDialog {
        id: showPcDetailsDialog
        property string pcDetails : "";
        text: showPcDetailsDialog.pcDetails
        imageSrc: "qrc:/res/baseline-help_outline-24px.svg"
        standardButtons: Dialog.Ok
    }

    ScrollBar.vertical: ScrollBar {}
}
