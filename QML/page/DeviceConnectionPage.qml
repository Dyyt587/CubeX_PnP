import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import QtMultimedia 6.2
import FluentUI

FluContentPage {
    id: root
    title: qsTr("设备连接")

    property var deviceList: []
    property int selectedDeviceIndex: -1

    // 控制器属性
    property string controllerStatus: qsTr("未连接")
    property string selectedComPort: ""
    property int selectedBaudRate: 115200
    property var availableComPorts: []
    property var availableBaudRates: [9600, 19200, 38400, 57600, 115200]

    Component.onCompleted: {
        loadDevices()
        syncComPorts(serialPortManager.portNames)
        serialPortManager.refreshPorts()
        cameraDeviceManager.refreshCameras()
    }

    Connections {
        target: mainWindow.sharedMediaDevices
        function onVideoInputsChanged() {
            cameraDeviceManager.refreshCameras()
        }
    }

    Connections {
        target: serialPortManager
        function onPortNamesChanged() {
            syncComPorts(serialPortManager.portNames)
        }
    }

    function loadDevices() {
        deviceList = [
                    { id: 1, name: "CubeXPnP-001", address: "192.168.1.100", status: "已连接", type: "USB" },
                    { id: 2, name: "CubeXPnP-002", address: "192.168.1.101", status: "离线", type: "网络" },
                    { id: 3, name: "CubeXPnP-003", address: "192.168.1.102", status: "已连接", type: "蓝牙" }
                ]
    }

    function syncComPorts(ports) {
        availableComPorts = ports ? ports.slice() : []
        if (availableComPorts.length === 0) {
            selectedComPort = ""
            if (controllerStatus === qsTr("已连接")) {
                controllerStatus = qsTr("未连接")
            }
            return
        }
        if (availableComPorts.indexOf(selectedComPort) === -1) {
            selectedComPort = availableComPorts[0]
        }
    }

    FluScrollablePage {
        anchors.fill: parent
        leftPadding: 20
        rightPadding: 20
        topPadding: 20
        bottomPadding: 20

        FluGroupBox {
            Layout.fillWidth: true
            title: qsTr("摄像头链接")

            Column {
                width: parent.width
                spacing: 15

                CameraCard {
                    cameraTitle: qsTr("顶部摄像头")
                    cameraName: qsTr("顶部摄像头")
                    cameraStatus: cameraDeviceManager.topCameraConnected ? qsTr("已连接") : qsTr("未连接")
                    cameraActive: cameraDeviceManager.topCameraOpened
                    cameraConnected: cameraDeviceManager.topCameraConnected
                    cameraOpened: cameraDeviceManager.topCameraOpened
                    cameraIndex: cameraDeviceManager.topCameraIndex
                    availableCameraNames: cameraDeviceManager.cameraNames
                    previewSource: "image://opencvpreview/top?" + openCvPreviewManager.topFrameToken
                    colorPreviewSource: "image://opencvpreview/top_color?" + openCvPreviewManager.topFrameToken
                    fps: openCvPreviewManager.topFps
                    processingMs: openCvPreviewManager.topProcessingMs
                    resWidth: openCvPreviewManager.topResWidth
                    resHeight: openCvPreviewManager.topResHeight
                    sharedCamera: mainWindow.topSharedCamera
                    binAlgorithm: openCvPreviewManager.topBinAlgorithm
                    binParam1: openCvPreviewManager.topBinParam1
                    binParam2: openCvPreviewManager.topBinParam2
                    onSelectCamera: (index) => cameraDeviceManager.selectTopCamera(index)
                    onInfoRequested: (message) => showInfo(message)
                    onBinAlgorithmUpdated: (algo) => { openCvPreviewManager.topBinAlgorithm = algo }
                    onBinParam1Updated: (value) => { openCvPreviewManager.topBinParam1 = value }
                    onBinParam2Updated: (value) => { openCvPreviewManager.topBinParam2 = value }
                    connectToggleAction: function() {
                        if (cameraDeviceManager.topCameraOpened) {
                            cameraDeviceManager.closeTopCamera()
                            cameraDeviceManager.disconnectTopCamera()
                            showInfo(qsTr("顶部摄像头已断开"))
                        } else {
                            if (cameraDeviceManager.connectTopCamera(cameraDeviceManager.topCameraIndex)
                                    && cameraDeviceManager.openTopCamera()) {
                                showInfo(qsTr("顶部摄像头已连接"))
                            } else {
                                showInfo(qsTr("顶部摄像头连接失败"))
                            }
                        }
                    }
                }

                CameraCard {
                    cameraTitle: qsTr("底部摄像头")
                    cameraName: qsTr("底部摄像头")
                    cameraStatus: cameraDeviceManager.bottomCameraConnected ? qsTr("已连接") : qsTr("未连接")
                    cameraActive: cameraDeviceManager.bottomCameraOpened
                    cameraConnected: cameraDeviceManager.bottomCameraConnected
                    cameraOpened: cameraDeviceManager.bottomCameraOpened
                    cameraIndex: cameraDeviceManager.bottomCameraIndex
                    availableCameraNames: cameraDeviceManager.cameraNames
                    previewSource: "image://opencvpreview/bottom?" + openCvPreviewManager.bottomFrameToken
                    colorPreviewSource: "image://opencvpreview/bottom_color?" + openCvPreviewManager.bottomFrameToken
                    fps: openCvPreviewManager.bottomFps
                    processingMs: openCvPreviewManager.bottomProcessingMs
                    resWidth: openCvPreviewManager.bottomResWidth
                    resHeight: openCvPreviewManager.bottomResHeight
                    sharedCamera: mainWindow.bottomSharedCamera
                    binAlgorithm: openCvPreviewManager.bottomBinAlgorithm
                    binParam1: openCvPreviewManager.bottomBinParam1
                    binParam2: openCvPreviewManager.bottomBinParam2
                    onSelectCamera: (index) => cameraDeviceManager.selectBottomCamera(index)
                    onInfoRequested: (message) => showInfo(message)
                    onBinAlgorithmUpdated: (algo) => { openCvPreviewManager.bottomBinAlgorithm = algo }
                    onBinParam1Updated: (value) => { openCvPreviewManager.bottomBinParam1 = value }
                    onBinParam2Updated: (value) => { openCvPreviewManager.bottomBinParam2 = value }
                    connectToggleAction: function() {
                        if (cameraDeviceManager.bottomCameraOpened) {
                            cameraDeviceManager.closeBottomCamera()
                            cameraDeviceManager.disconnectBottomCamera()
                            showInfo(qsTr("底部摄像头已断开"))
                        } else {
                            if (cameraDeviceManager.connectBottomCamera(cameraDeviceManager.bottomCameraIndex)
                                    && cameraDeviceManager.openBottomCamera()) {
                                showInfo(qsTr("底部摄像头已连接"))
                            } else {
                                showInfo(qsTr("底部摄像头连接失败"))
                            }
                        }
                    }
                }
            }
        }

        FluGroupBox {
            Layout.fillWidth: true
            title: qsTr("控制器连接")
            
            Column {
                width: parent.width
                spacing: 15

                // 连接状态
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
                        color: controllerStatus === qsTr("已连接") ? "#4caf50" : "#f44336"
                    }

                    FluText {
                        text: controllerStatus
                        color: controllerStatus === qsTr("已连接") ? "#4caf50" : "#f44336"
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }
                }

                // 串口配置
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
                            id: comPortCombo
                            width: parent.width
                            model: availableComPorts
                            currentIndex: Math.max(0, availableComPorts.indexOf(selectedComPort))
                            onCurrentIndexChanged: {
                                if (currentIndex >= 0 && currentIndex < availableComPorts.length) {
                                    selectedComPort = availableComPorts[currentIndex]
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
                            id: baudRateCombo
                            width: parent.width
                            model: availableBaudRates
                            currentIndex: Math.max(0, availableBaudRates.indexOf(selectedBaudRate))
                            onCurrentIndexChanged: {
                                if (currentIndex >= 0 && currentIndex < availableBaudRates.length) {
                                    selectedBaudRate = availableBaudRates[currentIndex]
                                }
                            }
                        }
                    }
                }

                // 连接/断开按钮
                Row {
                    width: parent.width
                    spacing: 10

                    FluButton {
                        text: controllerStatus === qsTr("已连接") ? qsTr("断开连接") : qsTr("连接")
                        // type: controllerStatus === qsTr("已连接") ? FluButtonType.Default : FluButtonType.Primary
                        width: parent.width * 0.3
                        onClicked: {
                            if (!selectedComPort) {
                                showInfo(qsTr("未检测到可用串口"))
                                return
                            }
                            if (controllerStatus === qsTr("已连接")) {
                                controllerStatus = qsTr("未连接")
                                showInfo(qsTr("已断开控制器连接"))
                            } else {
                                controllerStatus = qsTr("已连接")
                                showInfo(qsTr("已连接控制器") + " (" + selectedComPort + " @ " + selectedBaudRate + " baud)")
                            }
                        }
                    }

                    FluButton {
                        text: qsTr("重新扫描")
                        width: parent.width * 0.3
                        onClicked: {
                            serialPortManager.refreshPorts()
                            showInfo(qsTr("已扫描可用串口：") + availableComPorts.length)
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // 串口信息显示
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
                            text: qsTr("串口") + ": " + (selectedComPort ? selectedComPort : "--")
                            font.pixelSize: 11
                        }

                        FluText {
                            text: qsTr("波特率") + ": " + selectedBaudRate + " baud"
                            font.pixelSize: 11
                        }

                        FluText {
                            text: qsTr("状态") + ": " + controllerStatus
                            font.pixelSize: 11
                            color: controllerStatus === qsTr("已连接") ? "#4caf50" : "#f44336"
                        }
                    }
                }
            }
        }
    }

    // 删除设备确认对话框
    FluContentDialog {
        id: removeDeviceDialog
        title: qsTr("确认删除")
        message: qsTr("确定要删除选中的设备吗？")
        negativeText: qsTr("取消")
        positiveText: qsTr("删除")
        
        onPositiveClicked: {
            if (selectedDeviceIndex >= 0) {
                deviceList.splice(selectedDeviceIndex, 1)
                selectedDeviceIndex = -1
                showInfo(qsTr("设备已删除"))
            }
        }
    }

    function showInfoBar(message, type) {
        showInfo(message)
    }
}
