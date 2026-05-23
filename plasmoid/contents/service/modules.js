var _cachedEmojis = null;
var KLIPY_BASE_URL = "https://api.klipy.com/api/v1";
var KLIPY_DEFAULT_API_KEY = "c9d81d227b0b4b2fb4e0bd6f6e52003c";
var KLIPY_DEFAULT_PER_PAGE = 24;

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
    var key = (apiKey || KLIPY_DEFAULT_API_KEY).trim();
    return key !== "" ? key : KLIPY_DEFAULT_API_KEY;
}

function buildGifUrl(apiKey, query, page, perPage) {
    var key = normalizeKlipyApiKey(apiKey);
    var currentPage = page || 1;
    var pageSize = perPage || KLIPY_DEFAULT_PER_PAGE;

    if (!query || query.trim() === "") {
        return KLIPY_BASE_URL + "/" + key + "/gifs/trending?per_page=" + pageSize + "&page=" + currentPage;
    }

    return KLIPY_BASE_URL + "/" + key + "/gifs/search?q=" + encodeURIComponent(query) + "&per_page=" + pageSize + "&page=" + currentPage;
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
