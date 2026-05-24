import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml
import QtCore

import org.kde.kquickcontrolsaddons as KQCA
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

import "../assets/emoji-metadata.js" as EmojiList
import "../assets/emoji-kitchen-metadata.js" as KitchenMetadata
import "../assets/kaomoji-metadata.js" as KaomojiList

// MAIN

PlasmoidItem {
    id: root

    property var _cachedEmojis: null
    readonly property string klipyBaseUrl: "https://api.klipy.com/api/v1"
    readonly property string klipyDefaultApiKey: "s9q3axg5VURfGO45IDSDhJ1Nxm445kzNdiRF4lmbcVkJaZDe9ShO01YIOvIvtaY2"
    readonly property int klipyDefaultPerPage: 24

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

    function normalizeKlipyApiKey(apiKey) {
        var key = (apiKey || klipyDefaultApiKey).trim();
        return key !== "" ? key : klipyDefaultApiKey;
    }

    function buildGifUrl(apiKey, query, page, perPage) {
        var key = normalizeKlipyApiKey(apiKey);
        var currentPage = page || 1;
        var pageSize = perPage || klipyDefaultPerPage;

        if (!query || query.trim() === "") {
            return klipyBaseUrl + "/" + key + "/gifs/trending?per_page=" + pageSize + "&page=" + currentPage;
        }

        return klipyBaseUrl + "/" + key + "/gifs/search?q=" + encodeURIComponent(query) + "&per_page=" + pageSize + "&page=" + currentPage;
    }

    function parseGifItems(response) {
        if (!response || !response.result || !response.data || !response.data.data) {
            return [];
        }

        var list = response.data.data;
        var parsed = [];

        for (var i = 0; i < list.length; i++) {
            var item = list[i];
            var fileObj = item.file && item.file.sm && item.file.sm.gif ? item.file.sm.gif : null;
            if (!fileObj) {
                continue;
            }

            var rawGif = item.file && item.file.hd && item.file.hd.gif ? item.file.hd.gif.url : "";
            if (rawGif === "") {
                continue;
            }

            var previewGif = fileObj.url;
            var w = fileObj.width || 200;
            var h = fileObj.height || 200;

            parsed.push({
                title: item.title || "Klipy GIF",
                rawUrl: rawGif,
                previewUrl: previewGif,
                aspectRatio: w / h
            });
        }

        return parsed;
    }

    Plasmoid.icon: "preferences-desktop-emoticons-symbolic"
    preferredRepresentation: compactRepresentation
    hideOnWindowDeactivate: !plasmoid.configuration.AlwaysOpen

    compactRepresentation: Loader {
        sourceComponent: compactContentComponent
        onLoaded: {
            if (item) {
                item.plasmoidItem = root
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        collapseMarginsHint: true

        Layout.minimumWidth: Kirigami.Units.gridUnit * 27
        Layout.preferredWidth: Kirigami.Units.gridUnit * 35
        Layout.preferredHeight: Kirigami.Units.gridUnit * 35

        Layout.minimumHeight: Math.max(Kirigami.Units.gridUnit * 24, fullRepresentationView.item ? fullRepresentationView.item.minimumRequiredHeight : Kirigami.Units.gridUnit * 30)

        Loader {
            id: fullRepresentationView
            anchors.fill: parent
            sourceComponent: fullContentComponent
            onLoaded: {
                if (item) {
                    item.plasmoidItem = root
                }
            }
        }
    }

    // COMPACT REPRESENTATION

    Component {
        id: compactContentComponent

        MouseArea {
            id: compactRoot

            hoverEnabled: true
            cursorShape: easterEggMode ? Qt.CrossCursor : Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

            property bool wasExpanded: false
            property var plasmoidItem: null
            property bool easterEggMode: false
            property var emojiIcons: []
            property int currentEmojiIndex: 0

            implicitWidth: PlasmaCore.Theme.panelMinimumWidth
            implicitHeight: PlasmaCore.Theme.panelMinimumHeight
            Layout.minimumWidth: PlasmaCore.Theme.panelMinimumWidth
            Layout.minimumHeight: PlasmaCore.Theme.panelMinimumHeight

            Accessible.name: Plasmoid.title
            Accessible.role: Accessible.Button

            function expander() {
                if (plasmoidItem) {
                    return plasmoidItem;
                }
                if (typeof plasmoid !== "undefined") {
                    return plasmoid;
                }
                return null;
            }

            function ensureEmojiIcons() {
                if (emojiIcons.length === 0) {
                    emojiIcons = root.getIconEmojis(EmojiList.emojiList);
                }
                if (emojiIcons.length > 0) {
                    currentEmojiIndex = Math.floor(Math.random() * emojiIcons.length);
                }
            }

            onPressed: {
                const target = expander();
                wasExpanded = target ? target.expanded : false;

                if (mouse.button === Qt.MiddleButton) {
                    ensureEmojiIcons();
                    easterEggMode = !easterEggMode;
                    mouse.accepted = true;
                }
            }

            onClicked: {
                const target = expander();
                if (mouse.button === Qt.LeftButton) {
                    if (target) {
                        target.expanded = !wasExpanded;
                    }
                } else if (mouse.button === Qt.MiddleButton) {
                    mouse.accepted = true;
                }
            }

            onDoubleClicked: {
                easterEggMode = false;
            }

            onEntered: {
                const target = expander();
                if (!target || !target.expanded) {
                    ensureEmojiIcons();
                }
            }

            Item {
                anchors.fill: parent

                HoverHandler {
                    cursorShape: compactRoot.easterEggMode ? Qt.CrossCursor : Qt.PointingHandCursor
                }

                Kirigami.Icon {
                    id: defaultIcon
                    anchors.fill: parent
                    transformOrigin: Item.Center

                    source: "preferences-desktop-emoticons-symbolic"
                    visible: !compactRoot.easterEggMode
                    opacity: compactRoot.easterEggMode ? 0 : 1.0
                }

                Text {
                    id: emojiIcon
                    anchors.fill: parent
                    transformOrigin: Item.Center

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    text: (compactRoot.emojiIcons && compactRoot.emojiIcons.length > 0) ? compactRoot.emojiIcons[compactRoot.currentEmojiIndex] : ""
                    font.pixelSize: Math.min(width, height) * 0.8
                    font.family: "emoji"

                    visible: compactRoot.easterEggMode
                    opacity: compactRoot.easterEggMode ? ((compactRoot.containsMouse || (expander() && expander().expanded)) ? 1.0 : 0.7) : 0
                    scale: (compactRoot.containsMouse || (expander() && expander().expanded)) ? 1.0 : 1.0

                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                    smooth: true
                    antialiasing: true
                }
            }
        }
    }

    // FULL REPRESENTATION

    Component {
        id: fullContentComponent

        Item {
            id: fullRoot
            anchors.fill: parent

            implicitHeight: Math.max(Kirigami.Units.gridUnit * 24, minimumRequiredHeight)

            property var plasmoidItem: null
            readonly property bool isWidgetExpanded: fullRoot.plasmoidItem ? fullRoot.plasmoidItem.expanded : true
            property bool sidebarExpanded: false
            property bool isAnyCategoryDragging: false
            property var selectedEmojis: []
            property var selectedEmojiSet: ({})
            property bool ctrlDragSelectActive: false

            property string hoveredEmojiName: ""
            property int keyboardPressedIndex: -1
            property string defaultPastePlaceholder: {
                if (fullRoot.selectedCategory === fullRoot.catGifs) return i18n("Paste links…");
                if (fullRoot.selectedCategory === fullRoot.catKaomoji) return i18n("Paste kaomojis…");
                return i18n("Paste emojis…");
            }
            property string searchPlaceholderText: i18n("Search emojis…")
            property bool searchPlaceholderMessageActive: false

            property int internalGridSize: {
                var configValue = plasmoid.configuration.GridSize;
                if (configValue === undefined || configValue === null) {
                    return 44;
                }
                return configValue;
            }

            readonly property int gifPreferredWidth: {
                var configValue = plasmoid.configuration.GifSize;
                if (configValue === undefined || configValue === null) {
                    return 125;
                }
                if (configValue <= 0) return 90;
                if (configValue === 1) return 125;
                if (configValue === 2) return 160;
                return configValue;
            }

            property var emojiGridView: null
            property var emojiExternalScrollBar: null
            property string emojiHoveredEmojiKey: ""
            property string emojiHoveredEmojiType: ""
            property string emojiHoveredKitchenUrl: ""
            property string emojiLastHoveredEmojiKey: ""
            property bool emojiKeyboardNavigationEnabled: plasmoid.configuration.KeyboardNavigation
            property bool alwaysAnimateGifs: plasmoid.configuration.AlwaysAnimateGifs
            property Item emojiTabNextTarget: searchField
            property Item currentGridView: {
                if (selectedCategory === catEmojiKitchen)
                return kitchenView;
                if (selectedCategory === catGifs)
                return gifView;
                return null;
            }
            property Item emojiTabPreviousTarget: categoryListView.count > 0 ? (categoryListView.itemAtIndex(categoryListView.count - 1) ? categoryListView.itemAtIndex(categoryListView.count - 1) : sidebarToggleButton) : sidebarToggleButton

            property int categoryHeight: 32
            property int categorySpacing: 2
            property int pinButtonHeight: 32
            property int settingsButtonHeight: 32
            property int toggleButtonHeight: 32
            property int separatorHeight: 1
            property int fallbackTopSectionHeight: 76
            property int fallbackPreviewHeight: 76
            property int minimumRequiredHeight: {
                var categoryCount = categoryModel ? categoryModel.count : 0;
                var fallbackCategories = 0;
                if (categoryCount > 0) {
                    fallbackCategories = (categoryCount * categoryHeight) + Math.max(0, categoryCount - 1) * categorySpacing;
                }

                var topBlock = topSection ? (topSection.implicitHeight + 16) : fallbackTopSectionHeight;
                var bottomBlock = previewBar ? previewBar.Layout.preferredHeight : fallbackPreviewHeight;
                var sidebarButtons = (pinButton ? pinButton.implicitHeight : pinButtonHeight) + (settingsButtonInSidebar ? settingsButtonInSidebar.implicitHeight : settingsButtonHeight) + (sidebarToggleButton ? sidebarToggleButton.implicitHeight : toggleButtonHeight);
                var categoriesBlock = categoryListView ? categoryListView.contentHeight : fallbackCategories;

                return topBlock + separatorHeight + sidebarButtons + categoriesBlock + separatorHeight + bottomBlock;
            }

            readonly property string catFavorites: "Favorites"
            readonly property string catRecent: "Recent"
            readonly property string catEmojiKitchen: "Emoji Kitchen"
            readonly property string catGifs: "GIFs"
            readonly property string catKaomoji: "Kaomoji"

            property string hoveredGifTitle: ""
            property string hoveredGifUrl: ""

            readonly property int fontSizePreviewLabel: 14
            readonly property int fontSizeEmptyLabel: 16

            property var defaultCategoryOrder: [
                {
                    name: catGifs,
                    displayName: i18n("GIFs"),
                    icon: "fileview-preview-symbolic"
                },
                {
                    name: catKaomoji,
                    displayName: i18n("Kaomoji"),
                    icon: "kstars_cbound-symbolic"
                },
                {
                    name: "Smileys & Emotion",
                    displayName: i18n("Smileys & Emotion"),
                    icon: "smiley"
                },
                {
                    name: "People & Body",
                    displayName: i18n("People & Body"),
                    icon: "im-user"
                },
                {
                    name: "Animals & Nature",
                    displayName: i18n("Animals & Nature"),
                    icon: "animal"
                },
                {
                    name: "Food & Drink",
                    displayName: i18n("Food & Drink"),
                    icon: "food"
                },
                {
                    name: "Activities",
                    displayName: i18n("Activities"),
                    icon: "games-highscores"
                },
                {
                    name: "Travel & Places",
                    displayName: i18n("Travel & Places"),
                    icon: "globe"
                },
                {
                    name: "Objects",
                    displayName: i18n("Objects"),
                    icon: "object-group"
                },
                {
                    name: "Symbols",
                    displayName: i18n("Symbols"),
                    icon: "checkbox"
                },
                {
                    name: "Flags",
                    displayName: i18n("Flags"),
                    icon: "flag"
                }
            ]

            property var emojiList: []
            property string filter: ""
            property string lastFilterForGroups: "-1"
            property var filteredEmojis: []
            property string selectedCategory: "Smileys & Emotion"
            property var filteredEmojiByGroup: ({})
            property var recentEmojis: []
            property var favoriteEmojis: []

            property bool favoritesEmojisExpanded: true
            property bool favoritesGifsExpanded: true
            property bool favoritesKitchenExpanded: true
            property bool recentEmojisExpanded: true
            property bool recentGifsExpanded: true
            property bool recentKitchenExpanded: true

            property bool isLoading: false
            property int loadingProgress: 0
            property int totalEmojisToLoad: 0
            property var pendingEmojis: []
            property int chunkSize: 100

            property var loadingBuffer: []
            property var kitchenEmojiList: []
            property var emojiByGroup: ({})
            property var activeEmojis: []
            property var activeGifs: []
            property var activeKitchens: []

            function _updateActiveSubLists() {
                if (selectedCategory !== catFavorites && selectedCategory !== catRecent) {
                    activeEmojis = [];
                    activeGifs = [];
                    activeKitchens = [];
                    return;
                }

                activeEmojis = filteredEmojis.filter(e => !e.type || e.type === "emoji");
                activeGifs = filteredEmojis.filter(e => e.type === "gif");
                activeKitchens = filteredEmojis.filter(e => e.type === "kitchen");
            }

            function getActiveEmojis() {
                return activeEmojis;
            }
            function getActiveGifs() {
                return activeGifs;
            }
            function getActiveKitchens() {
                return activeKitchens;
            }

            readonly property int favRecentsNumColumns: Math.max(2, Math.min(4, Math.floor((fullRoot.width - 16) / gifPreferredWidth)))
            property var activeGifCol0: []
            property var activeGifCol1: []
            property var activeGifCol2: []
            property var activeGifCol3: []
            property int _lastNumCols: -1

            onActiveGifsChanged: _updateActiveGifCols(favRecentsNumColumns)
            onFavRecentsNumColumnsChanged: _updateActiveGifCols(favRecentsNumColumns)

            function _updateActiveGifCols(numCols) {
                _lastNumCols = numCols;

                const gifs = activeGifs;
                const c0 = [], c1 = [], c2 = [], c3 = [];
                for (let i = 0; i < gifs.length; i++) {
                    const col = i % numCols;
                    if (col === 0)
                        c0.push(gifs[i]);
                    else if (col === 1)
                        c1.push(gifs[i]);
                    else if (col === 2)
                        c2.push(gifs[i]);
                    else
                        c3.push(gifs[i]);
                }

                _syncListModel(favGifCol0Model, c0, "rawUrl");
                _syncListModel(favGifCol1Model, c1, "rawUrl");
                _syncListModel(favGifCol2Model, numCols >= 3 ? c2 : [], "rawUrl");
                _syncListModel(favGifCol3Model, numCols >= 4 ? c3 : [], "rawUrl");

                activeGifCol0 = c0;
                activeGifCol1 = c1;
                activeGifCol2 = numCols >= 3 ? c2 : [];
                activeGifCol3 = numCols >= 4 ? c3 : [];
            }

            function getActiveGifCol(colIndex, numCols) {
                if (colIndex === 0)
                    return activeGifCol0;
                if (colIndex === 1)
                    return activeGifCol1;
                if (colIndex === 2)
                    return activeGifCol2;
                return activeGifCol3;
            }

            property bool gridIsMouseOver: false

            property bool gridKeyboardActionPressed: false
            property bool gridExternalKeyboardActionPressed: false

            property bool pinButtonKeyboardPressed: false
            property bool settingsButtonKeyboardPressed: false
            property bool sidebarButtonKeyboardPressed: false
            property int draggedCategoryIndex: -1

            Settings {
                id: settings
                category: "RecentEmojis"
                property string recentEmojisJson: "[]"
                property string favoriteEmojisJson: "[]"
            }

            Timer {
                id: loadTimer
                interval: 10
                repeat: true
                onTriggered: processNextChunk()
            }

            function processNextChunk() {
                const limit = Math.min(loadingProgress + chunkSize, totalEmojisToLoad);
                const entries = emojiList;
                let currentEntries = [];
                let processedCount = 0;
                const sourceData = pendingEmojis;

                while (loadingProgress < totalEmojisToLoad && processedCount < chunkSize) {
                    const item = sourceData[loadingProgress];
                    const itemName = item.name || "";
                    const itemAliases = item.aliases || [];
                    const itemTags = item.tags || [];
                    const itemGroup = item.group;

                    let searchStr = (item.emoji + " " + itemName + " " + (item.slug || "") + " " + itemGroup).toLowerCase();
                    if (itemAliases.length > 0)
                    searchStr += " " + itemAliases.join(" ").toLowerCase();
                    if (itemTags.length > 0)
                    searchStr += " " + itemTags.join(" ").toLowerCase();

                    loadingBuffer.push({
                        emoji: item.emoji,
                        name: itemName,
                        slug: itemName ? itemName.toLowerCase().replace(/[^a-z0-9]+/g, '-') : "",
                        group: itemGroup,
                        aliases: itemAliases,
                        tags: itemTags,
                        searchString: searchStr,
                        emoji_version: "",
                        unicode_version: ""
                    });

                    loadingProgress++;
                    processedCount++;
                }

                if (loadingProgress >= totalEmojisToLoad) {
                    loadTimer.stop();
                    emojiList = loadingBuffer;
                    isLoading = false;
                    loadingBuffer = [];
                    pendingEmojis = [];
                    console.log("Successfully loaded", emojiList.length, "emojis asynchronously");

                    const kitchenBases = new Set(Object.keys(KitchenMetadata.kitchenMetadata));
                    kitchenEmojiList = emojiList.filter(e => {
                        if (!e.emoji)
                        return false;
                        let cp = [];
                        for (const char of e.emoji)
                        cp.push(char.codePointAt(0).toString(16));
                        return kitchenBases.has(cp.join("-"));
                    });

                    const byGroup = {};
                    for (let i = 0; i < emojiList.length; i++) {
                        const g = emojiList[i].group;
                        if (g) {
                            if (!byGroup[g])
                            byGroup[g] = [];
                            byGroup[g].push(emojiList[i]);
                        }
                    }
                    emojiByGroup = byGroup;

                    updateFilteredEmojis();
                }
            }

            function loadEmojis() {
                try {
                    const rawData = EmojiList.emojiList;
                    const flatList = [];

                    isLoading = true;
                    loadingProgress = 0;
                    loadingBuffer = [];
                    for (const category in rawData) {
                        if (!Object.prototype.hasOwnProperty.call(rawData, category))
                        continue;
                        const emojiArray = rawData[category] || [];
                        for (let i = 0; i < emojiArray.length; i++) {
                            emojiArray[i].group = category;
                            flatList.push(emojiArray[i]);
                        }
                    }

                    pendingEmojis = flatList;
                    totalEmojisToLoad = flatList.length;

                    loadTimer.restart();
                } catch (e) {
                    console.log("Error starting emoji load:", e);
                    isLoading = false;
                }
            }

            function loadRecentEmojis() {
                try {
                    if (settings.recentEmojisJson && settings.recentEmojisJson !== "[]") {
                        let parsed = JSON.parse(settings.recentEmojisJson);
                        if (Array.isArray(parsed)) {
                            let validItems = [];
                            parsed.forEach(item => {
                                if (!item) return;
                                const t = item.type || "emoji";
                                if (t === "emoji" && (!item.emoji || typeof item.emoji !== 'string')) return;
                                if (t === "gif" && (!item.rawUrl || typeof item.rawUrl !== 'string')) return;
                                if (t === "kitchen" && (!item.url || typeof item.url !== 'string')) return;
                                
                                if (t === "gif") {
                                    let r = item.aspectRatio;
                                    if (isNaN(r) || !r || r <= 0)
                                    item.aspectRatio = 1.0;
                                }
                                validItems.push(item);
                            });
                            recentEmojis = validItems;
                            if (recentEmojis.length > 100) {
                                recentEmojis = recentEmojis.slice(0, 100);
                            }
                            try {
                                settings.recentEmojisJson = JSON.stringify(recentEmojis);
                            } catch (e) {
                                console.log("Failed to save trimmed recent emojis:", e);
                            }
                            return;
                        }
                    }
                    recentEmojis = [];
                } catch (e) {
                    console.log("Failed to load recent emojis:", e);
                    recentEmojis = [];
                }
            }

            function loadFavoriteEmojis() {
                try {
                    if (settings.favoriteEmojisJson && settings.favoriteEmojisJson !== "[]") {
                        let parsed = JSON.parse(settings.favoriteEmojisJson);
                        if (Array.isArray(parsed)) {
                            let validItems = [];
                            parsed.forEach(item => {
                                if (!item) return;
                                const t = item.type || "emoji";
                                if (t === "emoji" && (!item.emoji || typeof item.emoji !== 'string')) return;
                                if (t === "gif" && (!item.rawUrl || typeof item.rawUrl !== 'string')) return;
                                if (t === "kitchen" && (!item.url || typeof item.url !== 'string')) return;
                                
                                if (t === "gif") {
                                    let r = item.aspectRatio;
                                    if (isNaN(r) || !r || r <= 0)
                                    item.aspectRatio = 1.0;
                                }
                                validItems.push(item);
                            });
                            favoriteEmojis = validItems;
                            try {
                                settings.favoriteEmojisJson = JSON.stringify(favoriteEmojis);
                            } catch (e) {
                                console.log("Failed to save filtered favorite emojis:", e);
                            }
                            return;
                        }
                    }
                    favoriteEmojis = [];
                } catch (e) {
                    console.log("Failed to load favorite emojis:", e);
                    favoriteEmojis = [];
                }
            }

            function addRecentItem(type, item) {
                if (!item)
                return;
                let newRecentEmojis = [];
                let found = false;

                for (let i = 0; i < recentEmojis.length; i++) {
                    const rec = recentEmojis[i];
                    const recType = rec.type || "emoji";
                    if (recType === type) {
                        if (type === "emoji" && rec.emoji === item.emoji) {
                            found = true;
                            continue;
                        }
                        if (type === "gif" && rec.rawUrl === item.rawUrl) {
                            found = true;
                            continue;
                        }
                        if (type === "kitchen" && rec.url === item.url) {
                            found = true;
                            continue;
                        }
                    }
                    newRecentEmojis.push(rec);
                }

                const copy = Object.assign({
                    type: type
                }, item);
                newRecentEmojis.unshift(copy);

                if (newRecentEmojis.length > 100) {
                    newRecentEmojis = newRecentEmojis.slice(0, 100);
                }

                recentEmojis = newRecentEmojis;
                try {
                    settings.recentEmojisJson = JSON.stringify(recentEmojis);
                } catch (e) {
                    console.log("Failed to save recent emojis:", e);
                }
                updateFilteredEmojis();
            }

            function addRecentEmoji(emoji) {
                addRecentItem("emoji", emoji);
            }

            function isFavoriteItem(type, item) {
                if (!item)
                return false;
                const len = favoriteEmojis.length;
                for (let i = 0; i < len; i++) {
                    const fav = favoriteEmojis[i];
                    const favType = fav.type || "emoji";
                    if (favType !== type)
                    continue;
                    if (type === "emoji" && fav.emoji === item.emoji) {
                        return true;
                    } else if (type === "gif" && fav.rawUrl === item.rawUrl) {
                        return true;
                    } else if (type === "kitchen" && fav.url === item.url) {
                        return true;
                    }
                }
                return false;
            }

            function isFavorite(emoji) {
                return isFavoriteItem("emoji", {
                    emoji: emoji
                });
            }

            function toggleFavoriteItem(type, item) {
                if (!item)
                return false;
                let isFavoriteNow = false;
                const index = favoriteEmojis.findIndex(e => {
                    const favType = e.type || "emoji";
                    if (favType !== type)
                    return false;
                    if (type === "emoji")
                    return e.emoji === item.emoji;
                    if (type === "gif")
                    return e.rawUrl === item.rawUrl;
                    if (type === "kitchen")
                    return e.url === item.url;
                    return false;
                });

                if (index >= 0) {
                    favoriteEmojis.splice(index, 1);
                    isFavoriteNow = false;
                } else {
                    const copy = Object.assign({
                        type: type
                    }, item);
                    favoriteEmojis.push(copy);
                    isFavoriteNow = true;
                }
                favoriteEmojis = favoriteEmojis.slice();
                saveFavoriteEmojis();
                updateFilteredEmojis();

                let label = "";
                if (type === "emoji") {
                    const displayName = (item.name && item.name.length > 0) ? item.name : "";
                    label = displayName && displayName.length > 0 ? displayName + " (" + item.emoji + ")" : item.emoji;
                } else if (type === "gif") {
                    label = item.title || "Klipy GIF";
                } else if (type === "kitchen") {
                    label = i18n("(%1 + %2)", item.emoji1, item.emoji2);
                }

                showSearchTemporaryMessage(isFavoriteNow ? i18n("Favorited: %1", label) : i18n("Unfavorited: %1", label));
                return isFavoriteNow;
            }

            function toggleFavoriteEmoji(emoji) {
                return toggleFavoriteItem("emoji", emoji);
            }

            function saveFavoriteEmojis() {
                try {
                    settings.favoriteEmojisJson = JSON.stringify(favoriteEmojis);
                } catch (e) {
                    console.log("Failed to save favorite emojis:", e);
                }
            }

            function clearRecentEmojis() {
                recentEmojis = recentEmojis.filter(e => e.type === "gif");
                try {
                    settings.recentEmojisJson = JSON.stringify(recentEmojis);
                } catch (e) {
                    console.log("Failed to clear recent emojis:", e);
                }
                updateFilteredEmojis();
            }

            function clearFavoriteEmojis() {
                favoriteEmojis = favoriteEmojis.filter(e => e.type === "gif");
                try {
                    settings.favoriteEmojisJson = JSON.stringify(favoriteEmojis);
                } catch (e) {
                    console.log("Failed to clear favorite emojis:", e);
                }
                updateFilteredEmojis();
            }

            function clearRecentGifs() {
                recentEmojis = recentEmojis.filter(e => e.type !== "gif");
                try {
                    settings.recentEmojisJson = JSON.stringify(recentEmojis);
                } catch (e) {
                    console.log("Failed to clear recent GIFs:", e);
                }
                updateFilteredEmojis();
            }

            function clearFavoriteGifs() {
                favoriteEmojis = favoriteEmojis.filter(e => e.type !== "gif");
                try {
                    settings.favoriteEmojisJson = JSON.stringify(favoriteEmojis);
                } catch (e) {
                    console.log("Failed to clear favorite GIFs:", e);
                }
                updateFilteredEmojis();
            }

            function performFilter(list, searchText) {
                if (!searchText || searchText.trim() === "") {
                    return list;
                }

                const lowerFilter = searchText.toLowerCase().trim();
                const searchTokens = lowerFilter.split(/\s+/);

                return list.filter(e => {
                    if (!e.searchString)
                    return false;
                    for (let i = 0; i < searchTokens.length; i++) {
                        if (e.searchString.indexOf(searchTokens[i]) === -1) {
                            return false;
                        }
                    }
                    return true;
                });
            }

            function getCodepoint(emoji) {
                if (!emoji)
                return "";
                let res = [];
                for (let char of emoji) {
                    let cp = char.codePointAt(0).toString(16);
                    res.push(cp);
                }
                return res.join("-");
            }

            function updateFilteredEmojis() {
                if (selectedCategory === catGifs) {
                    filteredEmojis = [];
                    return;
                }

                if (emojiList.length === 0) {
                    filteredEmojis = [];
                    return;
                }

                let result = emojiList;

                if (selectedCategory === catGifs) {
                    result = activeGifs;
                } else if (selectedCategory === catRecent) {
                    result = recentEmojis;
                } else if (selectedCategory === catFavorites) {
                    result = favoriteEmojis;
                } else if (selectedCategory === catEmojiKitchen) {
                    result = kitchenEmojiList;
                } else {
                    result = emojiByGroup[selectedCategory] || [];
                }

                if (filter && filter.trim() !== "") {
                    result = performFilter(result, filter);
                }
                filteredEmojis = result;

                if (fullRoot.lastFilterForGroups !== filter || Object.keys(filteredEmojiByGroup).length === 0) {
                    let groupResult = {};
                    const cats = ["Smileys & Emotion", "People & Body", "Animals & Nature", "Food & Drink", "Activities", "Travel & Places", "Objects", "Symbols", "Flags"];
                    for (let i = 0; i < cats.length; i++) {
                        let catEmojis = emojiByGroup[cats[i]] || [];
                        if (filter && filter.trim() !== "") {
                            catEmojis = performFilter(catEmojis, filter);
                        }
                        groupResult[cats[i]] = catEmojis;
                    }
                    filteredEmojiByGroup = groupResult;
                    fullRoot.lastFilterForGroups = filter;
                }
            }

            onFilterChanged: updateFilteredEmojis()
            onSelectedCategoryChanged: {
                updateFilteredEmojis();
                if (!fullRoot.searchPlaceholderMessageActive) {
                    fullRoot.resetSearchPlaceholder();
                }
                pastePlaceholderResetTimer.stop();
                Qt.callLater(function () {
                    if (pasteField)
                    pasteField.placeholderText = fullRoot.defaultPastePlaceholder;
                });
            }

            onEmojiListChanged: {
                if (fullRoot.selectedCategory === "Smileys & Emotion" && !fullRoot.searchPlaceholderMessageActive) {
                    fullRoot.resetSearchPlaceholder();
                }
            }

            onFilteredEmojisChanged: {
                _updateActiveSubLists();

                if (fullRoot.filter && fullRoot.filter.length > 0 && fullRoot.filteredEmojis.length > 0) {
                    const firstItem = fullRoot.filteredEmojis[0];
                    fullRoot.emojiHoveredEmojiKey = firstItem.emoji;
                    fullRoot.hoveredEmojiName = firstItem.name;
                    fullRoot.emojiLastHoveredEmojiKey = firstItem.emoji;

                    if (emojiGridView) {
                        emojiGridView.currentIndex = 0;
                    }
                }
            }

            Connections {
                target: fullRoot.plasmoidItem
                function onExpandedChanged() {
                    if (fullRoot.plasmoidItem && fullRoot.plasmoidItem.expanded) {
                        Qt.callLater(() => {
                            if (searchField) {
                                searchField.forceActiveFocus();
                                searchField.selectAll();
                            }
                        });
                    }
                }
            }

            function handleEscapePressed() {
                if (searchField.text.length > 0 || fullRoot.selectedEmojis.length > 0) {
                    searchField.text = "";
                    fullRoot.selectedEmojis = [];
                    fullRoot.selectedEmojiSet = ({});
                    if (pasteField)
                    pasteField.placeholderText = fullRoot.defaultPastePlaceholder;
                    if (searchField)
                    searchField.forceActiveFocus();
                } else {
                    if (fullRoot.plasmoidItem) {
                        fullRoot.plasmoidItem.expanded = false;
                    }
                }
            }

            function emojiIndexForEmojiKey(key) {
                if (!key || key.length === 0)
                return -1;
                const length = fullRoot.filteredEmojis ? fullRoot.filteredEmojis.length : 0;
                for (let i = 0; i < length; i++) {
                    const item = fullRoot.filteredEmojis[i];
                    if (item && item.emoji === key)
                    return i;
                }
                return -1;
            }

            function emojiEnsureKeyboardAnchorIndex() {
                if (!emojiGridView || emojiGridView.count === 0)
                return -1;
                if (emojiGridView.currentIndex >= 0 && emojiGridView.currentIndex < emojiGridView.count) {
                    return emojiGridView.currentIndex;
                }

                const keyCandidates = [fullRoot.emojiHoveredEmojiKey, fullRoot.emojiHoveredEmojiKey];
                for (let i = 0; i < keyCandidates.length; i++) {
                    const candidate = keyCandidates[i];
                    const candidateIndex = emojiIndexForEmojiKey(candidate);
                    if (candidateIndex >= 0) {
                        emojiGridView.currentIndex = candidateIndex;
                        emojiGridView.updateKeyboardHover();
                        return candidateIndex;
                    }
                }

                emojiGridView.currentIndex = 0;
                emojiGridView.updateKeyboardHover();
                return 0;
            }

            function emojiEstimateNavigationColumns() {
                if (!emojiGridView)
                return 1;
                const cellWidth = emojiGridView.cellWidth > 0 ? emojiGridView.cellWidth : fullRoot.internalGridSize;
                if (cellWidth <= 0)
                return 1;
                const availableWidth = emojiGridView.width > 0 ? emojiGridView.width : emojiArea.width;
                const columns = Math.floor(availableWidth / cellWidth);
                return Math.max(1, columns);
            }


            function emojiManualMoveCurrentIndex(key) {
                if (!emojiGridView || emojiGridView.count === 0)
                return false;

                let index = emojiGridView.currentIndex;
                if (index < 0)
                index = 0;

                const count = emojiGridView.count;
                const columns = emojiEstimateNavigationColumns();
                let newIndex = index;

                switch (key) {
                    case Qt.Key_Left:
                    if (index > 0)
                    newIndex = index - 1;
                    else if (emojiGridView.keyNavigationWraps && count > 0)
                    newIndex = count - 1;
                    break;
                    case Qt.Key_Right:
                    if (index + 1 < count)
                    newIndex = index + 1;
                    else if (emojiGridView.keyNavigationWraps && count > 0)
                    newIndex = 0;
                    break;
                    case Qt.Key_Up:
                    const candidateUp = index - columns;
                    if (candidateUp >= 0) {
                        newIndex = candidateUp;
                    } else if (emojiGridView.keyNavigationWraps && count > 0) {
                        const remainder = index % columns;
                        let wrapped = Math.floor((count - 1) / columns) * columns + remainder;
                        if (wrapped >= count)
                        wrapped = count - 1;
                        newIndex = wrapped;
                    }
                    break;
                    case Qt.Key_Down:
                    const candidateDown = index + columns;
                    if (candidateDown < count) {
                        newIndex = candidateDown;
                    } else if (emojiGridView.keyNavigationWraps && count > 0) {
                        let wrapped = index % columns;
                        if (wrapped >= count)
                        wrapped = count - 1;
                        newIndex = wrapped;
                    }
                    break;
                    default:
                    break;
                }

                if (newIndex !== index) {
                    emojiGridView.currentIndex = newIndex;
                    return true;
                }
                return false;
            }

            function emojiHandleExternalArrowKey(key) {
                if (!fullRoot.emojiKeyboardNavigationEnabled)
                return false;
                if (!emojiGridView || emojiGridView.count === 0)
                return false;
                if (key !== Qt.Key_Left && key !== Qt.Key_Right && key !== Qt.Key_Up && key !== Qt.Key_Down)
                return false;

                emojiEnsureKeyboardAnchorIndex();
                const previousIndex = emojiGridView.currentIndex;
                emojiManualMoveCurrentIndex(key);

                if (emojiGridView.currentIndex !== previousIndex) {
                    if (typeof emojiGridView.positionViewAtIndex === "function") {
                        emojiGridView.positionViewAtIndex(emojiGridView.currentIndex, GridView.Contain);
                    }
                    emojiGridView.updateKeyboardHover();
                    return true;
                }
                return false;
            }


            function handleEmojiSelected(emoji, isCtrlClick, isShiftClick, isAltClick) {
                if (!emoji) return;
                const emojiObj = fullRoot.emojiList.find(e => e.emoji === emoji) || {
                    emoji: emoji,
                    name: "",
                    slug: "",
                    group: ""
                };

                if (isAltClick) {
                    fullRoot.toggleFavoriteEmoji(emojiObj);
                    return;
                }

                if (isCtrlClick) {
                    const index = fullRoot.selectedEmojis.findIndex(e => e === emoji);
                    if (index >= 0) {
                        fullRoot.selectedEmojis.splice(index, 1);
                    } else {
                        fullRoot.selectedEmojis.push(emoji);
                    }
                    fullRoot.selectedEmojis = fullRoot.selectedEmojis.slice();

                    const newSet = {};
                    for (const e of fullRoot.selectedEmojis)
                    newSet[e] = true;
                    fullRoot.selectedEmojiSet = newSet;

                    if (fullRoot.selectedEmojis.length > 0) {
                        pasteField.placeholderText = i18n("Selected %1 emoji(s)", fullRoot.selectedEmojis.length);
                    } else {
                        pasteField.placeholderText = fullRoot.defaultPastePlaceholder;
                    }
                } else {
                    if (fullRoot.selectedEmojis.length > 0) {
                        const combined = fullRoot.selectedEmojis.join("");
                        clipboard.content = combined;
                        showCopiedFeedback(combined, fullRoot.selectedEmojis.length + " emojis");
                        fullRoot.selectedEmojis = [];
                        fullRoot.selectedEmojiSet = ({});
                    } else {
                        if (isShiftClick) {
                            if (emojiObj.name && emojiObj.name.length > 0) {
                                clipboard.content = emojiObj.name;
                                addRecentEmoji(emojiObj);
                                showCopiedFeedback(emojiObj.name, emojiObj.emoji);
                            } else {
                                clipboard.content = emoji;
                                addRecentEmoji(emojiObj);
                                showCopiedFeedback(emoji, "");
                            }
                        } else {
                            clipboard.content = emoji;
                            addRecentEmoji(emojiObj);
                            showCopiedFeedback(emoji, emojiObj.name);
                        }
                    }

                    if (plasmoid.configuration.CloseAfterSelection) {
                        if (fullRoot.plasmoidItem) {
                            fullRoot.plasmoidItem.expanded = false;
                        }
                    }
                }
            }

            function handleEmojiRightClicked(emoji, emojiObj, globalPos) {
                contextMenu.emoji = emoji;
                contextMenu.emojiObj = emojiObj;
                contextMenu.popup(globalPos.x, globalPos.y);
            }

            function loadDefaultCategories() {
                categoryModel.clear();
                for (var i = 0; i < defaultCategoryOrder.length; i++) {
                    categoryModel.append(defaultCategoryOrder[i]);
                }
            }

            function saveCategoryOrder() {
                var order = [];
                for (var i = 0; i < categoryModel.count; i++) {
                    order.push({
                        name: categoryModel.get(i).name,
                        icon: categoryModel.get(i).icon
                    });
                }
                plasmoid.configuration.CategoryOrder = JSON.stringify(order);
            }

            function _syncListModel(listModel, targetArray, keyField) {
                for (let i = listModel.count - 1; i >= 0; i--) {
                    const modelItem = listModel.get(i);
                    const key = modelItem[keyField];
                    const exists = targetArray.some(item => item[keyField] === key);
                    if (!exists) {
                        listModel.remove(i);
                    }
                }

                for (let i = 0; i < targetArray.length; i++) {
                    const targetItem = targetArray[i];
                    const key = targetItem[keyField];

                    let foundIndex = -1;
                    for (let j = 0; j < listModel.count; j++) {
                        if (listModel.get(j)[keyField] === key) {
                            foundIndex = j;
                            break;
                        }
                    }

                    if (foundIndex === -1) {
                        listModel.insert(i, targetItem);
                    } else if (foundIndex !== i) {
                        listModel.move(foundIndex, i, 1);
                    } else {
                        const modelItem = listModel.get(i);
                        for (let prop in targetItem) {
                            if (modelItem[prop] !== targetItem[prop]) {
                                listModel.setProperty(i, prop, targetItem[prop]);
                            }
                        }
                    }
                }
            }

            function getSearchPlaceholder() {
                if (fullRoot.selectedCategory === catGifs) {
                    return i18n("Search GIFs...");
                }
                if (fullRoot.selectedCategory !== catFavorites && fullRoot.selectedCategory !== catRecent && fullRoot.selectedCategory !== catEmojiKitchen) {
                    return i18n("Search %1 emojis...", fullRoot.emojiList.length);
                }

                let emojiCount = fullRoot.filteredEmojis.length;

                if (emojiCount === 0)
                return i18n("Search emojis…");
                return i18n("Search %1 emojis…", emojiCount);
            }

            function resetSearchPlaceholder() {
                searchPlaceholderResetTimer.stop();
                searchPlaceholderMessageActive = false;
                searchPlaceholderText = getSearchPlaceholder();
            }

            function showSearchTemporaryMessage(message) {
                searchPlaceholderMessageActive = true;
                searchPlaceholderText = message;
                searchPlaceholderResetTimer.restart();
            }

            function showPasteTemporaryMessage(message) {
                pasteField.placeholderText = message;
                pastePlaceholderResetTimer.restart();
            }

            function showCopiedFeedback(emoji, name) {
                if (name && name.length > 0) {
                    showPasteTemporaryMessage(i18n("Copied: %1 (%2)", emoji, name));
                } else {
                    showPasteTemporaryMessage(i18n("Copied: %1", emoji));
                }
            }

            function handleEmojiNavigationFromTextInput(event) {
                if (!plasmoid.configuration.KeyboardNavigation)
                return false;
                if (!event)
                return false;

                if (event.key !== Qt.Key_Left && event.key !== Qt.Key_Right && event.key !== Qt.Key_Up && event.key !== Qt.Key_Down) {
                    return false;
                }

                if (event.modifiers & (Qt.AltModifier | Qt.MetaModifier))
                return false;
                if (!emojiGridView || typeof emojiHandleExternalArrowKey !== "function")
                return false;

                return emojiHandleExternalArrowKey(event.key);
            }

            function openConfigurationDialog() {
                var configureAction = null;
                if (typeof Plasmoid !== "undefined" && typeof Plasmoid.internalAction === "function") {
                    configureAction = Plasmoid.internalAction("configure");
                }
                if (!configureAction && typeof plasmoid !== "undefined" && typeof plasmoid.action === "function") {
                    configureAction = plasmoid.action("configure");
                }
                if (!configureAction)
                return;
                if (typeof configureAction.trigger === "function") {
                    configureAction.trigger();
                } else if (typeof configureAction.triggered === "function") {
                    configureAction.triggered();
                }
            }

            Component.onCompleted: {
                loadRecentEmojis();
                loadFavoriteEmojis();
                Qt.callLater(loadEmojis);

                fullRoot.resetSearchPlaceholder();
                fullRoot.emojiExternalScrollBar = null;
                fullRoot.emojiKeyboardNavigationEnabled = plasmoid.configuration.KeyboardNavigation;
                Qt.callLater(function () {
                    searchField.forceActiveFocus();
                });

                var savedOrder = plasmoid.configuration.CategoryOrder;
                if (savedOrder && savedOrder.length > 0) {
                    try {
                        var parsed = JSON.parse(savedOrder);
                        parsed = parsed.filter(item => item.name !== catFavorites && item.name !== catRecent);

                        var hasGifs = false;
                        for (var k = 0; k < parsed.length; k++) {
                            if (parsed[k].name === catGifs) {
                                hasGifs = true;
                                parsed[k].icon = "fileview-preview-symbolic";
                            }
                        }
                        if (!hasGifs) {
                            parsed.splice(0, 0, {
                                name: catGifs,
                                icon: "fileview-preview-symbolic"
                            });
                        }

                        categoryModel.clear();
                        for (var i = 0; i < parsed.length; i++) {
                            if (parsed[i].name === "Activities") {
                                if (parsed[i].icon === "applications-games" || parsed[i].icon === "games-highscore") {
                                    parsed[i].icon = "games-highscores";
                                }
                            }

                            var defaultEntry = null;
                            for (var j = 0; j < defaultCategoryOrder.length; j++) {
                                if (defaultCategoryOrder[j].name === parsed[i].name) {
                                    defaultEntry = defaultCategoryOrder[j];
                                    break;
                                }
                            }
                            parsed[i].displayName = defaultEntry ? defaultEntry.displayName : parsed[i].name;

                            categoryModel.append(parsed[i]);
                        }
                        saveCategoryOrder();
                    } catch (e) {
                        loadDefaultCategories();
                    }
                } else {
                    loadDefaultCategories();
                }
            }

            Connections {
                target: plasmoid.configuration
                function onGridSizeChanged() {
                    fullRoot.internalGridSize = plasmoid.configuration.GridSize;
                }
                function onKeyboardNavigationChanged() {
                    fullRoot.emojiKeyboardNavigationEnabled = plasmoid.configuration.KeyboardNavigation;
                }
            }

            Keys.onPressed: function (event) {
                if (plasmoid.configuration.KeyboardNavigation) {
                    if (event.key === Qt.Key_Escape) {
                        if (fullRoot.plasmoidItem)
                        fullRoot.plasmoidItem.expanded = false;
                        event.accepted = true;
                        return;
                    }

                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ControlModifier)) {
                        if (fullRoot.selectedEmojis.length > 0) {
                            const combined = fullRoot.selectedEmojis.join("");
                            clipboard.content = combined;
                            fullRoot.showCopiedFeedback(combined, fullRoot.selectedEmojis.length + " emojis");
                            fullRoot.selectedEmojis = [];
                            fullRoot.selectedEmojiSet = ({});

                            if (plasmoid.configuration.CloseAfterSelection) {
                                if (fullRoot.plasmoidItem)
                                fullRoot.plasmoidItem.expanded = false;
                            }
                            event.accepted = true;
                            return;
                        }

                        if (emojiGridView && emojiGridView.activeFocus) {
                            return;
                        }
                    }
                } else {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        event.accepted = true;
                        return;
                    }
                }
            }

            ListModel {
                id: categoryModel
            }

            ListModel {
                id: favGifCol0Model
            }
            ListModel {
                id: favGifCol1Model
            }
            ListModel {
                id: favGifCol2Model
            }
            ListModel {
                id: favGifCol3Model
            }

            Timer {
                id: pastePlaceholderResetTimer
                interval: 2000
                running: false
                repeat: false
                onTriggered: {
                    var placeholder = i18n("Paste emojis…");
                    if (fullRoot.selectedCategory === fullRoot.catGifs) placeholder = i18n("Paste links…");
                    if (fullRoot.selectedCategory === fullRoot.catKaomoji) placeholder = i18n("Paste kaomojis…");
                    pasteField.placeholderText = placeholder;
                }
            }

            Timer {
                id: searchPlaceholderResetTimer
                interval: 2000
                running: false
                repeat: false
                onTriggered: {
                    fullRoot.resetSearchPlaceholder();
                }
            }

            KQCA.Clipboard {
                id: clipboard
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    implicitHeight: topSection.implicitHeight + 16

                    RowLayout {
                        id: topSection
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 8

                        PlasmaExtras.SearchField {
                            id: searchField
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            placeholderText: fullRoot.searchPlaceholderText
                            text: fullRoot.filter
                            focus: true
                            activeFocusOnTab: plasmoid.configuration.KeyboardNavigation
                            KeyNavigation.tab: plasmoid.configuration.KeyboardNavigation ? pasteField : null

                            KeyNavigation.backtab: plasmoid.configuration.KeyboardNavigation ? (fullRoot.selectedCategory === fullRoot.catEmojiKitchen ? kitchenGridView : allEmojisView) : null
                            onTextChanged: {
                                fullRoot.filter = text;
                            }

                            onActiveFocusChanged: {
                                if (!activeFocus && emojiGridView && typeof emojiGridView.cancelExternalFeedback === "function") {
                                    emojiGridView.cancelExternalFeedback();
                                }
                            }

                            Keys.onReturnPressed: {
                                if (!plasmoid.configuration.KeyboardNavigation)
                                return;
                                if (fullRoot.selectedCategory === fullRoot.catGifs) {
                                    if (fullRoot.hoveredGifUrl && typeof gifView !== "undefined" && gifView) {
                                        gifView.copyGif(fullRoot.hoveredGifUrl, fullRoot.hoveredGifTitle);
                                        if (plasmoid.configuration.CloseAfterSelection) {
                                            if (fullRoot.plasmoidItem)
                                            fullRoot.plasmoidItem.expanded = false;
                                        }
                                        searchField.text = "";
                                    }
                                    return;
                                }

                                if (fullRoot.selectedEmojis.length > 0) {
                                    const combined = fullRoot.selectedEmojis.join("");
                                    clipboard.content = combined;
                                    fullRoot.showCopiedFeedback(combined, fullRoot.selectedEmojis.length + " emojis");
                                    fullRoot.selectedEmojis = [];
                                    fullRoot.selectedEmojiSet = ({});

                                    if (plasmoid.configuration.CloseAfterSelection) {
                                        if (fullRoot.plasmoidItem)
                                        fullRoot.plasmoidItem.expanded = false;
                                    }
                                    searchField.text = "";
                                    return;
                                }

                                const isShift = (event.modifiers & Qt.ShiftModifier);

                                if (fullRoot.emojiHoveredEmojiKey) {
                                    const hoveredEmojiObj = fullRoot.filteredEmojis.find(e => e.emoji === fullRoot.emojiHoveredEmojiKey) || {
                                        emoji: fullRoot.emojiHoveredEmojiKey,
                                        name: fullRoot.hoveredEmojiName,
                                        slug: "",
                                        group: ""
                                    };

                                    if (emojiGridView && typeof emojiGridView.triggerExternalFeedback === "function") {
                                        var idx = fullRoot.emojiIndexForEmojiKey(fullRoot.emojiHoveredEmojiKey);
                                        if (idx >= 0) {
                                            emojiGridView.currentIndex = idx;
                                            emojiGridView.triggerExternalFeedback();
                                        }
                                    }

                                    if (isShift) {
                                        clipboard.content = hoveredEmojiObj.name;
                                        addRecentEmoji(hoveredEmojiObj);
                                        showCopiedFeedback(hoveredEmojiObj.name, hoveredEmojiObj.emoji);
                                    } else {
                                        clipboard.content = fullRoot.emojiHoveredEmojiKey;
                                        addRecentEmoji(hoveredEmojiObj);
                                        showCopiedFeedback(fullRoot.emojiHoveredEmojiKey, fullRoot.hoveredEmojiName);
                                    }
                                    searchField.text = "";
                                } else if (fullRoot.filteredEmojis.length > 0) {
                                    const firstEmoji = fullRoot.filteredEmojis[0];

                                    if (emojiGridView && typeof emojiGridView.triggerExternalFeedback === "function") {
                                        if (emojiGridView.count > 0) {
                                            emojiGridView.currentIndex = 0;
                                            emojiGridView.triggerExternalFeedback();
                                        }
                                    }

                                    if (isShift) {
                                        clipboard.content = firstEmoji.name;
                                        addRecentEmoji(firstEmoji);
                                        showCopiedFeedback(firstEmoji.name, "");
                                    } else {
                                        clipboard.content = firstEmoji.emoji;
                                        addRecentEmoji(firstEmoji);
                                        showCopiedFeedback(firstEmoji.emoji, firstEmoji.name);
                                    }
                                    searchField.text = "";
                                }
                            }

                            Keys.onReleased: function (event) {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (emojiGridView && typeof emojiGridView.cancelExternalFeedback === "function") {
                                        emojiGridView.cancelExternalFeedback();
                                    }
                                }
                            }

                            Keys.onPressed: function (event) {
                                if (plasmoid.configuration.KeyboardNavigation && event.key === Qt.Key_Escape) {
                                    handleEscapePressed();
                                    event.accepted = true;
                                } else if (!plasmoid.configuration.KeyboardNavigation && (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                    if (event.key === Qt.Key_Escape) {
                                        handleEscapePressed();
                                    }
                                    event.accepted = true;
                                    return;
                                }
                            }
                        }

                        PlasmaExtras.ActionTextField {
                            id: pasteField
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            placeholderText: fullRoot.defaultPastePlaceholder
                            activeFocusOnTab: plasmoid.configuration.KeyboardNavigation
                            KeyNavigation.tab: plasmoid.configuration.KeyboardNavigation ? pinButton : null
                            KeyNavigation.backtab: plasmoid.configuration.KeyboardNavigation ? searchField : null

                            onActiveFocusChanged: {
                                if (!activeFocus && emojiGridView && typeof emojiGridView.cancelExternalFeedback === "function") {
                                    emojiGridView.cancelExternalFeedback();
                                }
                            }

                            leftActions: [
                                Action {
                                    icon.name: "edit-paste"
                                    enabled: false
                                }
                            ]

                            Keys.onReleased: function (event) {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (emojiGridView && typeof emojiGridView.cancelExternalFeedback === "function") {
                                        emojiGridView.cancelExternalFeedback();
                                    }
                                }
                            }

                            Keys.onPressed: function (event) {
                                if (plasmoid.configuration.KeyboardNavigation && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                    const isShift = event.modifiers & Qt.ShiftModifier;

                                    if (fullRoot.selectedEmojis.length > 0) {
                                        const combined = fullRoot.selectedEmojis.join("");
                                        clipboard.content = combined;
                                        fullRoot.showCopiedFeedback(combined, fullRoot.selectedEmojis.length + " emojis");
                                        fullRoot.selectedEmojis = [];
                                        fullRoot.selectedEmojiSet = ({});

                                        if (plasmoid.configuration.CloseAfterSelection) {
                                            if (fullRoot.plasmoidItem)
                                            fullRoot.plasmoidItem.expanded = false;
                                        }
                                        event.accepted = true;
                                    } else if (fullRoot.emojiHoveredEmojiKey) {
                                        const hoveredEmojiObj = fullRoot.filteredEmojis.find(e => e.emoji === fullRoot.emojiHoveredEmojiKey) || {
                                            emoji: fullRoot.emojiHoveredEmojiKey,
                                            name: fullRoot.hoveredEmojiName,
                                            slug: "",
                                            group: ""
                                        };

                                        if (emojiGridView && typeof emojiGridView.triggerExternalFeedback === "function") {
                                            var idx = fullRoot.emojiIndexForEmojiKey(fullRoot.emojiHoveredEmojiKey);
                                            if (idx >= 0) {
                                                emojiGridView.currentIndex = idx;
                                                emojiGridView.triggerExternalFeedback();
                                            }
                                        }

                                        if (isShift) {
                                            clipboard.content = hoveredEmojiObj.name;
                                            addRecentEmoji(hoveredEmojiObj);
                                            showCopiedFeedback(hoveredEmojiObj.name, hoveredEmojiObj.emoji);
                                        } else {
                                            clipboard.content = fullRoot.emojiHoveredEmojiKey;
                                            addRecentEmoji(hoveredEmojiObj);
                                            showCopiedFeedback(fullRoot.emojiHoveredEmojiKey, fullRoot.hoveredEmojiName);
                                        }
                                        event.accepted = true;
                                    }
                                } else if (plasmoid.configuration.KeyboardNavigation && event.key === Qt.Key_Escape) {
                                    if (fullRoot.plasmoidItem)
                                    fullRoot.plasmoidItem.expanded = false;
                                    event.accepted = true;
                                } else if (!plasmoid.configuration.KeyboardNavigation && (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                    event.accepted = true;
                                    return;
                                }
                            }
                        }
                    }
                }

                Kirigami.Separator {

                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Item {
                        Layout.fillHeight: true
                        Layout.preferredWidth: fullRoot.sidebarExpanded ? 180 : 32
                        Layout.maximumWidth: 180
                        Kirigami.Theme.colorSet: Kirigami.Theme.Window
                        Kirigami.Theme.inherit: false

                        Item {
                            anchors.fill: parent

                            PlasmaComponents.ToolButton {
                                id: pinButton
                                implicitWidth: fullRoot.sidebarExpanded ? 180 : 32
                                implicitHeight: 32
                                x: 0
                                y: 0
                                focusPolicy: Qt.StrongFocus
                                activeFocusOnTab: plasmoid.configuration.KeyboardNavigation
                                KeyNavigation.tab: plasmoid.configuration.KeyboardNavigation ? settingsButtonInSidebar : null
                                KeyNavigation.backtab: plasmoid.configuration.KeyboardNavigation ? pasteField : null

                                Timer {
                                    id: pinKeyboardFeedbackReset
                                    interval: 120
                                    repeat: false
                                    running: false
                                    onTriggered: fullRoot.pinButtonKeyboardPressed = false
                                }

                                onClicked: {
                                    plasmoid.configuration.AlwaysOpen = !plasmoid.configuration.AlwaysOpen;
                                    if (!plasmoid.configuration.KeyboardNavigation) {
                                        activeFocus = false;
                                    }
                                }

                                Keys.onPressed: function (event) {
                                    if (!plasmoid.configuration.KeyboardNavigation)
                                    return;
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        fullRoot.pinButtonKeyboardPressed = true;
                                        pinKeyboardFeedbackReset.restart();
                                        plasmoid.configuration.AlwaysOpen = !plasmoid.configuration.AlwaysOpen;
                                        event.accepted = true;
                                    }
                                }

                                Keys.onReleased: function (event) {
                                    if (plasmoid.configuration.KeyboardNavigation && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                        fullRoot.pinButtonKeyboardPressed = false;
                                        pinKeyboardFeedbackReset.stop();
                                        event.accepted = true;
                                    }
                                }

                                MouseArea {
                                    id: pinArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: {
                                        if (mouse.button === Qt.LeftButton) {
                                            plasmoid.configuration.AlwaysOpen = !plasmoid.configuration.AlwaysOpen;
                                            if (!plasmoid.configuration.KeyboardNavigation) {
                                                parent.activeFocus = false;
                                            }
                                        }
                                    }
                                    onExited: {
                                        if (!plasmoid.configuration.KeyboardNavigation) {
                                            parent.activeFocus = false;
                                        }
                                    }
                                }

                                background: Item {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Kirigami.Theme.highlightColor
                                        radius: 4
                                        opacity: (pinArea.pressed || fullRoot.pinButtonKeyboardPressed) ? 1.0 : (((pinArea.containsMouse) || pinButton.activeFocus) ? 0.2 : 0)
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        radius: 4
                                        border.width: ((pinArea.containsMouse) || pinButton.activeFocus) ? 2 : 0
                                        border.color: Kirigami.Theme.highlightColor
                                    }
                                }

                                contentItem: Item {
                                    Kirigami.Icon {
                                        x: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: plasmoid.configuration.AlwaysOpen ? "window-unpin-symbolic" : "window-pin-symbolic"
                                        width: Kirigami.Units.iconSizes.smallMedium + 2
                                        height: Kirigami.Units.iconSizes.smallMedium + 2
                                        color: Kirigami.Theme.textColor
                                        visible: !fullRoot.sidebarExpanded
                                    }

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 4
                                        visible: fullRoot.sidebarExpanded
                                        spacing: 6

                                        Kirigami.Icon {
                                            source: plasmoid.configuration.AlwaysOpen ? "window-unpin-symbolic" : "window-pin-symbolic"
                                            width: Kirigami.Units.iconSizes.smallMedium + 2
                                            height: Kirigami.Units.iconSizes.smallMedium + 2
                                            color: Kirigami.Theme.textColor
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: plasmoid.configuration.AlwaysOpen ? i18n("Unpin Popup") : i18n("Pin Popup")
                                            color: Kirigami.Theme.textColor
                                            font.bold: false
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                                PlasmaComponents.ToolTip {
                                    text: fullRoot.sidebarExpanded ? "" : (plasmoid.configuration.AlwaysOpen ? i18n("Unpin Popup") : i18n("Pin Popup"))
                                }
                            }

                            PlasmaComponents.ToolButton {
                                id: settingsButtonInSidebar
                                implicitWidth: fullRoot.sidebarExpanded ? 180 : 32
                                implicitHeight: 32
                                x: 0
                                y: 32
                                focusPolicy: Qt.StrongFocus
                                activeFocusOnTab: plasmoid.configuration.KeyboardNavigation
                                KeyNavigation.tab: plasmoid.configuration.KeyboardNavigation ? sidebarToggleButton : null
                                KeyNavigation.backtab: plasmoid.configuration.KeyboardNavigation ? pinButton : null

                                Timer {
                                    id: settingsKeyboardFeedbackReset
                                    interval: 120
                                    repeat: false
                                    running: false
                                    onTriggered: fullRoot.settingsButtonKeyboardPressed = false
                                }

                                Timer {
                                    id: openSettingsTimer
                                    interval: 50
                                    repeat: false
                                    running: false
                                    onTriggered: fullRoot.openConfigurationDialog()
                                }

                                onClicked: fullRoot.openConfigurationDialog()

                                Keys.onPressed: function (event) {
                                    if (!plasmoid.configuration.KeyboardNavigation)
                                    return;
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        fullRoot.settingsButtonKeyboardPressed = true;
                                        settingsKeyboardFeedbackReset.restart();
                                        openSettingsTimer.restart();
                                        event.accepted = true;
                                    }
                                }

                                Keys.onReleased: function (event) {
                                    if (plasmoid.configuration.KeyboardNavigation && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                        fullRoot.settingsButtonKeyboardPressed = false;
                                        settingsKeyboardFeedbackReset.stop();
                                        event.accepted = true;
                                    }
                                }

                                MouseArea {
                                    id: settingsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: {
                                        if (mouse.button === Qt.LeftButton) {
                                            fullRoot.openConfigurationDialog();
                                            if (!plasmoid.configuration.KeyboardNavigation) {
                                                parent.activeFocus = false;
                                            }
                                        }
                                    }
                                    onExited: {
                                        if (!plasmoid.configuration.KeyboardNavigation) {
                                            parent.activeFocus = false;
                                        }
                                    }
                                }

                                background: Item {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Kirigami.Theme.highlightColor
                                        radius: 4
                                        opacity: (settingsArea.pressed || fullRoot.settingsButtonKeyboardPressed) ? 1.0 : (((settingsArea.containsMouse) || settingsButtonInSidebar.activeFocus) ? 0.2 : 0)
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        radius: 4
                                        border.width: ((settingsArea.containsMouse) || settingsButtonInSidebar.activeFocus) ? 2 : 0
                                        border.color: Kirigami.Theme.highlightColor
                                    }
                                }

                                contentItem: Item {
                                    Kirigami.Icon {
                                        x: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: "configure"
                                        width: Kirigami.Units.iconSizes.smallMedium + 2
                                        height: Kirigami.Units.iconSizes.smallMedium + 2
                                        color: Kirigami.Theme.textColor
                                        visible: !fullRoot.sidebarExpanded
                                    }

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 4
                                        visible: fullRoot.sidebarExpanded
                                        spacing: 6

                                        Kirigami.Icon {
                                            source: "configure"
                                            width: Kirigami.Units.iconSizes.smallMedium + 2
                                            height: Kirigami.Units.iconSizes.smallMedium + 2
                                            color: Kirigami.Theme.textColor
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: i18n("Configure Settings")
                                            color: Kirigami.Theme.textColor
                                            font.bold: false
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                                PlasmaComponents.ToolTip {
                                    text: fullRoot.sidebarExpanded ? "" : i18n("Configure Settings...")
                                }
                            }

                            PlasmaComponents.ToolButton {
                                id: sidebarToggleButton
                                implicitWidth: fullRoot.sidebarExpanded ? 180 : 32
                                implicitHeight: 32
                                x: 0
                                y: 64
                                focusPolicy: Qt.StrongFocus
                                activeFocusOnTab: plasmoid.configuration.KeyboardNavigation
                                KeyNavigation.backtab: plasmoid.configuration.KeyboardNavigation ? settingsButtonInSidebar : null
                                KeyNavigation.tab: plasmoid.configuration.KeyboardNavigation ? (categoryListView.count > 0 ? (categoryListView.itemAtIndex(0) ? categoryListView.itemAtIndex(0) : (fullRoot.selectedCategory === fullRoot.catEmojiKitchen ? kitchenView.kitchenGridView : allEmojisView)) : (fullRoot.selectedCategory === fullRoot.catEmojiKitchen ? kitchenView.kitchenGridView : allEmojisView)) : null

                                onClicked: {
                                    fullRoot.sidebarExpanded = !fullRoot.sidebarExpanded;
                                    if (!plasmoid.configuration.KeyboardNavigation) {
                                        activeFocus = false;
                                    }
                                }

                                Keys.onPressed: function (event) {
                                    if (!plasmoid.configuration.KeyboardNavigation)
                                    return;
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        fullRoot.sidebarButtonKeyboardPressed = true;
                                        fullRoot.sidebarExpanded = !fullRoot.sidebarExpanded;
                                        event.accepted = true;
                                    }
                                }

                                Keys.onReleased: function (event) {
                                    if (plasmoid.configuration.KeyboardNavigation && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                        fullRoot.sidebarButtonKeyboardPressed = false;
                                        event.accepted = true;
                                    }
                                }

                                MouseArea {
                                    id: sidebarToggleArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: {
                                        if (mouse.button === Qt.LeftButton) {
                                            fullRoot.sidebarExpanded = !fullRoot.sidebarExpanded;
                                            if (!plasmoid.configuration.KeyboardNavigation) {
                                                parent.activeFocus = false;
                                            }
                                        }
                                    }
                                    onExited: {
                                        if (!plasmoid.configuration.KeyboardNavigation) {
                                            parent.activeFocus = false;
                                        }
                                    }
                                }

                                background: Item {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Kirigami.Theme.highlightColor
                                        radius: 4
                                        opacity: (sidebarToggleArea.pressed || fullRoot.sidebarButtonKeyboardPressed) ? 1.0 : (((sidebarToggleArea.containsMouse) || sidebarToggleButton.activeFocus) ? 0.2 : 0)
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        radius: 4
                                        border.width: ((sidebarToggleArea.containsMouse) || sidebarToggleButton.activeFocus) ? 2 : 0
                                        border.color: Kirigami.Theme.highlightColor
                                    }
                                }

                                contentItem: Item {
                                    Kirigami.Icon {
                                        x: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: "sidebar-expand"
                                        width: Kirigami.Units.iconSizes.smallMedium + 2
                                        height: Kirigami.Units.iconSizes.smallMedium + 2
                                        color: Kirigami.Theme.textColor
                                        visible: !fullRoot.sidebarExpanded
                                    }

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 4
                                        visible: fullRoot.sidebarExpanded
                                        spacing: 6

                                        Kirigami.Icon {
                                            source: "sidebar-collapse"
                                            width: Kirigami.Units.iconSizes.smallMedium + 2
                                            height: Kirigami.Units.iconSizes.smallMedium + 2
                                            color: Kirigami.Theme.textColor
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: i18n("Close Sidebar")
                                            color: Kirigami.Theme.textColor
                                            font.bold: false
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                                PlasmaComponents.ToolTip {
                                    text: fullRoot.sidebarExpanded ? "" : i18n("Open Sidebar")
                                }
                            }

                            ListView {
                                id: categoryListView
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.topMargin: 96
                                clip: true

                                model: categoryModel
                                spacing: 2
                                boundsBehavior: Flickable.StopAtBounds

                                ScrollBar.vertical: ScrollBar {
                                    active: categoryListView.moving || categoryListView.contentHeight > categoryListView.height
                                }

                                displaced: Transition {
                                    NumberAnimation {
                                        properties: "x,y"
                                        duration: 100
                                    }
                                }

                                delegate: PlasmaComponents.ToolButton {
                                    id: categoryButton
                                    width: categoryListView.width
                                    implicitHeight: 32

                                    focusPolicy: Qt.StrongFocus
                                    activeFocusOnTab: plasmoid.configuration.KeyboardNavigation

                                    KeyNavigation.tab: plasmoid.configuration.KeyboardNavigation ? (index + 1 < categoryListView.count ? (categoryListView.itemAtIndex(index + 1) ? categoryListView.itemAtIndex(index + 1) : (fullRoot.selectedCategory === fullRoot.catEmojiKitchen ? slot1 : (fullRoot.selectedCategory === fullRoot.catEmojiKitchen ? kitchenView.kitchenGridView : allEmojisView))) : (fullRoot.selectedCategory === fullRoot.catEmojiKitchen ? slot1 : (fullRoot.selectedCategory === fullRoot.catEmojiKitchen ? kitchenView.kitchenGridView : allEmojisView))) : null
                                    KeyNavigation.backtab: plasmoid.configuration.KeyboardNavigation ? (index === 0 ? sidebarToggleButton : (categoryListView.itemAtIndex(index - 1) ? categoryListView.itemAtIndex(index - 1) : sidebarToggleButton)) : null

                                    Keys.onReturnPressed: clicked()
                                    Keys.onEnterPressed: clicked()

                                    opacity: fullRoot.draggedCategoryIndex === index ? 0.3 : 1.0

                                    background: Item {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        Rectangle {
                                            anchors.fill: parent
                                            color: Kirigami.Theme.highlightColor
                                            radius: 4
                                            opacity: (fullRoot.selectedCategory === model.name || fullRoot.draggedCategoryIndex === index || dragArea.pressed) ? 1.0 : (((dragArea.containsMouse && fullRoot.selectedCategory !== model.name && !fullRoot.isAnyCategoryDragging) || categoryButton.activeFocus) ? 0.2 : 0)
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            radius: 4
                                            border.width: ((fullRoot.selectedCategory === model.name || dragArea.pressed || fullRoot.draggedCategoryIndex === index) || (dragArea.containsMouse && fullRoot.selectedCategory !== model.name && !fullRoot.isAnyCategoryDragging) || categoryButton.activeFocus) ? 2 : 0
                                            border.color: Kirigami.Theme.highlightColor
                                        }
                                    }

                                    contentItem: Item {
                                        Kirigami.Icon {
                                            x: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            source: model.icon
                                            width: Kirigami.Units.iconSizes.smallMedium + 2
                                            height: Kirigami.Units.iconSizes.smallMedium + 2
                                            color: fullRoot.selectedCategory === model.name ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                            visible: !fullRoot.sidebarExpanded
                                        }

                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.leftMargin: 4
                                            visible: fullRoot.sidebarExpanded
                                            spacing: 6

                                            Kirigami.Icon {
                                                source: model.icon
                                                width: Kirigami.Units.iconSizes.smallMedium + 2
                                                height: Kirigami.Units.iconSizes.smallMedium + 2
                                                color: fullRoot.selectedCategory === model.name ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: model.displayName
                                                color: fullRoot.selectedCategory === model.name ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                                font.bold: false
                                                anchors.verticalCenter: parent.verticalCenter
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    PlasmaComponents.ToolTip {
                                        text: fullRoot.sidebarExpanded ? "" : model.displayName
                                    }

                                    onClicked: fullRoot.selectedCategory = model.name

                                    MouseArea {
                                        id: dragArea
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        hoverEnabled: true
                                        cursorShape: fullRoot.draggedCategoryIndex === index ? Qt.ClosedHandCursor : Qt.ArrowCursor
                                        onPressAndHold: function (mouse) {
                                            if (mouse.button === Qt.LeftButton) {
                                                fullRoot.draggedCategoryIndex = index;
                                                fullRoot.isAnyCategoryDragging = true;
                                            }
                                        }

                                        onPositionChanged: {
                                            if (fullRoot.draggedCategoryIndex === index) {
                                                var globalPos = mapToItem(categoryListView, mouseX, mouseY);
                                                var targetIndex = categoryListView.indexAt(10, globalPos.y + categoryListView.contentY);
                                                if (targetIndex !== -1 && targetIndex !== index) {
                                                    categoryModel.move(index, targetIndex, 1);
                                                    fullRoot.draggedCategoryIndex = targetIndex;
                                                }
                                            }
                                        }

                                        onReleased: {
                                            if (fullRoot.draggedCategoryIndex === index) {
                                                fullRoot.draggedCategoryIndex = -1;
                                                fullRoot.saveCategoryOrder();
                                                fullRoot.isAnyCategoryDragging = false;
                                            }
                                        }

                                        onCanceled: {
                                            if (fullRoot.draggedCategoryIndex === index) {
                                                fullRoot.draggedCategoryIndex = -1;
                                                fullRoot.isAnyCategoryDragging = false;
                                            }
                                        }

                                        onClicked: {
                                            if (mouse.button === Qt.RightButton) {
                                                var globalPos = mapToItem(fullRoot, mouse.x, mouse.y);
                                                if (model.name === fullRoot.catGifs) {
                                                    gifSidebarContextMenu.popup(globalPos.x, globalPos.y);
                                                } else {
                                                    emojiSidebarContextMenu.popup(globalPos.x, globalPos.y);
                                                }
                                                mouse.accepted = true;
                                            } else if (fullRoot.draggedCategoryIndex !== index) {
                                                fullRoot.selectedCategory = model.name;
                                                if (model.name !== fullRoot.catGifs && model.name !== fullRoot.catEmojiKitchen) {
                                                    if (typeof allEmojisView !== "undefined") {
                                                        allEmojisView.scrollToCategory(model.name);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Kirigami.Separator {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                    }

                    Item {
                        id: emojiArea
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        Kirigami.Theme.colorSet: Kirigami.Theme.Window
                        Kirigami.Theme.inherit: false

                        Item {
                            id: gifView
                            anchors.fill: parent
                            visible: fullRoot.selectedCategory === fullRoot.catGifs
                            clip: true

                            property bool isLoading: false
                            property bool isLoadingMore: false
                            property int currentPage: 1
                            property bool hasNextPage: false
                            property string lastQuery: ""
                            property string apiErrorMsg: ""

                            ListModel {
                                id: gifCol0Model
                            }
                            ListModel {
                                id: gifCol1Model
                            }
                            ListModel {
                                id: gifCol2Model
                            }
                            ListModel {
                                id: gifCol3Model
                            }
                            property var colModels: [gifCol0Model, gifCol1Model, gifCol2Model, gifCol3Model]
                            property var rawGifsList: []
                            property int gifCol0Height: 0
                            property int gifCol1Height: 0
                            property int gifCol2Height: 0
                            property int gifCol3Height: 0

                            Connections {
                                target: plasmoid.configuration
                                function onGifSizeChanged() {
                                    redistributeTimer.restart();
                                }
                            }

                            onWidthChanged: {
                                redistributeTimer.restart();
                            }

                            Timer {
                                id: redistributeTimer
                                interval: 100
                                repeat: false
                                onTriggered: {
                                    if (gifView.visible) {
                                        gifView.redistributeGifs();
                                    }
                                }
                            }

                            Plasma5Support.DataSource {
                                id: gifShellSource
                                engine: "executable"
                                connectedSources: []
                                onNewData: (source, data) => {
                                    disconnectSource(source);
                                }
                            }

                            onVisibleChanged: {
                                if (visible) {
                                    gifView.fetchGifs(fullRoot.filter, false);
                                } else {
                                    fullRoot.hoveredGifTitle = "";
                                    fullRoot.hoveredGifUrl = "";
                                }
                            }

                            Connections {
                                target: fullRoot
                                function onFilterChanged() {
                                    if (fullRoot.selectedCategory === fullRoot.catGifs) {
                                        gifSearchTimer.restart();
                                    }
                                }
                            }

                            Timer {
                                id: gifSearchTimer
                                interval: 500
                                repeat: false
                                running: false
                                onTriggered: {
                                    gifView.fetchGifs(fullRoot.filter, false);
                                }
                            }

                            function _processMasonryItems(items, initialHeights) {
                                var numCols = masonryRow.numColumns;
                                var colWidth = masonryRow.columnWidth;
                                var space = masonryRow.spacing;
                                var colHeights = initialHeights;

                                for (var i = 0; i < items.length; i++) {
                                    var item = items[i];

                                    var minCol = 0;
                                    var minHeight = colHeights[0];
                                    for (var c = 1; c < numCols; c++) {
                                        if (colHeights[c] < minHeight) {
                                            minHeight = colHeights[c];
                                            minCol = c;
                                        }
                                    }

                                    colModels[minCol].append({
                                        title: item.title,
                                        rawUrl: item.rawUrl,
                                        previewUrl: item.previewUrl,
                                        aspectRatio: item.aspectRatio
                                    });

                                    var cardHeight = Math.floor(colWidth / item.aspectRatio);
                                    colHeights[minCol] += cardHeight + space;
                                }

                                gifCol0Height = colHeights[0];
                                gifCol1Height = colHeights[1];
                                gifCol2Height = colHeights[2];
                                gifCol3Height = colHeights[3];
                            }

                            function redistributeGifs() {
                                gifCol0Model.clear();
                                gifCol1Model.clear();
                                gifCol2Model.clear();
                                gifCol3Model.clear();
                                _processMasonryItems(rawGifsList, [0, 0, 0, 0]);
                            }

                            function appendToColumns(newItems) {
                                _processMasonryItems(newItems, [gifCol0Height, gifCol1Height, gifCol2Height, gifCol3Height]);
                            }

                            function fetchGifs(query, append) {
                                gifView.apiErrorMsg = "";
                                if (!append) {
                                    gifView.currentPage = 1;
                                    gifView.hasNextPage = false;
                                    gifView.lastQuery = query || "";
                                    gifView.isLoading = true;
                                } else {
                                    gifView.isLoadingMore = true;
                                }

                                var page = append ? gifView.currentPage : 1;
                                var url = root.buildGifUrl(plasmoid.configuration.KlipyApiKey, query, page, 24);

                                var xhr = new XMLHttpRequest();
                                xhr.open("GET", url);
                                xhr.onreadystatechange = function () {
                                    if (xhr.readyState === XMLHttpRequest.DONE) {
                                        gifView.isLoading = false;
                                        gifView.isLoadingMore = false;
                                        if (xhr.status === 200) {
                                            var response = JSON.parse(xhr.responseText);
                                            var responseData = response && response.data ? response.data : null;
                                            if (!responseData) {
                                                console.log("ERROR: Klipy API returned an unexpected payload");
                                                return;
                                            }

                                            var parsed = root.parseGifItems(response);

                                            if (append) {
                                                rawGifsList = rawGifsList.concat(parsed);
                                                appendToColumns(parsed);
                                            } else {
                                                rawGifsList = parsed;
                                                redistributeGifs();
                                            }

                                            gifView.hasNextPage = responseData.has_next === true;
                                            gifView.currentPage = (responseData.current_page || page) + 1;
                                        } else {
                                            console.log("ERROR: Klipy API returned status: " + xhr.status);
                                            try {
                                                var errResponse = JSON.parse(xhr.responseText);
                                                if (errResponse.errors && errResponse.errors.message && errResponse.errors.message.length > 0) {
                                                    var msg = errResponse.errors.message[0];
                                                    if (msg.indexOf("API key is invalid") !== -1) {
                                                        gifView.apiErrorMsg = i18n("Invalid Klipy API Key. Get a new key from partner.klipy.com and update it in Settings.");
                                                    } else {
                                                        gifView.apiErrorMsg = msg;
                                                    }
                                                } else {
                                                    gifView.apiErrorMsg = i18n("Klipy API Error: %1", xhr.status);
                                                }
                                            } catch (e) {
                                                gifView.apiErrorMsg = i18n("Klipy API Error: %1", xhr.status);
                                            }
                                        }
                                    }
                                };
                                xhr.send();
                            }

                            function fetchMoreGifs() {
                                if (gifView.isLoadingMore || gifView.isLoading || !gifView.hasNextPage)
                                return;
                                gifView.fetchGifs(gifView.lastQuery, true);
                            }

                            function copyGif(gifUrl, title, webpUrl, previewUrl, aspectRatio) {
                                if (!gifUrl)
                                return;

                                clipboard.content = gifUrl;
                                fullRoot.showPasteTemporaryMessage(i18n("Copied: %1", title));

                                fullRoot.addRecentItem("gif", {
                                    rawUrl: gifUrl,
                                    title: title,
                                    webpUrl: webpUrl || gifUrl,
                                    previewUrl: previewUrl || gifUrl,
                                    aspectRatio: aspectRatio || 1.0
                                });
                            }

                            PlasmaComponents.BusyIndicator {
                                id: gifLoadingIndicator
                                anchors.centerIn: parent
                                running: gifView.isLoading || gifSearchTimer.running
                                visible: running
                            }

                            PlasmaComponents.Label {
                                anchors.centerIn: parent
                                text: gifView.apiErrorMsg !== "" ? gifView.apiErrorMsg : (fullRoot.filter !== "" ? i18n("No GIFs found :(") : i18n("No internet or Klipy API error"))
                                visible: !gifView.isLoading && !gifSearchTimer.running && gifCol0Model.count === 0 && gifCol1Model.count === 0 && gifCol2Model.count === 0 && gifCol3Model.count === 0
                                font.pixelSize: fullRoot.fontSizeEmptyLabel
                                opacity: 0.6
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                width: Math.min(implicitWidth, parent.width - 40)
                            }

                            Component {
                                id: gifDelegate

                                PC3.ItemDelegate {
                                    id: delegateItem
                                    property var itemData: {
                                        if (typeof modelData !== "undefined" && modelData) return modelData;
                                        if (typeof model !== "undefined" && model) return model;
                                        return {};
                                    }
                                    width: masonryRow.columnWidth
                                    height: Math.floor(width / (itemData.aspectRatio || 1.0))

                                    readonly property bool inView: {
                                        if (!fullRoot.isWidgetExpanded)
                                        return false;
                                        if (typeof gifFlickable === "undefined" || !gifFlickable || !gifFlickable.contentItem)
                                        return false;
                                        if (!delegateItem.parent)
                                        return false;
                                        var dummy = gifFlickable.contentItem.contentY + gifFlickable.height + gifFlickable.contentHeight;
                                        var absPos = delegateItem.mapToItem(gifFlickable.contentItem.contentItem, 0, 0);
                                        var absY = absPos ? absPos.y : 0;
                                        return (absY + height >= gifFlickable.contentItem.contentY - 200) && (absY <= gifFlickable.contentItem.contentY + gifFlickable.height + 200);
                                    }

                                    onClicked: {
                                        gifView.copyGif(itemData.rawUrl, itemData.title, itemData.webpUrl, itemData.previewUrl, itemData.aspectRatio);
                                        if (plasmoid.configuration.CloseAfterSelection) {
                                            if (fullRoot.plasmoidItem)
                                            fullRoot.plasmoidItem.expanded = false;
                                        }
                                    }

                                    HoverHandler {
                                        id: gifDelegateHover
                                        cursorShape: Qt.PointingHandCursor
                                        onHoveredChanged: {
                                            if (hovered) {
                                                fullRoot.hoveredGifTitle = itemData.title;
                                                fullRoot.hoveredGifUrl = itemData.previewUrl;
                                            } else {
                                                if (fullRoot.hoveredGifUrl === itemData.previewUrl) {
                                                    fullRoot.hoveredGifTitle = "";
                                                    fullRoot.hoveredGifUrl = "";
                                                }
                                            }
                                        }
                                    }

                                    PlasmaComponents.ToolButton {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 6
                                        icon.name: fullRoot.isFavoriteItem("gif", {
                                            rawUrl: itemData.rawUrl
                                        }) ? "bookmarks-bookmarked" : "bookmarks"
                                        visible: gifDelegateHover.hovered
                                        width: 28
                                        height: 28
                                        display: PlasmaComponents.ToolButton.IconOnly
                                        z: 10
                                        background: Rectangle {
                                            color: parent.pressed ? Kirigami.Theme.highlightColor : (parent.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.35) : Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.85))
                                            radius: 4
                                            border.color: (parent.pressed || parent.hovered) ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                                            border.width: 1
                                        }

                                        onClicked: {
                                            fullRoot.toggleFavoriteItem("gif", {
                                                rawUrl: itemData.rawUrl,
                                                title: itemData.title,
                                                webpUrl: itemData.webpUrl || itemData.rawUrl,
                                                previewUrl: itemData.previewUrl,
                                                aspectRatio: itemData.aspectRatio
                                            });
                                        }
                                    }

                                    background: Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        color: Kirigami.Theme.alternateBackgroundColor
                                        radius: 6
                                        border.width: gifDelegateHover.hovered ? 2 : 0
                                        border.color: Kirigami.Theme.highlightColor

                                        AnimatedImage {
                                            id: gifImage
                                            source: delegateItem.inView ? itemData.previewUrl : ""
                                            anchors.fill: parent
                                            anchors.margins: gifDelegateHover.hovered ? 1 : 2
                                            fillMode: Image.Stretch
                                            playing: alwaysAnimateGifs || gifDelegateHover.hovered
                                            paused: !playing
                                            cache: true
                                        }
                                    }
                                }
                            }

                            ScrollView {
                                id: gifFlickable
                                anchors.fill: parent
                                anchors.leftMargin: 0
                                anchors.topMargin: 0
                                anchors.bottomMargin: 0
                                anchors.rightMargin: 0
                                clip: true
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                readonly property var activeStickyInfo: {
                                    if (!gifView.visible || !contentItem) return null;
                                    let currentY = contentItem.contentY;
                                    
                                    let items = [];
                                    if (typeof gifCategoriesRepeater !== "undefined" && gifCategoriesRepeater) {
                                        for (let i = 0; i < gifCategoriesRepeater.count; i++) {
                                            let item = gifCategoriesRepeater.itemAt(i);
                                            if (item && item.visible) {
                                                items.push({
                                                    name: item.catName,
                                                    item: item,
                                                    y: item.y,
                                                    height: item.height,
                                                    headerHeight: 32,
                                                    isTrending: false
                                                });
                                            }
                                        }
                                    }
                                    if (typeof trendingSection !== "undefined" && trendingSection && trendingSection.visible) {
                                        items.push({
                                            name: "GIFs",
                                            item: trendingSection,
                                            y: trendingSection.y,
                                            height: trendingSection.height,
                                            headerHeight: 32,
                                            isTrending: true
                                        });
                                    }

                                    if (items.length === 0) return null;

                                    let activeIdx = -1;
                                    for (let i = 0; i < items.length; i++) {
                                        if (currentY >= items[i].y) {
                                            activeIdx = i;
                                        }
                                    }

                                    if (activeIdx === -1) return null;

                                    let active = items[activeIdx];
                                    
                                    // Hide if scroll has completely passed the bottom of the active category
                                    if (currentY >= active.y + active.height) {
                                        return null;
                                    }

                                    let nextItem = (activeIdx + 1 < items.length) ? items[activeIdx + 1] : null;
                                    let offset = 0;
                                    if (nextItem && nextItem.y < currentY + active.headerHeight) {
                                        offset = nextItem.y - (currentY + active.headerHeight);
                                    } else if (currentY + active.headerHeight > active.y + active.height) {
                                        offset = (active.y + active.height) - (currentY + active.headerHeight);
                                    }

                                    return {
                                        name: active.name,
                                        item: active.item,
                                        y: active.y,
                                        height: active.height,
                                        isTrending: active.isTrending,
                                        offset: offset,
                                        headerHeight: active.headerHeight
                                    };
                                }
                                visible: !gifView.isLoading && !gifSearchTimer.running && (gifCol0Model.count > 0 || gifCol1Model.count > 0 || gifCol2Model.count > 0 || gifCol3Model.count > 0 || fullRoot.favoriteEmojis.filter(e => e.type === "gif").length > 0 || fullRoot.recentEmojis.filter(e => e.type === "gif").length > 0)

                                Connections {
                                    target: gifFlickable.contentItem
                                    function onContentYChanged() {
                                        if (gifFlickable.contentHeight > gifFlickable.height && gifFlickable.contentItem.contentY >= gifFlickable.contentHeight - gifFlickable.height - 500) {
                                            gifView.fetchMoreGifs();
                                        }
                                    }
                                }


                                Column {
                                    id: gifLayout
                                    width: gifFlickable.width - ((gifFlickable.ScrollBar.vertical && gifFlickable.ScrollBar.vertical.visible) ? gifFlickable.ScrollBar.vertical.width : 0)
                                    spacing: 12

                                    Repeater {
                                        id: gifCategoriesRepeater
                                        model: ["Favorites", "Recent"]
                                        delegate: Column {
                                            id: parentCatLayout
                                            width: parent.width
                                            spacing: 8
                                            property string catName: modelData
                                            property Item headerItem: catHeader
                                            property var catGifs: {
                                                let list = catName === "Favorites" 
                                                    ? fullRoot.favoriteEmojis.filter(e => e.type === "gif")
                                                    : fullRoot.recentEmojis.filter(e => e.type === "gif").slice(0, 36);
                                                
                                                if (fullRoot.filter && fullRoot.filter.trim() !== "") {
                                                    return performFilter(list, fullRoot.filter);
                                                }
                                                return list;
                                            }
                                            visible: catGifs.length > 0

                                            Item {
                                                id: catHeader
                                                width: parent.width
                                                height: 32
                                                property bool isExpanded: true

                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: catHeaderMouse.pressed ? Kirigami.Theme.highlightColor : (catHeaderMouse.containsMouse ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent")
                                                    border.color: (catHeaderMouse.pressed || catHeaderMouse.containsMouse) ? Kirigami.Theme.highlightColor : "transparent"
                                                    border.width: 1
                                                    radius: 4
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 8
                                                    anchors.rightMargin: 8
                                                    spacing: 8

                                                    Item {
                                                        implicitWidth: 16
                                                        implicitHeight: 16
                                                        Kirigami.Icon {
                                                            anchors.centerIn: parent
                                                            source: catHeader.isExpanded ? "go-down" : "go-next"
                                                            width: 16
                                                            height: 16
                                                        }
                                                    }

                                                    PlasmaComponents.Label {
                                                        text: catName === "Favorites" ? i18n("Favorites") : i18n("Recent")
                                                        font.bold: true
                                                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.05
                                                    }

                                                    Rectangle {
                                                        width: catCountLabel.contentWidth + 12
                                                        height: 18
                                                        radius: 9
                                                        color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2)

                                                        PlasmaComponents.Label {
                                                            id: catCountLabel
                                                            anchors.centerIn: parent
                                                            text: catGifs.length
                                                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                            font.bold: true
                                                            color: Kirigami.Theme.textColor
                                                        }
                                                    }

                                                    Rectangle {
                                                        Layout.fillWidth: true
                                                        height: 1
                                                        color: Kirigami.Theme.textColor
                                                        opacity: 0.3
                                                    }
                                                }

                                                MouseArea {
                                                    id: catHeaderMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: function(mouse) {
                                                        if (mouse.button === Qt.LeftButton) {
                                                            catHeader.isExpanded = !catHeader.isExpanded;
                                                        }
                                                    }
                                                }
                                            }

                                            Row {
                                                id: catRow
                                                width: parent.width
                                                spacing: 6
                                                visible: catHeader.isExpanded
                                                
                                                readonly property int numCols: masonryRow.numColumns
                                                readonly property int colWidth: masonryRow.columnWidth

                                                Repeater {
                                                    model: parent.numCols
                                                    delegate: Column {
                                                        spacing: 6
                                                        width: parent.colWidth
                                                        property int colIndex: index
                                                        Repeater {
                                                            property var sourceArray: parentCatLayout.catGifs
                                                            model: {
                                                                let colItems = [];
                                                                let arr = sourceArray;
                                                                let cCols = catRow.numCols;
                                                                let cIdx = colIndex;
                                                                if (!arr || !cCols) return colItems;
                                                                for (let i = 0; i < arr.length; i++) {
                                                                    if (i % cCols === cIdx) colItems.push(arr[i]);
                                                                }
                                                                return colItems;
                                                            }
                                                            delegate: gifDelegate
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        id: trendingSection
                                        width: parent.width
                                        spacing: 8
                                        visible: gifCol0Model.count > 0 || gifCol1Model.count > 0 || gifCol2Model.count > 0 || gifCol3Model.count > 0

                                        Item {
                                            id: trendingHeader
                                            width: parent.width
                                            height: 32
                                            property bool isExpanded: true

                                            Rectangle {
                                                anchors.fill: parent
                                                color: trendingHeaderMouse.pressed ? Kirigami.Theme.highlightColor : (trendingHeaderMouse.containsMouse ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent")
                                                border.color: (trendingHeaderMouse.pressed || trendingHeaderMouse.containsMouse) ? Kirigami.Theme.highlightColor : "transparent"
                                                border.width: 1
                                                radius: 4
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 8

                                                Item {
                                                    implicitWidth: 16
                                                    implicitHeight: 16
                                                    Kirigami.Icon {
                                                        anchors.centerIn: parent
                                                        source: trendingHeader.isExpanded ? "go-down" : "go-next"
                                                        width: 16
                                                        height: 16
                                                    }
                                                }

                                                PlasmaComponents.Label {
                                                    text: fullRoot.filter !== "" ? i18n("Search Results") : i18n("GIFs")
                                                    font.bold: true
                                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.05
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 1
                                                    color: Kirigami.Theme.textColor
                                                    opacity: 0.3
                                                }
                                            }

                                            MouseArea {
                                                id: trendingHeaderMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.LeftButton
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: function(mouse) {
                                                    if (mouse.button === Qt.LeftButton) {
                                                        trendingHeader.isExpanded = !trendingHeader.isExpanded;
                                                    }
                                                }
                                            }
                                        }

                                        Row {
                                            id: masonryRow
                                            width: parent.width
                                            spacing: 6
                                            visible: trendingHeader.isExpanded && (gifCol0Model.count > 0 || gifCol1Model.count > 0 || gifCol2Model.count > 0 || gifCol3Model.count > 0)

                                            readonly property int numColumns: Math.max(2, Math.min(4, Math.floor(width / gifPreferredWidth)))
                                            readonly property int columnWidth: Math.floor((width - (numColumns - 1) * spacing) / numColumns)

                                            Column {
                                                id: col0
                                                spacing: 6
                                                width: masonryRow.columnWidth
                                                property real baseY: parent.y
                                                anchors.top: parent.top

                                                Repeater {
                                                    model: gifCol0Model
                                                    delegate: gifDelegate
                                                }
                                            }

                                            Column {
                                                id: col1
                                                spacing: 6
                                                width: masonryRow.columnWidth
                                                property real baseY: parent.y
                                                anchors.top: parent.top

                                                Repeater {
                                                    model: gifCol1Model
                                                    delegate: gifDelegate
                                                }
                                            }

                                            Column {
                                                id: col2
                                                spacing: 6
                                                width: masonryRow.columnWidth
                                                property real baseY: parent.y
                                                visible: masonryRow.numColumns >= 3
                                                anchors.top: parent.top

                                                Repeater {
                                                    model: gifCol2Model
                                                    delegate: gifDelegate
                                                }
                                            }

                                            Column {
                                                id: col3
                                                spacing: 6
                                                width: masonryRow.columnWidth
                                                property real baseY: parent.y
                                                visible: masonryRow.numColumns >= 4
                                                anchors.top: parent.top

                                                Repeater {
                                                    model: gifCol3Model
                                                    delegate: gifDelegate
                                                }
                                            }
                                        }

                                        PlasmaComponents.BusyIndicator {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            running: gifView.isLoadingMore
                                            visible: gifView.isLoadingMore && trendingHeader.isExpanded
                                            width: 24
                                            height: 24
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            id: gifFloatingStickyHeader
                            parent: gifView
                            width: gifFlickable.width - ((gifFlickable.ScrollBar.vertical && gifFlickable.ScrollBar.vertical.visible) ? gifFlickable.ScrollBar.vertical.width : 0)
                            height: 32
                            z: 10
                            visible: gifView.visible && gifFlickable.activeStickyInfo !== null
                            
                            x: gifFlickable.x
                            y: gifFlickable.y + (gifFlickable.activeStickyInfo ? gifFlickable.activeStickyInfo.offset : 0)

                            readonly property var info: gifFlickable.activeStickyInfo
                            readonly property string catName: info ? info.name : ""
                            readonly property bool isTrending: info ? (info.isTrending === true) : false
                            readonly property bool isExpanded: info ? (isTrending ? trendingHeader.isExpanded : info.item.headerItem.isExpanded) : true
                            readonly property int count: info ? (isTrending ? 0 : info.item.catGifs.length) : 0

                            Rectangle {
                                anchors.fill: parent
                                color: Kirigami.Theme.backgroundColor
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: gifStickyHeaderMouse.pressed ? Kirigami.Theme.highlightColor : (gifStickyHeaderMouse.containsMouse ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent")
                                border.color: (gifStickyHeaderMouse.pressed || gifStickyHeaderMouse.containsMouse) ? Kirigami.Theme.highlightColor : "transparent"
                                border.width: 1
                                radius: 4
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Item {
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    Kirigami.Icon {
                                        anchors.centerIn: parent
                                        source: gifFloatingStickyHeader.isExpanded ? "go-down" : "go-next"
                                        width: 16
                                        height: 16
                                    }
                                }

                                PlasmaComponents.Label {
                                    text: gifFloatingStickyHeader.isTrending ? (fullRoot.filter !== "" ? i18n("Search Results") : i18n("GIFs")) : (gifFloatingStickyHeader.catName === "Favorites" ? i18n("Favorites") : i18n("Recent"))
                                    font.bold: true
                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.05
                                }

                                Rectangle {
                                    width: gifStickyCountLabel.contentWidth + 12
                                    height: 18
                                    radius: 9
                                    color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2)
                                    visible: !gifFloatingStickyHeader.isTrending

                                    PlasmaComponents.Label {
                                        id: gifStickyCountLabel
                                        anchors.centerIn: parent
                                        text: gifFloatingStickyHeader.count
                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                        font.bold: true
                                        color: Kirigami.Theme.textColor
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Kirigami.Theme.textColor
                                    opacity: 0.3
                                }
                            }

                            MouseArea {
                                id: gifStickyHeaderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.LeftButton && gifFloatingStickyHeader.info) {
                                        if (gifFloatingStickyHeader.isTrending) {
                                            trendingHeader.isExpanded = !trendingHeader.isExpanded;
                                        } else {
                                            gifFloatingStickyHeader.info.item.headerItem.isExpanded = !gifFloatingStickyHeader.info.item.headerItem.isExpanded;
                                        }
                                    }
                                }
                            }
                        }

                        ScrollView {
                            id: kaomojiView
                            anchors.fill: parent
                            visible: fullRoot.selectedCategory === fullRoot.catKaomoji
                            clip: true

                            property var categoryStates: ({})
                            property string currentFilter: fullRoot.searchFilter
                            
                            function toggleCategory(catName) {
                                let states = Object.assign({}, categoryStates);
                                states[catName] = !(states[catName] !== false);
                                categoryStates = states;
                            }

                            readonly property var activeStickyInfo: {
                                let cy = contentY;
                                let column = contentItem.children[0];
                                if (!column) return null;
                                
                                let activeItem = null;
                                let activeY = 0;
                                let nextY = Infinity;
                                
                                for (let p = 0; p < column.children.length; p++) {
                                    let pCol = column.children[p];
                                    if (!pCol || pCol.y === undefined) continue;
                                    
                                    for (let k = 0; k < pCol.children.length; k++) {
                                        let subCol = pCol.children[k];
                                        if (!subCol || subCol.y === undefined || !subCol.visible) continue;
                                        
                                        let header = subCol.children[0];
                                        if (!header || header.height === undefined) continue;
                                        
                                        let absY = pCol.y + subCol.y; 
                                        
                                        if (absY <= cy) {
                                            activeItem = subCol;
                                            activeY = absY;
                                        } else if (absY < nextY && absY > cy) {
                                            nextY = absY;
                                        }
                                    }
                                }
                                
                                if (!activeItem) return null;
                                
                                let headerH = 32;
                                let offset = 0;
                                if (nextY !== Infinity && (nextY - cy) < headerH) {
                                    offset = (nextY - cy) - headerH;
                                }
                                
                                return {
                                    catName: activeItem.catName,
                                    isExpanded: kaomojiView.categoryStates[activeItem.catName] !== false,
                                    count: activeItem.filteredEmojis.length,
                                    offset: offset
                                };
                            }

                            Column {
                                width: kaomojiView.width - (kaomojiView.ScrollBar.vertical.visible ? kaomojiView.ScrollBar.vertical.width : 0)
                                spacing: 0

                                Repeater {
                                    model: KaomojiList.kaomojiList
                                    delegate: Column {
                                        width: parent.width
                                        spacing: 0
                                        property var parentCategory: modelData
                                        
                                        Repeater {
                                            model: parentCategory.categories
                                            delegate: Column {
                                                width: parent.width
                                                spacing: 0
                                                property var subCategory: modelData
                                                property string catName: parentCategory.name + " - " + subCategory.name
                                                property var catEmojis: subCategory.emoticons
                                                
                                                property var filteredEmojis: {
                                                    let cf = kaomojiView.currentFilter.toLowerCase().trim();
                                                    if (cf === "") return catEmojis;
                                                    let res = [];
                                                    for (let i = 0; i < catEmojis.length; i++) {
                                                        if (catEmojis[i].toLowerCase().indexOf(cf) !== -1) {
                                                            res.push(catEmojis[i]);
                                                        }
                                                    }
                                                    return res;
                                                }
                                                
                                                visible: filteredEmojis.length > 0
                                                
                                                Item {
                                                    id: kaomojiCatHeader
                                                    width: parent.width
                                                    height: 32
                                                    property bool isExpanded: kaomojiView.categoryStates[catName] !== false
                                                    visible: (!kaomojiView.activeStickyInfo || kaomojiView.activeStickyInfo.catName !== catName || kaomojiView.activeStickyInfo.offset < 0)

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: kaomojiCatHeaderMouse.pressed ? Kirigami.Theme.highlightColor : (kaomojiCatHeaderMouse.containsMouse ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent")
                                                        border.color: (kaomojiCatHeaderMouse.pressed || kaomojiCatHeaderMouse.containsMouse) ? Kirigami.Theme.highlightColor : "transparent"
                                                        border.width: 1
                                                        radius: 4
                                                    }

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 8
                                                        anchors.rightMargin: 8
                                                        spacing: 8

                                                        Item {
                                                            implicitWidth: 16
                                                            implicitHeight: 16
                                                            Kirigami.Icon {
                                                                anchors.centerIn: parent
                                                                source: kaomojiCatHeader.isExpanded ? "go-down" : "go-next"
                                                                width: 16
                                                                height: 16
                                                            }
                                                        }

                                                        PlasmaComponents.Label {
                                                            text: catName
                                                            font.bold: true
                                                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.05
                                                        }
                                                        
                                                        Rectangle {
                                                             Layout.fillWidth: true
                                                             height: 1
                                                             color: Kirigami.Theme.textColor
                                                             opacity: 0.3
                                                         }
                                                    }

                                                    MouseArea {
                                                        id: kaomojiCatHeaderMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: function(mouse) {
                                                            if (mouse.button === Qt.LeftButton) {
                                                                kaomojiView.toggleCategory(catName);
                                                            }
                                                        }
                                                    }
                                                }

                                                Flow {
                                                    width: parent.width
                                                    spacing: 4
                                                    visible: kaomojiCatHeader.isExpanded
                                                    
                                                    Repeater {
                                                        model: filteredEmojis
                                                        delegate: Item {
                                                            property string kaomojiText: modelData
                                                            width: kaomojiLabel.implicitWidth + 16
                                                            height: 36

                                                            Rectangle {
                                                                anchors.fill: parent
                                                                anchors.margins: 2
                                                                color: Kirigami.Theme.highlightColor
                                                                radius: 4
                                                                opacity: kaomojiMouseArea.pressed ? 1.0 : (kaomojiMouseArea.containsMouse ? 0.2 : 0)
                                                            }
                                                            Rectangle {
                                                                anchors.fill: parent
                                                                anchors.margins: 2
                                                                color: "transparent"
                                                                radius: 4
                                                                border.width: (kaomojiMouseArea.pressed || kaomojiMouseArea.containsMouse) ? 2 : 0
                                                                border.color: Kirigami.Theme.highlightColor
                                                            }

                                                            PlasmaComponents.Label {
                                                                id: kaomojiLabel
                                                                anchors.centerIn: parent
                                                                text: kaomojiText
                                                                font.pixelSize: Math.floor(fullRoot.internalGridSize * 0.4)
                                                                renderType: Text.NativeRendering
                                                            }

                                                            MouseArea {
                                                                id: kaomojiMouseArea
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                acceptedButtons: Qt.LeftButton
                                                                cursorShape: Qt.PointingHandCursor
                                                                
                                                                onEntered: {
                                                                    fullRoot.emojiHoveredEmojiKey = kaomojiText;
                                                                    fullRoot.hoveredEmojiName = catName;
                                                                    fullRoot.emojiHoveredEmojiType = "kaomoji";
                                                                }

                                                                onExited: {
                                                                    if (fullRoot.emojiHoveredEmojiKey === kaomojiText) {
                                                                        fullRoot.emojiLastHoveredEmojiKey = kaomojiText;
                                                                    }
                                                                }

                                                                onClicked: function(mouse) {
                                                                    handleEmojiSelected(kaomojiText, false, false, false);
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        ScrollView {
                            id: allEmojisView
                            anchors.fill: parent
                            visible: fullRoot.selectedCategory !== fullRoot.catGifs && fullRoot.selectedCategory !== fullRoot.catKaomoji
                            clip: true

                            property var categoryStates: ({})

                            readonly property var activeStickyInfo: {
                                if (!contentItem || !allEmojisView.visible) return null;
                                let currentY = contentItem.contentY;
                                
                                let items = [];
                                if (typeof emojiKitchenSection !== "undefined" && emojiKitchenSection && emojiKitchenSection.visible) {
                                    items.push({
                                        name: emojiKitchenSection.catName,
                                        item: emojiKitchenSection,
                                        y: emojiKitchenSection.y,
                                        height: emojiKitchenSection.height,
                                        headerHeight: 32,
                                        isKitchen: true
                                    });
                                }
                                if (typeof allEmojisRepeater !== "undefined" && allEmojisRepeater) {
                                    for (let i = 0; i < allEmojisRepeater.count; i++) {
                                        let item = allEmojisRepeater.itemAt(i);
                                        if (item && item.visible) {
                                            items.push({
                                                name: item.catName,
                                                item: item,
                                                y: item.y,
                                                height: item.height,
                                                headerHeight: 32,
                                                isKitchen: false
                                            });
                                        }
                                    }
                                }

                                if (items.length === 0) return null;

                                let activeIdx = -1;
                                for (let i = 0; i < items.length; i++) {
                                    if (currentY >= items[i].y) {
                                        activeIdx = i;
                                    }
                                }

                                if (activeIdx === -1) return null;

                                let active = items[activeIdx];
                                
                                // Hide if scroll has completely passed the bottom of the active category
                                if (currentY >= active.y + active.height) {
                                    return null;
                                }

                                let nextItem = (activeIdx + 1 < items.length) ? items[activeIdx + 1] : null;
                                let offset = 0;
                                if (nextItem && nextItem.y < currentY + active.headerHeight) {
                                    offset = nextItem.y - (currentY + active.headerHeight);
                                } else if (currentY + active.headerHeight > active.y + active.height) {
                                    offset = (active.y + active.height) - (currentY + active.headerHeight);
                                }

                                return {
                                    name: active.name,
                                    item: active.item,
                                    y: active.y,
                                    height: active.height,
                                    isKitchen: active.isKitchen,
                                    offset: offset,
                                    headerHeight: active.headerHeight
                                };
                            }

                            Connections {
                                target: allEmojisView.contentItem
                                function onContentYChanged() {
                                    if (!allEmojisView.visible || scrollTimer.running) return;
                                    let currentY = allEmojisView.contentItem.contentY;
                                    let activeCat = "";
                                    for (let i = 0; i < allEmojisRepeater.count; i++) {
                                        let item = allEmojisRepeater.itemAt(i);
                                        // 40px offset: if the header is slightly below the top edge, consider it active
                                        if (item && item.visible && item.y <= currentY + 40) {
                                            activeCat = item.catName;
                                        }
                                    }
                                    if (activeCat !== "" && fullRoot.selectedCategory !== activeCat) {
                                        fullRoot.selectedCategory = activeCat;
                                    }
                                }
                            }

                            function toggleCategory(catName) {
                                let states = Object.assign({}, categoryStates);
                                states[catName] = !(states[catName] !== false);
                                categoryStates = states;
                            }

                            Timer {
                                id: scrollTimer
                                interval: 50
                                property var targetItem: null
                                onTriggered: {
                                    if (targetItem && allEmojisView.contentItem) {
                                        let targetY = targetItem.y;
                                        let maxContentY = allEmojisLayout.height - allEmojisView.height;
                                        allEmojisView.contentItem.contentY = Math.max(0, Math.min(targetY, maxContentY));
                                    }
                                }
                            }

                            function scrollToCategory(catName) {
                                if (catName === fullRoot.catEmojiKitchen) {
                                    let states = Object.assign({}, categoryStates);
                                    states[catName] = true;
                                    categoryStates = states;
                                    scrollTimer.targetItem = emojiKitchenSection;
                                    scrollTimer.restart();
                                    return;
                                }

                                for (let i = 0; i < allEmojisRepeater.count; i++) {
                                    let item = allEmojisRepeater.itemAt(i);
                                    if (item && item.catName === catName) {
                                        // Scroll view needs to update contentY. We ensure it's expanded.
                                        let states = Object.assign({}, categoryStates);
                                        states[catName] = true;
                                        categoryStates = states;
                                        
                                        scrollTimer.targetItem = item;
                                        scrollTimer.restart();
                                        break;
                                    }
                                }
                            }

                            Column {
                                id: allEmojisLayout
                                width: allEmojisView.width - (allEmojisView.ScrollBar.vertical.visible ? allEmojisView.ScrollBar.vertical.width : 0)
                                spacing: 0

                                
                                Column {
                                    id: emojiKitchenSection
                                    width: parent.width
                                    spacing: 8
                                    property string catName: fullRoot.catEmojiKitchen

                                    Item {
                                        id: kitchenCatHeader
                                        width: parent.width
                                        height: 32
                                        property bool isExpanded: allEmojisView.categoryStates[emojiKitchenSection.catName] !== false

                                        Rectangle {
                                            anchors.fill: parent
                                            color: kitchenCatHeaderMouse.pressed ? Kirigami.Theme.highlightColor : (kitchenCatHeaderMouse.containsMouse ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent")
                                            border.color: (kitchenCatHeaderMouse.pressed || kitchenCatHeaderMouse.containsMouse) ? Kirigami.Theme.highlightColor : "transparent"
                                            border.width: 1
                                            radius: 4
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            Item {
                                                implicitWidth: 16
                                                implicitHeight: 16
                                                Kirigami.Icon {
                                                    anchors.centerIn: parent
                                                    source: kitchenCatHeader.isExpanded ? "go-down" : "go-next"
                                                    width: 16
                                                    height: 16
                                                }
                                            }

                                            PlasmaComponents.Label {
                                                text: i18n("Emoji Kitchen")
                                                font.bold: true
                                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.05
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 1
                                                color: Kirigami.Theme.textColor
                                                opacity: 0.3
                                            }
                                        }

                                        MouseArea {
                                            id: kitchenCatHeaderMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: function(mouse) {
                                                if (mouse.button === Qt.LeftButton) {
                                                    allEmojisView.toggleCategory(emojiKitchenSection.catName);
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        id: kitchenContentWrapper
                                        width: parent.width
                                        visible: kitchenCatHeader.isExpanded
                                        spacing: 0
                                        
                        Item {
                            id: kitchenView
                            width: parent.width
                            implicitHeight: kitchenGridView.y + kitchenGridView.height
                            property string emoji1: ""
                            property string emoji2: ""
                            property string resultUrl: ""
                            property string resultUrlAlternative: ""
                            property string _actualSource: ""
                            property string currentValidUrl: ""
                            property var candidatesList: []
                            property int currentCandidateIndex: 0

                            onResultUrlChanged: _actualSource = resultUrl

                            Plasma5Support.DataSource {
                                id: shellSource
                                engine: "executable"
                                connectedSources: []
                                onNewData: (source, data) => {
                                    disconnectSource(source);
                                }
                            }

                            readonly property int slotSize: {
                                let calculated = Math.floor((kitchenView.width - 144) / 3);
                                return Math.min(160, Math.max(32, calculated));
                            }



                            function updateResult() {
                                if (emoji1 !== "" && emoji2 !== "") {
                                    let cp1 = fullRoot.getCodepoint(emoji1);
                                    let cp2 = fullRoot.getCodepoint(emoji2);

                                    let findCombo = (c1, c2) => {
                                        let stripFE0F = s => s.replace(/-fe0f/g, "");
                                        let c1_norm = stripFE0F(c1);
                                        let c2_norm = stripFE0F(c2);

                                        let base = KitchenMetadata.kitchenMetadata[c1];
                                        if (base) {
                                            let exact = base.find(c => stripFE0F(c.e) === c2_norm);
                                            if (exact)
                                            return {
                                                entry: exact,
                                                b: c1,
                                                p: exact.e
                                            };
                                        }

                                        base = KitchenMetadata.kitchenMetadata[c1_norm];
                                        if (base) {
                                            let loose = base.find(c => stripFE0F(c.e) === c2_norm);
                                            if (loose)
                                            return {
                                                entry: loose,
                                                b: c1_norm,
                                                p: loose.e
                                            };
                                        }
                                        return null;
                                    };

                                    let combo = findCombo(cp1, cp2) || findCombo(cp2, cp1);

                                    if (combo) {
                                        let toUrl = cp => "u" + cp.replace(/-/g, "-u");
                                        let stripFE0F = s => s.replace(/-fe0f/g, "");

                                        let b_unstripped = combo.b;
                                        let b_stripped = stripFE0F(combo.b);
                                        let p_unstripped = combo.p;
                                        let p_stripped = stripFE0F(combo.p);

                                        let baseUrl = "https://www.gstatic.com/android/keyboard/emojikitchen/" + combo.entry.d + "/";

                                        let candidates = [];

                                        candidates.push(baseUrl + toUrl(b_unstripped) + "/" + toUrl(combo.b) + "_" + toUrl(combo.p) + ".png");
                                        if (b_stripped !== b_unstripped) {
                                            candidates.push(baseUrl + toUrl(b_stripped) + "/" + toUrl(combo.b) + "_" + toUrl(combo.p) + ".png");
                                        }

                                        candidates.push(baseUrl + toUrl(p_unstripped) + "/" + toUrl(combo.p) + "_" + toUrl(combo.b) + ".png");
                                        if (p_stripped !== p_unstripped) {
                                            candidates.push(baseUrl + toUrl(p_stripped) + "/" + toUrl(combo.p) + "_" + toUrl(combo.b) + ".png");
                                        }

                                        candidatesList = candidates;
                                        currentCandidateIndex = 0;
                                        resultUrl = candidates[0];
                                        _actualSource = candidates[0];

                                        console.log("DEBUG: Candidates list generated:", JSON.stringify(candidates));
                                    } else {
                                        candidatesList = [];
                                        currentCandidateIndex = 0;
                                        resultUrl = "";
                                        _actualSource = "";
                                        currentValidUrl = "";
                                    }
                                } else {
                                    candidatesList = [];
                                    currentCandidateIndex = 0;
                                    resultUrl = "";
                                    _actualSource = "";
                                    currentValidUrl = "";
                                }
                            }
                            onEmoji1Changed: updateResult()
                            onEmoji2Changed: updateResult()

                            function emojiFromCodepoint(cp) {
                                if (!cp)
                                return "";
                                return cp.split("-").map(part => String.fromCodePoint(parseInt(part, 16))).join("");
                            }
                            function randomize() {
                                let bases = Object.keys(KitchenMetadata.kitchenMetadata);
                                if (bases.length > 0) {
                                    let cp1 = bases[Math.floor(Math.random() * bases.length)];
                                    let partners = KitchenMetadata.kitchenMetadata[cp1];
                                    if (partners && partners.length > 0) {
                                        let partnerEntry = partners[Math.floor(Math.random() * partners.length)];
                                        let cp2 = partnerEntry.e;

                                        emoji1 = emojiFromCodepoint(cp1);
                                        emoji2 = emojiFromCodepoint(cp2);
                                    }
                                }
                            }

                            function randomizeSlot1() {
                                let bases = Object.keys(KitchenMetadata.kitchenMetadata);
                                if (bases.length === 0)
                                return;
                                if (emoji2 !== "") {
                                    let cp2 = fullRoot.getCodepoint(emoji2).replace(/-fe0f/g, "");
                                    let validBases = [];
                                    for (let cp1 of bases) {
                                        let partners = KitchenMetadata.kitchenMetadata[cp1];
                                        if (partners) {
                                            for (let p of partners) {
                                                if (p.e.replace(/-fe0f/g, "") === cp2) {
                                                    validBases.push(cp1);
                                                    break;
                                                }
                                            }
                                        }
                                    }
                                    if (validBases.length > 0) {
                                        let chosenCp = validBases[Math.floor(Math.random() * validBases.length)];
                                        emoji1 = emojiFromCodepoint(chosenCp);
                                        return;
                                    }
                                }
                                let chosenCp = bases[Math.floor(Math.random() * bases.length)];
                                emoji1 = emojiFromCodepoint(chosenCp);
                            }

                            function randomizeSlot2() {
                                let bases = Object.keys(KitchenMetadata.kitchenMetadata);
                                if (bases.length === 0)
                                return;
                                if (emoji1 !== "") {
                                    let cp1_raw = fullRoot.getCodepoint(emoji1);
                                    let cp1 = bases.find(k => k.replace(/-fe0f/g, "") === cp1_raw.replace(/-fe0f/g, ""));
                                    if (cp1) {
                                        let partners = KitchenMetadata.kitchenMetadata[cp1];
                                        if (partners && partners.length > 0) {
                                            let chosenPartner = partners[Math.floor(Math.random() * partners.length)];
                                            emoji2 = emojiFromCodepoint(chosenPartner.e);
                                            return;
                                        }
                                    }
                                }
                                let chosenCp = bases[Math.floor(Math.random() * bases.length)];
                                emoji2 = emojiFromCodepoint(chosenCp);
                            }

                            function copyResult() {
                                if (currentValidUrl !== "") {
                                    let cmd = 'curl -sL "' + currentValidUrl + '" > /tmp/kmoji_copy.png && (wl-copy --type image/png < /tmp/kmoji_copy.png || xclip -selection clipboard -t image/png -i /tmp/kmoji_copy.png)';
                                    shellSource.connectSource(cmd);
                                    showPasteTemporaryMessage(i18n("Copied mashup to clipboard!"));

                                    fullRoot.addRecentItem("kitchen", {
                                        url: currentValidUrl,
                                        emoji1: emoji1,
                                        emoji2: emoji2
                                    });
                                }
                            }

                            RowLayout {
                                id: selectionRow
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 16
                                clip: true

                                Item {
                                    Layout.fillWidth: true
                                }

                                ColumnLayout {
                                    spacing: 8
                                    Layout.alignment: Qt.AlignVCenter

                                    Rectangle {
                                        id: slot1
                                        width: kitchenView.slotSize
                                        height: kitchenView.slotSize
                                        Layout.preferredWidth: kitchenView.slotSize
                                        Layout.preferredHeight: kitchenView.slotSize
                                        color: Kirigami.Theme.backgroundColor
                                        border.color: (activeFocus || slot1MouseArea.containsMouse || kitchenView.emoji1 !== "") ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                                        border.width: (activeFocus || slot1MouseArea.containsMouse || kitchenView.emoji1 === "") ? 2 : 1
                                        radius: 8

                                        focusPolicy: Qt.StrongFocus
                                        activeFocusOnTab: true
                                        KeyNavigation.tab: randomizeSlot1Button
                                        KeyNavigation.backtab: (categoryListView.currentItem || sidebarToggleButton)

                                        Text {
                                            anchors.centerIn: parent
                                            text: kitchenView.emoji1 === "" ? "?" : kitchenView.emoji1
                                            font.pixelSize: kitchenView.emoji1 === "" ? Math.floor(kitchenView.slotSize * 0.6) : Math.floor(kitchenView.slotSize * 0.85)
                                            font.family: kitchenView.emoji1 === "" ? Kirigami.Theme.defaultFont.family : "Noto Color Emoji"
                                            color: Kirigami.Theme.textColor
                                            opacity: kitchenView.emoji1 === "" ? 0.2 : 1.0
                                            renderType: kitchenView.emoji1 === "" ? Text.QtRendering : Text.NativeRendering
                                        }

                                        MouseArea {
                                            id: slot1MouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                slot1.forceActiveFocus();
                                                kitchenView.emoji1 = "";
                                            }
                                        }

                                        Keys.onReturnPressed: kitchenView.emoji1 = ""
                                        Keys.onEnterPressed: kitchenView.emoji1 = ""
                                    }

                                    PlasmaComponents.ToolButton {
                                        id: randomizeSlot1Button
                                        display: PlasmaComponents.ToolButton.IconOnly
                                        icon.name: "roll-symbolic"
                                        Layout.alignment: Qt.AlignHCenter
                                        activeFocusOnTab: true
                                        KeyNavigation.tab: slot2
                                        KeyNavigation.backtab: slot1
                                        onClicked: kitchenView.randomizeSlot1()
                                        PlasmaComponents.ToolTip {
                                            text: i18n("Randomize Slot 1")
                                        }
                                    }
                                }

                                ColumnLayout {
                                    spacing: 8
                                    Layout.alignment: Qt.AlignVCenter
                                    Text {
                                        text: "+"
                                        font.pixelSize: 24
                                        color: Kirigami.Theme.textColor
                                        opacity: 0.6
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Item {
                                        Layout.preferredHeight: 32
                                        Layout.preferredWidth: 1
                                    }
                                }

                                ColumnLayout {
                                    spacing: 8
                                    Layout.alignment: Qt.AlignVCenter

                                    Rectangle {
                                        id: slot2
                                        width: kitchenView.slotSize
                                        height: kitchenView.slotSize
                                        Layout.preferredWidth: kitchenView.slotSize
                                        Layout.preferredHeight: kitchenView.slotSize
                                        color: Kirigami.Theme.backgroundColor
                                        border.color: (activeFocus || slot2MouseArea.containsMouse || kitchenView.emoji2 !== "") ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                                        border.width: (activeFocus || slot2MouseArea.containsMouse || kitchenView.emoji2 === "") ? 2 : 1
                                        radius: 8

                                        focusPolicy: Qt.StrongFocus
                                        activeFocusOnTab: true
                                        KeyNavigation.tab: randomizeSlot2Button
                                        KeyNavigation.backtab: randomizeSlot1Button

                                        Text {
                                            anchors.centerIn: parent
                                            text: kitchenView.emoji2 === "" ? "?" : kitchenView.emoji2
                                            font.pixelSize: kitchenView.emoji2 === "" ? Math.floor(kitchenView.slotSize * 0.6) : Math.floor(kitchenView.slotSize * 0.85)
                                            font.family: kitchenView.emoji2 === "" ? Kirigami.Theme.defaultFont.family : "Noto Color Emoji"
                                            color: Kirigami.Theme.textColor
                                            opacity: kitchenView.emoji2 === "" ? 0.2 : 1.0
                                            renderType: kitchenView.emoji2 === "" ? Text.QtRendering : Text.NativeRendering
                                        }

                                        MouseArea {
                                            id: slot2MouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                slot2.forceActiveFocus();
                                                kitchenView.emoji2 = "";
                                            }
                                        }

                                        Keys.onReturnPressed: kitchenView.emoji2 = ""
                                        Keys.onEnterPressed: kitchenView.emoji2 = ""
                                    }

                                    PlasmaComponents.ToolButton {
                                        id: randomizeSlot2Button
                                        display: PlasmaComponents.ToolButton.IconOnly
                                        icon.name: "roll-symbolic"
                                        Layout.alignment: Qt.AlignHCenter
                                        activeFocusOnTab: true
                                        KeyNavigation.tab: resultSlot
                                        KeyNavigation.backtab: slot2
                                        onClicked: kitchenView.randomizeSlot2()
                                        PlasmaComponents.ToolTip {
                                            text: i18n("Randomize Slot 2")
                                        }
                                    }
                                }

                                ColumnLayout {
                                    spacing: 8
                                    Layout.alignment: Qt.AlignVCenter
                                    Text {
                                        text: "="
                                        font.pixelSize: 24
                                        color: Kirigami.Theme.textColor
                                        opacity: 0.6
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Item {
                                        Layout.preferredHeight: 32
                                        Layout.preferredWidth: 1
                                    }
                                }

                                ColumnLayout {
                                    spacing: 8
                                    Layout.alignment: Qt.AlignVCenter

                                    Rectangle {
                                        id: resultSlot
                                        width: kitchenView.slotSize
                                        height: kitchenView.slotSize
                                        Layout.preferredWidth: kitchenView.slotSize
                                        Layout.preferredHeight: kitchenView.slotSize
                                        color: Kirigami.Theme.backgroundColor
                                        border.color: (activeFocus || resultSlotArea.containsMouse || kitchenView.resultUrl !== "") ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                                        border.width: (activeFocus || resultSlotArea.containsMouse || kitchenView.resultUrl === "") ? 2 : 1
                                        radius: 8

                                        focusPolicy: Qt.StrongFocus
                                        activeFocusOnTab: true
                                        KeyNavigation.tab: randomizeResultButton
                                        KeyNavigation.backtab: randomizeSlot2Button

                                        Text {
                                            anchors.centerIn: parent
                                            text: "?"
                                            font.pixelSize: Math.floor(kitchenView.slotSize * 0.6)
                                            color: Kirigami.Theme.textColor
                                            opacity: 0.2 * (1.0 - resultImage.opacity)
                                        }

                                        Image {
                                            id: resultImage
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            source: kitchenView._actualSource
                                            sourceSize: Qt.size(512, 512)
                                            fillMode: Image.PreserveAspectFit
                                            opacity: (status === Image.Ready && kitchenView.resultUrl !== "") ? 1.0 : 0.0
                                            smooth: true
                                            mipmap: true
                                            asynchronous: true

                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 150
                                                }
                                            }

                                            onStatusChanged: {
                                                if (status === Image.Ready) {
                                                    kitchenView.currentValidUrl = source.toString();
                                                } else if (status === Image.Error) {
                                                    if (kitchenView.currentCandidateIndex + 1 < kitchenView.candidatesList.length) {
                                                        kitchenView.currentCandidateIndex += 1;
                                                        kitchenView._actualSource = kitchenView.candidatesList[kitchenView.currentCandidateIndex];
                                                    } else {
                                                        kitchenView.currentValidUrl = "";
                                                    }
                                                }
                                            }
                                        }

                                        HoverHandler {
                                            id: resultSlotHover
                                            cursorShape: kitchenView.currentValidUrl !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        }

                                        MouseArea {
                                            id: resultSlotArea
                                            anchors.fill: parent
                                            enabled: kitchenView.currentValidUrl !== ""
                                            acceptedButtons: Qt.LeftButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                resultSlot.forceActiveFocus();
                                                kitchenView.copyResult();
                                            }
                                        }

                                        PlasmaComponents.ToolButton {
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            anchors.margins: 4
                                            icon.name: fullRoot.isFavoriteItem("kitchen", {
                                                url: kitchenView.currentValidUrl
                                            }) ? "bookmarks-bookmarked" : "bookmarks"
                                            visible: resultSlotHover.hovered && kitchenView.currentValidUrl !== ""
                                            width: 24
                                            height: 24
                                            display: PlasmaComponents.ToolButton.IconOnly
                                            z: 10
                                            background: Rectangle {
                                                color: parent.pressed ? Kirigami.Theme.highlightColor : (parent.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.35) : Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.85))
                                                radius: 4
                                                border.color: (parent.pressed || parent.hovered) ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                                                border.width: 1
                                            }

                                            onClicked: {
                                                fullRoot.toggleFavoriteItem("kitchen", {
                                                    url: kitchenView.currentValidUrl,
                                                    emoji1: kitchenView.emoji1,
                                                    emoji2: kitchenView.emoji2
                                                });
                                            }
                                        }

                                        Keys.onReturnPressed: if (kitchenView.currentValidUrl !== "")
                                        kitchenView.copyResult()
                                        Keys.onEnterPressed: if (kitchenView.currentValidUrl !== "")
                                        kitchenView.copyResult()
                                    }

                                    PlasmaComponents.ToolButton {
                                        id: randomizeResultButton
                                        display: PlasmaComponents.ToolButton.IconOnly
                                        icon.name: "roll-symbolic"
                                        Layout.alignment: Qt.AlignHCenter
                                        activeFocusOnTab: true
                                        KeyNavigation.tab: kitchenGridView
                                        KeyNavigation.backtab: resultSlot
                                        onClicked: kitchenView.randomize()
                                        PlasmaComponents.ToolTip {
                                            text: i18n("Randomize Result")
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }
                            }

                            Kirigami.Separator {
                                id: gridSeparator
                                anchors.top: selectionRow.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.topMargin: 8
                            }

                            GridView {
                                id: kitchenGridView
                                anchors.top: gridSeparator.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: Math.ceil(count / Math.max(1, Math.floor(width / cellWidth))) * cellHeight
                                cellWidth: fullRoot.internalGridSize
                                cellHeight: fullRoot.internalGridSize
                                clip: false
                                interactive: false
                                cacheBuffer: 1000000
                                property var kitchenFilteredEmojis: {
                                    if (fullRoot.filter && fullRoot.filter.trim() !== "") {
                                        return fullRoot.performFilter(fullRoot.kitchenEmojiList, fullRoot.filter);
                                    } else {
                                        return fullRoot.kitchenEmojiList;
                                    }
                                }
                                model: kitchenFilteredEmojis

                                activeFocusOnTab: true
                                KeyNavigation.tab: searchField
                                KeyNavigation.backtab: randomizeResultButton

                                keyNavigationEnabled: fullRoot.emojiKeyboardNavigationEnabled
                                keyNavigationWraps: fullRoot.emojiKeyboardNavigationEnabled



                                HoverHandler {
                                    id: kitchenGridHoverHandler
                                    onHoveredChanged: {
                                        fullRoot.gridIsMouseOver = hovered;
                                        if (!hovered && fullRoot.emojiHoveredEmojiKey !== "") {
                                            fullRoot.emojiLastHoveredEmojiKey = fullRoot.emojiHoveredEmojiKey;
                                            fullRoot.emojiHoveredEmojiKey = "";
                                            fullRoot.hoveredEmojiName = "";
                                        }
                                    }
                                }

                                property bool keyboardActionPressed: false

                                Timer {
                                    id: keyboardReleaseTimer
                                    interval: 150
                                    onTriggered: kitchenGridView.keyboardActionPressed = false
                                }

                                Keys.onPressed: function (event) {
                                    if (!fullRoot.emojiKeyboardNavigationEnabled)
                                    return;
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (currentIndex >= 0 && currentIndex < kitchenFilteredEmojis.length) {
                                            kitchenView.emoji1 = kitchenFilteredEmojis[currentIndex].emoji;
                                        }
                                        keyboardActionPressed = true;
                                        keyboardReleaseTimer.restart();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Space) {
                                        if (currentIndex >= 0 && currentIndex < kitchenFilteredEmojis.length) {
                                            kitchenView.emoji2 = kitchenFilteredEmojis[currentIndex].emoji;
                                        }
                                        keyboardActionPressed = true;
                                        keyboardReleaseTimer.restart();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Escape) {
                                        handleEscapePressed();
                                        event.accepted = true;
                                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                        const backwards = (event.key === Qt.Key_Backtab) || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier));
                                        if (!backwards) {
                                            searchField.forceActiveFocus();
                                            event.accepted = true;
                                        } else {
                                            randomizeResultButton.forceActiveFocus();
                                            event.accepted = true;
                                        }
                                    }
                                }



                                function updateKeyboardHover() {
                                    if (!fullRoot.emojiKeyboardNavigationEnabled)
                                    return;
                                    if (currentIndex >= 0 && currentIndex < kitchenFilteredEmojis.length) {
                                        const item = kitchenFilteredEmojis[currentIndex];
                                        if (item) {
                                            if (fullRoot.emojiHoveredEmojiKey !== item.emoji) {
                                                fullRoot.emojiHoveredEmojiKey = item.emoji;
                                                fullRoot.hoveredEmojiName = item.name;
                                                fullRoot.emojiHoveredEmojiType = "kitchen";
                                            }
                                            if (fullRoot.emojiLastHoveredEmojiKey !== item.emoji) {
                                                fullRoot.emojiLastHoveredEmojiKey = item.emoji;
                                            }
                                        }
                                    }
                                }

                                function clearKeyboardHover() {
                                    if (fullRoot.emojiHoveredEmojiKey !== "") {
                                        fullRoot.emojiHoveredEmojiKey = "";
                                        fullRoot.hoveredEmojiName = "";
                                    }
                                }

                                onActiveFocusChanged: {
                                    if (activeFocus && fullRoot.emojiKeyboardNavigationEnabled) {
                                        if (count > 0) {
                                            if (currentIndex < 0 || currentIndex >= count) {
                                                currentIndex = 0;
                                            } else {
                                                updateKeyboardHover();
                                            }
                                        }
                                    } else if (!activeFocus) {
                                        clearKeyboardHover();
                                    }
                                }

                                onCurrentIndexChanged: {
                                    if (activeFocus && fullRoot.emojiKeyboardNavigationEnabled) {
                                        updateKeyboardHover();
                                    }
                                }

                                delegate: Item {
                                    width: fullRoot.internalGridSize
                                    height: fullRoot.internalGridSize

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        color: Kirigami.Theme.highlightColor
                                        radius: 4
                                        opacity: (mouseArea.pressed || (kitchenGridView.activeFocus && kitchenGridView.currentIndex === index && kitchenGridView.keyboardActionPressed)) ? 1.0 : (mouseArea.containsMouse || (kitchenGridView.activeFocus && (kitchenGridView.currentIndex === index || (fullRoot.emojiLastHoveredEmojiKey === modelData.emoji && !true)))) ? 0.2 : 0
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        radius: 4
                                        border.width: (mouseArea.pressed || (kitchenGridView.activeFocus && kitchenGridView.currentIndex === index && kitchenGridView.keyboardActionPressed) || mouseArea.containsMouse || (kitchenGridView.activeFocus && (kitchenGridView.currentIndex === index || (fullRoot.emojiLastHoveredEmojiKey === modelData.emoji && !true)))) ? 2 : 0
                                        border.color: Kirigami.Theme.highlightColor
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.emoji
                                        font.pixelSize: Math.floor(fullRoot.internalGridSize * 0.81)
                                        font.family: "Noto Color Emoji"
                                        renderType: Text.NativeRendering
                                    }

                                    MouseArea {
                                        id: mouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onEntered: {
                                            fullRoot.emojiHoveredEmojiKey = modelData.emoji;
                                            fullRoot.hoveredEmojiName = modelData.name;
                                            fullRoot.emojiHoveredEmojiType = "kitchen";
                                            if (fullRoot.emojiKeyboardNavigationEnabled) {
                                                kitchenGridView.currentIndex = index;
                                            }
                                        }
                                        onExited: {
                                            if (fullRoot.emojiHoveredEmojiKey === modelData.emoji) {
                                                fullRoot.emojiLastHoveredEmojiKey = modelData.emoji;
                                            }
                                        }
                                        onClicked: function (mouse) {
                                            if (mouse.button === Qt.LeftButton) {
                                                kitchenView.emoji1 = modelData.emoji;
                                            } else if (mouse.button === Qt.RightButton) {
                                                kitchenView.emoji2 = modelData.emoji;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Kirigami.Separator {
                            width: parent.width
                            opacity: 0.3
                        }
                    }
                }


                Repeater {
                    id: allEmojisRepeater
                    model: ["Favorites", "Recent", "Smileys & Emotion", "People & Body", "Animals & Nature", "Food & Drink", "Activities", "Travel & Places", "Objects", "Symbols", "Flags"]
                    delegate: Column {
                        width: parent.width
                        spacing: 0
                        property string catName: modelData
                        property var catEmojis: {
                            let sourceList = [];
                            if (catName === "Favorites") {
                                sourceList = (fullRoot.favoriteEmojis || []).filter(e => !e.type || e.type === "emoji");
                            } else if (catName === "Recent") {
                                sourceList = (fullRoot.recentEmojis || []).filter(e => !e.type || e.type === "emoji").slice(0, 36);
                            } else {
                                sourceList = fullRoot.filteredEmojiByGroup[modelData] || [];
                            }
                            
                            if ((catName === "Favorites" || catName === "Recent") && fullRoot.filter && fullRoot.filter.trim() !== "") {
                                return performFilter(sourceList, fullRoot.filter);
                            }
                            return sourceList;
                        }

                        property var catKitchens: {
                            if (catName !== "Favorites" && catName !== "Recent") return [];
                            let sourceList = [];
                            if (catName === "Favorites") {
                                sourceList = (fullRoot.favoriteEmojis || []).filter(e => e.type === "kitchen");
                            } else if (catName === "Recent") {
                                sourceList = (fullRoot.recentEmojis || []).filter(e => e.type === "kitchen").slice(0, 36);
                            }
                            
                            if (fullRoot.filter && fullRoot.filter.trim() !== "") {
                                let lowerFilter = fullRoot.filter.toLowerCase().trim();
                                return sourceList.filter(e => {
                                    let matchStr = "kitchen mashup " + (e.emoji1 || "") + " " + (e.emoji2 || "");
                                    return matchStr.indexOf(lowerFilter) !== -1;
                                });
                            }
                            return sourceList;
                        }
                        visible: catEmojis.length > 0 || catKitchens.length > 0

                                        Item {
                                            id: catHeader
                                            width: parent.width
                                            height: 32

                                            property bool isExpanded: allEmojisView.categoryStates[catName] !== false

                                            Rectangle {
                                                anchors.fill: parent
                                                color: catHeaderMouse.pressed ? Kirigami.Theme.highlightColor : (catHeaderMouse.containsMouse ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent")
                                                border.color: (catHeaderMouse.pressed || catHeaderMouse.containsMouse) ? Kirigami.Theme.highlightColor : "transparent"
                                                border.width: 1
                                                radius: 4
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 8

                                                Item {
                                                    implicitWidth: 16
                                                    implicitHeight: 16
                                                    Kirigami.Icon {
                                                        anchors.centerIn: parent
                                                        source: catHeader.isExpanded ? "go-down" : "go-next"
                                                        width: 16
                                                        height: 16
                                                    }
                                                }

                                                PlasmaComponents.Label {
                                                    text: catName
                                                    font.bold: true
                                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.05
                                                }

                                                Rectangle {
                                                    width: catCountLabel.contentWidth + 12
                                                    height: 18
                                                    radius: 9
                                                    color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2)

                                                    PlasmaComponents.Label {
                                                        id: catCountLabel
                                                        anchors.centerIn: parent
                                                        text: catEmojis.length + catKitchens.length
                                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                        font.bold: true
                                                        color: Kirigami.Theme.textColor
                                                    }
                                                }

                                                Rectangle {
                                                     Layout.fillWidth: true
                                                     height: 1
                                                     color: Kirigami.Theme.textColor
                                                     opacity: 0.3
                                                 }
                                            }

                                            MouseArea {
                                                id: catHeaderMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: function(mouse) {
                                                    if (mouse.button === Qt.LeftButton) {
                                                        allEmojisView.toggleCategory(catName);
                                                    }
                                                }
                                            }
                                        }

                                        Flow {
                                            width: parent.width
                                            spacing: 0
                                            visible: catHeader.isExpanded

                                            Repeater {
                                                model: catEmojis

                                                delegate: Loader {
                                                    width: fullRoot.internalGridSize
                                                    height: fullRoot.internalGridSize
                                                    asynchronous: true
                                                    property var emojiData: modelData
                                                    
                                                    sourceComponent: Component {
                                                        Item {
                                                            anchors.fill: parent

                                                            Item {
                                                                anchors.fill: parent
                                                                anchors.margins: 2

                                                                Rectangle {
                                                                    anchors.fill: parent
                                                                    color: Kirigami.Theme.highlightColor
                                                                    radius: 4
                                                                    opacity: mouseArea.pressed ? 1.0 : (mouseArea.containsMouse ? 0.2 : 0)
                                                                }

                                                                Rectangle {
                                                                    anchors.fill: parent
                                                                    color: "transparent"
                                                                    radius: 4
                                                                    border.width: (mouseArea.pressed || mouseArea.containsMouse) ? 2 : 0
                                                                    border.color: Kirigami.Theme.highlightColor
                                                                }
                                                            }

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: emojiData.emoji
                                                                font.pixelSize: Math.floor(fullRoot.internalGridSize * 0.7)
                                                                horizontalAlignment: Text.AlignHCenter
                                                                verticalAlignment: Text.AlignVCenter
                                                                renderType: Text.NativeRendering
                                                            }

                                                            MouseArea {
                                                                id: mouseArea
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                                                onEntered: {
                                                                    fullRoot.emojiHoveredEmojiKey = emojiData.emoji;
                                                                    fullRoot.hoveredEmojiName = emojiData.name;
                                                                    fullRoot.emojiHoveredEmojiType = "emoji";
                                                                }

                                                                onExited: {
                                                                    if (fullRoot.emojiHoveredEmojiKey === emojiData.emoji) {
                                                                        fullRoot.emojiLastHoveredEmojiKey = emojiData.emoji;
                                                                    }
                                                                }

                                                                onClicked: function (mouse) {
                                                                    if (mouse.button === Qt.LeftButton) {
                                                                        const isCtrl = mouse.modifiers & Qt.ControlModifier;
                                                                        const isShift = mouse.modifiers & Qt.ShiftModifier;
                                                                        const isAlt = mouse.modifiers & Qt.AltModifier;
                                                                        handleEmojiSelected(emojiData.emoji, isCtrl, isShift, isAlt);
                                                                    } else if (mouse.button === Qt.RightButton) {
                                                                        var globalPos = mouseArea.mapToItem(fullRoot, mouse.x, mouse.y);
                                                                        handleEmojiRightClicked(emojiData.emoji, emojiData, globalPos);
                                                                    }
                                                                }

                                                                onPressAndHold: function (mouse) {
                                                                    var globalPos = mouseArea.mapToItem(fullRoot, mouse.x, mouse.y);
                                                                    handleEmojiRightClicked(emojiData.emoji, emojiData, globalPos);
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Item {
                                            width: parent.width
                                            height: 6
                                            visible: catHeader.isExpanded && catEmojis.length > 0 && catKitchens.length > 0
                                        }

                                        Flow {
                                            width: parent.width
                                            spacing: 8
                                            visible: catHeader.isExpanded && catKitchens.length > 0

                                            Repeater {
                                                model: catKitchens

                                                delegate: Loader {
                                                    width: Math.max(48, Math.floor(fullRoot.internalGridSize * 1.2))
                                                    height: Math.max(48, Math.floor(fullRoot.internalGridSize * 1.2))
                                                    asynchronous: true
                                                    property var kitchenData: modelData
                                                    
                                                    sourceComponent: Component {
                                                        Item {
                                                            anchors.fill: parent

                                                            Rectangle {
                                                                anchors.fill: parent
                                                                color: Kirigami.Theme.alternateBackgroundColor
                                                                border.color: (kitchenHoverHandler.hovered || kitchenMouseArea.pressed) ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                                                                border.width: (kitchenHoverHandler.hovered || kitchenMouseArea.pressed) ? 2 : 1
                                                                radius: 8

                                                                Image {
                                                                    anchors.fill: parent
                                                                    anchors.margins: 4
                                                                    source: kitchenData.url
                                                                    sourceSize: Qt.size(128, 128)
                                                                    fillMode: Image.PreserveAspectFit
                                                                    smooth: true
                                                                    mipmap: true
                                                                }

                                                                HoverHandler {
                                                                    id: kitchenHoverHandler
                                                                    onHoveredChanged: {
                                                                        if (hovered) {
                                                                            fullRoot.emojiHoveredEmojiKey = (kitchenData.emoji1 && kitchenData.emoji2) ? (kitchenData.emoji1 + " + " + kitchenData.emoji2) : "";
                                                                            fullRoot.hoveredEmojiName = (kitchenData.emoji1 && kitchenData.emoji2) ? (kitchenData.emoji1 + " + " + kitchenData.emoji2) : i18n("Emoji Kitchen Mashup");
                                                                            fullRoot.emojiHoveredEmojiType = "kitchen";
                                                                            fullRoot.emojiHoveredKitchenUrl = kitchenData.url;
                                                                        } else {
                                                                            if (fullRoot.emojiHoveredKitchenUrl === kitchenData.url) {
                                                                                fullRoot.emojiHoveredEmojiKey = "";
                                                                                fullRoot.hoveredEmojiName = "";
                                                                                fullRoot.emojiHoveredKitchenUrl = "";
                                                                            }
                                                                        }
                                                                    }
                                                                }

                                                                MouseArea {
                                                                    id: kitchenMouseArea
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onClicked: function(mouse) {
                                                                        if (mouse.button === Qt.LeftButton) {
                                                                            let cmd = 'curl -sL "' + kitchenData.url + '" > /tmp/kmoji_copy.png && (wl-copy --type image/png < /tmp/kmoji_copy.png || xclip -selection clipboard -t image/png -i /tmp/kmoji_copy.png)';
                                                                            shellSource.connectSource(cmd);
                                                                            showPasteTemporaryMessage(i18n("Copied mashup to clipboard!"));

                                                                            fullRoot.addRecentItem("kitchen", kitchenData);

                                                                            if (plasmoid.configuration.CloseAfterSelection) {
                                                                                if (fullRoot.plasmoidItem)
                                                                                    fullRoot.plasmoidItem.expanded = false;
                                                                            }
                                                                        }
                                                                    }
                                                                }

                                                                PlasmaComponents.ToolButton {
                                                                    anchors.top: parent.top
                                                                    anchors.right: parent.right
                                                                    anchors.margins: 2
                                                                    icon.name: fullRoot.isFavoriteItem("kitchen", {
                                                                        url: kitchenData.url
                                                                    }) ? "bookmarks-bookmarked" : "bookmarks"
                                                                    visible: kitchenHoverHandler.hovered
                                                                    width: 18
                                                                    height: 18
                                                                    display: PlasmaComponents.ToolButton.IconOnly
                                                                    z: 10

                                                                    background: Rectangle {
                                                                        color: parent.pressed ? Kirigami.Theme.highlightColor : (parent.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.35) : Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.85))
                                                                        radius: 3
                                                                        border.color: (parent.pressed || parent.hovered) ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                                                                        border.width: 1
                                                                    }

                                                                    onClicked: {
                                                                        fullRoot.toggleFavoriteItem("kitchen", kitchenData);
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Component {
                            id: favRecGifDelegate

                            PC3.ItemDelegate {
                                id: favRecDelegateItem
                                property var itemData: model
                                width: favRecentsMasonryRow.columnWidth
                                height: Math.floor(width / (itemData.aspectRatio || 1.0))

                                onClicked: {
                                    gifView.copyGif(itemData.rawUrl, itemData.title, itemData.webpUrl, itemData.previewUrl, itemData.aspectRatio || 1.0);
                                    if (plasmoid.configuration.CloseAfterSelection) {
                                        if (fullRoot.plasmoidItem)
                                        fullRoot.plasmoidItem.expanded = false;
                                    }
                                }

                                HoverHandler {
                                    id: favRecGifDelegateHover
                                    cursorShape: Qt.PointingHandCursor
                                    onHoveredChanged: {
                                        if (hovered) {
                                            fullRoot.hoveredGifTitle = itemData.title;
                                            fullRoot.hoveredGifUrl = itemData.previewUrl;
                                        } else {
                                            if (fullRoot.hoveredGifUrl === itemData.previewUrl) {
                                                fullRoot.hoveredGifTitle = "";
                                                fullRoot.hoveredGifUrl = "";
                                            }
                                        }
                                    }
                                }

                                PlasmaComponents.ToolButton {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    icon.name: fullRoot.isFavoriteItem("gif", {
                                        rawUrl: itemData.rawUrl
                                    }) ? "bookmarks-bookmarked" : "bookmarks"
                                    visible: favRecGifDelegateHover.hovered
                                    width: 28
                                    height: 28
                                    display: PlasmaComponents.ToolButton.IconOnly
                                    z: 10

                                    background: Rectangle {
                                        color: parent.pressed ? Kirigami.Theme.highlightColor : (parent.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.35) : Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.85))
                                        radius: 4
                                        border.color: (parent.pressed || parent.hovered) ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                                        border.width: 1
                                    }

                                    onClicked: {
                                        fullRoot.toggleFavoriteItem("gif", {
                                            rawUrl: itemData.rawUrl,
                                            title: itemData.title,
                                            webpUrl: itemData.webpUrl || itemData.rawUrl,
                                            previewUrl: itemData.previewUrl,
                                            aspectRatio: itemData.aspectRatio
                                        });
                                    }
                                }

                                background: Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    color: Kirigami.Theme.alternateBackgroundColor
                                    radius: 6
                                    border.width: favRecGifDelegateHover.hovered ? 2 : 0
                                    border.color: Kirigami.Theme.highlightColor

                                    AnimatedImage {
                                        source: fullRoot.isWidgetExpanded ? itemData.previewUrl : ""
                                        anchors.fill: parent
                                        anchors.margins: favRecGifDelegateHover.hovered ? 1 : 2
                                        fillMode: Image.Stretch
                                        playing: alwaysAnimateGifs || favRecGifDelegateHover.hovered
                                        paused: !playing
                                        cache: true
                                    }
                                }
                            }
                        }
                        // Floating sticky header for Kaomoji
                        Item {
                            id: floatingStickyHeaderKaomoji
                            anchors.left: kaomojiView.left
                            anchors.right: kaomojiView.right
                            anchors.rightMargin: kaomojiView.ScrollBar.vertical.visible ? kaomojiView.ScrollBar.vertical.width : 0
                            height: 32
                            y: kaomojiView.activeStickyInfo ? kaomojiView.activeStickyInfo.offset : 0
                            z: 10
                            
                            visible: kaomojiView.visible && kaomojiView.activeStickyInfo !== null
                            
                            readonly property var info: kaomojiView.activeStickyInfo
                            property string catName: info ? info.catName : ""
                            property bool isExpanded: info ? info.isExpanded : false
                            property int count: info ? info.count : 0
                            
                            Rectangle {
                                anchors.fill: parent
                                color: Kirigami.Theme.backgroundColor
                                opacity: 0.95
                            }
                            
                            Rectangle {
                                anchors.fill: parent
                                color: stickyHeaderMouseKaomoji.pressed ? Kirigami.Theme.highlightColor : (stickyHeaderMouseKaomoji.containsMouse ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent")
                                border.color: (stickyHeaderMouseKaomoji.pressed || stickyHeaderMouseKaomoji.containsMouse) ? Kirigami.Theme.highlightColor : "transparent"
                                border.width: 1
                                radius: 4
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                
                                Item {
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    Kirigami.Icon {
                                        anchors.centerIn: parent
                                        source: floatingStickyHeaderKaomoji.isExpanded ? "go-down" : "go-next"
                                        width: 16
                                        height: 16
                                    }
                                }
                                
                                PlasmaComponents.Label {
                                    text: floatingStickyHeaderKaomoji.catName
                                    font.bold: true
                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.05
                                }
                                
                                PlasmaComponents.Label {
                                    text: floatingStickyHeaderKaomoji.count
                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.9
                                    color: Kirigami.Theme.disabledTextColor
                                }
                                
                                Rectangle {
                                     Layout.fillWidth: true
                                     height: 1
                                     color: Kirigami.Theme.textColor
                                     opacity: 0.3
                                 }
                            }
                            
                            MouseArea {
                                id: stickyHeaderMouseKaomoji
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.LeftButton && floatingStickyHeaderKaomoji.catName !== "") {
                                        kaomojiView.toggleCategory(floatingStickyHeaderKaomoji.catName);
                                    }
                                }
                            }
                        }

                        Item {
                            id: floatingStickyHeader
                            x: 0
                            y: allEmojisView.activeStickyInfo ? allEmojisView.activeStickyInfo.offset : 0
                            width: allEmojisView.width - (allEmojisView.ScrollBar.vertical.visible ? allEmojisView.ScrollBar.vertical.width : 0)
                            height: 32
                            z: 10
                            visible: allEmojisView.visible && allEmojisView.activeStickyInfo !== null

                            readonly property var info: allEmojisView.activeStickyInfo
                            readonly property string catName: info ? info.name : ""
                            readonly property bool isKitchen: info ? info.isKitchen : false
                            readonly property bool isExpanded: info ? (allEmojisView.categoryStates[catName] !== false) : true
                            readonly property int count: {
                                if (!info || isKitchen) return 0;
                                return (info.item && info.item.catEmojis) ? (info.item.catEmojis.length + info.item.catKitchens.length) : 0;
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Kirigami.Theme.backgroundColor
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: stickyHeaderMouse.pressed ? Kirigami.Theme.highlightColor : (stickyHeaderMouse.containsMouse ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent")
                                border.color: (stickyHeaderMouse.pressed || stickyHeaderMouse.containsMouse) ? Kirigami.Theme.highlightColor : "transparent"
                                border.width: 1
                                radius: 4
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Item {
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    Kirigami.Icon {
                                        anchors.centerIn: parent
                                        source: floatingStickyHeader.isExpanded ? "go-down" : "go-next"
                                        width: 16
                                        height: 16
                                    }
                                }

                                PlasmaComponents.Label {
                                    text: floatingStickyHeader.isKitchen ? i18n("Emoji Kitchen") : floatingStickyHeader.catName
                                    font.bold: true
                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.05
                                }

                                Rectangle {
                                    width: stickyCountLabel.contentWidth + 12
                                    height: 18
                                    radius: 9
                                    color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2)
                                    visible: !floatingStickyHeader.isKitchen

                                    PlasmaComponents.Label {
                                        id: stickyCountLabel
                                        anchors.centerIn: parent
                                        text: floatingStickyHeader.count
                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                        font.bold: true
                                        color: Kirigami.Theme.textColor
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Kirigami.Theme.textColor
                                    opacity: 0.3
                                }
                            }

                            MouseArea {
                                id: stickyHeaderMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.LeftButton && floatingStickyHeader.catName !== "") {
                                        allEmojisView.toggleCategory(floatingStickyHeader.catName);
                                    }
                                }
                            }
                        }

                        ScrollView {
                            id: favRecentsView
                            anchors.fill: parent
                            visible: false
                            clip: true

                            readonly property int countEmojis: fullRoot.activeEmojis.length
                            readonly property int countGifs: fullRoot.activeGifs.length
                            readonly property int countKitchen: fullRoot.activeKitchens.length

                            property bool isEmojisExpanded: fullRoot.selectedCategory === fullRoot.catFavorites ? fullRoot.favoritesEmojisExpanded : fullRoot.recentEmojisExpanded
                            property bool isGifsExpanded: fullRoot.selectedCategory === fullRoot.catFavorites ? fullRoot.favoritesGifsExpanded : fullRoot.recentGifsExpanded
                            property bool isKitchenExpanded: fullRoot.selectedCategory === fullRoot.catFavorites ? fullRoot.favoritesKitchenExpanded : fullRoot.recentKitchenExpanded

                            function toggleEmojisExpanded() {
                                if (fullRoot.selectedCategory === fullRoot.catFavorites) {
                                    fullRoot.favoritesEmojisExpanded = !fullRoot.favoritesEmojisExpanded;
                                } else {
                                    fullRoot.recentEmojisExpanded = !fullRoot.recentEmojisExpanded;
                                }
                            }

                            function toggleGifsExpanded() {
                                if (fullRoot.selectedCategory === fullRoot.catFavorites) {
                                    fullRoot.favoritesGifsExpanded = !fullRoot.favoritesGifsExpanded;
                                } else {
                                    fullRoot.recentGifsExpanded = !fullRoot.recentGifsExpanded;
                                }
                            }

                            function toggleKitchenExpanded() {
                                if (fullRoot.selectedCategory === fullRoot.catFavorites) {
                                    fullRoot.favoritesKitchenExpanded = !fullRoot.favoritesKitchenExpanded;
                                } else {
                                    fullRoot.recentKitchenExpanded = !fullRoot.recentKitchenExpanded;
                                }
                            }

                            Column {
                                id: favRecentsMainLayout
                                x: 8
                                y: 8
                                width: favRecentsView.width - 16
                                spacing: 16

                                Column {
                                    width: parent.width
                                    spacing: 0
                                    visible: favRecentsView.countEmojis > 0

                                    Item {
                                        id: emojisHeader
                                        width: parent.width
                                        height: 32

                                        property bool isExpanded: favRecentsView.isEmojisExpanded
                                        property string title: i18n("Emojis")
                                        property int count: favRecentsView.countEmojis

                                        Rectangle {
                                            anchors.fill: parent
                                            color: emojisHeaderMouse.pressed ? Kirigami.Theme.highlightColor : (emojisHeaderMouse.containsMouse ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent")
                                            border.color: (emojisHeaderMouse.pressed || emojisHeaderMouse.containsMouse) ? Kirigami.Theme.highlightColor : "transparent"
                                            border.width: 1
                                            radius: 4
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 4
                                            spacing: 8

                                            Item {
                                                implicitWidth: 16
                                                implicitHeight: 16
                                                Kirigami.Icon {
                                                    anchors.centerIn: parent
                                                    source: emojisHeader.isExpanded ? "go-down" : "go-next"
                                                    width: 16
                                                    height: 16
                                                }
                                            }

                                            PlasmaComponents.Label {
                                                text: emojisHeader.title
                                                font.bold: true
                                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.05
                                            }

                                            Rectangle {
                                                width: emojisCountLabel.contentWidth + 12
                                                height: 18
                                                radius: 9
                                                color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2)

                                                PlasmaComponents.Label {
                                                    id: emojisCountLabel
                                                    anchors.centerIn: parent
                                                    text: emojisHeader.count
                                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                    font.bold: true
                                                    color: Kirigami.Theme.highlightColor
                                                }
                                            }

                                            Kirigami.Separator {
                                                Layout.fillWidth: true
                                                opacity: 0.3
                                            }
                                        }

                                        MouseArea {
                                            id: emojisHeaderMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: function(mouse) {
                                                if (mouse.button === Qt.LeftButton) {
                                                    favRecentsView.toggleEmojisExpanded();
                                                }
                                            }
                                        }
                                    }

                                    Flow {
                                        width: parent.width
                                        spacing: 4
                                        visible: favRecentsView.isEmojisExpanded

                                        Repeater {
                                            model: fullRoot.activeEmojis

                                            delegate: Item {
                                                width: fullRoot.internalGridSize
                                                height: fullRoot.internalGridSize

                                                Rectangle {
                                                    anchors.fill: parent
                                                    anchors.margins: 2
                                                    color: Kirigami.Theme.highlightColor
                                                    radius: 4
                                                    opacity: emojiMouseArea.pressed ? 1.0 : (emojiMouseArea.containsMouse ? 0.2 : 0)
                                                }

                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: "transparent"
                                                    radius: 4
                                                    border.width: (emojiMouseArea.pressed || emojiMouseArea.containsMouse) ? 2 : 0
                                                    border.color: Kirigami.Theme.highlightColor
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.emoji
                                                    font.pixelSize: Math.floor(fullRoot.internalGridSize * 0.81)
                                                    font.family: "Noto Color Emoji"
                                                    renderType: Text.NativeRendering
                                                }

                                                MouseArea {
                                                    id: emojiMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                                                    onEntered: {
                                                        fullRoot.emojiHoveredEmojiKey = modelData.emoji;
                                                        fullRoot.hoveredEmojiName = modelData.name;
                                                    }

                                                    onExited: {
                                                        if (fullRoot.emojiHoveredEmojiKey === modelData.emoji) {
                                                            fullRoot.emojiHoveredEmojiKey = "";
                                                            fullRoot.hoveredEmojiName = "";
                                                        }
                                                    }

                                                    onClicked: function (mouse) {
                                                        if (mouse.button === Qt.LeftButton) {
                                                            fullRoot.handleEmojiSelected(modelData.emoji, mouse.modifiers & Qt.ControlModifier, mouse.modifiers & Qt.ShiftModifier, mouse.modifiers & Qt.AltModifier);
                                                        } else if (mouse.button === Qt.RightButton) {
                                                            var globalPos = mapToItem(fullRoot, mouse.x, mouse.y);
                                                            contextMenu.emoji = modelData.emoji;
                                                            contextMenu.emojiObj = modelData;
                                                            contextMenu.popup(globalPos.x, globalPos.y);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 0
                                    visible: favRecentsView.countGifs > 0

                                    Item {
                                        id: gifsHeader
                                        width: parent.width
                                        height: 32

                                        property bool isExpanded: favRecentsView.isGifsExpanded
                                        property string title: i18n("GIFs")
                                        property int count: favRecentsView.countGifs

                                        Rectangle {
                                            anchors.fill: parent
                                            color: gifsHeaderMouse.pressed ? Kirigami.Theme.highlightColor : (gifsHeaderMouse.containsMouse ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent")
                                            border.color: (gifsHeaderMouse.pressed || gifsHeaderMouse.containsMouse) ? Kirigami.Theme.highlightColor : "transparent"
                                            border.width: 1
                                            radius: 4
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 4
                                            spacing: 8

                                            Item {
                                                implicitWidth: 16
                                                implicitHeight: 16
                                                Kirigami.Icon {
                                                    anchors.centerIn: parent
                                                    source: gifsHeader.isExpanded ? "go-down" : "go-next"
                                                    width: 16
                                                    height: 16
                                                }
                                            }

                                            PlasmaComponents.Label {
                                                text: gifsHeader.title
                                                font.bold: true
                                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.05
                                            }

                                            Rectangle {
                                                width: gifsCountLabel.contentWidth + 12
                                                height: 18
                                                radius: 9
                                                color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2)

                                                PlasmaComponents.Label {
                                                    id: gifsCountLabel
                                                    anchors.centerIn: parent
                                                    text: gifsHeader.count
                                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                    font.bold: true
                                                    color: Kirigami.Theme.highlightColor
                                                }
                                            }

                                            Kirigami.Separator {
                                                Layout.fillWidth: true
                                                opacity: 0.3
                                            }
                                        }

                                        MouseArea {
                                            id: gifsHeaderMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: function(mouse) {
                                                if (mouse.button === Qt.LeftButton) {
                                                    favRecentsView.toggleGifsExpanded();
                                                }
                                            }
                                        }
                                    }

                                    Row {
                                        id: favRecentsMasonryRow
                                        width: parent.width
                                        spacing: 6
                                        visible: favRecentsView.isGifsExpanded

                                        readonly property int numColumns: fullRoot.favRecentsNumColumns
                                        readonly property int columnWidth: Math.floor((width - (numColumns - 1) * spacing) / numColumns)

                                        Column {
                                            spacing: 6
                                            width: favRecentsMasonryRow.columnWidth

                                            Repeater {
                                                model: favGifCol0Model
                                                delegate: favRecGifDelegate
                                            }
                                        }

                                        Column {
                                            spacing: 6
                                            width: favRecentsMasonryRow.columnWidth

                                            Repeater {
                                                model: favGifCol1Model
                                                delegate: favRecGifDelegate
                                            }
                                        }

                                        Column {
                                            spacing: 6
                                            width: favRecentsMasonryRow.columnWidth
                                            visible: favRecentsMasonryRow.numColumns >= 3

                                            Repeater {
                                                model: favGifCol2Model
                                                delegate: favRecGifDelegate
                                            }
                                        }

                                        Column {
                                            spacing: 6
                                            width: favRecentsMasonryRow.columnWidth
                                            visible: favRecentsMasonryRow.numColumns >= 4

                                            Repeater {
                                                model: favGifCol3Model
                                                delegate: favRecGifDelegate
                                            }
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 0
                                    visible: favRecentsView.countKitchen > 0

                                    Item {
                                        id: kitchenHeader
                                        width: parent.width
                                        height: 32

                                        property bool isExpanded: favRecentsView.isKitchenExpanded
                                        property string title: i18n("Emoji Kitchen")
                                        property int count: favRecentsView.countKitchen

                                        Rectangle {
                                            anchors.fill: parent
                                            color: kitchenHeaderMouse.pressed ? Kirigami.Theme.highlightColor : (kitchenHeaderMouse.containsMouse ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.1) : "transparent")
                                            border.color: (kitchenHeaderMouse.pressed || kitchenHeaderMouse.containsMouse) ? Kirigami.Theme.highlightColor : "transparent"
                                            border.width: 1
                                            radius: 4
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 4
                                            spacing: 8

                                            Item {
                                                implicitWidth: 16
                                                implicitHeight: 16
                                                Kirigami.Icon {
                                                    anchors.centerIn: parent
                                                    source: kitchenHeader.isExpanded ? "go-down" : "go-next"
                                                    width: 16
                                                    height: 16
                                                }
                                            }

                                            PlasmaComponents.Label {
                                                text: kitchenHeader.title
                                                font.bold: true
                                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.05
                                            }

                                            Rectangle {
                                                width: kitchenCountLabel.contentWidth + 12
                                                height: 18
                                                radius: 9
                                                color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2)

                                                PlasmaComponents.Label {
                                                    id: kitchenCountLabel
                                                    anchors.centerIn: parent
                                                    text: kitchenHeader.count
                                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                                    font.bold: true
                                                    color: Kirigami.Theme.highlightColor
                                                }
                                            }

                                            Kirigami.Separator {
                                                Layout.fillWidth: true
                                                opacity: 0.3
                                            }
                                        }

                                        MouseArea {
                                            id: kitchenHeaderMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: function(mouse) {
                                                if (mouse.button === Qt.LeftButton) {
                                                    favRecentsView.toggleKitchenExpanded();
                                                }
                                            }
                                        }
                                    }

                                    Flow {
                                        width: parent.width
                                        spacing: 8
                                        visible: favRecentsView.isKitchenExpanded

                                        Repeater {
                                            model: fullRoot.activeKitchens

                                            delegate: Item {
                                                width: 64
                                                height: 64

                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: Kirigami.Theme.alternateBackgroundColor
                                                    border.color: (kitchenHoverHandler.hovered || kitchenMouseArea.pressed) ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                                                    border.width: (kitchenHoverHandler.hovered || kitchenMouseArea.pressed) ? 2 : 1
                                                    radius: 8

                                                    Image {
                                                        anchors.fill: parent
                                                        anchors.margins: 4
                                                        source: modelData.url
                                                        sourceSize: Qt.size(256, 256)
                                                        fillMode: Image.PreserveAspectFit
                                                        smooth: true
                                                        mipmap: true
                                                    }

                                                    HoverHandler {
                                                        id: kitchenHoverHandler
                                                        onHoveredChanged: {
                                                            if (hovered) {
                                                                fullRoot.emojiHoveredEmojiKey = (modelData.emoji1 && modelData.emoji2) ? (modelData.emoji1 + " + " + modelData.emoji2) : "";
                                                                fullRoot.hoveredEmojiName = (modelData.emoji1 && modelData.emoji2) ? (modelData.emoji1 + " + " + modelData.emoji2) : i18n("Emoji Kitchen Mashup");
                                                                fullRoot.emojiHoveredEmojiType = "kitchen";
                                                                fullRoot.emojiHoveredKitchenUrl = modelData.url;
                                                            } else {
                                                                if (fullRoot.emojiHoveredKitchenUrl === modelData.url) {
                                                                    fullRoot.emojiHoveredEmojiKey = "";
                                                                    fullRoot.hoveredEmojiName = "";
                                                                    fullRoot.emojiHoveredKitchenUrl = "";
                                                                }
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: kitchenMouseArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            let cmd = 'curl -sL "' + modelData.url + '" > /tmp/kmoji_copy.png && (wl-copy --type image/png < /tmp/kmoji_copy.png || xclip -selection clipboard -t image/png -i /tmp/kmoji_copy.png)';
                                                            shellSource.connectSource(cmd);
                                                            showPasteTemporaryMessage(i18n("Copied mashup to clipboard!"));

                                                            fullRoot.addRecentItem("kitchen", modelData);

                                                            if (plasmoid.configuration.CloseAfterSelection) {
                                                                if (fullRoot.plasmoidItem)
                                                                fullRoot.plasmoidItem.expanded = false;
                                                            }
                                                        }
                                                    }

                                                    PlasmaComponents.ToolButton {
                                                        anchors.top: parent.top
                                                        anchors.right: parent.right
                                                        anchors.margins: 2
                                                        icon.name: fullRoot.isFavoriteItem("kitchen", {
                                                            url: modelData.url
                                                        }) ? "bookmarks-bookmarked" : "bookmarks"
                                                        visible: kitchenHoverHandler.hovered
                                                        width: 18
                                                        height: 18
                                                        display: PlasmaComponents.ToolButton.IconOnly
                                                        z: 10

                                                        background: Rectangle {
                                                            color: parent.pressed ? Kirigami.Theme.highlightColor : (parent.hovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.35) : Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.85))
                                                            radius: 3
                                                            border.color: (parent.pressed || parent.hovered) ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                                                            border.width: 1
                                                        }

                                                        onClicked: {
                                                            fullRoot.toggleFavoriteItem("kitchen", modelData);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        PlasmaComponents.Label {
                            anchors.centerIn: parent
                            text: i18n("No results found :(")
                            font.pixelSize: fontSizeEmptyLabel
                            color: Kirigami.Theme.textColor
                            opacity: 0.6
                            visible: fullRoot.selectedCategory !== fullRoot.catGifs && fullRoot.selectedCategory !== fullRoot.catEmojiKitchen && fullRoot.selectedCategory !== fullRoot.catKaomoji && fullRoot.filteredEmojis.length === 0
                        }
                    }
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                Item {
                    id: previewBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: topSection.implicitHeight + 16
                    Kirigami.Theme.colorSet: Kirigami.Theme.Window
                    Kirigami.Theme.inherit: false

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: previewBar.height - 16
                            Layout.preferredHeight: previewBar.height - 16
                            Layout.alignment: Qt.AlignVCenter
                            color: "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: fullRoot.emojiHoveredEmojiKey
                                font.pixelSize: (fullRoot.selectedCategory === fullRoot.catEmojiKitchen || fullRoot.emojiHoveredEmojiType === "kitchen") ? Math.floor((previewBar.height - 20) * 1.18) : (previewBar.height - 20)
                                font.family: (fullRoot.selectedCategory === fullRoot.catEmojiKitchen || fullRoot.emojiHoveredEmojiType === "kitchen") ? "Noto Color Emoji" : Kirigami.Theme.defaultFont.family
                                visible: fullRoot.selectedCategory !== fullRoot.catGifs && fullRoot.emojiHoveredEmojiKey !== "" && fullRoot.emojiHoveredKitchenUrl === ""
                                color: Kirigami.Theme.textColor
                                renderType: Text.NativeRendering
                            }

                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: fullRoot.emojiHoveredKitchenUrl
                                sourceSize: Qt.size(128, 128)
                                fillMode: Image.PreserveAspectFit
                                visible: fullRoot.selectedCategory !== fullRoot.catGifs && fullRoot.emojiHoveredKitchenUrl !== ""
                                smooth: true
                                mipmap: true
                            }

                            AnimatedImage {
                                anchors.fill: parent
                                source: fullRoot.hoveredGifUrl
                                fillMode: Image.PreserveAspectFit
                                visible: fullRoot.selectedCategory === fullRoot.catGifs && fullRoot.hoveredGifUrl !== ""
                                playing: true
                            }

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                source: fullRoot.selectedCategory === fullRoot.catGifs ? "fileview-preview-symbolic" : "preferences-desktop-emoticons-symbolic"
                                width: parent.height
                                height: parent.height
                                color: Kirigami.Theme.disabledTextColor
                                visible: fullRoot.selectedCategory === fullRoot.catGifs ? (fullRoot.hoveredGifUrl === "") : (fullRoot.emojiHoveredEmojiKey === "" && fullRoot.emojiHoveredKitchenUrl === "")
                            }
                        }

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: {
                                if (fullRoot.selectedCategory === fullRoot.catGifs) {
                                    return fullRoot.hoveredGifTitle !== "" ? fullRoot.hoveredGifTitle : i18n("Hover over a GIF to animate it...");
                                }
                                return fullRoot.emojiHoveredEmojiKey !== "" ? fullRoot.hoveredEmojiName : i18n("Hover over an emoji for details...");
                            }
                            font.pixelSize: fontSizePreviewLabel
                            font.bold: false
                            elide: Text.ElideRight
                            color: (fullRoot.emojiHoveredEmojiKey !== "" || (fullRoot.selectedCategory === fullRoot.catGifs && fullRoot.hoveredGifTitle !== "")) ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                            visible: true
                        }
                    }
                }
            }

            PC3.Menu {
                id: contextMenu
                property string emoji: ""
                property var emojiObj: null

                PC3.MenuItem {
                    text: i18n("Copy Emoji")
                    icon.name: "edit-copy"
                    onClicked: {
                        clipboard.content = contextMenu.emoji;
                        showCopiedFeedback(contextMenu.emoji, contextMenu.emojiObj ? contextMenu.emojiObj.name : "");
                    }
                }

                PC3.MenuItem {
                    text: i18n("Copy Name")
                    icon.name: "edit-copy"
                    enabled: contextMenu.emojiObj && contextMenu.emojiObj.name && contextMenu.emojiObj.name.length > 0
                    onClicked: {
                        if (contextMenu.emojiObj && contextMenu.emojiObj.name && contextMenu.emojiObj.name.length > 0) {
                            clipboard.content = contextMenu.emojiObj.name;
                            showPasteTemporaryMessage(i18n("Copied: %1 (%2)", contextMenu.emojiObj.name, contextMenu.emoji));
                        } else {
                            clipboard.content = contextMenu.emoji;
                            showPasteTemporaryMessage(i18n("Copied: %1", contextMenu.emoji));
                        }
                    }
                }

                PC3.MenuItem {
                    text: isFavorite(contextMenu.emoji) ? i18n("Unfavorite Emoji") : i18n("Favorite Emoji")
                    icon.name: isFavorite(contextMenu.emoji) ? "bookmarks" : "bookmarks-bookmarked"
                    onClicked: {
                        toggleFavoriteEmoji(contextMenu.emojiObj);
                    }
                }
            }

            PC3.Menu {
                id: emojiSidebarContextMenu
                PC3.MenuItem {
                    text: i18n("Clear Favorite Emojis")
                    icon.name: "edit-clear"
                    onClicked: {
                        clearFavoriteEmojis();
                        showSearchTemporaryMessage(i18n("Cleared favorite emojis"));
                    }
                }
                PC3.MenuItem {
                    text: i18n("Clear Recent Emojis")
                    icon.name: "edit-clear"
                    onClicked: {
                        clearRecentEmojis();
                        showSearchTemporaryMessage(i18n("Cleared recent emojis"));
                    }
                }
            }

            PC3.Menu {
                id: gifSidebarContextMenu
                PC3.MenuItem {
                    text: i18n("Clear Favorite GIFs")
                    icon.name: "edit-clear"
                    onClicked: {
                        clearFavoriteGifs();
                        showSearchTemporaryMessage(i18n("Cleared favorite GIFs"));
                    }
                }
                PC3.MenuItem {
                    text: i18n("Clear Recent GIFs")
                    icon.name: "edit-clear"
                    onClicked: {
                        clearRecentGifs();
                        showSearchTemporaryMessage(i18n("Cleared recent GIFs"));
                    }
                }
            }

            Shortcut {
                sequences: [StandardKey.Escape]
                context: Qt.ApplicationShortcut
                onActivated: {
                    if (fullRoot.plasmoidItem) {
                        fullRoot.plasmoidItem.expanded = false;
                    }
                }
            }

            Shortcut {
                sequences: ["Ctrl+Return", "Ctrl+Enter"]
                context: Qt.ApplicationShortcut
                enabled: fullRoot.selectedCategory !== fullRoot.catEmojiKitchen && fullRoot.selectedCategory !== fullRoot.catGifs
                onActivated: {
                    if (!plasmoid.configuration.KeyboardNavigation)
                    return;
                    let currentEmoji = null;
                    if (emojiGridView.currentIndex >= 0 && emojiGridView.currentIndex < fullRoot.filteredEmojis.length) {
                        currentEmoji = fullRoot.filteredEmojis[emojiGridView.currentIndex];
                    } else if (fullRoot.emojiHoveredEmojiKey) {
                        currentEmoji = fullRoot.filteredEmojis.find(e => e.emoji === fullRoot.emojiHoveredEmojiKey);
                    } else if (fullRoot.emojiLastHoveredEmojiKey) {
                        currentEmoji = fullRoot.filteredEmojis.find(e => e.emoji === fullRoot.emojiLastHoveredEmojiKey);
                    }
                    if (currentEmoji && currentEmoji.emoji) {
                        handleEmojiSelected(currentEmoji.emoji, true);
                    }
                }
            }
        }
    }
}
