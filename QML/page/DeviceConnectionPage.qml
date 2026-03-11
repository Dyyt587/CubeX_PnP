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
    
    property string topCameraStatus: cameraDeviceManager.topCameraConnected ? qsTr("已连接") : qsTr("未连接")
    property string topCameraName: qsTr("顶部摄像头")
    property string bottomCameraStatus: cameraDeviceManager.bottomCameraConnected ? qsTr("已连接") : qsTr("未连接")
    property string bottomCameraName: qsTr("底部摄像头")
    property var availableCameraNames: cameraDeviceManager.cameraNames
    property int topCameraIndex: cameraDeviceManager.topCameraIndex
    property int bottomCameraIndex: cameraDeviceManager.bottomCameraIndex
    property bool topCameraActive: cameraDeviceManager.topCameraOpened
    property bool bottomCameraActive: cameraDeviceManager.bottomCameraOpened
    property bool topCameraConnecting: false
    property bool bottomCameraConnecting: false
    
    // 顶部摄像头参数
    property real topCameraBrightness: 0
    property real topCameraContrast: 0
    property real topCameraSaturation: 100
    property real topCameraExposure: 0
    
    // 底部摄像头参数
    property real bottomCameraBrightness: 0
    property real bottomCameraContrast: 0
    property real bottomCameraSaturation: 100
    property real bottomCameraExposure: 0
    
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
        target: root
        function onTopCameraActiveChanged() {
            if (topCameraActive && mainWindow.topSharedCamera) {
                mainWindow.topSharedCamera.exposureCompensation = topCameraBrightness
                if (mainWindow.topSharedCamera.isWhiteBalanceModeSupported(Camera.WhiteBalanceManual)) {
                    mainWindow.topSharedCamera.whiteBalanceMode = Camera.WhiteBalanceManual
                    mainWindow.topSharedCamera.colorTemperature = Math.max(2000, Math.min(6500, 4500 + topCameraExposure * 500))
                }
            }
        }
    }

    Binding {
        target: mainWindow.topSharedCamera
        property: "exposureCompensation"
        value: topCameraBrightness
        when: topCameraActive
    }

    Binding {
        target: mainWindow.topSharedCamera
        property: "colorTemperature"
        value: Math.max(2000, Math.min(6500, 4500 + topCameraExposure * 500))
        when: topCameraActive && mainWindow.topSharedCamera && mainWindow.topSharedCamera.whiteBalanceMode === Camera.WhiteBalanceManual
    }

    Connections {
        target: root
        function onBottomCameraActiveChanged() {
            if (bottomCameraActive && mainWindow.bottomSharedCamera) {
                mainWindow.bottomSharedCamera.exposureCompensation = bottomCameraBrightness
                if (mainWindow.bottomSharedCamera.isWhiteBalanceModeSupported(Camera.WhiteBalanceManual)) {
                    mainWindow.bottomSharedCamera.whiteBalanceMode = Camera.WhiteBalanceManual
                    mainWindow.bottomSharedCamera.colorTemperature = Math.max(2000, Math.min(6500, 4500 + bottomCameraExposure * 500))
                }
            }
        }
    }

    Binding {
        target: mainWindow.bottomSharedCamera
        property: "exposureCompensation"
        value: bottomCameraBrightness
        when: bottomCameraActive
    }

    Binding {
        target: mainWindow.bottomSharedCamera
        property: "colorTemperature"
        value: Math.max(2000, Math.min(6500, 4500 + bottomCameraExposure * 500))
        when: bottomCameraActive && mainWindow.bottomSharedCamera && mainWindow.bottomSharedCamera.whiteBalanceMode === Camera.WhiteBalanceManual
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

    Timer {
        id: topConnectTimer
        interval: 30
        repeat: false
        onTriggered: {
            topCameraConnecting = false
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

    Timer {
        id: bottomConnectTimer
        interval: 30
        repeat: false
        onTriggered: {
            bottomCameraConnecting = false
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

                Rectangle {
                    width: parent.width
                    height: 360
                    color: FluTheme.dark ? "#2a2a2a" : "#f5f5f5"
                    radius: 8
                    border.color: FluTheme.dark ? "#3a3a3a" : "#e0e0e0"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 10

                        Row {
                            width: parent.width
                            spacing: 10

                            FluText {
                                text: qsTr("顶部摄像头")
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: topCameraStatus === qsTr("已连接") ? "#4caf50" : "#f44336"
                            }

                            FluText {
                                text: topCameraStatus
                                font.pixelSize: 12
                                color: topCameraStatus === qsTr("已连接") ? "#4caf50" : "#f44336"
                            }

                            Item { width: 1; Layout.fillWidth: true }
                        }

                        Row {
                            width: parent.width
                            spacing: 10

                            FluTextBox {
                                width: parent.width * 0.35
                                placeholderText: qsTr("摄像头名称")
                                text: topCameraName
                                onTextChanged: topCameraName = text
                            }

                            FluComboBox {
                                width: parent.width * 0.35
                                model: availableCameraNames
                                enabled: !cameraDeviceManager.topCameraOpened && !topCameraConnecting
                                currentIndex: cameraDeviceManager.topCameraIndex
                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0 && currentIndex < availableCameraNames.length) {
                                        cameraDeviceManager.selectTopCamera(currentIndex)
                                    }
                                }
                            }

                            FluButton {
                                width: parent.width * 0.2
                                enabled: !topCameraConnecting
                                text: topCameraConnecting ? qsTr("处理中...") : (cameraDeviceManager.topCameraConnected ? qsTr("断开") : qsTr("连接"))
                                onClicked: {
                                    if (!cameraDeviceManager.topCameraConnected && cameraDeviceManager.topCameraIndex < 0) {
                                        showInfo(qsTr("未检测到顶部摄像头设备"))
                                        return
                                    }
                                    topCameraConnecting = true
                                    topConnectTimer.restart()
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            height: 240
                            spacing: 15

                            Rectangle {
                                width: parent.width * 0.5
                                height: parent.height
                                radius: 6
                                color: FluTheme.dark ? "#1a1a1a" : "#fafafa"
                                border.color: FluTheme.dark ? "#3a3a3a" : "#e0e0e0"
                                border.width: 1

                                Image {
                                    id: topPreview
                                    anchors.fill: parent
                                    visible: topCameraActive
                                    fillMode: Image.PreserveAspectFit
                                    cache: false
                                    source: "image://opencvpreview/top?" + openCvPreviewManager.topFrameToken
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: 8
                                    anchors.bottomMargin: 6
                                    visible: topCameraActive
                                    radius: 4
                                    color: FluTheme.dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(1, 1, 1, 0.55)
                                    width: topFpsText.implicitWidth + 10
                                    height: topFpsText.implicitHeight + 4

                                    FluText {
                                        id: topFpsText
                                        anchors.centerIn: parent
                                        text: qsTr("%1 FPS").arg(openCvPreviewManager.topFps.toFixed(1))
                                        font.pixelSize: 11
                                        color: FluTheme.dark ? "#ffffff" : "#000000"
                                    }
                                }

                                FluText {
                                    anchors.centerIn: parent
                                    visible: !topCameraActive
                                    text: availableCameraNames.length === 0 ? qsTr("未检测到摄像头") : qsTr("点击连接开始预览")
                                    font.pixelSize: 12
                                }
                            }

                            Column {
                                width: parent.width * 0.5
                                height: parent.height
                                spacing: 8

                                Row {
                                    width: parent.width
                                    spacing: 10

                                    Text {
                                        text: qsTr("参数调节")
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: FluTheme.dark ? "#ffffff" : "#000000"
                                    }

                                    Item { Layout.fillWidth: true }

                                    FluButton {
                                        text: qsTr("重置")
                                        width: 50
                                        height: 24
                                        font.pixelSize: 10
                                        onClicked: {
                                            topCameraBrightness = 0
                                            topCameraContrast = 0
                                            topCameraSaturation = 100
                                            topCameraExposure = 0
                                            showInfo(qsTr("顶部摄像头参数已重置"))
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 6

                                    Column {
                                        width: parent.width
                                        spacing: 2

                                        Text {
                                            text: qsTr("亮度: ") + (topCameraBrightness * 100).toFixed(0) + "%"
                                            font.pixelSize: 10
                                            color: FluTheme.dark ? "#ffffff" : "#000000"
                                        }

                                        FluSlider {
                                            width: parent.width
                                            from: -1
                                            to: 1
                                            value: topCameraBrightness
                                            onValueChanged: topCameraBrightness = value
                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: 2

                                        Text {
                                            text: qsTr("对比度: ") + (topCameraContrast * 100).toFixed(0) + "%"
                                            font.pixelSize: 10
                                            color: FluTheme.dark ? "#ffffff" : "#000000"
                                        }

                                        FluSlider {
                                            width: parent.width
                                            from: -1
                                            to: 1
                                            value: topCameraContrast
                                            onValueChanged: topCameraContrast = value
                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: 2

                                        Text {
                                            text: qsTr("饱和度: ") + topCameraSaturation.toFixed(0) + "%"
                                            font.pixelSize: 10
                                            color: FluTheme.dark ? "#ffffff" : "#000000"
                                        }

                                        FluSlider {
                                            width: parent.width
                                            from: 0
                                            to: 200
                                            value: topCameraSaturation
                                            onValueChanged: topCameraSaturation = value
                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: 2

                                        Text {
                                            text: qsTr("曝光: ") + (topCameraExposure * 100).toFixed(0) + "%"
                                            font.pixelSize: 10
                                            color: FluTheme.dark ? "#ffffff" : "#000000"
                                        }

                                        FluSlider {
                                            width: parent.width
                                            from: -2
                                            to: 2
                                            value: topCameraExposure
                                            onValueChanged: topCameraExposure = value
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 360
                    color: FluTheme.dark ? "#2a2a2a" : "#f5f5f5"
                    radius: 8
                    border.color: FluTheme.dark ? "#3a3a3a" : "#e0e0e0"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 10

                        Row {
                            width: parent.width
                            spacing: 10

                            FluText {
                                text: qsTr("底部摄像头")
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: bottomCameraStatus === qsTr("已连接") ? "#4caf50" : "#f44336"
                            }

                            FluText {
                                text: bottomCameraStatus
                                font.pixelSize: 12
                                color: bottomCameraStatus === qsTr("已连接") ? "#4caf50" : "#f44336"
                            }

                            Item { width: 1; Layout.fillWidth: true }
                        }

                        Row {
                            width: parent.width
                            spacing: 10

                            FluTextBox {
                                width: parent.width * 0.35
                                placeholderText: qsTr("摄像头名称")
                                text: bottomCameraName
                                onTextChanged: bottomCameraName = text
                            }

                            FluComboBox {
                                width: parent.width * 0.35
                                model: availableCameraNames
                                enabled: !cameraDeviceManager.bottomCameraOpened && !bottomCameraConnecting
                                currentIndex: cameraDeviceManager.bottomCameraIndex
                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0 && currentIndex < availableCameraNames.length) {
                                        cameraDeviceManager.selectBottomCamera(currentIndex)
                                    }
                                }
                            }

                            FluButton {
                                width: parent.width * 0.2
                                enabled: !bottomCameraConnecting
                                text: bottomCameraConnecting ? qsTr("处理中...") : (cameraDeviceManager.bottomCameraConnected ? qsTr("断开") : qsTr("连接"))
                                onClicked: {
                                    if (!cameraDeviceManager.bottomCameraConnected && cameraDeviceManager.bottomCameraIndex < 0) {
                                        showInfo(qsTr("未检测到底部摄像头设备"))
                                        return
                                    }
                                    bottomCameraConnecting = true
                                    bottomConnectTimer.restart()
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            height: 240
                            spacing: 15

                            Rectangle {
                                width: parent.width * 0.5
                                height: parent.height
                                radius: 6
                                color: FluTheme.dark ? "#1a1a1a" : "#fafafa"
                                border.color: FluTheme.dark ? "#3a3a3a" : "#e0e0e0"
                                border.width: 1

                                Image {
                                    id: bottomPreview
                                    anchors.fill: parent
                                    visible: bottomCameraActive
                                    fillMode: Image.PreserveAspectFit
                                    cache: false
                                    source: "image://opencvpreview/bottom?" + openCvPreviewManager.bottomFrameToken
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: 8
                                    anchors.bottomMargin: 6
                                    visible: bottomCameraActive
                                    radius: 4
                                    color: FluTheme.dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(1, 1, 1, 0.55)
                                    width: bottomFpsText.implicitWidth + 10
                                    height: bottomFpsText.implicitHeight + 4

                                    FluText {
                                        id: bottomFpsText
                                        anchors.centerIn: parent
                                        text: qsTr("%1 FPS").arg(openCvPreviewManager.bottomFps.toFixed(1))
                                        font.pixelSize: 11
                                        color: FluTheme.dark ? "#ffffff" : "#000000"
                                    }
                                }

                                FluText {
                                    anchors.centerIn: parent
                                    visible: !bottomCameraActive
                                    text: availableCameraNames.length === 0 ? qsTr("未检测到摄像头") : qsTr("点击连接开始预览")
                                    font.pixelSize: 12
                                }
                            }

                            Column {
                                width: parent.width * 0.5
                                height: parent.height
                                spacing: 8

                                Row {
                                    width: parent.width
                                    spacing: 10

                                    Text {
                                        text: qsTr("参数调节")
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: FluTheme.dark ? "#ffffff" : "#000000"
                                    }

                                    Item { Layout.fillWidth: true }

                                    FluButton {
                                        text: qsTr("重置")
                                        width: 50
                                        height: 24
                                        font.pixelSize: 10
                                        onClicked: {
                                            bottomCameraBrightness = 0
                                            bottomCameraContrast = 0
                                            bottomCameraSaturation = 100
                                            bottomCameraExposure = 0
                                            showInfo(qsTr("底部摄像头参数已重置"))
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 6

                                    Column {
                                        width: parent.width
                                        spacing: 2

                                        Text {
                                            text: qsTr("亮度: ") + (bottomCameraBrightness * 100).toFixed(0) + "%"
                                            font.pixelSize: 10
                                            color: FluTheme.dark ? "#ffffff" : "#000000"
                                        }

                                        FluSlider {
                                            width: parent.width
                                            from: -1
                                            to: 1
                                            value: bottomCameraBrightness
                                            onValueChanged: bottomCameraBrightness = value
                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: 2

                                        Text {
                                            text: qsTr("对比度: ") + (bottomCameraContrast * 100).toFixed(0) + "%"
                                            font.pixelSize: 10
                                            color: FluTheme.dark ? "#ffffff" : "#000000"
                                        }

                                        FluSlider {
                                            width: parent.width
                                            from: -1
                                            to: 1
                                            value: bottomCameraContrast
                                            onValueChanged: bottomCameraContrast = value
                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: 2

                                        Text {
                                            text: qsTr("饱和度: ") + bottomCameraSaturation.toFixed(0) + "%"
                                            font.pixelSize: 10
                                            color: FluTheme.dark ? "#ffffff" : "#000000"
                                        }

                                        FluSlider {
                                            width: parent.width
                                            from: 0
                                            to: 200
                                            value: bottomCameraSaturation
                                            onValueChanged: bottomCameraSaturation = value
                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: 2

                                        Text {
                                            text: qsTr("曝光: ") + (bottomCameraExposure * 100).toFixed(0) + "%"
                                            font.pixelSize: 10
                                            color: FluTheme.dark ? "#ffffff" : "#000000"
                                        }

                                        FluSlider {
                                            width: parent.width
                                            from: -2
                                            to: 2
                                            value: bottomCameraExposure
                                            onValueChanged: bottomCameraExposure = value
                                        }
                                    }
                                }
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
