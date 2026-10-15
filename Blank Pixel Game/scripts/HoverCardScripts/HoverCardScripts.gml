// General-purpose hover/tooltip data overlay -- name plate + wrapped body +
// optional flavor text, base for every specialized hover card. See HoverCardScripts.md.

#macro HOVER_CARD_SCALE               2   // GUI render scale -- layout scales, text does not (see .md)
#macro HOVER_CARD_WIDTH               133 // NATIVE shared width of sHoverCardShort/Mid/Tall
#macro HOVER_CARD_NAME_HEIGHT         20  // NATIVE top strip reserved for the name plate
#macro HOVER_CARD_NAME_OFFSET_X       5   // unused now that the name is centered -- see .md
#macro HOVER_CARD_NAME_OFFSET_Y       11  // NATIVE vertical anchor for the name text
#macro HOVER_CARD_BODY_MARGIN_X       6   // NATIVE left/right padding for the body text's wrap width
#macro HOVER_CARD_BODY_MARGIN_TOP     4   // NATIVE gap between the name plate and the first body line
#macro HOVER_CARD_BODY_MARGIN_BOTTOM  6   // NATIVE gap between the last content and the card's bottom edge
#macro HOVER_CARD_FLAVOR_GAP_TOP      6   // NATIVE gap between the body text and the flavor window
#macro HOVER_CARD_FLAVOR_PADDING_X    4   // NATIVE inset for flavor text inside sHoverCardDataWindow
#macro HOVER_CARD_FLAVOR_PADDING_Y    4
#macro HOVER_CARD_NAME_FONT           "fntDataCard"        // Scribble font name -- must match the font asset's resource name
#macro HOVER_CARD_BODY_FONT           "fntDataCard"
#macro HOVER_CARD_FLAVOR_FONT         "FntDataCardItalics" // exact resource name -- capital F
#macro HOVER_CARD_TEXT_COLOR          make_color_rgb(241, 222, 182) // F1DEB6
#macro HOVER_CARD_SHADOW_COLOR        c_black
#macro HOVER_CARD_SHADOW_OFFSET       1       // px, NATIVE -- not scaled, matching text staying native

// Per-instance counter so multiple simultaneous HoverCards never collide in
// Scribble's (uniqueId + string) cache -- a global, not a #macro, since it
// must persist/increment across calls.
global.__hoverCardNextId = 0;

/// @function HoverCardScaledWidth()
/// @description Every card's actual on-screen width (all 3 sizes share the same native width).
/// @returns {Real}
function HoverCardScaledWidth() {
    return HOVER_CARD_WIDTH * HOVER_CARD_SCALE;
}

/// @function HoverCardBodyWrapWidth()
/// @description Wrap width for a card's body text, in real on-screen pixels.
/// @returns {Real}
function HoverCardBodyWrapWidth() {
    return (HOVER_CARD_WIDTH - (HOVER_CARD_BODY_MARGIN_X * 2)) * HOVER_CARD_SCALE;
}

/// @function HoverCardFlavorWrapWidth()
/// @description Wrap width for a card's flavor text inside sHoverCardDataWindow.
/// @returns {Real}
function HoverCardFlavorWrapWidth() {
    return (sprite_get_width(sHoverCardDataWindow) - (HOVER_CARD_FLAVOR_PADDING_X * 2)) * HOVER_CARD_SCALE;
}

/// @function HoverCardRequiredHeight(_bodyHeight, _hasFlavor, _topContentHeight, _bottomContentHeight)
/// @description Total on-screen card height needed below the name plate.
/// @param {Real} _bodyHeight
/// @param {Bool} _hasFlavor
/// @param {Real} [_topContentHeight] Already-scaled px reserved above the body for a specialized overlay's own content. Not re-multiplied by HOVER_CARD_SCALE (mixes scaled/native internally, see caller). Defaults to 0.
/// @param {Real} [_bottomContentHeight] Same, reserved below the flavor window (or body). Defaults to 0.
/// @returns {Real}
function HoverCardRequiredHeight(_bodyHeight, _hasFlavor, _topContentHeight = 0, _bottomContentHeight = 0) {
    var _height = _topContentHeight + ((HOVER_CARD_NAME_HEIGHT + HOVER_CARD_BODY_MARGIN_TOP) * HOVER_CARD_SCALE) + _bodyHeight;

    if (_hasFlavor) {
        _height += (HOVER_CARD_FLAVOR_GAP_TOP * HOVER_CARD_SCALE) + (sprite_get_height(sHoverCardDataWindow) * HOVER_CARD_SCALE);
    }

    return _height + _bottomContentHeight + (HOVER_CARD_BODY_MARGIN_BOTTOM * HOVER_CARD_SCALE);
}

