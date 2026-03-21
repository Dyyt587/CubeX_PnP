import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import QtQuick.Dialogs
import QtWebView
import QtMultimedia
import FluentUI 1.0
import "../component"

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
    property var mw: mainWindow
    property bool runPaused: mainWindow.homeRunPaused
    property int runCurrentRow: mainWindow.homeRunCurrentRow
    property real mountedProgress: mainWindow.homeMountedProgress
    property int visibleRunCurrentRow: -1
    property real placementObjectWidthMm: gerberPreviewManager && gerberPreviewManager.boardWidthMm > 0 ? gerberPreviewManager.boardWidthMm : 15.748
    property real placementObjectHeightMm: gerberPreviewManager && gerberPreviewManager.boardHeightMm > 0 ? gerberPreviewManager.boardHeightMm : 25.527
    property var placementPreviewPoints: []
    property real placementZoom: 1.0
    property real placementPanX: 0
    property real placementPanY: 0
    property bool placementFillView: false
    property real placementMinZoom: 0.2
    property real placementMaxZoom: 8.0
    // true: 左下原点且 y 向上为正；false: 左下原点且 y 向下为正（历史负Y数据）。
    property bool placementBottomLeftYPositive: mainWindow.homePlacementBottomLeftYPositive
    property real placementOffsetXMm: mainWindow.homePlacementOffsetXMm
    property real placementOffsetYMm: mainWindow.homePlacementOffsetYMm
    signal checkBoxChanged
    signal runCurrentItemChanged(int rowIndex, var item)

    function resetPlacementView(fillView) {
        placementFillView = !!fillView
        placementZoom = 1.0
        placementPanX = 0
        placementPanY = 0
    }

    function clampPlacementPan() {
        if (!placementViewport || !placementImage) {
            return
        }
        // 允许任意一侧边缘拖到视口中心，而不仅仅是拖到视口边缘。
        var maxOffsetX = placementImage.width - 8
        var maxOffsetY = placementImage.height - 8
        placementPanX = Math.max(-maxOffsetX, Math.min(maxOffsetX, placementPanX))
        placementPanY = Math.max(-maxOffsetY, Math.min(maxOffsetY, placementPanY))
    }

    function zoomPlacement(factor) {
        if (!isFinite(factor) || factor <= 0) {
            return
        }
        var nextZoom = placementZoom * factor
        nextZoom = Math.max(placementMinZoom, Math.min(placementMaxZoom, nextZoom))
        if (nextZoom === placementZoom) {
            return
        }
        placementZoom = nextZoom
        clampPlacementPan()
    }

    function parseCoordinateMm(rawValue) {
        if (rawValue === undefined || rawValue === null) {
            return NaN
        }
        var text = String(rawValue)
        var match = text.match(/-?\d+(\.\d+)?/)
        if (!match || match.length <= 0) {
            return NaN
        }
        return Number(match[0])
    }

    // FluSpinBox 以整数工作，这里用 0.01mm 精度做换算。
    function offsetMmToSpin(valueMm) {
        return Math.round(valueMm * 100)
    }

    function spinToOffsetMm(spinValue) {
        return spinValue / 100.0
    }

    function offsetSpinValueFromText(textValue) {
        var cleaned = String(textValue).replace(/[^0-9+\-.]/g, "")
        var parsed = Number(cleaned)
        if (!isFinite(parsed)) {
            return 0
        }
        return offsetMmToSpin(parsed)
    }

    function offsetSpinTextFromValue(spinValue) {
        return spinToOffsetMm(spinValue).toFixed(2)
    }

    function resetHomePlacementAdjustments() {
        if (mainWindow && mainWindow.resetHomePlacementAdjustments) {
            mainWindow.resetHomePlacementAdjustments()
            return
        }
        if (mainWindow) {
            mainWindow.homePlacementBottomLeftYPositive = true
            mainWindow.homePlacementOffsetXMm = 0
            mainWindow.homePlacementOffsetYMm = 0
        }
    }

    function placementRowsForPreview() {
        var rows = mainWindow.homeTableData || []
        if (rows.length > 0) {
            return rows
        }
        if (table_view && typeof table_view.collectHomeRawRowsFromSource === "function") {
            return table_view.collectHomeRawRowsFromSource()
        }
        return []
    }

    function rebuildPlacementPreviewPoints() {
        var rows = placementRowsForPreview()
        var nextPoints = []
        var statsXMin = Number.POSITIVE_INFINITY
        var statsXMax = Number.NEGATIVE_INFINITY
        var statsYMin = Number.POSITIVE_INFINITY
        var statsYMax = Number.NEGATIVE_INFINITY
        var hasBoardSize = placementObjectWidthMm > 0.000001 && placementObjectHeightMm > 0.000001

        for (var s = 0; s < rows.length; s++) {
            var statRow = rows[s]
            if (!statRow) {
                continue
            }
            var statX = parseCoordinateMm(statRow.address)
            var statY = parseCoordinateMm(statRow.nickname)
            if (!isFinite(statX) || !isFinite(statY)) {
                continue
            }
            statsXMin = Math.min(statsXMin, statX)
            statsXMax = Math.max(statsXMax, statX)
            statsYMin = Math.min(statsYMin, statY)
            statsYMax = Math.max(statsYMax, statY)
        }

        var tolerance = 0.15
        var mode = hasBoardSize ? (placementBottomLeftYPositive ? "bottomLeftUpPositive" : "bottomLeftUpNegative") : "fitRange"
        if (isFinite(statsXMin) && isFinite(statsXMax) && isFinite(statsYMin) && isFinite(statsYMax)) {
            var xInObjectRange = statsXMin >= -placementObjectWidthMm * tolerance && statsXMax <= placementObjectWidthMm * (1 + tolerance)
            var yInNegativeRange = statsYMin >= -placementObjectHeightMm * (1 + tolerance) && statsYMax <= placementObjectHeightMm * tolerance
            var yInPositiveRange = statsYMin >= -placementObjectHeightMm * tolerance && statsYMax <= placementObjectHeightMm * (1 + tolerance)
            var xInCenterRange = statsXMin >= -placementObjectWidthMm * (0.5 + tolerance) && statsXMax <= placementObjectWidthMm * (0.5 + tolerance)
            var yInCenterRange = statsYMin >= -placementObjectHeightMm * (0.5 + tolerance) && statsYMax <= placementObjectHeightMm * (0.5 + tolerance)

            // 有板尺寸时优先按左下原点，并由开关决定 y 正方向。
            if (hasBoardSize) {
                if (xInObjectRange) {
                    mode = placementBottomLeftYPositive ? "bottomLeftUpPositive" : "bottomLeftUpNegative"
                } else if (xInCenterRange && yInCenterRange) {
                    mode = "centerUpPositive"
                }
            } else {
                if (xInObjectRange && yInNegativeRange) {
                    mode = "bottomLeftUpNegative"
                } else if (xInCenterRange && yInCenterRange) {
                    mode = "centerUpPositive"
                }
            }
        }

        for (var i = 0; i < rows.length; i++) {
            var row = rows[i]
            if (!row) {
                continue
            }

            var layerText = row.layer === undefined || row.layer === null ? "" : String(row.layer).trim().toUpperCase()
            if (layerText !== "T") {
                continue
            }
            if (!row.selected) {
                continue
            }

            var xMm = parseCoordinateMm(row.address)
            var yMm = parseCoordinateMm(row.nickname)
            if (!isFinite(xMm) || !isFinite(yMm)) {
                continue
            }

            var adjustedXmm = xMm + placementOffsetXMm
            var adjustedYmm = yMm + placementOffsetYMm

            var normalizedX
            var normalizedY
            if (mode === "bottomLeftUpPositive") {
                // 左下原点，x 向右正，y 向上正。
                normalizedX = adjustedXmm / placementObjectWidthMm
                normalizedY = 1 - (adjustedYmm / placementObjectHeightMm)
            } else if (mode === "bottomLeftUpNegative") {
                // 兼容历史负Y数据：y in [-H,0]，仍视作左下原点语义。
                normalizedX = adjustedXmm / placementObjectWidthMm
                normalizedY = -adjustedYmm / placementObjectHeightMm
            } else if (mode === "centerUpPositive") {
                // 中心原点，x 向右正，y 向上正。
                normalizedX = (adjustedXmm + placementObjectWidthMm / 2) / placementObjectWidthMm
                normalizedY = (-adjustedYmm + placementObjectHeightMm / 2) / placementObjectHeightMm
            } else {
                // 坐标范围无法判定时，按数据范围自适应，避免点被大量压到角落。
                var xDen = Math.max(0.000001, statsXMax - statsXMin)
                var yDen = Math.max(0.000001, statsYMax - statsYMin)
                normalizedX = (adjustedXmm - statsXMin) / xDen
                normalizedY = (statsYMax - adjustedYmm) / yDen
            }

            normalizedX = Math.max(0, Math.min(1, normalizedX))
            normalizedY = Math.max(0, Math.min(1, normalizedY))
            nextPoints.push({
                xNorm: normalizedX,
                yNorm: normalizedY,
                key: row._key || ("p_" + i)
            })
        }
        placementPreviewPoints = nextPoints
    }

    function warn(text) {
        showWarning(text)
    }

    function ok(text) {
        showSuccess(text)
    }

    function refreshHomeTableFromState() {
        table_view.setHomeRowsFromRaw(mainWindow.homeTableData, mainWindow.homeTablePageCurrent)
        if (mainWindow.homeTablePageCurrent > 0) {
            gagination.pageCurrent = mainWindow.homeTablePageCurrent
        }
    }

    function persistHomeTableData() {
        mainWindow.setHomeTableData(table_view.collectHomeRawRowsFromSource())
        mainWindow.homeTablePageCurrent = gagination.pageCurrent
    }

    function applyHomeTableData(data) {
        mainWindow.setHomeTableData(data)
        table_view.setHomeRowsFromRaw(mainWindow.homeTableData, gagination.pageCurrent)
        mainWindow.homeTablePageCurrent = gagination.pageCurrent
    }

    function updateMountedProgress() {
        mountedProgress = mainWindow.homeMountedProgress
    }

    function getCurrentRunItem() {
        return table_view.getHomeUiRowFromRaw(mainWindow.homeTableData, runCurrentRow)
    }

    function isRowSelected(rowIndex) {
        return mainWindow.isHomeRowSelected(rowIndex)
    }

    function findNextSelectedRow(startIndex) {
        return mainWindow.findNextSelectedHomeRow(startIndex)
    }

    function buildRowCommand(rowData) {
        return mainWindow.buildHomeRowCommand(table_view.homeExtractRawRow(rowData, rowData ? rowData.rowIndex : 0))
    }

    function sendSelectedRowsToController() {
        if (!serialPortManager || !serialPortManager.connected) {
            warn(qsTr("串口未连接，无法发送任务列表"))
            return false
        }
        if (!mainWindow.sendHomeSelectedRowsToController()) {
            warn(qsTr("没有可发送的勾选项"))
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
        // 叠加的 Rectangle 会自动跟随 runCurrentRow，这里只负责滚动视图到当前行
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
            ok(qsTr("流程执行完成"))
            return
        }
        var currentItem = getCurrentRunItem()
        syncCurrentRunHighlight()
        appendRunConsoleMessage(runCurrentRow, currentItem)
        runCurrentItemChanged(runCurrentRow, currentItem)
    }

    function startRunLoop() {
        if (mainWindow.homeTableData.length <= 0) {
            warn(qsTr("表格为空，无法开始"))
            return
        }

        var runOrder = table_view.buildRunOrderFromVisibleRows(mainWindow.homeTableData)
        if (!mainWindow.startHomeRun(runOrder)) {
            warn(qsTr("没有勾选项，无法开始"))
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
            warn(qsTr("Focus not acquired: Please click any item in the form as the target for insertion!"))
        }
    }

    function toggleRunOrPause() {
        if (runPaused) {
            startRunLoop()
            ok(qsTr("开始执行"))
        } else {
            pauseRunLoop()
            ok(qsTr("已暂停"))
        }
    }

    function stepRunOnce() {
        if (runCurrentRow < 0) {
            if (mainWindow.homeTableData.length <= 0) {
                warn(qsTr("表格为空，无法单步执行"))
                return
            }
            if (!mainWindow.stepHomeRun(table_view.buildRunOrderFromVisibleRows(mainWindow.homeTableData))) {
                warn(qsTr("没有勾选项，无法单步执行"))
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
        ok(qsTr("单步执行"))
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
    onPlacementBottomLeftYPositiveChanged: rebuildPlacementPreviewPoints()
    onPlacementOffsetXMmChanged: rebuildPlacementPreviewPoints()
    onPlacementOffsetYMmChanged: rebuildPlacementPreviewPoints()

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
        rebuildPlacementPreviewPoints()
    }

    Connections {
        target: mainWindow
        function onHomeTableDataChanged() {
            // 运行期间（尤其带排序时）避免整表 dataSource 重建，防止模型重排导致崩溃。
            // 页面可见时会在 onVisibleChanged 中主动同步一次。
            rebuildPlacementPreviewPoints()
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

    Connections {
        target: table_view
        function onRowsChanged() {
            // 兼容延迟加载/后台加载后仅更新表格模型但尚未同步到 mainWindow 的场景。
            rebuildPlacementPreviewPoints()
        }
    }

    Connections {
        target: gerberPreviewManager
        function onBoardSizeChanged() {
            rebuildPlacementPreviewPoints()
        }
    }

    function importFile(filePath) {
        var fileUrl = filePath ? filePath.toString() : ""
        var fileName = fileUrl.split("/").pop()
        // 导入新数据前先中止运行态，避免旧索引高亮引用已被替换的模型。
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
        
        // 将 CSV 数据转换为表格格式。
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
                avatar:  row.Footprint || row.footprint ||row.Device || row.device || "",
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
        resetHomePlacementAdjustments()
        Qt.callLater(function() {
            table_view.resizeHomeColumnsToContents()
        })

        gagination.pageCurrent = 1
        mainWindow.homeTablePageCurrent = 1

        root.allCheckState = Qt.Unchecked

       // updateMountedProgress()
        if (csvData.length > maxImportRows) {
                warn(qsTr("文件行数过大，仅加载 ") + maxImportRows + qsTr(" 行"))
        }
        
            ok(qsTr("文件已导入 ") + fileName + qsTr(" (") + importCount + qsTr(" 行)"))
    }

    function importGerberFile(filePath) {
        var fileUrl = filePath ? filePath.toString() : ""
        if (fileUrl === "") {
            var invalidMsg = qsTr("解析失败：请选择有效的 Gerber 文件")
            warn(invalidMsg)
            return
        }
        if (!gerberPreviewManager || !gerberPreviewManager.importGerber) {
            var mgrMsg = qsTr("解析失败：Gerber 预览管理器不可用")
            warn(mgrMsg)
            return
        }
        if (!gerberPreviewManager.importGerber(fileUrl)) {
            var err = gerberPreviewManager.lastError
            var failMsg = (err && err !== "") ? (qsTr("解析失败：") + err) : qsTr("解析失败：Gerber 导入失败")
            warn(failMsg)
            return
        }

        var widthText = Number(gerberPreviewManager.boardWidthMm).toFixed(3)
        var heightText = Number(gerberPreviewManager.boardHeightMm).toFixed(3)
        var okMsg = qsTr("解析成功：板子尺寸约为 ") + widthText + qsTr(" mm x ") + heightText + qsTr(" mm")
        ok(okMsg)
        resetHomePlacementAdjustments()
        rebuildPlacementPreviewPoints()
        resetPlacementView(false)
        ok(qsTr("Gerber 已导入并更新预览"))
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
            Qt.callLater(rebuildPlacementPreviewPoints)
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

                        Item {
                            id: placementViewport
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true

                            readonly property real imageAspect: {
                                if (!placementImage.sourceSize || placementImage.sourceSize.width <= 0 || placementImage.sourceSize.height <= 0) {
                                    return 1
                                }
                                return placementImage.sourceSize.width / placementImage.sourceSize.height
                            }
                            readonly property real viewportAspect: width > 0 && height > 0 ? width / height : 1
                            readonly property real baseImageWidth: {
                                if (placementFillView) {
                                    return imageAspect > viewportAspect ? height * imageAspect : width
                                }
                                return imageAspect > viewportAspect ? width : height * imageAspect
                            }
                            readonly property real baseImageHeight: {
                                if (placementFillView) {
                                    return imageAspect > viewportAspect ? height : width / imageAspect
                                }
                                return imageAspect > viewportAspect ? width / imageAspect : height
                            }

                            Image {
                                id: placementImage
                                width: placementViewport.baseImageWidth * root.placementZoom
                                height: placementViewport.baseImageHeight * root.placementZoom
                                x: (placementViewport.width - width) / 2 + root.placementPanX
                                y: (placementViewport.height - height) / 2 + root.placementPanY
                                source: gerberPreviewManager && gerberPreviewManager.previewUrl && gerberPreviewManager.previewUrl !== "" ? gerberPreviewManager.previewUrl : "qrc:/image/png/004914.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                                onWidthChanged: root.clampPlacementPan()
                                onHeightChanged: root.clampPlacementPan()
                            }

                            Item {
                                id: placementOverlay
                                x: placementImage.x + (placementImage.width - placementImage.paintedWidth) / 2
                                y: placementImage.y + (placementImage.height - placementImage.paintedHeight) / 2
                                width: placementImage.paintedWidth
                                height: placementImage.paintedHeight
                                visible: placementImage.status === Image.Ready && width > 0 && height > 0
                                clip: true

                                Repeater {
                                    model: root.placementPreviewPoints
                                    delegate: Rectangle {
                                        property var pointData: modelData
                                        width: 10
                                        height: 10
                                        radius: width / 2
                                        color: Qt.rgba(1, 0, 0, 0.18)
                                        border.color: "#FF2D2D"
                                        border.width: 1.5
                                        antialiasing: true
                                        x: pointData.xNorm * placementOverlay.width - width / 2
                                        y: pointData.yNorm * placementOverlay.height - height / 2
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                hoverEnabled: true
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                property real lastMouseX: 0
                                property real lastMouseY: 0

                                onPressed: {
                                    lastMouseX = mouse.x
                                    lastMouseY = mouse.y
                                }
                                onPositionChanged: {
                                    if (!(mouse.buttons & Qt.LeftButton)) {
                                        return
                                    }
                                    var dx = mouse.x - lastMouseX
                                    var dy = mouse.y - lastMouseY
                                    lastMouseX = mouse.x
                                    lastMouseY = mouse.y
                                    root.placementPanX += dx
                                    root.placementPanY += dy
                                    root.clampPlacementPan()
                                }
                                onWheel: function(wheel) {
                                    root.zoomPlacement(wheel.angleDelta.y > 0 ? 1.1 : 1 / 1.1)
                                    wheel.accepted = true
                                }
                            }

                            Column {
                                spacing: 8
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: 10
                                anchors.bottomMargin: placementAdjustPanel.height + 16

                                FluIconButton {
                                    iconSource: FluentIcons.FitPage
                                    onClicked: root.resetPlacementView(false)
                                }

                                FluIconButton {
                                    iconSource: FluentIcons.FullScreen
                                    onClicked: root.resetPlacementView(true)
                                }

                                FluIconButton {
                                    iconSource: FluentIcons.BackToWindow
                                    onClicked: {
                                        root.placementZoom = 1.0
                                        root.placementPanX = 0
                                        root.placementPanY = 0
                                        root.clampPlacementPan()
                                    }
                                }
                            }

                            FluFrame {
                                id: placementAdjustPanel
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: 10
                                anchors.bottomMargin: 10
                                padding: 8
                                // 固定为原面板(约260)的1.5倍，并限制不超过视口宽度，避免布局循环。
                                width: 260

                                Column {
                                    id: adjustPanelContent
                                    spacing: 6
                                    width: parent.width - placementAdjustPanel.padding * 2

                                    FluToggleSwitch {
                                        text: qsTr("Y向上为正")
                                        checked: root.placementBottomLeftYPositive
                                        onClicked: mainWindow.homePlacementBottomLeftYPositive = checked
                                    }

                                    Row {
                                        spacing: 6
                                        width: parent.width
                                        FluText {
                                            text: qsTr("X偏移(mm)")
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        FluSpinBox {
                                            width: 128
                                            editable: true
                                            from: -10000
                                            to: 10000
                                            stepSize: 1
                                            value: root.offsetMmToSpin(root.placementOffsetXMm)
                                            textFromValue: function(value, locale) {
                                                return root.offsetSpinTextFromValue(value)
                                            }
                                            valueFromText: function(text, locale) {
                                                return root.offsetSpinValueFromText(text)
                                            }
                                            onValueModified: {
                                                mainWindow.homePlacementOffsetXMm = root.spinToOffsetMm(value)
                                            }
                                            onValueChanged: {
                                                mainWindow.homePlacementOffsetXMm = root.spinToOffsetMm(value)
                                            }
                                        }
                                    }

                                    Row {
                                        spacing: 6
                                        width: parent.width
                                        FluText {
                                            text: qsTr("Y偏移(mm)")
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        FluSpinBox {
                                            width: 128
                                            editable: true
                                            from: -10000
                                            to: 10000
                                            stepSize: 1
                                            value: root.offsetMmToSpin(root.placementOffsetYMm)
                                            textFromValue: function(value, locale) {
                                                return root.offsetSpinTextFromValue(value)
                                            }
                                            valueFromText: function(text, locale) {
                                                return root.offsetSpinValueFromText(text)
                                            }
                                            onValueModified: {
                                                mainWindow.homePlacementOffsetYMm = root.spinToOffsetMm(value)
                                            }
                                            onValueChanged: {
                                                mainWindow.homePlacementOffsetYMm = root.spinToOffsetMm(value)
                                            }
                                        }
                                    }
                                }
                            }
                        }

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
                    onImportGerberClicked: dialogs.openImportGerberDialog()
                    onClearAllClicked: root.clearAllRows()
                    onDeleteSelectionClicked: root.deleteSelectionRows()
                    onAddRowClicked: root.addRowData()
                    onInsertRowClicked: root.insertRowData()
                    onRunToggleClicked: root.toggleRunOrPause()
                    onStopClicked: {
                        root.stopRunLoop()
                        ok(qsTr("已中止"))
                    }
                    onStepClicked: root.stepRunOnce()
                }

                CubexFluTableView{
                    id:table_view
                    highlightRow: root.visibleRunCurrentRow
                    useHomePreset: true
                    homeDelegates: delegates
                    homeNormalizer: mainWindow.normalizeHomeRow
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
            onPreviewRoleChanged: function(role) {
                root.homePreviewRole = role
            }
        }
    }

    function loadData(page,count){
        stopRunLoop()

        var csvFiles = csvFileReader.csvFilesInWorkingDirectory()
        if (!csvFiles || csvFiles.length === 0) {
            warn(qsTr("工作目录下未找到 CSV 文件"))
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
                    avatar:  row.Footprint || row.footprint || row.Device || row.device ||"",
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
        Qt.callLater(function() {
            table_view.resizeHomeColumnsToContents()
        })
        gagination.pageCurrent = 1
        mainWindow.homeTablePageCurrent = 1
        root.allCheckState = Qt.Unchecked
        updateMountedProgress()

        if (dataSource.length >= maxImportRows) {
            warn(qsTr("CSV 数据过多，仅加载 ") + maxImportRows + qsTr(" 行"))
        } else {
            ok(qsTr("已从工作目录加载 CSV，共 ") + dataSource.length + qsTr(" 行"))
        }
    }
    function updateAllCheck() {
        root.allCheckState = table_view.checkedRowsState()
    }
}


