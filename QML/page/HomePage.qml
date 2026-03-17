import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import QtQuick.Dialogs
import QtWebView
import QtMultimedia
import FluentUI 1.0

FluContentPage{

    id:root
    title: qsTr("TableView")
    property int sortType: 0
    property int allCheckState: Qt.Checked
    property string nameKeyword: ""
    property string layerKeyword: ""
    property var topPreviewCameraDevice: null
    property var bottomPreviewCameraDevice: null
    property int homePreviewRole: 0
    property bool runPaused: mainWindow.homeRunPaused
    property int runCurrentRow: mainWindow.homeRunCurrentRow
    property real mountedProgress: mainWindow.homeMountedProgress
    property int visibleRunCurrentRow: -1
    signal checkBoxChanged
    signal runCurrentItemChanged(int rowIndex, var item)

    function buildUiRow(rawRow, fallbackRowIndex) {
        var row = mainWindow.normalizeHomeRow(rawRow, fallbackRowIndex)
        return {
            rowIndex: row.rowIndex,
            checkbox: table_view.customItem(delegates.com_checbox, {checked: row.selected}),
            name: row.name,
            avatar: row.avatar,
            age: row.age,
            address: row.address,
            nickname: row.nickname,
            longstring: row.longstring,
            mounted: table_view.customItem(delegates.com_mounted_checkbox, {checked: row.mounted}),
            layer: row.layer,
            quantity: row.quantity,
            component_name: row.component_name,
            action: table_view.customItem(delegates.com_action),
            _minimumHeight: row._minimumHeight,
            _key: row._key
        }
    }

    function extractRawRow(rowData, fallbackRowIndex) {
        return mainWindow.normalizeHomeRow({
            rowIndex: rowData.rowIndex || fallbackRowIndex,
            selected: rowData.checkbox && rowData.checkbox.options && rowData.checkbox.options.checked,
            name: rowData.name,
            avatar: rowData.avatar,
            age: rowData.age,
            address: rowData.address,
            nickname: rowData.nickname,
            longstring: rowData.longstring,
            mounted: rowData.mounted && rowData.mounted.options && rowData.mounted.options.checked,
            layer: rowData.layer,
            quantity: rowData.quantity,
            component_name: rowData.component_name,
            _minimumHeight: rowData._minimumHeight,
            _key: rowData._key
        }, fallbackRowIndex)
    }

    function refreshHomeTableFromState() {
        var rows = []
        for (var i = 0; i < mainWindow.homeTableData.length; i++) {
            rows.push(buildUiRow(mainWindow.homeTableData[i], i + 1))
        }
        table_view.dataSource = rows
        if (mainWindow.homeTablePageCurrent > 0) {
            gagination.pageCurrent = mainWindow.homeTablePageCurrent
        }
    }

    function persistHomeTableData() {
        var data = []
        if (table_view && table_view.sourceModel) {
            for (var i = 0; i < table_view.sourceModel.rowCount; i++) {
                data.push(extractRawRow(table_view.sourceModel.getRow(i), i + 1))
            }
        }
        mainWindow.setHomeTableData(data)
        mainWindow.homeTablePageCurrent = gagination.pageCurrent
    }

    function applyHomeTableData(data) {
        mainWindow.setHomeTableData(data)
        refreshHomeTableFromState()
        mainWindow.homeTablePageCurrent = gagination.pageCurrent
    }

    function updateMountedProgress() {
        mountedProgress = mainWindow.homeMountedProgress
    }

    function getCurrentRunItem() {
        if (runCurrentRow < 0 || runCurrentRow >= mainWindow.homeTableData.length) {
            return null
        }
        return buildUiRow(mainWindow.homeTableData[runCurrentRow], runCurrentRow + 1)
    }

    function isRowSelected(rowIndex) {
        return mainWindow.isHomeRowSelected(rowIndex)
    }

    function findNextSelectedRow(startIndex) {
        return mainWindow.findNextSelectedHomeRow(startIndex)
    }

    function buildRowCommand(rowData) {
        return mainWindow.buildHomeRowCommand(extractRawRow(rowData, rowData ? rowData.rowIndex : 0))
    }

    function sendSelectedRowsToController() {
        if (!serialPortManager || !serialPortManager.connected) {
            showWarning(qsTr("串口未连接，无法发送任务列表"))
            return false
        }
        if (!mainWindow.sendHomeSelectedRowsToController()) {
            showWarning(qsTr("没有可发送的勾选项"))
            return false
        }
        return true
    }

    function appendRunConsoleMessage(rowIndex, item) {
        if (!serialPortManager) {
            return
        }
        serialPortManager.appendConsoleMessage("[RUN] row=" + rowIndex + " item=" + JSON.stringify(item))
    }

    function syncCurrentRunHighlight() {
        visibleRunCurrentRow = table_view.resolveVisibleRowByRawIndex(mainWindow.homeTableData, runCurrentRow)
        // 叠加层 Rectangle 会自动跟随 runCurrentRow，这里只负责滚动视图到当前行
        if (visibleRunCurrentRow >= 0 && visibleRunCurrentRow < table_view.rows) {
            if (table_view.view && typeof table_view.view.positionViewAtRow === "function") {
                table_view.view.positionViewAtRow(visibleRunCurrentRow, Qt.AlignVCenter)
            }
        }
    }

    function moveToNextRunItem() {
        var previousRow = mainWindow.homeRunCurrentRow
        mainWindow.advanceHomeRun()
        table_view.markMountedByRawIndex(mainWindow.homeTableData, previousRow, delegates.com_mounted_checkbox)
        runPaused = mainWindow.homeRunPaused
        runCurrentRow = mainWindow.homeRunCurrentRow
        updateMountedProgress()
        if (mainWindow.homeRunCurrentRow < 0) {
            showSuccess(qsTr("流程执行完成"))
            return
        }
        var currentItem = getCurrentRunItem()
        syncCurrentRunHighlight()
        appendRunConsoleMessage(runCurrentRow, currentItem)
        runCurrentItemChanged(runCurrentRow, currentItem)
    }

    function startRunLoop() {
        if (mainWindow.homeTableData.length <= 0) {
            showWarning(qsTr("表格为空，无法开始"))
            return
        }

        var runOrder = table_view.buildRunOrderFromVisibleRows(mainWindow.homeTableData)
        if (!mainWindow.startHomeRun(runOrder)) {
            showWarning(qsTr("没有勾选项，无法开始"))
            return
        }

        runPaused = mainWindow.homeRunPaused
        runCurrentRow = mainWindow.homeRunCurrentRow
        var currentItem = getCurrentRunItem()
        syncCurrentRunHighlight()
        appendRunConsoleMessage(runCurrentRow, currentItem)
        runCurrentItemChanged(runCurrentRow, currentItem)
    }

    function pauseRunLoop() {
        mainWindow.pauseHomeRun()
        runPaused = mainWindow.homeRunPaused
    }

    function stopRunLoop() {
        mainWindow.stopHomeRun(true)
        table_view.clearMountedChecks(delegates.com_mounted_checkbox)
        runPaused = mainWindow.homeRunPaused
        runCurrentRow = mainWindow.homeRunCurrentRow
        updateMountedProgress()
        syncCurrentRunHighlight()
    }

    function clearAllRows() {
        stopRunLoop()
        applyHomeTableData([])
        updateMountedProgress()
    }

    function deleteSelectionRows() {
        applyHomeTableData(table_view.dataAfterDeletingSelected())
        updateMountedProgress()
    }

    function addRowData() {
        table_view.appendRow(genTestObject())
        persistHomeTableData()
        updateMountedProgress()
    }

    function insertRowData() {
        var index = table_view.currentIndex()
        if (index !== -1) {
            var testObj = genTestObject()
            table_view.insertRow(index, testObj)
            persistHomeTableData()
            updateMountedProgress()
        } else {
            showWarning(qsTr("Focus not acquired: Please click any item in the form as the target for insertion!"))
        }
    }

    function toggleRunOrPause() {
        if (runPaused) {
            startRunLoop()
            showSuccess(qsTr("开始执行"))
        } else {
            pauseRunLoop()
            showSuccess(qsTr("已暂停"))
        }
    }

    function stepRunOnce() {
        if (runCurrentRow < 0) {
            if (mainWindow.homeTableData.length <= 0) {
                showWarning(qsTr("表格为空，无法单步执行"))
                return
            }
            if (!mainWindow.stepHomeRun(table_view.buildRunOrderFromVisibleRows(mainWindow.homeTableData))) {
                showWarning(qsTr("没有勾选项，无法单步执行"))
                return
            }
            runCurrentRow = mainWindow.homeRunCurrentRow
            var firstItem = getCurrentRunItem()
            syncCurrentRunHighlight()
            appendRunConsoleMessage(runCurrentRow, firstItem)
            runCurrentItemChanged(runCurrentRow, firstItem)
        } else {
            var prevRow = mainWindow.homeRunCurrentRow
            mainWindow.stepHomeRun(table_view.buildRunOrderFromVisibleRows(mainWindow.homeTableData))
            table_view.markMountedByRawIndex(mainWindow.homeTableData, prevRow, delegates.com_mounted_checkbox)
            runCurrentRow = mainWindow.homeRunCurrentRow
            syncCurrentRunHighlight()
        }
        showSuccess(qsTr("单步执行"))
    }

    function applyFilters() {
        mainWindow.homeNameKeyword = nameKeyword
        mainWindow.homeLayerKeyword = layerKeyword
        table_view.filter(function(item){
            var nameMatch = nameKeyword === "" || item.name.includes(nameKeyword)
            var layerMatch = layerKeyword === "" || item.layer.includes(layerKeyword)
            return nameMatch && layerMatch
        })
        mainWindow.updateHomeMountedProgress()
        updateMountedProgress()
        syncCurrentRunHighlight()
    }

    HomePageDialogs {
        id: dialogs
        rootPage: root
        tableView: table_view
    }

    onNameKeywordChanged: applyFilters()
    onLayerKeywordChanged: applyFilters()

    Component.onCompleted: {
        nameKeyword = mainWindow.homeNameKeyword
        layerKeyword = mainWindow.homeLayerKeyword
        if (mainWindow.homeTableData && mainWindow.homeTableData.length > 0) {
            refreshHomeTableFromState()
        } else {
            loadData(1,1000)
        }
        runPaused = mainWindow.homeRunPaused
        runCurrentRow = mainWindow.homeRunCurrentRow
        scanStartupTimer.start()
        scheduleResolvePreviewDevices()
        applyFilters()
        updateMountedProgress()
    }

    Connections {
        target: mainWindow
        function onHomeTableDataChanged() {
            // 运行期间（尤其带排序时）避免整表 dataSource 重建，防止模型重排导致崩溃。
            // 页面可见时会在 onVisibleChanged 中主动同步一次。
        }
        function onHomeRunCurrentRowChanged() {
            table_view.markMountedByRawIndex(mainWindow.homeTableData, mainWindow.homeRunLastMountedRow, delegates.com_mounted_checkbox)
            runCurrentRow = mainWindow.homeRunCurrentRow
            syncCurrentRunHighlight()
        }
        function onHomeRunPausedChanged() {
            runPaused = mainWindow.homeRunPaused
        }
        function onHomeMountedProgressChanged() {
            mountedProgress = mainWindow.homeMountedProgress
        }
    }

    function importFile(filePath) {
        var fileUrl = filePath ? filePath.toString() : ""
        var fileName = fileUrl.split("/").pop()
        // 导入新数据前先中止运行态，避免旧索引/高亮引用已被替换的模型
        stopRunLoop()

        if (fileUrl === "" || !fileUrl.toLowerCase().endsWith(".csv")) {
            showError(qsTr("仅支持导入 CSV 文件"))
            return
        }

        // 使用C++后端读取CSV文件
        var csvData = csvFileReader.readCsvFile(fileUrl)
        
        if (!csvData || csvData.length === undefined || csvData.length === 0) {
            var err = csvFileReader.getLastError()
            if (err === "") {
                err = qsTr("文件读取失败或文件为空")
            }
            showError(err)
            return
        }
        
        // 将CSV数据转换为表格格式
        // 单行会创建多个 customItem，对超大文件需限制行数以避免瞬时内存暴涨。
        var maxImportRows = 10000
        var importCount = Math.min(csvData.length, maxImportRows)
        var dataSource = []
        for (var i = 0; i < importCount; i++) {
            var row = csvData[i]
            if (!row) {
                continue
            }
            var item = {
                rowIndex: row.rowIndex || (i + 1),
                selected: row.SMD === "Yes",
                name: row.Designator || row.designator || "",
                avatar: row.Device || row.device || row.Footprint || row.footprint || "",
                age: row.Pins || "0",
                address: row["Mid X"] || row.midX || row.midx || "",  // x坐标
                nickname: row["Mid Y"] || row.midY || row.midy || "", // y坐标
                longstring: row.Rotation || row.rotation || "0",       // 角度
                mounted: false,
                layer: row.Layer || row.layer || "",                  // 板层
                quantity: row.Pins || "0",                            // 数量
                component_name: row.Device || row.device || row.Footprint || row.footprint || "",  // 器件名字
                _minimumHeight: 50,
                _key: FluTools.uuid()
            }
            dataSource.push(item)
        }

        // 加载到表格
        applyHomeTableData(dataSource)

        gagination.pageCurrent = 1
        mainWindow.homeTablePageCurrent = 1

        root.allCheckState = Qt.Unchecked

       // updateMountedProgress()
        if (csvData.length > maxImportRows) {
            showWarning(qsTr("文件行数过大，仅加载前 ") + maxImportRows + qsTr(" 行"))
        }
        
        showSuccess(qsTr("文件已导入: ") + fileName + qsTr(" (") + importCount + qsTr(" 行)"))
    }

    function resolveCameraDeviceFor(cameraName, cameraIndex) {
        if (cameraName === "") {
            return mainWindow.sharedMediaDevices.defaultVideoInput
        }
        var devices = mainWindow.sharedMediaDevices.videoInputs
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].description === cameraName) {
                return devices[i]
            }
        }
        if (cameraIndex >= 0 && cameraIndex < devices.length) {
            return devices[cameraIndex]
        }
        return mainWindow.sharedMediaDevices.defaultVideoInput
    }

    function resolvePreviewCameraDevices() {
        topPreviewCameraDevice = resolveCameraDeviceFor(cameraDeviceManager.topCameraName, cameraDeviceManager.topCameraIndex)
        bottomPreviewCameraDevice = resolveCameraDeviceFor(cameraDeviceManager.bottomCameraName, cameraDeviceManager.bottomCameraIndex)
    }

    function scheduleResolvePreviewDevices() {
        resolveCameraTimer.restart()
    }

    function isCurrentPreviewOpened() {
        return homePreviewRole < 2 ? cameraDeviceManager.topCameraOpened : cameraDeviceManager.bottomCameraOpened
    }

    function currentPreviewCameraDevice() {
        return homePreviewRole < 2 ? topPreviewCameraDevice : bottomPreviewCameraDevice
    }

    Timer {
        id: resolveCameraTimer
        interval: 60
        repeat: false
        onTriggered: resolvePreviewCameraDevices()
    }

    Timer {
        id: scanStartupTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (root.visible) {
                cameraDeviceManager.startScanning()
            }
        }
    }

    Connections {
        target: mainWindow.sharedMediaDevices
        function onVideoInputsChanged() {
            scheduleResolvePreviewDevices()
        }
    }

    Connections {
        target: cameraDeviceManager
        function onTopCameraNameChanged() {
            scheduleResolvePreviewDevices()
        }
        function onBottomCameraNameChanged() {
            scheduleResolvePreviewDevices()
        }
        function onTopCameraIndexChanged() {
            scheduleResolvePreviewDevices()
        }
        function onBottomCameraIndexChanged() {
            scheduleResolvePreviewDevices()
        }
        function onTopCameraConnectedChanged() {
            scheduleResolvePreviewDevices()
        }
        function onBottomCameraConnectedChanged() {
            scheduleResolvePreviewDevices()
        }
        function onTopCameraOpenedChanged() {
            scheduleResolvePreviewDevices()
        }
        function onBottomCameraOpenedChanged() {
            scheduleResolvePreviewDevices()
        }
        function onCameraNamesChanged() {
            if (cameraDeviceManager.cameraNames.length > 0 && cameraDeviceManager.topCameraIndex < 0) {
                cameraDeviceManager.selectTopCamera(0)
            }
            if (cameraDeviceManager.cameraNames.length > 1 && cameraDeviceManager.bottomCameraIndex < 0) {
                cameraDeviceManager.selectBottomCamera(1)
            } else if (cameraDeviceManager.cameraNames.length === 1 && cameraDeviceManager.bottomCameraIndex < 0) {
                cameraDeviceManager.selectBottomCamera(0)
            }
            scheduleResolvePreviewDevices()
        }
    }

    onCheckBoxChanged: {
        updateAllCheck()
        updateMountedProgress()
    }

    onVisibleChanged: {
        if (visible) {
            refreshHomeTableFromState()
            Qt.callLater(syncCurrentRunHighlight)
            scanStartupTimer.restart()
        } else {
            cameraDeviceManager.stopScanning()
        }
    }

    function quantitySortValue(row) {
        if (!row) {
            return 0
        }
        var raw = row.quantity
        if (raw === undefined || raw === null || raw === "") {
            raw = row.age
        }
        var text = String(raw)
        var numberText = text.replace(/[^0-9+\-.]/g, "")
        var value = Number(numberText)
        return isNaN(value) ? 0 : value
    }

    onSortTypeChanged: {
        table_view.closeEditor()
        if(sortType === 0){
            table_view.sort()
        }else if(sortType === 1){
            table_view.sort(
                        (l, r) =>{
                            var lq = quantitySortValue(l)
                            var rq = quantitySortValue(r)
                            if(lq === rq){
                                return l._key>r._key
                            }
                            return lq>rq
                        });
        }else if(sortType === 2){
            table_view.sort(
                        (l, r) => {
                            var lq = quantitySortValue(l)
                            var rq = quantitySortValue(r)
                            if(lq === rq){
                                return l._key>r._key
                            }
                            return lq<rq
                        });
        }
        Qt.callLater(syncCurrentRunHighlight)
    }

    

    HomePageTableDelegates {
        id: delegates
        tableView: table_view
        rootPage: root
        popFilter: dialogs.popFilter
        popFilterLayer: dialogs.popFilterLayer
        customUpdateDialog: dialogs.customUpdateDialog
    }

    FluSplitLayout {
        anchors.fill: parent
        anchors.margins: 20
        orientation: Qt.Horizontal

        // 左侧：图片和TableView 区域
        FluSplitLayout {
            clip: true
            implicitWidth: root.width * 0.7
            implicitHeight: root.height
            SplitView.minimumWidth: 400
            SplitView.fillHeight: true
            orientation: Qt.Vertical

            // 上半部分：图片查看器
            Item {
                clip: true
                implicitWidth: parent.width
                implicitHeight: parent.height * 0.4
                SplitView.minimumHeight: 200
                SplitView.fillWidth: true

                FluFrame {
                    anchors.fill: parent
                    padding: 10

                    Item {
                        anchors.fill: parent
                        clip: true

                        // WebView {
                        //     id: bomWebView
                        //     anchors.fill: parent
                        //     url: interactiveBomUrl ? interactiveBomUrl : "about:blank"
                        // }
                    }
                }
            }

            // 下半部分：TableView
            Item {
                clip: true
                implicitWidth: parent.width
                implicitHeight: parent.height * 0.6
                SplitView.minimumHeight: 200
                SplitView.fillWidth: true

                HomePageTableToolbar {
                    id: layout_controls
                    runPaused: root.runPaused
                    mountedProgress: root.mountedProgress
                    onImportClicked: dialogs.openImportDialog()
                    onClearAllClicked: root.clearAllRows()
                    onDeleteSelectionClicked: root.deleteSelectionRows()
                    onAddRowClicked: root.addRowData()
                    onInsertRowClicked: root.insertRowData()
                    onRunToggleClicked: root.toggleRunOrPause()
                    onStopClicked: {
                        root.stopRunLoop()
                        showSuccess(qsTr("已中止"))
                    }
                    onStepClicked: root.stepRunOnce()
                }

            CubexFluTableView{
                id:table_view
                highlightRow: root.visibleRunCurrentRow
                useHomePreset: true
                homeDelegates: delegates
                pageCurrent: gagination.pageCurrent
                itemPerPage: gagination.__itemPerPage
                anchors{
                    left: parent.left
                    right: parent.right
                    top: layout_controls.bottom
                    bottom: gagination.top
                }
                anchors.topMargin: 5
                onRowsChanged: {
                    root.checkBoxChanged()
                    root.syncCurrentRunHighlight()
                }
            }

            FluPagination{
                id:gagination
                anchors{
                    bottom: parent.bottom
                    left: parent.left
                }
                pageCurrent: 1
                itemCount: 100000
                pageButtonCount: 7
                __itemPerPage: 1000
                previousText: qsTr("<Previous")
                nextText: qsTr("Next>")
                onRequestPage:
                    (page,count)=> {
                        table_view.closeEditor()
                        loadData(page,count)
                        table_view.resetPosition()
                    }
            }
            }
        }

        HomePageMotionControlPanel {
            pageWidth: root.width
            pageHeight: root.height
            homePreviewRole: root.homePreviewRole
            notify: root.showSuccess
            onPreviewRoleChanged: {
                root.homePreviewRole = role
            }
        }
    }

    function loadData(page,count){
        stopRunLoop()

        var csvFiles = csvFileReader.csvFilesInWorkingDirectory()
        if (!csvFiles || csvFiles.length === 0) {
            showWarning(qsTr("工作目录下未找到 CSV 文件"))
            applyHomeTableData([])
            return
        }

        var dataSource = []
        var maxImportRows = 10000

        for (var f = 0; f < csvFiles.length; f++) {
            var csvData = csvFileReader.readCsvFile(csvFiles[f])
            if (!csvData || csvData.length === undefined || csvData.length === 0) {
                continue
            }

            for (var i = 0; i < csvData.length; i++) {
                if (dataSource.length >= maxImportRows) {
                    break
                }
                var row = csvData[i]
                if (!row) {
                    continue
                }
                dataSource.push({
                    rowIndex: dataSource.length + 1,
                    selected: row.SMD === "Yes",
                    name: row.Designator || row.designator || "",
                    avatar: row.Device || row.device || row.Footprint || row.footprint || "",
                    age: row.Pins || "0",
                    address: row["Mid X"] || row.midX || row.midx || "",
                    nickname: row["Mid Y"] || row.midY || row.midy || "",
                    longstring: row.Rotation || row.rotation || "0",
                    mounted: false,
                    layer: row.Layer || row.layer || "",
                    quantity: row.Pins || "0",
                    component_name: row.Device || row.device || row.Footprint || row.footprint || "",
                    _minimumHeight: 50,
                    _key: FluTools.uuid()
                })
            }

            if (dataSource.length >= maxImportRows) {
                break
            }
        }

        applyHomeTableData(dataSource)
        gagination.pageCurrent = 1
        mainWindow.homeTablePageCurrent = 1
        root.allCheckState = Qt.Unchecked
        updateMountedProgress()

        if (dataSource.length >= maxImportRows) {
            showWarning(qsTr("CSV 数据过多，仅加载前 ") + maxImportRows + qsTr(" 行"))
        } else {
            showSuccess(qsTr("已从工作目录加载 CSV，共 ") + dataSource.length + qsTr(" 行"))
        }
    }
    function updateAllCheck() {
        root.allCheckState = table_view.checkedRowsState()
    }
}
