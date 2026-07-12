// -----------------------------------------------------------
// HoverCardScripts -- general-purpose hover/tooltip data overlay. 2026-07-06
// request, step 1 of 4: this pass builds the reusable BASE (a name plate +
// a wrapped text body, auto-sized to the smallest card sprite that fits)
// that later passes will layer unit data, building data, and event data on
// top of. The specialized sprites sHoverCardBuildingWindow/sHoverCardTimer/
// sHoverCardUnitWindow (all in "In Game/UI/Assets/DataOverlays", same
// folder as the 3 card sprites below) are still NOT wired up -- out of
// scope for this pass. sHoverCardDataWindow (also that folder) IS wired up
// now (see below) as an optional secondary "flavor text" region.
//
// Card sprites (sHoverCardShort/Mid/Tall) all share the same 133px NATIVE
// width and a top-left origin; only height differs (148/185/222 native).
// Per spec, the top HOVER_CARD_NAME_HEIGHT (20 native) px of every card's
// art is a name plate -- nothing is drawn there except the name text
// itself, left-middle aligned, anchored at (5, 11) native relative to the
// card's top-left corner.
//
// 2026-07-06 follow-up: the CARD SPRITE (and sHoverCardDataWindow, below)
// render at HOVER_CARD_SCALE (2x), same "most UI items render at 2x"
// convention as XpBarWidget/FateDrum. TEXT stays at native (1x) glyph
// size, per a same-day correction ("text can be rendered at 1x... it does
// not need to be scaled up with everything else") -- nameText/bodyText/
// flavorText carry no Scribble .scale() call. Only the LAYOUT -- positions,
// margins, wrap width -- scales by HOVER_CARD_SCALE, so native-sized
// glyphs sit correctly placed within the visually-2x card.
//
// 2026-07-06 second follow-up: every data card now uses fntDataCard for
// BOTH the name plate and the normal body text (previously fnt_gm_20/
// fnt_gm_15), plus a new optional secondary region -- fed via Show()'s
// _flavor param -- rendered in FntDataCardItalics inside sHoverCardDataWindow
// below the main body (per the ORIGINAL spec: "sHoverCardDataWindow: used
// for secondary data... on buildings, this is for the flavor text
// (italicized)"). sHoverCardDataWindow's native width (121) exactly equals
// HoverCardBodyWrapWidth()'s native value (133 - 6*2), so it lines up
// flush with the body text's left/right margins with zero extra alignment
// math needed. All card text now renders in HOVER_CARD_TEXT_COLOR (F1DEB6)
// with a 1px downward drop shadow (HOVER_CARD_SHADOW_COLOR) -- see
// DrawCardTextWithShadow(), a simple double-draw (Scribble has no built-in
// runtime shadow effect; scribble_font_bake_shadow.gml bakes a whole new
// FONT ASSET instead, a heavier one-time step this project doesn't use
// anywhere, so a plain offset-and-redraw is the lighter-weight match).
//
// Uses Scribble (already wired into this project -- see
// oAlphaDisclaimer/Create_0.gml's disclaimerText, and
// ResourceUIScripts.gml's CostToScribbleText/draw_text_scribble_ext)
// instead of raw draw_text_ext: Scribble's .wrap()/.get_height() is what
// makes "does this text fit in card X" answerable AHEAD of drawing, which
// plain draw_text_ext can't do without a parallel string_height_ext guess.
// scribble(_string, _uniqueId) is cheap to call every frame with the same
// arguments -- it's a cache lookup keyed on (uniqueId + string), not a
// rebuild (see scripts/scribble/scribble.gml) -- so Show() below just
// re-requests an element each call rather than mutating one in place
// (Scribble elements have no "change this element's text" setter).
// -----------------------------------------------------------

