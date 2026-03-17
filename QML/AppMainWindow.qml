import QtQuick 6.2
import QtQuick.Window 6.2
import QtMultimedia
import FluentUI
// import CubeX_PnP
FluWindow {
    id: mainWindow

    Component.onCompleted: {
        openCvPreviewManager.setTopCamera(topSharedCamera)
        openCvPreviewManager.setBottomCamera(bottomSharedCamera)
    }

    width: Screen.width *0.8
    height: Screen.height *0.8
    minimumWidth: Screen.width * 0.1
    minimumHeight: Screen.height * 0.1
    title: qsTr("CubeX_PnP")
    launchMode: FluWindowType.SingleInstance
    fitsAppBarWindows: true
    visible: true

    property point revealCenter: Qt.point(width / 2, height / 2)
    property bool revealingTheme: false
    property var homeTableData: []
    property int homeTablePageCurrent: 1
    property string homeNameKeyword: ""
    property string homeLayerKeyword: ""
    property bool homeRunPaused: true
    property int homeRunCurrentRow: -1
    property int homeRunLastMountedRow: -1
    property real homeMountedProgress: 0
    property var homeRunOrder: []
    property int homeRunOrderPos: -1
    property string serialSelectedComPort: ""
    property int serialSelectedBaudRate: 115200
    property var serialAvailableComPorts: []
    property string serialControllerConsoleText: ""
    property bool serialAutoReconnectEnabled: false
    property bool serialManualDisconnectRequested: false
    property bool serialReconnectAttemptInProgress: false
    property string serialReconnectTargetComPort: ""
    property int serialReconnectTargetBaudRate: 115200

    // 共享的摄像头资源
    readonly property MediaDevices sharedMediaDevices: MediaDevices { id: sharedMediaDevices }

    function normalizeHomeRow(rawRow, fallbackRowIndex) {
        var row = rawRow || {}
        var selected = row.selected
        if (selected === undefined) {
            selected = row.checkbox && row.checkbox.options && row.checkbox.options.checked
        }
        var mounted = row.mounted
        if (mounted !== true && mounted !== false) {
            mounted = row.mounted && row.mounted.options && row.mounted.options.checked
        }
        return {
            rowIndex: row.rowIndex || fallbackRowIndex,
            selected: !!selected,
            name: row.name || "",
            avatar: row.avatar || "",
            age: row.age || "0",
            address: row.address || "",
            nickname: row.nickname || "",
            longstring: row.longstring || "0",
            mounted: !!mounted,
            layer: row.layer || "",
            quantity: row.quantity || "0",
            component_name: row.component_name || "",
            _minimumHeight: row._minimumHeight || 50,
            _key: row._key || FluTools.uuid()
        }
    }

    function matchesHomeFilter(rowData, nameKeyword, layerKeyword) {
        var row = rowData || {}
        var nameFilter = nameKeyword !== undefined ? nameKeyword : homeNameKeyword
        var layerFilter = layerKeyword !== undefined ? layerKeyword : homeLayerKeyword
        var nameValue = row.name || ""
        var layerValue = row.layer || ""
        var nameMatch = nameFilter === "" || nameValue.indexOf(nameFilter) !== -1
        var layerMatch = layerFilter === "" || layerValue.indexOf(layerFilter) !== -1
        return nameMatch && layerMatch
    }

    function filteredHomeRowIndices(nameKeyword, layerKeyword) {
        var result = []
        for (var i = 0; i < homeTableData.length; i++) {
            if (matchesHomeFilter(homeTableData[i], nameKeyword, layerKeyword)) {
                result.push(i)
            }
        }
        return result
    }

    function visibleHomeRowPosition(rawRowIndex, nameKeyword, layerKeyword) {
        var visibleRows = filteredHomeRowIndices(nameKeyword, layerKeyword)
        for (var i = 0; i < visibleRows.length; i++) {
            if (visibleRows[i] === rawRowIndex) {
                return i
            }
        }
        return -1
    }

    function updateHomeMountedProgress() {
        var selectedCount = 0
        var mountedCount = 0
        var visibleRows = filteredHomeRowIndices()
        for (var i = 0; i < visibleRows.length; i++) {
            var row = homeTableData[visibleRows[i]]
            if (!row || !row.selected) {
                continue
            }
            selectedCount += 1
            if (row.mounted) {
                mountedCount += 1
            }
        }
        homeMountedProgress = selectedCount > 0 ? (mountedCount / selectedCount) : 0
    }

    function setHomeTableData(rows) {
        var normalized = []
        var sourceRows = rows || []
        for (var i = 0; i < sourceRows.length; i++) {
            normalized.push(normalizeHomeRow(sourceRows[i], i + 1))
        }
        homeTableData = normalized
        if (homeRunCurrentRow >= homeTableData.length) {
            homeRunCurrentRow = -1
            homeRunPaused = true
            smtWork.stop()
        }
        updateHomeMountedProgress()
    }

    function replaceHomeRow(rowIndex, rowData) {
        if (rowIndex < 0 || rowIndex >= homeTableData.length) {
            return
        }
        var rows = homeTableData.slice()
        rows[rowIndex] = normalizeHomeRow(rowData, rowIndex + 1)
        homeTableData = rows
        updateHomeMountedProgress()
    }

    function isHomeRowSelected(rowIndex) {
        return rowIndex >= 0 && rowIndex < homeTableData.length && matchesHomeFilter(homeTableData[rowIndex]) && !!homeTableData[rowIndex].selected
    }

    function findNextSelectedHomeRow(startIndex) {
        for (var i = Math.max(0, startIndex); i < homeTableData.length; i++) {
            if (isHomeRowSelected(i)) {
                return i
            }
        }
        return -1
    }

    function buildHomeRunOrder(rawIndexList) {
        var source = rawIndexList && rawIndexList.length !== undefined ? rawIndexList : filteredHomeRowIndices()
        var order = []
        for (var i = 0; i < source.length; i++) {
            var rowIndex = Number(source[i])
            if (!isFinite(rowIndex) || rowIndex < 0 || rowIndex >= homeTableData.length) {
                continue
            }
            if (isHomeRowSelected(rowIndex)) {
                order.push(rowIndex)
            }
        }
        return order
    }

    function setHomeRunOrder(rawIndexList) {
        homeRunOrder = buildHomeRunOrder(rawIndexList)
        homeRunOrderPos = -1
    }

    function indexOfInHomeRunOrder(rowIndex) {
        for (var i = 0; i < homeRunOrder.length; i++) {
            if (homeRunOrder[i] === rowIndex) {
                return i
            }
        }
        return -1
    }

    function ensureHomeRunOrder(rawIndexList) {
        if (rawIndexList && rawIndexList.length !== undefined) {
            setHomeRunOrder(rawIndexList)
            return
        }
        if (!homeRunOrder || homeRunOrder.length <= 0) {
            setHomeRunOrder(filteredHomeRowIndices())
        }
    }

    function buildHomeRowCommand(rowData) {
        if (!rowData) {
            return ""
        }
        return JSON.stringify({
            rowIndex: rowData.rowIndex,
            name: rowData.name,
            component: rowData.component_name,
            x: rowData.address,
            y: rowData.nickname,
            rotation: rowData.longstring,
            layer: rowData.layer,
            quantity: rowData.quantity
        })
    }

    function sendHomeSelectedRowsToController() {
        if (!serialPortManager || !serialPortManager.connected) {
            return false
        }
        var sentCount = 0
        var visibleRows = filteredHomeRowIndices()
        for (var i = 0; i < visibleRows.length; i++) {
            var rowIndex = visibleRows[i]
            if (!isHomeRowSelected(rowIndex)) {
                continue
            }
            var cmd = buildHomeRowCommand(homeTableData[rowIndex])
            if (cmd !== "" && serialPortManager.sendWithConsole(cmd)) {
                sentCount += 1
            }
        }
        return sentCount > 0
    }

    function dispatchHomeWorkRow(rowIndex) {
        if (rowIndex < 0 || rowIndex >= homeTableData.length) {
            return false
        }
        var rowData = homeTableData[rowIndex]
        var cmd = buildHomeRowCommand(rowData)
        var label = "[WORK] row=" + rowIndex + " ref=" + rowData.name

        if (!serialPortManager) {
            return false
        }

        if (!serialPortManager.connected) {
            console.log(label + " [跳过: 串口未连接]")
            return false
        }

        var ok = serialPortManager.sendWithConsole(cmd)
        console.log(label + (ok ? " [已发送]" : " [发送失败]"))
        return ok
    }

    function startHomeRun(rawIndexList) {
        if (homeTableData.length <= 0) {
            return false
        }

        ensureHomeRunOrder(rawIndexList)
        if (!homeRunOrder || homeRunOrder.length <= 0) {
            return false
        }

        if (homeRunCurrentRow >= 0 && homeRunCurrentRow < homeTableData.length && isHomeRowSelected(homeRunCurrentRow)) {
            var currentPos = indexOfInHomeRunOrder(homeRunCurrentRow)
            if (currentPos >= 0) {
                homeRunOrderPos = currentPos
                homeRunPaused = false
                dispatchHomeWorkRow(homeRunCurrentRow)
                smtWork.start()
                return true
            }
        }

        homeRunPaused = false
        homeRunOrderPos = 0
        homeRunCurrentRow = homeRunOrder[homeRunOrderPos]
        dispatchHomeWorkRow(homeRunCurrentRow)
        smtWork.start()
        return true
    }

    function pauseHomeRun() {
        homeRunPaused = true
        smtWork.pause()
    }

    function clearHomeMountedStates() {
        if (!homeTableData || homeTableData.length <= 0) {
            homeMountedProgress = 0
            homeRunLastMountedRow = -1
            return
        }

        var rows = homeTableData.slice()
        for (var i = 0; i < rows.length; i++) {
            var item = normalizeHomeRow(rows[i], i + 1)
            item.mounted = false
            rows[i] = item
        }
        homeTableData = rows
        homeMountedProgress = 0
        homeRunLastMountedRow = -1
    }

    function stopHomeRun(clearMounted) {
        homeRunPaused = true
        homeRunCurrentRow = -1
        homeRunOrderPos = -1
        if (clearMounted === true) {
            clearHomeMountedStates()
        }
        smtWork.stop()
    }

    function stepHomeRun(rawIndexList) {
        ensureHomeRunOrder(rawIndexList)
        if (!homeRunOrder || homeRunOrder.length <= 0) {
            return false
        }

        if (homeRunCurrentRow < 0) {
            homeRunPaused = true
            homeRunOrderPos = 0
            homeRunCurrentRow = homeRunOrder[homeRunOrderPos]
            dispatchHomeWorkRow(homeRunCurrentRow)
            return true
        }
        advanceHomeRun()
        return true
    }

    function advanceHomeRun() {
        if (homeTableData.length <= 0 || homeRunCurrentRow < 0 || homeRunCurrentRow >= homeTableData.length) {
            return
        }
        var rows = homeTableData.slice()
        var previous = normalizeHomeRow(rows[homeRunCurrentRow], homeRunCurrentRow + 1)
        previous.mounted = true
        rows[homeRunCurrentRow] = previous
        homeRunLastMountedRow = homeRunCurrentRow
        homeTableData = rows
        updateHomeMountedProgress()

        var currentPos = indexOfInHomeRunOrder(homeRunCurrentRow)
        if (currentPos < 0) {
            stopHomeRun()
            return
        }

        var nextPos = currentPos + 1
        if (nextPos >= homeRunOrder.length) {
            stopHomeRun()
            return
        }

        homeRunOrderPos = nextPos
        homeRunCurrentRow = homeRunOrder[homeRunOrderPos]
        dispatchHomeWorkRow(homeRunCurrentRow)
    }
    
    function getTopCameraDevice() {
        if (cameraDeviceManager.topCameraIndex >= 0 && cameraDeviceManager.topCameraIndex < sharedMediaDevices.videoInputs.length) {
            return sharedMediaDevices.videoInputs[cameraDeviceManager.topCameraIndex]
        }
        return sharedMediaDevices.defaultVideoInput
    }
    
    function getBottomCameraDevice() {
        if (cameraDeviceManager.bottomCameraIndex >= 0 && cameraDeviceManager.bottomCameraIndex < sharedMediaDevices.videoInputs.length) {
            return sharedMediaDevices.videoInputs[cameraDeviceManager.bottomCameraIndex]
        }
        return sharedMediaDevices.defaultVideoInput
    }
    
    // 共享的Camera对象（各页面可引用）
    readonly property Camera topSharedCamera: Camera {
        id: topSharedCamera
        cameraDevice: getTopCameraDevice()
        active: cameraDeviceManager.topCameraOpened
    }
    readonly property Camera bottomSharedCamera: Camera {
        id: bottomSharedCamera
        cameraDevice: getBottomCameraDevice()
        active: cameraDeviceManager.bottomCameraOpened
    }
    
    Connections {
        target: cameraDeviceManager
        function onTopCameraIndexChanged() {
            topSharedCamera.cameraDevice = getTopCameraDevice()
        }
        function onBottomCameraIndexChanged() {
            bottomSharedCamera.cameraDevice = getBottomCameraDevice()
        }
    }

    Connections {
        target: smtWork
        function onTick() {
            mainWindow.advanceHomeRun()
        }
    }

    function distance(x1, y1, x2, y2) {
        return Math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2))
    }

    function toggleTheme(button) {
        var target = mainWindow.containerItem ? mainWindow.containerItem() : mainWindow
        if (target && button) {
            var pos = button.mapToItem(target, button.width / 2, button.height / 2)
            revealCenter = Qt.point(pos.x, pos.y)
        } else if (target) {
            revealCenter = Qt.point(target.width / 2, target.height / 2)
        }
        startReveal(target)
    }

    function startReveal(target) {
        if (!target) {
            FluTheme.darkMode = FluTheme.dark ? FluThemeType.Light : FluThemeType.Dark
            return
        }

        revealingTheme = true
        if (FluTheme.dark) {
            revealCanvas.overlayColor =     Qt.rgba(1, 1, 1, 1)
            revealCanvas.overlayColorEnd =  Qt.rgba(0, 0, 0, 1)
        } else {
            revealCanvas.overlayColor =     Qt.rgba(0, 0, 0, 1)
            revealCanvas.overlayColorEnd =  Qt.rgba(1, 1, 1, 1)
        }

        revealCanvas.radius = 0

        var radius = Math.max(
                    distance(revealCenter.x, revealCenter.y, 0, 0),
                    distance(revealCenter.x, revealCenter.y, target.width, 0),
                    distance(revealCenter.x, revealCenter.y, 0, target.height),
                    distance(revealCenter.x, revealCenter.y, target.width, target.height))

        revealAnim.radiusAnimation.from = 0
        revealAnim.radiusAnimation.to = radius
        // 先启动动画，动画中途切换主题
        revealAnim.restart()
    }

    appBar: FluAppBar {
        id: appBar
        title: qsTr("CubeXPnP")
        showDark: true
        darkClickListener: (button) => handleDarkChanged(button)
    }

    FluObject {
        id: navItems

        FluPaneItem {
            title: qsTr("首页")
            icon: FluentIcons.Home
            url: "qrc:qt/qml/CubeX_PnP/QML/page/HomePage.qml"
            onTap: nav_view.push(url)
        }

        FluPaneItem {
            title: qsTr("设备连接")
            icon: FluentIcons.Connect
            url: "qrc:qt/qml/CubeX_PnP/QML/page/DeviceConnectionPage.qml"
            onTap: nav_view.push(url)
        }

        FluPaneItem {
            title: qsTr("设置")
            icon: FluentIcons.Settings
            url: "qrc:qt/qml/CubeX_PnP/QML/page/SettingsPage.qml"
            onTap: nav_view.push(url)
        }
    }

    FluNavigationView {
        id: nav_view
        anchors.fill: parent
        anchors.topMargin: appBar ? appBar.height : 0  // 避免与顶部 AppBar/返回箭头重叠
        items: navItems
        displayMode: FluNavigationViewType.Auto
        pageMode: FluNavigationViewType.NoStack
        title: qsTr("导航")
        // cellWidth: navPaneWidth //添加此行以进行调节
        Component.onCompleted: setCurrentIndex(0)
    }

    property int navPaneWidth: 250  // 导航面板默认宽度
    property int minNavPaneWidth: 150  // 最小宽度
    property int maxNavPaneWidth: 400  // 最大宽度

    // // 拖动分隔条
    // Rectangle {
    //     id: resizeHandle
    //     width: 6
    //     height: parent.height
    //     anchors.top: parent.top
    //     anchors.topMargin: appBar ? appBar.height : 0
    //     x: navPaneWidth - width / 2
    //     color: "transparent"
    //     z: 999

    //     Rectangle {
    //         anchors.centerIn: parent
    //         width: 2
    //         height: parent.height
    //         color: handleMouseArea.containsMouse || handleMouseArea.pressed ? 
    //                FluTheme.primaryColor : "transparent"
    //         opacity: 0.6
    //     }

    //     MouseArea {
    //         id: handleMouseArea
    //         anchors.fill: parent
    //         cursorShape: Qt.SizeHorCursor
    //         hoverEnabled: true
            
    //         property real startX: 0
    //         property int startWidth: 0

    //         onPressed: (mouse) => {
    //             startX = mouse.x
    //             startWidth = navPaneWidth
    //         }

    //         onPositionChanged: (mouse) => {
    //             if (pressed) {
    //                 var newWidth = startWidth + (mouseX - startX)
    //                 navPaneWidth = Math.max(minNavPaneWidth, Math.min(maxNavPaneWidth, newWidth))
    //             }
    //         }
    //     }
    // }
    Component{
        id: com_reveal
        CircularReveal{
            id: reveal
            target: mainWindow.containerItem()
            anchors.fill: parent
            darkToLight: FluTheme.dark
            onAnimationFinished:{
                //动画结束后释放资源
                loader_reveal.sourceComponent = undefined
            }
            onImageChanged: {
                changeDark()
            }
        }
    }

    FluLoader{
        id:loader_reveal
        anchors.fill: parent
    }


    function handleDarkChanged(button){
        if(FluTools.isMacos() || !FluTheme.animationEnabled){
            changeDark()
        }else{
            loader_reveal.sourceComponent = com_reveal
            var target = mainWindow.containerItem()
            var pos = button.mapToItem(target,0,0)
            var mouseX = pos.x + button.width / 2
            var mouseY = pos.y + button.height / 2
            var radius = Math.max(distance(mouseX,mouseY,0,0),distance(mouseX,mouseY,target.width,0),distance(mouseX,mouseY,0,target.height),distance(mouseX,mouseY,target.width,target.height))
            var reveal = loader_reveal.item
            reveal.start(reveal.width*Screen.devicePixelRatio,reveal.height*Screen.devicePixelRatio,Qt.point(mouseX,mouseY),radius)
        }
    }

    function changeDark(){
        if(FluTheme.dark){
            FluTheme.darkMode = FluThemeType.Light
        }else{
            FluTheme.darkMode = FluThemeType.Dark
        }
    }
    // Canvas {
    //     id: revealCanvas
    //     anchors.fill: parent
    //     visible: revealingTheme
    //     renderTarget: Canvas.FramebufferObject
    //     property real radius: 0
    //     property color overlayColor: Qt.rgba(0, 0, 0, 1)
    //     property color overlayColorEnd: Qt.rgba(0, 0, 0, 0)

    //     onRadiusChanged: requestPaint()

    //     onPaint: {
    //         var ctx = getContext("2d")
    //         ctx.clearRect(0, 0, width, height)
    //         var g = ctx.createRadialGradient(revealCenter.x, revealCenter.y, 0,
    //                                          revealCenter.x, revealCenter.y, radius)
    //         g.addColorStop(0, overlayColor)
    //         g.addColorStop(1, overlayColorEnd)
    //         ctx.fillStyle = g
    //         ctx.fillRect(0, 0, width, height)
    //     }
    // }

    // SequentialAnimation {
    //     id: revealAnim
    //     property alias radiusAnimation: radiusAnim

    //     ParallelAnimation {
    //         NumberAnimation {
    //             id: radiusAnim
    //             target: revealCanvas
    //             property: "radius"
    //             duration: 400
    //             easing.type: Easing.OutCubic
    //         }
    //         SequentialAnimation {
    //             PauseAnimation { duration: 400 }  // 动画进行到一半时切换主题
    //             ScriptAction {
    //                 script: FluTheme.darkMode = FluTheme.dark ? FluThemeType.Light : FluThemeType.Dark
    //             }
    //         }
    //     }
    //     ScriptAction {
    //         script: revealingTheme = false
    //     }
    // }
}
