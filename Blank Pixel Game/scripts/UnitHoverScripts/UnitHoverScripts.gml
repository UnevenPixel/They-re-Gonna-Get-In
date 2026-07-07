// -----------------------------------------------------------
// UnitHoverScripts -- a SECOND, paired hover card showing a trained unit
// type's own stats/passives -- 2026-07-11 request. Distinct from every
// other hover card so far in two ways:
//   1. It doesn't stand alone -- it always appears NEXT TO another card
//      (a training building's blueprint-UI card, or its placed-building
//      hover card), and the pair anchors away from the cursor as one
//      combined group (see PositionHoverCardPair, HoverCardScripts.gml).
//   2. It can ALSO appear on its own, fixed in the GUI's top-left corner,
//      whenever exactly one unit is selected (UnitSelectHoverController
//      below) -- no mouse-anchoring, no dwell/fade, just instant show/hide
//      tied to selection state (2026-07-11 clarification: "Instant show/
//      hide... it's not a hover tooltip, it's tied to a deliberate player
//      action").
//
// Layout (shared by all three contexts, per the request's "In Both Cases"
// wording covering blueprint UI + placed-building + single-selection):
//   - Top row: the unit's FULL-size sprite (UnitDefinition.sprites.idle,
//     NOT smallSprite -- that's the Item/Unit Window's purpose-built
//     32x32-ish icon, this wants the real in-world sprite) centered inside
//     an sHoverCardBuildingWindow-sized box (the LARGER of the two icon-row
//     windows, per "use the larger building window") using the exact same
//     bottom-anchor half-height offset BuildingHoverExtras already uses for
//     smallSprite -- sprites.idle is ALSO bottom-center anchored (confirmed
//     via sPeasantIdle.yy: xorigin/yorigin sit at the sprite's horizontal
//     center and within 2px of its bottom edge), so the same math applies
//     unchanged. "HP:"/"DMG:" stat text sits to the RIGHT of that box,
//     vertically centered against it (2026-07-11: request explicitly wrote
//     these as literal text labels, "written as HP and DMG" -- not icons
//     like BuildingHoverExtras' sUIHeart/sUIHammer, so no new icon asset
//     needed here).
//   - Main body (HoverCard's own _body slot): the unit's "Deployed Effect"
//     passive description (UnitHoverDeployedPassiveText) -- falls back to
//     the unit's flavor description if no such passive entry exists, so
//     this never renders blank.
//   - Flavor window (HoverCard's own _flavor slot, but with
//     HOVER_CARD_BODY_FONT instead of the usual italic
//     HOVER_CARD_FLAVOR_FONT -- see HoverCard.Show()'s new _flavorFont
//     param, HoverCardScripts.gml): "Station/Deploy Cost: [gold
//     icon]<amount>" followed by the "Stationed Effect" passive
//     description on its own line. Per the request this is NOT italicized
//     like every other card's flavor text -- it's repurposing that same
//     window/position for different, non-flavor content.
//   - HP display differs by context, driven by _liveUnit (noone or an
//     actual instance) rather than a separate bool -- there's no live unit
//     instance to read from in either blueprint-UI or placed-training-
//     building context (a training building isn't tied to any one specific
//     trained unit), so both naturally want "max HP only"; only the
//     single-selection context ever has a real instance to read
//     GetCurrentHealth off, so passing/not-passing an instance IS the
//     distinction the request draws between "Case 1" and "Case 2".
//   - Cost-to-produce row along the bottom is BLUEPRINT-ONLY (2026-07-11:
//     "In Case 1 (Blueprint UI): 1. Show the cost to produce on the bottom
//     below the station window") -- neither the placed-training-building
//     hover nor the single-selection card shows it (the building/unit
//     already exists in both of those, nothing left to "produce"). Reuses
//     the plain CostToScribbleText (ResourceUIScripts.gml) -- no plot-
//     discount concept applies to training cost, that was placement-
//     specific for buildings.
// -----------------------------------------------------------

#macro UNIT_HOVER_ROW_GAP_TOP    4 // native, gap between the name plate and the top row -- same value as BUILDING_HOVER_ICON_ROW_GAP_TOP/HOVER_CARD_BODY_MARGIN_TOP, no reason for it to differ
#macro UNIT_HOVER_IMAGE_TEXT_GAP_X 6 // native, horizontal gap between the unit image box and the HP/DMG stat text beside it
#macro UNIT_HOVER_ROW_TO_BODY_GAP  4 // native, gap between the top row's bottom and the "Deployed Effect" body text below it
#macro UNIT_HOVER_COST_ROW_GAP_TOP 4 // native, gap between the card's last content (the repurposed flavor window) and the blueprint-only cost row

// Per-instance counter, same "why a global not a #macro" reasoning as
// HoverCard's global.__hoverCardNextId (HoverCardScripts.gml) -- keeps this
// struct's own Scribble elements from colliding in Scribble's
// (uniqueId + string) cache across the (up to 3) simultaneous owners
// this can have: BuildingHoverController, BlueprintController, and the new
// UnitSelectHoverController below.
global.__unitHoverExtrasNextId = 0;

