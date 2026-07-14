// -----------------------------------------------------------
// DropDownMenuScripts -- shared sprite-based rendering for every drop-down/
// panel menu (OrderMenu, CastleGarrisonMenu, SelectionSummaryMenu) --
// 2026-07-12 request: replace the old plain draw_rectangle_color panels
// with the sDropDownMenuTop/sDropDownMenuMiddle/sDropDowmMenuBottom sprite
// set, plus a title on every menu ("Orders"/"Castle"/"Selected").
//
// 2026-07-13 addition: PositionDropDownMenuFromClick (see below) -- shared
// mouse-dependent anchoring for menus that open from a click, matching the
// same "quadrant-anchor-away-from-cursor + screen-edge clamp" logic every
// hover card already uses (PositionHoverCardPair, HoverCardScripts.gml).
// OrderMenu and CastleGarrisonMenu both now call this from their own Open().
// Deliberately NOT used by ArmyLimitMenu (no click position exists to
// anchor from -- fixed HUD-icon trigger) or SelectionSummaryMenu (stays a
// fixed top-left panel, unrelated to any click) -- both explicitly excluded
// from this request.
//
// NOTE: the bottom sprite's actual asset name is "sDropDowmMenuBottom"
// (missing the second "n" in "Down") -- a pre-existing typo in the asset
// as it was added to the project. Used verbatim below rather than renamed,
// since renaming an already-placed asset wasn't asked for; flagging.
//
// Layout, per the request:
//   1. TOP sprite (sDropDownMenuTop, single frame) -- the menu's title,
//      centered text. Never hoverable/clickable.
//   2. BOTTOM sprite (sDropDowmMenuBottom, 2 frames -- 0 normal, 1 hover)
//      -- the LAST/bottom-most option row only.
//   3. MIDDLE sprite (sDropDownMenuMiddle, 2 frames -- 0 normal, 1 hover)
//      -- every option row ABOVE the bottom-most one.
// Stacked seamlessly top-to-bottom (title, then middle rows in order, then
// the bottom row last) -- no gap between pieces, matching how a sprite set
// like this is normally authored to tile into one continuous panel.
//
// All three sprites have a top-left origin (confirmed via their .yy --
// "origin":0), so every _x/_y below is a sprite's own top-left screen
// corner -- no center-based offset math needed anywhere in this file.
// All three share DROPDOWN_MENU_SCALE (2x, per the request) and native
// width (133, shared across all three -- there's one menu width for the
// whole stack, not a per-piece one).
//
// Option text is left-aligned, DROPDOWN_MENU_TEXT_PAD_X in from the row's
// left edge, per the request's literal "text aligned to the left edge,
// with a 6 px buffer". Treated as a NATIVE px value, scaled by
// DROPDOWN_MENU_SCALE like every other sizing constant in this file --
// the request didn't specify native vs. on-screen, flagging this as the
// interpretation used. For a menu whose rows also show an icon
// (CastleGarrisonMenu, SelectionSummaryMenu), this buffer is where the
// ICON starts (unchanged from before), not a second, additional inset
// before the text that follows it -- the request's alignment/buffer rule
// reads as being about the row's own left edge, not specifically about
// icon-less rows, and this preserves each menu's existing icon+gap+text
// sequencing rather than inventing a new one.
// -----------------------------------------------------------

#macro DROPDOWN_MENU_SCALE      2 // 2026-07-12 request -- all three drop-down sprites drawn at 2x
#macro DROPDOWN_MENU_TEXT_PAD_X 6 // native px left-edge text/icon buffer (request's literal "6 px buffer") -- see file header for the native-vs-scaled call

/// @function DropDownMenuWidth()
/// @description On-screen (scaled) width shared by all three drop-down
///        sprites -- there's a single menu width for the whole stack
///        (title + every row), not a per-piece one.
/// @returns {Real}
function DropDownMenuWidth() {
    return sprite_get_width(sDropDownMenuTop) * DROPDOWN_MENU_SCALE;
}

/// @function DropDownMenuTitleHeight()
/// @returns {Real} On-screen height of the title row (sDropDownMenuTop).
function DropDownMenuTitleHeight() {
    return sprite_get_height(sDropDownMenuTop) * DROPDOWN_MENU_SCALE;
}

