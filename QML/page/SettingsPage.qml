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
        spacing: 16

        FluText {
            text: qsTr("快速设置")
            font: FluTextStyle.TitleLarge
        }

        // 深色模式开关
        FluToggleSwitch {
            id: themeToggle
            text: qsTr("深色模式")
            checked: FluTheme.dark
            Layout.alignment: Qt.AlignLeft
            Component.onCompleted: {
                console.log("[SettingsPage] Theme toggle initialized with dark mode:", checked)
            }
            onClicked: {
                var mode = checked ? FluThemeType.Dark : FluThemeType.Light
                FluTheme.darkMode = mode
                // Save dark mode setting
                if (settingsHelper) {
                    var darkModeValue = checked ? 1 : 0
                    settingsHelper.saveDarkMode(darkModeValue)
                    console.log("[SettingsPage] Saved dark mode setting:", darkModeValue)
                } else {
                    console.warn("[SettingsPage] settingsHelper not available")
                }
                console.log("[SettingsPage] Dark mode changed to:", checked)
            }
            
            Connections {
                target: FluTheme
                function onDarkChanged() {
                    themeToggle.checked = FluTheme.dark
                }
            }
        }

        Item { height: 1 }  // 分隔符

        FluText {
            text: qsTr("语言设置")
            font: FluTextStyle.TitleLarge
        }

        // 语言选择
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft
            spacing: 12

            FluText {
                text: qsTr("应用语言:")
                Layout.alignment: Qt.AlignVCenter
            }

            FluComboBox {
                id: languageCombo
                Layout.preferredWidth: 200
                model: ["zh_CN", "en_US"]
                
                property bool isInitializing: true
                
                Component.onCompleted: {
                    console.log("[SettingsPage] Language ComboBox initialized, current lang:", transHelper.current)
                    // Set the index without triggering language switch
                    if (transHelper.current === "zh_CN") {
                        currentIndex = 0
                    } else {
                        currentIndex = 1
                    }
                    isInitializing = false
                    console.log("[SettingsPage] ComboBox index set to:", currentIndex, "for language:", transHelper.current)
                }
                
                Connections {
                    target: transHelper
                    function onCurrentChanged() {
                        console.log("[SettingsPage] Language changed externally to:", transHelper.current)
                        // Update display without triggering switch
                        if (transHelper.current === "zh_CN") {
                            languageCombo.currentIndex = 0
                        } else {
                            languageCombo.currentIndex = 1
                        }
                    }
                }
                
                displayText: currentIndex === 0 ? "中文 (Chinese)" : "English (英文)"
                
                onCurrentIndexChanged: {
                    // Only switch language if user manually changed it, not during initialization
                    if (isInitializing) {
                        return
                    }
                    console.log("[SettingsPage] ComboBox index changed to:", currentIndex)
                    var selectedLang = currentIndex === 0 ? "zh_CN" : "en_US"
                    if (selectedLang !== transHelper.current) {
                        console.log("[SettingsPage] Switching language to:", selectedLang)
                        transHelper.switchLanguage(selectedLang)
                        // Save language setting
                        if (settingsHelper) {
                            settingsHelper.saveLanguage(selectedLang)
                            console.log("[SettingsPage] Saved language setting:", selectedLang)
                        }
                    }
                }
            }
        }

        FluText {
            text: qsTr("选择应用的界面语言，改变后立即生效。")
            wrapMode: Text.Wrap
            color: FluColors.Grey120
            Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true }  // 填充空间
    }
}

