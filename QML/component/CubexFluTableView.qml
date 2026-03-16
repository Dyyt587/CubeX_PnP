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
