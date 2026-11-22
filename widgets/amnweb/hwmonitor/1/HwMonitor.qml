pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Yasb
import Yasb.Bar
import Yasb.Common
import Yasb.Themes

Item {
    id: hwMonitor

    component PopupIcons: QtObject {
        property string pin
        property string unpin
    }

    component Settings: QtObject {
        required property Theme theme

        // Label placeholders: {cpu} {memory} {swap} {gpu} {gpu_fan} in %, {cpu_freq} in GHz, {cpu_cores}
        // {cpu_threads}, sizes such as 8.0G: {memory_used} {memory_total} {memory_available} {gpu_memory_used}
        // {gpu_memory_total}, {gpu_temp} in °C, {gpu_power} in W, speeds: {download} {upload}. :.0f after a name sets
        // the decimals, as {cpu:.0f}. An empty label hides its part. Right-click shows the alternate labels.
        property string cpuLabel: "{cpu:.0f}%"
        property string cpuAlternateLabel: "{cpu_freq:.2f} GHz"
        property string memoryLabel: "{memory:.0f}%"
        property string memoryAlternateLabel: "{memory_used}/{memory_total}"
        property string gpuLabel: "{gpu:.0f}%"
        property string gpuAlternateLabel: "{gpu_memory_used}/{gpu_memory_total}"
        // Milliseconds between readings, 2000 to 60000
        property int updateInterval: 2000
        property int gpuIndex: 0
        // The network adapter: "auto" for the one Windows uses for internet, or a name such as Ethernet or Wi-Fi
        property string interfaceName: "auto"
        property bool showNetwork: true
        property color graphColor: theme.colors.accent
        // Square grid lines behind the graphs
        property bool graphGrid: true
        property int graphHeight: 48
        property color meterColor: theme.colors.accent
        property int meterHeight: 4
        // The two lines of the network graph; upload is thinner and has no fill
        property color downloadColor: theme.colors.accent
        property color uploadColor: theme.colors.textSecondary
        // Glyphs in front of each part, drawn in iconFont and the text colour; "" for none
        property string cpuIcon: "\ueea1"
        property string memoryIcon: "\ueea0"
        property string gpuIcon: "\uf211"
        property int iconSize: theme.bar.iconFont.pixelSize
        // Between the CPU, memory and GPU parts on the bar
        property int partSpacing: 12
        // Hotkey that opens the popup, such as "alt+shift+h"
        property string hotkey: ""
        property int popupWidth: 420
        // Text on the bar takes the theme's colour, and labels the bar's font; parts set in font replace the bar's
        property color textColor: theme.colors.text
        property font font
        // Glyphs take the theme's icon font, each part unless the widget file sets it
        property font iconFont
        iconFont.family: theme.bar.iconFont.family
        iconFont.weight: theme.bar.iconFont.weight
        iconFont.variableAxes: theme.bar.iconFont.variableAxes
        // The popup: the theme's, unless set here
        property color popupColor: theme.popup.background
        property color popupBorderColor: theme.popup.border
        property color popupTextColor: theme.colors.text
        property real popupRadius: theme.popup.radius
        property real popupGap: theme.popup.gap
        // Text in the popup: the theme's font family, in this widget's sizes
        property font popupFont
        popupFont.family: theme.popup.font.family
        popupFont.pixelSize: 13
        property font popupSmallFont
        popupSmallFont.family: theme.popup.font.family
        popupSmallFont.pixelSize: 12
        property int popupOpenDuration: theme.popup.openDuration
        property int popupCloseDuration: theme.popup.closeDuration
        property color popupDividerColor: theme.colors.divider
        property color popupSecondaryTextColor: theme.colors.textSecondary
        property color popupTertiaryTextColor: theme.colors.textTertiary
        property color popupCardColor: theme.colors.card
        property color popupCardBorderColor: theme.colors.cardBorder
        // Behind the memory meter
        property color popupControlColor: theme.colors.control
        property font popupTitleFont
        popupTitleFont.family: theme.popup.font.family
        popupTitleFont.pixelSize: 16
        popupTitleFont.weight: 600
        readonly property PopupIcons popupIcons: PopupIcons {
            pin: "\ue840"
            unpin: "\ue77a"
        }
        property font popupIconFont
        popupIconFont.family: theme.popup.iconFont.family
        popupIconFont.weight: theme.popup.iconFont.weight
        popupIconFont.variableAxes: theme.popup.iconFont.variableAxes
        property int popupIconSize: 14
        // The usage beside each card's name
        property font valueFont
        valueFont.family: theme.popup.font.family
        valueFont.pixelSize: 20
        valueFont.weight: 700
    }

    required property BarBase bar
    readonly property Theme theme: bar.theme
    readonly property Settings settings: Settings {
        theme: hwMonitor.theme
    }

    property bool showAlternate: false
    property list<real> cpuHistory: []
    property list<real> gpuHistory: []
    property list<real> downloadHistory: []
    property list<real> uploadHistory: []

    readonly property string edge: bar.edge
    readonly property var placeholders: {
        const cpuData = cpuMonitor.data
        const memoryData = memoryMonitor.data
        const gpuData = gpuMonitor.data
        return {
            cpu: cpuData.percent.total,
            cpu_freq: cpuData.freq.current / 1000,
            cpu_cores: cpuData.cores.physical,
            cpu_threads: cpuData.cores.total,
            memory: memoryData.virtual.percent,
            memory_used: memoryData.virtual.used,
            memory_total: memoryData.virtual.total,
            memory_available: memoryData.virtual.available,
            swap: memoryData.swap.percent,
            gpu: gpuData.utilization,
            gpu_memory_used: gpuData.mem_used,
            gpu_memory_total: gpuData.mem_total,
            gpu_temp: gpuData.temp,
            gpu_fan: gpuData.fan_speed,
            gpu_power: gpuData.power_draw,
            download: networkMonitor.data.downloadRate,
            upload: networkMonitor.data.uploadRate
        }
    }
    // [icon, text] for each part shown on the bar
    readonly property var parts: [
        [settings.cpuIcon, format(showAlternate ? settings.cpuAlternateLabel : settings.cpuLabel)],
        [settings.memoryIcon, format(showAlternate ? settings.memoryAlternateLabel : settings.memoryLabel)],
        [settings.gpuIcon, gpuMonitor.available ? format(showAlternate ? settings.gpuAlternateLabel : settings.gpuLabel) : ""]
    ].filter(part => part[1] !== "")

    function size(bytes: real, decimals: int): string {
        if (Math.abs(bytes) < 1024)
            return `${Math.trunc(bytes)}B`
        const units = "KMGTPEZY"
        let unit = 1024
        let index = 0
        while (index < units.length - 1 && Math.abs(bytes) >= unit * 1024) {
            unit *= 1024
            ++index
        }
        return `${(bytes / unit).toFixed(decimals)}${units[index]}`
    }

    function usage(used: real, total: real): string {
        const units = ["Bytes", "KB", "MB", "GB", "TB", "PB"]
        let unit = 1
        let index = 0
        while (index < units.length - 1 && total >= unit * 1024) {
            unit *= 1024
            ++index
        }
        const digits = index === 0 ? 0 : 1
        return `${(used / unit).toFixed(digits)} / ${(total / unit).toFixed(digits)} ${units[index]}`
    }

    function amount(bytes: real): string {
        const units = ["Bytes", "KB", "MB", "GB", "TB", "PB"]
        let value = Math.max(0, bytes)
        let index = 0
        while (index < units.length - 1 && value >= 1024) {
            value /= 1024
            ++index
        }
        return `${value.toFixed(index === 0 ? 0 : 1)} ${units[index]}`
    }

    function speed(bytesPerSecond: real, decimals: int): string {
        const units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
        let value = Math.max(0, bytesPerSecond)
        let index = 0
        while (index < units.length - 1 && value >= 1024) {
            value /= 1024
            ++index
        }
        return `${value.toFixed(index === 0 ? 0 : decimals)} ${units[index]}`
    }

    function format(template: string): string {
        const values = placeholders
        const sizes = ["memory_used", "memory_total", "memory_available", "gpu_memory_used", "gpu_memory_total"]
        const speeds = ["download", "upload"]
        return template.replace(/\{(\w+)(?::\.(\d+)f)?\}/g, (match, key, decimals) => {
            if (!Object.prototype.hasOwnProperty.call(values, key))
                return match
            const value = values[key]
            if (sizes.includes(key))
                return size(value, decimals === undefined ? 1 : Number(decimals))
            if (speeds.includes(key))
                return speed(value, decimals === undefined ? 1 : Number(decimals))
            return decimals === undefined ? String(value) : value.toFixed(Number(decimals))
        })
    }

    function placePopup() {
        const start = mapToGlobal(0, 0)
        let px = edge === "left" ? start.x + width + settings.popupGap
            : edge === "right" ? start.x - popup.width - settings.popupGap : start.x + (width - popup.width) / 2
        let py = edge === "top" ? start.y + height + settings.popupGap
            : edge === "bottom" ? start.y - popup.height - settings.popupGap : start.y + (height - popup.height) / 2
        const screen = hwMonitor.Screen
        px = Math.max(screen.virtualX + 8, Math.min(px, screen.virtualX + screen.width - popup.width - 8))
        py = Math.max(screen.virtualY + 8, Math.min(py, screen.virtualY + screen.desktopAvailableHeight - popup.height - 8))
        popup.x = Math.round(px)
        popup.y = Math.round(py)
    }

    function togglePopup() {
        if (popup.visible)
            popup.close()
        else {
            placePopup()
            popup.open()
        }
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    visible: parts.length > 0

    Component.onDestruction: popup.hide()

    CpuMonitor {
        id: cpuMonitor

        updateInterval: hwMonitor.settings.updateInterval
        onDataChanged: hwMonitor.cpuHistory = [...hwMonitor.cpuHistory, cpuMonitor.data.percent.total].slice(-60)
    }

    MemoryMonitor {
        id: memoryMonitor

        updateInterval: hwMonitor.settings.updateInterval
    }

    GpuMonitor {
        id: gpuMonitor

        gpuIndex: hwMonitor.settings.gpuIndex
        updateInterval: hwMonitor.settings.updateInterval
        onDataChanged: hwMonitor.gpuHistory = [...hwMonitor.gpuHistory, gpuMonitor.data.utilization].slice(-60)
    }

    NetworkTrafficMonitor {
        id: networkMonitor

        interfaceName: hwMonitor.settings.interfaceName
        updateInterval: hwMonitor.settings.updateInterval
        onDataChanged: {
            hwMonitor.downloadHistory = [...hwMonitor.downloadHistory, networkMonitor.data.downloadRate].slice(-60)
            hwMonitor.uploadHistory = [...hwMonitor.uploadHistory, networkMonitor.data.uploadRate].slice(-60)
        }
    }

    Connections {
        target: hwMonitor.Window.window
        function onVisibleChanged() {
            if (!hwMonitor.Window.window?.visible)
                popup.hide()
        }
        function onXChanged() { if (popup.visible && !popup.pinned) hwMonitor.placePopup() }
        function onYChanged() { if (popup.visible && !popup.pinned) hwMonitor.placePopup() }
    }

    // Keep the popup anchored when its height changes
    Connections {
        target: popup
        function onHeightChanged() { if (popup.visible && !popup.pinned) hwMonitor.placePopup() }
    }

    Row {
        id: row

        height: parent.height
        spacing: hwMonitor.settings.partSpacing

        Repeater {
            model: hwMonitor.parts

            delegate: Row {
                id: part

                required property var modelData

                height: row.height
                spacing: 4

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: part.modelData[0] !== ""
                    text: part.modelData[0]
                    color: hwMonitor.settings.textColor
                    font.family: hwMonitor.settings.iconFont.family
                    font.weight: hwMonitor.settings.iconFont.weight
                    font.variableAxes: hwMonitor.settings.iconFont.variableAxes
                    font.pixelSize: hwMonitor.settings.iconSize
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: part.modelData[1]
                    textFormat: Text.PlainText
                    color: hwMonitor.settings.textColor
                    font: hwMonitor.settings.font
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                hwMonitor.togglePopup()
            else
                hwMonitor.showAlternate = !hwMonitor.showAlternate
        }
    }

    Hotkey {
        keys: hwMonitor.settings.hotkey
        onActivated: hwMonitor.togglePopup()
    }

    BackdropPopup {
        id: popup

        property real reveal: 0
        readonly property bool networkShown: hwMonitor.settings.showNetwork && networkMonitor.data.connected
        // The top of the network graph: the fastest download or upload it shows
        readonly property real networkPeak: Math.max(0, ...hwMonitor.downloadHistory, ...hwMonitor.uploadHistory)
        readonly property var cpuText: {
            const freq = cpuMonitor.data.freq
            const current = `${(freq.current / 1000).toFixed(2)} GHz`
            return freq.max > 0 ? `${current} · base ${(freq.max / 1000).toFixed(2)} GHz` : current
        }
        readonly property var memoryStats: {
            const data = memoryMonitor.data
            return [
                ["In use", hwMonitor.usage(data.virtual.used, data.virtual.total)],
                ["Available", hwMonitor.amount(data.virtual.available)],
                ["Cached", hwMonitor.amount(data.cached_bytes)],
                ["Swap used", hwMonitor.usage(data.swap.used, data.swap.total)]
            ]
        }
        readonly property var gpuStats: {
            const data = gpuMonitor.data
            const cells = [["Video memory", hwMonitor.usage(data.mem_used, data.mem_total)]]
            if (data.temp > 0)
                cells.push(["Temperature", `${data.temp}°C`])
            if (data.fan_speed > 0)
                cells.push(["Fan", `${data.fan_speed}%`])
            if (data.power_draw > 0)
                cells.push(["Power draw", `${data.power_draw.toFixed(1)} W`])
            if (data.mem_shared_total > 0)
                cells.push(["Shared memory", hwMonitor.usage(data.mem_shared_used, data.mem_shared_total)])
            return cells
        }

        objectName: "menu"
        title: "Hardware monitor"
        width: hwMonitor.settings.popupWidth
        height: popupContent.implicitHeight
        anchor: hwMonitor
        font: hwMonitor.settings.popupFont
        theme: hwMonitor.theme
        backdropItem: surface
        enter: NumberAnimation { target: popup; property: "reveal"; to: 1; duration: hwMonitor.settings.popupOpenDuration; easing.type: Easing.OutCubic }
        exit: NumberAnimation { target: popup; property: "reveal"; to: 0; duration: hwMonitor.settings.popupCloseDuration; easing.type: Easing.InCubic }
        onVisibleChanged: {
            if (!visible) {
                reveal = 0
                pinned = false
            }
        }

        Rectangle {
            id: surface

            anchors.fill: parent
            radius: hwMonitor.settings.popupRadius
            color: hwMonitor.settings.popupColor
            border.width: 1
            border.color: hwMonitor.settings.popupBorderColor
            opacity: popup.reveal
            scale: 0.85 + popup.reveal * 0.15
            transformOrigin: hwMonitor.edge === "bottom" ? Item.Bottom : Item.Top

            ColumnLayout {
                id: popupContent

                width: parent.width
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 10
                    Layout.topMargin: 12
                    Layout.bottomMargin: 10

                    Text {
                        Layout.fillWidth: true
                        text: "Hardware monitor"
                        font: hwMonitor.settings.popupTitleFont
                        color: hwMonitor.settings.popupTextColor

                        MouseArea {
                            property point grab

                            anchors.fill: parent
                            enabled: popup.pinned
                            cursorShape: popup.pinned ? Qt.SizeAllCursor : Qt.ArrowCursor
                            onPressed: mouse => grab = Qt.point(popup.x - mapToGlobal(mouse.x, mouse.y).x,
                                popup.y - mapToGlobal(mouse.x, mouse.y).y)
                            onPositionChanged: mouse => {
                                const at = mapToGlobal(mouse.x, mouse.y)
                                popup.x = at.x + grab.x
                                popup.y = at.y + grab.y
                            }
                        }
                    }

                    Item {
                        implicitWidth: 28
                        implicitHeight: 28
                        Accessible.role: Accessible.Button
                        Accessible.name: popup.pinned ? "Unpin this window" : "Pin this window"
                        Accessible.onPressAction: popup.pinned = !popup.pinned

                        Text {
                            anchors.centerIn: parent
                            text: popup.pinned ? hwMonitor.settings.popupIcons.unpin : hwMonitor.settings.popupIcons.pin
                            color: hwMonitor.settings.popupTextColor
                            opacity: popup.pinned ? 1 : 0.6
                            font.family: hwMonitor.settings.popupIconFont.family
                            font.weight: hwMonitor.settings.popupIconFont.weight
                            font.variableAxes: hwMonitor.settings.popupIconFont.variableAxes
                            font.pixelSize: hwMonitor.settings.popupIconSize
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: popup.pinned = !popup.pinned
                        }
                    }
                }
                // The header's bottom line
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: hwMonitor.settings.popupDividerColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: 14
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: cpuCard.implicitHeight + 20
                        radius: 8
                        color: hwMonitor.settings.popupCardColor
                        border.width: 1
                        border.color: hwMonitor.settings.popupCardBorderColor

                        ColumnLayout {
                            id: cpuCard

                            x: 12
                            y: 10
                            width: parent.width - 24
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: "CPU"
                                    color: hwMonitor.settings.popupSecondaryTextColor
                                    font: hwMonitor.settings.popupFont
                                }

                                Text {
                                    text: `${cpuMonitor.data.percent.total.toFixed(0)}%`
                                    color: hwMonitor.settings.popupTextColor
                                    font: hwMonitor.settings.valueFont
                                }
                            }

                            HistoryGraph {
                                Layout.fillWidth: true
                                Layout.preferredHeight: hwMonitor.settings.graphHeight
                                values: hwMonitor.cpuHistory
                                lineColor: hwMonitor.settings.graphColor
                                gridColor: Qt.alpha(hwMonitor.settings.popupTextColor, 0.05)
                                grid: hwMonitor.settings.graphGrid
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: popup.cpuText
                                    color: hwMonitor.settings.popupTertiaryTextColor
                                    font: hwMonitor.settings.popupSmallFont
                                }

                                Text {
                                    text: `${cpuMonitor.data.cores.physical} cores · ${cpuMonitor.data.cores.total} threads`
                                    color: hwMonitor.settings.popupTertiaryTextColor
                                    font: hwMonitor.settings.popupSmallFont
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: memoryCard.implicitHeight + 20
                        radius: 8
                        color: hwMonitor.settings.popupCardColor
                        border.width: 1
                        border.color: hwMonitor.settings.popupCardBorderColor

                        ColumnLayout {
                            id: memoryCard

                            x: 12
                            y: 10
                            width: parent.width - 24
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: "Memory"
                                    color: hwMonitor.settings.popupSecondaryTextColor
                                    font: hwMonitor.settings.popupFont
                                }

                                Text {
                                    text: `${memoryMonitor.data.virtual.percent.toFixed(0)}%`
                                    color: hwMonitor.settings.popupTextColor
                                    font: hwMonitor.settings.valueFont
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: hwMonitor.settings.meterHeight
                                radius: height / 2
                                color: hwMonitor.settings.popupControlColor

                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(memoryMonitor.data.virtual.percent, 100)) / 100
                                    height: parent.height
                                    radius: height / 2
                                    color: hwMonitor.settings.meterColor
                                }
                            }

                            StatGrid {
                                Layout.fillWidth: true
                                stats: popup.memoryStats
                                nameColor: hwMonitor.settings.popupTertiaryTextColor
                                valueColor: hwMonitor.settings.popupTextColor
                                nameFont: hwMonitor.settings.popupSmallFont
                                valueFont: hwMonitor.settings.popupFont
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: gpuMonitor.available
                        implicitHeight: gpuCard.implicitHeight + 20
                        radius: 8
                        color: hwMonitor.settings.popupCardColor
                        border.width: 1
                        border.color: hwMonitor.settings.popupCardBorderColor

                        ColumnLayout {
                            id: gpuCard

                            x: 12
                            y: 10
                            width: parent.width - 24
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: gpuMonitor.data.name ? `GPU · ${gpuMonitor.data.name}` : "GPU"
                                    color: hwMonitor.settings.popupSecondaryTextColor
                                    font: hwMonitor.settings.popupFont
                                }

                                Text {
                                    text: `${gpuMonitor.data.utilization.toFixed(0)}%`
                                    color: hwMonitor.settings.popupTextColor
                                    font: hwMonitor.settings.valueFont
                                }
                            }

                            HistoryGraph {
                                Layout.fillWidth: true
                                Layout.preferredHeight: hwMonitor.settings.graphHeight
                                values: hwMonitor.gpuHistory
                                lineColor: hwMonitor.settings.graphColor
                                gridColor: Qt.alpha(hwMonitor.settings.popupTextColor, 0.05)
                                grid: hwMonitor.settings.graphGrid
                            }

                            StatGrid {
                                Layout.fillWidth: true
                                stats: popup.gpuStats
                                nameColor: hwMonitor.settings.popupTertiaryTextColor
                                valueColor: hwMonitor.settings.popupTextColor
                                nameFont: hwMonitor.settings.popupSmallFont
                                valueFont: hwMonitor.settings.popupFont
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: popup.networkShown
                        implicitHeight: networkCard.implicitHeight + 20
                        radius: 8
                        color: hwMonitor.settings.popupCardColor
                        border.width: 1
                        border.color: hwMonitor.settings.popupCardBorderColor

                        ColumnLayout {
                            id: networkCard

                            x: 12
                            y: 10
                            width: parent.width - 24
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: networkMonitor.data.adapterName ? `Network · ${networkMonitor.data.adapterName}` : "Network"
                                    color: hwMonitor.settings.popupSecondaryTextColor
                                    font: hwMonitor.settings.popupFont
                                }

                                Text {
                                    text: `peak ${hwMonitor.speed(popup.networkPeak, 1)}`
                                    color: hwMonitor.settings.popupTertiaryTextColor
                                    font: hwMonitor.settings.popupSmallFont
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: hwMonitor.settings.graphHeight

                                HistoryGraph {
                                    anchors.fill: parent
                                    values: hwMonitor.downloadHistory
                                    maximum: popup.networkPeak
                                    lineColor: hwMonitor.settings.downloadColor
                                    gridColor: Qt.alpha(hwMonitor.settings.popupTextColor, 0.05)
                                    grid: hwMonitor.settings.graphGrid
                                }

                                HistoryGraph {
                                    anchors.fill: parent
                                    values: hwMonitor.uploadHistory
                                    maximum: popup.networkPeak
                                    lineColor: hwMonitor.settings.uploadColor
                                    lineWidth: 1.5
                                    fill: false
                                    grid: false
                                }
                            }

                            Row {
                                spacing: 18

                                Repeater {
                                    // [name, line colour, speed]
                                    model: [
                                        ["Download", hwMonitor.settings.downloadColor, networkMonitor.data.downloadRate],
                                        ["Upload", hwMonitor.settings.uploadColor, networkMonitor.data.uploadRate]
                                    ]

                                    delegate: Row {
                                        id: legend

                                        required property var modelData

                                        spacing: 6

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 10
                                            height: 2
                                            color: legend.modelData[1]
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: legend.modelData[0]
                                            color: hwMonitor.settings.popupTertiaryTextColor
                                            font: hwMonitor.settings.popupSmallFont
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: hwMonitor.speed(legend.modelData[2], 1)
                                            color: hwMonitor.settings.popupTextColor
                                            font: hwMonitor.settings.popupFont
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
