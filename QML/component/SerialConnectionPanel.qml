import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import FluentUI

FluGroupBox {
    id: panel
    title: qsTr("控制器连接")

    property string controllerStatus: qsTr("未连接")
    property string selectedComPort: ""
    property int selectedBaudRate: 115200
    property var availableComPorts: []
    property var availableBaudRates: [9600, 19200, 38400, 57600, 115200]
    property string consoleText: ""
    property bool autoReconnectEnabled: false

    signal comPortSelected(string portName)
    signal baudRateSelected(int baudRate)
    signal toggleConnectionRequested()
    signal rescanRequested()
    signal sendRequested(string text)
    signal autoReconnectToggled(bool enabled)

    Column {
        width: parent.width
        spacing: 15

        Row {
            width: parent.width
            spacing: 10

            FluText {
                text: qsTr("状态：")
                font.bold: true
            }

            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: panel.controllerStatus === qsTr("已连接") ? "#4caf50" : "#f44336"
            }

            FluText {
                text: panel.controllerStatus
                color: panel.controllerStatus === qsTr("已连接") ? "#4caf50" : "#f44336"
                font.bold: true
            }

            Item { width: 1 }
        }

        Row {
            width: parent.width
            spacing: 15

            Column {
                spacing: 5
                width: parent.width * 0.45

                FluText {
                    text: qsTr("串口")
                    font.pixelSize: 12
                }

                FluComboBox {
                    width: parent.width
                    model: panel.availableComPorts
                    currentIndex: Math.max(0, panel.availableComPorts.indexOf(panel.selectedComPort))
                    onCurrentIndexChanged: {
                        if (currentIndex >= 0 && currentIndex < panel.availableComPorts.length) {
                            panel.comPortSelected(panel.availableComPorts[currentIndex])
                        }
                    }
                }
            }

            Column {
                spacing: 5
                width: parent.width * 0.45

                FluText {
                    text: qsTr("波特率")
                    font.pixelSize: 12
                }

                FluComboBox {
                    width: parent.width
                    model: panel.availableBaudRates
                    currentIndex: Math.max(0, panel.availableBaudRates.indexOf(panel.selectedBaudRate))
                    onCurrentIndexChanged: {
                        if (currentIndex >= 0 && currentIndex < panel.availableBaudRates.length) {
                            panel.baudRateSelected(panel.availableBaudRates[currentIndex])
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 10

            FluButton {
                text: panel.controllerStatus === qsTr("已连接") ? qsTr("断开连接") : qsTr("连接")
                width: 120
                onClicked: panel.toggleConnectionRequested()
            }

            FluButton {
                text: qsTr("重新扫描")
                width: 120
                onClicked: panel.rescanRequested()
            }

            FluCheckBox {
                text: qsTr("自动重连")
                checked: panel.autoReconnectEnabled
                onToggled: panel.autoReconnectToggled(checked)
            }

            Item { width: 1 }
        }

        Rectangle {
            width: parent.width
            height: 80
            color: FluTheme.dark ? "#1a1a1a" : "#fafafa"
            radius: 6
            border.color: FluTheme.dark ? "#3a3a3a" : "#e0e0e0"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5

                FluText {
                    text: qsTr("连接信息")
                    font.pixelSize: 12
                    font.bold: true
                }

                FluText {
                    text: qsTr("串口") + ": " + (panel.selectedComPort ? panel.selectedComPort : "--")
                    font.pixelSize: 11
                }

                FluText {
                    text: qsTr("波特率") + ": " + panel.selectedBaudRate + " baud"
                    font.pixelSize: 11
                }

                FluText {
                    text: qsTr("状态") + ": " + panel.controllerStatus
                    font.pixelSize: 11
                    color: panel.controllerStatus === qsTr("已连接") ? "#4caf50" : "#f44336"
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 220
            color: FluTheme.dark ? "#121212" : "#f7f7f7"
            radius: 6
            border.color: FluTheme.dark ? "#3a3a3a" : "#e0e0e0"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                FluText {
                    text: qsTr("串口控制台")
                    font.pixelSize: 12
                    font.bold: true
                }

                ScrollView {
                    width: parent.width
                    height: 170
                    clip: true

                    TextArea {
                        width: parent.width
                        readOnly: true
                        wrapMode: TextEdit.WrapAnywhere
                        text: panel.consoleText
                        color: FluTheme.dark ? "#d9d9d9" : "#202020"
                        background: null
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 10

            FluTextBox {
                id: sendTextBox
                width: parent.width * 0.72
                placeholderText: qsTr("输入要发送的数据")
                onAccepted: {
                    if (text.length > 0) {
                        panel.sendRequested(text)
                        text = ""
                    }
                }
            }

            FluButton {
                text: qsTr("发送")
                width: parent.width * 0.22
                onClicked: {
                    if (sendTextBox.text.length > 0) {
                        panel.sendRequested(sendTextBox.text)
                        sendTextBox.text = ""
                    }
                }
            }
        }
    }
}
