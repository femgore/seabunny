import QtQuick

Item {
    id: iconRoot
    property string name: "file"
    property real size: 20
    property color color: (typeof theme !== "undefined" && theme && theme.textMain) ? theme.textMain : "#e6e1e6"

    width: size
    height: size

    // Codepoints verified against Phosphor web 2.1.1 (matches assets/fonts/Phosphor.ttf).
    // Each icon is a single PUA glyph; duotone renders base (codepoint) + overlay (codepoint+1).

    readonly property var symbolsMap: ({
        "file-image": "󰋩", "file-audio": "󰎆", "file-video": "󰕧", "file-zip": "󰛫",
        "file-pdf": "󰈦", "file-html": "󰅩", "file-css": "󰅩", "folder-dashed": "󰉋", "file-dashed": "󰈔",
        "folder": "󰉋", "folder-open": "\uf07c", "folder-plus": "\uf07b", "folder-simple": "󰉋",
        "file": "󰈔", "file-text": "󰈙", "file-code": "󰅩", "file-archive": "󰛫",
        "file-plus": "\uf15b", "image": "\uf03e", "pictures": "\uf03e", "music": "\uf001",
        "video": "\uf03d", "videos": "\uf03d", "download": "\uf019", "gear": "\uf013",
        "house": "\uf015", "house-line": "\uf015", "desktop": "\uf108", "laptop": "\uf109",
        "trash": "\uf1f8", "magnifying-glass": "\uf002", "code": "\uf121", "projects": "\uf121",
        "documents": "\uf15c", "terminal": "\uf120", "hard-drive": "\uf0a0", "recycle": "\uf1b8",
        "arrow-up": "\uf062", "arrow-down": "\uf063", "arrow-left": "\uf060", "arrow-right": "\uf061",
        "caret-up": "\uf0d8", "caret-down": "\uf0d7", "caret-left": "\uf0d9", "caret-right": "\uf0da",
        "plus": "\uf067", "minus": "\uf068", "x": "\uf00d", "check": "\uf00c", "check-square": "\uf14a",
        "scissors": "\uf0c4", "copy": "\uf0c5", "clipboard": "\uf0ea", "pencil-simple": "\uf040",
        "info": "\uf05a", "warning": "\uf071", "star": "\uf005", "lock": "\uf023", "key": "\uf084",
        "link": "\uf0c1", "arrow-square-out": "\uf08e", "arrow-counter-clockwise": "\uf0e2",
        "clock": "\uf017", "calendar-blank": "\uf073", "user": "\uf007", "users": "\uf0c0",
        "sidebar": "\uf0db", "sidebar-simple": "\uf0db", "sliders-horizontal": "\uf1de",
        "eject": "\uf052", "usb": "\uf287", "github-logo": "\uf09b", "camera": "\uf030",
        "sun": "\uf185", "moon": "\uf186", "shield-check": "\uf132", "cloud": "\uf0c2",
        "package": "\uf187"
    })
    readonly property bool usesSymbols: typeof theme !== "undefined" && theme.iconSource === "serpantinum" && !!symbolsMap[name]
    readonly property string primaryGlyph: usesSymbols ? symbolsMap[name] : ((typeof theme !== "undefined" && theme.glyphs[name]) || "\ue230")
    readonly property bool isDuotone: !usesSymbols && (typeof theme !== "undefined" && theme.phosphorWeight === "duotone")
    readonly property string fontFamily: usesSymbols ? theme.symbolsFontFamily : (typeof theme !== "undefined" && theme.getFontFamily) ? theme.getFontFamily() : "Phosphor"

    Text {
        anchors.centerIn: parent
        text: iconRoot.primaryGlyph
        font.family: iconRoot.fontFamily
        font.pixelSize: iconRoot.size
        color: iconRoot.color
        opacity: iconRoot.isDuotone ? 0.32 : 1.0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Loader {
        active: iconRoot.isDuotone
        anchors.centerIn: parent
        sourceComponent: duotoneOverlay
    }

    Component {
        id: duotoneOverlay
        Text {
            text: String.fromCharCode(iconRoot.primaryGlyph.charCodeAt(0) + 1)
            font.family: iconRoot.fontFamily
            font.pixelSize: iconRoot.size
            color: iconRoot.color
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
