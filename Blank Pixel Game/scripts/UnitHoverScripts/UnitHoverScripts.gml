// A second, paired hover card showing a trained unit type's stats/passives --
// appears alongside a building card, or standalone on single-unit selection.
// See UnitHoverScripts.md.

#macro UNIT_HOVER_ROW_GAP_TOP    4 // native, gap between the name plate and the top row
#macro UNIT_HOVER_IMAGE_TEXT_GAP_X 6 // native, horizontal gap between the unit image box and the HP/DMG stat text beside it
#macro UNIT_HOVER_ROW_TO_BODY_GAP  4 // native, gap between the top row's bottom and the body text below it
#macro UNIT_HOVER_COST_ROW_GAP_TOP 4 // native, gap between the card's last content and the blueprint-only cost row

// Per-instance counter, same reasoning as HoverCard's global.__hoverCardNextId --
// keeps this struct's Scribble elements from colliding across its up-to-3
// simultaneous owners (BuildingHoverController, BlueprintController, UnitSelectHoverController).
global.__unitHoverExtrasNextId = 0;

/// @function UnitHoverFindPassive(_unitDef, _passiveName)
/// @description Looks up one entry in _unitDef.passives by its "name" field. See .md re: passives still being inert data.
/// @param {Struct.UnitDefinition} _unitDef
/// @param {String} _passiveName
/// @returns {Struct|Undefined} The {name, description} entry, or undefined.
function UnitHoverFindPassive(_unitDef, _passiveName) {
    for (var i = 0; i < array_length(_unitDef.passives); i++) {
        if (_unitDef.passives[i].name == _passiveName) return _unitDef.passives[i];
    }
    return undefined;
}

/// @function UnitHoverDeployedPassiveText(_unitDef)
/// @description Main body text -- the "Deployed Effect" passive description, falling back to _unitDef.description.
/// @param {Struct.UnitDefinition} _unitDef
/// @returns {String}
function UnitHoverDeployedPassiveText(_unitDef) {
    var _entry = UnitHoverFindPassive(_unitDef, "Deployed Effect");
    return (_entry != undefined) ? _entry.description : _unitDef.description;
}

/// @function UnitHoverStationFlavorText(_unitDef)
/// @description Content for the repurposed (non-italic) flavor window -- cost line + "Stationed Effect" passive description.
/// @param {Struct.UnitDefinition} _unitDef
/// @returns {String}
function UnitHoverStationFlavorText(_unitDef) {
    var _costLine = $"Station/Deploy Cost: {ResourceIconTag("gold")}{_unitDef.stationCost}";

    var _stationedEntry = UnitHoverFindPassive(_unitDef, "Stationed Effect");
    if (_stationedEntry == undefined) return _costLine;

    return _costLine + "\n" + _stationedEntry.description;
}

