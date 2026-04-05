import QtQuick
import QtQuick.Layouts
import FluentUI

QtObject {
    id: control

    property var tableView
    property var rootPage
    property var popFilter
    property var popFilterLayer
    property var customUpdateDialog

    property Component com_checbox: Component {
        Item {
            FluCheckBox {
                anchors.centerIn: parent
                checked: true === options.checked
                animationEnabled: false
                clickListener: function() {
                    var obj = control.tableView.getRow(row)
                    obj.checkbox = control.tableView.customItem(control.com_checbox, {checked: checked})
                    control.tableView.setRow(row, obj)
                    control.rootPage.persistHomeTableData()
                    control.rootPage.checkBoxChanged()
                }
            }
        }
    }

    property Component com_mounted_checkbox: Component {
        Item {
            FluCheckBox {
                anchors.centerIn: parent
                checked: true === options.checked
                animationEnabled: false
                clickListener: function() {
                    var obj = control.tableView.getRow(row)
                    obj.mounted = control.tableView.customItem(control.com_mounted_checkbox, {checked: checked})
                    control.tableView.setRow(row, obj)
                    control.rootPage.persistHomeTableData()
                }
            }
        }
    }

    property Component com_column_filter_name: Component {
        Item {
            FluText {
                text: qsTr("名称")
                anchors.centerIn: parent
            }
            FluIconButton {
                width: 20
                height: 20
                iconSize: 12
                verticalPadding: 0
                horizontalPadding: 0
                iconSource: FluentIcons.Filter
                iconColor: {
                    if ("" !== control.rootPage.nameKeyword) {
                        return FluTheme.primaryColor
                    }
                    return FluTheme.dark ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1)
                }
                anchors {
                    right: parent.right
                    rightMargin: 3
                    verticalCenter: parent.verticalCenter
                }
                onClicked: {
                    control.popFilter.showPopup()
                }
            }
        }
    }

    property Component com_column_filter_layer: Component {
        Item {
            FluText {
                text: qsTr("板层")
                anchors.centerIn: parent
            }
            FluIconButton {
                width: 20
                height: 20
                iconSize: 12
                verticalPadding: 0
                horizontalPadding: 0
                iconSource: FluentIcons.Filter
                iconColor: {
                    if ("" !== control.rootPage.layerKeyword) {
                        return FluTheme.primaryColor
                    }
                    return FluTheme.dark ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1)
                }
                anchors {
                    right: parent.right
                    rightMargin: 3
                    verticalCenter: parent.verticalCenter
                }
                onClicked: {
                    control.popFilterLayer.showPopup()
                }
            }
        }
    }

    property Component com_action: Component {
        Item {
            RowLayout {
                anchors.centerIn: parent
                FluButton {
                    text: qsTr("删除")
                    onClicked: {
                        control.tableView.closeEditor()
                        control.tableView.removeRow(row)
                        control.rootPage.persistHomeTableData()
                    }
                }
                FluFilledButton {
                    text: qsTr("编辑")
                    onClicked: {
                        var obj = control.tableView.getRow(row)
                        obj.name = "12345"
                        control.tableView.setRow(row, obj)
                        control.rootPage.persistHomeTableData()
                        control.rootPage.showSuccess(JSON.stringify(obj))
                    }
                }
            }
        }
    }

    property Component com_column_checbox: Component {
        Item {
            RowLayout {
                anchors.centerIn: parent
                FluText {
                    text: qsTr("选择")
                    Layout.alignment: Qt.AlignVCenter
                }
                FluCheckBox {
                    Layout.alignment: Qt.AlignVCenter
                    checkState: control.rootPage.allCheckState
                    animationEnabled: false
                    clickListener: function() {
                        control.rootPage.allCheckState = checkState
                        for (var i = 0; i < control.tableView.rows; i++) {
                            var rowData = control.tableView.getRow(i)
                            rowData.checkbox = control.tableView.customItem(control.com_checbox, {"checked": checkState === Qt.Checked})
                            control.tableView.setRow(i, rowData)
                        }
                        control.rootPage.persistHomeTableData()
                    }
                }
            }
        }
    }

    property Component com_combobox: Component {
        FluComboBox {
            anchors.fill: parent
            focus: true
            editText: display
            editable: true
            model: ListModel {
                ListElement { text: "100" }
                ListElement { text: "300" }
                ListElement { text: "500" }
                ListElement { text: "1000" }
            }
            Component.onCompleted: {
                currentIndex = ["100", "300", "500", "1000"].findIndex((element) => element === display)
                textBox.forceActiveFocus()
                textBox.selectAll()
            }
            onCommit: {
                editTextChaged(editText)
                tableView.closeEditor()
            }
        }
    }

    property Component com_auto_suggestbox: Component {
        FluAutoSuggestBox {
            id: textbox
            anchors.fill: parent
            focus: true
            Component.onCompleted: {
                var data = ["傲来国界花果山水帘洞", "傲来国界坎源山脏水洞", "大唐国界黑风山黑风洞", "大唐国界黄风岭黄风洞", "大唐国界骷髅山白骨洞", "宝象国界碗子山波月洞", "宝象国界平顶山莲花洞", "宝象国界压龙山压龙洞", "乌鸡国界号山枯松涧火云洞", "乌鸡国界衡阳峪黑水河河神府"]
                var result = data.map(function(item) {
                    return {title: item}
                })
                items = result
                textbox.text = String(display)
                forceActiveFocus()
                selectAll()
            }
            onCommit: {
                editTextChaged(textbox.text)
                tableView.closeEditor()
            }
        }
    }

    property Component com_avatar: Component {
        Item {
            FluClip {
                anchors.centerIn: parent
                width: 40
                height: 40
                radius: [20, 20, 20, 20]
                Image {
                    anchors.fill: parent
                    source: options && options.avatar ? options.avatar : ""
                    sourceSize: Qt.size(80, 80)
                }
            }
        }
    }

    property Component com_column_update_title: Component {
        Item {
            FluText {
                id: text_title
                text: {
                    if (options.title) {
                        return options.title
                    }
                    return ""
                }
                anchors.fill: parent
                verticalAlignment: Qt.AlignVCenter
                horizontalAlignment: Qt.AlignHCenter
                elide: Text.ElideRight
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    control.customUpdateDialog.showDialog(options.title, function(text) {
                        var columnModel = model.display
                        columnModel.title = control.tableView.customItem(control.com_column_update_title, {"title": text})
                        model.display = columnModel
                    })
                }
            }
        }
    }

    property Component com_column_sort_age: Component {
        Item {
            FluText {
                text: qsTr("数量")
                anchors.centerIn: parent
            }
            ColumnLayout {
                spacing: 0
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 4
                }
                FluIconButton {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 15
                    iconSize: 12
                    verticalPadding: 0
                    horizontalPadding: 0
                    iconSource: FluentIcons.ChevronUp
                    iconColor: {
                        if (1 === control.rootPage.sortType) {
                            return FluTheme.primaryColor
                        }
                        return FluTheme.dark ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1)
                    }
                    onClicked: {
                        if (control.rootPage.sortType === 1) {
                            control.rootPage.sortType = 0
                            return
                        }
                        control.rootPage.sortType = 1
                    }
                }
                FluIconButton {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 15
                    iconSize: 12
                    verticalPadding: 0
                    horizontalPadding: 0
                    iconSource: FluentIcons.ChevronDown
                    iconColor: {
                        if (2 === control.rootPage.sortType) {
                            return FluTheme.primaryColor
                        }
                        return FluTheme.dark ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1)
                    }
                    onClicked: {
                        if (control.rootPage.sortType === 2) {
                            control.rootPage.sortType = 0
                            return
                        }
                        control.rootPage.sortType = 2
                    }
                }
            }
        }
    }
}
