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
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

import "../assets/emoji-list.js" as EmojiList

Item {
    id: fullRoot

    // =========================================================================
    // Properties & Configuration
    // =========================================================================

    // Layout
    implicitHeight: Math.max(Kirigami.Units.gridUnit * 24, minimumRequiredHeight)

    // Colors
    readonly property color highContrastSectionColor: PlasmaCore.Theme.backgroundColor
    readonly property color lowContrastSectionColor: PlasmaCore.Theme.viewBackgroundColor

    // State
    property var plasmoidItem: null
    property bool sidebarExpanded: false
    property bool isAnyCategoryDragging: false
    property var selectedEmojis: []

    // Search & Feedback
    property string hoveredEmoji: ""
    property string hoveredEmojiName: ""
    property string defaultPastePlaceholder: i18n("Paste emojis…")
    property string searchPlaceholderText: i18n("Search emojis…")
    property bool searchPlaceholderMessageActive: false

    // Grid Configuration
    property int internalGridSize: {
        var configValue = plasmoid.configuration.GridSize
        if (configValue === undefined || configValue === null) {
            return 44
        }
        return configValue
    }

    // EmojiView Integration Properties
    property var emojiViewModel: []
    property alias emojiGridView: emojiGridView
    property var emojiExternalScrollBar: null
    property string emojiHoveredEmojiKey: ""
    property string emojiLastHoveredEmojiKey: ""
    property bool emojiKeyboardNavigationEnabled: plasmoid.configuration.KeyboardNavigation
    property Item emojiTabNextTarget: searchField
    property Item emojiTabPreviousTarget: categoryRepeater.count > 0 ? (categoryRepeater.itemAt(categoryRepeater.count - 1) ? categoryRepeater.itemAt(categoryRepeater.count - 1) : sidebarToggleButton) : sidebarToggleButton

    // Height Calculation Properties
    property int categoryHeight: 32
    property int categorySpacing: 2
    property int pinButtonHeight: 32
    property int settingsButtonHeight: 32
    property int toggleButtonHeight: 32
    property int separatorHeight: 1
    property int fallbackTopSectionHeight: 76
    property int fallbackPreviewHeight: 76
    property int minimumRequiredHeight: {
        var categoryCount = categoryModel ? categoryModel.count : 0
        var fallbackCategories = 0
        if (categoryCount > 0) {
            fallbackCategories = (categoryCount * categoryHeight) + Math.max(0, categoryCount - 1) * categorySpacing
        }

        var topBlock = topSection ? (topSection.implicitHeight + 16) : fallbackTopSectionHeight
        var bottomBlock = previewBar ? previewBar.Layout.preferredHeight : fallbackPreviewHeight
        var sidebarButtons = (pinButton ? pinButton.implicitHeight : pinButtonHeight) +
        (settingsButtonInSidebar ? settingsButtonInSidebar.implicitHeight : settingsButtonHeight) +
        (sidebarToggleButton ? sidebarToggleButton.implicitHeight : toggleButtonHeight)
        var categoriesBlock = categoryColumn ? categoryColumn.implicitHeight : fallbackCategories

        return topBlock + separatorHeight + sidebarButtons + categoriesBlock + separatorHeight + bottomBlock
    }

    // Default Categories
    property var defaultCategoryOrder: [
        { name: "All", displayName: i18n("All"), icon: "view-list-icons" },
        { name: "Favorites", displayName: i18n("Favorites"), icon: "bookmarks-bookmarked" },
        { name: "Recent", displayName: i18n("Recent"), icon: "chronometer" },
        { name: "Smileys & Emotion", displayName: i18n("Smileys & Emotion"), icon: "smiley" },
        { name: "People & Body", displayName: i18n("People & Body"), icon: "im-user" },
        { name: "Animals & Nature", displayName: i18n("Animals & Nature"), icon: "animal" },
        { name: "Food & Drink", displayName: i18n("Food & Drink"), icon: "food" },
        { name: "Activities", displayName: i18n("Activities"), icon: "games-highscores" },
        { name: "Travel & Places", displayName: i18n("Travel & Places"), icon: "globe" },
        { name: "Objects", displayName: i18n("Objects"), icon: "object-group" },
        { name: "Symbols", displayName: i18n("Symbols"), icon: "checkbox" },
        { name: "Flags", displayName: i18n("Flags"), icon: "flag" }
    ]

    // =========================================================================
    // Data Logic
    // =========================================================================

    property var emojiList: []
    property string filter: ""
    property var filteredEmojis: []
    property string selectedCategory: "All"
    property var recentEmojis: []
    property var favoriteEmojis: []

    Settings {
        id: settings
        category: "RecentEmojis"
        property string recentEmojisJson: "[]"
        property string favoriteEmojisJson: "[]"
    }

    function loadEmojis() {
        try {
            const rawData = EmojiList.emojiList
            const entries = []

            for (const category in rawData) {
                if (!Object.prototype.hasOwnProperty.call(rawData, category)) continue
                    const emojiArray = rawData[category] || []
                    const arrayLength = emojiArray.length

                    for (let i = 0; i < arrayLength; i++) {
                        const item = emojiArray[i]
                        const itemName = item.name || ""
                        const itemAliases = item.aliases || []
                        const itemTags = item.tags || []

                        entries.push({
                            emoji: item.emoji,
                            name: itemName,
                            slug: itemName ? itemName.toLowerCase().replace(/[^a-z0-9]+/g, '-') : "",
                                     group: category,
                                     aliases: itemAliases,
                                     tags: itemTags,
                                     emoji_version: "",
                                     unicode_version: ""
                        })
                    }
            }
            emojiList = entries
            console.log("Successfully loaded", entries.length, "emojis from Unicode data (including all variants)")
            updateFilteredEmojis()
        } catch (e) {
            console.log("Error loading emojis:", e)
        }
    }

    function loadRecentEmojis() {
        try {
            if (settings.recentEmojisJson && settings.recentEmojisJson !== "[]") {
                recentEmojis = JSON.parse(settings.recentEmojisJson)
                if (recentEmojis.length > 50) {
                    recentEmojis = recentEmojis.slice(0, 50)
                    try {
                        settings.recentEmojisJson = JSON.stringify(recentEmojis)
                    } catch (e) {
                        console.log("Failed to save trimmed recent emojis:", e)
                    }
                }
            } else {
                recentEmojis = []
            }
        } catch (e) {
            console.log("Failed to load recent emojis:", e)
            recentEmojis = []
        }
    }

    function loadFavoriteEmojis() {
        try {
            if (settings.favoriteEmojisJson && settings.favoriteEmojisJson !== "[]") {
                favoriteEmojis = JSON.parse(settings.favoriteEmojisJson)
            }
        } catch (e) {
            console.log("Failed to load favorite emojis:", e)
            favoriteEmojis = []
        }
    }

    function addRecentEmoji(emoji) {
        let newRecentEmojis = []
        let found = false

        for (let i = 0; i < recentEmojis.length; i++) {
            if (!found && recentEmojis[i].emoji === emoji.emoji) {
                found = true
                continue
            }
            newRecentEmojis.push(recentEmojis[i])
        }

        newRecentEmojis.unshift(emoji)

        if (newRecentEmojis.length > 50) {
            newRecentEmojis = newRecentEmojis.slice(0, 50)
        }

        recentEmojis = newRecentEmojis
        try {
            settings.recentEmojisJson = JSON.stringify(recentEmojis)
        } catch (e) {
            console.log("Failed to save recent emojis:", e)
        }
    }

    function toggleFavoriteEmoji(emoji) {
        if (!emoji) return false
            let isFavoriteNow = false
            const index = favoriteEmojis.findIndex(e => e.emoji === emoji.emoji)
            if (index >= 0) {
                favoriteEmojis.splice(index, 1)
                isFavoriteNow = false
            } else {
                favoriteEmojis.push(emoji)
                isFavoriteNow = true
            }
            favoriteEmojis = favoriteEmojis.slice()
            saveFavoriteEmojis()
            updateFilteredEmojis()
            return isFavoriteNow
    }

    function isFavorite(emoji) {
        const len = favoriteEmojis.length
        for (let i = 0; i < len; i++) {
            if (favoriteEmojis[i].emoji === emoji) {
                return true
            }
        }
        return false
    }

    function saveFavoriteEmojis() {
        try {
            settings.favoriteEmojisJson = JSON.stringify(favoriteEmojis)
        } catch (e) {
            console.log("Failed to save favorite emojis:", e)
        }
    }

    function clearRecentEmojis() {
        recentEmojis = []
        try {
            settings.recentEmojisJson = "[]"
        } catch (e) {
            console.log("Failed to clear recent emojis:", e)
        }
        updateFilteredEmojis()
    }

    function clearFavoriteEmojis() {
        favoriteEmojis = []
        try {
            settings.favoriteEmojisJson = "[]"
        } catch (e) {
            console.log("Failed to clear favorite emojis:", e)
        }
        updateFilteredEmojis()
    }

    function performFilter(list, searchText) {
        if (!searchText || searchText.trim() === "") {
            return list
        }

        const lowerFilter = searchText.toLowerCase()
        let searchRegex = null
        try {
            searchRegex = new RegExp(searchText.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i')
        } catch (e) {
            searchRegex = null
        }

        return list.filter(e => {
            if (e.emoji && searchRegex && searchRegex.test(e.emoji)) return true
                if (e.emoji && e.emoji.indexOf(searchText) !== -1) return true

                    if (e.name) {
                        if (searchRegex && searchRegex.test(e.name)) return true
                            if (e.name.toLowerCase().indexOf(lowerFilter) !== -1) return true
                    }

                    if (e.slug) {
                        if (searchRegex && searchRegex.test(e.slug)) return true
                            if (e.slug.toLowerCase().indexOf(lowerFilter) !== -1) return true
                    }

                    if (e.group) {
                        if (searchRegex && searchRegex.test(e.group)) return true
                            if (e.group.toLowerCase().indexOf(lowerFilter) !== -1) return true
                    }

                    if (e.aliases && e.aliases.length > 0) {
                        const aliasLen = e.aliases.length
                        for (let i = 0; i < aliasLen; i++) {
                            if (e.aliases[i] &&
                                (searchRegex && searchRegex.test(e.aliases[i]) ||
                                e.aliases[i].toLowerCase().indexOf(lowerFilter) !== -1)) {
                                return true
                                }
                        }
                    }

                    if (e.tags && e.tags.length > 0) {
                        const tagLen = e.tags.length
                        for (let i = 0; i < tagLen; i++) {
                            if (e.tags[i] &&
                                (searchRegex && searchRegex.test(e.tags[i]) ||
                                e.tags[i].toLowerCase().indexOf(lowerFilter) !== -1)) {
                                return true
                                }
                        }
                    }

                    return false
        })
    }

    function updateFilteredEmojis() {
        if (emojiList.length === 0) {
            filteredEmojis = [];
            return
        }

        let result = emojiList

        if (selectedCategory === "Recent") {
            result = recentEmojis
        } else if (selectedCategory === "Favorites") {
            result = favoriteEmojis
        } else if (selectedCategory !== "All") {
            result = emojiList.filter(e => e.group === selectedCategory)
        }

        if (filter && filter.trim() !== "") {
            result = performFilter(result, filter)

            if (result.length === 0 && selectedCategory !== "All") {
                const globalResult = performFilter(emojiList, filter)
                if (globalResult.length > 0) {
                    selectedCategory = "All"
                    return
                }
            }
        }
        filteredEmojis = result
    }

    onFilterChanged: updateFilteredEmojis()
    onSelectedCategoryChanged: {
        updateFilteredEmojis()
        if (!fullRoot.searchPlaceholderMessageActive) {
            fullRoot.resetSearchPlaceholder()
        }
    }

    onEmojiListChanged: {
        if (fullRoot.selectedCategory === "All" && !fullRoot.searchPlaceholderMessageActive) {
            fullRoot.resetSearchPlaceholder()
        }
    }

    onFilteredEmojisChanged: {
        fullRoot.emojiViewModel = fullRoot.filteredEmojis

        if (fullRoot.filter && fullRoot.filter.length > 0 && fullRoot.emojiViewModel.length > 0) {
            const firstItem = fullRoot.emojiViewModel[0]
            fullRoot.emojiHoveredEmojiKey = firstItem.emoji
            fullRoot.hoveredEmoji = firstItem.emoji
            fullRoot.hoveredEmojiName = firstItem.name
            fullRoot.emojiLastHoveredEmojiKey = firstItem.emoji

            if (emojiGridView) {
                emojiGridView.currentIndex = 0
            }
        }
    }

    // =========================================================================
    // Helper Functions (Navigation & Actions)
    // =========================================================================

    function emojiModelLength() {
        if (!fullRoot.emojiViewModel) return 0
            if (fullRoot.emojiViewModel.length !== undefined) return fullRoot.emojiViewModel.length
                if (fullRoot.emojiViewModel.count !== undefined) return fullRoot.emojiViewModel.count
                    return 0
    }

    function emojiModelItemAt(index) {
        if (!fullRoot.emojiViewModel || index < 0) return null
            if (fullRoot.emojiViewModel.length !== undefined) {
                if (index >= fullRoot.emojiViewModel.length) return null
                    return fullRoot.emojiViewModel[index]
            }
            if (typeof fullRoot.emojiViewModel.get === "function") {
                return fullRoot.emojiViewModel.get(index)
            }
            return null
    }

    function emojiIndexForEmojiKey(key) {
        if (!key || key.length === 0) return -1
            const length = emojiModelLength()
            for (let i = 0; i < length; i++) {
                const item = emojiModelItemAt(i)
                if (item && item.emoji === key) return i
            }
            return -1
    }

    function emojiEnsureKeyboardAnchorIndex() {
        if (!emojiGridView || emojiGridView.count === 0) return -1
            if (emojiGridView.currentIndex >= 0 && emojiGridView.currentIndex < emojiGridView.count) {
                return emojiGridView.currentIndex
            }

            const keyCandidates = [fullRoot.emojiHoveredEmojiKey, fullRoot.emojiHoveredEmojiKey]
            for (let i = 0; i < keyCandidates.length; i++) {
                const candidate = keyCandidates[i]
                const candidateIndex = emojiIndexForEmojiKey(candidate)
                if (candidateIndex >= 0) {
                    emojiGridView.currentIndex = candidateIndex
                    emojiGridView.updateKeyboardHover()
                    return candidateIndex
                }
            }

            emojiGridView.currentIndex = 0
            emojiGridView.updateKeyboardHover()
            return 0
    }

    function emojiEstimateNavigationColumns() {
        if (!emojiGridView) return 1
            const cellWidth = emojiGridView.cellWidth > 0 ? emojiGridView.cellWidth : fullRoot.internalGridSize
            if (cellWidth <= 0) return 1
                const availableWidth = emojiGridView.width > 0 ? emojiGridView.width : emojiArea.width
                const columns = Math.floor(availableWidth / cellWidth)
                return Math.max(1, columns)
    }

    function emojiManualMoveCurrentIndex(key) {
        if (!emojiGridView || emojiGridView.count === 0) return false

            let index = emojiGridView.currentIndex
            if (index < 0) index = 0

                const count = emojiGridView.count
                const columns = emojiEstimateNavigationColumns()
                let newIndex = index

                switch (key) {
                    case Qt.Key_Left:
                        if (index > 0) newIndex = index - 1
                            else if (emojiGridView.keyNavigationWraps && count > 0) newIndex = count - 1
                                break
                    case Qt.Key_Right:
                        if (index + 1 < count) newIndex = index + 1
                            else if (emojiGridView.keyNavigationWraps && count > 0) newIndex = 0
                                break
                    case Qt.Key_Up:
                        const candidateUp = index - columns
                        if (candidateUp >= 0) {
                            newIndex = candidateUp
                        } else if (emojiGridView.keyNavigationWraps && count > 0) {
                            const remainder = index % columns
                            let wrapped = Math.floor((count - 1) / columns) * columns + remainder
                            if (wrapped >= count) wrapped = count - 1
                                newIndex = wrapped
                        }
                        break
                    case Qt.Key_Down:
                        const candidateDown = index + columns
                        if (candidateDown < count) {
                            newIndex = candidateDown
                        } else if (emojiGridView.keyNavigationWraps && count > 0) {
                            let wrapped = index % columns
                            if (wrapped >= count) wrapped = count - 1
                                newIndex = wrapped
                        }
                        break
                    default:
                        break
                }

                if (newIndex !== index) {
                    emojiGridView.currentIndex = newIndex
                    return true
                }
                return false
    }

    function emojiHandleExternalArrowKey(key) {
        if (!fullRoot.emojiKeyboardNavigationEnabled) return false
            if (!emojiGridView || emojiGridView.count === 0) return false
                if (key !== Qt.Key_Left && key !== Qt.Key_Right && key !== Qt.Key_Up && key !== Qt.Key_Down) return false

                    emojiEnsureKeyboardAnchorIndex()
                    const previousIndex = emojiGridView.currentIndex
                    emojiManualMoveCurrentIndex(key)

                    if (emojiGridView.currentIndex !== previousIndex) {
                        if (typeof emojiGridView.positionViewAtIndex === "function") {
                            emojiGridView.positionViewAtIndex(emojiGridView.currentIndex, GridView.Contain)
                        }
                        emojiGridView.updateKeyboardHover()
                        return true
                    }
                    return false
    }

    function getCurrentFocusedEmoji() {
        if (emojiGridView.currentIndex >= 0 && emojiGridView.currentIndex < fullRoot.emojiViewModel.length) {
            return fullRoot.emojiViewModel[emojiGridView.currentIndex]
        }
        if (fullRoot.emojiHoveredEmojiKey) {
            for (let i = 0; i < fullRoot.emojiViewModel.length; i++) {
                if (fullRoot.emojiViewModel[i].emoji === fullRoot.emojiHoveredEmojiKey) {
                    return fullRoot.emojiViewModel[i]
                }
            }
        }
        if (fullRoot.emojiLastHoveredEmojiKey) {
            for (let i = 0; i < fullRoot.emojiViewModel.length; i++) {
                if (fullRoot.emojiViewModel[i].emoji === fullRoot.emojiLastHoveredEmojiKey) {
                    return fullRoot.emojiViewModel[i]
                }
            }
        }
        return null
    }

    function handleEmojiSelected(emoji, isCtrlClick, isShiftClick) {
        const emojiObj = fullRoot.emojiList.find(e => e.emoji === emoji) || {
            emoji: emoji,
            name: "",
            slug: "",
            group: ""
        }

        if (isCtrlClick) {
            const index = fullRoot.selectedEmojis.findIndex(e => e === emoji)
            if (index >= 0) {
                fullRoot.selectedEmojis.splice(index, 1)
            } else {
                fullRoot.selectedEmojis.push(emoji)
            }
            fullRoot.selectedEmojis = fullRoot.selectedEmojis.slice()

            if (fullRoot.selectedEmojis.length > 0) {
                pasteField.placeholderText = i18n("Selected %1 emoji(s)", fullRoot.selectedEmojis.length)
            } else {
                pasteField.placeholderText = fullRoot.defaultPastePlaceholder
            }
        } else {
            if (fullRoot.selectedEmojis.length > 0) {
                const combined = fullRoot.selectedEmojis.join("")
                clipboard.content = combined
                showCopiedFeedback(combined, fullRoot.selectedEmojis.length + " emojis")
                fullRoot.selectedEmojis = []
            } else {
                if (isShiftClick) {
                    if (emojiObj.name && emojiObj.name.length > 0) {
                        clipboard.content = emojiObj.name
                        addRecentEmoji(emojiObj)
                        showCopiedFeedback(emojiObj.name, emojiObj.emoji)
                    } else {
                        clipboard.content = emoji
                        addRecentEmoji(emojiObj)
                        showCopiedFeedback(emoji, "")
                    }
                } else {
                    clipboard.content = emoji
                    addRecentEmoji(emojiObj)
                    showCopiedFeedback(emoji, emojiObj.name)
                }
            }

            if (plasmoid.configuration.CloseAfterSelection) {
                if (fullRoot.plasmoidItem) {
                    fullRoot.plasmoidItem.expanded = false
                }
            }
        }
    }

    function handleEmojiRightClicked(emoji, emojiObj, pos) {
        contextMenu.emoji = emoji
        contextMenu.emojiObj = emojiObj
        contextMenu.popup(emojiGridView, pos.x, pos.y)
    }

    function loadDefaultCategories() {
        categoryModel.clear()
        for (var i = 0; i < defaultCategoryOrder.length; i++) {
            categoryModel.append(defaultCategoryOrder[i])
        }
    }

    function saveCategoryOrder() {
        var order = []
        for (var i = 0; i < categoryModel.count; i++) {
            order.push({
                name: categoryModel.get(i).name,
                       icon: categoryModel.get(i).icon
            })
        }
        plasmoid.configuration.CategoryOrder = JSON.stringify(order)
    }

    function getSearchPlaceholder() {
        if (fullRoot.selectedCategory === "All") {
            return i18n("Search %1 emojis...", fullRoot.emojiList.length)
        }
        const emojiCount = fullRoot.filteredEmojis.length
        if (emojiCount === 0) return i18n("Search emojis…")
            return i18n("Search %1 emojis…", emojiCount)
    }

    function resetSearchPlaceholder() {
        searchPlaceholderResetTimer.stop()
        searchPlaceholderMessageActive = false
        searchPlaceholderText = getSearchPlaceholder()
    }

    function showSearchTemporaryMessage(message) {
        searchPlaceholderMessageActive = true
        searchPlaceholderText = message
        searchPlaceholderResetTimer.restart()
    }

    function showPasteTemporaryMessage(message) {
        pasteField.placeholderText = message
        pastePlaceholderResetTimer.restart()
    }

    function showCopiedFeedback(emoji, name) {
        if (name && name.length > 0) {
            showPasteTemporaryMessage(i18n("Copied: %1 (%2)", emoji, name))
        } else {
            showPasteTemporaryMessage(i18n("Copied: %1", emoji))
        }
    }

    function handleEmojiNavigationFromTextInput(event) {
        if (!plasmoid.configuration.KeyboardNavigation) return false
            if (!event) return false

                if (event.key !== Qt.Key_Left && event.key !== Qt.Key_Right &&
                    event.key !== Qt.Key_Up && event.key !== Qt.Key_Down) {
                    return false
                    }

                    if (event.modifiers & (Qt.AltModifier | Qt.MetaModifier)) return false
                        if (!emojiGridView || typeof emojiHandleExternalArrowKey !== "function") return false

                            return emojiHandleExternalArrowKey(event.key)
    }

    function openConfigurationDialog() {
        var configureAction = null
        if (typeof Plasmoid !== "undefined" && typeof Plasmoid.internalAction === "function") {
            configureAction = Plasmoid.internalAction("configure")
        }
        if (!configureAction && typeof plasmoid !== "undefined" && typeof plasmoid.action === "function") {
            configureAction = plasmoid.action("configure")
        }
        if (!configureAction) return

            if (typeof configureAction.trigger === "function") {
                configureAction.trigger()
            } else if (typeof configureAction.triggered === "function") {
                configureAction.triggered()
            }
    }

    // =========================================================================
    // Initialization & Event Handling
    // =========================================================================

    Component.onCompleted: {
        loadRecentEmojis()
        loadFavoriteEmojis()
        Qt.callLater(loadEmojis)

        fullRoot.resetSearchPlaceholder()
        fullRoot.emojiViewModel = fullRoot.filteredEmojis
        fullRoot.emojiExternalScrollBar = null
        fullRoot.emojiKeyboardNavigationEnabled = plasmoid.configuration.KeyboardNavigation
        Qt.callLater(function() {
            searchField.forceActiveFocus()
        })

        var savedOrder = plasmoid.configuration.CategoryOrder
        if (savedOrder && savedOrder.length > 0) {
            try {
                var parsed = JSON.parse(savedOrder)
                categoryModel.clear()
                for (var i = 0; i < parsed.length; i++) {
                    if (parsed[i].name === "Activities") {
                        if (parsed[i].icon === "applications-games" || parsed[i].icon === "games-highscore") {
                            parsed[i].icon = "games-highscores"
                        }
                    }

                    var defaultEntry = null
                    for (var j = 0; j < defaultCategoryOrder.length; j++) {
                        if (defaultCategoryOrder[j].name === parsed[i].name) {
                            defaultEntry = defaultCategoryOrder[j]
                            break
                        }
                    }
                    parsed[i].displayName = defaultEntry ? defaultEntry.displayName : parsed[i].name

                    categoryModel.append(parsed[i])
                }
                saveCategoryOrder()
            } catch (e) {
                loadDefaultCategories()
            }
        } else {
            loadDefaultCategories()
        }
    }

    Connections {
        target: plasmoid.configuration
        function onGridSizeChanged() {
            fullRoot.internalGridSize = plasmoid.configuration.GridSize
        }
        function onKeyboardNavigationChanged() {
            fullRoot.emojiKeyboardNavigationEnabled = plasmoid.configuration.KeyboardNavigation
        }
    }

    // Handle global key events for navigation
    Keys.onPressed: function(event) {
        if (plasmoid.configuration.KeyboardNavigation) {
            if (event.key === Qt.Key_Escape) {
                if (fullRoot.plasmoidItem) fullRoot.plasmoidItem.expanded = false
                    event.accepted = true
                    return
            }

            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                if (!(event.modifiers & (Qt.AltModifier | Qt.MetaModifier))) {
                    if (emojiGridView && typeof emojiHandleExternalArrowKey === "function") {
                        var handled = emojiHandleExternalArrowKey(event.key)
                        if (handled) event.accepted = true
                            return
                    }
                }
                }

                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) &&
                    !(event.modifiers & Qt.ControlModifier)) {

                    if (fullRoot.selectedEmojis.length > 0) {
                        const combined = fullRoot.selectedEmojis.join("")
                        clipboard.content = combined
                        fullRoot.showCopiedFeedback(combined, fullRoot.selectedEmojis.length + " emojis")
                        fullRoot.selectedEmojis = []

                        if (plasmoid.configuration.CloseAfterSelection) {
                            if (fullRoot.plasmoidItem) fullRoot.plasmoidItem.expanded = false
                        }
                        event.accepted = true
                        return
                    }

                    if (emojiGridView && emojiGridView.activeFocus) {
                        return
                    }
                    }
        } else {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab ||
                event.key === Qt.Key_Backtab || event.key === Qt.Key_Return ||
                event.key === Qt.Key_Enter) {
                event.accepted = true
                return
                }
        }
    }

    // Non-visual helper objects
    ListModel {
        id: categoryModel
    }

    Timer {
        id: searchDebounceTimer
        interval: 200 // 200ms debounce
        repeat: false
        onTriggered: {
            fullRoot.filter = searchField.text
        }
    }

    Timer {
        id: pastePlaceholderResetTimer
        interval: 2000
        running: false
        repeat: false
        onTriggered: {
            pasteField.placeholderText = fullRoot.defaultPastePlaceholder
        }
    }

    Timer {
        id: searchPlaceholderResetTimer
        interval: 2000
        running: false
        repeat: false
        onTriggered: {
            fullRoot.resetSearchPlaceholder()
        }
    }

    KQCA.Clipboard {
        id: clipboard
    }

    // =========================================================================
    // UI Layout
    // =========================================================================

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------------------------
        // Top Section (Search & Paste)
        // ---------------------------------------------------------------------
        Item {
            Layout.fillWidth: true
            implicitHeight: topSection.implicitHeight + 16

            ColumnLayout {
                id: topSection
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
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
                        KeyNavigation.backtab: plasmoid.configuration.KeyboardNavigation ? emojiGridView : null

                        onTextChanged: {
                            searchDebounceTimer.restart()
                        }

                        onActiveFocusChanged: {
                            if (!activeFocus && emojiGridView && typeof emojiGridView.cancelExternalFeedback === "function") {
                                emojiGridView.cancelExternalFeedback()
                            }
                        }

                        Keys.onReturnPressed: {
                            if (!plasmoid.configuration.KeyboardNavigation) return

                                if (fullRoot.selectedEmojis.length > 0) {
                                    const combined = fullRoot.selectedEmojis.join("")
                                    clipboard.content = combined
                                    fullRoot.showCopiedFeedback(combined, fullRoot.selectedEmojis.length + " emojis")
                                    fullRoot.selectedEmojis = []

                                    if (plasmoid.configuration.CloseAfterSelection) {
                                        if (fullRoot.plasmoidItem) fullRoot.plasmoidItem.expanded = false
                                    }
                                    searchField.text = ""
                                    return
                                }

                                const isShift = (event.modifiers & Qt.ShiftModifier)

                                if (fullRoot.hoveredEmoji) {
                                    const hoveredEmojiObj = fullRoot.filteredEmojis.find(e => e.emoji === fullRoot.hoveredEmoji) || {
                                        emoji: fullRoot.hoveredEmoji,
                                        name: fullRoot.hoveredEmojiName,
                                        slug: "",
                                        group: ""
                                    }

                                    if (emojiGridView && typeof emojiGridView.triggerExternalFeedback === "function") {
                                        var idx = fullRoot.emojiIndexForEmojiKey(fullRoot.hoveredEmoji)
                                        if (idx >= 0) {
                                            emojiGridView.currentIndex = idx
                                            emojiGridView.triggerExternalFeedback()
                                        }
                                    }

                                    if (isShift) {
                                        clipboard.content = hoveredEmojiObj.name
                                        addRecentEmoji(hoveredEmojiObj)
                                        showCopiedFeedback(hoveredEmojiObj.name, hoveredEmojiObj.emoji)
                                    } else {
                                        clipboard.content = fullRoot.hoveredEmoji
                                        addRecentEmoji(hoveredEmojiObj)
                                        showCopiedFeedback(fullRoot.hoveredEmoji, fullRoot.hoveredEmojiName)
                                    }
                                    searchField.text = ""
                                } else if (fullRoot.filteredEmojis.length > 0) {
                                    const firstEmoji = fullRoot.filteredEmojis[0]

                                    if (emojiGridView && typeof emojiGridView.triggerExternalFeedback === "function") {
                                        if (emojiGridView.count > 0) {
                                            emojiGridView.currentIndex = 0
                                            emojiGridView.triggerExternalFeedback()
                                        }
                                    }

                                    if (isShift) {
                                        clipboard.content = firstEmoji.name
                                        addRecentEmoji(firstEmoji)
                                        showCopiedFeedback(firstEmoji.name, "")
                                    } else {
                                        clipboard.content = firstEmoji.emoji
                                        addRecentEmoji(firstEmoji)
                                        showCopiedFeedback(firstEmoji.emoji, firstEmoji.name)
                                    }
                                    searchField.text = ""
                                }
                        }

                        Keys.onDownPressed: {
                            fullRoot.handleEmojiNavigationFromTextInput(event)
                            event.accepted = true
                        }

                        Keys.onReleased: function(event) {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (emojiGridView && typeof emojiGridView.cancelExternalFeedback === "function") {
                                    emojiGridView.cancelExternalFeedback()
                                }
                            }
                        }

                        Keys.onPressed: function(event) {
                            if (plasmoid.configuration.KeyboardNavigation &&
                                (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                                event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                                var handled = fullRoot.handleEmojiNavigationFromTextInput(event)
                                if (handled) event.accepted = true
                                }

                                if (plasmoid.configuration.KeyboardNavigation && event.key === Qt.Key_Escape) {
                                    if (fullRoot.plasmoidItem) fullRoot.plasmoidItem.expanded = false
                                        event.accepted = true
                                } else if (!plasmoid.configuration.KeyboardNavigation && (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                    event.accepted = true
                                    return
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
                                emojiGridView.cancelExternalFeedback()
                            }
                        }

                        leftActions: [
                            Action {
                                icon.name: "edit-paste"
                                enabled: false
                            }
                        ]

                        Keys.onReleased: function(event) {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (emojiGridView && typeof emojiGridView.cancelExternalFeedback === "function") {
                                    emojiGridView.cancelExternalFeedback()
                                }
                            }
                        }

                        Keys.onPressed: function(event) {
                            if (plasmoid.configuration.KeyboardNavigation &&
                                (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                                event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                                var handled = fullRoot.handleEmojiNavigationFromTextInput(event)
                                if (handled) event.accepted = true
                                }

                                if (plasmoid.configuration.KeyboardNavigation && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                    const isShift = event.modifiers & Qt.ShiftModifier

                                    if (fullRoot.selectedEmojis.length > 0) {
                                        const combined = fullRoot.selectedEmojis.join("")
                                        clipboard.content = combined
                                        fullRoot.showCopiedFeedback(combined, fullRoot.selectedEmojis.length + " emojis")
                                        fullRoot.selectedEmojis = []

                                        if (plasmoid.configuration.CloseAfterSelection) {
                                            if (fullRoot.plasmoidItem) fullRoot.plasmoidItem.expanded = false
                                        }
                                        event.accepted = true
                                    } else if (fullRoot.hoveredEmoji) {
                                        const hoveredEmojiObj = fullRoot.filteredEmojis.find(e => e.emoji === fullRoot.hoveredEmoji) || {
                                            emoji: fullRoot.hoveredEmoji,
                                            name: fullRoot.hoveredEmojiName,
                                            slug: "",
                                            group: ""
                                        }

                                        if (emojiGridView && typeof emojiGridView.triggerExternalFeedback === "function") {
                                            var idx = fullRoot.emojiIndexForEmojiKey(fullRoot.hoveredEmoji)
                                            if (idx >= 0) {
                                                emojiGridView.currentIndex = idx
                                                emojiGridView.triggerExternalFeedback()
                                            }
                                        }

                                        if (isShift) {
                                            clipboard.content = hoveredEmojiObj.name
                                            addRecentEmoji(hoveredEmojiObj)
                                            showCopiedFeedback(hoveredEmojiObj.name, hoveredEmojiObj.emoji)
                                        } else {
                                            clipboard.content = fullRoot.hoveredEmoji
                                            addRecentEmoji(hoveredEmojiObj)
                                            showCopiedFeedback(fullRoot.hoveredEmoji, fullRoot.hoveredEmojiName)
                                        }
                                        event.accepted = true
                                    }
                                } else if (plasmoid.configuration.KeyboardNavigation && event.key === Qt.Key_Escape) {
                                    if (fullRoot.plasmoidItem) fullRoot.plasmoidItem.expanded = false
                                        event.accepted = true
                                } else if (!plasmoid.configuration.KeyboardNavigation && (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                    event.accepted = true
                                    return
                                }
                        }
                    }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // ---------------------------------------------------------------------
        // Middle Section (Sidebar + Grid)
        // ---------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // --- Sidebar ---
            Item {
                Layout.fillHeight: true
                Layout.preferredWidth: fullRoot.sidebarExpanded ? 180 : 32
                Layout.maximumWidth: 180

                Item {
                    anchors.fill: parent

                    // Pin Button
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
                        KeyNavigation.down: plasmoid.configuration.KeyboardNavigation ? settingsButtonInSidebar : null
                        KeyNavigation.right: plasmoid.configuration.KeyboardNavigation ? emojiGridView : null

                        property bool keyboardPressed: false

                        Timer {
                            id: pinKeyboardFeedbackReset
                            interval: 120
                            repeat: false
                            running: false
                            onTriggered: pinButton.keyboardPressed = false
                        }

                        onClicked: {
                            plasmoid.configuration.AlwaysOpen = !plasmoid.configuration.AlwaysOpen
                            if (!plasmoid.configuration.KeyboardNavigation) {
                                activeFocus = false
                            }
                        }

                        Keys.onPressed: function(event) {
                            if (!plasmoid.configuration.KeyboardNavigation) return
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    keyboardPressed = true
                                    pinKeyboardFeedbackReset.restart()
                                    plasmoid.configuration.AlwaysOpen = !plasmoid.configuration.AlwaysOpen
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                                    event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                                    var handled = fullRoot.handleEmojiNavigationFromTextInput(event)
                                    if (handled) event.accepted = true
                                    }
                        }

                        Keys.onReleased: function(event) {
                            if (plasmoid.configuration.KeyboardNavigation && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                keyboardPressed = false
                                pinKeyboardFeedbackReset.stop()
                                event.accepted = true
                            }
                        }

                        MouseArea {
                            id: pinArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            onClicked: {
                                plasmoid.configuration.AlwaysOpen = !plasmoid.configuration.AlwaysOpen
                                if (!plasmoid.configuration.KeyboardNavigation) {
                                    parent.activeFocus = false
                                }
                            }
                            onExited: {
                                if (!plasmoid.configuration.KeyboardNavigation) {
                                    parent.activeFocus = false
                                }
                            }
                        }

                        background: Item {
                            anchors.fill: parent
                            anchors.margins: 4
                            Rectangle {
                                anchors.fill: parent
                                color: PlasmaCore.Theme.backgroundColor
                                radius: 4
                                opacity: 0.05
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: PlasmaCore.Theme.highlightColor
                                radius: 4
                                opacity: (pinArea.pressed || pinButton.keyboardPressed) ? 1.0 : (((pinArea.containsMouse) || pinButton.activeFocus) ? 0.2 : 0)
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: 4
                                border.width: ((pinArea.containsMouse) || pinButton.activeFocus) ? 2 : 0
                                border.color: PlasmaCore.Theme.highlightColor
                            }
                        }

                        contentItem: Item {
                            Kirigami.Icon {
                                x: 4
                                anchors.verticalCenter: parent.verticalCenter
                                source: plasmoid.configuration.AlwaysOpen ? "window-unpin-symbolic" : "window-pin-symbolic"
                                width: Kirigami.Units.iconSizes.smallMedium + 2
                                height: Kirigami.Units.iconSizes.smallMedium + 2
                                color: PlasmaCore.Theme.textColor
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
                                    color: PlasmaCore.Theme.textColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: plasmoid.configuration.AlwaysOpen ? i18n("Unpin Window") : i18n("Pin Window")
                                    color: PlasmaCore.Theme.textColor
                                    font.bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                        PlasmaComponents.ToolTip {
                            text: fullRoot.sidebarExpanded ? "" : (plasmoid.configuration.AlwaysOpen ? i18n("Unpin Window") : i18n("Pin Window"))
                        }
                    }

                    // Settings Button
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
                        KeyNavigation.down: plasmoid.configuration.KeyboardNavigation ? sidebarToggleButton : null
                        KeyNavigation.up: plasmoid.configuration.KeyboardNavigation ? pinButton : null
                        KeyNavigation.right: plasmoid.configuration.KeyboardNavigation ? emojiGridView : null

                        property bool keyboardPressed: false

                        Timer {
                            id: settingsKeyboardFeedbackReset
                            interval: 120
                            repeat: false
                            running: false
                            onTriggered: settingsButtonInSidebar.keyboardPressed = false
                        }

                        Timer {
                            id: openSettingsTimer
                            interval: 50
                            repeat: false
                            running: false
                            onTriggered: fullRoot.openConfigurationDialog()
                        }

                        onClicked: fullRoot.openConfigurationDialog()

                        Keys.onPressed: function(event) {
                            if (!plasmoid.configuration.KeyboardNavigation) return
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    keyboardPressed = true
                                    settingsKeyboardFeedbackReset.restart()
                                    openSettingsTimer.restart()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                                    event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                                    var handled = fullRoot.handleEmojiNavigationFromTextInput(event)
                                    if (handled) event.accepted = true
                                    }
                        }

                        Keys.onReleased: function(event) {
                            if (plasmoid.configuration.KeyboardNavigation && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                keyboardPressed = false
                                settingsKeyboardFeedbackReset.stop()
                                event.accepted = true
                            }
                        }

                        MouseArea {
                            id: settingsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            onClicked: {
                                fullRoot.openConfigurationDialog()
                                if (!plasmoid.configuration.KeyboardNavigation) {
                                    parent.activeFocus = false
                                }
                            }
                            onExited: {
                                if (!plasmoid.configuration.KeyboardNavigation) {
                                    parent.activeFocus = false
                                }
                            }
                        }

                        background: Item {
                            anchors.fill: parent
                            anchors.margins: 4
                            Rectangle {
                                anchors.fill: parent
                                color: PlasmaCore.Theme.backgroundColor
                                radius: 4
                                opacity: 0.05
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: PlasmaCore.Theme.highlightColor
                                radius: 4
                                opacity: (settingsArea.pressed || settingsButtonInSidebar.keyboardPressed) ? 1.0 : (((settingsArea.containsMouse) || settingsButtonInSidebar.activeFocus) ? 0.2 : 0)
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: 4
                                border.width: ((settingsArea.containsMouse) || settingsButtonInSidebar.activeFocus) ? 2 : 0
                                border.color: PlasmaCore.Theme.highlightColor
                            }
                        }

                        contentItem: Item {
                            Kirigami.Icon {
                                x: 4
                                anchors.verticalCenter: parent.verticalCenter
                                source: "configure"
                                width: Kirigami.Units.iconSizes.smallMedium + 2
                                height: Kirigami.Units.iconSizes.smallMedium + 2
                                color: PlasmaCore.Theme.textColor
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
                                    color: PlasmaCore.Theme.textColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: i18n("Configure Settings")
                                    color: PlasmaCore.Theme.textColor
                                    font.bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                        PlasmaComponents.ToolTip {
                            text: fullRoot.sidebarExpanded ? "" : i18n("Configure Emoji Selector Plus Settings...")
                        }
                    }

                    // Toggle Button
                    PlasmaComponents.ToolButton {
                        id: sidebarToggleButton
                        implicitWidth: fullRoot.sidebarExpanded ? 180 : 32
                        implicitHeight: 32
                        x: 0
                        y: 64
                        focusPolicy: Qt.StrongFocus
                        activeFocusOnTab: plasmoid.configuration.KeyboardNavigation
                        KeyNavigation.backtab: plasmoid.configuration.KeyboardNavigation ? settingsButtonInSidebar : null
                        KeyNavigation.tab: plasmoid.configuration.KeyboardNavigation ? (categoryRepeater.count > 0 ? (categoryRepeater.itemAt(0) ? categoryRepeater.itemAt(0) : emojiGridView) : emojiGridView) : null
                        KeyNavigation.down: plasmoid.configuration.KeyboardNavigation ? (categoryRepeater.count > 0 ? (categoryRepeater.itemAt(0) ? categoryRepeater.itemAt(0) : emojiGridView) : emojiGridView) : null
                        KeyNavigation.up: plasmoid.configuration.KeyboardNavigation ? settingsButtonInSidebar : null
                        KeyNavigation.right: plasmoid.configuration.KeyboardNavigation ? emojiGridView : null

                        property bool keyboardPressed: false

                        onClicked: {
                            fullRoot.sidebarExpanded = !fullRoot.sidebarExpanded
                            if (!plasmoid.configuration.KeyboardNavigation) {
                                activeFocus = false
                                if (categoryRepeater.count > 0) {
                                    for (let i = 0; i < categoryRepeater.count; i++) {
                                        const button = categoryRepeater.itemAt(i);
                                        if (button && button.activeFocus) {
                                            button.activeFocus = false;
                                        }
                                    }
                                }
                            }
                        }

                        Keys.onPressed: function(event) {
                            if (!plasmoid.configuration.KeyboardNavigation) return
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    keyboardPressed = true
                                    fullRoot.sidebarExpanded = !fullRoot.sidebarExpanded
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                                    event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                                    var handled = fullRoot.handleEmojiNavigationFromTextInput(event)
                                    if (handled) event.accepted = true
                                    }
                        }

                        Keys.onReleased: function(event) {
                            if (plasmoid.configuration.KeyboardNavigation && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                keyboardPressed = false
                                event.accepted = true
                            }
                        }

                        MouseArea {
                            id: sidebarToggleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: {
                                if (mouse.button === Qt.LeftButton) {
                                    fullRoot.sidebarExpanded = !fullRoot.sidebarExpanded
                                    if (!plasmoid.configuration.KeyboardNavigation) {
                                        parent.activeFocus = false
                                        if (categoryRepeater.count > 0) {
                                            for (let i = 0; i < categoryRepeater.count; i++) {
                                                const button = categoryRepeater.itemAt(i);
                                                if (button && button.activeFocus) {
                                                    button.activeFocus = false;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            onExited: {
                                if (!plasmoid.configuration.KeyboardNavigation) {
                                    parent.activeFocus = false
                                }
                            }
                        }

                        background: Item {
                            anchors.fill: parent
                            anchors.margins: 4
                            Rectangle {
                                anchors.fill: parent
                                color: PlasmaCore.Theme.backgroundColor
                                radius: 4
                                opacity: 0.05
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: PlasmaCore.Theme.highlightColor
                                radius: 4
                                opacity: (sidebarToggleArea.pressed || sidebarToggleButton.keyboardPressed) ? 1.0 : (((sidebarToggleArea.containsMouse) || sidebarToggleButton.activeFocus) ? 0.2 : 0)
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: 4
                                border.width: ((sidebarToggleArea.containsMouse) || sidebarToggleButton.activeFocus) ? 2 : 0
                                border.color: PlasmaCore.Theme.highlightColor
                            }
                        }

                        contentItem: Item {
                            Kirigami.Icon {
                                x: 4
                                anchors.verticalCenter: parent.verticalCenter
                                source: "sidebar-expand"
                                width: Kirigami.Units.iconSizes.smallMedium + 2
                                height: Kirigami.Units.iconSizes.smallMedium + 2
                                color: PlasmaCore.Theme.textColor
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
                                    color: PlasmaCore.Theme.textColor
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: i18n("Close Sidebar")
                                    color: PlasmaCore.Theme.textColor
                                    font.bold: false
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                        PlasmaComponents.ToolTip {
                            text: fullRoot.sidebarExpanded ? "" : i18n("Open Sidebar")
                        }
                    }

                    // Category List
                    ScrollView {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 96
                        clip: true

                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        Column {
                            id: categoryColumn
                            width: parent.width
                            spacing: 2

                            Repeater {
                                id: categoryRepeater
                                model: categoryModel

                                delegate: PlasmaComponents.ToolButton {
                                    id: categoryButton
                                    implicitWidth: fullRoot.sidebarExpanded ? 180 : 32
                                    implicitHeight: 32
                                    focusPolicy: Qt.StrongFocus
                                    activeFocusOnTab: plasmoid.configuration.KeyboardNavigation
                                    KeyNavigation.tab: plasmoid.configuration.KeyboardNavigation ? (index + 1 < categoryRepeater.count ? (categoryRepeater.itemAt(index + 1) ? categoryRepeater.itemAt(index + 1) : emojiGridView) : emojiGridView) : null
                                    KeyNavigation.backtab: plasmoid.configuration.KeyboardNavigation ? (index === 0 ? sidebarToggleButton : (categoryRepeater.itemAt(index - 1) ? categoryRepeater.itemAt(index - 1) : sidebarToggleButton)) : null
                                    KeyNavigation.down: plasmoid.configuration.KeyboardNavigation ? (index + 1 < categoryRepeater.count ? (categoryRepeater.itemAt(index + 1) ? categoryRepeater.itemAt(index + 1) : emojiGridView) : emojiGridView) : null
                                    KeyNavigation.up: plasmoid.configuration.KeyboardNavigation ? (index === 0 ? sidebarToggleButton : (categoryRepeater.itemAt(index - 1) ? categoryRepeater.itemAt(index - 1) : sidebarToggleButton)) : null
                                    KeyNavigation.right: plasmoid.configuration.KeyboardNavigation ? emojiGridView : null

                                    property bool isSelected: fullRoot.selectedCategory === model.name
                                    property bool isDragging: false
                                    readonly property bool dragEnabled: true

                                    opacity: isDragging ? 0.3 : 1.0

                                    onClicked: fullRoot.selectedCategory = model.name

                                    Keys.onPressed: function(event) {
                                        if (!plasmoid.configuration.KeyboardNavigation) return
                                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                fullRoot.selectedCategory = model.name
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                                                event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                                                var handled = fullRoot.handleEmojiNavigationFromTextInput(event)
                                                if (handled) event.accepted = true
                                                }
                                    }

                                    background: Item {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        Rectangle {
                                            anchors.fill: parent
                                            color: PlasmaCore.Theme.backgroundColor
                                            radius: 4
                                            opacity: 0.05
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            color: PlasmaCore.Theme.highlightColor
                                            radius: 4
                                            opacity: (categoryButton.isSelected || categoryButton.isDragging || dragArea.pressed) ? 1.0 :
                                            (((dragArea.containsMouse && !categoryButton.isSelected && !fullRoot.isAnyCategoryDragging) || categoryButton.activeFocus) ? 0.2 : 0)
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            radius: 4
                                            border.width: ((categoryButton.isSelected || dragArea.pressed || categoryButton.isDragging) ||
                                            (dragArea.containsMouse && !categoryButton.isSelected && !fullRoot.isAnyCategoryDragging) ||
                                            categoryButton.activeFocus) ? 2 : 0
                                            border.color: PlasmaCore.Theme.highlightColor
                                        }
                                    }

                                    contentItem: Item {
                                        Kirigami.Icon {
                                            x: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            source: model.icon
                                            width: Kirigami.Units.iconSizes.smallMedium + 2
                                            height: Kirigami.Units.iconSizes.smallMedium + 2
                                            color: categoryButton.isSelected ? PlasmaCore.Theme.highlightedTextColor : PlasmaCore.Theme.textColor
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
                                                color: categoryButton.isSelected ? PlasmaCore.Theme.highlightedTextColor : PlasmaCore.Theme.textColor
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: model.displayName
                                                color: categoryButton.isSelected ? PlasmaCore.Theme.highlightedTextColor : PlasmaCore.Theme.textColor
                                                font.bold: false
                                                anchors.verticalCenter: parent.verticalCenter
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    PlasmaComponents.ToolTip {
                                        text: fullRoot.sidebarExpanded ? "" : model.displayName
                                    }

                                    MouseArea {
                                        id: dragArea
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        hoverEnabled: true
                                        cursorShape: categoryButton.isDragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
                                        pressAndHoldInterval: 500
                                        preventStealing: true
                                        propagateComposedEvents: false

                                        property int draggedIndex: -1
                                        property real startY: 0
                                        property bool dragInitialized: false

                                        Timer {
                                            id: dragInitTimer
                                            interval: 50
                                            onTriggered: {
                                                dragArea.dragInitialized = true
                                            }
                                        }

                                        onPressAndHold: function(mouse) {
                                            if (mouse.button === Qt.LeftButton && categoryButton.dragEnabled) {
                                                draggedIndex = index
                                                startY = mouseY
                                                categoryButton.isDragging = true
                                                dragInitialized = false
                                                dragInitTimer.restart()
                                                fullRoot.isAnyCategoryDragging = true
                                            }
                                        }

                                        onPositionChanged: {
                                            if (categoryButton.isDragging && dragInitialized) {
                                                var globalMousePos = mapToItem(fullRoot, mouseX, mouseY)
                                                var columnPos = categoryColumn.mapFromItem(fullRoot, globalMousePos.x, globalMousePos.y)
                                                var itemHeight = categoryButton.height + categoryColumn.spacing
                                                var targetIndex = Math.floor(columnPos.y / itemHeight)
                                                targetIndex = Math.max(0, Math.min(targetIndex, categoryRepeater.count - 1))

                                                if (targetIndex !== index && draggedIndex >= 0) {
                                                    var targetCenterY = (targetIndex * itemHeight) + (itemHeight / 2)
                                                    if (Math.abs(columnPos.y - targetCenterY) > itemHeight * 0.4) {
                                                        var actualDraggedIndex = -1
                                                        for (var i = 0; i < categoryRepeater.count; i++) {
                                                            var item = categoryRepeater.itemAt(i)
                                                            if (item && item.isDragging) {
                                                                actualDraggedIndex = i
                                                                break
                                                            }
                                                        }

                                                        if (actualDraggedIndex !== -1 && targetIndex !== actualDraggedIndex) {
                                                            categoryModel.move(actualDraggedIndex, targetIndex, 1)
                                                            draggedIndex = targetIndex
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        onReleased: {
                                            if (categoryButton.isDragging) {
                                                categoryButton.isDragging = false
                                                draggedIndex = -1
                                                dragInitialized = false
                                                dragInitTimer.stop()
                                                fullRoot.saveCategoryOrder()
                                                fullRoot.isAnyCategoryDragging = false
                                            }
                                        }

                                        onCanceled: {
                                            if (categoryButton.isDragging) {
                                                categoryButton.isDragging = false
                                                draggedIndex = -1
                                                dragInitialized = false
                                                dragInitTimer.stop()
                                                fullRoot.isAnyCategoryDragging = false
                                            }
                                        }

                                        onClicked: {
                                            if (mouse.button === Qt.RightButton) {
                                                if (model.name === "Recent") {
                                                    recentContextMenu.popup(dragArea, mouse.x, mouse.y)
                                                    mouse.accepted = true
                                                } else if (model.name === "Favorites") {
                                                    favoritesContextMenu.popup(dragArea, mouse.x, mouse.y)
                                                    mouse.accepted = true
                                                }
                                            } else if (!categoryButton.isDragging) {
                                                fullRoot.selectedCategory = model.name
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

            // --- Emoji Grid ---
            Item {
                id: emojiArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property bool showEmojiScrollBar: emojiGridView && emojiGridView.contentHeight > emojiGridView.height + 1

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    GridView {
                        id: emojiGridView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        cellWidth: fullRoot.internalGridSize
                        cellHeight: fullRoot.internalGridSize
                        rightMargin: ScrollBar.vertical.visible ? ScrollBar.vertical.width : 0
                        model: fullRoot.emojiViewModel
                        clip: true
                        interactive: true
                        flickableDirection: Flickable.VerticalFlick
                        ScrollBar.vertical: ScrollBar {}

                        activeFocusOnTab: fullRoot.emojiKeyboardNavigationEnabled
                        keyNavigationEnabled: fullRoot.emojiKeyboardNavigationEnabled
                        keyNavigationWraps: fullRoot.emojiKeyboardNavigationEnabled

                        property bool isMouseOver: false
                        property bool keyboardActionPressed: false
                        property bool externalKeyboardActionPressed: false

                        Timer {
                            id: mouseOverExitTimer
                            interval: 100
                            onTriggered: {
                                emojiGridView.isMouseOver = false
                                if (fullRoot.emojiHoveredEmojiKey !== "") {
                                    fullRoot.emojiLastHoveredEmojiKey = fullRoot.emojiHoveredEmojiKey
                                    fullRoot.emojiHoveredEmojiKey = ""
                                    fullRoot.hoveredEmoji = ""
                                    fullRoot.hoveredEmojiName = ""
                                }
                            }
                        }

                        function setMouseOver() {
                            mouseOverExitTimer.stop()
                            isMouseOver = true
                        }

                        function setMouseExit() {
                            mouseOverExitTimer.restart()
                        }

                        function triggerExternalFeedback() {
                            externalKeyboardActionPressed = true
                        }

                        function cancelExternalFeedback() {
                            externalKeyboardActionPressed = false
                        }

                        function updateKeyboardHover() {
                            if (!fullRoot.emojiKeyboardNavigationEnabled) return
                                if (currentIndex >= 0 && currentIndex < fullRoot.emojiViewModel.length) {
                                    const item = fullRoot.emojiViewModel[currentIndex]
                                    if (item) {
                                        if (fullRoot.emojiHoveredEmojiKey !== item.emoji) {
                                            fullRoot.emojiHoveredEmojiKey = item.emoji
                                            fullRoot.hoveredEmoji = item.emoji
                                            fullRoot.hoveredEmojiName = item.name
                                        }
                                        if (fullRoot.emojiLastHoveredEmojiKey !== item.emoji) {
                                            fullRoot.emojiLastHoveredEmojiKey = item.emoji
                                        }
                                    }
                                }
                        }

                        function clearKeyboardHover() {
                            if (fullRoot.emojiHoveredEmojiKey !== "") {
                                fullRoot.emojiHoveredEmojiKey = ""
                                fullRoot.hoveredEmoji = ""
                                fullRoot.hoveredEmojiName = ""
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                            propagateComposedEvents: true
                            onEntered: emojiGridView.setMouseOver()
                            onExited: emojiGridView.setMouseExit()
                        }

                        Keys.onPressed: function(event) {
                            if (!fullRoot.emojiKeyboardNavigationEnabled) return

                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select) {
                                    emojiGridView.keyboardActionPressed = true
                                    if (currentIndex >= 0 && currentIndex < fullRoot.emojiViewModel.length) {
                                        const item = fullRoot.emojiViewModel[currentIndex]
                                        const isCtrl = event.modifiers & Qt.ControlModifier
                                        const isShift = event.modifiers & Qt.ShiftModifier
                                        handleEmojiSelected(item.emoji, isCtrl, isShift)
                                        event.accepted = true
                                    }
                                } else if (event.key === Qt.Key_Space) {
                                    if (currentIndex >= 0 && currentIndex < fullRoot.emojiViewModel.length) {
                                        const item = fullRoot.emojiViewModel[currentIndex]
                                        fullRoot.emojiHoveredEmojiKey = item.emoji
                                        fullRoot.hoveredEmoji = item.emoji
                                        fullRoot.hoveredEmojiName = item.name
                                    }
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Escape) {
                                    if (fullRoot.plasmoidItem) {
                                        fullRoot.plasmoidItem.expanded = false
                                    }
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                    const backwards = (event.key === Qt.Key_Backtab) || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))
                                    if (!backwards && fullRoot.emojiTabNextTarget) {
                                        fullRoot.emojiTabNextTarget.forceActiveFocus()
                                        event.accepted = true
                                    } else if (backwards && fullRoot.emojiTabPreviousTarget) {
                                        fullRoot.emojiTabPreviousTarget.forceActiveFocus()
                                        event.accepted = true
                                    }
                                }
                        }

                        Keys.onReleased: function(event) {
                            if (fullRoot.emojiKeyboardNavigationEnabled &&
                                (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Select)) {
                                emojiGridView.keyboardActionPressed = false
                                }
                        }

                        onActiveFocusChanged: {
                            if (activeFocus && fullRoot.emojiKeyboardNavigationEnabled) {
                                if (count > 0) {
                                    if (currentIndex < 0 || currentIndex >= count) {
                                        if (fullRoot.emojiHoveredEmojiKey) {
                                            for (var i = 0; i < fullRoot.emojiViewModel.length; i++) {
                                                if (fullRoot.emojiViewModel[i].emoji === fullRoot.emojiHoveredEmojiKey) {
                                                    currentIndex = i
                                                    break
                                                }
                                            }
                                        }
                                        if (currentIndex < 0) currentIndex = 0
                                    } else {
                                        updateKeyboardHover()
                                    }
                                }
                            }
                        }

                        onModelChanged: {
                            if (fullRoot.emojiKeyboardNavigationEnabled) {
                                if (count > 0 && activeFocus) {
                                    if (currentIndex < 0 || currentIndex >= count) {
                                        if (fullRoot.emojiHoveredEmojiKey) {
                                            for (var i = 0; i < fullRoot.emojiViewModel.length; i++) {
                                                if (fullRoot.emojiViewModel[i].emoji === fullRoot.emojiHoveredEmojiKey) {
                                                    currentIndex = i
                                                    break
                                                }
                                            }
                                        }
                                        if (currentIndex < 0) currentIndex = 0
                                    } else {
                                        updateKeyboardHover()
                                    }
                                } else if (count === 0) {
                                    clearKeyboardHover()
                                }
                            }
                        }

                        onCountChanged: {
                            if (count === 0) {
                                clearKeyboardHover()
                            } else if (currentIndex >= count) {
                                currentIndex = count - 1
                            }
                        }

                        onCurrentIndexChanged: {
                            if (activeFocus && fullRoot.emojiKeyboardNavigationEnabled) {
                                updateKeyboardHover()
                                if (currentIndex >= 0 && currentIndex < fullRoot.emojiViewModel.length) {
                                    const item = fullRoot.emojiViewModel[currentIndex]
                                    if (item) {
                                        fullRoot.emojiLastHoveredEmojiKey = item.emoji
                                    }
                                }
                            }
                        }

                        delegate: Item {
                            width: fullRoot.internalGridSize
                            height: fullRoot.internalGridSize

                            readonly property bool isSelected: fullRoot.selectedEmojis.indexOf(modelData.emoji) >= 0
                            readonly property bool isKeyboardFocus: GridView.isCurrentItem && emojiGridView.activeFocus
                            readonly property bool isKeyboardPressed: GridView.isCurrentItem && (emojiGridView.keyboardActionPressed || emojiGridView.externalKeyboardActionPressed)
                            readonly property bool isLastHovered: fullRoot.emojiLastHoveredEmojiKey === modelData.emoji && !emojiGridView.isMouseOver
                            readonly property bool isGlobalHover: fullRoot.emojiHoveredEmojiKey === modelData.emoji
                            property bool isLocallyHovered: false

                            Item {
                                anchors.fill: parent
                                anchors.margins: 2

                                Rectangle {
                                    anchors.fill: parent
                                    color: PlasmaCore.Theme.backgroundColor
                                    radius: 4
                                    opacity: 0.05
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: PlasmaCore.Theme.highlightColor
                                    radius: 4
                                    opacity: (mouseArea.pressed || isSelected || isKeyboardPressed) ? 1.0 :
                                    (isLocallyHovered || isGlobalHover || isKeyboardFocus || isLastHovered ? 0.2 : 0)
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    radius: 4
                                    border.width: (mouseArea.pressed || isSelected || isLocallyHovered || isGlobalHover || isKeyboardFocus || isLastHovered || isKeyboardPressed) ? 2 : 0
                                    border.color: PlasmaCore.Theme.highlightColor
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.emoji
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
                                    isLocallyHovered = true
                                    fullRoot.emojiHoveredEmojiKey = modelData.emoji
                                    fullRoot.hoveredEmoji = modelData.emoji
                                    fullRoot.hoveredEmojiName = modelData.name

                                    if (emojiGridView && fullRoot.emojiKeyboardNavigationEnabled) {
                                        emojiGridView.currentIndex = index
                                    }
                                    if (emojiGridView) {
                                        emojiGridView.setMouseOver()
                                    }
                                }

                                onExited: {
                                    isLocallyHovered = false
                                    if (fullRoot.emojiHoveredEmojiKey === modelData.emoji) {
                                        fullRoot.emojiLastHoveredEmojiKey = modelData.emoji
                                    }
                                    if (emojiGridView) {
                                        emojiGridView.setMouseExit()
                                    }
                                }

                                onClicked: {
                                    if (mouse.button === Qt.LeftButton) {
                                        const isCtrl = mouse.modifiers & Qt.ControlModifier
                                        const isShift = mouse.modifiers & Qt.ShiftModifier
                                        handleEmojiSelected(modelData.emoji, isCtrl, isShift)
                                    } else if (mouse.button === Qt.RightButton) {
                                        handleEmojiRightClicked(modelData.emoji, modelData, Qt.point(mouse.x, mouse.y))
                                    }
                                }
                            }
                        }
                    }
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: i18n("No results found :(")
                    font.pixelSize: 16
                    color: PlasmaCore.Theme.textColor
                    opacity: 0.6
                    visible: fullRoot.filteredEmojis.length === 0
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // ---------------------------------------------------------------------
        // Bottom Section (Preview Bar)
        // ---------------------------------------------------------------------
        Item {
            id: previewBar
            Layout.fillWidth: true
            Layout.preferredHeight: topSection.implicitHeight + 16

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
                        text: fullRoot.hoveredEmoji
                        font.pixelSize: previewBar.height - 20
                        visible: fullRoot.hoveredEmoji !== ""
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: "preferences-desktop-emoticons-symbolic"
                        width: parent.height
                        height: parent.height
                        color: PlasmaCore.Theme.disabledTextColor
                        visible: fullRoot.hoveredEmoji === ""
                    }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: fullRoot.hoveredEmoji !== "" ? fullRoot.hoveredEmojiName : i18n("Hover over an emoji for details...")
                    font.pixelSize: 14
                    font.bold: false
                    elide: Text.ElideRight
                    color: fullRoot.hoveredEmoji !== "" ? PlasmaCore.Theme.textColor : PlasmaCore.Theme.disabledTextColor
                    visible: fullRoot.hoveredEmoji === "" || fullRoot.hoveredEmojiName !== ""
                }
            }
        }
    }

    // =========================================================================
    // Context Menus & Shortcuts
    // =========================================================================

    PlasmaComponents.Menu {
        id: contextMenu
        property string emoji: ""
        property var emojiObj: null

        PlasmaComponents.MenuItem {
            text: i18n("Copy Emoji")
            icon.name: "edit-copy"
            onClicked: {
                clipboard.content = contextMenu.emoji
                showCopiedFeedback(contextMenu.emoji, contextMenu.emojiObj ? contextMenu.emojiObj.name : "")
            }
        }

        PlasmaComponents.MenuItem {
            text: i18n("Copy Name")
            icon.name: "edit-copy"
            enabled: contextMenu.emojiObj && contextMenu.emojiObj.name && contextMenu.emojiObj.name.length > 0
            onClicked: {
                if (contextMenu.emojiObj && contextMenu.emojiObj.name && contextMenu.emojiObj.name.length > 0) {
                    clipboard.content = contextMenu.emojiObj.name
                    showPasteTemporaryMessage(i18n("Copied: %1 (%2)", contextMenu.emojiObj.name, contextMenu.emoji))
                } else {
                    clipboard.content = contextMenu.emoji
                    showPasteTemporaryMessage(i18n("Copied: %1", contextMenu.emoji))
                }
            }
        }

        PlasmaComponents.MenuItem {
            text: isFavorite(contextMenu.emoji) ? i18n("Unfavorite Emoji") : i18n("Favorite Emoji")
            icon.name: isFavorite(contextMenu.emoji) ? "bookmarks" : "bookmarks-bookmarked"
            onClicked: {
                var isFavoriteNow = toggleFavoriteEmoji(contextMenu.emojiObj)
                var displayName = (contextMenu.emojiObj && contextMenu.emojiObj.name && contextMenu.emojiObj.name.length > 0) ? contextMenu.emojiObj.name : ""
                var label = displayName && displayName.length > 0 ? displayName + " (" + contextMenu.emoji + ")" : contextMenu.emoji
                if (isFavoriteNow) {
                    showSearchTemporaryMessage(i18n("Favorited: %1", label))
                } else {
                    showSearchTemporaryMessage(i18n("Unfavorited: %1", label))
                }
            }
        }
    }

    PlasmaComponents.Menu {
        id: recentContextMenu
        PlasmaComponents.MenuItem {
            text: i18n("Clear Recent Emojis")
            icon.name: "edit-clear"
            onClicked: {
                clearRecentEmojis()
                showSearchTemporaryMessage(i18n("Cleared recent emojis"))
            }
        }
    }

    PlasmaComponents.Menu {
        id: favoritesContextMenu
        PlasmaComponents.MenuItem {
            text: i18n("Clear Favorite Emojis")
            icon.name: "edit-clear"
            onClicked: {
                clearFavoriteEmojis()
                showSearchTemporaryMessage(i18n("Cleared favorite emojis"))
            }
        }
    }

    Shortcut {
        sequences: [StandardKey.Escape]
        context: Qt.ApplicationShortcut
        onActivated: {
            if (fullRoot.plasmoidItem) {
                fullRoot.plasmoidItem.expanded = false
            }
        }
    }

    Shortcut {
        sequences: ["Ctrl+Return", "Ctrl+Enter"]
        context: Qt.ApplicationShortcut
        enabled: true
        onActivated: {
            if (!plasmoid.configuration.KeyboardNavigation) return
                if (typeof getCurrentFocusedEmoji === "function") {
                    var currentEmoji = getCurrentFocusedEmoji();
                    if (currentEmoji && currentEmoji.emoji) {
                        handleEmojiSelected(currentEmoji.emoji, true);
                    }
                }
        }
    }
}