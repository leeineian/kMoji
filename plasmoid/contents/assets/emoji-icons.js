var _cachedEmojis = null;

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
