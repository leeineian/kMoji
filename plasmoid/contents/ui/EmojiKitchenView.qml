import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: kitchenRoot

    property var emojiList: []
    property string emoji1: ""
    property string emoji2: ""
    property string resultUrl: ""
    property var clipboard: null
    property var kitchenMetadata: ({})
    
    // Grid configuration
    property int gridSize: 44
    property int slotSize: 80

    activeFocusOnTab: false // We will manage internal focus

    Plasma5Support.DataSource {
        id: shellSource
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 12

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
                width: slotSize
                height: slotSize
                color: Kirigami.Theme.backgroundColor
                border.color: emoji1 !== "" ? Kirigami.Theme.highlightColor : Kirigami.Theme.separatorColor
                border.width: emoji1 === "" ? 1 : 2
                radius: 8
                
                Text {
                    anchors.centerIn: parent
                    text: emoji1 === "" ? "?" : emoji1
                    font.pixelSize: emoji1 === "" ? Math.floor(slotSize * 0.4) : (slotSize - 20)
                    color: Kirigami.Theme.textColor
                    opacity: emoji1 === "" ? 0.3 : 1.0
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: emoji1 = ""
                }
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
                width: slotSize
                height: slotSize
                color: Kirigami.Theme.backgroundColor
                border.color: emoji2 !== "" ? Kirigami.Theme.highlightColor : Kirigami.Theme.separatorColor
                border.width: emoji2 === "" ? 1 : 2
                radius: 8
                
                Text {
                    anchors.centerIn: parent
                    text: emoji2 === "" ? "?" : emoji2
                    font.pixelSize: emoji2 === "" ? Math.floor(slotSize * 0.4) : (slotSize - 20)
                    color: Kirigami.Theme.textColor
                    opacity: emoji2 === "" ? 0.3 : 1.0
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: emoji2 = ""
                }
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
                width: slotSize
                height: slotSize
                color: Kirigami.Theme.backgroundColor
                border.color: resultUrl !== "" ? Kirigami.Theme.highlightColor : Kirigami.Theme.separatorColor
                border.width: resultUrl === "" ? 1 : 2
                radius: 8
                
                Image {
                    id: resultImage
                    anchors.fill: parent
                    anchors.margins: 6
                    source: resultUrl
                    fillMode: Image.PreserveAspectFit
                    visible: resultUrl !== ""
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    
                    onStatusChanged: {
                        if (status === Image.Error) {
                            console.log("Failed to load kitchen emoji:", source)
                        }
                    }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "?"
                    font.pixelSize: Math.floor(slotSize * 0.4)
                    visible: resultUrl === ""
                    color: Kirigami.Theme.textColor
                    opacity: 0.2
                }
            }
        }
        
        // --- Action Buttons ---
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 8
            
            PlasmaComponents.ToolButton {
                display: PlasmaComponents.ToolButton.IconOnly
                icon.name: "edit-clear-all"
                onClicked: {
                    emoji1 = ""
                    emoji2 = ""
                }
                PlasmaComponents.ToolTip { text: i18n("Clear All") }
            }

            PlasmaComponents.ToolButton {
                display: PlasmaComponents.ToolButton.IconOnly
                icon.name: "roll"
                onClicked: kitchenRoot.randomize()
                PlasmaComponents.ToolTip { text: i18n("Randomize") }
            }

            PlasmaComponents.ToolButton {
                display: PlasmaComponents.ToolButton.IconOnly
                icon.name: "swap-panels"
                onClicked: {
                    let tmp = emoji1
                    emoji1 = emoji2
                    emoji2 = tmp
                }
                PlasmaComponents.ToolTip { text: i18n("Swap") }
            }
            
            PlasmaComponents.ToolButton {
                display: PlasmaComponents.ToolButton.IconOnly
                icon.name: "edit-copy"
                enabled: resultUrl !== ""
                onClicked: kitchenRoot.copyResult()
                PlasmaComponents.ToolTip { text: i18n("Copy Result") }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: 4
        }

        // --- Emoji Grid ---
        GridView {
            id: kitchenGridView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: -12
            cellWidth: gridSize
            cellHeight: gridSize
            clip: true
            model: {
                let bases = Object.keys(kitchenMetadata);
                return emojiList.filter(e => {
                    let cp = getCodepoint(e.emoji);
                    return bases.includes(cp);
                });
            }
            
            delegate: Item {
                width: kitchenGridView.cellWidth
                height: kitchenGridView.cellHeight
                
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    color: mouseArea.containsMouse ? Kirigami.Theme.hoverColor : "transparent"
                    radius: 4
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
                    onClicked: {
                        kitchenGridView.currentIndex = index
                        kitchenGridView.forceActiveFocus()
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
    
    function getCodepoint(emoji) {
        if (!emoji) return "";
        return [...emoji].map(c => c.codePointAt(0).toString(16)).join("-");
    }
    
    function updateResult() {
        if (emoji1 !== "" && emoji2 !== "") {
            let cp1 = getCodepoint(emoji1);
            let cp2 = getCodepoint(emoji2);
            
            let findCombo = (c1, c2) => {
                let base = kitchenMetadata[c1];
                if (base) return base.find(c => c.e === c2);
                
                // Loose match: try without fe0f
                let c1_loose = c1.replace(/-fe0f/g, "");
                base = kitchenMetadata[c1_loose];
                if (base) return base.find(c => {
                    let e_loose = c.e.replace(/-fe0f/g, "");
                    return e_loose === c2.replace(/-fe0f/g, "");
                });
                return null;
            };

            let combo = findCombo(cp1, cp2) || findCombo(cp2, cp1);
            
            if (combo) {
                let urlCp = (cp) => "u" + cp.replace(/-fe0f/g, "").replace(/-/g, "-u");
                
                let u1 = urlCp(cp1);
                let u2 = urlCp(cp2);
                let cps = [u1, u2].sort();
                
                resultUrl = "https://www.gstatic.com/android/keyboard/emojikitchen/" + combo.d + "/" + cps[0] + "/" + cps[0] + "_" + cps[1] + ".png";
            } else {
                resultUrl = "";
            }
        } else {
            resultUrl = "";
        }
    }
    
    onEmoji1Changed: updateResult()
    onEmoji2Changed: updateResult()
    
    function emojiFromCodepoint(cp) {
        if (!cp) return "";
        return cp.split("-").map(part => String.fromCodePoint(parseInt(part, 16))).join("");
    }

    function randomize() {
        let bases = Object.keys(kitchenMetadata);
        if (bases.length > 0) {
            let cp1 = bases[Math.floor(Math.random() * bases.length)];
            let partners = kitchenMetadata[cp1];
            if (partners && partners.length > 0) {
                let partnerEntry = partners[Math.floor(Math.random() * partners.length)];
                let cp2 = partnerEntry.e;
                
                emoji1 = emojiFromCodepoint(cp1);
                emoji2 = emojiFromCodepoint(cp2);
            }
        }
    }
    
    function copyResult() {
        if (resultUrl !== "") {
            let cmd = 'curl -sL "' + resultUrl + '" > /tmp/kmoji_copy.png && (wl-copy --type image/png < /tmp/kmoji_copy.png || xclip -selection clipboard -t image/png -i /tmp/kmoji_copy.png)'
            shellSource.connectSource(cmd)
        }
    }
}
