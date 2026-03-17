import QtQuick
import QtQuick.Layouts
import FluentUI

FluFrame {
    id: control

    property bool runPaused: true
    property real mountedProgress: 0

    signal importClicked()
    signal clearAllClicked()
    signal deleteSelectionClicked()
    signal addRowClicked()
    signal insertRowClicked()
    signal runToggleClicked()
    signal stopClicked()
    signal stepClicked()

    anchors {
        left: parent.left
        right: parent.right
        top: parent.top
    }
    height: 60

    Row {
        spacing: 5
        anchors {
            left: parent.left
            leftMargin: 10
            verticalCenter: parent.verticalCenter
        }
        FluButton {
            text: qsTr("导入文件")
            onClicked: control.importClicked()
        }
        FluButton {
            text: qsTr("Clear All")
            onClicked: control.clearAllClicked()
        }

        FluButton {
            text: qsTr("Delete Selection")
            onClicked: control.deleteSelectionClicked()
        }
        FluButton {
            text: qsTr("Add a row of Data")
            onClicked: control.addRowClicked()
        }
        FluButton {
            text: qsTr("Insert a Row")
            onClicked: control.insertRowClicked()
        }
    }

    Rectangle {
        anchors {
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        radius: 8
        color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)
        border.width: 1
        border.color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.12)
        width: controlButtonsRow.width + 16
        height: controlButtonsRow.height + 12

        Row {
            id: controlButtonsRow
            spacing: 5
            anchors.centerIn: parent

            Item {
                width: 170
                height: 34

                FluProgressBar {
                    anchors.left: parent.left
                    anchors.right: progressText.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0
                    to: 1
                    value: control.mountedProgress
                    indeterminate: false
                }

                FluText {
                    id: progressText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(control.mountedProgress * 100) + "%"
                    font: FluTextStyle.Caption
                    color: FluTheme.dark ? "#e0e0e0" : "#444444"
                }
            }

            FluIconButton {
                iconSource: control.runPaused ? FluentIcons.Play : FluentIcons.Pause
                iconSize: 16
                width: 34
                height: 34
                onClicked: control.runToggleClicked()
            }
            FluIconButton {
                iconSource: FluentIcons.Stop
                iconSize: 16
                width: 34
                height: 34
                onClicked: control.stopClicked()
            }
            FluIconButton {
                iconSource: FluentIcons.ChevronRight
                iconSize: 16
                width: 34
                height: 34
                onClicked: control.stepClicked()
            }
        }
    }
}