/// @function DropDownMenuRowHeight(_isBottom)
/// @description On-screen height of one option row -- sDropDowmMenuBottom
///        for the bottom-most option, sDropDownMenuMiddle for every other
///        option above it.
/// @param {Bool} _isBottom
/// @returns {Real}
function DropDownMenuRowHeight(_isBottom) {
    return sprite_get_height(_isBottom ? sDropDowmMenuBottom : sDropDownMenuMiddle) * DROPDOWN_MENU_SCALE;
}

/// @function DropDownMenuTotalHeight(_rowCount)
/// @description Total on-screen height of a full menu -- the title plus
///        every option row (the last one counted at the bottom sprite's
///        height, every other at the middle sprite's height). _rowCount
///        <= 0 returns just the title's height (a menu with zero rows is
///        the caller's call to make -- none of today's three menus ever
///        actually have zero: CastleGarrisonMenu always has at least its
///        "--" placeholder row, and the other two simply don't open/show
///        with nothing to display).
/// @param {Real} _rowCount
/// @returns {Real}
function DropDownMenuTotalHeight(_rowCount) {
    var _h = DropDownMenuTitleHeight();
    if (_rowCount <= 0) return _h;

    _h += DropDownMenuRowHeight(false) * (_rowCount - 1); // every row except the last
    _h += DropDownMenuRowHeight(true);                    // the last row
    return _h;
}

/// @function DropDownMenuHitTest(_x, _y, _rowCount, _mx, _my)
/// @description Returns the index (0-based, counting only option rows --
///        the title is never included/hoverable) of whichever row the
///        given GUI-space point falls inside, or -1 if it's outside every
///        row (including over the title itself). Shared hit-test math for
///        every drop-down menu's Update()/Step().
/// @param {Real} _x Menu's top-left X.
/// @param {Real} _y Menu's top-left Y.
/// @param {Real} _rowCount
/// @param {Real} _mx GUI-space mouse X.
/// @param {Real} _my GUI-space mouse Y.
/// @returns {Real}
function DropDownMenuHitTest(_x, _y, _rowCount, _mx, _my) {
    if (_mx < _x || _mx > _x + DropDownMenuWidth()) return -1;

    var _rowY = _y + DropDownMenuTitleHeight();
    for (var i = 0; i < _rowCount; i++) {
        var _isBottom = (i == _rowCount - 1);
        var _rowH     = DropDownMenuRowHeight(_isBottom);
        if (_my >= _rowY && _my <= _rowY + _rowH) return i;
        _rowY += _rowH;
    }
    return -1;
}

/// @function DrawDropDownMenuTitle(_x, _y, _text)
/// @description Draws the title row (sDropDownMenuTop) at (_x, _y) --
///        its own top-left corner -- with _text centered.
/// @param {Real} _x
/// @param {Real} _y
/// @param {String} _text
function DrawDropDownMenuTitle(_x, _y, _text) {
    draw_sprite_ext(sDropDownMenuTop, 0, _x, _y, DROPDOWN_MENU_SCALE, DROPDOWN_MENU_SCALE, 0, c_white, 1);

    draw_set_color(HOVER_CARD_TEXT_COLOR);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(_x + (DropDownMenuWidth() / 2), _y + (DropDownMenuTitleHeight() / 2), _text);
}

/// @function DrawDropDownMenuRowBackground(_x, _y, _isBottom, _hovered)
/// @description Draws just the row's sprite (sDropDownMenuMiddle or
///        sDropDowmMenuBottom, per _isBottom) at (_x, _y) -- its own
///        top-left corner -- frame 1 while _hovered, frame 0 otherwise.
///        Does NOT draw any text/icon -- callers draw their own row
///        content starting at DropDownMenuRowContentX(_x), since rows
///        differ per menu (OrderMenu: a label only; CastleGarrisonMenu/
///        SelectionSummaryMenu: an icon + name + right-aligned value).
/// @param {Real} _x
/// @param {Real} _y
/// @param {Bool} _isBottom
/// @param {Bool} _hovered
function DrawDropDownMenuRowBackground(_x, _y, _isBottom, _hovered) {
    var _sprite = _isBottom ? sDropDowmMenuBottom : sDropDownMenuMiddle;
    draw_sprite_ext(_sprite, _hovered ? 1 : 0, _x, _y, DROPDOWN_MENU_SCALE, DROPDOWN_MENU_SCALE, 0, c_white, 1);
}

