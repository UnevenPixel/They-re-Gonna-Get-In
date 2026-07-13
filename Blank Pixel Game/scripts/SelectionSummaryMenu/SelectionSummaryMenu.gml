// -----------------------------------------------------------
// SelectionSummaryMenu -- top-left panel shown whenever 2+ units are
// selected (2026-07-12 request). Title "Selected". Background/title/hover-
// frame rendering shares DropDownMenuScripts.gml with every other drop-
// down menu (OrderMenu/CastleGarrisonMenu) -- this file only owns its own
// row CONTENT (icon + name + right-aligned value), same split
// CastleGarrisonMenu uses, plus CASTLE_MENU_ICON_GAP/CASTLE_MENU_COUNT_MARGIN
// reused directly from that file rather than redeclaring near-duplicates.
// Unlike OrderMenu/CastleGarrisonMenu, there's no Open()/Close() -- this is
// a passive, always-recomputed-from-selection panel (same "instant show/
// hide tied to selectionController.selected" architecture as
// UnitSelectHoverController, UnitHoverScripts.gml, which owns the exact
// same top-left corner for the single-unit case; the two are mutually
// exclusive since this only engages at 2+ selected).
//
// Two modes, purely derived from the current selection each Step (no
// explicit mode field/state machine):
//   - GROUPED: selection spans 2+ distinct unit types -- one row per type
//     (icon, name, "x#" count of how many of that type are selected).
//     Hovering a row shows the GENERAL unit hover card (ShowUnitHoverCard
//     with _liveUnit = noone -- max HP only, no specific instance, same
//     "no live instance" treatment UnitHoverExtras already uses for the
//     blueprint-UI/placed-training-building contexts). Clicking a row
//     narrows selectionController.selected down to just the CURRENTLY
//     SELECTED units of that type (not every unit of that type on the
//     map) -- the row's own count is exactly that subset, so narrowing to
//     it keeps the panel's next-frame row count consistent with what was
//     just shown.
//   - INDIVIDUAL: selection is 2+ units that all share ONE type -- one row
//     per actual unit instance (icon/name repeat per row; the distinguishing
//     value is current/max HP instead of a count -- "x#" doesn't mean
//     anything per-unit). Hovering a row shows the DETAILED unit hover card
//     (ShowUnitHoverCard with the real instance -- exact remaining HP,
//     identical treatment to UnitSelectHoverController's single-selected
//     card). Clicking a row replaces selectionController.selected with
//     JUST that one unit.
//
// A row click is recorded in `consumedClick` (mirrors CastleGarrisonMenu's
// same-named field, added alongside this) so oUnitControl/Step_0.gml can
// skip its room-space left-click handling for that press -- without this,
// clicking a row would ALSO be read as a world click by the selection-drag/
// castle/training/blueprint logic later in the same Step, immediately
// clobbering the selection this panel just set. Scoped narrower than
// CastleGarrisonMenu's version: only a click that actually LANDS ON A ROW
// counts as consumed here, since this panel isn't modal -- a click
// anywhere else on screen (e.g. picking a different unit, starting a new
// drag) must keep working normally even while this panel happens to be
// visible.
// -----------------------------------------------------------

#macro SELECTION_SUMMARY_HOVER_GAP_X 8 // already-scaled on-screen px between the panel's right edge and the paired hover data card

/// @function SelectionSummaryRow(_unitType, _icon, _name, _valueText, _unit)
/// @description One display row for SelectionSummaryMenu. _unit is noone
///        for a GROUPED (by-type) row, or a real unit instance for an
///        INDIVIDUAL row -- this is what tells Step() which click behavior
///        (narrow-by-type vs. select-just-this-one) and which hover card
///        (general vs. detailed) a given row wants.
/// @param {Asset.GMObject} _unitType
/// @param {Asset.GMSprite|Undefined} _icon UnitDefinition.icon.
/// @param {String} _name UnitDefinition.name.
/// @param {String} _valueText Right-aligned column text -- "x#" for a
///        grouped row, "{hp}/{maxHp}" for an individual row.
/// @param {Id.Instance|Constant.NoOne} _unit
function SelectionSummaryRow(_unitType, _icon, _name, _valueText, _unit) constructor {
    unitType  = _unitType;
    icon      = _icon;
    name      = _name;
    valueText = _valueText;
    unit      = _unit;
}

