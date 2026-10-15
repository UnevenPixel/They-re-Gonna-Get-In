// sResourceIcons lookup/translation for Scribble-formatted text, plus the
// player's resource bar HUD. See ResourceUIScripts.md.

global.resourceIconOrder = ["wood", "wheat", "water", "iron", "gold", "meat", "bones", "coal", "weapons", "coins"];

/// @function ResourceIconIndex(_resource)
/// @description Resolves a base-resource name to its frame index in sResourceIcons.
/// @param {String} _resource One of the 10 base resource names.
/// @returns {Real} Frame index (0-9), or -1 if _resource isn't a base resource.
function ResourceIconIndex(_resource) {
    for (var i = 0; i < array_length(global.resourceIconOrder); i++) {
        if (global.resourceIconOrder[i] == _resource) return i;
    }
    return -1;
}

/// @function ResourceIconTag(_resource)
/// @description Translates a base-resource name into the Scribble inline-sprite tag that renders its icon.
/// @param {String} _resource One of the 10 base resource names.
/// @returns {String} The tag, or "" if _resource has no icon.
function ResourceIconTag(_resource) {
    var _index = ResourceIconIndex(_resource);
    return (_index == -1) ? "" : $"[sResourceIcons,{_index}]";
}

/// @function CostToScribbleText(_cost)
/// @description Builds a Scribble-formatted string for a Cost struct -- one icon+amount run per non-zero base resource. Feed into draw_text_scribble(_ext). xp/fateTokens are skipped (no icon). See .md.
/// @param {Struct.Cost} _cost
/// @returns {String} e.g. "[sResourceIcons,0]15  [sResourceIcons,9]10". "" if entirely zero.
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

/// @function CostToScribbleTextWithDiscount(_baseCost, _discountCost, _discountAvailable, _team)
/// @description Builds the blueprint hover's cost row -- "[icon]BasePrice (DiscountPrice)" per non-zero base resource. Base/discount prices are colored independently (unaffordable red, discount-unavailable gray). See .md.
/// @param {Struct.Cost} _baseCost Typically _def.cost.
/// @param {Struct.Cost} _discountCost Typically GetDiscountedCost(_def.cost, PLOT_BONUS_DISCOUNT_FRACTION).
/// @param {Bool} _discountAvailable Whether any currently open plot grants the discount -- see GetBestAvailablePlacementCost (BlueprintScripts.gml).
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY -- indexes global.resources.
/// @returns {String}
function CostToScribbleTextWithDiscount(_baseCost, _discountCost, _discountAvailable, _team) {
    var _text = "";
    for (var i = 0; i < array_length(global.resourceIconOrder); i++) {
        var _resource   = global.resourceIconOrder[i];
        var _baseAmount = struct_get(_baseCost, _resource);
        if (_baseAmount <= 0) continue;

        var _discountAmount = struct_get(_discountCost, _resource);
        var _haveAmount     = struct_get(global.resources[_team], _resource);

        var _baseRun = string(_baseAmount);
        if (_haveAmount < _baseAmount) _baseRun = $"[{PLOT_HOVER_BAD_COLOR_TAG}]{_baseRun}[/c]";

        var _discountRun = string(_discountAmount);
        if (!_discountAvailable) {
            _discountRun = $"[{BLUEPRINT_DISCOUNT_UNAVAILABLE_COLOR_TAG}]{_discountRun}[/c]";
        } else if (_haveAmount < _discountAmount) {
            _discountRun = $"[{PLOT_HOVER_BAD_COLOR_TAG}]{_discountRun}[/c]";
        }

        if (_text != "") _text += "  ";
        _text += $"{ResourceIconTag(_resource)}{_baseRun} ({_discountRun})";
    }
    return _text;
}

#macro RESOURCE_BAR_ORIGIN_X     466 // center of the first (Wood) icon
#macro RESOURCE_BAR_ORIGIN_Y     1060
#macro RESOURCE_BAR_ICON_SPACING 148 // center-to-center between consecutive icons
#macro RESOURCE_BAR_TEXT_GAP     10  // px from the icon's RIGHT EDGE (not center) to the count text

#macro RESOURCE_BAR_UI_SCALE          2    // matches sMainUIBarBottom's draw scale (oUnitControl/Draw_64.gml)
#macro RESOURCE_BAR_BOTTOM_Y          1080 // GUI Y of the UI bar's bottom edge, same call
#macro RESOURCE_BAR_HOVER_NATIVE_H    22   // native px: the bottom strip of the UI bar that counts as "the resource bar" (== sMainUIResourceBarPopup's height)
#macro RESOURCE_BAR_POPUP_SLIDE_PER_STEP 0.12 // 0..1 slide progress per draw frame
#macro RESOURCE_SPEND_POPUP_SECONDS   2.5  // real seconds a "-##" popup lives
#macro RESOURCE_SPEND_POPUP_RISE      60   // GUI px a popup floats up over its lifetime
#macro RESOURCE_SPEND_POPUP_COLOR     c_red
#macro RESOURCE_RATE_ZERO_COLOR       c_dkgray
#macro RESOURCE_RATE_POSITIVE_COLOR   c_lime

global.resourceSpendPopups = []; // { index, amount, age } -- player spends, drawn by DrawResourceBar
global.resourceBarPopupK   = 0;  // 0..1 slide progress of sMainUIResourceBarPopup

/// @function ResourceSpendPopupAdd(_resource, _amount)
/// @description Queues a floating "-##" popup over _resource's slot in the resource bar. Ignored for resources with no bar icon (xp, fateTokens).
/// @param {String} _resource
/// @param {Real} _amount
function ResourceSpendPopupAdd(_resource, _amount) {
    var _index = ResourceIconIndex(_resource);
    if (_index == -1) return;
    array_push(global.resourceSpendPopups, { index: _index, amount: _amount, age: 0 });
}