#macro HOVER_CARD_SCALE               2   // GUI render scale -- "most UI items render at 2x", 2026-07-06 request
#macro HOVER_CARD_WIDTH               133 // NATIVE shared width of sHoverCardShort/Mid/Tall -- multiply by HOVER_CARD_SCALE for on-screen size
#macro HOVER_CARD_NAME_HEIGHT         20  // NATIVE top strip reserved for the name plate baked into the card art
#macro HOVER_CARD_NAME_OFFSET_X       5   // NATIVE name text anchor relative to the card's top-left -- ORIGINAL spec: "aligned left-middle, anchored at 5,11". 2026-07-07: name is now horizontally CENTERED (see nameText's .align() and Draw() below), so this X offset is currently unused -- kept in case a future specialized card variant wants the old left-anchor behavior; flag if it should just be deleted instead.
#macro HOVER_CARD_NAME_OFFSET_Y       11  // still used -- vertical anchor is unchanged, only horizontal centering was requested
#macro HOVER_CARD_BODY_MARGIN_X       6   // NATIVE left/right padding subtracted from HOVER_CARD_WIDTH for the body text's wrap width
#macro HOVER_CARD_BODY_MARGIN_TOP     4   // NATIVE gap between the name plate and the first line of body text
#macro HOVER_CARD_BODY_MARGIN_BOTTOM  6   // NATIVE gap between the last content (body, or the flavor window if present) and the card's bottom edge
#macro HOVER_CARD_FLAVOR_GAP_TOP      6   // NATIVE gap between the end of the body text and the top of the flavor sHoverCardDataWindow
#macro HOVER_CARD_FLAVOR_PADDING_X    4   // NATIVE inset for the flavor text inside sHoverCardDataWindow
#macro HOVER_CARD_FLAVOR_PADDING_Y    4
#macro HOVER_CARD_NAME_FONT           "fntDataCard"        // Scribble font name -- must match the font ASSET's resource name exactly (font_get_name-equivalent)
#macro HOVER_CARD_BODY_FONT           "fntDataCard"
#macro HOVER_CARD_FLAVOR_FONT         "FntDataCardItalics" // exact resource name -- capital F, see fonts/FntDataCardItalics/FntDataCardItalics.yy
#macro HOVER_CARD_TEXT_COLOR          make_color_rgb(241, 222, 182) // F1DEB6, 2026-07-06 request -- every data card's text
#macro HOVER_CARD_SHADOW_COLOR        c_black // 1px downward drop shadow color -- not specified by the request, black is the conventional default
#macro HOVER_CARD_SHADOW_OFFSET       1       // px, NATIVE -- NOT scaled by HOVER_CARD_SCALE, matching text itself staying native

// Per-instance counter so multiple simultaneous HoverCards (e.g. a
// unit-hover card AND a building-hover card open at once, once those land)
// never collide in Scribble's (uniqueId + string) cache -- see the file
// header. A plain global, not a #macro -- must persist/increment across
// calls, which a macro (re-expanded at every reference) can't do.
global.__hoverCardNextId = 0;

/// @function HoverCardScaledWidth()
/// @description HOVER_CARD_WIDTH at HOVER_CARD_SCALE -- every card's actual
///        on-screen width, since all 3 sizes share the same native width.
/// @returns {Real}
function HoverCardScaledWidth() {
    return HOVER_CARD_WIDTH * HOVER_CARD_SCALE;
}

/// @function HoverCardBodyWrapWidth()
/// @description The wrap width available to a hover card's body text, in
///        real on-screen pixels -- HOVER_CARD_WIDTH minus left+right
///        margins, scaled by HOVER_CARD_SCALE to match the card's actual
///        on-screen width. Text itself renders at native (1x) glyph size
///        (see file header), so this scaled width just means more native-
///        sized text fits per line inside the visually wider card. Shared
///        by every card size since they're all the same width; only
///        height varies. Also exactly matches sHoverCardDataWindow's
///        native width (121 = 133 - 6*2), so the flavor window lines up
///        flush with the body text below it.
/// @returns {Real}
function HoverCardBodyWrapWidth() {
    return (HOVER_CARD_WIDTH - (HOVER_CARD_BODY_MARGIN_X * 2)) * HOVER_CARD_SCALE;
}