/// @function ChooseHoverCardSprite(_requiredHeight)
/// @description Smallest of Short/Mid/Tall tall enough to fit _requiredHeight, capped at Tall (see .md re: overflow).
/// @param {Real} _requiredHeight
/// @returns {Asset.GMSprite}
function ChooseHoverCardSprite(_requiredHeight) {
    if (_requiredHeight <= sprite_get_height(sHoverCardShort) * HOVER_CARD_SCALE) return sHoverCardShort;
    if (_requiredHeight <= sprite_get_height(sHoverCardMid) * HOVER_CARD_SCALE)   return sHoverCardMid;
    return sHoverCardTall;
}

#macro HOVER_CARD_PAIR_GAP 8 // already-scaled on-screen px between a primary card and its paired secondary card

/// @function PositionHoverCardPair(_mx, _my, _primaryCard, _secondaryCard, _cardGap, _secondaryAlwaysRight)
/// @description Positions _primaryCard (and _secondaryCard, if given) as a single anchored group -- see .md for the pairing/clamp rationale.
/// @param {Real} _mx GUI-space mouse X.
/// @param {Real} _my GUI-space mouse Y.
/// @param {Struct.HoverCard} _primaryCard
/// @param {Struct.HoverCard|Constant.NoOne} _secondaryCard noone if nothing to pair this frame.
/// @param {Real} [_cardGap] Already-scaled on-screen px between the two cards. Defaults to HOVER_CARD_PAIR_GAP.
/// @param {Bool} [_secondaryAlwaysRight] Forces the secondary card to the primary's right regardless of cursor quadrant. See .md for the tradeoff. Default false.
function PositionHoverCardPair(_mx, _my, _primaryCard, _secondaryCard, _cardGap = HOVER_CARD_PAIR_GAP, _secondaryAlwaysRight = false) {
    var _hasSecondary = (_secondaryCard != noone);

    var _primaryW   = _primaryCard.GetWidth();
    var _primaryH   = _primaryCard.GetHeight();
    var _secondaryW = _hasSecondary ? _secondaryCard.GetWidth()  : 0;
    var _secondaryH = _hasSecondary ? _secondaryCard.GetHeight() : 0;

    var _totalWidth  = _primaryW + (_hasSecondary ? (_cardGap + _secondaryW) : 0);
    var _totalHeight = max(_primaryH, _secondaryH);

    var _anchorLeft = (_mx < display_get_gui_width()  / 2);
    var _anchorTop  = (_my < display_get_gui_height() / 2);

    var _groupX = _anchorLeft ? (_mx + PLOT_HOVER_CURSOR_GAP) : (_mx - PLOT_HOVER_CURSOR_GAP - _totalWidth);
    var _groupY = _anchorTop  ? (_my + PLOT_HOVER_CURSOR_GAP) : (_my - PLOT_HOVER_CURSOR_GAP - _totalHeight);

    _groupX = clamp(_groupX, 0, display_get_gui_width()  - _totalWidth);
    _groupY = clamp(_groupY, 0, display_get_gui_height() - _totalHeight);

    if (_secondaryAlwaysRight) {
        _primaryCard.x = _groupX;
        if (_hasSecondary) _secondaryCard.x = _groupX + _primaryW + _cardGap;
    } else if (_anchorLeft) {
        _primaryCard.x = _groupX;
        if (_hasSecondary) _secondaryCard.x = _groupX + _primaryW + _cardGap;
    } else {
        if (_hasSecondary) _secondaryCard.x = _groupX;
        _primaryCard.x = _hasSecondary ? (_groupX + _secondaryW + _cardGap) : _groupX;
    }

    _primaryCard.y = _groupY;
    if (_hasSecondary) _secondaryCard.y = _groupY;
}

