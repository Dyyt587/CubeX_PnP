import QtQuick 2.15

Item {
    id: overlay
    anchors.fill: parent

    property bool active: true
    property int boxSize: 56
    property color lineColor: Qt.rgba(0.1, 1.0, 0.1, 0.85)

    visible: active

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: overlay.lineColor
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: overlay.lineColor
    }

    Rectangle {
        id: focusBox
        width: overlay.boxSize
        height: overlay.boxSize
        x: (overlay.width - width) / 2
        y: (overlay.height - height) / 2
        color: "transparent"
        border.width: 2
        border.color: Qt.rgba(0.1, 1.0, 0.1, 0.95)
        radius: 2

        Behavior on x {
            enabled: !dragArea.drag.active
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            enabled: !dragArea.drag.active
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            cursorShape: Qt.OpenHandCursor
            drag.target: parent
            drag.axis: Drag.XAndYAxis
            drag.minimumX: 0
            drag.minimumY: 0
            drag.maximumX: overlay.width - focusBox.width
            drag.maximumY: overlay.height - focusBox.height

            onPressed: cursorShape = Qt.ClosedHandCursor

            onReleased: {
                cursorShape = Qt.OpenHandCursor
                focusBox.x = (overlay.width - focusBox.width) / 2
                focusBox.y = (overlay.height - focusBox.height) / 2
            }
        }
    }
}
