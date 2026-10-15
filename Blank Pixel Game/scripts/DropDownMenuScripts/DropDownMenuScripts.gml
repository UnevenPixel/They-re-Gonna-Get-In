// Shared sprite-based rendering/layout for every drop-down/panel menu
// (OrderMenu, CastleGarrisonMenu, SelectionSummaryMenu). See DropDownMenuScripts.md.

#macro DROPDOWN_MENU_SCALE      2
#macro DROPDOWN_MENU_TEXT_PAD_X 6 // native px

/// @function DropDownMenuWidth()
/// @description On-screen width shared by all three drop-down sprites.
/// @returns {Real}
function DropDownMenuWidth() {
    return sprite_get_width(sDropDownMenuTop) * DROPDOWN_MENU_SCALE;
}

/// @function DropDownMenuTitleHeight()
/// @returns {Real} On-screen height of the title row.
function DropDownMenuTitleHeight() {
    return sprite_get_height(sDropDownMenuTop) * DROPDOWN_MENU_SCALE;
}

/// @function DropDownMenuRowHeight(_isBottom)
/// @description On-screen height of one option row.
/// @param {Bool} _isBottom
/// @returns {Real}
function DropDownMenuRowHeight(_isBottom) {
    return sprite_get_height(_isBottom ? sDropDowmMenuBottom : sDropDownMenuMiddle) * DROPDOWN_MENU_SCALE;
}

/// @function DropDownMenuTotalHeight(_rowCount)
/// @description Total on-screen height of a full menu (title + every row).
/// @param {Real} _rowCount
/// @returns {Real}
function DropDownMenuTotalHeight(_rowCount) {
    var _h = DropDownMenuTitleHeight();
    if (_rowCount <= 0) return _h;

    _h += DropDownMenuRowHeight(false) * (_rowCount - 1);
    _h += DropDownMenuRowHeight(true);
    return _h;
}

/// @function DropDownMenuHitTest(_x, _y, _rowCount, _mx, _my)
/// @description Row index (0-based, option rows only) the point falls inside, or -1.
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
/// @description Draws the title row at (_x, _y) with _text centered.
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
/// @description Draws just the row's sprite -- callers draw their own row
///        content starting at DropDownMenuRowContentX(_x).
/// @param {Real} _x
/// @param {Real} _y
/// @param {Bool} _isBottom
/// @param {Bool} _hovered
function DrawDropDownMenuRowBackground(_x, _y, _isBottom, _hovered) {
    var _sprite = _isBottom ? sDropDowmMenuBottom : sDropDownMenuMiddle;
    draw_sprite_ext(_sprite, _hovered ? 1 : 0, _x, _y, DROPDOWN_MENU_SCALE, DROPDOWN_MENU_SCALE, 0, c_white, 1);
}

/// @function PositionDropDownMenuFromClick(_mx, _my, _rowCount)
/// @description Menu top-left position, anchored away from the triggering click.
/// @param {Real} _mx GUI-space X of the triggering click.
/// @param {Real} _my GUI-space Y of the triggering click.
/// @param {Real} _rowCount Row count the menu is about to open with.
/// @returns {Struct} { x, y }
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
/// @description Menu top-left position, centered on screen.
/// @param {Real} _rowCount Row count the menu is about to open with.
/// @returns {Struct} { x, y }
function PositionDropDownMenuCentered(_rowCount) {
    var _w = DropDownMenuWidth();
    var _h = DropDownMenuTotalHeight(_rowCount);
    return {
        x: (display_get_gui_width()  - _w) / 2,
        y: (display_get_gui_height() - _h) / 2
    };
}

/// @function DropDownMenuRowContentX(_x)
/// @description Left-aligned start X for a row's own content.
/// @param {Real} _x Row's top-left X.
/// @returns {Real}
function DropDownMenuRowContentX(_x) {
    return _x + (DROPDOWN_MENU_TEXT_PAD_X * DROPDOWN_MENU_SCALE);
}
