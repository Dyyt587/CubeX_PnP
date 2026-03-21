import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import FluentUI

Item {
    id: control

    property var rootPage
    property var tableView

    property alias customUpdateDialog: custom_update_dialog
    property alias popFilter: pop_filter
    property alias popFilterLayer: pop_filter_layer

    function openImportDialog() {
        fileImportDialog.open()
    }

    function openImportGerberDialog() {
        importGerberDialog.open()
    }

    FileDialog {
        id: fileImportDialog
        title: qsTr("选择要导入的文件")
        nameFilters: [qsTr("CSV 文件 (*.csv)"), qsTr("所有文件 (*)")]
        onAccepted: {
            control.rootPage.importFile(selectedFile)
        }
    }

    FluContentDialog {
        id: custom_update_dialog
        property var text
        property var onAccpetListener
        title: qsTr("Modify the column name")
        negativeText: qsTr("Cancel")
        contentDelegate: Component {
            Item {
                implicitWidth: parent.width
                implicitHeight: 60
                FluTextBox {
                    id: textbox_text
                    anchors.centerIn: parent
                    onTextChanged: {
                        custom_update_dialog.text = textbox_text.text
                    }
                }
                Component.onCompleted: {
                    textbox_text.text = custom_update_dialog.text
                    textbox_text.forceActiveFocus()
                }
            }
        }
        positiveText: qsTr("OK")
        onPositiveClicked: {
            if (custom_update_dialog.onAccpetListener) {
                custom_update_dialog.onAccpetListener(custom_update_dialog.text)
            }
        }
        function showDialog(text, listener) {
            custom_update_dialog.text = text
            custom_update_dialog.onAccpetListener = listener
            custom_update_dialog.open()
        }
    }

    FluMenu {
        id: pop_filter
        width: 200
        height: 89

        contentItem: Item {
            onVisibleChanged: {
                if (visible) {
                    name_filter_text.text = control.rootPage.nameKeyword
                    name_filter_text.cursorPosition = name_filter_text.text.length
                    name_filter_text.forceActiveFocus()
                }
            }

            FluTextBox {
                id: name_filter_text
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: 10
                    rightMargin: 10
                    topMargin: 10
                }
                iconSource: FluentIcons.Search
            }

            FluButton {
                text: qsTr("Search")
                anchors {
                    bottom: parent.bottom
                    right: parent.right
                    bottomMargin: 10
                    rightMargin: 10
                }
                onClicked: {
                    control.rootPage.nameKeyword = name_filter_text.text
                    pop_filter.close()
                }
            }
        }

        function showPopup() {
            control.tableView.closeEditor()
            pop_filter.popup()
        }
    }

    FluMenu {
        id: pop_filter_layer
        width: 200
        height: 89

        contentItem: Item {
            onVisibleChanged: {
                if (visible) {
                    layer_filter_text.text = control.rootPage.layerKeyword
                    layer_filter_text.cursorPosition = layer_filter_text.text.length
                    layer_filter_text.forceActiveFocus()
                }
            }

            FluTextBox {
                id: layer_filter_text
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: 10
                    rightMargin: 10
                    topMargin: 10
                }
                iconSource: FluentIcons.Search
            }

            FluButton {
                text: qsTr("Search")
                anchors {
                    bottom: parent.bottom
                    right: parent.right
                    bottomMargin: 10
                    rightMargin: 10
                }
                onClicked: {
                    control.rootPage.layerKeyword = layer_filter_text.text
                    pop_filter_layer.close()
                }
            }
        }

        function showPopup() {
            control.tableView.closeEditor()
            pop_filter_layer.popup()
        }
    }

    FileDialog {
        id: importGerberDialog
        title: qsTr("导入Gerber")
        nameFilters: [
            qsTr("Gerber/Zip (*.gbr *.gtl *.gbl *.gto *.gbo *.gts *.gbs *.gko *.zip)"),
            qsTr("All Files (*)")
        ]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            if (selectedFile && control.rootPage && control.rootPage.importGerberFile) {
                control.rootPage.importGerberFile(selectedFile)
            }
        }
    }
}
