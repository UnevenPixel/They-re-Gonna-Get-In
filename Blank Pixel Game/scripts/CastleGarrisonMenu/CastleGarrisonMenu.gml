#macro CASTLE_MENU_ICON_GAP     6  // gap between a row's unit icon and its name text
#macro CASTLE_MENU_COUNT_MARGIN 8  // right-edge margin for the "x#" count text

/// @function CastleGarrisonRow(_unitType, _icon, _name, _count)
/// @description One display row for CastleGarrisonMenu. Pass _unitType,
///        _icon, and _count all undefined for the "nothing garrisoned"
///        placeholder row (name "--") -- see BuildCastleGarrisonRows.
///        _unitType is what CastleGarrisonMenu.Update() reports back when
///        this row is clicked (see DeployStationedUnit, StationScripts.gml)
///        -- undefined on the placeholder row makes clicking it a safe
///        no-op there.
/// @param {Asset.GMObject|Undefined} _unitType e.g. oPeasantUnit.
/// @param {Asset.GMSprite|Undefined} _icon UnitDefinition.icon (small
///        inline sprite, middle-center origin).
/// @param {String} _name UnitDefinition.name, or "--" for the placeholder.
/// @param {Real|Undefined} _count How many of this type are stationed.
function CastleGarrisonRow(_unitType, _icon, _name, _count) constructor {
    unitType = _unitType;
    icon     = _icon;
    name     = _name;
    count    = _count;
}

/// @function BuildCastleGarrisonRows(_team)
/// @description Aggregates every live oUnitStationed belonging to _team into
///        one CastleGarrisonRow per distinct unit type (icon/name from that
///        type's UnitDefinition, count = how many of that type are
///        currently stationed), ordered by first-seen stationing order.
///        Returns a single CastleGarrisonRow(undefined, undefined, "--", undefined)
///        placeholder if _team has nothing stationed -- per the 2026-07-11
///        request: "If there are no units in the castle, display the only
///        option as '--'."
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

// -----------------------------------------------------------
// CastleGarrisonMenu -- a GUI-space dropdown shown when the player left-
// clicks their own castle's wall (not an interior plot -- see
// oUnitControl/Step_0.gml). Lists what's currently stationed there, per
// row: icon, name, "x#" count. Clicking a row deploys ONE unit of that
// type (see DeployStationedUnit, StationScripts.gml, called from
// oUnitControl/Step_0.gml off this menu's Update() return value) --
// 2026-07-12 addition; the "--" placeholder row has no unitType so
// clicking it is a safe no-op. Clicking anywhere else (or right-clicking)
// just dismisses, same as before. Title "Castle", per the 2026-07-12
// request. Structurally mirrors OrderMenu.gml (Open/Close/Update/Draw,
// screen-edge containment on Open) and, as of 2026-07-12, shares its
// sprite/title/hit-test rendering with every other drop-down menu
// (DropDownMenuScripts.gml) -- this file only owns its OWN row content
// (icon + name + right-aligned count), since that's genuinely different
// from OrderMenu's plain-label rows.
// -----------------------------------------------------------

/// @function CastleGarrisonMenu()
/// @description Call Open() to show it with a set of CastleGarrisonRow
///        structs, Update() once per Step to handle hover/click/dismiss,
///        and Draw() once per Draw GUI to render it.
function CastleGarrisonMenu() constructor {
    isOpen        = false;
    x             = 0;
    y             = 0;
    rows          = []; // Array<Struct.CastleGarrisonRow>
    hoveredIndex  = -1;
    consumedClick = false; // true for exactly the Step a left click was handled while open (row or dismiss) -- see oUnitControl/Step_0.gml, which skips its own room-space left-click handling when this is true so the same click can't ALSO start a drag-select/etc. this same frame. 2026-07-12 fix -- SelectionSummaryMenu.gml needed the identical guard, and this menu had the same unpatched gap.

    /// @function Open(_x, _y, _rows)
    /// Opens the menu at a GUI-space position with the given rows.
    /// @param {Real} _x
    /// @param {Real} _y
    /// @param {Array<Struct.CastleGarrisonRow>} _rows
    /// @returns {Struct.CastleGarrisonMenu} self
    static Open = function(_x, _y, _rows) {
        x      = _x;
        y      = _y;
        rows   = _rows;
        isOpen = true;

        // Keep the menu on-screen if opened near an edge -- same containment
        // math as OrderMenu.Open.
        var _w = DropDownMenuWidth();
        var _h = DropDownMenuTotalHeight(array_length(rows));
        if (x + _w > display_get_gui_width())  x = display_get_gui_width() - _w;
        if (y + _h > display_get_gui_height()) y = display_get_gui_height() - _h;

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
    /// Call once per Step event while the menu might be open. Same hover-
    /// track-then-click pattern as OrderMenu.Update().
    /// @returns {Asset.GMObject|Undefined} The unitType of the row clicked
    ///         this frame (undefined for the "--" placeholder row), or
    ///         undefined if nothing was clicked. Right-click always
    ///         dismisses without returning anything, same as OrderMenu.
    static Update = function() {
        consumedClick = false;
        if (!isOpen) return undefined;

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        hoveredIndex = DropDownMenuHitTest(x, y, array_length(rows), _mx, _my);

        if (mouse_check_button_pressed(mb_left)) {
            consumedClick = true; // ANY left click while open counts -- this menu is modal-ish (explicitly opened by the player), so even a dismiss-elsewhere click shouldn't ALSO act on the world this same frame
            var _clickedType = (hoveredIndex >= 0) ? rows[hoveredIndex].unitType : undefined;
            Close();
            return _clickedType; // undefined for a click outside every row, or on the "--" placeholder row
        }

        if (mouse_check_button_pressed(mb_right)) {
            Close(); // right-click anywhere dismisses without deploying anything
        }

        return undefined;
    }

    /// @function Draw()
    /// Call once per Draw GUI event while the menu might be open.
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
