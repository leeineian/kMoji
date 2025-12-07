import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

import "../assets/emoji-icons.js" as IconEmojis

MouseArea {
    id: compactRoot

    // Behavioral Properties
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    // Custom Properties
    property bool wasExpanded: false
    property var plasmoidItem: null
    property bool easterEggMode: false
    property var emojiIcons: []
    property int currentEmojiIndex: 0

    // Size hints for panel layout - use system default icon size
    implicitWidth: PlasmaCore.Theme.panelMinimumWidth
    implicitHeight: PlasmaCore.Theme.panelMinimumHeight
    Layout.minimumWidth: PlasmaCore.Theme.panelMinimumWidth
    Layout.minimumHeight: PlasmaCore.Theme.panelMinimumHeight

    Accessible.name: Plasmoid.title
    Accessible.role: Accessible.Button

    // Helper function to resolve the plasmoid object
    function expander() {
        if (plasmoidItem) {
            return plasmoidItem
        }
        if (typeof plasmoid !== "undefined") {
            return plasmoid
        }
        return null
    }

    // --- Signal Handlers ---

    onPressed: {
        const target = expander()
        wasExpanded = target ? target.expanded : false
    }

    onClicked: {
        const target = expander()
        if (mouse.button === Qt.LeftButton) {
            if (target) {
                target.expanded = !wasExpanded
            }
        } else if (mouse.button === Qt.MiddleButton) {
            // Toggle easter egg mode on middle click
            easterEggMode = !easterEggMode
            mouse.accepted = true
        }
    }

    onDoubleClicked: {
        easterEggMode = false
    }

    onEntered: {
        const target = expander()
        if (!target || !target.expanded) {
            if (emojiIcons.length === 0) {
                emojiIcons = IconEmojis.getIconEmojis()
            }
            if (emojiIcons.length > 0) {
                currentEmojiIndex = Math.floor(Math.random() * emojiIcons.length)
            }
        }
    }

    // --- Visual Elements ---

    Item {
        anchors.fill: parent

        // Default icon (when not in easter egg mode)
        Kirigami.Icon {
            id: defaultIcon
            anchors.fill: parent
            transformOrigin: Item.Center

            source: "preferences-desktop-emoticons-symbolic"
            visible: !compactRoot.easterEggMode
            opacity: compactRoot.easterEggMode ? 0 : 1.0
        }

        // Emoji text (when in easter egg mode)
        Text {
            id: emojiIcon
            anchors.fill: parent
            transformOrigin: Item.Center

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            text: (compactRoot.emojiIcons && compactRoot.emojiIcons.length > 0) ? compactRoot.emojiIcons[compactRoot.currentEmojiIndex] : ""
            font.pixelSize: Math.min(width, height) * 0.8
            font.family: "emoji" // Use emoji font family if available

            visible: compactRoot.easterEggMode
            opacity: compactRoot.easterEggMode
            ? ((compactRoot.containsMouse || (expander() && expander().expanded)) ? 1.0 : 0.7)
            : 0
            scale: (compactRoot.containsMouse || (expander() && expander().expanded)) ? 1.0 : 1.0

            // Improve rendering quality
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            smooth: true
            antialiasing: true
        }
    }
}
