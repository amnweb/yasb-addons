pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Particles
import QtQuick.Shapes
import Yasb
import Yasb.Bar
import Yasb.Themes

Item {
    id: orbit

    component Icons: QtObject {
        // In place of your picture while there is none
        property string user
        property string lock
        property string signout
        property string sleep
        property string hibernate
        property string restart
        property string shutdown
        property string forceRestart
        property string forceShutdown
    }

    component Settings: QtObject {
        required property Theme theme

        // The glyph on the bar
        property string icon: "\ue7e8"
        property int iconSize: theme.bar.iconFont.pixelSize
        property color textColor: theme.colors.text
        property font iconFont
        iconFont.family: theme.bar.iconFont.family
        iconFont.weight: theme.bar.iconFont.weight
        iconFont.variableAxes: theme.bar.iconFont.variableAxes
        // The orbs, clockwise from the top. Actions: lock, signout, sleep, hibernate, restart, shutdown, force_restart,
        // force_shutdown
        property var actions: [
            { action: "lock", label: qsTr("Lock") },
            { action: "sleep", label: qsTr("Sleep") },
            { action: "signout", label: qsTr("Sign out") },
            { action: "restart", label: qsTr("Restart") },
            { action: "shutdown", label: qsTr("Shut down") }
        ]
        // Milliseconds an orb has to be held before its action runs
        property int holdDuration: 800
        // Your picture and name in the middle of the ring, and the uptime under them
        property bool showUser: true
        property bool showUptime: true
        // Dust drifting behind the ring, comet trails while the orbs fly, and sparks when an action runs
        property bool particles: true
        // How dark the screen gets, 0 to 1
        property real dim: 0.6
        property int ringRadius: 230
        property int orbSize: 92
        property int avatarSize: 112
        // Degrees the neighbours of the orb under the pointer lean away
        property real pushAngle: 9
        // Milliseconds for the whole ring to turn once; 0 keeps it still
        property int driftDuration: 180000
        property int openDuration: 700
        property int closeDuration: 320
        // The hold ring, the glow, the shockwave and the sparks
        property color accentColor: theme.colors.accent
        // Text, glyphs and orbs, always over the darkened screen
        property color menuColor: "#ffffff"
        property font nameFont
        nameFont.family: theme.popup.font.family
        nameFont.pixelSize: 26
        nameFont.weight: 600
        // The action's name in the middle while an orb is under the pointer
        property font actionFont
        actionFont.family: theme.popup.font.family
        actionFont.pixelSize: 26
        actionFont.weight: 600
        property font labelFont
        labelFont.family: theme.popup.font.family
        labelFont.pixelSize: 13
        labelFont.weight: 600
        property font smallFont
        smallFont.family: theme.popup.font.family
        smallFont.pixelSize: 12
        property int orbIconSize: 28
        property font popupIconFont
        popupIconFont.family: theme.popup.iconFont.family
        popupIconFont.weight: theme.popup.iconFont.weight
        popupIconFont.variableAxes: theme.popup.iconFont.variableAxes
        readonly property Icons icons: Icons {
            user: "\ue77b"
            lock: "\ue72e"
            signout: "\uf3b1"
            sleep: "\ue708"
            hibernate: "\ue823"
            restart: "\ue777"
            shutdown: "\ue7e8"
            forceRestart: "\ue777"
            forceShutdown: "\ue7e8"
        }
    }

    required property BarBase bar
    readonly property Theme theme: bar.theme
    readonly property Settings settings: Settings {
        theme: orbit.theme
    }

    // Held so the garbage collector doesn't destroy the open menu
    property Window opened: null

    function open() {
        if (opened)
            return
        const screen = orbit.Screen
        const from = mapToGlobal(width / 2, height / 2)
        opened = overlay.createObject(null, {
            area: Qt.rect(screen.virtualX, screen.virtualY, screen.width, screen.height),
            origin: Qt.point(from.x - screen.virtualX, from.y - screen.virtualY)
        })
    }

    // force_restart reads icons.forceRestart
    function actionIcon(action: string): string {
        return settings.icons[action.replace(/_(\w)/g, (match, letter) => letter.toUpperCase())] ?? ""
    }

    function uptimeText(seconds: int): string {
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor(seconds % 86400 / 3600)
        const minutes = Math.floor(seconds % 3600 / 60)
        if (days > 0)
            return qsTr("Up %1 d %2 h").arg(days).arg(hours)
        if (hours > 0)
            return qsTr("Up %1 h %2 min").arg(hours).arg(minutes)
        return qsTr("Up %1 min").arg(minutes)
    }

    implicitWidth: settings.iconSize
    implicitHeight: settings.iconSize
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Power menu")
    Accessible.onPressAction: open()

    PowerSession {
        id: power
    }

    Text {
        anchors.centerIn: parent
        text: orbit.settings.icon
        textFormat: Text.PlainText
        color: orbit.settings.textColor
        font.family: orbit.settings.iconFont.family
        font.weight: orbit.settings.iconFont.weight
        font.variableAxes: orbit.settings.iconFont.variableAxes
        font.pixelSize: orbit.settings.iconSize
        scale: iconArea.containsMouse ? 1.18 : 1
        rotation: iconArea.containsMouse ? 90 : 0

        Behavior on scale {
            SpringAnimation { spring: 4; damping: 0.25 }
        }

        Behavior on rotation {
            SpringAnimation { spring: 3; damping: 0.3 }
        }
    }

    MouseArea {
        id: iconArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: orbit.open()
    }

    Component {
        id: overlay

        Window {
            id: window

            required property rect area
            // The bar's icon, where the orbs fly out from and back to, in this window
            required property point origin
            readonly property int count: orbit.settings.actions.length
            // The shade, the ring and the middle, 0 to 1
            property real reveal: 0
            // opening, open, closing or confirming
            property string phase: "opening"
            // The orb under the pointer or chosen with the keys, -1 for none
            property int hovered: -1
            property real spin: 0
            // While an action runs: the orb, where it is, how far the others are pulled into it, the shockwave, and the
            // screen folding up like an old CRT
            property int chosen: -1
            property point chosenPoint: Qt.point(0, 0)
            property real collapse: 0
            property real shock: 0
            property real crtY: 1
            property real crtX: 1
            property real flash: 0

            signal launched
            signal recalled
            // Enter, Return or Space held on the orb chosen with the arrow keys
            signal holdStarted(int index)
            signal holdCancelled(int index)

            function dismiss() {
                if (phase === "closing" || phase === "confirming")
                    return
                phase = "closing"
                openAnimation.stop()
                closeAnimation.start()
            }

            function confirm(index: int) {
                if (phase !== "open")
                    return
                const orb = orbs.itemAt(index)
                if (!orb)
                    return
                phase = "confirming"
                chosen = index
                chosenPoint = Qt.point(orb.x + orb.width / 2, orb.y + orb.height / 2)
                confirmAnimation.start()
            }

            function step(direction: int) {
                if (count > 0)
                    hovered = hovered < 0 ? 0 : (hovered + direction + count) % count
            }

            flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
            color: "transparent"
            x: area.x
            y: area.y
            width: area.width
            height: area.height

            Component.onCompleted: {
                power.refresh()
                visible = true
                requestActivate()
                openAnimation.start()
            }

            onActiveChanged: {
                if (!active)
                    dismiss()
            }

            onVisibleChanged: {
                if (visible)
                    return
                // Cleared now, the window itself is deleted later, so the menu can open again straight away
                orbit.opened = null
                destroy()
            }

            ParallelAnimation {
                id: openAnimation

                ScriptAction { script: window.launched() }
                NumberAnimation {
                    target: window
                    property: "reveal"
                    to: 1
                    duration: orbit.settings.openDuration
                    easing.type: Easing.OutCubic
                }
                // Until the last orb has landed
                PauseAnimation { duration: orbit.settings.openDuration + window.count * 70 }

                onFinished: window.phase = "open"
            }

            SequentialAnimation {
                id: closeAnimation

                ParallelAnimation {
                    ScriptAction { script: window.recalled() }
                    NumberAnimation {
                        target: window
                        property: "reveal"
                        to: 0
                        duration: orbit.settings.closeDuration + window.count * 35
                        easing.type: Easing.InCubic
                    }
                }
                ScriptAction { script: window.close() }
            }

            SequentialAnimation {
                id: confirmAnimation

                // The other orbs fall into the chosen one
                NumberAnimation {
                    target: window
                    property: "collapse"
                    to: 1
                    duration: 380
                    easing.type: Easing.InCubic
                }
                ScriptAction {
                    script: {
                        if (orbit.settings.particles)
                            sparks.burst(90, window.chosenPoint.x, window.chosenPoint.y)
                    }
                }
                NumberAnimation {
                    target: window
                    property: "shock"
                    to: 1
                    duration: 620
                    easing.type: Easing.OutCubic
                }
                // The screen folds to a bright line, then to a dot, and goes out
                ParallelAnimation {
                    NumberAnimation {
                        target: window
                        property: "crtY"
                        to: 0.004
                        duration: 240
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: window
                        property: "flash"
                        to: 0.9
                        duration: 240
                        easing.type: Easing.InQuad
                    }
                }
                NumberAnimation {
                    target: window
                    property: "crtX"
                    to: 0
                    duration: 200
                    easing.type: Easing.InQuad
                }
                ScriptAction {
                    script: {
                        const action = orbit.settings.actions[window.chosen].action
                        window.close()
                        power.run(action)
                    }
                }
            }

            NumberAnimation on spin {
                from: 0
                to: 360
                duration: Math.max(1, orbit.settings.driftDuration)
                loops: Animation.Infinite
                running: orbit.settings.driftDuration > 0 && window.phase !== "confirming"
            }

            // Everything folds up together at the end
            Item {
                id: stage

                anchors.fill: parent
                transform: Scale {
                    origin.x: stage.width / 2
                    origin.y: stage.height / 2
                    xScale: window.crtX
                    yScale: window.crtY
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha("#000000", orbit.settings.dim)
                    opacity: window.reveal
                }

                // A soft glow of the accent colour behind the ring
                Shape {
                    anchors.fill: parent
                    opacity: window.reveal
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {
                            centerX: window.width / 2
                            centerY: window.height / 2
                            centerRadius: orbit.settings.ringRadius * 1.7
                            focalX: centerX
                            focalY: centerY

                            GradientStop { position: 0; color: Qt.alpha(orbit.settings.accentColor, 0.22) }
                            GradientStop { position: 1; color: "transparent" }
                        }

                        PathRectangle {
                            width: window.width
                            height: window.height
                        }
                    }
                }

                // A click anywhere but an orb closes the menu
                MouseArea {
                    anchors.fill: parent
                    onClicked: window.dismiss()
                }

                ParticleSystem {
                    id: particles

                    anchors.fill: parent
                    running: orbit.settings.particles

                    ItemParticle {
                        groups: ["dust"]
                        fade: true

                        delegate: Rectangle {
                            width: 3
                            height: 3
                            radius: 1.5
                            color: Qt.alpha(orbit.settings.menuColor, 0.35)
                        }
                    }

                    ItemParticle {
                        groups: ["trail", "spark"]
                        fade: true

                        delegate: Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: orbit.settings.accentColor
                        }
                    }

                    Emitter {
                        anchors.fill: parent
                        group: "dust"
                        enabled: orbit.settings.particles && window.phase !== "confirming"
                        emitRate: 10
                        lifeSpan: 7000
                        lifeSpanVariation: 2000
                        velocity: AngleDirection {
                            angleVariation: 360
                            magnitude: 14
                            magnitudeVariation: 10
                        }
                    }

                    Emitter {
                        id: sparks

                        group: "spark"
                        enabled: false
                        lifeSpan: 900
                        lifeSpanVariation: 300
                        velocity: AngleDirection {
                            angleVariation: 360
                            magnitude: 420
                            magnitudeVariation: 220
                        }
                    }

                    Friction {
                        groups: ["spark"]
                        factor: 2.5
                    }
                }

                // The path the orbs drift along, drawn round as the menu opens
                Shape {
                    anchors.fill: parent
                    opacity: 0.6 * window.reveal * (1 - window.collapse)
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Qt.alpha(orbit.settings.menuColor, 0.14)
                        strokeWidth: 1
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [4, 6]
                        fillColor: "transparent"

                        PathAngleArc {
                            centerX: window.width / 2
                            centerY: window.height / 2
                            radiusX: orbit.settings.ringRadius
                            radiusY: orbit.settings.ringRadius
                            startAngle: window.spin - 90
                            sweepAngle: 360 * window.reveal
                        }
                    }
                }

                // In the middle: your picture and name, or the action of the orb under the pointer
                Column {
                    anchors.centerIn: parent
                    spacing: 14
                    opacity: window.reveal * (1 - window.collapse)
                    scale: 0.7 + 0.3 * window.reveal

                    Item {
                        id: avatar

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: orbit.settings.avatarSize
                        height: orbit.settings.avatarSize
                        visible: orbit.settings.showUser

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Qt.alpha(orbit.settings.menuColor, 0.1)
                            border.color: Qt.alpha(orbit.settings.menuColor, 0.2)
                            visible: picture.status !== Image.Ready

                            Text {
                                anchors.centerIn: parent
                                text: orbit.settings.icons.user
                                textFormat: Text.PlainText
                                color: orbit.settings.menuColor
                                font.family: orbit.settings.popupIconFont.family
                                font.weight: orbit.settings.popupIconFont.weight
                                font.variableAxes: orbit.settings.popupIconFont.variableAxes
                                font.pixelSize: Math.round(orbit.settings.avatarSize * 0.4)
                            }
                        }

                        Item {
                            anchors.fill: parent
                            visible: picture.status === Image.Ready
                            layer.enabled: visible
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: circle
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1
                            }

                            Image {
                                id: picture

                                anchors.fill: parent
                                source: power.avatar
                                sourceSize: Qt.size(orbit.settings.avatarSize * 2, orbit.settings.avatarSize * 2)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            Rectangle {
                                id: circle

                                anchors.fill: parent
                                radius: width / 2
                                visible: false
                                layer.enabled: true
                            }
                        }

                        // A ring of the accent colour that breathes while the menu is open
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 14
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: orbit.settings.accentColor

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: window.visible

                                NumberAnimation { from: 0.15; to: 0.6; duration: 1600; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 0.6; to: 0.15; duration: 1600; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    // The name and the action share a place, and cross over
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.max(nameText.implicitWidth, actionText.implicitWidth)
                        height: Math.max(nameText.implicitHeight, actionText.implicitHeight)

                        Text {
                            id: nameText

                            anchors.centerIn: parent
                            text: orbit.settings.showUser ? power.userName : "" 
                            textFormat: Text.PlainText
                            color: orbit.settings.menuColor
                            font: orbit.settings.nameFont
                            opacity: window.hovered < 0 ? 1 : 0
                            scale: window.hovered < 0 ? 1 : 0.8

                            Behavior on opacity {
                                NumberAnimation { duration: 180 }
                            }

                            Behavior on scale {
                                SpringAnimation { spring: 4; damping: 0.3 }
                            }
                        }

                        Text {
                            id: actionText

                            anchors.centerIn: parent
                            text: window.hovered < 0 ? "" : orbit.settings.actions[window.hovered]?.label ?? ""
                            textFormat: Text.PlainText
                            color: orbit.settings.menuColor
                            font: orbit.settings.actionFont
                            opacity: window.hovered < 0 ? 0 : 1
                            scale: window.hovered < 0 ? 1.2 : 1

                            Behavior on opacity {
                                NumberAnimation { duration: 180 }
                            }

                            Behavior on scale {
                                SpringAnimation { spring: 4; damping: 0.3 }
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: orbit.settings.showUptime
                        text: orbit.uptimeText(power.uptime)
                        textFormat: Text.PlainText
                        color: Qt.alpha(orbit.settings.menuColor, 0.6)
                        font: orbit.settings.smallFont
                    }
                }

                // The shockwave from the chosen orb
                Rectangle {
                    readonly property real size: 40 + window.shock * Math.max(window.width, window.height) * 1.3

                    x: window.chosenPoint.x - size / 2
                    y: window.chosenPoint.y - size / 2
                    width: size
                    height: size
                    radius: size / 2
                    visible: window.shock > 0 && window.shock < 1
                    color: "transparent"
                    border.width: 2 + 6 * (1 - window.shock)
                    border.color: orbit.settings.accentColor
                    opacity: 1 - window.shock
                }

                Repeater {
                    id: orbs

                    model: orbit.settings.actions

                    delegate: Item {
                        id: orb

                        required property var modelData
                        required property int index

                        // 0 at the bar's icon, 1 in its place on the ring; it overshoots on the way out
                        property real progress: 0
                        // 0 to 1 while held
                        property real hold: 0
                        readonly property bool active: window.hovered === index
                        // Neighbours of the orb under the pointer lean away from it, the nearest the most
                        readonly property real pushTarget: {
                            if (window.hovered < 0 || active)
                                return 0
                            let distance = ((index - window.hovered) % window.count + window.count) % window.count
                            if (distance > window.count / 2)
                                distance -= window.count
                            return Math.sign(distance) * orbit.settings.pushAngle / Math.abs(distance)
                        }
                        property real push: pushTarget
                        property real swell: active ? 1.22 : 1
                        readonly property real angle: (window.spin + push - 90 + index * 360 / Math.max(1, window.count)) * Math.PI / 180
                        readonly property point slot: Qt.point(window.width / 2 + orbit.settings.ringRadius * Math.cos(angle),
                            window.height / 2 + orbit.settings.ringRadius * Math.sin(angle))
                        // A curve from the bar's icon to the slot, bent to alternate sides
                        readonly property point bend: {
                            const dx = slot.x - window.origin.x
                            const dy = slot.y - window.origin.y
                            const side = index % 2 === 0 ? 0.35 : -0.35
                            return Qt.point((window.origin.x + slot.x) / 2 - dy * side, (window.origin.y + slot.y) / 2 + dx * side)
                        }
                        readonly property point onPath: {
                            const t = progress
                            const u = 1 - t
                            return Qt.point(u * u * window.origin.x + 2 * u * t * bend.x + t * t * slot.x,
                                u * u * window.origin.y + 2 * u * t * bend.y + t * t * slot.y)
                        }
                        readonly property real pull: index === window.chosen ? 0 : window.collapse
                        readonly property point at: Qt.point(onPath.x + (window.chosenPoint.x - onPath.x) * pull,
                            onPath.y + (window.chosenPoint.y - onPath.y) * pull)

                        function startHold() {
                            if (window.phase !== "open")
                                return
                            release.stop()
                            holding.start()
                        }

                        function cancelHold() {
                            if (window.phase !== "open")
                                return
                            holding.stop()
                            release.start()
                        }

                        x: at.x - width / 2
                        y: at.y - height / 2
                        width: orbit.settings.orbSize
                        height: orbit.settings.orbSize
                        z: active ? 1 : 0
                        opacity: Math.min(1, progress * 2) * (1 - pull)
                        scale: Math.max(0.2, Math.min(progress, 1.2)) * swell * (1 - 0.6 * pull)
                            * (index === window.chosen ? 1 + 0.4 * window.collapse : 1)
                        // Spins in as it flies out
                        rotation: (1 - Math.min(progress, 1)) * -220
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.label ?? modelData.action
                        Accessible.onPressAction: window.confirm(index)

                        Behavior on push {
                            SpringAnimation { spring: 3; damping: 0.28 }
                        }

                        Behavior on swell {
                            SpringAnimation { spring: 4; damping: 0.22 }
                        }

                        Connections {
                            target: window

                            function onLaunched() {
                                flyBack.stop()
                                flyOut.start()
                            }

                            function onHoldStarted(index: int) {
                            if (index === orb.index)
                                orb.startHold()
                        }

                        function onHoldCancelled(index: int) {
                            if (index === orb.index)
                                orb.cancelHold()
                        }

                        function onRecalled() {
                                flyOut.stop()
                                holding.stop()
                                orb.hold = 0
                                flyBack.start()
                            }
                        }

                        SequentialAnimation {
                            id: flyOut

                            PauseAnimation { duration: orb.index * 70 }
                            NumberAnimation {
                                target: orb
                                property: "progress"
                                to: 1
                                duration: orbit.settings.openDuration
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.6
                            }
                        }

                        SequentialAnimation {
                            id: flyBack

                            PauseAnimation { duration: (window.count - 1 - orb.index) * 35 }
                            NumberAnimation {
                                target: orb
                                property: "progress"
                                to: 0
                                duration: orbit.settings.closeDuration
                                easing.type: Easing.InBack
                            }
                        }

                        NumberAnimation {
                            id: holding

                            target: orb
                            property: "hold"
                            to: 1
                            duration: orbit.settings.holdDuration * (1 - orb.hold)
                            onFinished: {
                                if (orb.hold >= 1)
                                    window.confirm(orb.index)
                            }
                        }

                        NumberAnimation {
                            id: release

                            target: orb
                            property: "hold"
                            to: 0
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                        // A comet tail while it flies
                        Emitter {
                            system: particles
                            anchors.centerIn: parent
                            width: 8
                            height: 8
                            group: "trail"
                            enabled: orbit.settings.particles && orb.progress > 0.04 && orb.progress < 0.96
                                && window.phase === "opening"
                            emitRate: 90
                            lifeSpan: 420
                            lifeSpanVariation: 120
                            velocity: AngleDirection {
                                angleVariation: 360
                                magnitude: 18
                            }
                        }

                        // A glow of the accent colour behind the orb under the pointer
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 1.5
                            height: width
                            radius: width / 2
                            color: orbit.settings.accentColor
                            opacity: orb.active ? 0.35 : 0
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                blurEnabled: true
                                blur: 1
                                blurMax: 48
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: 200 }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Qt.alpha(orbit.settings.menuColor, orb.active ? 0.2 : 0.09)
                            border.width: 1
                            border.color: Qt.alpha(orbit.settings.menuColor, orb.active ? 0.5 : 0.18)

                            Behavior on color {
                                ColorAnimation { duration: 160 }
                            }
                        }

                        // Fills round as the orb is held
                        Shape {
                            anchors.centerIn: parent
                            width: parent.width + 14
                            height: width
                            visible: orb.hold > 0
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeColor: orbit.settings.accentColor
                                strokeWidth: 4
                                capStyle: ShapePath.RoundCap
                                fillColor: "transparent"

                                PathAngleArc {
                                    centerX: (orbit.settings.orbSize + 14) / 2
                                    centerY: (orbit.settings.orbSize + 14) / 2
                                    radiusX: (orbit.settings.orbSize + 14) / 2 - 2
                                    radiusY: (orbit.settings.orbSize + 14) / 2 - 2
                                    startAngle: -90
                                    sweepAngle: 360 * orb.hold
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: orbit.actionIcon(orb.modelData.action)
                            textFormat: Text.PlainText
                            color: orbit.settings.menuColor
                            font.family: orbit.settings.popupIconFont.family
                            font.weight: orbit.settings.popupIconFont.weight
                            font.variableAxes: orbit.settings.popupIconFont.variableAxes
                            font.pixelSize: orbit.settings.orbIconSize
                            // Upright while the orb spins in
                            rotation: -orb.rotation
                        }

                        // The label slides out from under the orb under the pointer
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height + (orb.active ? 12 : 2)
                            text: orb.modelData.label ?? orb.modelData.action
                            textFormat: Text.PlainText
                            color: orbit.settings.menuColor
                            font: orbit.settings.labelFont
                            opacity: orb.active ? 1 : 0
                            rotation: -orb.rotation

                            Behavior on y {
                                SpringAnimation { spring: 4; damping: 0.3 }
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: 160 }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: window.hovered = orb.index
                            onExited: {
                                if (window.hovered === orb.index && !pressed)
                                    window.hovered = -1
                            }
                            onPressed: orb.startHold()
                            onReleased: orb.cancelHold()
                            onCanceled: orb.cancelHold()
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 56
                    text: qsTr("Hold an orb to run it · Esc to close")
                    textFormat: Text.PlainText
                    color: Qt.alpha(orbit.settings.menuColor, 0.45)
                    font: orbit.settings.smallFont
                    opacity: window.reveal * (1 - window.collapse)
                }

                // The last moment of the CRT: a bright line, then a dot
                Rectangle {
                    anchors.fill: parent
                    color: orbit.settings.menuColor
                    opacity: window.flash
                }
            }

            FocusScope {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: window.dismiss()
                Keys.onLeftPressed: window.step(-1)
                Keys.onUpPressed: window.step(-1)
                Keys.onRightPressed: window.step(1)
                Keys.onDownPressed: window.step(1)
                Keys.onPressed: event => {
                    if (event.isAutoRepeat || window.hovered < 0)
                        return
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        window.holdStarted(window.hovered)
                        event.accepted = true
                    }
                }
                Keys.onReleased: event => {
                    if (event.isAutoRepeat || window.hovered < 0)
                        return
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        window.holdCancelled(window.hovered)
                        event.accepted = true
                    }
                }
            }
        }
    }
}
