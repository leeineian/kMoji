import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

import "../../assets/emoji-icons.js" as EmojiIcons

Kirigami.ScrollablePage {
    id: root

    // =========================================================================
    // Properties & Helpers
    // =========================================================================

    property string smallSizeEmojiLabel: i18n("Small")
    property string largeSizeEmojiLabel: i18n("Large")

    property alias cfg_CloseAfterSelection: closeAfterSelection.checked
    property alias cfg_KeyboardNavigation: keyboardNavigation.checked

    function emojiFontPixelSize(gridSize) {
        const size = gridSize || 0
        const scaled = Math.floor(size * 0.7)
        return Math.max(scaled, 16)
    }

    function _randomEmojiFromPool() {
        const pool = EmojiIcons.getIconEmojis() || []
        if (pool.length === 0) {
            return null
        }
        return pool[Math.floor(Math.random() * pool.length)]
    }

    function rollSizeEmojiLabels() {
        const emoji = _randomEmojiFromPool()
        if (emoji) {
            root.smallSizeEmojiLabel = emoji
            root.largeSizeEmojiLabel = emoji
        } else {
            root.smallSizeEmojiLabel = i18n("Small")
            root.largeSizeEmojiLabel = i18n("Large")
        }
    }

    component ConfigSection : ColumnLayout {
        property alias text: label.text
        spacing: 0
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: Kirigami.Units.largeSpacing

        PlasmaComponents.Label {
            id: label
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
            Layout.alignment: Qt.AlignHCenter
        }
        Kirigami.Separator {
            Layout.preferredWidth: label.contentWidth
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignHCenter
        }
    }

    Component.onCompleted: {
        rollSizeEmojiLabels()
    }

    // =========================================================================
    // Visual Layout
    // =========================================================================

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        // --- Display Section ---
        ConfigSection {
            text: i18n("Display")
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    text: root.smallSizeEmojiLabel
                    font.pixelSize: root.emojiFontPixelSize(gridSizeSlider.sizeValues[0])
                }

                PlasmaComponents.Slider {
                    id: gridSizeSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 2
                    stepSize: 1
                    snapMode: Slider.SnapAlways

                    readonly property var sizeValues: [36, 44, 56]

                    value: {
                        const current = plasmoid.configuration.GridSize
                        if (current <= 36) return 0
                        if (current >= 56) return 2
                        return 1
                    }

                    onMoved: {
                        plasmoid.configuration.GridSize = sizeValues[value]
                    }
                }

                PlasmaComponents.Label {
                    text: root.largeSizeEmojiLabel
                    font.pixelSize: root.emojiFontPixelSize(gridSizeSlider.sizeValues[2])
                }
            }
        }

        // --- Behavior Section ---
        ConfigSection {
            text: i18n("Behavior")
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            PlasmaComponents.CheckBox {
                id: closeAfterSelection
                text: i18n("Close popup after emoji selection")
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.CheckBox {
                    id: keyboardNavigation
                    text: i18n("Enable keyboard navigation")
                }

                PlasmaComponents.ToolButton {
                    icon.name: "data-information"
                    text: i18n("Help")
                    display: PlasmaComponents.ToolButton.IconOnly

                    PlasmaComponents.ToolTip {
                        text: i18n("← ↑ → ↓: Navigate UI elements\nENTER: Copy emoji\nSHIFT+ENTER: Copy emoji name\nCTRL+ENTER: Select emoji\nTAB: Focus next\nSHIFT+TAB: Focus previous\nESC: Close popup")
                    }

                    // Prevent click, acts as a tooltip anchor only
                    onPressed: mouse => mouse.accepted = false
                }
            }
        }

        // --- Update Section ---
        ConfigSection {
            text: i18n("Update")
        }

        // We use a simplified GroupBox-like look for the logs area
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            // Wrapper to center the button robustly
            RowLayout {
                Layout.fillWidth: true
                
                Item { Layout.fillWidth: true } // Left spacer
                
                PlasmaComponents.Button {
                    id: syncButton
                    text: syncController.statusText
                    enabled: !syncController.isSyncing
                    icon.name: syncController.isSyncing ? "view-refresh-symbolic" : "download"
                    
                    onClicked: syncController.startSync()
                }
                
                Item { Layout.fillWidth: true } // Right spacer
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: syncController.logAreaHeight
                visible: syncController.logVisible
                
                background: Rectangle {
                    color: PlasmaCore.Theme.backgroundColor
                    border.color: PlasmaCore.Theme.textColor
                    border.width: 1
                    opacity: 0.3
                    radius: Kirigami.Units.smallSpacing
                }

                TextArea {
                    id: syncLogArea
                    text: syncController.logText
                    readOnly: true
                    wrapMode: TextEdit.Wrap
                    font.family: "monospace"
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    selectByMouse: true
                    color: PlasmaCore.Theme.textColor
                }
            }

            // Resize Handle
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.largeSpacing
                visible: syncController.logVisible

                Rectangle {
                    anchors.centerIn: parent
                    width: Kirigami.Units.gridUnit * 2
                    height: Math.round(Kirigami.Units.smallSpacing / 2)
                    radius: height / 2
                    color: PlasmaCore.Theme.textColor
                    opacity: 0.3
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeVerCursor
                    preventStealing: true

                    property real startY: 0

                    onPressed: (mouse) => {
                        startY = mouse.y
                    }

                    onPositionChanged: (mouse) => {
                        const delta = mouse.y - startY
                        let newHeight = syncController.logAreaHeight + delta
                        
                        const minHeight = Kirigami.Units.gridUnit * 3
                        const maxHeight = root.height * 0.8

                        if (newHeight < minHeight) newHeight = minHeight
                        if (newHeight > maxHeight) newHeight = maxHeight
                        
                        syncController.logAreaHeight = newHeight
                    }
                }
            }
        }
    }

    // =========================================================================
    // Data & Logic
    // =========================================================================

    Plasma5Support.DataSource {
        id: shellSource
        engine: "executable"
        connectedSources: []

        onNewData: (source, data) => {
            if (source !== syncController.currentCommand) return

            const stdout = data["stdout"]
            const stderr = data["stderr"]
            const exitCode = data["exit code"]

            if (stdout) syncController.appendLog(stdout)
            if (stderr) syncController.appendLog(stderr)

            if (exitCode !== undefined) {
                disconnectSource(source)
                syncController.finishSync(exitCode)
            }
        }
    }

    QtObject {
        id: syncController

        property bool isSyncing: false
        property string statusText: i18n("Sync Emoji Database")
        property string logText: ""
        property bool logVisible: false
        property real logAreaHeight: Kirigami.Units.gridUnit * 6
        property string currentCommand: ""

        function appendLog(message) {
            logText += message
            Qt.callLater(() => {
                if(syncLogArea) syncLogArea.cursorPosition = syncLogArea.length
            })
        }

        function addSystemLog(message) {
            const timestamp = new Date().toLocaleTimeString()
            appendLog(`[${timestamp}] ${message}\n`)
        }

        function startSync() {
            if (isSyncing) return

            isSyncing = true
            statusText = i18n("Syncing...")
            logVisible = true
            logText = ""

            executeScript()
        }

        function executeScript() {
            const scriptUrl = Qt.resolvedUrl('../../service/update_emoji.sh')
            let path = scriptUrl.toString()

            // Strip protocol robustly
            if (path.startsWith("file://")) {
                path = path.substring(7)
            } else if (path.startsWith("file:")) {
                path = path.substring(5)
            }

            // Decode path (e.g. spaces -> %20 handled)
            const cleanPath = decodeURIComponent(path)
            
            addSystemLog(`Script: ${cleanPath}`)

            // Check if path looks valid (basic sanity check)
            if (cleanPath.length === 0 || cleanPath.includes("undefined")) {
                 addSystemLog("Error: Could not resolve script path.")
                 finishSync(1)
                 return
            }

            // Safety: Disconnect previous command if valid to prevent dangling connections
            if (currentCommand !== "") {
                shellSource.disconnectSource(currentCommand)
            }

            currentCommand = `bash "${cleanPath}"`
            shellSource.connectSource(currentCommand)
        }

        function finishSync(exitCode) {
            isSyncing = false
            currentCommand = ""
            
            const isSuccess = (exitCode === 0)
            
            if (isSuccess) {
                statusText = i18n("Sync Complete!")
                addSystemLog("Process finished successfully.")
            } else if (exitCode === 3) {
                statusText = i18n("Error: Read-only Filesystem")
                addSystemLog("Failed: Cannot write to assets directory. Is the plasmoid installed system-wide?")
            } else {
                statusText = i18n("Sync failed (%1)", exitCode)
                addSystemLog(`Process failed with code ${exitCode}.`)
            }

            resetStatusTimer.restart()
        }
    }

    // =========================================================================
    // Timers
    // =========================================================================

    Timer {
        id: resetStatusTimer
        interval: 3000
        onTriggered: {
            if (!syncController.isSyncing) {
                syncController.statusText = i18n("Sync Emoji Database")
            }
        }
    }
}