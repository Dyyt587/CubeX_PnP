import QtQuick 6.2
import QtQuick.Layouts 6.2
import FluentUI

FluScrollablePage {
    id: page

    title: qsTr("设置")
    launchMode: FluPageType.SingleTask

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        FluText {
            text: qsTr("快速设置")
            font: FluTextStyle.TitleLarge
        }

        FluToggleSwitch {
            id: themeToggle
            text: qsTr("深色模式")
            checked: FluTheme.dark
            Layout.alignment: Qt.AlignLeft
            onClicked: FluTheme.darkMode = checked ? FluThemeType.Dark : FluThemeType.Light
        }

        FluText {
            text: qsTr("您可以在这里添加更多业务相关的配置项，当前仅演示主题切换。")
            wrapMode: Text.Wrap
            color: FluColors.Grey120
            Layout.fillWidth: true
        }
    }
}
