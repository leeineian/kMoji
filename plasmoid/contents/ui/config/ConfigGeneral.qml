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
    readonly property var emojiIconPool: EmojiIcons.getIconEmojis() || []

    // Helper to calculate font size based on grid size
    function emojiFontPixelSize(gridSize) {
        const size = gridSize || 0
        const scaled = Math.floor(size * 0.7)
        return Math.max(scaled, 16)
    }

    function _randomEmojiFromPool() {
        if (!root.emojiIconPool || root.emojiIconPool.length === 0) {
            return null
        }
        return root.emojiIconPool[Math.floor(Math.random() * root.emojiIconPool.length)]
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

    Component.onCompleted: {
        rollSizeEmojiLabels()
    }

    // =========================================================================
    // Visual Layout
    // =========================================================================

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.FormLayout {
            id: formLayout
            Layout.fillWidth: true

            // --- Display Section ---
            Kirigami.Separator {
                Kirigami.FormData.label: i18n("Display")
                Kirigami.FormData.isSection: true
            }

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
                    
                    // Bind value to config, fallback to Medium (index 1)
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

            // --- Behavior Section ---
            Kirigami.Separator {
                Kirigami.FormData.label: i18n("Behavior")
                Kirigami.FormData.isSection: true
            }

            PlasmaComponents.CheckBox {
                text: i18n("Close popup after emoji selection")
                checked: plasmoid.configuration.CloseAfterSelection
                onToggled: plasmoid.configuration.CloseAfterSelection = checked
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.CheckBox {
                    text: i18n("Enable keyboard navigation")
                    checked: plasmoid.configuration.KeyboardNavigation
                    onToggled: plasmoid.configuration.KeyboardNavigation = checked
                }

                PlasmaComponents.ToolButton {
                    icon.name: "help-hint-symbolic"
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

        // --- Sync Section ---
        
        // We use a simplified GroupBox-like look for the logs area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
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
                Layout.preferredHeight: Kirigami.Units.gridUnit * 6
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
        }
    }

    // =========================================================================
    // Data & Logic
    // =========================================================================

    Plasma5Support.DataSource {
        id: shellSource
        engine: "executable"
        connectedSources: []
        
        signal scriptFinished(string output, int exitCode)

        onNewData: (source, data) => {
            const stdout = data["stdout"] || ""
            const stderr = data["stderr"] || "" // Sometimes useful
            
            // Check if this was a cleanup command (rm)
            if (source.startsWith("rm ")) {
                disconnectSource(source)
                return
            }

            // If we are reading the log file
            if (source.startsWith("cat ")) {
                disconnectSource(source)
                syncController.processLogOutput(stdout)
                return
            }
            
            // If this is the main execution (not usually captured here due to > redirection, 
            // but kept for safety)
            disconnectSource(source)
        }
    }

    QtObject {
        id: syncController

        property bool isSyncing: false
        property string statusText: i18n("Sync Emoji Database")
        property string logText: ""
        property bool logVisible: false
        property string tempLogPath: ""

        function addLog(message) {
            const timestamp = new Date().toLocaleTimeString()
            logText += `[${timestamp}] ${message}\n`
            // Auto scroll to bottom
            Qt.callLater(() => {
                if(syncLogArea) syncLogArea.cursorPosition = syncLogArea.length
            })
        }

        function startSync() {
            if (isSyncing) return

            isSyncing = true
            statusText = i18n("Syncing...")
            logVisible = true
            logText = "" 
            addLog("Sync started")

            // Generate unique temp file
            tempLogPath = `/tmp/emoji_sync_${Date.now()}.log`

            // 1. Cleanup old logs if they exist (optional, but good hygiene)
            // We just let the new one be created.
            
            // 2. Execute Script
            executeScript()
            
            // 3. Start polling the log file
            syncPollTimer.start()
        }

        function executeScript() {
            const scriptUrl = Qt.resolvedUrl('../../service/update_emoji.sh')
            const cleanPath = scriptUrl.toString().replace('file://', '').replace(/\/\//g, '/')
            
            addLog(`Script: ${cleanPath}`)
            addLog(`Log file: ${tempLogPath}`)

            // Command: Run script, redirect all output to file, append exit code at the end
            const cmd = `bash "${cleanPath}" > "${tempLogPath}" 2>&1; echo "EXIT:$?" >> "${tempLogPath}"`
            
            // We connect, but we don't expect data back immediately via this source 
            // because of the redirection. We rely on the poll timer.
            shellSource.connectSource(cmd)
        }

        function checkStatus() {
            if (!isSyncing || !tempLogPath) return
            // Read the log file
            shellSource.connectSource(`cat "${tempLogPath}" 2>/dev/null`)
        }

        function processLogOutput(output) {
            if (!output) return

            // Update display log
            logText = output

            // Check completion states
            const hasNetError = output.includes('SYNC_NET_ERROR')
            const isDone = output.includes('SYNC_COMPLETE')
            
            // Parse exit code
            let exitCode = -1
            const exitMatch = output.match(/EXIT:(\d+)/)
            
            if (exitMatch) {
                exitCode = parseInt(exitMatch[1])
            }

            if (exitCode === 0 && isDone) {
                finishSync(true, i18n("Sync Complete!"))
            } else if (hasNetError) {
                finishSync(false, i18n("Network error!"))
            } else if (exitCode > 0) {
                finishSync(false, i18n("Sync failed (Code %1)", exitCode))
            }
        }

        function finishSync(success, message) {
            syncPollTimer.stop()
            isSyncing = false
            statusText = message
            addLog(success ? "Process finished successfully." : "Process failed.")
            
            // Cleanup temp file
            if (tempLogPath) {
                 shellSource.connectSource(`rm -f "${tempLogPath}"`)
            }

            // Reset button text after delay
            resetStatusTimer.restart()
        }
    }

    // =========================================================================
    // Timers
    // =========================================================================

    Timer {
        id: syncPollTimer
        interval: 1000
        repeat: true
        onTriggered: syncController.checkStatus()
    }

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