/// @function HoverCardFlavorWrapWidth()
/// @description The wrap width available to a hover card's flavor text
///        inside sHoverCardDataWindow -- that sprite's native width minus
///        left+right HOVER_CARD_FLAVOR_PADDING_X insets, scaled.
/// @returns {Real}
function HoverCardFlavorWrapWidth() {
    return (sprite_get_width(sHoverCardDataWindow) - (HOVER_CARD_FLAVOR_PADDING_X * 2)) * HOVER_CARD_SCALE;
}

/// @function HoverCardRequiredHeight(_bodyHeight, _hasFlavor, _topContentHeight, _bottomContentHeight)
/// @description Total on-screen card height needed below the name plate:
///        an optional _topContentHeight block (2026-07-08 addition -- see
///        Show()), the body text (_bodyHeight -- a Scribble get_height(),
///        native glyph size since body text isn't scaled) plus its top
///        margin, optionally the flavor sHoverCardDataWindow (fixed native
///        size, scaled) plus its own top gap if _hasFlavor, an optional
///        _bottomContentHeight block (2026-07-08 addition), and the bottom
///        margin -- all margins scaled to match the card's on-screen size.
/// @param {Real} _bodyHeight
/// @param {Bool} _hasFlavor
/// @param {Real} [_topContentHeight] Already-scaled on-screen px reserved
///        ABOVE the body text for a specialized overlay's own content (e.g.
///        BuildingHoverScripts.gml's icon row) -- unlike every other
///        dimension in this function, this one is NOT re-multiplied by
///        HOVER_CARD_SCALE here, because it mixes scaled sprite heights
///        with native text heights internally (see BuildingHoverScripts.gml
///        callers) and can't be scaled as a single native value. Defaults
///        to 0 (no extra top content) -- PlotHoverController's existing
///        Show() call doesn't pass this, so plot hover cards are completely
///        unaffected.
/// @param {Real} [_bottomContentHeight] Same deal, but reserved BELOW the
///        flavor window (or body text, if no flavor) -- e.g. a blueprint
///        tooltip's cost row. Defaults to 0.
/// @returns {Real}
function HoverCardRequiredHeight(_bodyHeight, _hasFlavor, _topContentHeight = 0, _bottomContentHeight = 0) {
    var _height = _topContentHeight + ((HOVER_CARD_NAME_HEIGHT + HOVER_CARD_BODY_MARGIN_TOP) * HOVER_CARD_SCALE) + _bodyHeight;

    if (_hasFlavor) {
        _height += (HOVER_CARD_FLAVOR_GAP_TOP * HOVER_CARD_SCALE) + (sprite_get_height(sHoverCardDataWindow) * HOVER_CARD_SCALE);
    }

    return _height + _bottomContentHeight + (HOVER_CARD_BODY_MARGIN_BOTTOM * HOVER_CARD_SCALE);
}

/// @function ChooseHoverCardSprite(_requiredHeight)
/// @description The smallest of sHoverCardShort / sHoverCardMid /
///        sHoverCardTall (each compared at HOVER_CARD_SCALE, i.e. their
///        real on-screen height) tall enough to fit _requiredHeight,
///        capped at Tall -- if even Tall isn't enough, this still returns
///        Tall (the content will run past the card's bottom edge; no
///        truncation/scrolling exists yet -- see HoverCard.Show()'s
///        overflowed flag).
/// @param {Real} _requiredHeight
/// @returns {Asset.GMSprite}
function ChooseHoverCardSprite(_requiredHeight) {
    if (_requiredHeight <= sprite_get_height(sHoverCardShort) * HOVER_CARD_SCALE) return sHoverCardShort;
    if (_requiredHeight <= sprite_get_height(sHoverCardMid) * HOVER_CARD_SCALE)   return sHoverCardMid;
    return sHoverCardTall;
}

