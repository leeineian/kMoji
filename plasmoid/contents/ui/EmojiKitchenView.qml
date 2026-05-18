import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: kitchenRoot
    property var emojiList: []
    property int gridSize: 44
    property var clipboard: null
    property var kitchenMetadata: ({})
    property Item nextTabItem: null

    property string emoji1: ""
    property string emoji2: ""
    property string resultUrl: ""
    property string resultUrlAlternative: ""
    property string _actualSource: ""
    property string currentValidUrl: ""

    signal emojiHovered(string emoji, string name)
    signal emojiExited()

    onResultUrlChanged: _actualSource = resultUrl

    readonly property int slotSize: 128

    function getCodepoint(emoji) {
        if (!emoji) return "";
        let res = [];
        for (let char of emoji) {
            let cp = char.codePointAt(0).toString(16);
            res.push(cp);
        }
        return res.join("-");
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // --- Selection and Result Area ---
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            // Slot 1
            Rectangle {
                id: slot1
                width: slotSize
                height: slotSize
                color: Kirigami.Theme.backgroundColor
                border.color: (activeFocus || emoji1 !== "") ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                border.width: (activeFocus || emoji1 === "") ? 2 : 1
                radius: 8
                
                focusPolicy: Qt.StrongFocus
                activeFocusOnTab: true
                KeyNavigation.tab: slot2
                KeyNavigation.backtab: fullRoot.emojiTabPreviousTarget

                Text {
                    anchors.centerIn: parent
                    text: emoji1 === "" ? "?" : emoji1
                    font.pixelSize: emoji1 === "" ? Math.floor(slotSize * 0.6) : Math.floor(slotSize * 0.85)
                    font.family: emoji1 === "" ? "" : "Noto Color Emoji"
                    color: Kirigami.Theme.textColor
                    opacity: emoji1 === "" ? 0.2 : 1.0
                    renderType: emoji1 === "" ? Text.QtRendering : Text.NativeRendering
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        slot1.forceActiveFocus()
                        emoji1 = ""
                    }
                }

                Keys.onReturnPressed: emoji1 = ""
                Keys.onEnterPressed: emoji1 = ""
            }

            Text {
                text: "+"
                font.pixelSize: 24
                color: Kirigami.Theme.textColor
                opacity: 0.6
                Layout.alignment: Qt.AlignVCenter
            }

            // Slot 2
            Rectangle {
                id: slot2
                width: slotSize
                height: slotSize
                color: Kirigami.Theme.backgroundColor
                border.color: (activeFocus || emoji2 !== "") ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                border.width: (activeFocus || emoji2 === "") ? 2 : 1
                radius: 8
                
                focusPolicy: Qt.StrongFocus
                activeFocusOnTab: true
                KeyNavigation.tab: resultSlot

                Text {
                    anchors.centerIn: parent
                    text: emoji2 === "" ? "?" : emoji2
                    font.pixelSize: emoji2 === "" ? Math.floor(slotSize * 0.6) : Math.floor(slotSize * 0.85)
                    font.family: emoji2 === "" ? "" : "Noto Color Emoji"
                    color: Kirigami.Theme.textColor
                    opacity: emoji2 === "" ? 0.2 : 1.0
                    renderType: emoji2 === "" ? Text.QtRendering : Text.NativeRendering
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        slot2.forceActiveFocus()
                        emoji2 = ""
                    }
                }

                Keys.onReturnPressed: emoji2 = ""
                Keys.onEnterPressed: emoji2 = ""
            }

            Text {
                text: "="
                font.pixelSize: 24
                color: Kirigami.Theme.textColor
                opacity: 0.6
                Layout.alignment: Qt.AlignVCenter
            }

            // Result
            Rectangle {
                id: resultSlot
                width: slotSize
                height: slotSize
                color: Kirigami.Theme.backgroundColor
                border.color: (activeFocus || resultUrl !== "") ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                border.width: (activeFocus || resultUrl === "") ? 2 : 1
                radius: 8
                
                focusPolicy: Qt.StrongFocus
                activeFocusOnTab: true
                KeyNavigation.tab: clearButton

                Text {
                    anchors.centerIn: parent
                    text: "?"
                    font.pixelSize: Math.floor(slotSize * 0.6)
                    color: Kirigami.Theme.textColor
                    opacity: 0.2
                }

                Image {
                    id: resultImage
                    anchors.fill: parent
                    anchors.margins: 6
                    source: _actualSource
                    fillMode: Image.PreserveAspectFit
                    opacity: (status === Image.Ready && resultUrl !== "") ? 1.0 : 0.0
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    
                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                    
                    onStatusChanged: {
                        if (status === Image.Ready) {
                            kitchenRoot.currentValidUrl = source.toString()
                        } else if (status === Image.Error && source.toString() === resultUrl && resultUrlAlternative !== "") {
                            _actualSource = resultUrlAlternative
                        }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    enabled: kitchenRoot.currentValidUrl !== ""
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        resultSlot.forceActiveFocus()
                        kitchenRoot.copyResult()
                    }
                }

                Keys.onReturnPressed: if(kitchenRoot.currentValidUrl !== "") kitchenRoot.copyResult()
                Keys.onEnterPressed: if(kitchenRoot.currentValidUrl !== "") kitchenRoot.copyResult()
            }
        }
        
        // --- Action Buttons ---
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 8
            
            PlasmaComponents.ToolButton {
                id: clearButton
                display: PlasmaComponents.ToolButton.IconOnly
                icon.name: "edit-clear-all"
                onClicked: {
                    emoji1 = ""
                    emoji2 = ""
                }
                PlasmaComponents.ToolTip { text: i18n("Clear All") }
            }

            PlasmaComponents.ToolButton {
                id: copyButton
                display: PlasmaComponents.ToolButton.IconOnly
                icon.name: "edit-copy"
                enabled: kitchenRoot.currentValidUrl !== ""
                onClicked: kitchenRoot.copyResult()
                PlasmaComponents.ToolTip { text: i18n("Copy Result") }
            }
        }

        // --- Grid Area ---
        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: 16
        }

        GridView {
            id: kitchenGridView
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: gridSize
            cellHeight: gridSize
            clip: true
            model: emojiList
            
            delegate: Item {
                width: gridSize
                height: gridSize
                
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    color: Kirigami.Theme.highlightColor
                    radius: 4
                    opacity: (mouseArea.containsMouse || activeFocus) ? 0.2 : 0
                }
                
                Text {
                    anchors.centerIn: parent
                    text: modelData.emoji
                    font.pixelSize: Math.floor(gridSize * 0.7)
                    renderType: Text.NativeRendering
                }
                
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: kitchenRoot.emojiHovered(modelData.emoji, modelData.name)
                    onExited: kitchenRoot.emojiExited()
                    onClicked: {
                        if (emoji1 === "") {
                            emoji1 = modelData.emoji
                        } else {
                            emoji2 = modelData.emoji
                        }
                    }
                }
            }
        }
    }

    function updateResult() {
        if (emoji1 === "" || emoji2 === "") {
            resultUrl = ""
            resultUrlAlternative = ""
            currentValidUrl = ""
            return
        }

        let cp1 = getCodepoint(emoji1);
        let cp2 = getCodepoint(emoji2);

        let data = kitchenMetadata[cp1];
        if (data) {
            let combo = data.find(c => c.e === cp2);
            if (combo) {
                let date = combo.d;
                resultUrl = "https://www.gstatic.com/android/keyboard/emojikitchen/" + date + "/" + cp1 + "/" + cp1 + "_" + cp2 + ".png";
                resultUrlAlternative = "https://www.gstatic.com/android/keyboard/emojikitchen/" + date + "/" + cp2 + "/" + cp2 + "_" + cp1 + ".png";
                return;
            }
        }

        // Try reverse
        data = kitchenMetadata[cp2];
        if (data) {
            let combo = data.find(c => c.e === cp1);
            if (combo) {
                let date = combo.d;
                resultUrl = "https://www.gstatic.com/android/keyboard/emojikitchen/" + date + "/" + cp2 + "/" + cp2 + "_" + cp1 + ".png";
                resultUrlAlternative = "https://www.gstatic.com/android/keyboard/emojikitchen/" + date + "/" + cp1 + "/" + cp1 + "_" + cp2 + ".png";
                return;
            }
        }

        resultUrl = "";
        resultUrlAlternative = "";
        currentValidUrl = "";
    }

    onEmoji1Changed: updateResult()
    onEmoji2Changed: updateResult()

    function copyResult() {
        if (currentValidUrl !== "") {
            clipboard.content = currentValidUrl
            fullRoot.showCopiedFeedback("Emoji Kitchen", "Sticker URL")
        }
    }
}
