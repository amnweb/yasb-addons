import QtQuick
import Yasb.Themes

// Mocha when Windows is dark, Latte when it is light
Theme {
    id: catppuccin

    component Palette: QtObject {
        property color mauve
        property color red
        property color yellow
        property color green
        property color text
        property color subtext1
        property color overlay1
        property color overlay0
        property color surface2
        property color surface1
        property color surface0
        property color base
        property color mantle
        property color crust
    }

    readonly property Palette mocha: Palette {
        mauve: "#CBA6F7"
        red: "#F38BA8"
        yellow: "#F9E2AF"
        green: "#A6E3A1"
        text: "#CDD6F4"
        subtext1: "#BAC2DE"
        overlay1: "#7F849C"
        overlay0: "#6C7086"
        surface2: "#585B70"
        surface1: "#45475A"
        surface0: "#313244"
        base: "#1E1E2E"
        mantle: "#181825"
        crust: "#11111B"
    }

    readonly property Palette latte: Palette {
        mauve: "#8839EF"
        red: "#D20F39"
        yellow: "#DF8E1D"
        green: "#40A02B"
        text: "#4C4F69"
        subtext1: "#5C5F77"
        overlay1: "#8C8FA1"
        overlay0: "#9CA0B0"
        surface2: "#ACB0BE"
        surface1: "#BCC0CC"
        surface0: "#CCD0DA"
        base: "#EFF1F5"
        mantle: "#E6E9EF"
        crust: "#DCE0E8"
    }

    readonly property Palette palette: dark ? mocha : latte

    colors {
        text: palette.text
        textSecondary: palette.subtext1
        textTertiary: palette.overlay1
        textDisabled: palette.overlay0
        textOnAccent: palette.crust
        background: palette.base
        backgroundSecondary: palette.mantle
        card: Qt.alpha(palette.surface0, 0.5)
        cardBorder: Qt.alpha(palette.crust, 0.5)
        border: palette.surface1
        divider: Qt.alpha(palette.surface1, 0.6)
        hover: Qt.alpha(palette.surface1, 0.5)
        pressed: Qt.alpha(palette.surface1, 0.3)
        selected: Qt.alpha(palette.surface1, 0.5)
        control: Qt.alpha(palette.surface0, 0.8)
        controlHover: Qt.alpha(palette.surface1, 0.8)
        controlPressed: Qt.alpha(palette.surface0, 0.5)
        controlBorder: Qt.alpha(palette.surface2, 0.4)
        smoke: Qt.alpha(palette.crust, 0.4)
        accent: palette.mauve
        success: palette.green
        warning: palette.yellow
        critical: palette.red
    }

    menu.background: palette.mantle
}