/// @function UnitHoverExtras()
/// @description Owns the top-row (image + HP/DMG) and cost-row Scribble elements. Same "Layout() every frame, feed sizes into HoverCard.Show(), Draw() right after HoverCard.Draw()" pattern as BuildingHoverExtras. The owning controller calls card.Show() with UnitHoverDeployedPassiveText/UnitHoverStationFlavorText as body/flavor and HOVER_CARD_BODY_FONT as the flavor font override.
function UnitHoverExtras() constructor {
    __id = global.__unitHoverExtrasNextId++;

    unitSprite  = noone;
    showCostRow = false;

    statText = scribble("", $"__unitHoverExtras{__id}Stat__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_left, fa_top);

    costText = scribble("", $"__unitHoverExtras{__id}Cost__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_left, fa_top)
        .wrap(HoverCardBodyWrapWidth());

    /// @function Layout(_unitDef, _liveUnit, _showCostRow)
    /// @description Sets this frame's content and computes extra vertical space for the top row and cost row. Feed the result into HoverCard.Show()'s trailing params.
    /// @param {Struct.UnitDefinition} _unitDef
    /// @param {Id.Instance|Constant.NoOne} _liveUnit noone for blueprint-UI/placed-training-building contexts (max HP only); a real oUnitParent instance for single-selection (remaining/max HP).
    /// @param {Bool} _showCostRow True only for the blueprint-UI context.
    /// @returns {Struct} { topContentHeight, bottomContentHeight } -- already-scaled on-screen px.
    static Layout = function(_unitDef, _liveUnit, _showCostRow) {
        unitSprite = _unitDef.sprites.idle;

        var _hpString = (_liveUnit == noone)
            ? string(_unitDef.maxHealth)
            : $"{GetCurrentHealth(_liveUnit)}/{_unitDef.maxHealth}";

        statText = scribble($"HP: {_hpString}\nDMG: {_unitDef.attackDamage}", $"__unitHoverExtras{__id}Stat__")
            .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
            .align(fa_left, fa_top);

        var _boxHeight = sprite_get_height(sHoverCardBuildingWindow) * HOVER_CARD_SCALE;
        var _rowHeight = max(_boxHeight, statText.get_height());
        var _topContentHeight = _rowHeight + (UNIT_HOVER_ROW_GAP_TOP * HOVER_CARD_SCALE) + (UNIT_HOVER_ROW_TO_BODY_GAP * HOVER_CARD_SCALE);

        showCostRow = _showCostRow;
        var _bottomContentHeight = 0;
        if (showCostRow) {
            var _costString = CostToScribbleText(_unitDef.cost);
            showCostRow = (_costString != ""); // a free unit has nothing to show
            if (showCostRow) {
                costText = scribble(_costString, $"__unitHoverExtras{__id}Cost__")
                    .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
                    .align(fa_left, fa_top)
                    .wrap(HoverCardBodyWrapWidth());

                _bottomContentHeight = (UNIT_HOVER_COST_ROW_GAP_TOP * HOVER_CARD_SCALE) + costText.get_height();
            }
        }

        return { topContentHeight: _topContentHeight, bottomContentHeight: _bottomContentHeight };
    }

    /// @function Draw(_card, _alpha)
    /// @description Call once per Draw GUI event, immediately after _card.Draw(_alpha).
    /// @param {Struct.HoverCard} _card
    /// @param {Real} _alpha
    static Draw = function(_card, _alpha) {
        var _rowTopY      = _card.GetContentTopY();
        var _cardLeftEdge = _card.x;

        var _boxHalfW   = (sprite_get_width(sHoverCardBuildingWindow) / 2) * HOVER_CARD_SCALE;
        var _boxCenterX = _cardLeftEdge + (HOVER_CARD_BODY_MARGIN_X * HOVER_CARD_SCALE) + _boxHalfW;
        var _boxCenterY = _rowTopY + (sprite_get_height(sHoverCardBuildingWindow) / 2) * HOVER_CARD_SCALE;

        draw_sprite_ext(sHoverCardBuildingWindow, 0, _boxCenterX, _boxCenterY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);

        if (unitSprite != noone) {
            // Bottom-center anchored -- offset the draw Y down by half the
            // sprite's own height to re-center it in the box.
            var _offsetY = (sprite_get_height(unitSprite) / 2) * HOVER_CARD_SCALE;
            draw_sprite_ext(unitSprite, 0, _boxCenterX, _boxCenterY + _offsetY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);
        }

        var _statX = _boxCenterX + _boxHalfW + (UNIT_HOVER_IMAGE_TEXT_GAP_X * HOVER_CARD_SCALE);
        var _statY = _boxCenterY - statText.get_height() / 2; // vertically centered against the image box
        DrawCardTextWithShadow(statText, _statX, _statY, _alpha);

        if (showCostRow) {
            var _costX = _card.x + HOVER_CARD_BODY_MARGIN_X * HOVER_CARD_SCALE;
            var _costY = _card.GetContentBottomY() + UNIT_HOVER_COST_ROW_GAP_TOP * HOVER_CARD_SCALE;
            DrawCardTextWithShadow(costText, _costX, _costY, _alpha);
        }
    }
}

/// @function ShowUnitHoverCard(_card, _extras, _unitDef, _liveUnit, _showCostRow)
/// @description Shared Show() call for the unit hover card -- centralizes identical body/flavor/font wiring across its 3 owners. See .md.
/// @param {Struct.HoverCard} _card
/// @param {Struct.UnitHoverExtras} _extras
/// @param {Struct.UnitDefinition} _unitDef
/// @param {Id.Instance|Constant.NoOne} _liveUnit
/// @param {Bool} _showCostRow
function ShowUnitHoverCard(_card, _extras, _unitDef, _liveUnit, _showCostRow) {
    var _sizes = _extras.Layout(_unitDef, _liveUnit, _showCostRow);
    _card.Show(
        _unitDef.name,
        UnitHoverDeployedPassiveText(_unitDef),
        0, 0,
        UnitHoverStationFlavorText(_unitDef),
        _sizes.topContentHeight,
        _sizes.bottomContentHeight,
        HOVER_CARD_BODY_FONT // non-italic override -- see .md
    );
}

// -----------------------------------------------------------
// UnitSelectHoverController -- the single-unit-selection context (top-left
// corner of the GUI). Instant show/hide, no dwell/fade -- tied directly to
// selectionController.selected having exactly one entry, not mouse position.
// -----------------------------------------------------------

#macro UNIT_SELECT_HOVER_MARGIN_X 8 // already-scaled on-screen px from the GUI's left edge
#macro UNIT_SELECT_HOVER_MARGIN_Y 8 // already-scaled on-screen px from the GUI's top edge

/// @function UnitSelectHoverController()
/// @description Owns one HoverCard + one UnitHoverExtras, shown fixed top-left whenever exactly one unit is selected -- shows that unit's own live remaining/max HP, no cost row. Owner calls Step()/Draw().
function UnitSelectHoverController() constructor {
    card   = new HoverCard();
    extras = new UnitHoverExtras();
    visible = false;

    /// @function Step(_selectionController)
    /// @description Call once per Step event.
    /// @param {Struct.SelectionController} _selectionController
    static Step = function(_selectionController) {
        visible = false;

        if (array_length(_selectionController.selected) != 1) return;

        var _unit = _selectionController.selected[0];
        var _def  = GetUnitDefinition(_unit.object_index);
        if (_def == undefined) return;

        ShowUnitHoverCard(card, extras, _def, _unit, false);

        card.x = UNIT_SELECT_HOVER_MARGIN_X;
        card.y = UNIT_SELECT_HOVER_MARGIN_Y;
        visible = true;
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event. No dwell/fade -- draws at full alpha whenever visible.
    static Draw = function() {
        if (!visible) return;
        card.Draw(1);
        extras.Draw(card, 1);
    }
}
