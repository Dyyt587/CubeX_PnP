import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import QtMultimedia 6.2
import FluentUI

Rectangle {
    id: cameraCard
    width: parent.width
    height: 510
    color: FluTheme.dark ? "#2a2a2a" : "#f5f5f5"
    radius: 8
    border.color: FluTheme.dark ? "#3a3a3a" : "#e0e0e0"
    border.width: 1

    required property string cameraTitle
    property string cameraName: ""
    property string cameraStatus: qsTr("未连接")
    property bool cameraActive: false
    property bool cameraConnected: false
    property bool cameraOpened: false
    property int cameraIndex: -1
    property var availableCameraNames: []
    property string previewSource: ""
    property string colorPreviewSource: ""
    property real fps: 0
    property real processingMs: 0
    property int resWidth: 0
    property int resHeight: 0
    property var sharedCamera: null
    property var connectToggleAction: null

    property real cameraBrightness: 0
    property real cameraContrast: 0
    property real cameraSaturation: 100
    property real cameraExposure: 0
    property bool cameraConnecting: false
    property bool bwFlip: false
    property bool colorFlip: false

    property string spare2Label: qsTr("备用2")
    property string spare3Label: qsTr("备用3")
    property string spare4Label: qsTr("备用4")
    property real spare2Value: 0
    property real spare3Value: 0
    property real spare4Value: 0
    property real spare2From: -1
    property real spare2To: 1
    property real spare3From: -1
    property real spare3To: 1
    property real spare4From: -1
    property real spare4To: 1

    property int binAlgorithm: 0
    property real binParam1: 127
    property real binParam2: 5

    readonly property var binAlgorithmNames: [
        qsTr("手动阈值"),
        qsTr("Otsu自适应"),
        qsTr("Triangle"),
        qsTr("自适应高斯"),
        qsTr("自适应均值")
    ]

    signal selectCamera(int index)
    signal infoRequested(string message)
    signal binAlgorithmUpdated(int algo)
    signal binParam1Updated(real value)
    signal binParam2Updated(real value)

    onCameraActiveChanged: {
        if (cameraActive && sharedCamera) {
            sharedCamera.exposureCompensation = cameraBrightness
            if (sharedCamera.isWhiteBalanceModeSupported(Camera.WhiteBalanceManual)) {
                sharedCamera.whiteBalanceMode = Camera.WhiteBalanceManual
                sharedCamera.colorTemperature = Math.max(2000, Math.min(6500, 4500 + cameraExposure * 500))
            }
        }
    }

    Binding {
        target: sharedCamera
        property: "exposureCompensation"
        value: cameraBrightness
        when: cameraActive
    }

    Binding {
        target: sharedCamera
        property: "colorTemperature"
        value: Math.max(2000, Math.min(6500, 4500 + cameraExposure * 500))
        when: cameraActive && sharedCamera && sharedCamera.whiteBalanceMode === Camera.WhiteBalanceManual
    }

    Timer {
        id: connectTimer
        interval: 30
        repeat: false
        onTriggered: {
            cameraConnecting = false
            if (connectToggleAction) connectToggleAction()
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        Row {
            width: parent.width
            spacing: 10

            FluText {
                text: cameraTitle
                font.pixelSize: 14
                font.bold: true
            }

            Rectangle {
                width: 12; height: 12; radius: 6
                color: cameraStatus === qsTr("已连接") ? "#4caf50" : "#f44336"
            }

            FluText {
                text: cameraStatus
                font.pixelSize: 12
                color: cameraStatus === qsTr("已连接") ? "#4caf50" : "#f44336"
            }

            Item { width: 1; Layout.fillWidth: true }
        }

        Row {
            width: parent.width
            spacing: 10

            FluTextBox {
                width: parent.width * 0.35
                placeholderText: qsTr("摄像头名称")
                text: cameraCard.cameraName
                onTextChanged: cameraCard.cameraName = text
            }

            FluComboBox {
                width: parent.width * 0.35
                model: availableCameraNames
                enabled: !cameraOpened && !cameraConnecting
                currentIndex: cameraIndex
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && currentIndex < availableCameraNames.length)
                        cameraCard.selectCamera(currentIndex)
                }
            }

            FluButton {
                width: parent.width * 0.2
                enabled: !cameraConnecting
                text: cameraConnecting ? qsTr("处理中...") : (cameraConnected ? qsTr("断开") : qsTr("连接"))
                onClicked: {
                    if (!cameraConnected && cameraIndex < 0) {
                        cameraCard.infoRequested(qsTr("未检测到") + cameraTitle + qsTr("设备"))
                        return
                    }
                    cameraConnecting = true
                    connectTimer.restart()
                }
            }
        }

        Row {
            width: parent.width
            height: 240
            spacing: 10

            Rectangle {
                width: (parent.width - parent.spacing) * 0.25
                height: parent.height
                radius: 6
                color: FluTheme.dark ? "#1a1a1a" : "#fafafa"
                border.color: FluTheme.dark ? "#3a3a3a" : "#e0e0e0"
                border.width: 1
                clip: true

                Image {
                    id: bwImageA
                    anchors.fill: parent
                    visible: cameraActive && status === Image.Ready
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    asynchronous: false
                }
                Image {
                    id: bwImageB
                    anchors.fill: parent
                    visible: cameraActive && status === Image.Ready
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    asynchronous: false
                }
                Connections {
                    target: cameraCard
                    function onPreviewSourceChanged() {
                        if (cameraCard.bwFlip) {
                            bwImageA.source = cameraCard.previewSource
                        } else {
                            bwImageB.source = cameraCard.previewSource
                        }
                        cameraCard.bwFlip = !cameraCard.bwFlip
                    }
                }

                FluText {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 4
                    visible: cameraActive
                    text: qsTr("黑白")
                    font.pixelSize: 10
                    color: FluTheme.dark ? "#aaaaaa" : "#666666"
                }

                FluText {
                    anchors.centerIn: parent
                    visible: !cameraActive
                    text: availableCameraNames.length === 0 ? qsTr("未检测到摄像头") : qsTr("黑白预览")
                    font.pixelSize: 11
                }
            }

            Rectangle {
                width: (parent.width - parent.spacing) * 0.25
                height: parent.height
                radius: 6
                color: FluTheme.dark ? "#1a1a1a" : "#fafafa"
                border.color: FluTheme.dark ? "#3a3a3a" : "#e0e0e0"
                border.width: 1
                clip: true

                Image {
                    id: colorImageA
                    anchors.fill: parent
                    visible: cameraActive && status === Image.Ready
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    asynchronous: false
                }
                Image {
                    id: colorImageB
                    anchors.fill: parent
                    visible: cameraActive && status === Image.Ready
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    asynchronous: false
                }
                Connections {
                    target: cameraCard
                    function onColorPreviewSourceChanged() {
                        if (cameraCard.colorFlip) {
                            colorImageA.source = cameraCard.colorPreviewSource
                        } else {
                            colorImageB.source = cameraCard.colorPreviewSource
                        }
                        cameraCard.colorFlip = !cameraCard.colorFlip
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 4
                    anchors.bottomMargin: 4
                    visible: cameraActive
                    radius: 4
                    color: FluTheme.dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(1, 1, 1, 0.65)
                    width: statsCol.width + 10
                    height: statsCol.height + 6

                    Column {
                        id: statsCol
                        anchors.centerIn: parent
                        spacing: 1

                        FluText {
                            text: qsTr("%1 FPS").arg(cameraCard.fps.toFixed(1))
                            font.pixelSize: 10
                            color: FluTheme.dark ? "#ffffff" : "#000000"
                        }
                        FluText {
                            text: cameraCard.processingMs.toFixed(1) + " ms"
                            font.pixelSize: 10
                            color: FluTheme.dark ? "#ffffff" : "#000000"
                        }
                        FluText {
                            text: cameraCard.resWidth + "\u00d7" + cameraCard.resHeight
                            font.pixelSize: 10
                            color: FluTheme.dark ? "#ffffff" : "#000000"
                        }
                    }
                }

                FluText {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 4
                    visible: cameraActive
                    text: qsTr("彩色")
                    font.pixelSize: 10
                    color: FluTheme.dark ? "#aaaaaa" : "#666666"
                }

                FluText {
                    anchors.centerIn: parent
                    visible: !cameraActive
                    text: availableCameraNames.length === 0 ? qsTr("未检测到摄像头") : qsTr("彩色预览")
                    font.pixelSize: 11
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
                        width: 50; height: 24
                        font.pixelSize: 10
                        onClicked: {
                            cameraBrightness = 0
                            cameraContrast = 0
                            cameraSaturation = 100
                            cameraExposure = 0
                            cameraCard.infoRequested(cameraTitle + qsTr("参数已重置"))
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
                            text: qsTr("亮度: ") + (cameraBrightness * 100).toFixed(0) + "%"
                            font.pixelSize: 10
                            color: FluTheme.dark ? "#ffffff" : "#000000"
                        }
                        FluSlider {
                            width: parent.width
                            from: -1; to: 1
                            value: cameraBrightness
                            onValueChanged: cameraBrightness = value
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 2
                        Text {
                            text: qsTr("对比度: ") + (cameraContrast * 100).toFixed(0) + "%"
                            font.pixelSize: 10
                            color: FluTheme.dark ? "#ffffff" : "#000000"
                        }
                        FluSlider {
                            width: parent.width
                            from: -1; to: 1
                            value: cameraContrast
                            onValueChanged: cameraContrast = value
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 2
                        Text {
                            text: qsTr("饱和度: ") + cameraSaturation.toFixed(0) + "%"
                            font.pixelSize: 10
                            color: FluTheme.dark ? "#ffffff" : "#000000"
                        }
                        FluSlider {
                            width: parent.width
                            from: 0; to: 200
                            value: cameraSaturation
                            onValueChanged: cameraSaturation = value
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 2
                        Text {
                            text: qsTr("曝光: ") + (cameraExposure * 100).toFixed(0) + "%"
                            font.pixelSize: 10
                            color: FluTheme.dark ? "#ffffff" : "#000000"
                        }
                        FluSlider {
                            width: parent.width
                            from: -2; to: 2
                            value: cameraExposure
                            onValueChanged: cameraExposure = value
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 15

            Column {
                width: parent.width * 0.35
                spacing: 4

                Text {
                    text: qsTr("二值化算法")
                    font.pixelSize: 11
                    font.bold: true
                    color: FluTheme.dark ? "#ffffff" : "#000000"
                }

                FluComboBox {
                    width: parent.width
                    model: binAlgorithmNames
                    currentIndex: binAlgorithm
                    onCurrentIndexChanged: {
                        if (currentIndex !== binAlgorithm) {
                            binAlgorithm = currentIndex
                            cameraCard.binAlgorithmUpdated(currentIndex)
                        }
                    }
                }
            }

            Column {
                width: parent.width * 0.6
                spacing: 4
                visible: binAlgorithm === 0

                Text {
                    text: qsTr("阈值: ") + binParam1.toFixed(0)
                    font.pixelSize: 10
                    color: FluTheme.dark ? "#ffffff" : "#000000"
                }
                FluSlider {
                    width: parent.width
                    from: 0; to: 255; stepSize: 1
                    value: binParam1
                    onValueChanged: {
                        binParam1 = value
                        cameraCard.binParam1Updated(value)
                    }
                }
            }

            Column {
                width: parent.width * 0.6
                spacing: 4
                visible: binAlgorithm === 1 || binAlgorithm === 2

                Text {
                    text: binAlgorithm === 1 ? qsTr("Otsu: 自动计算阈值") : qsTr("Triangle: 自动计算阈值")
                    font.pixelSize: 10
                    color: FluTheme.dark ? "#aaaaaa" : "#888888"
                }
            }

            Column {
                width: parent.width * 0.6
                spacing: 2
                visible: binAlgorithm === 3 || binAlgorithm === 4

                Text {
                    text: qsTr("块大小: ") + (Math.max(3, Math.floor(binParam1) % 2 === 0 ? Math.floor(binParam1) + 1 : Math.floor(binParam1)))
                    font.pixelSize: 10
                    color: FluTheme.dark ? "#ffffff" : "#000000"
                }
                FluSlider {
                    width: parent.width
                    from: 3; to: 99; stepSize: 2
                    value: binParam1
                    onValueChanged: {
                        binParam1 = value
                        cameraCard.binParam1Updated(value)
                    }
                }

                Text {
                    text: qsTr("C值: ") + binParam2.toFixed(1)
                    font.pixelSize: 10
                    color: FluTheme.dark ? "#ffffff" : "#000000"
                }
                FluSlider {
                    width: parent.width
                    from: -20; to: 20; stepSize: 0.5
                    value: binParam2
                    onValueChanged: {
                        binParam2 = value
                        cameraCard.binParam2Updated(value)
                    }
                }
            }
        }

        Grid {
            width: parent.width
            columns: 3
            columnSpacing: 15
            rowSpacing: 6

            Column {
                width: (parent.width - 30) / 3
                spacing: 2
                Text {
                    text: spare2Label + ": " + spare2Value.toFixed(2)
                    font.pixelSize: 10
                    color: FluTheme.dark ? "#ffffff" : "#000000"
                }
                FluSlider {
                    width: parent.width
                    from: spare2From; to: spare2To
                    value: spare2Value
                    onValueChanged: spare2Value = value
                }
            }

            Column {
                width: (parent.width - 30) / 3
                spacing: 2
                Text {
                    text: spare3Label + ": " + spare3Value.toFixed(2)
                    font.pixelSize: 10
                    color: FluTheme.dark ? "#ffffff" : "#000000"
                }
                FluSlider {
                    width: parent.width
                    from: spare3From; to: spare3To
                    value: spare3Value
                    onValueChanged: spare3Value = value
                }
            }

            Column {
                width: (parent.width - 30) / 3
                spacing: 2
                Text {
                    text: spare4Label + ": " + spare4Value.toFixed(2)
                    font.pixelSize: 10
                    color: FluTheme.dark ? "#ffffff" : "#000000"
                }
                FluSlider {
                    width: parent.width
                    from: spare4From; to: spare4To
                    value: spare4Value
                    onValueChanged: spare4Value = value
                }
            }
        }
    }
}
