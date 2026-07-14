#macro ARMY_LIMIT_MENU_ANCHOR_X        408 // left corner -- 2026-07-13 request
#macro ARMY_LIMIT_MENU_ANCHOR_BOTTOM_Y 812 // menu's BOTTOM edge lands here -- 2026-07-13 request. Same value as SELECTION_DRAG_MIN_GUI_Y (UnitSelection.gml) -- both mark the same "top of the bottom HUD panel" boundary, not a coincidence; the menu's bottom edge sits flush with the top of that panel.

/// @function ArmyLimitRow(_unitType, _icon, _name, _count, _limit)
/// @description One display row for ArmyLimitMenu. Pass all four of
///        _unitType/_icon/_count/_limit undefined for the "nothing to
///        show" placeholder row (name "--") -- see BuildArmyLimitRows.
///        _unitType is what ArmyLimitMenu.Update() reports back when this
///        row is clicked (see SelectionController.SelectAllOfType,
///        UnitSelection.gml) -- undefined on the placeholder row makes
///        clicking it a safe no-op there.
/// @param {Asset.GMObject|Undefined} _unitType e.g. oPeasantUnit.
/// @param {Asset.GMSprite|Undefined} _icon UnitDefinition.icon (small
///        inline sprite, middle-center origin) -- same field
///        CastleGarrisonRow uses (CastleGarrisonMenu.gml).
/// @param {String} _name UnitDefinition.name, or "--" for the placeholder.
/// @param {Real|Undefined} _count Live + stationed units of this type.
/// @param {Real|Undefined} _limit TrainingTypeLimit for this type.
function ArmyLimitRow(_unitType, _icon, _name, _count, _limit) constructor {
    unitType = _unitType;
    icon     = _icon;
    name     = _name;
    count    = _count;
    limit    = _limit;
}

/// @function BuildArmyLimitRows(_team)
/// @description Aggregates every live oUnitParent AND oUnitStationed
///        belonging to _team into one ArmyLimitRow per distinct unit
///        type -- count is LIVE + STATIONED combined (matching this
///        session's established "both count against limits" correction,
///        TrainingScripts.gml/StationScripts.gml), limit is
///        TrainingTypeLimit(_team, _type) (TrainingScripts.gml). Ordered
///        by first-seen (live units scanned first, then stationed) --
///        same "first-seen ds_map + parallel array" idiom
///        BuildCastleGarrisonRows (CastleGarrisonMenu.gml) uses, just with
///        two source with-loops merged into the one map instead of one.
///        Returns a single
///        ArmyLimitRow(undefined, undefined, "--", undefined, undefined)
///        placeholder if _team has no units of any kind, live or
///        stationed -- same empty-state precedent as
///        BuildCastleGarrisonRows.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Array<Struct.ArmyLimitRow>}
function BuildArmyLimitRows(_team) {
    var _counts    = ds_map_create(); // Asset.GMObject (unitType) -> Real count
    var _typeOrder = [];

    with (oUnitParent) {
        if (team != _team) continue;

        var _type = object_index;
        if (!ds_map_exists(_counts, _type)) {
            ds_map_add(_counts, _type, 0);
            array_push(_typeOrder, _type);
        }
        _counts[? _type] += 1;
    }

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
        var _type  = _typeOrder[i];
        var _def   = GetUnitDefinition(_type);
        var _limit = TrainingTypeLimit(_team, _type);
        array_push(_rows, new ArmyLimitRow(_type, _def.icon, _def.name, _counts[? _type], _limit));
    }

    ds_map_destroy(_counts);

    if (array_length(_rows) == 0) {
        array_push(_rows, new ArmyLimitRow(undefined, undefined, "--", undefined, undefined));
    }

    return _rows;
}

// -----------------------------------------------------------
// ArmyLimitMenu -- a GUI-space dropdown shown when the player left-clicks
// the Army Limit Widget's icon (HUDWidgetScripts.gml -- a fixed HUD icon
// click, NOT a room-space click like CastleGarrisonMenu's castle-wall
// trigger; see oUnitControl/Step_0.gml). Lists every unit type the player
// currently has (live + stationed), per row: icon, name, "count/limit".
// Clicking a row selects every currently DEPLOYED (live, not stationed)
// unit of that type -- 2026-07-13 request: "select all deployed units of
// that type" -- via SelectionController.SelectAllOfType
// (UnitSelection.gml), then closes, same row-click-then-close shape as
// CastleGarrisonMenu. Title "Unit Limits", per the request. Structurally
// mirrors CastleGarrisonMenu.gml (Open/Close/Update/Draw, shared
// DropDownMenuScripts.gml rendering/hit-test, CASTLE_MENU_ICON_GAP/
// CASTLE_MENU_COUNT_MARGIN reused directly rather than redeclared -- same
// precedent SelectionSummaryMenu.gml already set) with ONE deliberate
// difference: Open() does NOT take a click position -- this menu always
// opens at the SAME fixed anchor (ARMY_LIMIT_MENU_ANCHOR_X,
// ARMY_LIMIT_MENU_ANCHOR_BOTTOM_Y), bottom-edge-aligned and growing
// UPWARD, rather than top-left-from-a-click like every other menu in this
// project -- see Open()'s own doc comment for why.
// -----------------------------------------------------------

