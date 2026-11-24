# Pomodoro

A focus timer with short and long breaks, and a toast and a sound when each part ends

```
yasbc addons install amnweb.pomodoro
```

A focus timer for your bar, built on the **Pomodoro Technique**: you work in focused sessions of 25 minutes, with a 5 minute break after each one and a 15 minute break after every 4 sessions.

## Use

- **Left click** opens the timer: the current part, a ring with the time left, **Start/Pause**, **Reset** and **Skip**, and today's sessions and focus time.
- **Right click** starts or pauses the timer without opening it.
- When a part ends, the widget shows a Windows notification and plays a sound, then the next part begins. Breaks start on their own after focus; focus waits until you start it.
- Skipped or reset sessions don't count.

## Settings

Change them in the `Settings` block at the top of `Pomodoro.qml`:

- **Durations:** `focusMinutes`, `shortBreakMinutes`, `longBreakMinutes`, `sessionsBeforeLongBreak`
- **Auto start:** `autoStartBreaks`, `autoStartFocus`
- **Alerts:** `toast`, `sound`, and `soundFile` for your own WAV file
- **Hotkey:** `hotkey`, which starts or pauses the timer

Colours and fonts follow your YASB theme and Windows accent colour.

## The `pomodoro.ini` file

The widget keeps its state in `pomodoro.ini` next to `Pomodoro.qml`. It saves the current part, whether the timer is running and when it ends, a paused part's time left, your progress toward the long break, and today's sessions and focus time.

Because of this file, the timer keeps going when YASB reloads your config or restarts. If a part ended while YASB was closed, it is counted without a notification.

You can delete the file at any time to start fresh. Updating the widget also resets it.

<!-- changes -->
## Changes

### Version 1 (2026-11-24)

Initial release
