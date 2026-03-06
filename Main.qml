import QtQuick 6.2
import FluentUI

FluLauncher {
    id: app

    Component.onCompleted: {
        FluApp.init(app)
        // 只使用 FluentUI 的导航/标题栏，关闭系统默认栏以避免冲突
        FluApp.useSystemAppBar = false
        FluTheme.darkMode = FluThemeType.Light
        FluTheme.enableAnimation = true
        FluRouter.routes = {
            "/": "qrc:qt/qml/CubeX_PnP/QML/AppMainWindow.qml"
        }
        FluRouter.navigate("/")
    }
}