/// @function ArmyLimitMenu()
/// @description Call Open() to show it with a set of ArmyLimitRow structs,
///        Update() once per Step to handle hover/click/dismiss, and
///        Draw() once per Draw GUI to render it.
function ArmyLimitMenu() constructor {
    isOpen        = false;
    x             = 0;
    y             = 0;
    rows          = []; // Array<Struct.ArmyLimitRow>
    hoveredIndex  = -1;
    consumedClick = false; // true for exactly the Step a left click was handled while open (row or dismiss) -- same oUnitControl/Step_0.gml passthrough guard every other menu in this project uses.

    /// @function Open(_rows)
    /// @description Opens the menu with the given rows, ALWAYS at the same
    ///        fixed anchor -- unlike CastleGarrisonMenu/OrderMenu, which
    ///        open wherever the triggering click landed, this menu is
    ///        triggered by clicking a FIXED HUD icon (the Army Limit
    ///        Widget), so there's no meaningful "click position" to open
    ///        from -- it always appears in the same place relative to
    ///        that icon. Per the 2026-07-13 request: left edge at
    ///        ARMY_LIMIT_MENU_ANCHOR_X, BOTTOM edge at
    ///        ARMY_LIMIT_MENU_ANCHOR_BOTTOM_Y -- the menu grows UPWARD
    ///        from that Y (title/rows stacked so the LAST row ends up
    ///        highest, first row lowest, right above the anchor), unlike
    ///        every other menu in this project, which grows downward from
    ///        a top-left anchor. That bottom-Y also happens to equal
    ///        SELECTION_DRAG_MIN_GUI_Y (UnitSelection.gml), the
    ///        established boundary between the playfield and the bottom
    ///        HUD panel.
    /// @param {Array<Struct.ArmyLimitRow>} _rows
    /// @returns {Struct.ArmyLimitMenu} self
    static Open = function(_rows) {
        rows   = _rows;
        x      = ARMY_LIMIT_MENU_ANCHOR_X;
        y      = ARMY_LIMIT_MENU_ANCHOR_BOTTOM_Y - DropDownMenuTotalHeight(array_length(rows));
        isOpen = true;

        // Defensive floor clamp only -- unlike CastleGarrisonMenu/OrderMenu
        // (which clamp against an arbitrary click point that could land
        // anywhere near a screen edge), this menu's position is fixed and
        // only grows taller with more distinct unit types (currently
        // capped at 6 registered types total), so overflowing the TOP of
        // the screen is vanishingly unlikely -- kept anyway since it
        // costs nothing.
        if (y < 0) y = 0;

        return self;
    }

    /// @function Close()
    /// @returns {Struct.ArmyLimitMenu} self
    static Close = function() {
        isOpen       = false;
        rows         = [];
        hoveredIndex = -1;
        return self;
    }

    /// @function Update()
    /// Call once per Step event while the menu might be open. Same
    /// hover-track-then-click pattern as CastleGarrisonMenu.Update().
    /// @returns {Asset.GMObject|Undefined} The unitType of the row clicked
    ///         this frame (undefined for the "--" placeholder row), or
    ///         undefined if nothing was clicked. Right-click always
    ///         dismisses without returning anything.
    static Update = function() {
        consumedClick = false;
        if (!isOpen) return undefined;

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        hoveredIndex = DropDownMenuHitTest(x, y, array_length(rows), _mx, _my);

        if (mouse_check_button_pressed(mb_left)) {
            consumedClick = true; // same "any left click while open counts" reasoning as CastleGarrisonMenu -- explicitly opened by the player, so even a dismiss-elsewhere click shouldn't ALSO act on the world this same frame
            var _clickedType = (hoveredIndex >= 0) ? rows[hoveredIndex].unitType : undefined;
            Close();
            return _clickedType; // undefined for a click outside every row, or on the "--" placeholder row
        }

        if (mouse_check_button_pressed(mb_right)) {
            Close(); // right-click anywhere dismisses without selecting anything
        }

        return undefined;
    }

    /// @function Draw()
    /// Call once per Draw GUI event while the menu might be open.
    static Draw = function() {
        if (!isOpen) return;

        DrawDropDownMenuTitle(x, y, "Unit Limits");

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
                draw_text(x + DropDownMenuWidth() - CASTLE_MENU_COUNT_MARGIN, _rowMidY, $"{_row.count}/{_row.limit}");
            }

            _rowY += _rowH;
        }
    }
}