/// @function DrawCardTextWithShadow(_element, _x, _y, _alpha)
/// @description Draws a Scribble text element twice -- shadow offset, then main pass blended with c_white (see .md for why not HOVER_CARD_TEXT_COLOR). Mutates _element's blend state as a side effect.
/// @param {Struct} _element A Scribble text element (nameText/bodyText/flavorText).
/// @param {Real} _x
/// @param {Real} _y
/// @param {Real} _alpha
function DrawCardTextWithShadow(_element, _x, _y, _alpha) {
    _element.blend(HOVER_CARD_SHADOW_COLOR, _alpha).draw(_x, _y + HOVER_CARD_SHADOW_OFFSET);
    _element.blend(c_white, _alpha).draw(_x, _y);
}

/// @function HoverCard()
/// @description General-purpose hover/tooltip overlay. Owner calls Show()/Hide() on hover-state change and Draw() once per Draw GUI event. See HoverCardScripts.md.
function HoverCard() constructor {
    visible    = false;
    x          = 0; // GUI-space top-left corner, in real (post-scale) screen pixels
    y          = 0;
    sprite     = sHoverCardShort;
    hasFlavor  = false; // true if Show() was last given non-empty flavor text
    overflowed = false; // true if the content didn't fit even sHoverCardTall

    // Already-scaled on-screen px a specialized overlay reserved above/below
    // this card's own content via Show()'s trailing params.
    topContentHeight    = 0;
    bottomContentHeight = 0;

    __id = global.__hoverCardNextId++;

    nameText = scribble("", $"__hoverCard{__id}Name__")
        .starting_format(HOVER_CARD_NAME_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_center, fa_middle);

    bodyText = scribble("", $"__hoverCard{__id}Body__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_left, fa_top)
        .wrap(HoverCardBodyWrapWidth());

    flavorText = scribble("", $"__hoverCard{__id}Flavor__")
        .starting_format(HOVER_CARD_FLAVOR_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_left, fa_top)
        .wrap(HoverCardFlavorWrapWidth());

    /// @function Show(_name, _body, _x, _y, _flavor, _topContentHeight, _bottomContentHeight, _flavorFont)
    /// @description Sets content and position, picks the smallest sprite that fits, marks visible. Safe to call every frame the card should show. Callers that need to position based on the card's own size should call with a placeholder x/y, then read GetWidth()/GetHeight() and set x/y directly.
    /// @param {String} _name Name-plate text.
    /// @param {String} _body Body text, wrapped automatically.
    /// @param {Real} _x GUI-space X of the card's top-left corner.
    /// @param {Real} _y GUI-space Y of the card's top-left corner.
    /// @param {String} [_flavor] Optional flavor text, shown only when non-empty. Defaults to "".
    /// @param {Real} [_topContentHeight] Already-scaled px to reserve above the body text. Defaults to 0.
    /// @param {Real} [_bottomContentHeight] Already-scaled px to reserve below the flavor window (or body). Defaults to 0.
    /// @param {String} [_flavorFont] Font override for the flavor window. Defaults to HOVER_CARD_FLAVOR_FONT.
    /// @returns {Struct.HoverCard} self
    static Show = function(_name, _body, _x, _y, _flavor = "", _topContentHeight = 0, _bottomContentHeight = 0, _flavorFont = HOVER_CARD_FLAVOR_FONT) {
        nameText = scribble(_name, $"__hoverCard{__id}Name__")
            .starting_format(HOVER_CARD_NAME_FONT, HOVER_CARD_TEXT_COLOR)
            .align(fa_center, fa_middle);

        bodyText = scribble(_body, $"__hoverCard{__id}Body__")
            .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
            .align(fa_left, fa_top)
            .wrap(HoverCardBodyWrapWidth());

        hasFlavor = (_flavor != "");
        if (hasFlavor) {
            flavorText = scribble(_flavor, $"__hoverCard{__id}Flavor__")
                .starting_format(_flavorFont, HOVER_CARD_TEXT_COLOR)
                .align(fa_left, fa_top)
                .wrap(HoverCardFlavorWrapWidth());
        }

        topContentHeight    = _topContentHeight;
        bottomContentHeight = _bottomContentHeight;

        var _requiredHeight = HoverCardRequiredHeight(bodyText.get_height(), hasFlavor, topContentHeight, bottomContentHeight);
        sprite     = ChooseHoverCardSprite(_requiredHeight);
        overflowed = _requiredHeight > sprite_get_height(sHoverCardTall) * HOVER_CARD_SCALE;

        x       = _x;
        y       = _y;
        visible = true;
        return self;
    }

    /// @function Hide()
    /// @returns {Struct.HoverCard} self
    static Hide = function() {
        visible = false;
        return self;
    }

    /// @function GetWidth()
    /// @description This card's real on-screen width -- constant across all 3 sprites (same native width).
    /// @returns {Real}
    static GetWidth = function() {
        return HoverCardScaledWidth();
    }

    /// @function GetHeight()
    /// @description This card's real on-screen height for whichever sprite Show() most recently picked.
    /// @returns {Real}
    static GetHeight = function() {
        return sprite_get_height(sprite) * HOVER_CARD_SCALE;
    }

    /// @function GetContentTopY()
    /// @description Y immediately below the name plate, before topContentHeight's offset -- where a specialized overlay's own top content should start drawing. Only meaningful after Show().
    /// @returns {Real}
    static GetContentTopY = function() {
        return y + (HOVER_CARD_NAME_HEIGHT + HOVER_CARD_BODY_MARGIN_TOP) * HOVER_CARD_SCALE;
    }

    /// @function GetContentBottomY()
    /// @description Y immediately below this card's last drawn content (flavor window if hasFlavor, else body text) -- where a specialized overlay's own bottom content should start drawing. Only meaningful after Show().
    /// @returns {Real}
    static GetContentBottomY = function() {
        var _bodyY = GetContentTopY() + topContentHeight;

        if (hasFlavor) {
            var _windowY = _bodyY + bodyText.get_height() + HOVER_CARD_FLAVOR_GAP_TOP * HOVER_CARD_SCALE;
            return _windowY + sprite_get_height(sHoverCardDataWindow) * HOVER_CARD_SCALE;
        }

        return _bodyY + bodyText.get_height();
    }

    /// @function Draw(_alpha)
    /// @description Call once per Draw GUI event. Draws nothing while hidden or fully transparent. Name plate is centered horizontally; body/flavor stay left-aligned.
    /// @param {Real} [_alpha] 0-1 fade level. Defaults to fully opaque.
    static Draw = function(_alpha = 1) {
        if (!visible || _alpha <= 0) return;

        draw_sprite_ext(sprite, 0, x, y, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);

        DrawCardTextWithShadow(nameText, x + (HOVER_CARD_WIDTH * HOVER_CARD_SCALE) / 2, y + HOVER_CARD_NAME_OFFSET_Y * HOVER_CARD_SCALE, _alpha);

        var _bodyX = x + HOVER_CARD_BODY_MARGIN_X * HOVER_CARD_SCALE;
        var _bodyY = GetContentTopY() + topContentHeight;
        DrawCardTextWithShadow(bodyText, _bodyX, _bodyY, _alpha);

        if (hasFlavor) {
            var _windowX = x + HOVER_CARD_BODY_MARGIN_X * HOVER_CARD_SCALE;
            var _windowY = _bodyY + bodyText.get_height() + HOVER_CARD_FLAVOR_GAP_TOP * HOVER_CARD_SCALE;

            draw_sprite_ext(sHoverCardDataWindow, 0, _windowX, _windowY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);

            var _flavorX = _windowX + HOVER_CARD_FLAVOR_PADDING_X * HOVER_CARD_SCALE;
            var _flavorY = _windowY + HOVER_CARD_FLAVOR_PADDING_Y * HOVER_CARD_SCALE;
            DrawCardTextWithShadow(flavorText, _flavorX, _flavorY, _alpha);
        }
    }
}
