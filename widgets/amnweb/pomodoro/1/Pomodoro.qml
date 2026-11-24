pragma ComponentBehavior: Bound

import QtCore as Core
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Yasb
import Yasb.Bar
import Yasb.Common
import Yasb.Themes

Item {
    id: pomodoro

    component Icons: QtObject {
        // On the bar during a break, in place of the ring
        property string breakTime
        property string reset
        property string skip
        property string pin
        property string unpin
    }

    component Settings: QtObject {
        required property Theme theme

        // Minutes of each part, 1 to 180
        property int focusMinutes: 25
        property int shortBreakMinutes: 5
        property int longBreakMinutes: 15
        // Focus sessions before a long break instead of a short one
        property int sessionsBeforeLongBreak: 4
        // Whether the next part starts by itself when one ends
        property bool autoStartBreaks: true
        property bool autoStartFocus: false
        // When a part ends: a Windows toast, and a sound
        property bool toast: true
        property bool sound: true
        // A WAV file, such as Qt.resolvedUrl("ding.wav") beside this file; empty for YASB's sound
        property url soundFile
        // Hotkey that starts or pauses the timer, such as "alt+shift+p"
        property string hotkey: ""
        // The time on the bar while the timer has not started; false shows only the ring
        property bool showIdleTime: true
        // The rings, the break glyph and the Start button
        property color accentColor: theme.colors.accent
        property color trackColor: theme.colors.divider
        property int ringSize: 16
        property int ringThickness: 2
        // Text on the bar takes the theme's colour, and the bar's font; parts set in font replace the bar's
        property color textColor: theme.colors.text
        property font font
        font.features: { "tnum": 1 }
        // Glyphs take the theme's icon font
        property font iconFont
        iconFont.family: theme.bar.iconFont.family
        iconFont.weight: theme.bar.iconFont.weight
        iconFont.variableAxes: theme.bar.iconFont.variableAxes
        property int iconSize: theme.bar.iconFont.pixelSize
        readonly property Icons icons: Icons {
            breakTime: "\uec32"
            reset: "\ue72c"
            skip: "\ue893"
            pin: "\ue840"
            unpin: "\ue77a"
        }
        property int popupWidth: 300
        property int popupRingSize: 160
        property int popupRingThickness: 6
        // The popup: the theme's, unless set here
        property color popupColor: theme.popup.background
        property color popupBorderColor: theme.popup.border
        property color popupTextColor: theme.colors.text
        property color popupSecondaryTextColor: theme.colors.textSecondary
        property color popupDividerColor: theme.colors.divider
        property color popupCardColor: theme.colors.card
        property color popupCardBorderColor: theme.colors.cardBorder
        property real popupRadius: theme.popup.radius
        property real popupGap: theme.popup.gap
        property int popupOpenDuration: theme.popup.openDuration
        property int popupCloseDuration: theme.popup.closeDuration
        // Text in the popup: the theme's font family, in this widget's sizes
        property font popupFont
        popupFont.family: theme.popup.font.family
        popupFont.pixelSize: 14
        property font popupSmallFont
        popupSmallFont.family: theme.popup.font.family
        popupSmallFont.pixelSize: 12
        property font popupTitleFont
        popupTitleFont.family: theme.popup.font.family
        popupTitleFont.pixelSize: 16
        popupTitleFont.weight: 600
        // The part running now, under the header
        property font phaseFont
        phaseFont.family: theme.popup.font.family
        phaseFont.pixelSize: 14
        phaseFont.weight: 600
        // The time in the ring
        property font timeFont
        timeFont.family: theme.popup.font.family
        timeFont.pixelSize: 34
        timeFont.weight: 600
        timeFont.features: { "tnum": 1 }
        // The numbers on the cards
        property font valueFont
        valueFont.family: theme.popup.font.family
        valueFont.pixelSize: 20
        valueFont.weight: 600
        property font popupIconFont
        popupIconFont.family: theme.popup.iconFont.family
        popupIconFont.weight: theme.popup.iconFont.weight
        popupIconFont.variableAxes: theme.popup.iconFont.variableAxes
        popupIconFont.pixelSize: 14
        property int popupIconSize: 14
    }

    component Ring: Shape {
        id: ring

        property real progress: 0
        property real thickness: 2
        property color trackColor
        property color color
        // False while a popup is hidden: Shape keeps no geometry once the popup's scene graph is released, and
        // rebuilds it only when the path changes
        property bool shown: true
        readonly property real radius: shown ? (Math.min(width, height) - thickness) / 2 : 0

        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: ring.trackColor
            strokeWidth: ring.thickness
            fillColor: "transparent"

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: ring.progress > 0 ? ring.color : "transparent"
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: -90
                sweepAngle: 360 * Math.min(1, ring.progress)
            }
        }
    }

    component StatCard: Rectangle {
        id: card

        property string label
        property string value

        Layout.fillWidth: true
        implicitHeight: cardText.implicitHeight + 20
        radius: 8
        color: pomodoro.settings.popupCardColor
        border.width: 1
        border.color: pomodoro.settings.popupCardBorderColor

        Column {
            id: cardText

            x: 12
            y: 10
            width: parent.width - 24

            Text {
                width: parent.width
                text: card.label
                elide: Text.ElideRight
                font: pomodoro.settings.popupSmallFont
                color: pomodoro.settings.popupSecondaryTextColor
            }

            Text {
                width: parent.width
                text: card.value
                elide: Text.ElideRight
                font: pomodoro.settings.valueFont
                color: pomodoro.settings.popupTextColor
            }
        }
    }

    component GlyphButton: Button {
        id: glyphButton

        required property string glyph

        Layout.preferredWidth: 40
        text: glyph
        font: pomodoro.settings.popupIconFont
        Accessible.onPressAction: glyphButton.clicked()
    }

    required property BarBase bar
    readonly property Theme theme: bar.theme
    readonly property Settings settings: Settings {
        theme: pomodoro.theme
    }

    readonly property string edge: bar.edge
    // Milliseconds since 1970, moved on each second while the timer runs
    property real now: Date.now()
    readonly property int duration: 60 * (saved.phase === "focus" ? settings.focusMinutes
        : saved.phase === "short" ? settings.shortBreakMinutes : settings.longBreakMinutes)
    readonly property int secondsLeft: saved.running ? Math.max(0, Math.ceil((saved.endsAt - now) / 1000))
        : saved.remaining < 0 ? duration : Math.min(saved.remaining, duration)
    readonly property real progress: duration > 0 ? 1 - secondsLeft / duration : 0
    readonly property bool started: saved.running || saved.remaining >= 0
    readonly property string phaseName: saved.phase === "focus" ? "Focus"
        : saved.phase === "short" ? "Short break" : "Long break"
    readonly property string sessionText: saved.phase === "focus"
        ? `Session ${Math.min(saved.cycle + 1, settings.sessionsBeforeLongBreak)} of ${settings.sessionsBeforeLongBreak}`
        : `${Math.min(saved.cycle, settings.sessionsBeforeLongBreak)} of ${settings.sessionsBeforeLongBreak} done`
    readonly property string timeText: `${String(Math.floor(secondsLeft / 60)).padStart(2, "0")}:${String(secondsLeft % 60).padStart(2, "0")}`
    readonly property bool countsToday: saved.day === Qt.formatDate(new Date(now), "yyyy-MM-dd")

    function start() {
        now = Date.now()
        saved.endsAt = now + secondsLeft * 1000
        saved.running = true
    }

    function pause() {
        saved.remaining = secondsLeft
        saved.running = false
    }

    function toggle() {
        if (saved.running)
            pause()
        else
            start()
    }

    function reset() {
        saved.running = false
        saved.remaining = -1
    }

    function moveTo(phase: string, run: bool) {
        saved.running = false
        saved.phase = phase
        saved.remaining = -1
        if (run)
            start()
    }

    function skip() {
        const run = saved.running
        if (saved.phase === "long")
            saved.cycle = 0
        moveTo(saved.phase === "focus" ? "short" : "focus", run)
    }

    // A part ended; onTime is false when it ended long ago, while YASB was closed, and then nothing is announced
    function finish(onTime: bool) {
        const ended = saved.phase
        let next = "focus"
        if (ended === "focus") {
            saved.cycle += 1
            countFocus(duration)
            next = saved.cycle >= settings.sessionsBeforeLongBreak ? "long" : "short"
        } else if (ended === "long") {
            saved.cycle = 0
        }
        if (onTime)
            announce(ended, next)
        moveTo(next, onTime && (next === "focus" ? settings.autoStartFocus : settings.autoStartBreaks))
    }

    function countFocus(seconds: int) {
        const day = Qt.formatDate(new Date(), "yyyy-MM-dd")
        if (saved.day !== day) {
            saved.day = day
            saved.sessions = 0
            saved.focusSeconds = 0
        }
        saved.sessions += 1
        saved.focusSeconds += seconds
    }

    function announce(ended: string, next: string) {
        pulse.restart()
        const title = ended === "focus" ? "Focus done" : "Break's over"
        const message = next === "long" ? `Time for a long break, ${settings.longBreakMinutes} minutes`
            : next === "short" ? `Time for a short break, ${settings.shortBreakMinutes} minutes` : "Time to focus"
        if (settings.toast)
            Notifier.toast(title, message)
        if (settings.sound)
            Notifier.playSound(settings.soundFile.toString())
    }

    function focusTime(seconds: int): string {
        const minutes = Math.round(seconds / 60)
        return minutes < 60 ? `${minutes} min` : `${Math.floor(minutes / 60)} h ${minutes % 60} min`
    }

    function placePopup() {
        const start = mapToGlobal(0, 0)
        let px = edge === "left" ? start.x + width + settings.popupGap
            : edge === "right" ? start.x - popup.width - settings.popupGap : start.x + (width - popup.width) / 2
        let py = edge === "top" ? start.y + height + settings.popupGap
            : edge === "bottom" ? start.y - popup.height - settings.popupGap : start.y + (height - popup.height) / 2
        const screen = pomodoro.Screen
        px = Math.max(screen.virtualX + 8, Math.min(px, screen.virtualX + screen.width - popup.width - 8))
        py = Math.max(screen.virtualY + 8, Math.min(py, screen.virtualY + screen.desktopAvailableHeight - popup.height - 8))
        popup.x = Math.round(px)
        popup.y = Math.round(py)
    }

    function togglePopup() {
        if (popup.visible)
            popup.close()
        else {
            now = Date.now()
            placePopup()
            popup.open()
        }
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Component.onDestruction: popup.hide()

    // The timer's state, kept beside this file so it carries on through reloads and restarts
    Core.Settings {
        id: saved

        property string phase: "focus"
        property bool running: false
        property real endsAt: 0
        // Seconds left of a paused part; -1 for a part not started
        property int remaining: -1
        // Focus sessions since the last long break
        property int cycle: 0
        property string day: ""
        property int sessions: 0
        property int focusSeconds: 0

        location: Qt.resolvedUrl("pomodoro.ini")
    }

    Timer {
        interval: 1000
        repeat: true
        running: saved.running
        triggeredOnStart: true
        onTriggered: {
            pomodoro.now = Date.now()
            if (pomodoro.now >= saved.endsAt)
                pomodoro.finish(pomodoro.now - saved.endsAt < 60000)
        }
    }

    Hotkey {
        keys: pomodoro.settings.hotkey
        onActivated: pomodoro.toggle()
    }

    Connections {
        target: pomodoro.Window.window
        function onVisibleChanged() {
            if (!pomodoro.Window.window?.visible)
                popup.hide()
        }
        function onXChanged() { if (popup.visible && !popup.pinned) pomodoro.placePopup() }
        function onYChanged() { if (popup.visible && !popup.pinned) pomodoro.placePopup() }
    }

    Connections {
        target: popup
        function onHeightChanged() { if (popup.visible && !popup.pinned) pomodoro.placePopup() }
    }

    Row {
        id: row

        height: parent.height
        spacing: 6
        opacity: pomodoro.started && !saved.running ? 0.6 : 1

        Item {
            id: marker

            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(pomodoro.settings.ringSize, breakGlyph.implicitWidth)
            height: pomodoro.settings.ringSize

            Ring {
                anchors.centerIn: parent
                width: pomodoro.settings.ringSize
                height: pomodoro.settings.ringSize
                visible: saved.phase === "focus"
                thickness: pomodoro.settings.ringThickness
                trackColor: pomodoro.settings.trackColor
                color: pomodoro.settings.accentColor
                progress: pomodoro.progress
            }

            Text {
                id: breakGlyph

                anchors.centerIn: parent
                visible: saved.phase !== "focus"
                text: pomodoro.settings.icons.breakTime
                color: pomodoro.settings.accentColor
                font.family: pomodoro.settings.iconFont.family
                font.weight: pomodoro.settings.iconFont.weight
                font.variableAxes: pomodoro.settings.iconFont.variableAxes
                font.pixelSize: pomodoro.settings.iconSize
            }

            SequentialAnimation {
                id: pulse

                loops: 3

                NumberAnimation { target: marker; property: "scale"; to: 1.35; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { target: marker; property: "scale"; to: 1; duration: 280; easing.type: Easing.InOutCubic }
            }
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: pomodoro.started || pomodoro.settings.showIdleTime
            text: pomodoro.timeText
            textFormat: Text.PlainText
            color: pomodoro.settings.textColor
            font: pomodoro.settings.font
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                pomodoro.togglePopup()
            else
                pomodoro.toggle()
        }
    }

    BackdropPopup {
        id: popup

        property real reveal: 0

        objectName: "menu"
        title: "Pomodoro"
        width: pomodoro.settings.popupWidth
        height: popupContent.implicitHeight
        anchor: pomodoro
        font: pomodoro.settings.popupFont
        theme: pomodoro.theme
        backdropItem: surface
        enter: NumberAnimation { target: popup; property: "reveal"; to: 1; duration: pomodoro.settings.popupOpenDuration; easing.type: Easing.OutCubic }
        exit: NumberAnimation { target: popup; property: "reveal"; to: 0; duration: pomodoro.settings.popupCloseDuration; easing.type: Easing.InCubic }
        onVisibleChanged: {
            if (!visible) {
                reveal = 0
                pinned = false
            }
        }

        Rectangle {
            id: surface

            anchors.fill: parent
            radius: pomodoro.settings.popupRadius
            color: pomodoro.settings.popupColor
            // Active and inactive only, so disabled controls keep the style's dimmed colours
            palette.active.accent: pomodoro.settings.accentColor
            palette.inactive.accent: pomodoro.settings.accentColor
            border.width: 1
            border.color: pomodoro.settings.popupBorderColor
            opacity: popup.reveal
            scale: 0.85 + popup.reveal * 0.15
            transformOrigin: pomodoro.edge === "bottom" ? Item.Bottom : Item.Top

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
                        text: "Pomodoro"
                        font: pomodoro.settings.popupTitleFont
                        color: pomodoro.settings.popupTextColor

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
                            text: popup.pinned ? pomodoro.settings.icons.unpin : pomodoro.settings.icons.pin
                            color: pomodoro.settings.popupTextColor
                            opacity: popup.pinned ? 1 : 0.6
                            font.family: pomodoro.settings.popupIconFont.family
                            font.weight: pomodoro.settings.popupIconFont.weight
                            font.variableAxes: pomodoro.settings.popupIconFont.variableAxes
                            font.pixelSize: pomodoro.settings.popupIconSize
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
                    color: pomodoro.settings.popupDividerColor
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 14

                    Text {
                        Layout.fillWidth: true
                        text: pomodoro.phaseName
                        font: pomodoro.settings.phaseFont
                        color: pomodoro.settings.popupTextColor
                    }

                    Text {
                        text: pomodoro.sessionText
                        font: pomodoro.settings.popupSmallFont
                        color: pomodoro.settings.popupSecondaryTextColor
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: 18
                    Layout.bottomMargin: 18
                    implicitHeight: pomodoro.settings.popupRingSize

                    Ring {
                        anchors.centerIn: parent
                        width: pomodoro.settings.popupRingSize
                        height: pomodoro.settings.popupRingSize
                        thickness: pomodoro.settings.popupRingThickness
                        trackColor: pomodoro.settings.trackColor
                        color: pomodoro.settings.accentColor
                        progress: pomodoro.progress
                        shown: popup.visible
                    }

                    Column {
                        anchors.centerIn: parent

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: pomodoro.timeText
                            font: pomodoro.settings.timeFont
                            color: pomodoro.settings.popupTextColor
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: saved.running ? "Running" : pomodoro.started ? "Paused" : "Ready"
                            font: pomodoro.settings.popupSmallFont
                            color: pomodoro.settings.popupSecondaryTextColor
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 8

                    GlyphButton {
                        glyph: pomodoro.settings.icons.reset
                        Accessible.name: "Reset"
                        onClicked: pomodoro.reset()
                    }

                    Button {
                        Layout.fillWidth: true
                        text: saved.running ? "Pause" : pomodoro.started ? "Resume" : "Start"
                        highlighted: true
                        onClicked: pomodoro.toggle()
                    }

                    GlyphButton {
                        glyph: pomodoro.settings.icons.skip
                        Accessible.name: "Skip to the next part"
                        onClicked: pomodoro.skip()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 16
                    spacing: 8

                    StatCard {
                        label: "Sessions today"
                        value: String(pomodoro.countsToday ? saved.sessions : 0)
                    }

                    StatCard {
                        label: "Focus time"
                        value: pomodoro.focusTime(pomodoro.countsToday ? saved.focusSeconds : 0)
                    }
                }
            }
        }
    }
}
