import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import FluentUI 1.0

Item {
    id: control

    property real pageWidth: 0
    property real pageHeight: 0
    property int homePreviewRole: 0
    property var notify
    signal previewRoleChanged(int role)

    clip: true
    implicitWidth: pageWidth * 0.3
    implicitHeight: pageHeight
    SplitView.minimumWidth: 250
    SplitView.fillHeight: true

    FluFrame {
        anchors.fill: parent
        padding: 20

        ColumnLayout {
            anchors.fill: parent
            spacing: 20

            FluText {
                text: qsTr("运动控制")
                font: FluTextStyle.Title
            }

            // 主控制区域：左侧XY+Z轴，右侧速度和位置
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 15

                // 左侧：XY平面 + Z轴控制
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    spacing: 15

                    // XY平面控制 (3x3布局)
                    ColumnLayout {
                        spacing: 5

                        FluText {
                            text: qsTr("XY 平面")
                            font: FluTextStyle.Subtitle
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // 第一行：左上、上、右上
                        RowLayout {
                            spacing: 5
                            Layout.alignment: Qt.AlignHCenter

                            FluButton {
                                text: "↖"
                                font.pixelSize: 24
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 50
                                onClicked: if (control.notify) control.notify(qsTr("左上 (-X+Y)"))
                            }
                            FluButton {
                                text: "↑"
                                font.pixelSize: 24
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 50
                                onClicked: if (control.notify) control.notify(qsTr("上 (+Y)"))
                            }
                            FluButton {
                                text: "↗"
                                font.pixelSize: 24
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 50
                                onClicked: if (control.notify) control.notify(qsTr("右上 (+X+Y)"))
                            }
                        }

                        // 第二行：左、原点、右
                        RowLayout {
                            spacing: 5
                            Layout.alignment: Qt.AlignHCenter

                            FluButton {
                                text: "←"
                                font.pixelSize: 24
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 50
                                onClicked: if (control.notify) control.notify(qsTr("左 (-X)"))
                            }
                            FluIconButton {
                                iconSource: FluentIcons.Home
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 50
                                onClicked: if (control.notify) control.notify(qsTr("归零"))
                            }
                            FluButton {
                                text: "→"
                                font.pixelSize: 24
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 50
                                onClicked: if (control.notify) control.notify(qsTr("右 (+X)"))
                            }
                        }

                        // 第三行：左下、下、右下
                        RowLayout {
                            spacing: 5
                            Layout.alignment: Qt.AlignHCenter

                            FluButton {
                                text: "↙"
                                font.pixelSize: 24
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 50
                                onClicked: if (control.notify) control.notify(qsTr("左下 (-X-Y)"))
                            }
                            FluButton {
                                text: "↓"
                                font.pixelSize: 24
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 50
                                onClicked: if (control.notify) control.notify(qsTr("下 (-Y)"))
                            }
                            FluButton {
                                text: "↘"
                                font.pixelSize: 24
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 50
                                onClicked: if (control.notify) control.notify(qsTr("右下 (+X-Y)"))
                            }
                        }
                    }

                    // Z轴控制
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 20

                        // Z1轴控制
                        ColumnLayout {
                            spacing: 5

                            FluText {
                                text: qsTr("Z1 轴")
                                font: FluTextStyle.Subtitle
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // Z轴上下控制
                            RowLayout {
                                spacing: 5
                                Layout.alignment: Qt.AlignHCenter

                                FluButton {
                                    text: "↑"
                                    font.pixelSize: 20
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    onClicked: if (control.notify) control.notify(qsTr("Z1 上升 (+Z1)"))
                                }
                                FluButton {
                                    text: "↓"
                                    font.pixelSize: 20
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    onClicked: if (control.notify) control.notify(qsTr("Z1 下降 (-Z1)"))
                                }
                            }

                            // Z轴回零
                            FluIconButton {
                                iconSource: FluentIcons.Home
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                Layout.alignment: Qt.AlignHCenter
                                onClicked: if (control.notify) control.notify(qsTr("Z1 归零"))
                            }

                            FluText {
                                text: qsTr("R1 轴")
                                font: FluTextStyle.Caption
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // R轴旋转控制
                            RowLayout {
                                spacing: 5
                                Layout.alignment: Qt.AlignHCenter

                                FluButton {
                                    text: "↶"
                                    font.pixelSize: 20
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    onClicked: if (control.notify) control.notify(qsTr("R1 逆时针"))
                                }
                                FluButton {
                                    text: "↷"
                                    font.pixelSize: 20
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    onClicked: if (control.notify) control.notify(qsTr("R1 顺时针"))
                                }
                            }
                        }

                        // Z2轴控制
                        ColumnLayout {
                            spacing: 5

                            FluText {
                                text: qsTr("Z2 轴")
                                font: FluTextStyle.Subtitle
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // Z轴上下控制
                            RowLayout {
                                spacing: 5
                                Layout.alignment: Qt.AlignHCenter

                                FluButton {
                                    text: "↑"
                                    font.pixelSize: 20
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    onClicked: if (control.notify) control.notify(qsTr("Z2 上升 (+Z2)"))
                                }
                                FluButton {
                                    text: "↓"
                                    font.pixelSize: 20
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    onClicked: if (control.notify) control.notify(qsTr("Z2 下降 (-Z2)"))
                                }
                            }

                            // Z轴回零
                            FluIconButton {
                                iconSource: FluentIcons.Home
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                Layout.alignment: Qt.AlignHCenter
                                onClicked: if (control.notify) control.notify(qsTr("Z2 归零"))
                            }

                            FluText {
                                text: qsTr("R2 轴")
                                font: FluTextStyle.Caption
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // R轴旋转控制
                            RowLayout {
                                spacing: 5
                                Layout.alignment: Qt.AlignHCenter

                                FluButton {
                                    text: "↶"
                                    font.pixelSize: 20
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    onClicked: if (control.notify) control.notify(qsTr("R2 逆时针"))
                                }
                                FluButton {
                                    text: "↷"
                                    font.pixelSize: 20
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    onClicked: if (control.notify) control.notify(qsTr("R2 顺时针"))
                                }
                            }
                        }
                    }
                }

                // 右侧：速度滑条和坐标显示
                ColumnLayout {
                    spacing: 10
                    Layout.preferredWidth: 80
                    Layout.alignment: Qt.AlignTop

                    FluText {
                        text: qsTr("速度")
                        font: FluTextStyle.Caption
                        Layout.alignment: Qt.AlignHCenter
                    }

                    FluSlider {
                        id: speedSlider
                        Layout.preferredHeight: 250
                        Layout.preferredWidth: 50
                        Layout.alignment: Qt.AlignHCenter
                        orientation: Qt.Vertical
                        from: 0
                        to: 100
                        value: 50
                        stepSize: 10
                        snapMode: Slider.SnapAlways
                    }

                    FluText {
                        id: speedValue
                        text: speedSlider.value + "%"
                        font: FluTextStyle.BodyStrong
                        color: FluTheme.primaryColor
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: FluTheme.dividerColor
                        Layout.topMargin: 5
                        Layout.bottomMargin: 5
                    }

                    FluText {
                        text: qsTr("当前位置")
                        font: FluTextStyle.Caption
                        Layout.alignment: Qt.AlignHCenter
                    }

                    RowLayout {
                        spacing: 8
                        Layout.alignment: Qt.AlignHCenter

                        // XYZ列
                        ColumnLayout {
                            spacing: 3

                            FluText {
                                text: "X: 200.00mm"
                                font: FluTextStyle.Caption
                                Layout.alignment: Qt.AlignLeft
                            }
                            FluText {
                                text: "Y: 200.00mm"
                                font: FluTextStyle.Caption
                                Layout.alignment: Qt.AlignLeft
                            }
                            FluText {
                                text: "Z: 200.00mm"
                                font: FluTextStyle.Caption
                                Layout.alignment: Qt.AlignLeft
                            }
                        }

                        // 分割线
                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 50
                            color: FluTheme.dividerColor
                        }

                        // R1 R2列
                        ColumnLayout {
                            spacing: 3

                            FluText {
                                text: "R1: 0.00°"
                                font: FluTextStyle.Caption
                                Layout.alignment: Qt.AlignLeft
                            }
                            FluText {
                                text: "R2: 0.00°"
                                font: FluTextStyle.Caption
                                Layout.alignment: Qt.AlignLeft
                            }
                        }
                    }
                }
            }

            // 步进距离选择
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    FluText {
                        text: qsTr("移动距离:")
                        font: FluTextStyle.Body
                    }

                    FluText {
                        id: distanceValue
                        text: "10 mm"
                        font: FluTextStyle.BodyStrong
                        color: FluTheme.primaryColor
                    }
                }

                FluSlider {
                    id: distanceSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 3
                    stepSize: 1
                    value: 2
                    snapMode: Slider.SnapAlways

                    onValueChanged: {
                        var distances = [0.1, 1, 10, 50]
                        distanceValue.text = distances[value] + " mm"
                    }

                    Component.onCompleted: {
                        var distances = [0.1, 1, 10, 50]
                        distanceValue.text = distances[value] + " mm"
                    }
                }

                Row {
                    Layout.fillWidth: true
                    spacing: 0

                    FluText {
                        text: "0.1"
                        font: FluTextStyle.Caption
                        width: parent.width / 4
                        horizontalAlignment: Text.AlignLeft
                    }
                    FluText {
                        text: "1"
                        font: FluTextStyle.Caption
                        width: parent.width / 4
                        horizontalAlignment: Text.AlignHCenter
                    }
                    FluText {
                        text: "10"
                        font: FluTextStyle.Caption
                        width: parent.width / 4
                        horizontalAlignment: Text.AlignHCenter
                    }
                    FluText {
                        text: "50"
                        font: FluTextStyle.Caption
                        width: parent.width / 4
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // 摄像头预览区域
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                spacing: 10

                // 摄像头选择下拉框
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    FluText {
                        text: qsTr("摄像头:")
                        font: FluTextStyle.Body
                    }

                    FluComboBox {
                        Layout.fillWidth: true
                        model: [
                            qsTr("顶部黑白"),
                            qsTr("顶部彩色"),
                            qsTr("底部黑白"),
                            qsTr("底部彩色")
                        ]
                        enabled: true
                        currentIndex: control.homePreviewRole
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0) {
                                control.previewRoleChanged(currentIndex)
                            }
                        }
                    }
                }

                // 摄像头预览（单窗口，按下拉框切换）
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#000000"
                    border.color: FluTheme.dividerColor
                    border.width: 1
                    radius: 4
                    clip: true

                    readonly property bool previewOpened: (control.homePreviewRole === 0 && cameraDeviceManager.topCameraOpened)
                                                       || (control.homePreviewRole === 1 && cameraDeviceManager.topCameraOpened)
                                                       || (control.homePreviewRole === 2 && cameraDeviceManager.bottomCameraOpened)
                                                       || (control.homePreviewRole === 3 && cameraDeviceManager.bottomCameraOpened)
                    readonly property string bwSource: control.homePreviewRole < 2
                                                     ? ("image://opencvpreview/top?" + openCvPreviewManager.topFrameToken)
                                                     : ("image://opencvpreview/bottom?" + openCvPreviewManager.bottomFrameToken)
                    readonly property string colorSource: control.homePreviewRole < 2
                                                        ? ("image://opencvpreview/top_color?" + openCvPreviewManager.topFrameToken)
                                                        : ("image://opencvpreview/bottom_color?" + openCvPreviewManager.bottomFrameToken)
                    readonly property bool showColor: control.homePreviewRole === 1 || control.homePreviewRole === 3

                    Image {
                        anchors.fill: parent
                        visible: parent.previewOpened
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        source: parent.showColor ? parent.colorSource : parent.bwSource
                    }

                    DraggableFocusOverlay {
                        anchors.fill: parent
                        active: parent.previewOpened
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 8
                        anchors.bottomMargin: 6
                        visible: parent.previewOpened
                        radius: 4
                        color: FluTheme.dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(1, 1, 1, 0.55)
                        width: homeFpsText.implicitWidth + 10
                        height: homeFpsText.implicitHeight + 4

                        FluText {
                            id: homeFpsText
                            anchors.centerIn: parent
                            text: control.homePreviewRole < 2
                                  ? qsTr("%1 FPS").arg(openCvPreviewManager.topFps.toFixed(1))
                                  : qsTr("%1 FPS").arg(openCvPreviewManager.bottomFps.toFixed(1))
                            color: FluTheme.dark ? "#ffffff" : "#000000"
                            font: FluTextStyle.Caption
                        }
                    }

                    FluText {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 4
                        text: parent.showColor ? qsTr("彩色") : qsTr("黑白")
                        color: FluTheme.dark ? "#aaaaaa" : "#cccccc"
                        font: FluTextStyle.Caption
                        visible: parent.previewOpened
                    }

                    FluText {
                        anchors.centerIn: parent
                        text: cameraDeviceManager.cameraNames.length === 0
                              ? qsTr("未检测到摄像头")
                              : qsTr("摄像头未打开")
                        color: "#888888"
                        font: FluTextStyle.Body
                        visible: !parent.previewOpened
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
