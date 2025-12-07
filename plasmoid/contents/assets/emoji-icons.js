// Import the shared emoji list module
.import "emoji-list.js" as EmojiSource

// Dynamically populate iconEmojis from the shared emoji list
var _cachedEmojis = null;

function getIconEmojis() {
    if (_cachedEmojis) {
        return _cachedEmojis;
    }

    var allEmojis = [];
    var list = EmojiSource.emojiList;
    
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
