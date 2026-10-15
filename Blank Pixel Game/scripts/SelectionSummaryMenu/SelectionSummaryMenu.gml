// Top-left panel shown when 2+ units are selected. See SelectionSummaryMenu.md.

#macro SELECTION_SUMMARY_HOVER_GAP_X 8 // on-screen px between the panel's right edge and the paired hover card

/// @function SelectionSummaryRow(_unitType, _icon, _name, _valueText, _unit)
/// @description One display row. _unit is noone for a GROUPED row, a real instance for an INDIVIDUAL row.
/// @param {Asset.GMObject} _unitType
/// @param {Asset.GMSprite|Undefined} _icon
/// @param {String} _name
/// @param {String} _valueText "x#" for grouped, "{hp}/{maxHp}" for individual.
/// @param {Id.Instance|Constant.NoOne} _unit
function SelectionSummaryRow(_unitType, _icon, _name, _valueText, _unit) constructor {
    unitType  = _unitType;
    icon      = _icon;
    name      = _name;
    valueText = _valueText;
    unit      = _unit;
}

/// @function BuildSelectionSummaryRows(_selected)
/// @description Builds this frame's rows -- GROUPED if 2+ types present, INDIVIDUAL if one shared type.
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
        for (var i = 0; i < array_length(_typeOrder); i++) {
            var _type = _typeOrder[i];
            var _def  = GetUnitDefinition(_type);
            if (_def == undefined) continue;
            array_push(_rows, new SelectionSummaryRow(_type, _def.icon, _def.name, $"x{_counts[? _type]}", noone));
        }
    } else {
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
/// @description Owns its rows and its own hover card. Call Step(_selectionController) once per Step, Draw() once per Draw GUI.
function SelectionSummaryMenu() constructor {
    visible       = false;
    rows          = []; // Array<Struct.SelectionSummaryRow>
    hoveredIndex  = -1;
    consumedClick = false;

    x = UNIT_SELECT_HOVER_MARGIN_X; // same anchor as UnitSelectHoverController -- mutually exclusive with it
    y = UNIT_SELECT_HOVER_MARGIN_Y;

    hoverCard    = new HoverCard();
    hoverExtras  = new UnitHoverExtras();
    hoverVisible = false;

    /// @function Step(_selectionController)
    /// @description Call once per Step, after _selectionController.PruneDeadSelected().
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
                _selectionController.selected = [_row.unit];
            } else {
                var _filtered = [];
                for (var i = 0; i < array_length(_selected); i++) {
                    if (_selected[i].object_index == _row.unitType) array_push(_filtered, _selected[i]);
                }
                _selectionController.selected = _filtered;
            }

            visible      = false; // this frame's rows are now stale -- Step() recomputes next frame
            hoverVisible = false;
        }
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event.
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
