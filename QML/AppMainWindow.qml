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

    // 共享的摄像头资源
    readonly property MediaDevices sharedMediaDevices: MediaDevices { id: sharedMediaDevices }
    
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
