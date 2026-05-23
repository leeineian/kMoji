import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

import "../assets/emoji-metadata.js" as EmojiList

Kirigami.ScrollablePage {
    id: root

    property var _cachedEmojis: null

    function getIconEmojis(emojiList) {
        if (_cachedEmojis) {
            return _cachedEmojis;
        }

        var allEmojis = [];
        var list = emojiList;

        for (var category in list) {
            var categoryData = list[category];
            if (categoryData) {
                for (var i = 0; i < categoryData.length; i++) {
                    allEmojis.push(categoryData[i].emoji);
                }
            }
        }

        _cachedEmojis = allEmojis;
        return allEmojis;
    }

    property string smallSizeEmojiLabel: i18n("Small")
    property string largeSizeEmojiLabel: i18n("Large")

    property alias cfg_CloseAfterSelection: closeAfterSelection.checked
    property alias cfg_KeyboardNavigation: keyboardNavigation.checked
    property alias cfg_AlwaysOpen: alwaysOpen.checked
    property alias cfg_AlwaysAnimateGifs: alwaysAnimateGifs.checked
    property alias cfg_KlipyApiKey: klipyApiKey.text

    property string randomGifUrl: ""

    function emojiFontPixelSize(gridSize) {
        const size = gridSize || 0
        const scaled = Math.floor(size * 0.7)
        return Math.max(scaled, 16)
    }

    function _randomEmojiFromPool() {
        const pool = getIconEmojis(EmojiList.emojiList) || []
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

    function fetchRandom4x4Gif() {
        const apiKey = plasmoid.configuration.KlipyApiKey || "s9q3axg5VURfGO45IDSDhJ1Nxm445kzNdiRF4lmbcVkJaZDe9ShO01YIOvIvtaY2"
        const url = "https://api.klipy.com/api/v1/" + apiKey + "/gifs/search?q=4x4&per_page=24&page=1"
        const xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    const response = JSON.parse(xhr.responseText)
                    const dataList = response && response.data && response.data.data ? response.data.data : []
                    if (dataList.length > 0) {
                        const randomItem = dataList[Math.floor(Math.random() * dataList.length)]
                        if (randomItem && randomItem.file && randomItem.file.sm && randomItem.file.sm.gif) {
                            root.randomGifUrl = randomItem.file.sm.gif.url
                        }
                    }
                } catch(e) {
                    console.log("Failed to parse random 4x4 gif: " + e)
                }
            }
        }
        xhr.send()
    }

    Component.onCompleted: {
        rollSizeEmojiLabels()
        fetchRandom4x4Gif()
    }

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        ConfigSection {
            text: i18n("Display")
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Item {
                    width: 48
                    height: 48
                    Layout.alignment: Qt.AlignVCenter

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: root.smallSizeEmojiLabel
                        font.pixelSize: root.emojiFontPixelSize(gridSizeSlider.sizeValues[0])
                    }
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

                Item {
                    width: 48
                    height: 48
                    Layout.alignment: Qt.AlignVCenter

                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        text: root.largeSizeEmojiLabel
                        font.pixelSize: root.emojiFontPixelSize(gridSizeSlider.sizeValues[2])
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Item {
                    width: 48
                    height: 48
                    Layout.alignment: Qt.AlignVCenter

                    AnimatedImage {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: root.randomGifUrl
                        fillMode: Image.PreserveAspectFit
                        playing: true
                        visible: root.randomGifUrl !== ""
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: "fileview-preview-symbolic"
                        visible: root.randomGifUrl === ""
                    }
                }

                PlasmaComponents.Slider {
                    id: gifSizeSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 2
                    stepSize: 1
                    snapMode: Slider.SnapAlways

                    readonly property var sizeValues: [90, 125, 160]

                    value: {
                        const current = plasmoid.configuration.GifSize
                        if (current <= 90) return 0
                        if (current >= 160) return 2
                        return 1
                    }

                    onMoved: {
                        plasmoid.configuration.GifSize = sizeValues[value]
                    }
                }

                Item {
                    width: 48
                    height: 48
                    Layout.alignment: Qt.AlignVCenter

                    AnimatedImage {
                        anchors.centerIn: parent
                        width: 44
                        height: 44
                        source: root.randomGifUrl
                        fillMode: Image.PreserveAspectFit
                        playing: true
                        visible: root.randomGifUrl !== ""
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 44
                        height: 44
                        source: "fileview-preview-symbolic"
                        visible: root.randomGifUrl === ""
                    }
                }
            }
        }

        ConfigSection {
            text: i18n("Behavior")
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            PlasmaComponents.CheckBox {
                id: alwaysOpen
                text: i18n("Pin popup in place when opened")
            }

            PlasmaComponents.CheckBox {
                id: closeAfterSelection
                text: i18n("Close popup after selection")
            }

            PlasmaComponents.CheckBox {
                id: alwaysAnimateGifs
                text: i18n("Always animate GIFs")
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.CheckBox {
                    id: keyboardNavigation
                    text: i18n("Enable keyboard navigation")
                }

                Kirigami.ContextualHelpButton {
                    icon.name: "data-information"
                    toolTipText: i18n("← ↑ → ↓: Navigate UI elements\nENTER: Copy emoji\nSHIFT+ENTER: Copy emoji name\nCTRL+ENTER: Select emoji\nTAB: Focus next\nSHIFT+TAB: Focus previous\nESC: Close popup")
                    display: PlasmaComponents.ToolButton.IconOnly
                    leftPadding: 0
                    rightPadding: 0
                }
            }
        }

        ConfigSection {
            text: i18n("Services")
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            TextField {
                id: klipyApiKey
                Kirigami.FormData.label: i18n("Klipy API Key:")
                placeholderText: i18n("Get a key from partner.klipy.com")
                echoMode: TextInput.PasswordEchoOnEdit
                Layout.fillWidth: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                
                Item { Layout.fillWidth: true }
                
                PlasmaComponents.Button {
                    id: syncButton
                    text: syncController.statusText
                    enabled: !syncController.isSyncing && syncController.statusText === syncController.defaultStatusText
                    icon.name: {
                        if (syncController.isSyncing) return "view-refresh-symbolic"
                        if (syncController.resultIcon !== "") return syncController.resultIcon
                        return "download-symbolic"
                    }
                    
                    onClicked: syncController.startSync()
                }
                
                Item { Layout.fillWidth: true }
            }

            ScrollView {
                id: syncScrollView
                Layout.fillWidth: true
                Layout.preferredHeight: syncController.logAreaHeight
                visible: syncController.logVisible
                clip: true

                background: Rectangle {
                    color: Kirigami.Theme.alternateBackgroundColor
                    border.color: Kirigami.Theme.highlightColor
                    border.width: 1
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
                    color: Kirigami.Theme.textColor
                    background: null
                    padding: Kirigami.Units.smallSpacing
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.largeSpacing
                visible: syncController.logVisible

                Rectangle {
                    anchors.centerIn: parent
                    width: Kirigami.Units.gridUnit * 2
                    height: Math.round(Kirigami.Units.smallSpacing / 2)
                    radius: height / 2
                    color: Kirigami.Theme.disabledTextColor
                    opacity: 0.45
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
        readonly property string defaultStatusText: i18n("Sync Emoji Database")
        property string statusText: defaultStatusText
        property string resultIcon: ""
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
            const now = new Date()
            const hh = String(now.getHours()).padStart(2, '0')
            const mm = String(now.getMinutes()).padStart(2, '0')
            const ss = String(now.getSeconds()).padStart(2, '0')
            appendLog(`[${hh}:${mm}:${ss}] ${message}\n`)
        }

        function startSync() {
            if (isSyncing) return

            isSyncing = true
            statusText = i18n("Syncing...")
            resultIcon = ""
            logVisible = true
            logText = ""

            executeScript()
        }

        function executeScript() {
            const scriptUrl = Qt.resolvedUrl('../../service/metadata.sh')
            let path = scriptUrl.toString()

            if (path.startsWith("file://")) {
                path = path.substring(7)
            } else if (path.startsWith("file:")) {
                path = path.substring(5)
            }

            const cleanPath = decodeURIComponent(path)
            
            addSystemLog("Sync started.")

            if (cleanPath.length === 0 || cleanPath.includes("undefined")) {
                 addSystemLog("Error: Could not resolve script path.")
                 finishSync(1)
                 return
            }

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
                resultIcon = "checkmark-symbolic"
                addSystemLog("Process finished successfully.")
            } else if (exitCode === 3) {
                statusText = i18n("Error: Read-only Filesystem")
                resultIcon = "action-unavailable-symbolic"
                addSystemLog("Failed: Cannot write to assets directory. Is the plasmoid installed system-wide?")
            } else {
                statusText = i18n("Sync failed (%1)", exitCode)
                resultIcon = "action-unavailable-symbolic"
                addSystemLog(`Process failed with code ${exitCode}.`)
            }

            resetStatusTimer.restart()
        }
    }

    Timer {
        id: resetStatusTimer
        interval: 3000
        onTriggered: {
            if (!syncController.isSyncing) {
                syncController.statusText = syncController.defaultStatusText
                syncController.resultIcon = ""
            }
        }
    }
}