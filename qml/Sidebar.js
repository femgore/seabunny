.pragma library

function layout(raw) {
    try {
        var value = JSON.parse(raw || "{}");
        return { version: 1, order: Array.isArray(value.order) ? value.order : [],
            hidden: Array.isArray(value.hidden) ? value.hidden : [],
            icons: value.icons && typeof value.icons === "object" && !Array.isArray(value.icons) ? value.icons : {} };
    } catch (error) { return { version: 1, order: [], hidden: [], icons: {} }; }
}

function arrange(places, favorites, state) {
    var items = places.map(function(place) {
        var item = Object.assign({}, place);
        item.id = "place:" + (item.view === "pc" ? "pc" : item.trashRoot ? "trash" : item.pathSuffix || "home");
        return item;
    }).concat(favorites.map(function(item) {
        return { id: "folder:" + item.path, name: item.label, path: item.path,
            iconName: "folder", systemIcon: "folder-symbolic", view: "files", favorite: true };
    }));
    items = items.filter(function(item) { return state.hidden.indexOf(item.id) < 0; });
    items.forEach(function(item) {
        item.customIcon = typeof state.icons[item.id] === "string" ? state.icons[item.id] : "";
        if (item.customIcon) item.iconName = item.customIcon;
    });
    var positions = {};
    state.order.forEach(function(id, index) { positions[id] = index; });
    items.forEach(function(item, index) {
        if (positions[item.id] === undefined) positions[item.id] = state.order.length + index;
    });
    return items.sort(function(first, second) {
        return positions[first.id] - positions[second.id];
    });
}

function move(state, items, source, target, before) {
    var result = layout(JSON.stringify(state));
    var ids = items.map(function(item) { return item.id; });
    if (source === target || ids.indexOf(source) < 0 || (target && ids.indexOf(target) < 0)) return result;
    ids.splice(ids.indexOf(source), 1);
    var position = target ? ids.indexOf(target) + (before ? 0 : 1) : ids.length;
    ids.splice(position, 0, source);
    result.order = ids;
    return result;
}

function localPaths(urls) {
    var paths = [];
    for (var index = 0; index < urls.length; index++) {
        var value = urls[index].toString();
        if (!/^file:\/\/(localhost)?\//.test(value)) continue;
        try {
            var path = decodeURIComponent(value.replace(/^file:\/\/(localhost)?/, ""));
            if (path.indexOf("\u0000") < 0 && paths.indexOf(path) < 0) paths.push(path);
        } catch (error) {}
    }
    return paths;
}
