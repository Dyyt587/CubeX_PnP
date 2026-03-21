pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import QtCore
import FluentUI 1.0

FluContentPage {
    id: page
    title: qsTr("封装库")

    property string searchKeyword: ""

    function ok(text) {
        showSuccess(text)
    }

    function warn(text) {
        showWarning(text)
    }

    function normalizeRecord(record) {
        var row = record || {}
        return {
            pkg: String(row.pkg || row.package || row.name || "").trim(),
            size: String(row.size || row.dimension || row["封装大小(mm)"] || "").trim(),
            category: String(row.category || row.type || row["分类"] || "").trim(),
            note: String(row.note || row.remark || row["备注"] || "").trim()
        }
    }

    function modelToArray() {
        var list = []
        for (var i = 0; i < packageModel.count; i++) {
            var row = packageModel.get(i)
            list.push({
                pkg: String(row.pkg || ""),
                size: String(row.size || ""),
                category: String(row.category || ""),
                note: String(row.note || "")
            })
        }
        return list
    }

    function loadFromArray(list, appendMode) {
        if (!appendMode) {
            packageModel.clear()
        }
        var source = list || []
        for (var i = 0; i < source.length; i++) {
            var row = normalizeRecord(source[i])
            if (row.pkg === "") {
                continue
            }
            packageModel.append(row)
        }
    }

    function saveLibrary() {
        packageStore.dataJson = JSON.stringify(modelToArray())
        ok(qsTr("封装库已保存"))
    }

    function loadLibrary() {
        var text = packageStore.dataJson
        if (!text || text.trim() === "") {
            loadDefaults(false)
            return
        }
        try {
            var parsed = JSON.parse(text)
            if (parsed && parsed.length !== undefined) {
                loadFromArray(parsed, false)
                return
            }
        } catch (e) {
            warn(qsTr("封装库数据损坏，已恢复默认"))
        }
        loadDefaults(false)
    }

    function loadDefaults(saveAfter) {
        packageModel.clear()
        for (var i = 0; i < defaultData.length; i++) {
            packageModel.append(defaultData[i])
        }
        if (saveAfter) {
            packageStore.dataJson = JSON.stringify(modelToArray())
        }
    }

    function openEditor(index) {
        if (index >= 0 && index < packageModel.count) {
            var row = packageModel.get(index)
            editorDialog.editIndex = index
            editorDialog.pkg = row.pkg
            editorDialog.size = row.size
            editorDialog.category = row.category
            editorDialog.note = row.note
        } else {
            editorDialog.editIndex = -1
            editorDialog.pkg = ""
            editorDialog.size = ""
            editorDialog.category = ""
            editorDialog.note = ""
        }
        editorDialog.open()
    }

    function saveEditorRecord() {
        var row = normalizeRecord({
            pkg: editorDialog.pkg,
            size: editorDialog.size,
            category: editorDialog.category,
            note: editorDialog.note
        })
        if (row.pkg === "") {
            warn(qsTr("封装名称不能为空"))
            return
        }
        if (editorDialog.editIndex >= 0 && editorDialog.editIndex < packageModel.count) {
            packageModel.set(editorDialog.editIndex, row)
        } else {
            packageModel.append(row)
        }
        packageStore.dataJson = JSON.stringify(modelToArray())
        ok(qsTr("已保存封装记录"))
    }

    function removeRecord(index) {
        if (index < 0 || index >= packageModel.count) {
            return
        }
        packageModel.remove(index)
        packageStore.dataJson = JSON.stringify(modelToArray())
        ok(qsTr("已删除封装记录"))
    }

    function importCsv(path) {
        var rows = csvFileReader.readCsvFile(path)
        if (!rows || rows.length === undefined || rows.length === 0) {
            var err = csvFileReader.getLastError()
            warn(err && err !== "" ? err : qsTr("CSV 导入失败"))
            return
        }
        var mapped = []
        for (var i = 0; i < rows.length; i++) {
            var r = rows[i]
            mapped.push(normalizeRecord({
                pkg: r.pkg || r.package || r.name || r["封装名称"],
                size: r.size || r.dimension || r["封装大小(mm)"],
                category: r.category || r.type || r["分类"],
                note: r.note || r.remark || r["备注"]
            }))
        }
        loadFromArray(mapped, true)
        packageStore.dataJson = JSON.stringify(modelToArray())
        ok(qsTr("CSV 导入成功，共 ") + rows.length + qsTr(" 条"))
    }

    function exportCsv(path) {
        var headers = ["pkg", "size", "category", "note"]
        if (!csvFileReader.writeCsvFile(path, modelToArray(), headers)) {
            var err = csvFileReader.getLastError()
            warn(err && err !== "" ? err : qsTr("CSV 导出失败"))
            return
        }
        ok(qsTr("CSV 导出成功"))
    }

    Component.onCompleted: loadLibrary()

    Settings {
        id: packageStore
        category: "PackageLibrary"
        property string dataJson: ""
    }

    readonly property var defaultData: [
        { pkg: "0201", size: "0.60 x 0.30", category: "电阻/电容", note: "超小型，被动器件" },
        { pkg: "0402", size: "1.00 x 0.50", category: "电阻/电容", note: "高密度贴装常用" },
        { pkg: "0603", size: "1.60 x 0.80", category: "电阻/电容", note: "通用主流尺寸" },
        { pkg: "0805", size: "2.00 x 1.25", category: "电阻/电容", note: "手工焊接友好" },
        { pkg: "1206", size: "3.20 x 1.60", category: "电阻/电容", note: "较大功率器件" },
        { pkg: "SOT-23", size: "2.90 x 1.30", category: "三极管/MOS", note: "小信号器件常用" },
        { pkg: "SOD-123", size: "2.70 x 1.60", category: "二极管", note: "肖特基/TVS 常见" },
        { pkg: "QFN-32", size: "5.00 x 5.00", category: "IC", note: "中高引脚密度" },
        { pkg: "TQFP-48", size: "7.00 x 7.00", category: "MCU", note: "通用 MCU 封装" },
        { pkg: "SOIC-8", size: "4.90 x 3.90", category: "IC", note: "EEPROM/运放常见" }
    ]

    ListModel {
        id: packageModel
    }

    FileDialog {
        id: importDialog
        title: qsTr("导入封装 CSV")
        nameFilters: [qsTr("CSV 文件 (*.csv)")]
        onAccepted: page.importCsv(selectedFile)
    }

    FileDialog {
        id: exportDialog
        title: qsTr("导出封装 CSV")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "csv"
        nameFilters: [qsTr("CSV 文件 (*.csv)")]
        onAccepted: page.exportCsv(selectedFile)
    }

    FluContentDialog {
        id: editorDialog
        property int editIndex: -1
        property string pkg: ""
        property string size: ""
        property string category: ""
        property string note: ""
        title: editIndex >= 0 ? qsTr("编辑封装") : qsTr("新增封装")
        negativeText: qsTr("取消")
        positiveText: qsTr("保存")
        contentDelegate: Component {
            Column {
                spacing: 8
                width: parent.width

                FluTextBox {
                    placeholderText: qsTr("封装名称，如 0603")
                    text: editorDialog.pkg
                    onTextChanged: editorDialog.pkg = text
                }
                FluTextBox {
                    placeholderText: qsTr("封装大小(mm)，如 1.60 x 0.80")
                    text: editorDialog.size
                    onTextChanged: editorDialog.size = text
                }
                FluTextBox {
                    placeholderText: qsTr("分类")
                    text: editorDialog.category
                    onTextChanged: editorDialog.category = text
                }
                FluTextBox {
                    placeholderText: qsTr("备注")
                    text: editorDialog.note
                    onTextChanged: editorDialog.note = text
                }
            }
        }
        onPositiveClicked: page.saveEditorRecord()
    }

    FluFrame {
        anchors.fill: parent
        anchors.margins: 20
        padding: 12

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            FluText {
                text: qsTr("常见 PCB 元件封装库（尺寸单位：mm）")
                font: FluTextStyle.Subtitle
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                FluTextBox {
                    Layout.fillWidth: true
                    placeholderText: qsTr("按封装名搜索，如 0603 / QFN / SOT")
                    text: page.searchKeyword
                    onTextChanged: page.searchKeyword = text
                }

                FluButton { text: qsTr("新增"); onClicked: page.openEditor(-1) }
                FluButton { text: qsTr("保存"); onClicked: page.saveLibrary() }
                FluButton { text: qsTr("导入CSV"); onClicked: importDialog.open() }
                FluButton { text: qsTr("导出CSV"); onClicked: exportDialog.open() }
                FluButton {
                    text: qsTr("恢复默认")
                    onClicked: {
                        page.loadDefaults(true)
                        page.ok(qsTr("已恢复默认封装库"))
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 6
                color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    FluText { text: qsTr("封装名称"); Layout.preferredWidth: 160; font: FluTextStyle.BodyStrong }
                    FluText { text: qsTr("封装大小(mm)"); Layout.preferredWidth: 170; font: FluTextStyle.BodyStrong }
                    FluText { text: qsTr("分类"); Layout.preferredWidth: 160; font: FluTextStyle.BodyStrong }
                    FluText { text: qsTr("备注"); Layout.fillWidth: true; font: FluTextStyle.BodyStrong }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: packageModel

                delegate: Rectangle {
                    id: rowDelegate
                    required property int index
                    required property string pkg
                    required property string size
                    required property string category
                    required property string note

                    readonly property bool matched: page.searchKeyword.trim() === "" ||
                                                  rowDelegate.pkg.toLowerCase().indexOf(page.searchKeyword.trim().toLowerCase()) !== -1
                    visible: matched
                    width: ListView.view.width
                    height: matched ? 40 : 0
                    radius: 6
                    color: index % 2 === 0
                           ? (FluTheme.dark ? Qt.rgba(1, 1, 1, 0.03) : Qt.rgba(0, 0, 0, 0.02))
                           : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        FluText { text: rowDelegate.pkg; Layout.preferredWidth: 160 }
                        FluText { text: rowDelegate.size; Layout.preferredWidth: 170 }
                        FluText { text: rowDelegate.category; Layout.preferredWidth: 160 }
                        FluText { text: rowDelegate.note; Layout.fillWidth: true; elide: Text.ElideRight }

                        FluButton {
                            text: qsTr("编辑")
                            Layout.preferredWidth: 54
                            onClicked: page.openEditor(rowDelegate.index)
                        }
                        FluButton {
                            text: qsTr("删除")
                            Layout.preferredWidth: 54
                            onClicked: page.removeRecord(rowDelegate.index)
                        }
                    }
                }
            }
        }
    }
}