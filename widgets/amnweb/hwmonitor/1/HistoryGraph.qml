import QtQuick
import QtQuick.Shapes

Item {
    id: graph

    // Oldest first
    property list<real> values: []
    // The value at the top of the graph
    property real maximum: 100
    property color lineColor
    property real lineWidth: 2
    // A gradient under the line
    property bool fill: true
    property color gridColor
    property bool grid: true

    readonly property var points: values.map((value, index) => Qt.point(
        values.length > 1 ? index * width / (values.length - 1) : width,
        1 + (height - 2) * (1 - (maximum > 0 ? Math.max(0, Math.min(value / maximum, 1)) : 0))))
    readonly property string line: spline(points)
    readonly property string gridPath: {
        if (!grid || width <= 0 || height <= 0)
            return ""
        const lines = [`M 0 0.5 L ${width} 0.5`, `M 0.5 0 L 0.5 ${height}`]
        for (let y = height - 0.5; y > 0; y -= 16)
            lines.push(`M 0 ${y} L ${width} ${y}`)
        for (let x = width - 0.5; x > 0; x -= 16)
            lines.push(`M ${x} 0 L ${x} ${height}`)
        return lines.join(" ")
    }

    function spline(points: var): string {
        if (points.length < 2)
            return ""
        let path = `M ${points[0].x} ${points[0].y}`
        const last = points.length - 1
        for (let index = 0; index < last; ++index) {
            const p0 = points[Math.max(0, index - 1)]
            const p1 = points[index]
            const p2 = points[index + 1]
            const p3 = points[Math.min(last, index + 2)]
            const low = Math.min(p1.y, p2.y)
            const high = Math.max(p1.y, p2.y)
            const y1 = Math.max(low, Math.min(p1.y + (p2.y - p0.y) * 0.2, high))
            const y2 = Math.max(low, Math.min(p2.y - (p3.y - p1.y) * 0.2, high))
            path += ` C ${p1.x + (p2.x - p0.x) * 0.2} ${y1} ${p2.x - (p3.x - p1.x) * 0.2} ${y2} ${p2.x} ${p2.y}`
        }
        return path
    }

    Shape {
        anchors.fill: parent
        visible: graph.gridPath !== ""

        ShapePath {
            fillColor: "transparent"
            strokeColor: graph.gridColor
            strokeWidth: 1

            PathSvg {
                path: graph.gridPath
            }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                y2: graph.height

                GradientStop {
                    position: 0
                    color: Qt.alpha(graph.lineColor, 100 / 255)
                }

                GradientStop {
                    position: 1
                    color: Qt.alpha(graph.lineColor, 10 / 255)
                }
            }

            PathSvg {
                path: graph.fill && graph.line ? `M 0 ${graph.height} L ${graph.line.slice(2)} L ${graph.width} ${graph.height} Z` : ""
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: graph.lineColor
            strokeWidth: graph.lineWidth
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.BevelJoin

            PathSvg {
                path: graph.line
            }
        }
    }
}