#macro HOVER_CARD_PAIR_GAP 8 // already-scaled on-screen px between a primary card and its paired secondary card -- 2026-07-11 addition, PositionHoverCardPair. Same value as PLOT_HOVER_CURSOR_GAP (PlotHoverScripts.gml) -- not reusing that macro directly since it's conceptually "mouse-to-card" distance, not "card-to-card", even though they happen to match today.

/// @function PositionHoverCardPair(_mx, _my, _primaryCard, _secondaryCard, _cardGap)
/// @description Positions _primaryCard (and _secondaryCard, if given) as a
///        single anchored group -- 2026-07-11 addition, first needed by the
///        unit hover card pairing with a training building's own hover card
///        (UnitHoverScripts.gml, BuildingHoverScripts.gml,
///        BlueprintScripts.gml). Same quadrant-anchor-away-from-cursor +
///        screen-edge clamp every existing hover card already uses
///        (PlotHoverController, BuildingHoverController,
///        BlueprintController.UpdateHover), but the anchor-flip and clamp
///        are computed against the COMBINED width/height of both cards
///        instead of just one -- per the "anchoring... should be in
///        relation to both cards, not just the core building card" request
///        -- so the pair can't get clamped in a way that separates them or
///        pushes one off-screen while the other stays put.
///        _primaryCard always sits on the side NEAREST the cursor (same
///        gap every single-card hover controller already used);
///        _secondaryCard sits immediately beyond it, further from the
///        cursor, both cards' tops aligned. Mutates both cards' .x/.y
///        fields directly -- same convention every hover controller
///        already follows. Caller must call Show() on both cards first
///        (this reads their current GetWidth()/GetHeight()).
///        Passing _secondaryCard = noone collapses this to EXACTLY the
///        original single-card positioning math every existing caller used
///        (_totalWidth/_totalHeight reduce to just the primary card's own
///        size) -- BuildingHoverController and BlueprintController.UpdateHover
///        both now route their non-training-building case through this same
///        function rather than keeping a separate duplicate of the old math.
/// @param {Real} _mx GUI-space mouse X.
/// @param {Real} _my GUI-space mouse Y.
/// @param {Struct.HoverCard} _primaryCard
/// @param {Struct.HoverCard|Constant.NoOne} _secondaryCard noone if there's
///        nothing to pair this frame (e.g. a non-training building/blueprint).
/// @param {Real} [_cardGap] Already-scaled on-screen px between the two
///        cards. Defaults to HOVER_CARD_PAIR_GAP.
/// @param {Bool} [_secondaryAlwaysRight] 2026-07-11 addition: when true, the
///        secondary card always sits to the primary's RIGHT, regardless of
///        cursor quadrant -- normal behavior otherwise flips which card is
///        nearest the cursor depending on which half of the screen the
///        cursor's in (see the two branches below), which BuildingHoverController's
///        placed-training-building pairing no longer wants ("always have it
///        on the right side of the building's card"). The overall group's
///        position (which side of the cursor it sits on, and the screen-edge
///        clamp) is UNCHANGED by this -- only the left/right ordering of the
///        two cards within that group is forced. Consequence: when the
///        cursor is in the right half of the screen, the primary card is no
///        longer guaranteed nearest the cursor in this mode (the secondary
///        is, since it's forced to primary's right while the group still
///        anchors its right edge near the cursor) -- accepted tradeoff for
///        the explicit "always right" request. Default false (existing
///        quadrant-flip behavior, unchanged for every other caller).
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

    // Primary always sits nearest the cursor -- which physical side that is
    // flips with _anchorLeft, since _groupX already points at whichever edge
    // is "away from the cursor" for this quadrant. _secondaryAlwaysRight
    // overrides this ordering (see doc above) while leaving _groupX/_groupY's
    // own position -- and thus the screen-edge clamp -- untouched.
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
/// @description Draws a Scribble text element twice -- once
///        HOVER_CARD_SHADOW_OFFSET px down in HOVER_CARD_SHADOW_COLOR, then
///        again at (_x, _y) in each glyph's OWN colour -- the "1px downward
///        drop shadow" every data card's text uses, 2026-07-06 request.
///
///        2026-07-07 correction: the main pass now blends with c_white, not
///        HOVER_CARD_TEXT_COLOR. Confirmed via __shd_scribble.vsh:
///        `v_vColour = in_Colour * u_vColourBlend` -- .blend() MULTIPLIES
///        onto each glyph's already-baked-in colour (set at generation time
///        by .starting_format()'s colour param, or overridden per-run by an
///        inline [c_lime]/[c_red]/etc. tag -- see PlotHoverBonusText,
///        PlotHoverScripts.gml, for the first real user of colour tags), it
///        does NOT override it. Blending with HOVER_CARD_TEXT_COLOR (as
///        this did through v0.0.2.45) multiplied every glyph against
///        itself -- plain text was quietly darker/more saturated than the
///        actual F1DEB6 value, and any colour-tagged run would have washed
///        toward F1DEB6 instead of showing its real colour. c_white is the
///        multiplicative identity, so plain text now renders at the exact
///        starting_format colour and tagged runs render their own colour
///        correctly. The SHADOW pass is unaffected by this distinction --
///        c_black multiplied by anything is still black, so it was already
///        correct.
///
///        Mutates _element's blend state (via .blend()) as a side effect,
///        same as any other Scribble draw call in this file.
/// @param {Struct} _element A Scribble text element (nameText/bodyText/flavorText).
/// @param {Real} _x
/// @param {Real} _y
/// @param {Real} _alpha
function DrawCardTextWithShadow(_element, _x, _y, _alpha) {
    _element.blend(HOVER_CARD_SHADOW_COLOR, _alpha).draw(_x, _y + HOVER_CARD_SHADOW_OFFSET);
    _element.blend(c_white, _alpha).draw(_x, _y);
}

