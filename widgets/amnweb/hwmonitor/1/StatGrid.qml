pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

GridLayout {
    id: grid

    // Rows of [name, value]; the right column is right-aligned
    property var stats: []
    property color nameColor
    property color valueColor
    property font nameFont
    property font valueFont

    columns: 2
    columnSpacing: 12
    rowSpacing: 8
    uniformCellWidths: true

    Repeater {
        model: grid.stats.length

        delegate: ColumnLayout {
            id: stat

            required property int index
            readonly property var row: grid.stats[index] ?? ["", ""]
            readonly property int alignment: index % 2 ? Text.AlignRight : Text.AlignLeft

            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                horizontalAlignment: stat.alignment
                elide: Text.ElideRight
                text: stat.row[0]
                color: grid.nameColor
                font: grid.nameFont
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: stat.alignment
                elide: Text.ElideRight
                text: stat.row[1]
                color: grid.valueColor
                font: grid.valueFont
            }
        }
    }
}
