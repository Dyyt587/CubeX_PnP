import QtQuick
import FluentUI

/**
 * CubexFluTableView
 *
 * 封装 FluTableView + 当前行高亮叠加层，对外暴露完整的 FluTableView API，
 * 并额外提供 highlightRow / highlightColor 两个属性控制高亮。
 */
Item {
    id: control

    // ── 高亮控制 ────────────────────────────────────────────────────────────────
    /// 要高亮的行索引（-1 = 无高亮）
    property int   highlightRow:   -1
    /// 高亮颜色
    property color highlightColor: Qt.rgba(0.45, 0.75, 1.0, 0.30)
    /// 默认高亮行高（当行高读取失败时作为兜底）
    property real highlightRowHeight: 42
    /// 启用 HomePage 专用列配置
    property bool useHomePreset: false
    /// HomePage 委托提供者（如 HomePageTableDelegates 实例）
    property var homeDelegates
    /// 分页参数（用于计算 startRowIndex）
    property int pageCurrent: 1
    property int itemPerPage: 1000

    // ── FluTableView 属性透传 ────────────────────────────────────────────────────
    property alias rows:                   _tableView.rows
    property alias columns:                _tableView.columns
    property alias columnSource:           _tableView.columnSource
    property alias dataSource:             _tableView.dataSource
    property alias selectedColor:          _tableView.selectedColor
    property alias startRowIndex:          _tableView.startRowIndex
    property alias horizonalHeaderVisible: _tableView.horizonalHeaderVisible
    property alias verticalHeaderVisible:  _tableView.verticalHeaderVisible
    property alias view:                   _tableView.view
    property alias sourceModel:            _tableView.sourceModel
    property alias current:                _tableView.current
    property alias columnWidthProvider:    _tableView.columnWidthProvider
    property alias rowHeightProvider:      _tableView.rowHeightProvider
    property alias borderColor:            _tableView.borderColor

    // ── FluTableView 方法代理 ────────────────────────────────────────────────────
    function customItem(comId, options)    { return _tableView.customItem(comId, options !== undefined ? options : {}) }
    function getRow(rowIndex)              { return _tableView.getRow(rowIndex) }
    function setRow(rowIndex, obj)         { _tableView.setRow(rowIndex, obj) }
    function removeRow(rowIndex, rows)     { _tableView.removeRow(rowIndex, rows !== undefined ? rows : 1) }
    function insertRow(rowIndex, obj)      { _tableView.insertRow(rowIndex, obj) }
    function appendRow(obj)                { _tableView.appendRow(obj) }
    function closeEditor()                 { _tableView.closeEditor() }
    function resetPosition()               { _tableView.resetPosition() }
    function sort(callback)                { _tableView.sort(callback) }
    function filter(callback)              { _tableView.filter(callback) }
    function currentIndex()                { return _tableView.currentIndex() }

    function buildRunOrderFromVisibleRows(rawRows) {
        var order = []
        var rowsData = rawRows || []
        var keyToRawIndex = {}
        for (var i = 0; i < rowsData.length; i++) {
            var raw = rowsData[i]
            if (!raw || !raw._key) {
                continue
            }
            keyToRawIndex[raw._key] = i
        }

        for (var row = 0; row < _tableView.rows; row++) {
            var visible = _tableView.getRow(row)
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

    function resolveVisibleRowByRawIndex(rawRows, rawRowIndex) {
        var rowsData = rawRows || []
        if (rawRowIndex < 0 || rawRowIndex >= rowsData.length) {
            return -1
        }
        var current = rowsData[rawRowIndex]
        if (!current || !current._key) {
            return -1
        }
        for (var i = 0; i < _tableView.rows; i++) {
            var row = _tableView.getRow(i)
            if (row && row._key === current._key) {
                return i
            }
        }
        return -1
    }

    function markMountedByRawIndex(rawRows, rawRowIndex, mountedDelegate) {
        var rowsData = rawRows || []
        if (rawRowIndex < 0 || rawRowIndex >= rowsData.length) {
            return
        }
        var target = rowsData[rawRowIndex]
        if (!target || !target._key) {
            return
        }
        for (var i = 0; i < _tableView.rows; i++) {
            var obj = _tableView.getRow(i)
            if (obj && obj._key === target._key) {
                obj.mounted = _tableView.customItem(mountedDelegate, {checked: true})
                _tableView.setRow(i, obj)
                return
            }
        }
    }

    function clearMountedChecks(mountedDelegate) {
        if (!_tableView.sourceModel) {
            return
        }
        var sourceModel = _tableView.sourceModel
        for (var i = 0; i < sourceModel.rowCount; i++) {
            var item = sourceModel.getRow(i)
            if (!item) {
                continue
            }
            item.mounted = _tableView.customItem(mountedDelegate, {checked: false})
            sourceModel.setRow(i, item)
        }
    }

    function checkedRowsState() {
        if (_tableView.rows <= 0) {
            return Qt.Unchecked
        }
        var checkedCount = 0
        for (var i = 0; i < _tableView.rows; i++) {
            var row = _tableView.getRow(i)
            if (row && row.checkbox && row.checkbox.options && row.checkbox.options.checked) {
                checkedCount += 1
            }
        }
        if (checkedCount > 0 && checkedCount === _tableView.rows) {
            return Qt.Checked
        }
        if (checkedCount > 0) {
            return Qt.PartiallyChecked
        }
        return Qt.Unchecked
    }

    function dataAfterDeletingSelected() {
        var data = []
        var visibleRows = []

        for (var i = 0; i < _tableView.rows; i++) {
            var item = _tableView.getRow(i)
            visibleRows.push(item)
            if (!item || !item.checkbox || !item.checkbox.options || !item.checkbox.options.checked) {
                data.push(item)
            }
        }

        var sourceModel = _tableView.sourceModel
        if (!sourceModel) {
            return data
        }

        for (i = 0; i < sourceModel.rowCount; i++) {
            var sourceItem = sourceModel.getRow(i)
            var foundItem = visibleRows.find(function(row) {
                return row && sourceItem && row._key === sourceItem._key
            })
            if (!foundItem) {
                data.push(sourceItem)
            }
        }
        return data
    }

    function updateStartRowIndex() {
        if (!useHomePreset) {
            return
        }
        _tableView.startRowIndex = (pageCurrent - 1) * itemPerPage + 1
    }

    function applyHomePresetColumns() {
        if (!useHomePreset || !homeDelegates) {
            return
        }
        _tableView.columnSource = [
            {
                title: _tableView.customItem(homeDelegates.com_column_checbox, {checked: true}),
                dataIndex: "checkbox",
                frozen: true
            },
            {
                title: _tableView.customItem(homeDelegates.com_column_filter_name, {title: qsTr("Name")}),
                dataIndex: "name",
                readOnly: true
            },
            {
                title: qsTr("封装"),
                dataIndex: "avatar",
                width: 150,
                minimumWidth: 100,
                maximumWidth: 250
            },
            {
                title: _tableView.customItem(homeDelegates.com_column_sort_age, {sort: 0}),
                dataIndex: "age",
                editDelegate: homeDelegates.com_combobox,
                width: 100,
                minimumWidth: 100,
                maximumWidth: 100
            },
            {
                title: qsTr("x坐标"),
                dataIndex: "address",
                editDelegate: homeDelegates.com_auto_suggestbox,
                width: 200,
                minimumWidth: 100,
                maximumWidth: 250
            },
            {
                title: qsTr("y坐标"),
                dataIndex: "nickname",
                width: 100,
                minimumWidth: 80,
                maximumWidth: 200
            },
            {
                title: qsTr("角度"),
                dataIndex: "longstring",
                width: 100,
                minimumWidth: 80,
                maximumWidth: 150
            },
            {
                title: qsTr("已贴装"),
                dataIndex: "mounted",
                width: 100,
                minimumWidth: 80,
                maximumWidth: 150
            },
            {
                title: _tableView.customItem(homeDelegates.com_column_filter_layer, {}),
                dataIndex: "layer",
                width: 80,
                minimumWidth: 60,
                maximumWidth: 120
            },
            {
                title: qsTr("器件名字"),
                dataIndex: "component_name",
                width: 120,
                minimumWidth: 100,
                maximumWidth: 200
            },
            {
                title: qsTr("Options"),
                dataIndex: "action",
                width: 160,
                frozen: true
            }
        ]
    }

    onUseHomePresetChanged: {
        applyHomePresetColumns()
        updateStartRowIndex()
    }
    onHomeDelegatesChanged: applyHomePresetColumns()
    onPageCurrentChanged: updateStartRowIndex()
    onItemPerPageChanged: updateStartRowIndex()

    Component.onCompleted: {
        applyHomePresetColumns()
        updateStartRowIndex()
    }

    // ── 内层表格 ────────────────────────────────────────────────────────────────
    FluTableView {
        id: _tableView
        anchors.fill: parent
    }

    // ── 当前行高亮叠加层 ─────────────────────────────────────────────────────────
    Item {
        z: 20
        x:      _tableView.view ? (_tableView.width  - _tableView.view.width) : 0
        y:      _tableView.view ? (_tableView.height - _tableView.view.height) : 0
        width:  _tableView.view ? _tableView.view.width : control.width
        height: _tableView.view ? _tableView.view.height : 0
        clip:   true

        Rectangle {
            id: _highlight
            visible: _tableView.rows > 0 && control.highlightRow >= 0 && control.highlightRow < _tableView.rows

            property real rowTop: {
                if (control.highlightRow < 0 || !_tableView.rowHeightProvider) {
                    return 0
                }
                var y = 0
                for (var i = 0; i < control.highlightRow; i++) {
                    y += _tableView.rowHeightProvider(i)
                }
                return y
            }
            property real rowH: {
                if (control.highlightRow < 0 || control.highlightRow >= _tableView.rows || !_tableView.rowHeightProvider) {
                    return control.highlightRowHeight
                }
                return _tableView.rowHeightProvider(control.highlightRow)
            }

            x:      0
            y:      _tableView.view ? (rowTop - _tableView.view.contentY) : 0
            width:  parent.width
            height: rowH
            color:  control.highlightColor
        }
    }
}
