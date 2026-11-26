pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Yasb
import Yasb.Bar
import Yasb.Common
import Yasb.Themes

Item {
    id: center

    component Icons: QtObject {
        property string settings
        property string power
        // The arrow on a tile that opens its page in Windows Settings
        property string chevron
        property string wifi
        property string ethernet
        property string bluetooth
        property string dnd
        property string microphone
        property string microphoneOff
        property string brightness
        // Volume from muted to loud
        property string volumeMuted
        property string volume0
        property string volume1
        property string volume2
        property string volume3
        property string previous
        property string play
        property string pause
        property string next
        // The button at the end of a slider that picks its screen or device
        property string sourceSelector
    }

    component Settings: QtObject {
        required property Theme theme

        // The glyph on the bar
        property string icon: "\ueca5"
        property int iconSize: theme.bar.iconFont.pixelSize
        property color textColor: theme.colors.text
        property font iconFont
        iconFont.family: theme.bar.iconFont.family
        iconFont.weight: theme.bar.iconFont.weight
        iconFont.variableAxes: theme.bar.iconFont.variableAxes
        // Hotkey that opens the popup, such as "alt+shift+c"
        property string hotkey: ""
        // What the do not disturb tile turns on: "priority" or "alarms"
        property string dndMode: "priority"
        // A button at the end of the brightness, volume and microphone sliders that picks the screen or device
        property bool sourceSelector: true
        // Round buttons under the tiles. Each opens a url, such as "ms-screenclip:", or starts a command, such as "taskmgr"
        property var shortcuts: [
            { icon: "\ue722", label: "Screenshot", url: "ms-screenclip:" },
            { icon: "\uf120", label: "Task Manager", command: "taskmgr" },
            { icon: "\ue8b7", label: "File Explorer", command: "explorer" }
        ]
        readonly property Icons icons: Icons {
            settings: "\ue713"
            power: "\ue7e8"
            chevron: "\ue76c"
            wifi: "\ue701"
            ethernet: "\ue839"
            bluetooth: "\ue702"
            dnd: "\ue708"
            microphone: "\ue720"
            microphoneOff: "\uf781"
            brightness: "\ue706"
            volumeMuted: "\ue74f"
            volume0: "\ue992"
            volume1: "\ue993"
            volume2: "\ue994"
            volume3: "\ue995"
            previous: "\ue892"
            play: "\ue768"
            pause: "\ue769"
            next: "\ue893"
            sourceSelector: "\ue972"
        }
        property int popupWidth: 400
        // The popup: the theme's, unless set here
        property color popupColor: theme.popup.background
        property color popupBorderColor: theme.popup.border
        property color popupTextColor: theme.colors.text
        property color popupSecondaryTextColor: theme.colors.textSecondary
        property color popupDividerColor: theme.colors.divider
        property color popupHoverColor: theme.colors.hover
        property color popupCardColor: theme.colors.card
        property color popupCardBorderColor: theme.colors.cardBorder
        // The strip at the bottom with the battery and the uptime
        property color popupFooterColor: theme.colors.backgroundSecondary
        property color errorColor: theme.colors.critical
        property real popupRadius: theme.popup.radius
        property real popupGap: theme.popup.gap
        property int popupOpenDuration: theme.popup.openDuration
        property int popupCloseDuration: theme.popup.closeDuration
        // The tiles, and the round buttons under them
        property color controlColor: theme.colors.control
        property color controlHoverColor: theme.colors.controlHover
        property color controlBorderColor: theme.colors.controlBorder
        // A tile that is on, the sliders and the loading line
        property color accentColor: theme.colors.accent
        property color onAccentColor: theme.colors.textOnAccent
        property real tileRadius: 8
        property real cardRadius: 8
        // Text in the popup: the theme's font family, in this widget's sizes
        property font popupFont
        popupFont.family: theme.popup.font.family
        popupFont.pixelSize: 13
        property font popupSmallFont
        popupSmallFont.family: theme.popup.font.family
        popupSmallFont.pixelSize: 12
        // Your name in the header, and the tiles' and the media's titles
        property font popupTitleFont
        popupTitleFont.family: theme.popup.font.family
        popupTitleFont.pixelSize: 13
        popupTitleFont.weight: 600
        property font popupIconFont
        popupIconFont.family: theme.popup.iconFont.family
        popupIconFont.weight: theme.popup.iconFont.weight
        popupIconFont.variableAxes: theme.popup.iconFont.variableAxes
        // The power menu: the theme's, unless set here
        property int menuWidth: 160
        property color menuColor: theme.menu.background
        property color menuBorderColor: theme.menu.border
        property color menuTextColor: theme.colors.text
        property real menuRadius: theme.menu.radius
        property font menuFont: theme.menu.font
        property int menuOpenDuration: theme.menu.openDuration
    }

    component Glyph: Text {
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: center.settings.popupTextColor
        font.family: center.settings.popupIconFont.family
        font.weight: center.settings.popupIconFont.weight
        font.variableAxes: center.settings.popupIconFont.variableAxes
    }

    component IconButton: Item {
        id: button

        property string glyph
        property int iconSize: 14
        // Round, with a fill: the shortcuts under the tiles
        property bool round: false
        property string tip
        property int padding: 16

        signal clicked

        implicitWidth: iconSize + padding
        implicitHeight: iconSize + 16
        opacity: enabled ? 1 : 0.4
        Accessible.role: Accessible.Button
        Accessible.name: tip
        Accessible.onPressAction: button.clicked()
        ToolTip.visible: buttonArea.containsMouse && tip !== ""
        ToolTip.delay: 500
        ToolTip.text: tip

        Rectangle {
            anchors.fill: parent
            radius: button.round ? width / 2 : 4
            color: button.round ? (buttonArea.containsMouse ? center.settings.controlHoverColor : center.settings.controlColor)
                : buttonArea.containsMouse ? center.settings.popupHoverColor : "transparent"
            border.width: button.round ? 1 : 0
            border.color: center.settings.controlBorderColor
        }

        Glyph {
            anchors.centerIn: parent
            text: button.glyph
            font.pixelSize: button.iconSize
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    // A quick setting: the tile toggles it, the arrow opens its page in Windows Settings
    component Tile: Rectangle {
        id: tile

        property string glyph
        property string title
        property string subtitle
        property bool on: false
        property string settingsPage: ""

        signal toggled

        Layout.fillWidth: true
        Layout.preferredHeight: 58
        radius: center.settings.tileRadius
        color: tileArea.containsMouse ? center.settings.controlHoverColor : center.settings.controlColor
        border.width: 1
        border.color: center.settings.controlBorderColor
        opacity: enabled ? 1 : 0.5
        Accessible.role: Accessible.CheckBox
        Accessible.name: `${title}, ${subtitle}`
        Accessible.checked: on
        Accessible.onPressAction: tile.toggled()

        MouseArea {
            id: tileArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 4
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: tile.on ? center.settings.accentColor : center.settings.popupHoverColor

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Glyph {
                    anchors.centerIn: parent
                    text: tile.glyph
                    color: tile.on ? center.settings.onAccentColor : center.settings.popupTextColor
                    font.pixelSize: 16
                }
            }

            Column {
                Layout.fillWidth: true

                Text {
                    width: parent.width
                    text: tile.title
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: center.settings.popupTextColor
                    font: center.settings.popupTitleFont
                }

                Text {
                    width: parent.width
                    text: tile.subtitle
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: center.settings.popupSecondaryTextColor
                    font: center.settings.popupSmallFont
                }
            }

            IconButton {
                visible: tile.settingsPage !== ""
                glyph: center.settings.icons.chevron
                iconSize: 10
                padding: 10
                tip: qsTr("%1 settings").arg(tile.title)
                onClicked: center.openUrl(tile.settingsPage)
            }
        }
    }

    // A box for a group of rows: the sliders, the power settings and the media
    component Card: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        radius: center.settings.cardRadius
        color: center.settings.popupCardColor
        border.width: 1
        border.color: center.settings.popupCardBorderColor
    }

    component LevelRow: RowLayout {
        id: level

        property string glyph
        property string tip
        property int value: 0
        // False dims the glyph and the slider, but leaves the source button usable
        property bool active: true
        // Whether the row has the source button, and what it says
        property bool selectable: false
        property string selectorTip

        signal moved(int value)
        signal glyphClicked
        signal selectorClicked(Item button)

        Layout.fillWidth: true
        spacing: 4

        IconButton {
            enabled: level.active
            glyph: level.glyph
            iconSize: 16
            tip: level.tip
            onClicked: level.glyphClicked()
        }

        Slider {
            Layout.fillWidth: true
            enabled: level.active
            from: 0
            to: 100
            value: level.value
            onMoved: level.moved(Math.round(value))
            Accessible.name: level.tip
        }

        Text {
            Layout.preferredWidth: 28
            horizontalAlignment: Text.AlignRight
            opacity: level.active ? 1 : 0.4
            text: level.value
            color: center.settings.popupTextColor
            font: center.settings.popupFont
        }

        IconButton {
            id: selector

            visible: level.selectable && center.settings.sourceSelector
            glyph: center.settings.icons.sourceSelector
            iconSize: 12
            padding: 10
            tip: level.selectorTip
            onClicked: level.selectorClicked(selector)
        }
    }

    // A menu in the widget's look
    component WidgetMenu: Menu {
        // A window of its own, so it shows whole even past the popup's edges
        popupType: Popup.Window
        // A press on the button that opened it is left to the button, which closes it again
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        // Its window is made once and reused, and Windows shows it again where it was, under the popup raised since;
        // raising it before it shows keeps it in front
        onAboutToShow: contentItem.Window.window?.raise()
        // Fades in when it opens, in place of the style's growing from a third of its height
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: center.settings.menuOpenDuration; easing.type: Easing.OutCubic }
        }
        topInset: 0
        leftInset: 0
        rightInset: 0
        bottomInset: 0
        font: center.settings.menuFont
        // Active and inactive only, so disabled controls keep the style's dimmed colours
        palette.active.text: center.settings.menuTextColor
        palette.inactive.text: center.settings.menuTextColor

        background: Rectangle {
            implicitWidth: center.settings.menuWidth
            radius: center.settings.menuRadius
            color: center.settings.menuColor
            border.color: center.settings.menuBorderColor
        }
    }

    // A menu of screens or devices, with a check on the one in use
    component SourceMenu: WidgetMenu {
        id: sourceMenu

        // The style's menu is as wide as its background, and cuts longer names short; screens often share a name,
        // so the menu grows to its widest item. Called before it opens, so it can be placed by its width
        function fitWidth() {
            let widest = center.settings.menuWidth
            for (let index = 0; index < sourceMenu.count; ++index) {
                const item = sourceMenu.itemAt(index) as SourceItem
                if (item)
                    widest = Math.max(widest, item.implicitWidth + sourceMenu.leftPadding + sourceMenu.rightPadding)
            }
            sourceMenu.width = widest
        }

        onAboutToShow: {
            contentItem.Window.window?.raise()
            // Qt checks an item itself when it is clicked, which would leave it apart from what is in use
            for (let index = 0; index < sourceMenu.count; ++index) {
                const item = sourceMenu.itemAt(index) as SourceItem
                if (item)
                    item.checked = item.current
            }
        }
    }

    component SourceItem: MenuItem {
        // Whether this is the screen or device in use
        property bool current: false

        checkable: true
    }

    component PowerChoice: RowLayout {
        id: choice

        property string title
        property var options
        property string selectedId
        property string placeholder: qsTr("Unavailable")
        property bool available: true

        signal selected(string id)

        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: choice.title
            elide: Text.ElideRight
            color: center.settings.popupTextColor
            font: center.settings.popupFont
        }

        ComboBox {
            Layout.preferredWidth: Math.min(180, center.settings.popupWidth / 2)
            enabled: choice.available && !center.powerBusy && choice.options.length > 0
            model: choice.options
            textRole: "name"
            valueRole: "id"
            currentIndex: enabled ? choice.options.findIndex(option => option.id === choice.selectedId) : -1
            displayText: choice.options.find(option => option.id === choice.selectedId)?.name ?? choice.placeholder
            font: center.settings.popupFont
            // A window of its own, so the list shows whole even past the popup's edges
            popup.popupType: Popup.Window
            Accessible.name: choice.title
            onActivated: index => choice.selected(valueAt(index))

            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }

    required property BarBase bar
    readonly property Theme theme: bar.theme
    readonly property Settings settings: Settings {
        theme: center.theme
    }

    readonly property string edge: bar.edge
    readonly property string activePlanId: PowerPlans.activeId
    readonly property bool powerBusy: PowerPlans.loading || PowerModes.loading
    // The plan the power modes were read for; they belong to the active plan
    property string modesPlanId: ""
    property bool refreshModesPending: false
    // The screen the brightness slider sets, by its subtitle; "" for the bar's screen
    property string brightnessScreen: ""
    // Whether that screen is connected, so its row shows in place of the bar's screen
    readonly property bool otherScreenShown: {
        if (brightnessScreen === "")
            return false
        for (let index = 0; index < screenRows.count; ++index) {
            if ((screenRows.itemAt(index) as LevelRow)?.objectName === brightnessScreen)
                return true
        }
        return false
    }

    function syncPowerModes() {
        if (!popup.visible || powerBusy || (!refreshModesPending && modesPlanId === activePlanId))
            return
        refreshModesPending = false
        modesPlanId = activePlanId
        PowerModes.refresh()
    }

    function volumeIcon(level: int, muted: bool): string {
        const icons = settings.icons
        return muted ? icons.volumeMuted : level === 0 ? icons.volume0 : level < 34 ? icons.volume1
            : level < 67 ? icons.volume2 : icons.volume3
    }

    // Segoe Fluent Icons has a battery glyph for each tenth, charging and not
    function batteryIcon(percent: int, charging: bool): string {
        return String.fromCodePoint((charging ? 0xEBAB : 0xEBA0) + Math.round(Math.max(0, Math.min(100, percent)) / 10))
    }

    function uptimeText(seconds: int): string {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor(seconds % 86400 / 3600)
        const minutes = Math.floor(seconds % 3600 / 60)
        if (days > 0)
            return qsTr("Up %1d %2h").arg(days).arg(hours)
        return hours > 0 ? qsTr("Up %1h %2m").arg(hours).arg(minutes) : qsTr("Up %1m").arg(minutes)
    }

    function openUrl(url: string) {
        popup.close()
        Qt.openUrlExternally(url)
    }

    // Opens under the button with its right edge on the button's, so it stays inside the popup
    function toggleMenu(menu: Menu, button: Item) {
        if (menu.visible) {
            menu.close()
            return
        }
        (menu as SourceMenu)?.fitWidth()
        menu.popup(button, button.width - menu.width, button.height)
    }

    function runShortcut(shortcut: var) {
        popup.close()
        if (shortcut.url) {
            Qt.openUrlExternally(shortcut.url)
        } else {
            launcher.command = shortcut.command
            launcher.start()
        }
    }

    function placePopup() {
        const start = mapToGlobal(0, 0)
        const gap = settings.popupGap
        let px = edge === "left" ? start.x + width + gap
            : edge === "right" ? start.x - popup.width - gap : start.x + (width - popup.width) / 2
        let py = edge === "top" ? start.y + height + gap
            : edge === "bottom" ? start.y - popup.height - gap : start.y + (height - popup.height) / 2
        const screen = center.Screen
        px = Math.max(screen.virtualX + 8, Math.min(px, screen.virtualX + screen.width - popup.width - 8))
        py = Math.max(screen.virtualY + 8, Math.min(py, screen.virtualY + screen.desktopAvailableHeight - popup.height - 8))
        popup.x = Math.round(px)
        popup.y = Math.round(py)
    }

    function togglePopup() {
        if (popup.visible) {
            popup.close()
            return
        }
        session.refresh()
        refreshModesPending = true
        if (!PowerPlans.loading)
            PowerPlans.refresh()
        placePopup()
        popup.open()
        Qt.callLater(syncPowerModes)
    }

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Control center")
    Accessible.onPressAction: togglePopup()
    Keys.onReturnPressed: togglePopup()
    Keys.onSpacePressed: togglePopup()

    onActivePlanIdChanged: Qt.callLater(syncPowerModes)
    onPowerBusyChanged: Qt.callLater(syncPowerModes)

    // The popup is a window of its own, so it goes when the widget does
    Component.onDestruction: popup.hide()

    NetworkConnections { id: network }
    BluetoothMonitor { id: bluetooth }
    DoNotDisturb { id: dnd }
    AudioInput { id: microphone }
    AudioOutput { id: speakers }
    DisplayBrightness { id: screenBrightness; window: center.Window.window }
    NowPlaying { id: player }
    BatteryMonitor { id: battery }
    PowerSession { id: session }
    Process { id: launcher }

    Hotkey {
        keys: center.settings.hotkey
        onActivated: center.togglePopup()
    }

    Connections {
        target: center.Window.window
        function onVisibleChanged() {
            if (!center.Window.window?.visible)
                popup.hide()
        }
        function onXChanged() { if (popup.visible) center.placePopup() }
        function onYChanged() { if (popup.visible) center.placePopup() }
    }

    Connections {
        target: popup
        function onHeightChanged() { if (popup.visible) center.placePopup() }
    }

    Text {
        id: label

        anchors.verticalCenter: parent.verticalCenter
        text: center.settings.icon
        textFormat: Text.PlainText
        color: center.settings.textColor
        font.family: center.settings.iconFont.family
        font.weight: center.settings.iconFont.weight
        font.variableAxes: center.settings.iconFont.variableAxes
        font.pixelSize: center.settings.iconSize
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: center.togglePopup()
    }

    BackdropPopup {
        id: popup

        property real reveal: 0

        objectName: "popup"
        title: "Control center"
        width: center.settings.popupWidth
        height: popupContent.implicitHeight
        anchor: center
        font: center.settings.popupFont
        theme: center.theme
        backdropItem: surface
        enter: NumberAnimation { target: popup; property: "reveal"; to: 1; duration: center.settings.popupOpenDuration; easing.type: Easing.OutCubic }
        exit: NumberAnimation { target: popup; property: "reveal"; to: 0; duration: center.settings.popupCloseDuration; easing.type: Easing.InCubic }
        onVisibleChanged: {
            if (!visible)
                reveal = 0
        }

        Rectangle {
            id: surface

            anchors.fill: parent
            radius: center.settings.popupRadius
            color: center.settings.popupColor
            // Active and inactive only, so disabled controls keep the style's dimmed colours
            palette.active.accent: center.settings.accentColor
            palette.inactive.accent: center.settings.accentColor
            border.width: 1
            border.color: center.settings.popupBorderColor
            opacity: popup.reveal
            scale: 0.85 + popup.reveal * 0.15
            transformOrigin: center.edge === "bottom" ? Item.Bottom : Item.Top

            ColumnLayout {
                id: popupContent

                width: parent.width
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14
                    Layout.rightMargin: 10
                    Layout.topMargin: 14
                    spacing: 10

                    Item {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32

                        // The first letter of your name, until your picture is loaded or when there is none
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: center.settings.popupHoverColor
                            visible: avatar.status !== Image.Ready

                            Text {
                                anchors.centerIn: parent
                                text: session.userName.charAt(0).toUpperCase()
                                color: center.settings.popupTextColor
                                font: center.settings.popupTitleFont
                            }
                        }

                        Item {
                            anchors.fill: parent
                            visible: avatar.status === Image.Ready
                            layer.enabled: visible
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: avatarMask
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1
                            }

                            Image {
                                id: avatar

                                anchors.fill: parent
                                source: session.avatar
                                sourceSize: Qt.size(64, 64)
                                fillMode: Image.PreserveAspectCrop
                            }
                        }

                        Rectangle {
                            id: avatarMask

                            anchors.fill: parent
                            radius: width / 2
                            visible: false
                            layer.enabled: true
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: session.userName
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: center.settings.popupTextColor
                        font: center.settings.popupTitleFont
                    }

                    IconButton {
                        glyph: center.settings.icons.settings
                        tip: qsTr("Settings")
                        onClicked: center.openUrl("ms-settings:")
                    }

                    IconButton {
                        id: powerButton

                        glyph: center.settings.icons.power
                        tip: qsTr("Power")
                        onClicked: center.toggleMenu(powerMenu, powerButton)
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8

                    Tile {
                        readonly property bool wired: network.primary.kind === "ethernet"

                        glyph: wired ? center.settings.icons.ethernet : center.settings.icons.wifi
                        title: wired ? qsTr("Ethernet") : qsTr("Wi-Fi")
                        subtitle: wired ? qsTr("Connected") : network.primary.ssid || network.primary.name || qsTr("Not connected")
                        on: network.primary.kind !== "none"
                        onToggled: center.openUrl(wired ? "ms-settings:network-ethernet" : "ms-settings:network-wifi")
                    }

                    Tile {
                        glyph: center.settings.icons.bluetooth
                        title: qsTr("Bluetooth")
                        subtitle: bluetooth.connected.length > 0 ? bluetooth.connected[0] : bluetooth.radioOn ? qsTr("On") : qsTr("Off")
                        on: bluetooth.radioOn
                        settingsPage: "ms-settings:bluetooth"
                        onToggled: bluetooth.setRadio(!bluetooth.radioOn)
                    }

                    Tile {
                        enabled: dnd.available
                        glyph: center.settings.icons.dnd
                        title: qsTr("Do not disturb")
                        subtitle: dnd.status === "priority" ? qsTr("Priority only") : dnd.status === "alarms" ? qsTr("Alarms only")
                            : dnd.status === "disabled" ? qsTr("Off") : qsTr("Not available")
                        on: dnd.active
                        settingsPage: "ms-settings:notifications"
                        onToggled: dnd.toggle(center.settings.dndMode)
                    }

                    Tile {
                        enabled: microphone.available
                        glyph: microphone.available && !microphone.muted ? center.settings.icons.microphone : center.settings.icons.microphoneOff
                        title: qsTr("Microphone")
                        subtitle: !microphone.available ? qsTr("No microphone") : microphone.muted ? qsTr("Muted") : microphone.deviceName
                        on: microphone.available && !microphone.muted
                        settingsPage: "ms-settings:sound"
                        onToggled: microphone.toggleMute()
                    }
                }

                RowLayout {
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    visible: center.settings.shortcuts.length > 0
                    spacing: 8

                    Repeater {
                        model: center.settings.shortcuts

                        delegate: IconButton {
                            required property var modelData

                            glyph: modelData.icon
                            iconSize: 16
                            round: true
                            tip: modelData.label
                            onClicked: center.runShortcut(modelData)
                        }
                    }
                }

                Card {
                    implicitHeight: levels.implicitHeight + 12

                    ColumnLayout {
                        id: levels

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 4
                        anchors.rightMargin: 10
                        spacing: 0

                        // The bar's screen, unless another screen is picked and connected
                        LevelRow {
                            visible: (screenBrightness.available || screenBrightness.displays.count > 0) && !center.otherScreenShown
                            active: screenBrightness.available
                            glyph: center.settings.icons.brightness
                            tip: qsTr("Brightness")
                            value: Math.max(0, screenBrightness.brightness)
                            selectable: screenBrightness.displays.count > 0
                            selectorTip: qsTr("Choose a screen")
                            onMoved: value => screenBrightness.setBrightness(value)
                            onSelectorClicked: button => center.toggleMenu(screenMenu, button)
                        }

                        // The picked screen; its subtitle names it, as Monitor 2 and so on
                        Repeater {
                            id: screenRows

                            model: screenBrightness.displays

                            delegate: LevelRow {
                                id: screenRow

                                required property int monitor
                                required property string name
                                required property string subtitle
                                required property int brightness

                                objectName: subtitle
                                visible: subtitle === center.brightnessScreen
                                active: brightness >= 0
                                glyph: center.settings.icons.brightness
                                tip: qsTr("Brightness of %1").arg(name)
                                value: Math.max(0, brightness)
                                selectable: true
                                selectorTip: qsTr("Choose a screen")
                                onMoved: value => screenBrightness.setDisplayBrightness(screenRow.monitor, value)
                                onSelectorClicked: button => center.toggleMenu(screenMenu, button)
                            }
                        }

                        LevelRow {
                            active: speakers.available
                            glyph: center.volumeIcon(speakers.volume, speakers.muted)
                            tip: speakers.muted ? qsTr("Unmute") : qsTr("Mute")
                            value: speakers.volume
                            selectable: speakers.devices.length > 0
                            selectorTip: qsTr("Choose a speaker")
                            onMoved: value => speakers.setVolume(value)
                            onGlyphClicked: speakers.toggleMute()
                            onSelectorClicked: button => center.toggleMenu(speakerMenu, button)
                        }

                        LevelRow {
                            visible: microphone.available
                            glyph: microphone.muted ? center.settings.icons.microphoneOff : center.settings.icons.microphone
                            tip: microphone.muted ? qsTr("Unmute microphone") : qsTr("Mute microphone")
                            value: microphone.volume
                            selectable: microphone.devices.length > 0
                            selectorTip: qsTr("Choose a microphone")
                            onMoved: value => microphone.setVolume(value)
                            onGlyphClicked: microphone.toggleMute()
                            onSelectorClicked: button => center.toggleMenu(microphoneMenu, button)
                        }
                    }
                }

                Card {
                    implicitHeight: powerSettings.implicitHeight + 16

                    ColumnLayout {
                        id: powerSettings

                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        PowerChoice {
                            title: qsTr("Power plan")
                            options: PowerPlans.plans
                            selectedId: center.activePlanId
                            placeholder: PowerPlans.loading ? qsTr("Reading…") : qsTr("No plans found")
                            onSelected: id => PowerPlans.selectPlan(id)
                        }

                        PowerChoice {
                            title: battery.available ? qsTr("Power mode (plugged in)") : qsTr("Power mode")
                            options: PowerModes.modes
                            selectedId: available ? PowerModes.acModeId : ""
                            available: PowerModes.supported && center.modesPlanId === center.activePlanId
                            placeholder: center.powerBusy ? qsTr("Reading…") : qsTr("Unavailable")
                            onSelected: id => PowerModes.setMode(id, "ac")
                        }

                        PowerChoice {
                            visible: battery.available && available
                            title: qsTr("Power mode (on battery)")
                            options: PowerModes.modes
                            selectedId: PowerModes.dcModeId
                            available: PowerModes.supported && center.modesPlanId === center.activePlanId
                            onSelected: id => PowerModes.setMode(id, "dc")
                        }

                        Text {
                            readonly property string error: PowerPlans.error || PowerModes.error

                            Layout.fillWidth: true
                            visible: text !== ""
                            text: error || (!center.powerBusy && !PowerModes.supported
                                ? qsTr("Power mode depends on your Windows version and active power plan.") : "")
                            color: error ? center.settings.errorColor : center.settings.popupSecondaryTextColor
                            font: center.settings.popupSmallFont
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                        }

                        LoadingLine {
                            Layout.fillWidth: true
                            visible: running
                            running: center.powerBusy
                        }
                    }
                }

                Card {
                    visible: player.available
                    implicitHeight: 64

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        Item {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            visible: cover.status === Image.Ready
                            layer.enabled: visible
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: coverMask
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1
                            }

                            Image {
                                id: cover

                                anchors.fill: parent
                                source: player.thumbnail
                                sourceSize: Qt.size(96, 96)
                                fillMode: Image.PreserveAspectCrop
                            }

                            Rectangle {
                                id: coverMask

                                anchors.fill: parent
                                radius: 6
                                visible: false
                                layer.enabled: true
                            }
                        }

                        Column {
                            Layout.fillWidth: true

                            Text {
                                width: parent.width
                                text: player.title
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: center.settings.popupTextColor
                                font: center.settings.popupTitleFont
                            }

                            Text {
                                width: parent.width
                                text: player.artist || player.appName
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: center.settings.popupSecondaryTextColor
                                font: center.settings.popupSmallFont
                            }
                        }

                        IconButton {
                            glyph: center.settings.icons.previous
                            enabled: player.canPrevious
                            tip: qsTr("Previous")
                            onClicked: player.previous()
                        }

                        IconButton {
                            glyph: player.playing ? center.settings.icons.pause : center.settings.icons.play
                            iconSize: 16
                            enabled: player.canPlayPause
                            tip: player.playing ? qsTr("Pause") : qsTr("Play")
                            onClicked: player.playPause()
                        }

                        IconButton {
                            glyph: center.settings.icons.next
                            enabled: player.canNext
                            tip: qsTr("Next")
                            onClicked: player.next()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 1
                    Layout.rightMargin: 1
                    Layout.bottomMargin: 1
                    implicitHeight: 40
                    bottomLeftRadius: Math.max(0, center.settings.popupRadius - 1)
                    bottomRightRadius: Math.max(0, center.settings.popupRadius - 1)
                    color: center.settings.popupFooterColor

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: center.settings.popupDividerColor
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                        visible: battery.available
                        spacing: 6

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: center.batteryIcon(battery.data.percent, battery.data.charging)
                            font.pixelSize: 16
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: battery.data.charging ? qsTr("%1%, charging").arg(battery.data.percent) : `${battery.data.percent}%`
                            color: center.settings.popupSecondaryTextColor
                            font: center.settings.popupSmallFont
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                        text: center.uptimeText(session.uptime)
                        color: center.settings.popupSecondaryTextColor
                        font: center.settings.popupSmallFont
                    }
                }
            }

            SourceMenu {
                id: screenMenu

                Instantiator {
                    model: screenBrightness.displays

                    delegate: SourceItem {
                        required property int monitor
                        required property string name
                        required property string subtitle

                        text: `${name} · ${subtitle}`
                        current: center.otherScreenShown ? subtitle === center.brightnessScreen : monitor === screenBrightness.monitor
                        onTriggered: center.brightnessScreen = monitor === screenBrightness.monitor ? "" : subtitle
                    }

                    onObjectAdded: (index, object) => screenMenu.insertItem(index, object as SourceItem)
                    onObjectRemoved: (index, object) => screenMenu.removeItem(object as SourceItem)
                }
            }

            SourceMenu {
                id: speakerMenu

                Instantiator {
                    model: speakers.devices

                    delegate: SourceItem {
                        required property var modelData

                        text: modelData.name
                        current: modelData.current
                        onTriggered: speakers.setDevice(modelData.id)
                    }

                    onObjectAdded: (index, object) => speakerMenu.insertItem(index, object as SourceItem)
                    onObjectRemoved: (index, object) => speakerMenu.removeItem(object as SourceItem)
                }
            }

            SourceMenu {
                id: microphoneMenu

                Instantiator {
                    model: microphone.devices

                    delegate: SourceItem {
                        required property var modelData

                        text: modelData.name
                        current: modelData.current
                        onTriggered: microphone.setDevice(modelData.id)
                    }

                    onObjectAdded: (index, object) => microphoneMenu.insertItem(index, object as SourceItem)
                    onObjectRemoved: (index, object) => microphoneMenu.removeItem(object as SourceItem)
                }
            }

            WidgetMenu {
                id: powerMenu

                MenuItem {
                    text: qsTr("Lock")
                    onTriggered: { popup.close(); session.run("lock") }
                }

                MenuItem {
                    text: qsTr("Sleep")
                    onTriggered: { popup.close(); session.run("sleep") }
                }

                MenuItem {
                    text: qsTr("Sign out")
                    onTriggered: { popup.close(); session.run("signout") }
                }

                MenuSeparator {}

                MenuItem {
                    text: qsTr("Restart")
                    onTriggered: { popup.close(); session.run("restart") }
                }

                MenuItem {
                    text: qsTr("Shut down")
                    onTriggered: { popup.close(); session.run("shutdown") }
                }
            }
        }
    }
}
