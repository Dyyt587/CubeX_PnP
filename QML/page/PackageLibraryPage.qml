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
    property int visibleCount: 0
    property bool importIncrementalMode: false
    signal packageDataChanged()
    property string debugMessage: ""

    function debug(msg) {
        debugMessage = msg !== undefined ? String(msg) : ""
    }

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
        packageDataChanged()
        if (typeof packageTableRoot !== 'undefined' && packageTableRoot.rebuildTableData) packageTableRoot.rebuildTableData()
    }

    function saveLibrary() {
        if (!persistLibraryFile(true)) {
            return
        }
        packageStore.dataJson = JSON.stringify(modelToArray())
        ok(qsTr("封装库已保存到软件数据目录"))
    }

    function persistLibraryFile(showError) {
        var headers = ["pkg", "size", "category", "note"]
        if (!csvFileReader.writePackageLibraryCsv(modelToArray(), headers)) {
            if (showError) {
                var err = csvFileReader.getLastError()
                warn(err && err !== "" ? err : qsTr("封装库文件保存失败"))
            }
            return false
        }
        return true
    }

    function loadLibrary() {
        if (csvFileReader.packageLibraryCsvExists()) {
            var rows = csvFileReader.readPackageLibraryCsv()
            if (rows && rows.length !== undefined && rows.length > 0) {
                var mapped = []
                for (var i = 0; i < rows.length; i++) {
                    mapped.push(normalizeRecord(rows[i]))
                }
                loadFromArray(mapped, false)
                return
            }
        }

        var text = packageStore.dataJson
        if (!text || text.trim() === "") {
            loadDefaults(true)
            return
        }
        try {
            var parsed = JSON.parse(text)
            if (parsed && parsed.length !== undefined) {
                loadFromArray(parsed, false)
                persistLibraryFile(false)
                return
            }
        } catch (e) {
            warn(qsTr("封装库数据损坏，已恢复默认"))
        }
        loadDefaults(true)
    }

    function loadDefaults(saveAfter) {
        packageModel.clear()
        for (var i = 0; i < defaultData.length; i++) {
            packageModel.append(defaultData[i])
        }
        packageDataChanged()
        if (typeof packageTableRoot !== 'undefined' && packageTableRoot.rebuildTableData) packageTableRoot.rebuildTableData()
        if (saveAfter) {
            packageStore.dataJson = JSON.stringify(modelToArray())
            persistLibraryFile(false)
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
        packageDataChanged()
        if (typeof packageTableRoot !== 'undefined' && packageTableRoot.rebuildTableData) packageTableRoot.rebuildTableData()
        packageStore.dataJson = JSON.stringify(modelToArray())
        persistLibraryFile(false)
        ok(qsTr("已保存封装记录"))
    }

    function removeRecord(index) {
        console.log("removeRecord called with index: " + index)
        debug("Attempting to remove record at index: " + index)
        if (index < 0 || index >= packageModel.count) {
            warn("Invalid index: " + index)
            return
        }
        packageModel.remove(index)
        packageDataChanged()
        if (typeof packageTableRoot !== 'undefined' && packageTableRoot.rebuildTableData) packageTableRoot.rebuildTableData()
        packageStore.dataJson = JSON.stringify(modelToArray())
        persistLibraryFile(false)
        ok(qsTr("已删除封装记录"))
    }

    function importCsv(path) {
        importCsvWithMode(path, importIncrementalMode)
    }

    function pkgKey(name) {
        return String(name || "").trim().toLowerCase()
    }

    function mergeRowsByPkg(rows) {
        var merged = []
        var indexByKey = {}
        for (var i = 0; i < rows.length; i++) {
            var row = normalizeRecord(rows[i])
            if (row.pkg === "") {
                continue
            }
            var key = pkgKey(row.pkg)
            if (indexByKey[key] === undefined) {
                indexByKey[key] = merged.length
                merged.push(row)
            } else {
                merged[indexByKey[key]] = row
            }
        }
        return merged
    }

    function importCsvWithMode(path, incrementalMode) {
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

        var normalizedImportRows = mergeRowsByPkg(mapped)
        var updated = 0
        var added = 0

        if (incrementalMode) {
            var existingIndexByKey = {}
            for (var e = 0; e < packageModel.count; e++) {
                var existing = packageModel.get(e)
                existingIndexByKey[pkgKey(existing.pkg)] = e
            }

            for (var m = 0; m < normalizedImportRows.length; m++) {
                var incoming = normalizedImportRows[m]
                var incomingKey = pkgKey(incoming.pkg)
                if (existingIndexByKey[incomingKey] !== undefined) {
                    packageModel.set(existingIndexByKey[incomingKey], incoming)
                    updated++
                } else {
                    packageModel.append(incoming)
                    existingIndexByKey[incomingKey] = packageModel.count - 1
                    added++
                }
            }
        } else {
            loadFromArray(normalizedImportRows, false)
            added = normalizedImportRows.length
        }

        packageDataChanged()
        if (typeof packageTableRoot !== 'undefined' && packageTableRoot.rebuildTableData) packageTableRoot.rebuildTableData()
        packageStore.dataJson = JSON.stringify(modelToArray())
        if (!persistLibraryFile(true)) {
            return
        }

        if (incrementalMode) {
            ok(qsTr("CSV 增量导入成功：新增 ") + added + qsTr(" 条，覆盖 ") + updated + qsTr(" 条，并已保存到软件数据目录"))
        } else {
            ok(qsTr("CSV 覆盖导入成功：共 ") + added + qsTr(" 条（重名项已覆盖），并已保存到软件数据目录"))
        }
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
        onAccepted: page.importCsvWithMode(selectedFile, page.importIncrementalMode)
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

                Timer {
                    id: debugTimer
                    interval: 3000
                    repeat: false
                    onTriggered: page.debug("")
                }

                Rectangle {
                    id: debugOverlay
                    width: 360
                    height: 32
                    radius: 6
                    color: FluTheme.dark ? Qt.rgba(0,0,0,0.7) : Qt.rgba(0,0,0,0.08)
                    anchors {
                        top: parent.top
                        right: parent.right
                        topMargin: 6
                        rightMargin: 6
                    }
                    visible: page.debugMessage !== ""
                    z: 9999
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        FluText { text: page.debugMessage; elide: Text.ElideRight }
                    }
                }

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
                    onTextChanged: {
                        page.searchKeyword = text
                        page.packageDataChanged()
                    }
                }

                FluButton { text: qsTr("新增"); onClicked: page.openEditor(-1) }
                FluButton { text: qsTr("保存"); onClicked: page.saveLibrary() }
                FluButton {
                    text: qsTr("覆盖导入CSV")
                    onClicked: {
                        page.importIncrementalMode = false
                        importDialog.open()
                    }
                }
                FluButton {
                    text: qsTr("增量导入CSV")
                    onClicked: {
                        page.importIncrementalMode = true
                        importDialog.open()
                    }
                }
                FluButton { text: qsTr("导出CSV"); onClicked: exportDialog.open() }
                FluButton {
                    text: qsTr("恢复默认")
                    onClicked: {
                        page.loadDefaults(true)
                        page.ok(qsTr("已恢复默认封装库"))
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                FluText {
                    text: qsTr("项目总数：") + packageModel.count + qsTr("，当前显示：") + page.visibleCount
                    font: FluTextStyle.BodyStrong
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                FluTabView {
                    id: tableTabView
                    anchors.fill: parent
                    addButtonVisibility: false
                    closeButtonVisibility: FluTabViewType.Never
                    tabWidthBehavior: FluTabViewType.SizeToContent

                    Component.onCompleted: {
                        tableTabView.appendTab("", qsTr("封装列表"), packageTableTab)
                    }
                }
            }

            Component {
                id: packageTableTab
                Item {
                    id: packageTableRoot
                    anchors.fill: parent

                    function rebuildTableData() {
                        var rows = []
                        var key = page.searchKeyword.trim().toLowerCase()
                        var count = 0
                        for (var i = 0; i < packageModel.count; i++) {
                            var item = packageModel.get(i)
                            var pkg = String(item.pkg || "")
                            if (key !== "" && pkg.toLowerCase().indexOf(key) === -1) {
                                continue
                            }
                            count++
                            // 用立即执行函数固定 i，避免闭包捕获循环变量
                            ;(function(idx, pkgName) {
                                rows.push({
                                    sourceIndex: idx,
                                    pkg: pkgName,
                                    size: String(item.size || ""),
                                    category: String(item.category || ""),
                                    note: String(item.note || ""),
                                    action: packageTableView.customItem(rowActionDelegate, {
                                        sourceIndex: idx,
                                        pkg: pkgName
                                    })
                                })
                            })(i, pkg)
                        }
                        page.visibleCount = count
                        packageTableView.dataSource = rows
                    }

                    Component.onCompleted: rebuildTableData()

                    Connections {
                        target: page
                        function onPackageDataChanged() {
                            packageTableRoot.rebuildTableData()
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        FluTableView {
                            id: packageTableView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            verticalHeaderVisible: false
                            columnWidthProvider: function(column) {
                                if (column === 3) {
                                    var fixed = 180 + 190 + 170 + 150
                                    return Math.max(220, packageTableView.width - fixed - 24)
                                }
                                if (column === 0) return 180
                                if (column === 1) return 190
                                if (column === 2) return 170
                                if (column === 4) return 150
                                return 120
                            }
                            columnSource: [
                                { title: qsTr("封装名称"), dataIndex: "pkg", width: 180, minimumWidth: 140 },
                                { title: qsTr("封装大小(mm)"), dataIndex: "size", width: 190, minimumWidth: 150 },
                                { title: qsTr("分类"), dataIndex: "category", width: 170, minimumWidth: 130 },
                                { title: qsTr("备注"), dataIndex: "note", width: 360, minimumWidth: 220 },
                                { title: qsTr("操作"), dataIndex: "action", width: 150, minimumWidth: 130 }
                            ]
                        }

                        Component {
                            id: rowActionDelegate
                            Item {
                                // 不声明 options 属性，直接从 FluLoader 的 context 读取
                                // （与 HomePageTableDelegates.qml 的模式一致）
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    FluButton {
                                        text: qsTr("编辑")
                                        onClicked: {
                                            var idx = options ? options.sourceIndex : -1
                                            if (idx !== undefined && idx >= 0) {
                                                page.openEditor(idx)
                                            }
                                        }
                                    }
                                    FluButton {
                                        text: qsTr("删除")
                                        onClicked: {
                                            var idx = options ? options.sourceIndex : -1
                                            if (idx !== undefined && idx >= 0) {
                                                page.removeRecord(idx)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}