/// @function PositionDropDownMenuFromClick(_mx, _my, _rowCount)
/// @description Computes a drop-down menu's top-left GUI-space position,
///        anchored away from the initiating click -- 2026-07-13 request:
///        match the same "quadrant-anchor-away-from-cursor + screen-edge
///        clamp" logic every hover card already uses (PositionHoverCardPair,
///        HoverCardScripts.gml; also PlotHoverController/
///        BuildingHoverController/CastleBonusHoverController, all built on
///        the same pattern), instead of the previous "flush at the click,
///        clamp only if the far edge overflows" logic OrderMenu/
///        CastleGarrisonMenu used before this pass. Whichever screen HALF
///        the click landed in (horizontally and vertically, independently)
///        decides which side of the click point the menu grows into -- so
///        it always grows back toward screen-center, away from whichever
///        edge is nearest, same reasoning the hover cards use -- offset by
///        PLOT_HOVER_CURSOR_GAP px of daylight between the cursor and the
///        menu's nearest edge (PlotHoverScripts.gml -- reused directly, not
///        redeclared, same precedent HOVER_CARD_PAIR_GAP already set for
///        this exact value/reasoning).
///
///        Deliberately NOT used by ArmyLimitMenu (opens from a fixed HUD
///        icon, not a click -- no click position exists to anchor from) or
///        SelectionSummaryMenu (a fixed top-left panel, never opened from a
///        click at all) -- both explicitly excluded from the 2026-07-13
///        request this function was added for.
/// @param {Real} _mx GUI-space X of the triggering click.
/// @param {Real} _my GUI-space Y of the triggering click.
/// @param {Real} _rowCount Row count the menu is about to open with --
///        needed up front to know its total on-screen height/width for the
///        anchor-flip and edge-clamp math below.
/// @returns {Struct} { x, y } -- the menu's top-left corner, GUI-space.
function PositionDropDownMenuFromClick(_mx, _my, _rowCount) {
    var _w = DropDownMenuWidth();
    var _h = DropDownMenuTotalHeight(_rowCount);

    var _anchorLeft = (_mx < display_get_gui_width()  / 2);
    var _anchorTop  = (_my < display_get_gui_height() / 2);

    var _x = _anchorLeft ? (_mx + PLOT_HOVER_CURSOR_GAP) : (_mx - PLOT_HOVER_CURSOR_GAP - _w);
    var _y = _anchorTop  ? (_my + PLOT_HOVER_CURSOR_GAP) : (_my - PLOT_HOVER_CURSOR_GAP - _h);

    _x = clamp(_x, 0, display_get_gui_width()  - _w);
    _y = clamp(_y, 0, display_get_gui_height() - _h);

    return { x: _x, y: _y };
}

/// @function PositionDropDownMenuCentered(_rowCount)
/// @description Computes a drop-down menu's top-left GUI-space position,
///        centered on screen both horizontally and vertically -- 2026-07-13
///        request (PauseMenu, PauseMenuScripts.gml), for a menu that isn't
///        triggered by a click at all (a keyboard shortcut) so there's no
///        cursor position to anchor away from, unlike
///        PositionDropDownMenuFromClick above.
/// @param {Real} _rowCount Row count the menu is about to open with.
/// @returns {Struct} { x, y } -- the menu's top-left corner, GUI-space.
function PositionDropDownMenuCentered(_rowCount) {
    var _w = DropDownMenuWidth();
    var _h = DropDownMenuTotalHeight(_rowCount);
    return {
        x: (display_get_gui_width()  - _w) / 2,
        y: (display_get_gui_height() - _h) / 2
    };
}

/// @function DropDownMenuRowContentX(_x)
/// @description The left-aligned start X for a row's own content (icon or
///        text, whichever comes first) -- _x plus the scaled text/icon
///        buffer. See file header for the native-vs-scaled interpretation.
/// @param {Real} _x Row's top-left X (same _x passed to
///        DrawDropDownMenuRowBackground).
/// @returns {Real}
function DropDownMenuRowContentX(_x) {
    return _x + (DROPDOWN_MENU_TEXT_PAD_X * DROPDOWN_MENU_SCALE);
}
