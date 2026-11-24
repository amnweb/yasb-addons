pragma Singleton

import QtCore as Core
import QtQuick
import Yasb

// The one timer every bar's Pomodoro shows. YASB keeps it until it restarts, so edits here apply after a restart
QtObject {
    id: timer

    // The Pomodoro widgets on the bars; the first one's settings drive the timer
    property list<QtObject> widgets
    readonly property var settings: widgets.length > 0 ? widgets[0].settings : null

    readonly property string phase: saved.phase
    readonly property bool running: saved.running
    // Focus sessions since the last long break
    readonly property int cycle: saved.cycle
    // Milliseconds since 1970, moved on each second while the timer runs
    property real now: Date.now()
    readonly property int duration: 60 * (phase === "focus" ? settings?.focusMinutes ?? 25
        : phase === "short" ? settings?.shortBreakMinutes ?? 5 : settings?.longBreakMinutes ?? 15)
    readonly property int secondsLeft: running ? Math.max(0, Math.ceil((saved.endsAt - now) / 1000))
        : saved.remaining < 0 ? duration : Math.min(saved.remaining, duration)
    readonly property real progress: duration > 0 ? 1 - secondsLeft / duration : 0
    readonly property bool started: running || saved.remaining >= 0
    readonly property bool countsToday: saved.day === Qt.formatDate(new Date(now), "yyyy-MM-dd")
    readonly property int sessionsToday: countsToday ? saved.sessions : 0
    readonly property int focusSecondsToday: countsToday ? saved.focusSeconds : 0

    // A part ended, after the toast and sound; each bar shows it on its own
    signal ended(string phase, string next)

    // The state, kept beside this file so it carries on through restarts
    component State: Core.Settings {
        property string phase: "focus"
        property bool running: false
        property real endsAt: 0
        // Seconds left of a paused part; -1 for a part not started
        property int remaining: -1
        property int cycle: 0
        property string day: ""
        property int sessions: 0
        property int focusSeconds: 0

        location: Qt.resolvedUrl("pomodoro.ini")
    }

    property State saved: State {}

    property Timer ticker: Timer {
        interval: 1000
        repeat: true
        running: timer.running
        triggeredOnStart: true
        onTriggered: {
            timer.now = Date.now()
            if (timer.now >= timer.saved.endsAt)
                timer.finish(timer.now - timer.saved.endsAt < 60000)
        }
    }

    function attach(widget: QtObject) {
        widgets.push(widget)
    }

    function detach(widget: QtObject) {
        widgets = Array.from(widgets).filter(item => item !== widget)
    }

    function refresh() {
        now = Date.now()
    }

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
        if (running)
            pause()
        else
            start()
    }

    function reset() {
        saved.running = false
        saved.remaining = -1
    }

    function moveTo(next: string, run: bool) {
        saved.running = false
        saved.phase = next
        saved.remaining = -1
        if (run)
            start()
    }

    function skip() {
        const run = running
        if (phase === "long")
            saved.cycle = 0
        moveTo(phase === "focus" ? "short" : "focus", run)
    }

    // onTime is false for a part that ended long ago, while YASB was closed, and then nothing is announced
    function finish(onTime: bool) {
        const done = phase
        let next = "focus"
        if (done === "focus") {
            saved.cycle += 1
            countFocus(duration)
            next = saved.cycle >= (settings?.sessionsBeforeLongBreak ?? 4) ? "long" : "short"
        } else if (done === "long") {
            saved.cycle = 0
        }
        const autoStart = next === "focus" ? settings?.autoStartFocus ?? false : settings?.autoStartBreaks ?? true
        if (onTime)
            announce(done, next)
        moveTo(next, onTime && autoStart)
        if (onTime)
            ended(done, next)
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

    function announce(done: string, next: string) {
        if (settings === null)
            return
        const title = done === "focus" ? "Focus done" : "Break's over"
        const message = next === "long" ? `Time for a long break, ${settings.longBreakMinutes} minutes`
            : next === "short" ? `Time for a short break, ${settings.shortBreakMinutes} minutes` : "Time to focus"
        if (settings.toast)
            Notifier.toast(title, message)
        if (settings.sound)
            Notifier.playSound(settings.soundFile.toString())
    }
}
