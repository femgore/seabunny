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
    readonly property var glyphMap: ({
        "bread": "\ue81c",
        "house": "\ue2c2",
        "house-line": "\ue2c4",
        "folder": "\ue24a",
        "folder-open": "\ue256",
        "folder-plus": "\ue258",
        "folder-simple": "\ue25a",
        "file": "\ue230",
        "file-text": "\ue23a",
        "file-code": "\ue914",
        "file-plus": "\ue236",
        "file-archive": "\ueb2a",
        "image": "\ue2ca",
        "music": "\ue340",
        "video": "\ue740",
        "download": "\ue20a",
        "gear": "\ue270",
        "arrow-up": "\ue08e",
        "arrow-down": "\ue03e",
        "arrow-left": "\ue058",
        "arrow-right": "\ue06c",
        "magnifying-glass": "\ue30c",
        "trash": "\ue4a6",
        "recycle": "\ue75a",
        "code": "\ue1bc",
        "github-logo": "\ue284",
        "hard-drive": "\ue29e",
        "hard-drives": "\ue2a0",
        "desktop": "\ue560",
        "desktop-tower": "\ue562",
        "monitor": "\ue32e",
        "laptop": "\ue586",
        "device-mobile": "\ue1e0",
        "cpu": "\ue610",
        "memory": "\ue9c4",
        "gauge": "\ue628",
        "speedometer": "\uee74",
        "wifi-high": "\ue4ea",
        "battery-full": "\ue0c0",
        "thermometer": "\ue5c6",
        "fan": "\ue9f2",
        "camera": "\ue10e",
        "keyboard": "\ue2d8",
        "printer": "\ue3dc",
        "chart-bar": "\ue150",
        "chart-line-up": "\ue156",
        "clock": "\ue19a",
        "hourglass": "\ue2b2",
        "database": "\ue1de",
        "warning": "\ue4e0",
        "users": "\ue4d6",
        "user": "\ue4c2",
        "package": "\ue390",
        "shield-check": "\ue40c",
        "cloud": "\ue1aa",
        "lightning": "\ue2de",
        "plug": "\ue946",
        "floppy-disk": "\ue248",
        "calendar-blank": "\ue10a",
        "tree-structure": "\ue67c",
        "dots-three-vertical": "\ue208",
        "funnel-simple": "\ue268",
        "sliders-horizontal": "\ue434",
        "star": "\ue46a",
        "target": "\ue47c",
        "flame": "\ue624",
        "documents": "\ue23a",
        "pictures": "\ue2ca",
        "videos": "\ue740",
        "projects": "\ue1bc",
        "caret-right": "\ue13a",
        "caret-left": "\ue138",
        "caret-up": "\ue13c",
        "sidebar": "\ueab6",
        "sidebar-simple": "\uec24",
        "arrow-square-out": "\ue5de",
        "scissors": "\ueae0",
        "copy": "\ue1ca",
        "clipboard": "\ue196",
        "pencil-simple": "\ue3b4",
        "info": "\ue2ce",
        "check-square": "\ue186",
        "terminal": "\ue47e",
        "sun": "\ue472",
        "moon": "\ue330",
        "palette": "\ue6c8",
        "eye": "\ue220",
        "eye-slash": "\ue224",
        "check": "\ue182",
        "selection": "\ue69a",
        "hand-grabbing": "\ue57c",
        "arrows-out-cardinal": "\ue0a4",
        "sparkle": "\ue6a2",
        "globe": "\ue288",
        "broom": "\uec54",
        "list": "\ue2f0",
        "squares-four": "\ue464",
        "arrows-down-up": "\ue098",
        "sort-ascending": "\ue444",
        "sort-descending": "\ue446",
        "archive": "\ue00c",
        "file-zip": "\ue958",
        "file-html": "\ueb38",
        "file-css": "\ueb34",
        "file-audio": "\uea20",
        "file-video": "\uea22",
        "file-pdf": "\ue702",
        "file-image": "\uea24",
        "folder-dashed": "\ue8f8",
        "folder-simple-dashed": "\uec2a",
        "file-dashed": "\ue704",
        "caret-down": "\ue136",
        "lock": "\ue2fa",
        "key": "\ue2d6",
        "link": "\ue2e2",
        "x": "\ue4f6",
        "plus": "\ue3d4",
        "minus": "\ue32a",
        "dots-six-vertical": "\ueae2",
        "eject": "\ue212",
        "usb": "\ue956"
    })

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
        "sun": "\uf185", "moon": "\uf186", "shield-check": "\uf132", "cloud": "\uf0c2"
    })
    readonly property bool usesSymbols: typeof theme !== "undefined" && theme.iconSource === "serpantinum" && !!symbolsMap[name]
    readonly property string primaryGlyph: usesSymbols ? symbolsMap[name] : (glyphMap[name] || "\ue230")
    readonly property bool isDuotone: !usesSymbols && (typeof theme !== "undefined" && theme.phosphorWeight === "duotone")
    readonly property string fontFamily: usesSymbols ? theme.symbolsFontFamily
        : (typeof theme !== "undefined" && theme.getFontFamily) ? theme.getFontFamily() : "Phosphor"

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

    Text {
        visible: iconRoot.isDuotone
        anchors.centerIn: parent
        text: String.fromCharCode(iconRoot.primaryGlyph.charCodeAt(0) + 1)
        font.family: iconRoot.fontFamily
        font.pixelSize: iconRoot.size
        color: iconRoot.color
        opacity: 1.0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