/// @function UnitHoverFindPassive(_unitDef, _passiveName)
/// @description Looks up one entry in _unitDef.passives by its "name" field
///        (e.g. "Deployed Effect" / "Stationed Effect") -- passives is still
///        documented as inert, shape-not-designed-yet data (UnitDefinitions.gml),
///        so this is a defensive linear scan, not a keyed lookup; returns
///        undefined rather than throwing if a unit's passives array doesn't
///        contain a matching entry (every unit registered today does have
///        both, but nothing enforces that).
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
/// @description The unit hover card's main body text -- the "Deployed
///        Effect" passive's description. Falls back to _unitDef.description
///        (the same flavor field BuildingHoverDescriptionText's fallback
///        path uses) if no such passive entry exists, so the body is never
///        blank.
/// @param {Struct.UnitDefinition} _unitDef
/// @returns {String}
function UnitHoverDeployedPassiveText(_unitDef) {
    var _entry = UnitHoverFindPassive(_unitDef, "Deployed Effect");
    return (_entry != undefined) ? _entry.description : _unitDef.description;
}

/// @function UnitHoverStationFlavorText(_unitDef)
/// @description Content for the repurposed (non-italic) flavor window --
///        "Station/Deploy Cost: [gold icon]<amount>", then the "Stationed
///        Effect" passive description on its own line (omitted if no such
///        entry exists -- today every registered unit has one).
/// @param {Struct.UnitDefinition} _unitDef
/// @returns {String}
function UnitHoverStationFlavorText(_unitDef) {
    var _costLine = $"Station/Deploy Cost: {ResourceIconTag("gold")}{_unitDef.stationCost}";

    var _stationedEntry = UnitHoverFindPassive(_unitDef, "Stationed Effect");
    if (_stationedEntry == undefined) return _costLine;

    return _costLine + "\n" + _stationedEntry.description;
}

/// @function UnitHoverExtras()
/// @description Owns the Scribble text elements and draws the unit card's
///        top row (image box + HP/DMG stat text) and blueprint-only cost
///        row -- same "Layout() every frame, feed sizes into HoverCard.Show(),
///        Draw() right after HoverCard.Draw()" pattern as BuildingHoverExtras
///        (BuildingHoverScripts.gml). The owning controller is responsible
///        for calling card.Show() with UnitHoverDeployedPassiveText/
///        UnitHoverStationFlavorText as the body/flavor strings and
///        HOVER_CARD_BODY_FONT as the flavor font override -- this struct
///        only owns the parts HoverCard has no built-in slot for.
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
    /// @description Sets this frame's content and computes how much extra
    ///        vertical space the top row (image + stats) and cost row
    ///        (bottom, blueprint only) need -- feed the result straight into
    ///        HoverCard.Show()'s trailing params, same convention as
    ///        BuildingHoverExtras.Layout.
    /// @param {Struct.UnitDefinition} _unitDef
    /// @param {Id.Instance|Constant.NoOne} _liveUnit noone for the
    ///        blueprint-UI and placed-training-building contexts (max HP
    ///        only, no specific instance to read); an actual oUnitParent
    ///        instance for the single-selection context (shows
    ///        remaining/max HP off that instance).
    /// @param {Bool} _showCostRow True only for the blueprint-UI context.
    /// @returns {Struct} { topContentHeight, bottomContentHeight } --
    ///        already-scaled on-screen px, see HoverCard.Show()'s doc.
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
            showCostRow = (_costString != ""); // a free unit has nothing to show -- no such unit exists today, matching BuildingHoverExtras' same guard
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
    /// @description Call once per Draw GUI event, immediately after
    ///        _card.Draw(_alpha) -- draws the image box + stat text, and,
    ///        if showCostRow, the cost row below everything else.
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
            // Bottom-center anchored (see file header) -- offsetting the
            // draw Y downward by half the sprite's own height re-centers it
            // in the box, same math as BuildingHoverExtras' smallSprite case.
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
/// @description Shared Show() call for the unit hover card -- every one of
///        its 3 owners (BuildingHoverController, BlueprintController,
///        UnitSelectHoverController below) builds identical content, only
///        _liveUnit/_showCostRow differ. Centralizing this avoids 3 copies
///        of the same body/flavor/font wiring drifting out of sync.
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
        HOVER_CARD_BODY_FONT // non-italic override -- see file header
    );
}

// -----------------------------------------------------------
// UnitSelectHoverController -- the single-unit-selection context (top-left
// corner of the GUI, 2026-07-11 request). Instant show/hide, no dwell/fade
// (2026-07-11 clarification) -- tied directly to selectionController.selected
// having EXACTLY one entry, not mouse position at all.
// -----------------------------------------------------------

#macro UNIT_SELECT_HOVER_MARGIN_X 8 // already-scaled on-screen px from the GUI's left edge
#macro UNIT_SELECT_HOVER_MARGIN_Y 8 // already-scaled on-screen px from the GUI's top edge -- clear of the resource bar (bottom-anchored, RESOURCE_BAR_ORIGIN_Y, ResourceUIScripts.gml) and the lower-HUD XpBarWidget, so no overlap check needed against either

/// @function UnitSelectHoverController()
/// @description Owns one HoverCard + one UnitHoverExtras, shown fixed in the
///        GUI's top-left corner whenever selectionController.selected
///        contains EXACTLY one unit -- shows that unit's OWN live
///        remaining/max HP (2026-07-11: "Show remaining HP out of max HP"),
///        no cost row (nothing left to produce, the unit already exists).
///        Same "plain struct, owner calls Step()/Draw()" pattern as every
///        other hover controller -- wire into oUnitControl alongside them.
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
    /// @description Call once per Draw GUI event. No dwell/fade -- draws at
    ///        full alpha whenever visible, nothing otherwise.
    static Draw = function() {
        if (!visible) return;
        card.Draw(1);
        extras.Draw(card, 1);
    }
}
