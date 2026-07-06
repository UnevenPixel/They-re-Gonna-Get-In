// -----------------------------------------------------------
// ResourceUIScripts -- sResourceIcons lookup/translation (for embedding
// resource icons in Scribble-formatted text) and the player's resource
// bar HUD.
//
// sResourceIcons is a 10-frame sprite (16x16, origin Middle Center), one
// icon per BASE resource, in this fixed order: wood, wheat, water, iron,
// gold, meat, bones, coal, weapons, coins. xp and fateTokens are
// deliberately NOT in this strip -- xp isn't spent the way the base 10
// are (see ProgressionScripts.gml), and fateTokens are for a specific
// future mechanic, not general spending -- neither gets an icon here.
//
// global.resourceIconOrder is a plain global array (not a #macro) so it's
// allocated exactly once at game start rather than re-allocated every
// time something reads it (a #macro expanding to an array literal would
// build a fresh array at every reference site, including every frame
// inside DrawResourceBar's loop below).
// -----------------------------------------------------------

global.resourceIconOrder = ["wood", "wheat", "water", "iron", "gold", "meat", "bones", "coal", "weapons", "coins"];

/// @function ResourceIconIndex(_resource)
/// @description Resolves a base-resource name to its frame index in
///        sResourceIcons.
/// @param {String} _resource One of the 10 base resource names (matches a
///        key in global.resources / Cost -- see global.resourceIconOrder).
/// @returns {Real} Frame index (0-9), or -1 if _resource isn't a base
///        resource (e.g. "xp", "fateTokens", or an unrecognized string).
function ResourceIconIndex(_resource) {
    for (var i = 0; i < array_length(global.resourceIconOrder); i++) {
        if (global.resourceIconOrder[i] == _resource) return i;
    }
    return -1;
}

/// @function ResourceIconTag(_resource)
/// @description Translates a base-resource name into the Scribble inline-
///        sprite tag that renders its icon -- "[sResourceIcons,N]"; see
///        Scribble's sprite-tag syntax (__scribble_gen_2_parser.gml).
/// @param {String} _resource One of the 10 base resource names.
/// @returns {String} The tag, or "" if _resource has no icon (xp,
///        fateTokens, or unrecognized).
function ResourceIconTag(_resource) {
    var _index = ResourceIconIndex(_resource);
    return (_index == -1) ? "" : $"[sResourceIcons,{_index}]";
}

/// @function CostToScribbleText(_cost)
/// @description Builds a Scribble-formatted string for a Cost struct --
///        one "[sResourceIcons,N]<amount>" run per non-zero base resource,
///        in global.resourceIconOrder order, separated by double spaces.
///        Feed the result into draw_text_scribble/draw_text_scribble_ext
///        to render a building/unit's cost with icons inline (e.g. for a
///        blueprint tooltip) instead of spelling out resource names.
///        xp/fateTokens are skipped even if non-zero (no icon to show --
///        see the file doc comment above).
/// @param {Struct.Cost} _cost
/// @returns {String} e.g. "[sResourceIcons,0]15  [sResourceIcons,9]10" for
///        a cost of 15 wood + 10 coins. "" if the cost is entirely zero
///        (or entirely xp/fateTokens).
function CostToScribbleText(_cost) {
    var _text = "";
    for (var i = 0; i < array_length(global.resourceIconOrder); i++) {
        var _resource = global.resourceIconOrder[i];
        var _amount   = struct_get(_cost, _resource);
        if (_amount <= 0) continue;

        if (_text != "") _text += "  ";
        _text += ResourceIconTag(_resource) + string(_amount);
    }
    return _text;
}

// -----------------------------------------------------------
// Resource bar HUD -- a single row of all 10 base-resource icons with the
// team's current count next to each. No drag/click state (unlike
// BlueprintController) so this is a plain function, not a struct -- call
// once per Draw GUI event.
// -----------------------------------------------------------

#macro RESOURCE_BAR_ORIGIN_X     466 // center of the first (Wood) icon -- 2026-07-05 request
#macro RESOURCE_BAR_ORIGIN_Y     1060
#macro RESOURCE_BAR_ICON_SPACING 152 // center-to-center between consecutive icons
#macro RESOURCE_BAR_TEXT_GAP     10  // px from the icon's RIGHT EDGE (not center) to the count text

/// @function DrawResourceBar(_team)
/// @description Call once per Draw GUI event. Renders all 10 base-resource
///        icons (sResourceIcons, in global.resourceIconOrder) in a single
///        row starting at (RESOURCE_BAR_ORIGIN_X, RESOURCE_BAR_ORIGIN_Y) --
///        that point is the CENTER of the first (Wood) icon, since
///        sResourceIcons is origin-centered, same as every other UI sprite
///        this project draws by center. Each subsequent icon sits
///        RESOURCE_BAR_ICON_SPACING px to the right, center to center.
///        _team's current count for that resource is drawn
///        RESOURCE_BAR_TEXT_GAP px to the right of the icon's right EDGE
///        (icon center + half the icon's width + the gap), vertically
///        centered on the icon.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
function DrawResourceBar(_team) {
    var _halfIconWidth = sprite_get_width(sResourceIcons) / 2;

    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_color(c_white);

    for (var i = 0; i < array_length(global.resourceIconOrder); i++) {
        var _resource = global.resourceIconOrder[i];
        var _cx = RESOURCE_BAR_ORIGIN_X + i * RESOURCE_BAR_ICON_SPACING;
        var _cy = RESOURCE_BAR_ORIGIN_Y;

        draw_sprite(sResourceIcons, i, _cx, _cy);

        var _amount = struct_get(global.resources[_team], _resource);
        draw_text(_cx + _halfIconWidth + RESOURCE_BAR_TEXT_GAP, _cy, string(_amount));
    }
}
