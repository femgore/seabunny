.pragma library

function luminance(hex) {
    function channel(offset) {
        var value = parseInt(hex.slice(offset, offset + 2), 16) / 255;
        return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
    }
    return 0.2126 * channel(1) + 0.7152 * channel(3) + 0.0722 * channel(5);
}

function foreground(background, colors) {
    var candidates = [colors.text, colors.base, colors.crust];
    var backgroundLuminance = luminance(background);
    var best = candidates[0];
    var bestContrast = 0;
    for (var index = 0; index < candidates.length; index++) {
        var candidateLuminance = luminance(candidates[index]);
        var contrast = (Math.max(backgroundLuminance, candidateLuminance) + 0.05)
            / (Math.min(backgroundLuminance, candidateLuminance) + 0.05);
        if (contrast > bestContrast) {
            best = candidates[index];
            bestContrast = contrast;
        }
    }
    return best;
}

function mix(color, target, amount) {
    var result = "#";
    for (var offset = 1; offset < 7; offset += 2) {
        var channel = Math.round(parseInt(color.slice(offset, offset + 2), 16) * (1 - amount)
            + parseInt(target.slice(offset, offset + 2), 16) * amount);
        result += ("0" + channel.toString(16)).slice(-2);
    }
    return result;
}

function forMode(colors, dark) {
    if ((luminance(colors.base) < luminance(colors.text)) === dark) return colors;
    var result = Object.assign({}, colors);
    var neutral = dark ? "#000000" : "#ffffff";
    var foregroundColor = dark ? "#ffffff" : "#000000";
    var amounts = { base: 0.94, crust: 0.98, mantle: 0.92, surface0: 0.88, surface1: 0.82, surface2: 0.75 };
    for (var name in amounts) result[name] = mix(colors[name], neutral, amounts[name]);
    result.text = mix(colors.text, foregroundColor, 0.94);
    result.subtext0 = mix(colors.subtext0, foregroundColor, 0.70);
    result.subtext1 = mix(colors.subtext1, foregroundColor, 0.55);
    result.overlay0 = mix(colors.overlay0, foregroundColor, 0.35);
    for (var accent of ["blue", "green", "peach", "red", "sapphire", "yellow", "pink", "maroon"]) {
        if ((dark && luminance(colors[accent]) < 0.25) || (!dark && luminance(colors[accent]) > 0.30))
            result[accent] = mix(colors[accent], foregroundColor, dark ? 0.55 : 0.45);
    }
    return result;
}

function map(colors, mode) {
    if (mode === "light" || mode === "dark") colors = forMode(colors, mode === "dark");
    var roles = {
        Bg: colors.base,
        SurfaceLowest: colors.crust,
        SurfaceLow: colors.mantle,
        Surface: colors.surface0,
        SurfaceHigh: colors.surface1,
        SurfaceHighest: colors.surface2,
        Primary: colors.blue,
        Fg: foreground(colors.blue, colors),
        Container: colors.sapphire,
        ContainerFg: foreground(colors.sapphire, colors),
        SecondaryContainer: colors.yellow,
        SecondaryContainerFg: foreground(colors.yellow, colors),
        TertiaryContainer: colors.pink,
        TextMain: colors.text,
        TextMuted: colors.subtext0,
        Outline: colors.subtext1,
        OutlineVariant: colors.overlay0
    };
    var palette = {
        isDark: luminance(colors.base) < luminance(colors.text),
        secondary: colors.green,
        secondaryFg: foreground(colors.green, colors),
        tertiary: colors.peach,
        tertiaryFg: foreground(colors.peach, colors),
        tertiaryContainerFg: foreground(colors.pink, colors),
        error: colors.red,
        onError: foreground(colors.red, colors),
        errorContainer: colors.maroon,
        onErrorContainer: foreground(colors.maroon, colors)
    };
    for (var key in roles) {
        palette["dark" + key] = roles[key];
        palette["light" + key] = roles[key];
    }
    return palette;
}

function wallpaper(data, dark) {
    var source = data.colors || data;
    var mode = dark ? "dark" : "light";
    source = source[mode] || source;
    var flat = {};
    for (var key in source) {
        var value = source[key];
        if (value && typeof value === "object") {
            value = value[mode] || value.default || value;
            if (typeof value === "object") value = value.hex || value.color;
        }
        if (typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value)) flat[key] = value;
    }
    var special = data.special || {};
    var base = flat.background || flat.surface || special.background;
    var text = flat.on_surface || special.foreground;
    if (!/^#[0-9a-fA-F]{6}$/.test(base || "") || !/^#[0-9a-fA-F]{6}$/.test(text || "")) return {};
    var colors = {
        base: base, text: text,
        crust: flat.surface_container_lowest || base,
        mantle: flat.surface_container_low || base,
        surface0: flat.surface_container || base,
        surface1: flat.surface_container_high || base,
        surface2: flat.surface_container_highest || base,
        subtext0: flat.on_surface_variant || text,
        subtext1: flat.outline || text,
        overlay0: flat.outline_variant || base,
        blue: flat.primary || flat.color4 || text,
        sapphire: flat.primary_container || flat.color6 || base,
        green: flat.secondary || flat.color2 || text,
        yellow: flat.secondary_container || flat.color3 || base,
        peach: flat.tertiary || flat.color5 || text,
        pink: flat.tertiary_container || flat.color13 || base,
        red: flat.error || flat.color1 || text,
        maroon: flat.error_container || flat.color9 || base
    };
    var matches = (luminance(base) < luminance(text)) === dark;
    var palette = map(colors, mode);
    return {
        background: palette.darkBg,
        surface_container_lowest: palette.darkSurfaceLowest,
        surface_container_low: palette.darkSurfaceLow,
        surface_container: palette.darkSurface,
        surface_container_high: palette.darkSurfaceHigh,
        surface_container_highest: palette.darkSurfaceHighest,
        primary: palette.darkPrimary,
        on_primary: matches && flat.on_primary ? flat.on_primary : palette.darkFg,
        primary_container: palette.darkContainer,
        on_primary_container: matches && flat.on_primary_container ? flat.on_primary_container : palette.darkContainerFg,
        secondary_container: palette.darkSecondaryContainer,
        on_secondary_container: matches && flat.on_secondary_container ? flat.on_secondary_container : palette.darkSecondaryContainerFg,
        tertiary_container: palette.darkTertiaryContainer,
        on_surface: palette.darkTextMain,
        on_surface_variant: palette.darkTextMuted,
        outline: palette.darkOutline,
        outline_variant: palette.darkOutlineVariant
    };
}
