pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Yasb
import Yasb.Bar
import Yasb.Common
import Yasb.Themes

Item {
    id: claude

    component Icons: QtObject {
        // After the label while Claude Code's sign-in has run out
        property string expired
        property string refresh
    }

    component Settings: QtObject {
        required property Theme theme

        // How often the usage is fetched, in milliseconds, from 30000 to 3600000; Anthropic limits how often it answers
        property int updateInterval: 120000
        // Whether Claude Code's session logs are scanned for the tokens it used, shown in the popup; the scan runs in the
        // background, and the section shows once it ends
        property bool tokenHistory: true
        // How often the logs are scanned, in milliseconds, from 30000 to 3600000
        property int scanInterval: 120000
        // Whether tokens read back from the prompt cache count in the totals; they are most of a long session's tokens
        property bool countCacheRead: true
        // "monday" or "sunday"
        property string weekStartsOn: "monday"
        // Whether Claude's status is checked and shown in the popup
        property bool checkStatus: true
        // How often the status is checked, in milliseconds, from 60000 to 3600000
        property int statusInterval: 300000
        // "24h" or "12h"
        property string timeFormat: "24h"
        // Label placeholders: {five_hour}, {seven_day}, {five_hour_reset}, {seven_day_reset}, {session_tokens},
        // {today_tokens}, {week_tokens}, {month_tokens}, {year_tokens} and {status_text}
        property string label: "Claude {five_hour}%"
        property string alternateLabel: "Claude {seven_day}%"
        // The label while Claude Code is not signed in, so there are no limits but there is the token history
        property string signedOutLabel: "Claude {today_tokens}"
        // The period the token history opens on: session, today, week, month or year
        property string defaultPeriod: "today"
        // The warning glyph after the label while Claude Code's sign-in has run out
        property bool showExpired: true
        property bool tooltip: true
        // Hotkey that opens the popup, such as "alt+shift+c"
        property string hotkey: ""
        // Usage under 50% takes accentColor, under 80% cautionColor, and from 80% criticalColor
        property color accentColor: theme.colors.accent
        property color cautionColor: theme.colors.warning
        property color criticalColor: theme.colors.critical
        // Claude's status: all good, and the dot while it is not known
        property color successColor: theme.colors.success
        property color unknownColor: theme.colors.textDisabled
        // Text on the bar takes the theme's colour, and the bar's font; parts set in font replace the bar's
        property color textColor: theme.colors.text
        property font font
        property font iconFont
        iconFont.family: theme.bar.iconFont.family
        iconFont.weight: theme.bar.iconFont.weight
        iconFont.variableAxes: theme.bar.iconFont.variableAxes
        readonly property Icons icons: Icons {
            expired: "\ue7ba"
            refresh: "\ue72c"
        }
        property int popupWidth: 360
        // Popup alignment relative to the widget on a horizontal bar: "left", "right" or "center"
        property string popupAlignment: "center"
        // The popup: the theme's, unless set here
        property color popupColor: theme.popup.background
        property color popupBorderColor: theme.popup.border
        property color popupTextColor: theme.colors.text
        // Supporting text, and labels, times and other text to read last
        property color popupSecondaryTextColor: theme.colors.textSecondary
        property color popupMutedTextColor: theme.colors.textTertiary
        property color popupDividerColor: theme.colors.divider
        property color popupHoverColor: theme.colors.hover
        // The empty part of the usage bars
        property color meterTrackColor: theme.colors.control
        // The strip at the bottom with the link and the time
        property color popupFooterColor: theme.colors.backgroundSecondary
        property real popupRadius: theme.popup.radius
        property real popupGap: theme.popup.gap
        property int popupOpenDuration: theme.popup.openDuration
        property int popupCloseDuration: theme.popup.closeDuration
        // Text in the popup: the theme's font family, in this widget's sizes
        property font popupFont
        popupFont.family: theme.popup.font.family
        popupFont.pixelSize: 13
        property font popupSmallFont
        popupSmallFont.family: theme.popup.font.family
        popupSmallFont.pixelSize: 12
        property font popupTitleFont
        popupTitleFont.family: theme.popup.font.family
        popupTitleFont.pixelSize: 14
        popupTitleFont.weight: 600
        // A limit's name and how much of it is used
        property font limitFont
        limitFont.family: theme.popup.font.family
        limitFont.pixelSize: 14
        // The token total of the period
        property font totalFont
        totalFont.family: theme.popup.font.family
        totalFont.pixelSize: 20
        totalFont.weight: 600
        property font popupIconFont
        popupIconFont.family: theme.popup.iconFont.family
        popupIconFont.weight: theme.popup.iconFont.weight
        popupIconFont.variableAxes: theme.popup.iconFont.variableAxes
    }

    component Glyph: Text {
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: claude.settings.popupIconFont.family
        font.weight: claude.settings.popupIconFont.weight
        font.variableAxes: claude.settings.popupIconFont.variableAxes
    }

    // Text in the popup: plain, cut short with an ellipsis rather than widening a row
    component PopupText: Text {
        Layout.minimumWidth: 0
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: claude.settings.popupTextColor
        font: claude.settings.popupFont
    }

    // A line between the popup's parts
    component Divider: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: claude.settings.popupDividerColor
    }

    // A bar filled to a part of its width, from 0 to 1
    component Meter: Rectangle {
        property real part: 0
        property color fill: claude.settings.accentColor

        implicitHeight: 4
        radius: height / 2
        color: claude.settings.meterTrackColor

        Rectangle {
            width: parent.width * Math.max(0, Math.min(parent.part, 1))
            height: parent.height
            radius: parent.radius
            visible: parent.part > 0
            color: parent.fill
        }
    }

    component Link: Text {
        id: link

        signal clicked

        textFormat: Text.PlainText
        color: linkArea.containsMouse ? claude.settings.popupTextColor : claude.settings.popupSecondaryTextColor
        font: claude.settings.popupSmallFont
        Accessible.role: Accessible.Link
        Accessible.name: text
        Accessible.onPressAction: link.clicked()

        MouseArea {
            id: linkArea

            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicked()
        }
    }

    required property BarBase bar
    readonly property Theme theme: bar.theme
    readonly property Settings settings: Settings {
        theme: claude.theme
    }

    property bool showAlternate: false

    readonly property string edge: bar.edge
    readonly property string text: format(!usage.signedIn ? settings.signedOutLabel
        : showAlternate ? settings.alternateLabel : settings.label)
    // When the usage was fetched: the time today, the day and time before
    readonly property string updated: {
        const at = usage.updated
        if (!(at instanceof Date) || isNaN(at))
            return ""
        const time = Qt.formatTime(at, settings.timeFormat === "12h" ? "h:mm AP" : "HH:mm")
        return at.toDateString() === new Date().toDateString() ? time
            : `${Qt.locale().dayName(at.getDay(), Locale.ShortFormat)} ${time}`
    }

    readonly property string powershell: (Environment.value("SystemRoot") || "C:/Windows")
        + "/System32/WindowsPowerShell/v1.0/powershell.exe"
    readonly property string scriptPath: decodeURIComponent(Qt.resolvedUrl("claude_usage.ps1").toString()
        .replace(/^file:\/\/\/(?=[A-Za-z]:)/, "").replace(/^file:/, ""))
    readonly property int usageInterval: Math.max(30000, Math.min(3600000, settings.updateInterval))

    function format(template: string): string {
        return template.replace(/\{(\w+)\}/g, (match, key) => usage.values[key] ?? match)
    }

    function levelColor(level: string): color {
        return level === "high" ? settings.criticalColor : level === "medium" ? settings.cautionColor : settings.accentColor
    }

    // A token count in a few characters: 950, 12.3K, 4.5M, 1.2B
    function compact(tokens: var): string {
        const value = Number(tokens ?? 0)
        for (const [size, suffix] of [[1e9, "B"], [1e6, "M"], [1e3, "K"]]) {
            if (value >= size)
                return `${(value / size).toFixed(1).replace(/\.0$/, "")}${suffix}`
        }
        return String(value)
    }

    function statusColor(indicator: string): color {
        return indicator === "none" ? settings.successColor : indicator === "minor" ? settings.cautionColor
            : indicator === "major" || indicator === "critical" ? settings.criticalColor : settings.unknownColor
    }

    function placePopup() {
        const start = mapToGlobal(0, 0)
        const gap = settings.popupGap
        const margin = 8
        const screen = claude.Screen
        let px
        let py
        switch (edge) {
        case "left":
            px = start.x + width + gap
            py = start.y + (height - popup.height) / 2
            break
        case "right":
            px = start.x - popup.width - gap
            py = start.y + (height - popup.height) / 2
            break
        default:
            px = settings.popupAlignment === "left" ? start.x
                : settings.popupAlignment === "right" ? start.x + width - popup.width : start.x + (width - popup.width) / 2
            py = edge === "bottom" ? start.y - popup.height - gap : start.y + height + gap
            break
        }
        popup.x = Math.round(Math.max(screen.virtualX + margin,
            Math.min(px, screen.virtualX + screen.width - popup.width - margin)))
        popup.y = Math.round(Math.max(screen.virtualY + margin,
            Math.min(py, screen.virtualY + screen.desktopAvailableHeight - popup.height - margin)))
    }

    function togglePopup() {
        if (popup.visible) {
            popup.close()
            return
        }
        popup.period = settings.defaultPeriod
        placePopup()
        popup.open()
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: usage.ready ? qsTr("Claude usage, 5-hour %1%, 7-day %2%").arg(usage.values.five_hour).arg(usage.values.seven_day)
        : qsTr("Claude usage")
    Accessible.onPressAction: togglePopup()
    Keys.onReturnPressed: togglePopup()
    Keys.onSpacePressed: togglePopup()

    // The popup is a window of its own, so it goes when the widget does
    Component.onDestruction: popup.hide()

    Process {
        id: limitsRequest

        property bool force: false

        command: [claude.powershell, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "RemoteSigned",
            "-File", claude.scriptPath, "usage", String(claude.usageInterval), force ? "force" : "cached"]
        format: "json"
        interval: claude.usageInterval
        timeout: 25000
        active: claude.visible
        onFinished: force = false
        onFailed: force = false
    }

    Process {
        id: historyRequest

        command: [claude.powershell, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "RemoteSigned",
            "-File", claude.scriptPath, "history"]
        format: "json"
        interval: Math.max(30000, Math.min(3600000, claude.settings.scanInterval))
        timeout: 120000
        active: claude.visible && claude.settings.tokenHistory
    }

    Process {
        id: statusRequest

        command: [claude.powershell, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "RemoteSigned",
            "-File", claude.scriptPath, "status"]
        format: "json"
        interval: Math.max(60000, Math.min(3600000, claude.settings.statusInterval))
        timeout: 25000
        active: claude.visible && claude.settings.checkStatus
    }

    // Moves the reset times on between fetches
    Timer {
        interval: 30000
        repeat: true
        running: claude.visible
        onTriggered: usage.now = Date.now()
    }

    QtObject {
        id: usage

        property double now: Date.now()
        readonly property var result: limitsRequest.data ?? ({})
        readonly property bool signedIn: result.signedIn ?? true
        readonly property bool tokenExpired: signedIn && (result.expired === true
            || (result.expiresAt > 0 && result.expiresAt <= now))
        readonly property bool loading: limitsRequest.running
        readonly property bool scanning: historyRequest.running
        readonly property bool ready: (result.fetchedAt ?? 0) > 0
        readonly property string error: limitsRequest.error || (result.error ?? "")
        readonly property date updated: new Date(result.fetchedAt || NaN)
        readonly property var status: statusRequest.data ?? ({ indicator: "unknown", description: "" })
        readonly property var history: claude.settings.tokenHistory ? historyPeriods(historyRequest.data) : ({})
        readonly property var limits: (result.limits ?? []).map(limit => present(limit))
        readonly property var values: {
            const five = limits.find(limit => limit.key === "five_hour")
            const seven = limits.find(limit => limit.key === "seven_day")
            const values = {
                five_hour: five?.value ?? "--", seven_day: seven?.value ?? "--",
                five_hour_reset: resetLabel(five), seven_day_reset: resetLabel(seven),
                status_text: status.description
            }
            for (const period of ["session", "today", "week", "month", "year"]) {
                const total = history.periods?.[period]?.total
                values[period + "_tokens"] = total === undefined ? "--" : claude.compact(total)
            }
            return values
        }

        function present(limit: var): var {
            const remaining = limit.resetsAt > 0 ? Math.max(0, limit.resetsAt - now) : 0
            const minutes = Math.floor(remaining / 60000)
            const days = Math.floor(minutes / 1440)
            const hours = Math.floor(minutes / 60) % 24
            const rest = minutes % 60
            const value = Math.round(limit.percent)
            const pattern = claude.settings.timeFormat === "12h" ? "ddd h:mm AP" : "ddd HH:mm"
            return {
                key: limit.key, name: limit.name, percent: limit.percent, value: value, resetsAt: limit.resetsAt,
                level: value < 50 ? "low" : value < 80 ? "medium" : "high",
                resetIn: !limit.resetsAt ? "" : days ? days + "d " + hours + "h"
                    : hours ? hours + "h " + rest + "m" : rest + "m",
                resetOn: limit.resetsAt ? Qt.formatDateTime(new Date(limit.resetsAt), pattern) : ""
            }
        }

        function resetLabel(limit: var): string {
            if (!limit?.resetsAt)
                return "--"
            return limit.resetsAt - now < 86400000 ? limit.resetIn : limit.resetOn
        }

        function dayKey(date) {
            return date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0")
                + "-" + String(date.getDate()).padStart(2, "0")
        }

        function hourSeries(hours, first, last) {
            const values = []
            for (const hour = new Date(first); hour <= last; hour.setHours(hour.getHours() + 1)) {
                const key = dayKey(hour) + "T" + String(hour.getHours()).padStart(2, "0")
                values.push(total(hours[key] ?? []))
            }
            return values
        }

        function total(counts) {
            return (counts[0] ?? 0) + (counts[1] ?? 0) + (counts[2] ?? 0)
                + (claude.settings.countCacheRead ? (counts[3] ?? 0) : 0)
        }

        function addCounts(target, counts) {
            for (let index = 0; index < 4; ++index)
                target[index] += counts[index]
        }

        // claude-opus-4-1-20250805[fast] reads as Opus 4.1 (fast)
        function modelName(model) {
            const fast = model.endsWith("[fast]")
            const base = model.replace(/\[[^\]]*\]/g, "").replace(/^claude-/, "")
            const parts = base.split("-").filter(part => !/^\d{8}$/.test(part))
            const family = parts.find(part => /^[a-z]+$/i.test(part))
            const version = parts.filter(part => /^\d+$/.test(part)).join(".")
            const name = family ? (family[0].toUpperCase() + family.slice(1) + " " + version).trim() : base
            return fast ? name + " (fast)" : name
        }

        function period(models, series) {
            const counts = [0, 0, 0, 0]
            const breakdown = []
            for (const [model, values] of models) {
                addCounts(counts, values)
                const tokens = total(values)
                if (model !== "<synthetic>" && tokens > 0)
                    breakdown.push({ model, name: modelName(model), tokens })
            }
            breakdown.sort((left, right) => right.tokens - left.tokens)
            return {
                total: total(counts), series, models: breakdown,
                kinds: { input: counts[0], output: counts[1], cacheCreation: counts[2], cacheRead: counts[3] }
            }
        }

        function calendarPeriod(raw, start, today, step) {
            const models = new Map()
            const series = []
            for (const day = new Date(start); day <= today; day.setDate(day.getDate() + 1)) {
                const entries = Object.entries(raw.days[dayKey(day)] ?? {})
                let dayTotal = 0
                for (const [model, counts] of entries) {
                    if (!models.has(model))
                        models.set(model, [0, 0, 0, 0])
                    addCounts(models.get(model), counts)
                    dayTotal += total(counts)
                }
                if (step === "day")
                    series.push(dayTotal)
                else if (step === "month")
                    series[day.getMonth()] = (series[day.getMonth()] ?? 0) + dayTotal
            }
            return period(models, step === "hour" ? hourSeries(raw.hours, today, new Date(now)) : series)
        }

        function historyPeriods(raw) {
            if (!raw)
                return {}
            const at = new Date(now)
            const year = at.getFullYear()
            const month = at.getMonth()
            const date = at.getDate()
            const today = new Date(year, month, date)
            const offset = claude.settings.weekStartsOn === "sunday" ? at.getDay() : (at.getDay() + 6) % 7
            const hours = Object.keys(raw.session.hours).sort()
            const sessionSeries = hours.length
                ? hourSeries(raw.session.hours, new Date(hours[0] + ":00:00"), new Date(hours[hours.length - 1] + ":00:00"))
                : []
            return { periods: {
                session: period(new Map(Object.entries(raw.session.models)), sessionSeries),
                today: calendarPeriod(raw, today, today, "hour"),
                week: calendarPeriod(raw, new Date(year, month, date - offset), today, "day"),
                month: calendarPeriod(raw, new Date(year, month, 1), today, "day"),
                year: calendarPeriod(raw, new Date(year, 0, 1), today, "month")
            } }
        }

        function refresh() {
            now = Date.now()
            if (!limitsRequest.running) {
                limitsRequest.force = true
                limitsRequest.run()
            }
            if (claude.settings.tokenHistory && !historyRequest.running)
                historyRequest.run()
            if (claude.settings.checkStatus && !statusRequest.running)
                statusRequest.run()
        }
    }

    Hotkey {
        keys: claude.settings.hotkey
        onActivated: claude.togglePopup()
    }

    Connections {
        target: claude.Window.window

        function onVisibleChanged() {
            if (!claude.Window.window?.visible)
                popup.hide()
        }

        function onXChanged() {
            if (popup.visible)
                claude.placePopup()
        }

        function onYChanged() {
            if (popup.visible)
                claude.placePopup()
        }
    }

    // Keeps the popup in place when its height changes
    Connections {
        target: popup

        function onHeightChanged() {
            if (popup.visible)
                claude.placePopup()
        }
    }

    Row {
        id: row

        height: parent.height
        spacing: 4

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: claude.text
            textFormat: Text.PlainText
            color: claude.settings.textColor
            font: claude.settings.font
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: claude.settings.showExpired && usage.tokenExpired
            text: claude.settings.icons.expired
            textFormat: Text.PlainText
            color: claude.settings.cautionColor
            font.family: claude.settings.iconFont.family
            font.weight: claude.settings.iconFont.weight
            font.variableAxes: claude.settings.iconFont.variableAxes
            font.pixelSize: claude.theme.bar.font.pixelSize
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                claude.togglePopup()
            else
                claude.showAlternate = !claude.showAlternate
        }
    }

    ToolTip {
        popupType: Popup.Window
        visible: claude.settings.tooltip && area.containsMouse && !popup.visible
        delay: 400
        text: !usage.signedIn ? qsTr("%1 tokens today\n%2").arg(usage.values.today_tokens).arg(usage.error)
            : !usage.ready ? usage.error || qsTr("Fetching the Claude usage...")
            : usage.limits.length === 0 ? qsTr("Anthropic reports no usage limits for this account right now.")
            : usage.limits.map(limit => qsTr("%1: %2% used, resets in %3").arg(limit.name).arg(limit.value).arg(limit.resetIn))
                .join("\n")
        // Away from the bar's edge
        y: claude.edge === "bottom" ? -implicitHeight - claude.settings.popupGap : claude.height + claude.settings.popupGap
    }

    BackdropPopup {
        id: popup

        property real reveal: 0
        // The token history's period: session, today, week, month or year
        property string period: "today"
        readonly property var tokens: usage.history.periods?.[period] ?? null
        // A warning above the usage: Claude Code signed out or its sign-in run out, or a fetch that failed
        readonly property string notice: !usage.signedIn ? usage.error
            : usage.tokenExpired ? qsTr("Claude Code's sign-in has expired. Run any Claude Code command to renew it.")
            : usage.error

        objectName: "popup"
        title: qsTr("Claude usage")
        width: claude.settings.popupWidth
        // Never taller than the screen
        height: Math.min(popupContent.implicitHeight, claude.Screen.desktopAvailableHeight - 24)
        anchor: claude
        font: claude.settings.popupFont
        theme: claude.theme
        backdropItem: surface
        enter: NumberAnimation { target: popup; property: "reveal"; to: 1; duration: claude.settings.popupOpenDuration; easing.type: Easing.OutCubic }
        exit: NumberAnimation { target: popup; property: "reveal"; to: 0; duration: claude.settings.popupCloseDuration; easing.type: Easing.InCubic }
        onVisibleChanged: {
            if (!visible)
                reveal = 0
        }

        Rectangle {
            id: surface

            anchors.fill: parent
            radius: claude.settings.popupRadius
            color: claude.settings.popupColor
            border.width: 1
            border.color: claude.settings.popupBorderColor
            opacity: popup.reveal
            scale: 0.85 + popup.reveal * 0.15
            transformOrigin: claude.edge === "bottom" ? Item.Bottom : Item.Top
            clip: true

            ColumnLayout {
                id: popupContent

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 10
                    Layout.topMargin: 12
                    Layout.bottomMargin: 10
                    spacing: 8

                    Column {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 2

                        PopupText {
                            width: parent.width
                            text: qsTr("Claude usage")
                            font: claude.settings.popupTitleFont
                        }

                        // Claude's status, with a dot in its colour
                        Row {
                            width: parent.width
                            visible: claude.settings.checkStatus && usage.status.description !== ""
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: claude.statusColor(usage.status.indicator)
                            }

                            PopupText {
                                width: parent.width - 13
                                text: usage.status.description
                                color: claude.settings.popupMutedTextColor
                                font: claude.settings.popupSmallFont
                            }
                        }
                    }

                    Item {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        enabled: !usage.loading
                        opacity: enabled ? 1 : 0.4
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Refresh")
                        Accessible.onPressAction: usage.refresh()
                        ToolTip.visible: refreshArea.containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: qsTr("Refresh")

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: refreshArea.containsMouse ? claude.settings.popupHoverColor : "transparent"
                        }

                        Glyph {
                            anchors.fill: parent
                            text: claude.settings.icons.refresh
                            color: refreshArea.containsMouse ? claude.settings.popupTextColor : claude.settings.popupMutedTextColor
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: refreshArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: usage.refresh()
                        }
                    }
                }

                // The header's bottom line, which the loading bar runs along
                LoadingLine {
                    Layout.fillWidth: true
                    running: usage.loading || usage.scanning
                    color: claude.settings.accentColor
                    trackColor: claude.settings.popupDividerColor
                }

                PopupText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 12
                    Layout.bottomMargin: usage.ready ? 0 : 14
                    visible: popup.notice !== ""
                    text: popup.notice
                    wrapMode: Text.WordWrap
                    // Signing in is a step to take, not a failure
                    color: !usage.signedIn ? claude.settings.popupSecondaryTextColor
                        : usage.ready ? claude.settings.cautionColor : claude.settings.criticalColor
                    font: claude.settings.popupSmallFont
                }

                PopupText {
                    Layout.fillWidth: true
                    Layout.topMargin: 24
                    Layout.bottomMargin: 24
                    visible: !usage.ready && popup.notice === ""
                    text: qsTr("Fetching the Claude usage...")
                    horizontalAlignment: Text.AlignHCenter
                    color: claude.settings.popupMutedTextColor
                }

                // Anthropic answered, but left out every window and cap
                PopupText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 24
                    Layout.bottomMargin: 24
                    visible: usage.ready && usage.limits.length === 0
                    text: qsTr("Anthropic reports no usage limits for this account right now.")
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    color: claude.settings.popupMutedTextColor
                }

                // Each limit: its name and how much of it is used, a bar, and when it resets
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 14
                    Layout.bottomMargin: 16
                    visible: usage.limits.length > 0
                    spacing: 16

                    Repeater {
                        model: usage.limits

                        delegate: ColumnLayout {
                            id: limit

                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 6
                            Accessible.role: Accessible.StaticText
                            Accessible.name: qsTr("%1: %2% used, resets in %3").arg(modelData.name).arg(modelData.value)
                                .arg(modelData.resetIn)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                PopupText {
                                    Layout.fillWidth: true
                                    text: limit.modelData.name
                                    font: claude.settings.limitFont
                                }

                                PopupText {
                                    text: qsTr("%1%").arg(limit.modelData.value)
                                    color: limit.modelData.level === "low" ? claude.settings.popupTextColor
                                        : claude.levelColor(limit.modelData.level)
                                    font.family: claude.settings.limitFont.family
                                    font.pixelSize: claude.settings.limitFont.pixelSize
                                    font.weight: 600
                                }
                            }

                            Meter {
                                Layout.fillWidth: true
                                part: limit.modelData.percent / 100
                                fill: claude.levelColor(limit.modelData.level)
                            }

                            PopupText {
                                Layout.fillWidth: true
                                visible: limit.modelData.resetIn !== ""
                                text: qsTr("Resets in %1 · %2").arg(limit.modelData.resetIn).arg(limit.modelData.resetOn)
                                color: claude.settings.popupMutedTextColor
                                font: claude.settings.popupSmallFont
                            }
                        }
                    }
                }

                Divider {
                    visible: tokensPart.visible
                }

                // The tokens Claude Code used here in a period: the total, how it splits, a graph and the models
                ColumnLayout {
                    id: tokensPart

                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 10
                    Layout.bottomMargin: 16
                    visible: claude.settings.tokenHistory && popup.tokens !== null
                    spacing: 10

                    // Which period, marked as Windows marks the chosen view: bold, with a short accent bar under it.
                    // In a box of its own, so a long translation is cut off at the edge instead of widening the popup
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 24
                        clip: true

                        Row {
                            spacing: 16

                            Repeater {
                                model: [["session", qsTr("Session")], ["today", qsTr("Today")], ["week", qsTr("Week")],
                                    ["month", qsTr("Month")], ["year", qsTr("Year")]]

                                delegate: Item {
                                    id: periodItem

                                    required property var modelData
                                    readonly property bool chosen: popup.period === modelData[0]

                                    width: periodText.implicitWidth
                                    height: 24
                                    Accessible.role: Accessible.RadioButton
                                    Accessible.name: modelData[1]
                                    Accessible.checked: chosen
                                    Accessible.onPressAction: popup.period = modelData[0]

                                    PopupText {
                                        id: periodText

                                        text: periodItem.modelData[1]
                                        color: periodItem.chosen || periodArea.containsMouse ? claude.settings.popupTextColor
                                            : claude.settings.popupSecondaryTextColor
                                        font.family: claude.settings.popupFont.family
                                        font.pixelSize: claude.settings.popupFont.pixelSize
                                        font.weight: periodItem.chosen ? 600 : 400
                                    }

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        width: 16
                                        height: 3
                                        radius: 1.5
                                        visible: periodItem.chosen
                                        color: claude.settings.accentColor
                                    }

                                    MouseArea {
                                        id: periodArea

                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: popup.period = periodItem.modelData[0]
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        spacing: 6

                        PopupText {
                            anchors.baseline: tokensWord.baseline
                            text: Number(popup.tokens?.total ?? 0).toLocaleString(Qt.locale(), "f", 0)
                            font: claude.settings.totalFont
                        }

                        PopupText {
                            id: tokensWord

                            y: 7
                            text: qsTr("tokens")
                            color: claude.settings.popupMutedTextColor
                        }
                    }

                    // The tokens split by kind, as Anthropic counts them
                    PopupText {
                        readonly property var kinds: popup.tokens?.kinds ?? ({})

                        Layout.fillWidth: true
                        text: qsTr("Input %1 · Output %2 · Cache write %3 · Cache read %4")
                            .arg(claude.compact(kinds.input)).arg(claude.compact(kinds.output))
                            .arg(claude.compact(kinds.cacheCreation)).arg(claude.compact(kinds.cacheRead))
                        color: claude.settings.popupMutedTextColor
                        font: claude.settings.popupSmallFont
                    }

                    // The tokens per hour, day or month across the period
                    Item {
                        id: graph

                        readonly property var series: popup.tokens?.series ?? []
                        readonly property real most: Math.max(1, ...series)

                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        visible: series.length > 0

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: claude.settings.popupDividerColor
                        }

                        Row {
                            id: bars

                            anchors.fill: parent
                            spacing: graph.series.length > 40 ? 1 : 2

                            Repeater {
                                model: graph.series

                                // A bar as tall as its tokens against the period's most, and never too short to see
                                delegate: Rectangle {
                                    required property var modelData

                                    anchors.bottom: parent?.bottom
                                    width: (bars.width - bars.spacing * (graph.series.length - 1)) / graph.series.length
                                    height: modelData > 0 ? Math.max(2, bars.height * modelData / graph.most) : 0
                                    radius: Math.min(2, width / 2)
                                    color: Qt.alpha(claude.settings.accentColor, 0.75)
                                }
                            }
                        }
                    }

                    // The models that used the most tokens in the period
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: (popup.tokens?.models ?? []).length > 0
                        spacing: 8

                        Repeater {
                            model: (popup.tokens?.models ?? []).slice(0, 5)

                            delegate: ColumnLayout {
                                id: modelRow

                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true

                                    PopupText {
                                        Layout.fillWidth: true
                                        text: modelRow.modelData.name
                                    }

                                    PopupText {
                                        text: Number(modelRow.modelData.tokens).toLocaleString(Qt.locale(), "f", 0)
                                        color: claude.settings.popupMutedTextColor
                                        font: claude.settings.popupSmallFont
                                    }
                                }

                                Meter {
                                    Layout.fillWidth: true
                                    implicitHeight: 3
                                    part: modelRow.modelData.tokens / Math.max(1, popup.tokens?.total ?? 1)
                                    fill: Qt.alpha(claude.settings.accentColor, 0.75)
                                }
                            }
                        }
                    }
                }

                // The strip at the bottom: the usage page on claude.ai, and when the usage was fetched
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 1
                    Layout.rightMargin: 1
                    Layout.bottomMargin: 1
                    implicitHeight: 40
                    bottomLeftRadius: Math.max(0, claude.settings.popupRadius - 1)
                    bottomRightRadius: Math.max(0, claude.settings.popupRadius - 1)
                    color: claude.settings.popupFooterColor

                    Divider {
                        width: parent.width
                    }

                    Link {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        // Cut short before it reaches the time
                        width: Math.min(implicitWidth, parent.width - 48 - (updatedLabel.visible ? updatedLabel.implicitWidth : 0))
                        elide: Text.ElideRight
                        text: qsTr("Usage on claude.ai")
                        onClicked: {
                            Qt.openUrlExternally("https://claude.ai/settings/usage")
                            popup.close()
                        }
                    }

                    PopupText {
                        id: updatedLabel

                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: claude.updated !== ""
                        text: qsTr("Updated %1").arg(claude.updated)
                        color: claude.settings.popupMutedTextColor
                        font: claude.settings.popupSmallFont
                    }
                }
            }
        }
    }
}
