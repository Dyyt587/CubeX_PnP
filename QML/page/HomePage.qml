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

    function buildRunOrderFromVisibleRows() {
        var order = []
        var keyToRawIndex = {}
        for (var i = 0; i < mainWindow.homeTableData.length; i++) {
            var raw = mainWindow.homeTableData[i]
            if (!raw || !raw._key) {
                continue
            }
            keyToRawIndex[raw._key] = i
        }

        for (var row = 0; row < table_view.rows; row++) {
            var visible = table_view.getRow(row)
            if (!visible || !visible._key) {
                continue
            }
            var rawIndex = keyToRawIndex[visible._key]
            if (rawIndex === undefined) {
                continue
            }
            order.push(rawIndex)
        }
        return order
    }

    function resolveVisibleRunCurrentRow() {
        if (runCurrentRow < 0 || runCurrentRow >= mainWindow.homeTableData.length) {
            return -1
        }
        var current = mainWindow.homeTableData[runCurrentRow]
        if (!current || !current._key) {
            return -1
        }
        for (var i = 0; i < table_view.rows; i++) {
            var row = table_view.getRow(i)
            if (row && row._key === current._key) {
                return i
            }
        }
        return -1
    }

    function syncCurrentRunHighlight() {
        visibleRunCurrentRow = resolveVisibleRunCurrentRow()
        // 叠加层 Rectangle 会自动跟随 runCurrentRow，这里只负责滚动视图到当前行
        if (visibleRunCurrentRow >= 0 && visibleRunCurrentRow < table_view.rows) {
            if (table_view.view && typeof table_view.view.positionViewAtRow === "function") {
                table_view.view.positionViewAtRow(visibleRunCurrentRow, Qt.AlignVCenter)
            }
        }
    }

    function markTableRowMounted(rawRowIndex) {
        if (rawRowIndex < 0 || rawRowIndex >= mainWindow.homeTableData.length) {
            return
        }
        var targetKey = mainWindow.homeTableData[rawRowIndex]._key
        if (!targetKey) {
            return
        }
        for (var i = 0; i < table_view.rows; i++) {
            var obj = table_view.getRow(i)
            if (obj && obj._key === targetKey) {
                obj.mounted = table_view.customItem(delegates.com_mounted_checkbox, {checked: true})
                table_view.setRow(i, obj)
                return
            }
        }
    }

    function moveToNextRunItem() {
        var previousRow = mainWindow.homeRunCurrentRow
        mainWindow.advanceHomeRun()
        markTableRowMounted(previousRow)
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

        var runOrder = buildRunOrderFromVisibleRows()
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

    function clearMountedChecksInTable() {
        if (!table_view || !table_view.sourceModel) {
            return
        }
        var sourceModel = table_view.sourceModel
        for (var i = 0; i < sourceModel.rowCount; i++) {
            var item = sourceModel.getRow(i)
            if (!item) {
                continue
            }
            item.mounted = table_view.customItem(delegates.com_mounted_checkbox, {checked: false})
            sourceModel.setRow(i, item)
        }
    }

    function stopRunLoop() {
        mainWindow.stopHomeRun(true)
        clearMountedChecksInTable()
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
        var data = []
        var rows = []
        for (var i = 0; i < table_view.rows; i++) {
            var item = table_view.getRow(i)
            rows.push(item)
            if (!item.checkbox.options.checked) {
                data.push(item)
            }
        }
        var sourceModel = table_view.sourceModel
        for (i = 0; i < sourceModel.rowCount; i++) {
            var sourceItem = sourceModel.getRow(i)
            var foundItem = rows.find(item => item._key === sourceItem._key)
            if (!foundItem) {
                data.push(sourceItem)
            }
        }
        applyHomeTableData(data)
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
            if (!mainWindow.stepHomeRun(buildRunOrderFromVisibleRows())) {
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
            mainWindow.stepHomeRun(buildRunOrderFromVisibleRows())
            markTableRowMounted(prevRow)
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
            markTableRowMounted(mainWindow.homeRunLastMountedRow)
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
                startRowIndex: (gagination.pageCurrent - 1) * gagination.__itemPerPage + 1
                columnSource:[
                    {
                        title: table_view.customItem(delegates.com_column_checbox,{checked:true}),
                        dataIndex: 'checkbox',
                        frozen: true
                    },
                    {
                        title: table_view.customItem(delegates.com_column_filter_name,{title:qsTr("Name")}),
                        dataIndex: 'name',
                        readOnly:true
                    },
                    {
                        title: qsTr("封装"),
                        dataIndex: 'avatar',
                        width:150,
                        minimumWidth:100,
                        maximumWidth:250
                    },
                    {
                        title: table_view.customItem(delegates.com_column_sort_age,{sort:0}),
                        dataIndex: 'age',
                        editDelegate:delegates.com_combobox,
                        width:100,
                        minimumWidth:100,
                        maximumWidth:100
                    },
                    {
                        title: qsTr("x坐标"),
                        dataIndex: 'address',
                        editDelegate: delegates.com_auto_suggestbox,
                        width:200,
                        minimumWidth:100,
                        maximumWidth:250
                    },
                    {
                        title: qsTr("y坐标"),
                        dataIndex: 'nickname',
                        width:100,
                        minimumWidth:80,
                        maximumWidth:200
                    },
                    {
                        title: qsTr("角度"),
                        dataIndex: 'longstring',
                        width:100,
                        minimumWidth:80,
                        maximumWidth:150
                    },
                    {
                        title: qsTr("已贴装"),
                        dataIndex: 'mounted',
                        width:100,
                        minimumWidth:80,
                        maximumWidth:150
                    },
                    {
                        title: table_view.customItem(delegates.com_column_filter_layer,{}),
                        dataIndex: 'layer',
                        width:80,
                        minimumWidth:60,
                        maximumWidth:120
                    },
                    {
                        title: qsTr("器件名字"),
                        dataIndex: 'component_name',
                        width:120,
                        minimumWidth:100,
                        maximumWidth:200
                    },
                    {
                        title: qsTr("Options"),
                        dataIndex: 'action',
                        width:160,
                        frozen:true
                    }
                ]
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

        // 右侧：控制区域
        Item {
            clip: true
            implicitWidth: root.width * 0.3
            implicitHeight: root.height
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
                                    onClicked: showSuccess(qsTr("左上 (-X+Y)"))
                                }
                                FluButton {
                                    text: "↑"
                                    font.pixelSize: 24
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    onClicked: showSuccess(qsTr("上 (+Y)"))
                                }
                                FluButton {
                                    text: "↗"
                                    font.pixelSize: 24
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    onClicked: showSuccess(qsTr("右上 (+X+Y)"))
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
                                    onClicked: showSuccess(qsTr("左 (-X)"))
                                }
                                FluIconButton {
                                    iconSource: FluentIcons.Home
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    onClicked: showSuccess(qsTr("归零"))
                                }
                                FluButton {
                                    text: "→"
                                    font.pixelSize: 24
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    onClicked: showSuccess(qsTr("右 (+X)"))
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
                                    onClicked: showSuccess(qsTr("左下 (-X-Y)"))
                                }
                                FluButton {
                                    text: "↓"
                                    font.pixelSize: 24
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    onClicked: showSuccess(qsTr("下 (-Y)"))
                                }
                                FluButton {
                                    text: "↘"
                                    font.pixelSize: 24
                                    Layout.preferredWidth: 50
                                    Layout.preferredHeight: 50
                                    onClicked: showSuccess(qsTr("右下 (+X-Y)"))
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
                                        onClicked: showSuccess(qsTr("Z1 上升 (+Z1)"))
                                    }
                                    FluButton {
                                        text: "↓"
                                        font.pixelSize: 20
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        onClicked: showSuccess(qsTr("Z1 下降 (-Z1)"))
                                    }
                                }

                                // Z轴回零
                                FluIconButton {
                                    iconSource: FluentIcons.Home
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    Layout.alignment: Qt.AlignHCenter
                                    onClicked: showSuccess(qsTr("Z1 归零"))
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
                                        onClicked: showSuccess(qsTr("R1 逆时针"))
                                    }
                                    FluButton {
                                        text: "↷"
                                        font.pixelSize: 20
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        onClicked: showSuccess(qsTr("R1 顺时针"))
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
                                        onClicked: showSuccess(qsTr("Z2 上升 (+Z2)"))
                                    }
                                    FluButton {
                                        text: "↓"
                                        font.pixelSize: 20
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        onClicked: showSuccess(qsTr("Z2 下降 (-Z2)"))
                                    }
                                }

                                // Z轴回零
                                FluIconButton {
                                    iconSource: FluentIcons.Home
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    Layout.alignment: Qt.AlignHCenter
                                    onClicked: showSuccess(qsTr("Z2 归零"))
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
                                        onClicked: showSuccess(qsTr("R2 逆时针"))
                                    }
                                    FluButton {
                                        text: "↷"
                                        font.pixelSize: 20
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        onClicked: showSuccess(qsTr("R2 顺时针"))
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
                                    id: posX
                                    text: "X: 200.00mm"
                                    font: FluTextStyle.Caption
                                    Layout.alignment: Qt.AlignLeft
                                }
                                FluText {
                                    id: posY
                                    text: "Y: 200.00mm"
                                    font: FluTextStyle.Caption
                                    Layout.alignment: Qt.AlignLeft
                                }
                                FluText {
                                    id: posZ
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
                                    id: posR1
                                    text: "R1: 0.00°"
                                    font: FluTextStyle.Caption
                                    Layout.alignment: Qt.AlignLeft
                                }
                                FluText {
                                    id: posR2
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
                            id: cameraSelector
                            Layout.fillWidth: true
                            model: [
                                qsTr("顶部黑白"),
                                qsTr("顶部彩色"),
                                qsTr("底部黑白"),
                                qsTr("底部彩色")
                            ]
                            enabled: true
                            currentIndex: homePreviewRole
                            onCurrentIndexChanged: {
                                if (currentIndex >= 0) {
                                    homePreviewRole = currentIndex
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

                        readonly property bool previewOpened: (homePreviewRole === 0 && cameraDeviceManager.topCameraOpened)
                                                           || (homePreviewRole === 1 && cameraDeviceManager.topCameraOpened)
                                                           || (homePreviewRole === 2 && cameraDeviceManager.bottomCameraOpened)
                                                           || (homePreviewRole === 3 && cameraDeviceManager.bottomCameraOpened)
                        readonly property string bwSource: homePreviewRole < 2
                                                         ? ("image://opencvpreview/top?" + openCvPreviewManager.topFrameToken)
                                                         : ("image://opencvpreview/bottom?" + openCvPreviewManager.bottomFrameToken)
                        readonly property string colorSource: homePreviewRole < 2
                                                            ? ("image://opencvpreview/top_color?" + openCvPreviewManager.topFrameToken)
                                                            : ("image://opencvpreview/bottom_color?" + openCvPreviewManager.bottomFrameToken)
                        readonly property bool showColor: homePreviewRole === 1 || homePreviewRole === 3

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
                                text: homePreviewRole < 2
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
    }

    function genTestObject(){
        var ages = ["100", "300", "500", "1000"];
        function getRandomAge() {
            var randomIndex = Math.floor(Math.random() * ages.length);
            return ages[randomIndex];
        }
        var names = ["孙悟空", "猪八戒", "沙和尚", "唐僧","白骨夫人","金角大王","熊山君","黄风怪","银角大王"];
        function getRandomName(){
            var randomIndex = Math.floor(Math.random() * names.length);
            return names[randomIndex];
        }
        var y_addr = ["复海大圣","混天大圣","移山大圣","通风大圣","驱神大圣","齐天大圣","平天大圣"]
        function getRandomNickname(){
            var randomIndex = Math.floor(Math.random() * y_addr.length);
            return y_addr[randomIndex];
        }
        var x_addr = ["傲来国界花果山水帘洞","傲来国界坎源山脏水洞","大唐国界黑风山黑风洞","大唐国界黄风岭黄风洞","大唐国界骷髅山白骨洞","宝象国界碗子山波月洞","宝象国界平顶山莲花洞","宝象国界压龙山压龙洞","乌鸡国界号山枯松涧火云洞","乌鸡国界衡阳峪黑水河河神府"]
        function getRandomAddresses(){
            var randomIndex = Math.floor(Math.random() * x_addr.length);
            return x_addr[randomIndex];
        }
        var avatars = ["qrc:/qt/qml/content/svg/avatar_1.svg", "qrc:/qt/qml/content/svg/avatar_2.svg", "qrc:/qt/qml/content/svg/avatar_3.svg", "qrc:/qt/qml/content/svg/avatar_4.svg","qrc:/qt/qml/content/svg/avatar_5.svg","qrc:/qt/qml/content/svg/avatar_6.svg","qrc:/qt/qml/content/svg/avatar_7.svg","qrc:/qt/qml/content/svg/avatar_8.svg","qrc:/qt/qml/content/svg/avatar_9.svg","qrc:/qt/qml/content/svg/avatar_10.svg","qrc:/qt/qml/content/svg/avatar_11.svg","qrc:/qt/qml/content/svg/avatar_12.svg"];
        function getAvatar(){
            var randomIndex = Math.floor(Math.random() * avatars.length);
            return avatars[randomIndex];
        }
        return {
            rowIndex: '',
            selected: false,
            avatar: "TSSOP-20",
            name: getRandomName(),
            age:getRandomAge(),
            address: getRandomAddresses(),
            nickname: getRandomNickname(),
            longstring:"0",
            mounted: false,
            layer: "T",
            quantity: getRandomAge(),
            component_name: "TSSOP-20",
            _minimumHeight:50,
            _key:FluTools.uuid()
        }
    }
    function loadData(page,count){
        stopRunLoop()
        const dataSource = []
        const startIndex = (page - 1) * count + 1
        for(var i=0;i<count;i++){
            var obj = genTestObject()
            obj.rowIndex = startIndex + i
            dataSource.push(obj)
        }
        applyHomeTableData(dataSource)
    }
    function updateAllCheck() {
        let checkedCount = 0
        for (let i = 0; i < table_view.rows; i++) {
            if (table_view.getRow(i).checkbox.options.checked) {
                checkedCount += 1
            }
        }
        if (checkedCount > 0 && checkedCount === table_view.rows) {
            root.allCheckState = Qt.Checked
        } else if (checkedCount > 0 && checkedCount < table_view.rows) {
            root.allCheckState = Qt.PartiallyChecked
        } else {
            root.allCheckState = Qt.Unchecked
        }
    }
}