/// @function HoverCard()
/// @description General-purpose hover/tooltip data overlay: a name plate +
///        a wrapped text body, plus an OPTIONAL secondary "flavor text"
///        region (sHoverCardDataWindow, italic font) below the body --
///        auto-picking the smallest card sprite that fits everything
///        currently shown (ChooseHoverCardSprite), rendered at
///        HOVER_CARD_SCALE. Owner calls Show()/Hide() when hover state
///        changes and Draw() once per Draw GUI event -- same "plain
///        struct, owner drives Step/Draw" pattern as BlueprintController/
///        FateDrum/XpBarWidget. No Step() needed here -- purely static
///        content, nothing animates.
///
///        This is the intentional attachment point for the follow-up
///        passes (unit/building/event data): a specialized overlay can
///        either wrap a HoverCard (call its Show/Draw, then draw its own
///        extra sprites -- building/unit/timer windows -- at fixed offsets
///        from the same x/y) or extend it with more fields directly.
///        Nothing here assumes a specific data source (unit vs. building
///        vs. event) -- it only knows about a name, a body string, and an
///        optional flavor string.
function HoverCard() constructor {
    visible    = false;
    x          = 0; // GUI-space top-left corner, in real (post-scale) screen pixels
    y          = 0;
    sprite     = sHoverCardShort;
    hasFlavor  = false; // true if Show() was last given non-empty flavor text -- see Show()
    overflowed = false; // true if the content didn't fit even sHoverCardTall -- see Show()

    // 2026-07-08 addition (BuildingHoverScripts.gml) -- already-scaled
    // on-screen px a specialized overlay reserved above/below this card's
    // own content via Show()'s trailing params. Both default 0, so a caller
    // that never passes them (PlotHoverController) sees byte-for-byte the
    // same layout as before this pass.
    topContentHeight    = 0;
    bottomContentHeight = 0;

    __id = global.__hoverCardNextId++;

    nameText = scribble("", $"__hoverCard{__id}Name__")
        .starting_format(HOVER_CARD_NAME_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_center, fa_middle); // 2026-07-07 request: title is centered; body/flavor stay left-aligned, see those below

    bodyText = scribble("", $"__hoverCard{__id}Body__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_left, fa_top)
        .wrap(HoverCardBodyWrapWidth());

    flavorText = scribble("", $"__hoverCard{__id}Flavor__")
        .starting_format(HOVER_CARD_FLAVOR_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_left, fa_top)
        .wrap(HoverCardFlavorWrapWidth());

    /// @function Show(_name, _body, _x, _y, _flavor, _topContentHeight, _bottomContentHeight, _flavorFont)
    /// @description Sets this card's content and GUI-space position, picks
    ///        the smallest sprite that fits everything currently shown,
    ///        and marks the card visible. Safe to call every frame the
    ///        card should be showing (e.g. every Step while hovering
    ///        something) -- see the file header on why re-requesting a
    ///        Scribble element every call is cheap rather than wasteful.
    ///        Callers that need to position the card based on its OWN size
    ///        (e.g. anchoring away from the mouse) should call this with a
    ///        placeholder _x/_y first, then read GetWidth()/GetHeight() and
    ///        set the x/y fields directly afterward -- see
    ///        PlotHoverController.Step (PlotHoverScripts.gml) for the
    ///        established pattern.
    /// @param {String} _name Name-plate text -- plain string, no font tag
    ///        needed (the element's starting_format already fixes the font).
    /// @param {String} _body Body text -- plain string, wrapped
    ///        automatically at HoverCardBodyWrapWidth().
    /// @param {Real} _x GUI-space X of the card's top-left corner.
    /// @param {Real} _y GUI-space Y of the card's top-left corner.
    /// @param {String} [_flavor] Optional secondary "flavor text" -- shown
    ///        italicized inside sHoverCardDataWindow below the body, only
    ///        when non-empty. Defaults to "" (no flavor region at all).
    /// @param {Real} [_topContentHeight] 2026-07-08 addition -- already-
    ///        scaled on-screen px to reserve ABOVE the body text, for a
    ///        specialized overlay's own content (see BuildingHoverScripts.gml
    ///        for the first user of this -- its building/timer/item icon
    ///        row). The caller draws that content itself, at
    ///        GetContentTopY() and up; this param only makes room for it so
    ///        body text/card sizing don't overlap it. Defaults to 0.
    /// @param {Real} [_bottomContentHeight] Same, but reserved BELOW the
    ///        flavor window (or body text, if no flavor) -- e.g. a blueprint
    ///        tooltip's cost row, drawn by the caller starting at
    ///        GetContentBottomY(). Defaults to 0.
    /// @param {String} [_flavorFont] 2026-07-11 addition (unit hover card
    ///        request) -- font override for the flavor window's text.
    ///        Defaults to HOVER_CARD_FLAVOR_FONT (italic), so every existing
    ///        caller (plot/building/blueprint hover) is byte-for-byte
    ///        unaffected. UnitHoverScripts.gml's unit card is the first
    ///        caller to pass HOVER_CARD_BODY_FONT instead -- that card
    ///        repurposes the "usual flavor text window" to show Station/
    ///        Deploy Cost + the stationed passive as plain (non-italic) data
    ///        rather than actual flavor text, per that request.
    /// @returns {Struct.HoverCard} self
    static Show = function(_name, _body, _x, _y, _flavor = "", _topContentHeight = 0, _bottomContentHeight = 0, _flavorFont = HOVER_CARD_FLAVOR_FONT) {
        nameText = scribble(_name, $"__hoverCard{__id}Name__")
            .starting_format(HOVER_CARD_NAME_FONT, HOVER_CARD_TEXT_COLOR)
            .align(fa_center, fa_middle); // 2026-07-07 request: centered -- must match the constructor's nameText above

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
    /// @description This card's real on-screen width (HOVER_CARD_SCALE
    ///        applied) -- constant regardless of which sprite is currently
    ///        selected, since all 3 share the same native width.
    /// @returns {Real}
    static GetWidth = function() {
        return HoverCardScaledWidth();
    }

    /// @function GetHeight()
    /// @description This card's real on-screen height (HOVER_CARD_SCALE
    ///        applied), for whichever sprite Show() most recently picked.
    /// @returns {Real}
    static GetHeight = function() {
        return sprite_get_height(sprite) * HOVER_CARD_SCALE;
    }

    /// @function GetContentTopY()
    /// @description 2026-07-08 addition. The Y coordinate immediately below
    ///        the name plate, BEFORE topContentHeight's offset is applied --
    ///        i.e. exactly where a specialized overlay's own top content
    ///        (e.g. BuildingHoverScripts.gml's icon row) should start
    ///        drawing. Body text itself starts topContentHeight px further
    ///        down than this -- see Draw(). Only meaningful after Show()
    ///        has been called (reads x/y, which Show() sets).
    /// @returns {Real}
    static GetContentTopY = function() {
        return y + (HOVER_CARD_NAME_HEIGHT + HOVER_CARD_BODY_MARGIN_TOP) * HOVER_CARD_SCALE;
    }

    /// @function GetContentBottomY()
    /// @description 2026-07-08 addition. The Y coordinate immediately below
    ///        this card's LAST drawn content -- the flavor window if
    ///        hasFlavor, otherwise the body text -- i.e. exactly where a
    ///        specialized overlay's own bottom content (e.g. a blueprint
    ///        tooltip's cost row) should start drawing. Duplicates the same
    ///        math Draw() uses internally so external callers never have to
    ///        keep a second copy in sync by hand. Only meaningful after
    ///        Show() has been called.
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
    /// @description Call once per Draw GUI event. Draws nothing while
    ///        hidden or fully transparent. Name plate text is horizontally
    ///        CENTERED within the card's width (2026-07-07 request),
    ///        vertically anchored at HOVER_CARD_NAME_OFFSET_Y native px
    ///        (scaled) relative to the card's top-left -- body/flavor text
    ///        are UNCHANGED, still left-aligned, per the same request
    ///        ("keep the rest of the text as it is"). Body text starts HOVER_CARD_BODY_MARGIN_TOP
    ///        (scaled) px below the name plate strip -- PLUS topContentHeight
    ///        (2026-07-08 addition, 0 unless Show() was given one) for a
    ///        specialized overlay's own content drawn above it (see
    ///        GetContentTopY()) -- left-top aligned, wrapped to
    ///        HoverCardBodyWrapWidth(). If hasFlavor, draws
    ///        sHoverCardDataWindow HOVER_CARD_FLAVOR_GAP_TOP (scaled) px
    ///        below the body text, with the italic flavor text inset
    ///        HOVER_CARD_FLAVOR_PADDING_X/Y (scaled) inside it. Every text
    ///        element draws via DrawCardTextWithShadow (1px drop shadow,
    ///        F1DEB6 main color).
    /// @param {Real} [_alpha] 0-1 fade level, applied to the card sprite
    ///        (draw_sprite_ext), the flavor window sprite, and every text
    ///        element (Scribble's .blend()). Defaults to fully opaque.
    static Draw = function(_alpha = 1) {
        if (!visible || _alpha <= 0) return;

        draw_sprite_ext(sprite, 0, x, y, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);

        // Centered horizontally (2026-07-07 request) -- nameText's fa_center
        // alignment means this X is the text's horizontal CENTER point, so
        // it's the card's own horizontal center, not HOVER_CARD_NAME_OFFSET_X
        // (that offset is now unused -- see its macro comment above).
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