/// @function BuildSelectionSummaryRows(_selected)
/// @description Builds this frame's rows from the current selection --
///        GROUPED (one row per distinct type) if 2+ types are present,
///        INDIVIDUAL (one row per unit) if every selected unit shares one
///        type. Caller (Step, below) only calls this once array_length(
///        _selected) >= 2 is already confirmed.
/// @param {Array<Id.Instance>} _selected
/// @returns {Array<Struct.SelectionSummaryRow>}
function BuildSelectionSummaryRows(_selected) {
    var _counts    = ds_map_create(); // Asset.GMObject (unitType) -> Real count
    var _typeOrder = [];

    for (var i = 0; i < array_length(_selected); i++) {
        var _type = _selected[i].object_index;
        if (!ds_map_exists(_counts, _type)) {
            ds_map_add(_counts, _type, 0);
            array_push(_typeOrder, _type);
        }
        _counts[? _type] += 1;
    }

    var _rows = [];

    if (array_length(_typeOrder) > 1) {
        // GROUPED -- one row per distinct type.
        for (var i = 0; i < array_length(_typeOrder); i++) {
            var _type = _typeOrder[i];
            var _def  = GetUnitDefinition(_type);
            if (_def == undefined) continue;
            array_push(_rows, new SelectionSummaryRow(_type, _def.icon, _def.name, $"x{_counts[? _type]}", noone));
        }
    } else {
        // INDIVIDUAL -- every selected unit shares this one type.
        var _type = _typeOrder[0];
        var _def  = GetUnitDefinition(_type);
        if (_def != undefined) {
            for (var i = 0; i < array_length(_selected); i++) {
                var _unit   = _selected[i];
                var _hpText = $"{GetCurrentHealth(_unit)}/{_def.maxHealth}";
                array_push(_rows, new SelectionSummaryRow(_type, _def.icon, _def.name, _hpText, _unit));
            }
        }
    }

    ds_map_destroy(_counts);
    return _rows;
}

/// @function SelectionSummaryMenu()
/// @description Owns its rows, its own hover card (HoverCard + UnitHoverExtras,
///        same pair every other unit hover context uses), and handles its
///        own hover/click -- call Step(_selectionController) once per Step
///        (after PruneDeadSelected), Draw() once per Draw GUI.
function SelectionSummaryMenu() constructor {
    visible       = false;
    rows          = []; // Array<Struct.SelectionSummaryRow>
    hoveredIndex  = -1;
    consumedClick = false;

    x = UNIT_SELECT_HOVER_MARGIN_X; // same top-left anchor UnitSelectHoverController uses (UnitHoverScripts.gml) -- mutually exclusive with it (that shows at exactly 1 selected, this at 2+)
    y = UNIT_SELECT_HOVER_MARGIN_Y;

    hoverCard    = new HoverCard();
    hoverExtras  = new UnitHoverExtras();
    hoverVisible = false;

    /// @function Step(_selectionController)
    /// @description Call once per Step event, after
    ///        _selectionController.PruneDeadSelected(). Hidden (and
    ///        everything below skipped) unless 2+ units are selected.
    /// @param {Struct.SelectionController} _selectionController
    static Step = function(_selectionController) {
        consumedClick = false;
        visible       = false;
        hoverVisible  = false;
        hoveredIndex  = -1;

        var _selected = _selectionController.selected;
        if (array_length(_selected) <= 1) return;

        rows    = BuildSelectionSummaryRows(_selected);
        visible = (array_length(rows) > 0);
        if (!visible) return;

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        hoveredIndex = DropDownMenuHitTest(x, y, array_length(rows), _mx, _my);

        if (hoveredIndex >= 0) {
            var _row = rows[hoveredIndex];
            var _def = GetUnitDefinition(_row.unitType);
            if (_def != undefined) {
                // _row.unit is noone for a grouped row (general card, max HP
                // only) or a real instance for an individual row (detailed
                // card, exact HP) -- ShowUnitHoverCard already branches on
                // exactly that (UnitHoverScripts.gml).
                ShowUnitHoverCard(hoverCard, hoverExtras, _def, _row.unit, false);
                hoverCard.x  = x + DropDownMenuWidth() + SELECTION_SUMMARY_HOVER_GAP_X;
                hoverCard.y  = y;
                hoverVisible = true;
            }
        }

        if (mouse_check_button_pressed(mb_left) && hoveredIndex >= 0) {
            consumedClick = true;
            var _row = rows[hoveredIndex];

            if (_row.unit != noone) {
                // Individual row -- select just this one unit.
                _selectionController.selected = [_row.unit];
            } else {
                // Grouped row -- narrow the CURRENT selection down to units
                // of this type only (not every unit of this type on the map).
                var _filtered = [];
                for (var i = 0; i < array_length(_selected); i++) {
                    if (_selected[i].object_index == _row.unitType) array_push(_filtered, _selected[i]);
                }
                _selectionController.selected = _filtered;
            }

            // The selection this panel was drawn from is now stale -- hide
            // for the rest of THIS frame's Draw call rather than flashing
            // outdated rows; Step() recomputes correctly from next frame on.
            visible      = false;
            hoverVisible = false;
        }
    }

    /// @function Draw()
    /// Call once per Draw GUI event.
    static Draw = function() {
        if (!visible) return;

        DrawDropDownMenuTitle(x, y, "Selected");

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

            draw_set_halign(fa_right);
            draw_text(x + DropDownMenuWidth() - CASTLE_MENU_COUNT_MARGIN, _rowMidY, _row.valueText);

            _rowY += _rowH;
        }

        if (hoverVisible) {
            hoverCard.Draw(1);
            hoverExtras.Draw(hoverCard, 1);
        }
    }
}
