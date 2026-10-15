// Custom game-wide cursor: replaces the system cursor, picks a sprite by context. See CursorScripts.md.

#macro CURSOR_SCALE (global.gameSettings.cursorScale) // GUI-space draw scale, player setting (1-3, default 2) -- read live, see SettingsOverlayScripts.gml
#macro CURSOR_SELECT_MIN_DRAG 4 // world px the mouse must travel during a drag-select before the select cursor shows

/// @function CursorInit()
/// @description Hides the system cursor so the custom one can replace it. Call once at game start.
function CursorInit() {
    window_set_cursor(cr_none);
}

/// @function CursorHiddenInRoom(_room)
/// @description True for the studio splash and alpha warning screens (plus the init room), where no cursor is shown.
/// @param {Asset.GMRoom} _room
/// @returns {Bool}
function CursorHiddenInRoom(_room) {
    return _room == rmInit || _room == rmOpeningCredits || _room == rmDisclaimer;
}

/// @function GetCursorSprite()
/// @description Picks the cursor sprite for the current state. Priority: carry (dragging a blueprint or Fate Token) > flag (choosing an order target) > select (drag-selecting) > base.
/// @returns {Asset.GMSprite}
function GetCursorSprite() {
    if (instance_exists(oUnitControl)) {
        var _carry = false;
        var _flag  = false;
        var _box   = false;
        with (oUnitControl) {
            _carry = blueprintController.dragging || xpBarWidget.dragging; // blueprint drag or Fate Token drag
            _flag  = selectionController.isTargeting;
            if (selectionController.dragging) {
                var _sx = selectionController.dragStartX;
                var _sy = selectionController.dragStartY;
                // dragStart is world space; compare in world space so camera moves count too
                _box = (abs(mouse_x - _sx) >= CURSOR_SELECT_MIN_DRAG || abs(mouse_y - _sy) >= CURSOR_SELECT_MIN_DRAG);
            }
        }
        if (_carry) return sCursorCarry;
        if (_flag)  return sCursorFlag;
        if (_box)   return sCursorSelect;
    }
    return sCursorBase;
}

/// @function CursorDraw()
/// @description Draws the custom cursor at the mouse in GUI space. Call from a Draw GUI End event so it sits above everything.
function CursorDraw() {
    if (CursorHiddenInRoom(room)) return;
    draw_sprite_ext(GetCursorSprite(), 0, device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), CURSOR_SCALE, CURSOR_SCALE, 0, c_white, 1);
}