/// @function GetTeamResourceRates(_team)
/// @description Cumulative production per second of every base resource across _team's producing buildings, including garrison bonuses. Ignores spending.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Struct} resource name -> rate per second.
function GetTeamResourceRates(_team) {
    var _rates = {};
    for (var i = 0; i < array_length(global.resourceIconOrder); i++) struct_set(_rates, global.resourceIconOrder[i], 0);

    var _bonus = GetStationedPassiveBonuses(_team);
    with (oResourceBuildingParent) {
        if (team != _team || productionResource == undefined || productionRate <= 0) continue;
        var _goldBonus = (productionResource == "gold") ? _bonus.goldProductionBonus : 0;
        var _mult      = 1 + _bonus.allResourceProductionBonus + _goldBonus;
        struct_set(_rates, productionResource, struct_get(_rates, productionResource) + productionRate * _mult);
    }
    return _rates;
}

/// @function DrawResourceBar(_team)
/// @description Call once per Draw GUI event. Renders all 10 base-resource icons in a single row starting at (RESOURCE_BAR_ORIGIN_X, RESOURCE_BAR_ORIGIN_Y) (icon CENTER), with _team's current count drawn to the right of each. While the mouse is over the bar's bottom strip, sMainUIResourceBarPopup slides up over it and the counts become production rates; spend popups float above. See .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
function DrawResourceBar(_team) {
    var _halfIconWidth = sprite_get_width(sResourceIcons) / 2;

    // hover slide (progress lives in a global; this runs once per frame)
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    var _barH = RESOURCE_BAR_HOVER_NATIVE_H * RESOURCE_BAR_UI_SCALE;
    var _hover = (_mx >= 0 && _mx <= sprite_get_width(sMainUIResourceBarPopup) * RESOURCE_BAR_UI_SCALE
        && _my >= RESOURCE_BAR_BOTTOM_Y - _barH && _my <= RESOURCE_BAR_BOTTOM_Y);
    global.resourceBarPopupK = clamp(global.resourceBarPopupK + (_hover ? RESOURCE_BAR_POPUP_SLIDE_PER_STEP : -RESOURCE_BAR_POPUP_SLIDE_PER_STEP), 0, 1);
    var _k = global.resourceBarPopupK;

    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_font(fntResource);
    draw_set_color(HOVER_CARD_TEXT_COLOR);

    for (var i = 0; i < array_length(global.resourceIconOrder); i++) {
        var _resource = global.resourceIconOrder[i];
        var _cx = RESOURCE_BAR_ORIGIN_X + i * RESOURCE_BAR_ICON_SPACING;
        var _cy = RESOURCE_BAR_ORIGIN_Y;

        draw_sprite(sResourceIcons, i, _cx, _cy);

        var _amount = struct_get(global.resources[_team], _resource);
        draw_text(_cx + _halfIconWidth + RESOURCE_BAR_TEXT_GAP, _cy, string(_amount));
    }

    // Popup slides up from below the screen edge to sit exactly over the bar strip (sprite origin is bottom-left).
    if (_k > 0) {
        var _ease  = _k * _k * (3 - 2 * _k);
        var _slide = (1 - _ease) * _barH;
        draw_sprite_ext(sMainUIResourceBarPopup, 0, 0, RESOURCE_BAR_BOTTOM_Y + _slide, RESOURCE_BAR_UI_SCALE, RESOURCE_BAR_UI_SCALE, 0, c_white, 1);

        var _rates = GetTeamResourceRates(_team);
        for (var i = 0; i < array_length(global.resourceIconOrder); i++) {
            var _cx2 = RESOURCE_BAR_ORIGIN_X + i * RESOURCE_BAR_ICON_SPACING;
            var _cy2 = RESOURCE_BAR_ORIGIN_Y + _slide;
            var _rate = struct_get(_rates, global.resourceIconOrder[i]);

            draw_sprite(sResourceIcons, i, _cx2, _cy2);
            draw_set_color(_rate > 0 ? RESOURCE_RATE_POSITIVE_COLOR : RESOURCE_RATE_ZERO_COLOR);
            draw_text(_cx2 + _halfIconWidth + RESOURCE_BAR_TEXT_GAP, _cy2, $"{round(_rate * 100) / 100}/s");
        }
    }

    // Spend popups: "-##" in red, float up and fade over RESOURCE_SPEND_POPUP_SECONDS.
    var _dt = delta_time / 1000000;
    for (var p = array_length(global.resourceSpendPopups) - 1; p >= 0; p--) {
        var _pop = global.resourceSpendPopups[p];
        _pop.age += _dt;
        if (_pop.age >= RESOURCE_SPEND_POPUP_SECONDS) {
            array_delete(global.resourceSpendPopups, p, 1);
            continue;
        }
        var _t = _pop.age / RESOURCE_SPEND_POPUP_SECONDS;
        draw_set_alpha(1 - _t);
        draw_set_color(RESOURCE_SPEND_POPUP_COLOR);
        draw_text(
            RESOURCE_BAR_ORIGIN_X + _pop.index * RESOURCE_BAR_ICON_SPACING + _halfIconWidth + RESOURCE_BAR_TEXT_GAP,
            RESOURCE_BAR_ORIGIN_Y - 24 - _t * RESOURCE_SPEND_POPUP_RISE,
            $"-{_pop.amount}"
        );
    }
    draw_set_alpha(1);

    // Reset to the default font -- nothing else in this project calls
    // draw_set_font, so every other draw_text call this frame relies on
    // whatever font was last set. Leaving fntResource active would leak
    // into anything drawn after this in the same Draw GUI event.
    draw_set_font(-1);
}
