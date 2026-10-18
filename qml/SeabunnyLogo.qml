import QtQuick

Item {
    id: logo
    property real size: 24
    property color color: theme.primary
    implicitWidth: size
    implicitHeight: size
    Image {
        objectName: "seabunnyLogoImage"
        anchors.fill: parent
        source: "image://seabunnyicon/seabunny-logo?color=" + encodeURIComponent(logo.color.toString())
        sourceSize.width: Math.ceil(logo.size * Screen.devicePixelRatio)
        sourceSize.height: Math.ceil(logo.size * Screen.devicePixelRatio)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
