// Dropdown listing units stationed in the player's castle. See CastleGarrisonMenu.md.

#macro CASTLE_MENU_ICON_GAP     6
#macro CASTLE_MENU_COUNT_MARGIN 8

/// @function CastleGarrisonRow(_unitType, _icon, _name, _count)
/// @description One display row. Pass _unitType/_icon/_count all undefined
///        for the "nothing garrisoned" placeholder row (name "--").
/// @param {Asset.GMObject|Undefined} _unitType
/// @param {Asset.GMSprite|Undefined} _icon
/// @param {String} _name
/// @param {Real|Undefined} _count
function CastleGarrisonRow(_unitType, _icon, _name, _count) constructor {
    unitType = _unitType;
    icon     = _icon;
    name     = _name;
    count    = _count;
}

/// @function BuildCastleGarrisonRows(_team)
/// @description Aggregates every live oUnitStationed on _team into one row per distinct unit type.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Array<Struct.CastleGarrisonRow>}
function BuildCastleGarrisonRows(_team) {
    var _counts = ds_map_create(); // Asset.GMObject (unitType) -> Real count
    var _typeOrder = [];

    with (oUnitStationed) {
        if (team != _team) continue;

        var _type = unitData.unitType;
        if (!ds_map_exists(_counts, _type)) {
            ds_map_add(_counts, _type, 0);
            array_push(_typeOrder, _type);
        }
        _counts[? _type] += 1;
    }

    var _rows = [];
    for (var i = 0; i < array_length(_typeOrder); i++) {
        var _type = _typeOrder[i];
        var _def  = GetUnitDefinition(_type);
        array_push(_rows, new CastleGarrisonRow(_type, _def.icon, _def.name, _counts[? _type]));
    }

    ds_map_destroy(_counts);

    if (array_length(_rows) == 0) {
        array_push(_rows, new CastleGarrisonRow(undefined, undefined, "--", undefined));
    }

    return _rows;
}

/// @function CastleGarrisonMenu()
/// @description Call Open() with a set of rows, Update() once per Step, Draw() once per Draw GUI.
function CastleGarrisonMenu() constructor {
    isOpen        = false;
    x             = 0;
    y             = 0;
    rows          = []; // Array<Struct.CastleGarrisonRow>
    hoveredIndex  = -1;
    consumedClick = false; // true for exactly the Step a left click was handled while open -- see .md

    /// @function Open(_x, _y, _rows)
    /// @description Opens the menu, anchored away from the triggering click.
    /// @param {Real} _x GUI-space X of the triggering click.
    /// @param {Real} _y GUI-space Y of the triggering click.
    /// @param {Array<Struct.CastleGarrisonRow>} _rows
    /// @returns {Struct.CastleGarrisonMenu} self
    static Open = function(_x, _y, _rows) {
        rows   = _rows;
        isOpen = true;

        var _pos = PositionDropDownMenuFromClick(_x, _y, array_length(rows));
        x = _pos.x;
        y = _pos.y;

        return self;
    }

    /// @function Close()
    /// @returns {Struct.CastleGarrisonMenu} self
    static Close = function() {
        isOpen       = false;
        rows         = [];
        hoveredIndex = -1;
        return self;
    }

    /// @function Update()
    /// @description Call once per Step while the menu might be open.
    /// @returns {Asset.GMObject|Undefined} unitType of the row clicked this
    ///        frame, or undefined if nothing was clicked.
    static Update = function() {
        consumedClick = false;
        if (!isOpen) return undefined;

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        hoveredIndex = DropDownMenuHitTest(x, y, array_length(rows), _mx, _my);

        if (mouse_check_button_pressed(mb_left)) {
            consumedClick = true;
            var _clickedType = (hoveredIndex >= 0) ? rows[hoveredIndex].unitType : undefined;
            Close();
            return _clickedType;
        }

        if (mouse_check_button_pressed(mb_right)) {
            Close();
        }

        return undefined;
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event while the menu might be open.
    static Draw = function() {
        if (!isOpen) return;

        DrawDropDownMenuTitle(x, y, "Castle");

        var _rowY = y + DropDownMenuTitleHeight();
        for (var i = 0; i < array_length(rows); i++) {
            var _row      = rows[i];
            var _isBottom = (i == array_length(rows) - 1);
            var _rowH     = DropDownMenuRowHeight(_isBottom);
            var _rowMidY  = _rowY + (_rowH / 2);

            DrawDropDownMenuRowBackground(x, _rowY, _isBottom, (i == hoveredIndex));

            draw_set_color(HOVER_CARD_TEXT_COLOR);
            draw_set_halign(fa_left);
            draw_set_valign(fa_middle);

            var _textX = DropDownMenuRowContentX(x);
            if (_row.icon != undefined) {
                var _iconX = _textX + (sprite_get_width(_row.icon) / 2);
                draw_sprite(_row.icon, 0, _iconX, _rowMidY);
                _textX += sprite_get_width(_row.icon) + CASTLE_MENU_ICON_GAP;
            }
            draw_text(_textX, _rowMidY, _row.name);

            if (_row.count != undefined) {
                draw_set_halign(fa_right);
                draw_text(x + DropDownMenuWidth() - CASTLE_MENU_COUNT_MARGIN, _rowMidY, $"x{_row.count}");
            }

            _rowY += _rowH;
        }
    }
}
