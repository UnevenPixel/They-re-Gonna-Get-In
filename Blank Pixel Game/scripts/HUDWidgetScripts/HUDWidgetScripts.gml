// Fixed-position HUD readouts alongside the resource bar: Castle Health
// Widget and Army Limit Widget. See HUDWidgetScripts.md.

#macro CASTLE_HEALTH_WIDGET_X        452 // icon's left edge anchors here
#macro CASTLE_HEALTH_WIDGET_Y        856 // shared vertical anchor for icon + text
#macro CASTLE_HEALTH_WIDGET_TEXT_GAP 10  // px from icon's right edge to text

/// @function DrawCastleHealthWidget(_team)
/// @description Call once per Draw GUI event. No-ops if _team has no castle instance.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
function DrawCastleHealthWidget(_team) {
    var _castle = GetTeamCastle(_team);
    if (!instance_exists(_castle)) return;

    var _iconX = CASTLE_HEALTH_WIDGET_X + sprite_get_xoffset(sCastleHealthIcon);
    draw_sprite(sCastleHealthIcon, 0, _iconX, CASTLE_HEALTH_WIDGET_Y);

    var _textX = CASTLE_HEALTH_WIDGET_X + sprite_get_width(sCastleHealthIcon) + CASTLE_HEALTH_WIDGET_TEXT_GAP;

    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_font(fntResource);

    var _current = GetCurrentHealth(_castle);
    var _max     = _castle.maxHealth;
    var _text    = string(_current) + "/" + string(_max);

    draw_set_color(HOVER_CARD_SHADOW_COLOR);
    draw_text(_textX, CASTLE_HEALTH_WIDGET_Y + HOVER_CARD_SHADOW_OFFSET, _text);

    draw_set_color(HOVER_CARD_TEXT_COLOR);
    draw_text(_textX, CASTLE_HEALTH_WIDGET_Y, _text);

    draw_set_font(-1);
}

#macro ARMY_LIMIT_WIDGET_X     452 // same X anchor as CASTLE_HEALTH_WIDGET_X
#macro ARMY_LIMIT_WIDGET_GAP_Y 10  // px from Castle Health icon's bottom edge to this icon's top edge

/// @function ArmyLimitWidgetY()
/// @description Shared vertical anchor for the Army Limit Widget's icon and text.
/// @returns {Real}
function ArmyLimitWidgetY() {
    var _healthBottomEdge = CASTLE_HEALTH_WIDGET_Y + (sprite_get_height(sCastleHealthIcon) - sprite_get_yoffset(sCastleHealthIcon));
    var _limitTopEdge     = _healthBottomEdge + ARMY_LIMIT_WIDGET_GAP_Y;
    return _limitTopEdge + sprite_get_yoffset(sArmyLimitIcon);
}

/// @function ArmyLimitWidgetIconRect()
/// @description GUI-space bounding rect of the Army Limit Widget's icon.
/// @returns {Struct} { x1, y1, x2, y2 }
function ArmyLimitWidgetIconRect() {
    var _y1 = ArmyLimitWidgetY() - sprite_get_yoffset(sArmyLimitIcon);
    var _x1 = ARMY_LIMIT_WIDGET_X;
    return {
        x1: _x1,
        y1: _y1,
        x2: _x1 + sprite_get_width(sArmyLimitIcon),
        y2: _y1 + sprite_get_height(sArmyLimitIcon)
    };
}

