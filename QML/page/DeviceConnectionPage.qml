import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import QtMultimedia 6.2
import "../component" as Components
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
    property string controllerConsoleText: ""
    property bool autoReconnectEnabled: false
    property bool manualDisconnectRequested: false
    property bool reconnectAttemptInProgress: false
    property string reconnectTargetComPort: ""
    property int reconnectTargetBaudRate: 115200

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
            if (root.autoReconnectEnabled && !serialPortManager.connected && root.reconnectTargetComPort) {
                autoReconnectTimer.start()
            }
        }
        function onConnectedChanged() {
            var nowConnected = serialPortManager.connected
            root.controllerStatus = serialPortManager.connected ? qsTr("已连接") : qsTr("未连接")
            if (nowConnected) {
                root.manualDisconnectRequested = false
                root.reconnectAttemptInProgress = false
                autoReconnectTimer.stop()
                appendControllerConsole(qsTr("[系统] 串口已连接"))
            } else {
                appendControllerConsole(qsTr("[系统] 串口已断开"))
                if (root.autoReconnectEnabled && !root.manualDisconnectRequested && root.reconnectTargetComPort) {
                    autoReconnectTimer.start()
                }
            }
        }
        function onConsoleMessage(message) {
            appendControllerConsole(message)
        }
        function onErrorOccurred(message) {
            appendControllerConsole(qsTr("[错误] ") + message)
            showInfo(message)
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

    function appendControllerConsole(message) {
        var now = new Date()
        var hh = String(now.getHours()).padStart(2, "0")
        var mm = String(now.getMinutes()).padStart(2, "0")
        var ss = String(now.getSeconds()).padStart(2, "0")
        var line = "[" + hh + ":" + mm + ":" + ss + "] " + message
        controllerConsoleText = controllerConsoleText.length > 0
                ? controllerConsoleText + "\n" + line
                : line
    }

    function updateReconnectTarget(portName, baudRate) {
        reconnectTargetComPort = portName
        reconnectTargetBaudRate = baudRate
    }

    function tryAutoReconnect() {
        if (!root.autoReconnectEnabled || serialPortManager.connected || !root.reconnectTargetComPort) {
            autoReconnectTimer.stop()
            root.reconnectAttemptInProgress = false
            return
        }
        serialPortManager.refreshPorts()
        if (root.availableComPorts.indexOf(root.reconnectTargetComPort) === -1) {
            return
        }
        root.reconnectAttemptInProgress = true
        if (serialPortManager.connectPort(root.reconnectTargetComPort, root.reconnectTargetBaudRate)) {
            root.selectedComPort = root.reconnectTargetComPort
            root.selectedBaudRate = root.reconnectTargetBaudRate
            root.appendControllerConsole(qsTr("[系统] 自动重连成功: ") + root.reconnectTargetComPort + " @ " + root.reconnectTargetBaudRate)
            root.showInfoBar(qsTr("串口已自动重连"))
        }
    }

    Timer {
        id: autoReconnectTimer
        interval: 3000
        repeat: true
        running: false
        onTriggered: root.tryAutoReconnect()
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
                    cameraRole: 0
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
                    binInvert: openCvPreviewManager.topBinInvert
                    onSelectCamera: (index) => cameraDeviceManager.selectTopCamera(index)
                    onInfoRequested: (message) => showInfo(message)
                    onBinAlgorithmUpdated: (algo) => { openCvPreviewManager.topBinAlgorithm = algo }
                    onBinParam1Updated: (value) => { openCvPreviewManager.topBinParam1 = value }
                    onBinParam2Updated: (value) => { openCvPreviewManager.topBinParam2 = value }
                    onBinInvertUpdated: (value) => { openCvPreviewManager.topBinInvert = value }
                    spare2Label: qsTr("最小面积")
                    spare3Label: qsTr("最大面积")
                    spare2From: 0; spare2To: 10000
                    spare3From: 0; spare3To: 100000
                    spare2Value: openCvPreviewManager.topContourMinArea
                    spare3Value: openCvPreviewManager.topContourMaxArea
                    onSpare2ValueChanged: openCvPreviewManager.topContourMinArea = spare2Value
                    onSpare3ValueChanged: openCvPreviewManager.topContourMaxArea = spare3Value
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
                    cameraRole: 1
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
                    binInvert: openCvPreviewManager.bottomBinInvert
                    onSelectCamera: (index) => cameraDeviceManager.selectBottomCamera(index)
                    onInfoRequested: (message) => showInfo(message)
                    onBinAlgorithmUpdated: (algo) => { openCvPreviewManager.bottomBinAlgorithm = algo }
                    onBinParam1Updated: (value) => { openCvPreviewManager.bottomBinParam1 = value }
                    onBinParam2Updated: (value) => { openCvPreviewManager.bottomBinParam2 = value }
                    onBinInvertUpdated: (value) => { openCvPreviewManager.bottomBinInvert = value }
                    spare2Label: qsTr("最小面积")
                    spare3Label: qsTr("最大面积")
                    spare2From: 0; spare2To: 10000
                    spare3From: 0; spare3To: 100000
                    spare2Value: openCvPreviewManager.bottomContourMinArea
                    spare3Value: openCvPreviewManager.bottomContourMaxArea
                    onSpare2ValueChanged: openCvPreviewManager.bottomContourMinArea = spare2Value
                    onSpare3ValueChanged: openCvPreviewManager.bottomContourMaxArea = spare3Value
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

        Components.SerialConnectionPanel {
            Layout.fillWidth: true
            controllerStatus: root.controllerStatus
            selectedComPort: root.selectedComPort
            selectedBaudRate: root.selectedBaudRate
            availableComPorts: root.availableComPorts
            availableBaudRates: root.availableBaudRates
            consoleText: root.controllerConsoleText
            autoReconnectEnabled: root.autoReconnectEnabled
            onAutoReconnectToggled: (enabled) => {
                root.autoReconnectEnabled = enabled
                root.manualDisconnectRequested = false
                if (enabled) {
                    root.updateReconnectTarget(root.selectedComPort, root.selectedBaudRate)
                    root.appendControllerConsole(qsTr("[系统] 自动重连已开启"))
                    if (!serialPortManager.connected && root.reconnectTargetComPort) {
                        autoReconnectTimer.start()
                    }
                } else {
                    autoReconnectTimer.stop()
                    root.reconnectAttemptInProgress = false
                    root.appendControllerConsole(qsTr("[系统] 自动重连已关闭"))
                }
            }
            onComPortSelected: (portName) => { root.selectedComPort = portName }
            onBaudRateSelected: (baudRate) => { root.selectedBaudRate = baudRate }
            onToggleConnectionRequested: {
                if (!root.selectedComPort) {
                    showInfo(qsTr("未检测到可用串口"))
                    return
                }
                if (root.controllerStatus === qsTr("已连接")) {
                    root.manualDisconnectRequested = true
                    autoReconnectTimer.stop()
                    serialPortManager.disconnectPort()
                    showInfo(qsTr("已断开控制器连接"))
                } else {
                    root.manualDisconnectRequested = false
                    root.updateReconnectTarget(root.selectedComPort, root.selectedBaudRate)
                    if (serialPortManager.connectPort(root.selectedComPort, root.selectedBaudRate)) {
                        appendControllerConsole(qsTr("[系统] 打开串口 ") + root.selectedComPort + " @ " + root.selectedBaudRate)
                        showInfo(qsTr("已连接控制器") + " (" + root.selectedComPort + " @ " + root.selectedBaudRate + " baud)")
                    }
                }
            }
            onRescanRequested: {
                serialPortManager.refreshPorts()
                appendControllerConsole(qsTr("[系统] 已请求重新扫描串口"))
                showInfo(qsTr("正在扫描可用串口"))
            }
            onSendRequested: (text) => {
                if (!serialPortManager.connected) {
                    showInfo(qsTr("串口未连接"))
                    return
                }
                serialPortManager.sendWithConsole(text)
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
