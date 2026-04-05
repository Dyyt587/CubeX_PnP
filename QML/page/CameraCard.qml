import QtQuick 6.2
import QtQuick.Controls 6.2
import QtQuick.Layouts 6.2
import QtMultimedia 6.2
import FluentUI

Rectangle {
    id: cameraCard
    width: parent.width
    height: 880
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
    property int cameraRole: 0 // 0: top, 1: bottom
    property string templateStatus: qsTr("未拍摄模板")
    property real templateMatchScore: 0
    property bool templateMatchVisible: false
    property real templateMatchX: 0
    property real templateMatchY: 0
    property real templateMatchW: 0
    property real templateMatchH: 0
    property bool continuousMatchingEnabled: false
    readonly property int frameToken: cameraRole === 0
                                     ? openCvPreviewManager.topFrameToken
                                     : openCvPreviewManager.bottomFrameToken
    readonly property int templateToken: cameraRole === 0
                                        ? openCvPreviewManager.topTemplateToken
                                        : openCvPreviewManager.bottomTemplateToken
    readonly property bool frameReady: cameraOpened && frameToken > 0
    readonly property bool templateReady: templateToken > 0
    property string templatePreviewSource: cameraRole === 0
                                           ? "image://opencvpreview/top_template?" + templateToken
                                           : "image://opencvpreview/bottom_template?" + templateToken
    property string matchPreviewSource: cameraRole === 0
                                        ? "image://opencvpreview/top_color?" + frameToken
                                        : "image://opencvpreview/bottom_color?" + frameToken
    property real templatePreviewSide: 320

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
    property bool binInvert: false

    readonly property var binAlgorithmNames: [
        qsTr("手动阈值"),
        qsTr("Otsu自适应"),
        qsTr("三角形法"),
        qsTr("自适应高斯"),
        qsTr("自适应均值")
    ]

    signal selectCamera(int index)
    signal infoRequested(string message)
    signal binAlgorithmUpdated(int algo)
    signal binParam1Updated(real value)
    signal binParam2Updated(real value)
    signal binInvertUpdated(bool value)

    function clamp01(value) {
        return Math.max(0, Math.min(1, value))
    }

    function imageContentRect(imageItem) {
        if (!imageItem)
            return Qt.rect(0, 0, 1, 1)

        var paintedW = imageItem.paintedWidth > 0 ? imageItem.paintedWidth : imageItem.width
        var paintedH = imageItem.paintedHeight > 0 ? imageItem.paintedHeight : imageItem.height
        var offsetX = imageItem.x + (imageItem.width - paintedW) / 2
        var offsetY = imageItem.y + (imageItem.height - paintedH) / 2
        return Qt.rect(offsetX, offsetY, Math.max(1, paintedW), Math.max(1, paintedH))
    }

    function currentColorContentRect() {
        if (colorImageA.paintedWidth > 0 && colorImageA.paintedHeight > 0)
            return imageContentRect(colorImageA)
        if (colorImageB.paintedWidth > 0 && colorImageB.paintedHeight > 0)
            return imageContentRect(colorImageB)
        return Qt.rect(0, 0, Math.max(1, colorOverlay.width), Math.max(1, colorOverlay.height))
    }

    function applyTemplateMatchResult(result, showError) {
        if (result.success) {
            templateStatus = qsTr("匹配成功")
            templateMatchScore = result.score
            var w = Math.max(1, cameraCard.resWidth)
            var h = Math.max(1, cameraCard.resHeight)
            var matchRect = imageContentRect(matchPreviewImage)
            var colorRect = currentColorContentRect()
            var normalizedX = clamp01(result.x / w)
            var normalizedY = clamp01(result.y / h)
            var normalizedW = clamp01(matchRegionBox.width / matchRect.width)
            var normalizedH = clamp01(matchRegionBox.height / matchRect.height)
            templateMatchX = colorRect.x + normalizedX * colorRect.width
            templateMatchY = colorRect.y + normalizedY * colorRect.height
            templateMatchW = normalizedW * colorRect.width
            templateMatchH = normalizedH * colorRect.height
            templateMatchVisible = true
            return
        }

        templateStatus = result.message ? result.message : qsTr("匹配失败")
        templateMatchVisible = false
        if (showError) {
            cameraCard.infoRequested(templateStatus)
        }
    }

    function performTemplateMatch(silent) {
        if (!cameraActive) {
            return
        }
        var result = openCvPreviewManager.runTemplateMatchInRegion(
                    cameraRole,
                    selectedTemplatePoints(),
                    fullFramePoints())
        applyTemplateMatchResult(result, !silent)
    }

    function fullFramePoints() {
        return [
            Qt.point(0, 0),
            Qt.point(1, 0),
            Qt.point(1, 1),
            Qt.point(0, 1)
        ]
    }

    function selectedMatchRegionPoints() {
        var rect = imageContentRect(matchPreviewImage)
        var left = clamp01((matchRegionBox.x - rect.x) / rect.width)
        var top = clamp01((matchRegionBox.y - rect.y) / rect.height)
        var right = clamp01((matchRegionBox.x + matchRegionBox.width - rect.x) / rect.width)
        var bottom = clamp01((matchRegionBox.y + matchRegionBox.height - rect.y) / rect.height)
        return [
            Qt.point(left, top),
            Qt.point(right, top),
            Qt.point(right, bottom),
            Qt.point(left, bottom)
        ]
    }

    function clampMatchRegionBox() {
        if (!matchRegionBox || !matchPreviewImage)
            return
        var rect = imageContentRect(matchPreviewImage)
        var minSize = 0
        if (matchRegionBox.width < minSize)
            matchRegionBox.width = minSize
        if (matchRegionBox.height < minSize)
            matchRegionBox.height = minSize
        if (matchRegionBox.width > rect.width)
            matchRegionBox.width = rect.width
        if (matchRegionBox.height > rect.height)
            matchRegionBox.height = rect.height
        if (matchRegionBox.x < rect.x)
            matchRegionBox.x = rect.x
        if (matchRegionBox.y < rect.y)
            matchRegionBox.y = rect.y
        if (matchRegionBox.x + matchRegionBox.width > rect.x + rect.width)
            matchRegionBox.x = Math.max(rect.x, rect.x + rect.width - matchRegionBox.width)
        if (matchRegionBox.y + matchRegionBox.height > rect.y + rect.height)
            matchRegionBox.y = Math.max(rect.y, rect.y + rect.height - matchRegionBox.height)
    }

    function selectedTemplatePoints() {
        return selectedMatchRegionPoints()
    }

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

    Timer {
        id: continuousMatchTimer
        interval: 400
        repeat: true
        running: cameraActive && continuousMatchingEnabled
        onTriggered: cameraCard.performTemplateMatch(true)
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

                Item {
                    id: colorOverlay
                    anchors.fill: parent
                    z: 5
                    visible: cameraActive

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 1
                        color: Qt.rgba(0.1, 1.0, 0.1, 0.8)
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Qt.rgba(0.1, 1.0, 0.1, 0.8)
                    }

                    Rectangle {
                        id: focusBox
                        width: 56
                        height: 56
                        x: (colorOverlay.width - width) / 2
                        y: (colorOverlay.height - height) / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(0.1, 1.0, 0.1, 0.95)
                        radius: 2

                        Behavior on x {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on y {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            cursorShape: Qt.OpenHandCursor
                            drag.target: parent
                            drag.axis: Drag.XAndYAxis
                            drag.minimumX: 0
                            drag.minimumY: 0
                            drag.maximumX: colorOverlay.width - focusBox.width
                            drag.maximumY: colorOverlay.height - focusBox.height

                            onPressed: cursorShape = Qt.ClosedHandCursor

                            onReleased: {
                                cursorShape = Qt.OpenHandCursor
                                focusBox.x = (colorOverlay.width - focusBox.width) / 2
                                focusBox.y = (colorOverlay.height - focusBox.height) / 2
                            }
                        }
                    }

                    Rectangle {
                        id: templateMatchBox
                        x: cameraCard.templateMatchX
                        y: cameraCard.templateMatchY
                        width: cameraCard.templateMatchW
                        height: cameraCard.templateMatchH
                        visible: cameraCard.templateMatchVisible
                        color: "transparent"
                        border.width: 2
                        border.color: "#ff9800"
                        radius: 2

                        readonly property real crossSize: Math.min(width, height) / 5

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.crossSize
                            height: 2
                            color: "#ff9800"
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 2
                            height: parent.crossSize
                            color: "#ff9800"
                        }
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
                            text: qsTr("%1 帧/秒").arg(cameraCard.fps.toFixed(1))
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

            FluCheckBox {
                text: qsTr("取反")
                checked: binInvert
                onCheckedChanged: {
                    if (checked !== binInvert) {
                        binInvert = checked
                        cameraCard.binInvertUpdated(checked)
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
                    text: binAlgorithm === 1 ? qsTr("Otsu: 自动计算阈值") : qsTr("三角形法: 自动计算阈值")
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

        Rectangle {
            width: parent.width
            height: 400
            radius: 6
            color: FluTheme.dark ? "#1f1f1f" : "#f8f8f8"
            border.color: FluTheme.dark ? "#3a3a3a" : "#dfdfdf"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Row {
                    width: parent.width
                    spacing: 12

                    FluText {
                        text: qsTr("模板匹配")
                        font.pixelSize: 12
                        font.bold: true
                    }

                    FluButton {
                        text: qsTr("拍摄模板")
                        enabled: cameraActive
                        onClicked: {
                            if (!cameraActive) {
                                cameraCard.infoRequested(qsTr("请先连接并打开摄像头"))
                                return
                            }
                            var ok = openCvPreviewManager.captureTemplate(cameraRole, selectedTemplatePoints())
                            if (ok) {
                                templateStatus = qsTr("模板已更新")
                                templateMatchVisible = false
                                cameraCard.infoRequested(qsTr("已使用四点框区域拍摄模板"))
                            } else {
                                templateStatus = qsTr("模板拍摄失败")
                                cameraCard.infoRequested(qsTr("模板拍摄失败"))
                            }
                        }
                    }

                    FluButton {
                        text: qsTr("执行匹配")
                        enabled: cameraActive
                        onClicked: {
                            if (!cameraActive) {
                                cameraCard.infoRequested(qsTr("请先连接并打开摄像头"))
                                return
                            }
                            cameraCard.performTemplateMatch(false)
                        }
                    }

                    FluCheckBox {
                        text: qsTr("连续匹配")
                        checked: continuousMatchingEnabled
                        onCheckedChanged: continuousMatchingEnabled = checked
                    }
                }

                FluText {
                    text: qsTr("状态: ") + templateStatus + qsTr("   分数: ") + templateMatchScore.toFixed(3)
                    font.pixelSize: 10
                    color: FluTheme.dark ? "#cfcfcf" : "#4d4d4d"
                }

                Row {
                    width: parent.width
                    spacing: 12
                    height: cameraCard.templatePreviewSide

                    // 固定大小背景框，防止内部动态尺寸预览影响右侧画面位置
                    Rectangle {
                        width: cameraCard.templatePreviewSide
                        height: cameraCard.templatePreviewSide
                        radius: 4
                        color: FluTheme.dark ? "#111111" : "#f0f0f0"
                        border.color: FluTheme.dark ? "#3a3a3a" : "#d9d9d9"
                        border.width: 1
                        clip: true

                        // 动态尺寸的模板预览，居中放置在固定背景框内
                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.max(4, matchRegionBox.width)
                            height: Math.max(4, matchRegionBox.height)
                            radius: 3
                            color: FluTheme.dark ? "#151515" : "#ffffff"
                            border.color: "#03a9f4"
                            border.width: 1

                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: cameraCard.templateReady ? templatePreviewSource : ""
                                fillMode: Image.Stretch
                                cache: false
                            }
                        }

                        FluText {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 4
                            anchors.bottomMargin: 2
                            text: qsTr("模板预览")
                            font.pixelSize: 9
                            color: FluTheme.dark ? "#bbbbbb" : "#666666"
                        }
                    }

                    Rectangle {
                        id: matchPreviewFrame
                        width: cameraCard.templatePreviewSide
                        height: cameraCard.templatePreviewSide
                        radius: 4
                        color: FluTheme.dark ? "#151515" : "#ffffff"
                        border.color: FluTheme.dark ? "#3a3a3a" : "#d9d9d9"
                        border.width: 1

                        property real normLeft: 0.2
                        property real normTop: 0.2
                        property real normBoxW: 0.6
                        property real normBoxH: 0.6
                        property bool userInteracting: false

                        function reflowBox() {
                            if (userInteracting) return
                            var rect = cameraCard.imageContentRect(matchPreviewImage)
                            matchRegionBox.x = rect.x + normLeft * rect.width
                            matchRegionBox.y = rect.y + normTop * rect.height
                            matchRegionBox.width = normBoxW * rect.width
                            matchRegionBox.height = normBoxH * rect.height
                        }

                        function saveNorm() {
                            var rect = cameraCard.imageContentRect(matchPreviewImage)
                            normLeft = cameraCard.clamp01((matchRegionBox.x - rect.x) / rect.width)
                            normTop = cameraCard.clamp01((matchRegionBox.y - rect.y) / rect.height)
                            normBoxW = cameraCard.clamp01(matchRegionBox.width / rect.width)
                            normBoxH = cameraCard.clamp01(matchRegionBox.height / rect.height)
                        }

                        Image {
                            id: matchPreviewImage
                            anchors.fill: parent
                            anchors.margins: 4
                            source: cameraCard.frameReady ? matchPreviewSource : ""
                            fillMode: Image.PreserveAspectFit
                            cache: false

                            onPaintedWidthChanged: matchPreviewFrame.reflowBox()
                            onPaintedHeightChanged: matchPreviewFrame.reflowBox()
                            onWidthChanged: matchPreviewFrame.reflowBox()
                            onHeightChanged: matchPreviewFrame.reflowBox()
                        }

                        Rectangle {
                            id: matchRegionBox
                            color: "transparent"
                            border.width: 2
                            border.color: "#03a9f4"
                            radius: 2

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                preventStealing: true
                                propagateComposedEvents: false
                                scrollGestureEnabled: false
                                cursorShape: Qt.OpenHandCursor
                                drag.target: parent
                                drag.axis: Drag.XAndYAxis
                                drag.minimumX: cameraCard.imageContentRect(matchPreviewImage).x
                                drag.minimumY: cameraCard.imageContentRect(matchPreviewImage).y
                                drag.maximumX: Math.max(cameraCard.imageContentRect(matchPreviewImage).x,
                                                        cameraCard.imageContentRect(matchPreviewImage).x + cameraCard.imageContentRect(matchPreviewImage).width - matchRegionBox.width)
                                drag.maximumY: Math.max(cameraCard.imageContentRect(matchPreviewImage).y,
                                                        cameraCard.imageContentRect(matchPreviewImage).y + cameraCard.imageContentRect(matchPreviewImage).height - matchRegionBox.height)
                                onPressed: (mouse) => {
                                    mouse.accepted = true
                                        matchPreviewFrame.userInteracting = true
                                    cursorShape = Qt.ClosedHandCursor
                                }
                                onReleased: {
                                    cursorShape = Qt.OpenHandCursor
                                    cameraCard.clampMatchRegionBox()
                                    matchPreviewFrame.saveNorm()
                                        matchPreviewFrame.userInteracting = false
                                }
                            }

                            Rectangle {
                                id: resizeHandle
                                width: 12
                                height: 12
                                radius: 2
                                color: "#03a9f4"
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton
                                    preventStealing: true
                                    propagateComposedEvents: false
                                    scrollGestureEnabled: false
                                    cursorShape: Qt.SizeFDiagCursor
                                    property real startMouseX: 0
                                    property real startMouseY: 0
                                    property real startW: 0
                                    property real startH: 0

                                    onPressed: (mouse) => {
                                        mouse.accepted = true
                                            matchPreviewFrame.userInteracting = true
                                        startMouseX = mouse.x
                                        startMouseY = mouse.y
                                        startW = matchRegionBox.width
                                        startH = matchRegionBox.height
                                    }

                                    onPositionChanged: (mouse) => {
                                        var rect = cameraCard.imageContentRect(matchPreviewImage)
                                        var dw = mouse.x - startMouseX
                                        var dh = mouse.y - startMouseY
                                        matchRegionBox.width = Math.max(0, Math.min(rect.x + rect.width - matchRegionBox.x, startW + dw))
                                        matchRegionBox.height = Math.max(0, Math.min(rect.y + rect.height - matchRegionBox.y, startH + dh))
                                        matchPreviewFrame.saveNorm()
                                    }

                                        onReleased: {
                                            cameraCard.clampMatchRegionBox()
                                            matchPreviewFrame.saveNorm()
                                            matchPreviewFrame.userInteracting = false
                                        }
                                }
                            }
                        }

                        FluText {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 6
                            anchors.bottomMargin: 4
                            text: qsTr("模板匹配预览(全图搜索/蓝框为模板区域)")
                            font.pixelSize: 10
                            color: FluTheme.dark ? "#bbbbbb" : "#666666"
                        }
                    }
                }
            }
        }
    }
}