/// @function DrawArmyLimitWidget(_team)
/// @description Call once per Draw GUI event.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
function DrawArmyLimitWidget(_team) {
    var _y = ArmyLimitWidgetY();

    var _iconX = ARMY_LIMIT_WIDGET_X + sprite_get_xoffset(sArmyLimitIcon);
    draw_sprite(sArmyLimitIcon, 0, _iconX, _y);

    var _textX = ARMY_LIMIT_WIDGET_X + sprite_get_width(sArmyLimitIcon) + CASTLE_HEALTH_WIDGET_TEXT_GAP;

    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_font(fntResource);

    var _current = array_length(GatherTeamUnits(_team)) + CountTeamStationedUnits(_team);
    var _max     = global.armyLimit[_team];
    var _text    = string(_current) + "/" + string(_max);

    draw_set_color(HOVER_CARD_SHADOW_COLOR);
    draw_text(_textX, _y + HOVER_CARD_SHADOW_OFFSET, _text);

    draw_set_color(HOVER_CARD_TEXT_COLOR);
    draw_text(_textX, _y, _text);

    draw_set_font(-1);
}

#macro SPEED_BUTTON_NATIVE_X     816 // native (960x540 view-space) position of the first button's sprite origin
#macro SPEED_BUTTON_NATIVE_Y     501
#macro SPEED_BUTTON_NATIVE_STEP  23  // origin-to-origin spacing
#macro SPEED_BUTTON_UI_SCALE     2   // native -> GUI, matches the UI bar's draw scale

/// @function SpeedButtonSprite(_index)
/// @description Sprite for speed button _index: 0 = pause, 1-3 = game speeds 1x-3x.
/// @param {Real} _index 0..3
/// @returns {Asset.GMSprite}
function SpeedButtonSprite(_index) {
    return [sSpeedButtonPause, sSpeedButton1, sSpeedButton2, sSpeedButton3][_index];
}

/// @function SpeedButtonCenter(_index)
/// @description GUI-space center of speed button _index. Offsets by the sprite's own origin so every button lands centered on its slot regardless of origin.
/// @param {Real} _index 0..3
/// @returns {Struct.Vector2}
function SpeedButtonCenter(_index) {
    var _sprite = SpeedButtonSprite(_index);
    var _ox = (SPEED_BUTTON_NATIVE_X + _index * SPEED_BUTTON_NATIVE_STEP + (sprite_get_width(_sprite) / 2 - sprite_get_xoffset(_sprite))) * SPEED_BUTTON_UI_SCALE;
    var _oy = (SPEED_BUTTON_NATIVE_Y + (sprite_get_height(_sprite) / 2 - sprite_get_yoffset(_sprite))) * SPEED_BUTTON_UI_SCALE;
    return new Vector2(_ox, _oy);
}

/// @function SpeedButtonAtMouse()
/// @description Index of the speed button under the mouse (GUI space), or -1.
/// @returns {Real}
function SpeedButtonAtMouse() {
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    for (var i = 0; i < 4; i++) {
        var _c = SpeedButtonCenter(i);
        var _halfW = sprite_get_width(SpeedButtonSprite(i)) * SPEED_BUTTON_UI_SCALE / 2;
        var _halfH = sprite_get_height(SpeedButtonSprite(i)) * SPEED_BUTTON_UI_SCALE / 2;
        if (_mx >= _c.x - _halfW && _mx <= _c.x + _halfW && _my >= _c.y - _halfH && _my <= _c.y + _halfH) return i;
    }
    return -1;
}

/// @function DrawSpeedButtons()
/// @description Call once per Draw GUI event. Frame 1 on the button matching global.matchSpeed, frame 0 on the rest.
function DrawSpeedButtons() {
    for (var i = 0; i < 4; i++) {
        var _c = SpeedButtonCenter(i);
        var _sprite = SpeedButtonSprite(i);
        // draw so the sprite's CENTER lands on _c (origin offset compensated)
        var _dx = _c.x + (sprite_get_xoffset(_sprite) - sprite_get_width(_sprite) / 2) * SPEED_BUTTON_UI_SCALE;
        var _dy = _c.y + (sprite_get_yoffset(_sprite) - sprite_get_height(_sprite) / 2) * SPEED_BUTTON_UI_SCALE;
        draw_sprite_ext(_sprite, (global.matchSpeed == i) ? 1 : 0, _dx, _dy, SPEED_BUTTON_UI_SCALE, SPEED_BUTTON_UI_SCALE, 0, c_white, 1);
    }
}
