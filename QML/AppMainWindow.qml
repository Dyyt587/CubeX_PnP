import QtQuick 2.15
import FluentUI

FluWindow {

    id: mainWindow

    // 避免双屏情景下的宽度溢出
    minimumWidth: Screen.width * 0.8
    minimumHeight: Screen.desktopAvailableHeight * 0.8
    visible: true
    title: "Helloworld"
    //appBar: undefined

}
