// -----------------------------------------------------------
// BuildingHoverScripts -- hover/tooltip data overlay for PLACED building
// instances (oBuildingParent, in-world) AND blueprint UI slots
// (BlueprintController, GUI-space) -- 2026-07-08 request. Second real
// consumer of the general-purpose HoverCard base (HoverCardScripts.gml),
// after PlotHoverScripts.gml.
//
// Reuses PlotHoverScripts.gml's dwell/fade/anchor constants
// (PLOT_HOVER_DELAY_STEPS/PLOT_HOVER_FADE_STEPS/PLOT_HOVER_CURSOR_GAP) --
// the request says building hover should appear "the same way the plot
// hover data appears (after 1 second, as I adjusted it myself)", i.e. the
// SAME timing, not a separate copy of it. The "PLOT_HOVER_" prefix is now
// a bit of a misnomer since 3 systems share these constants (plot/building/
// blueprint); flagging rather than renaming an already-shipped macro name
// without being asked -- a future pass could rename to something generic
// like HOVER_CARD_DELAY_STEPS.
//
// This is the first consumer to need MORE than HoverCard's built-in
// name+body+flavor slots -- production/training buildings show an extra
// "icon row" above the body text (a building icon, a timer/rate readout,
// and the produced item's icon), per the ORIGINAL hover-card spec's items
// C/D/E (sHoverCardBuildingWindow/sHoverCardTimer/sHoverCardUnitWindow,
// all registered but unused until now -- see HoverCardScripts.gml's file
// header). HoverCardScripts.gml gained two new OPTIONAL trailing Show()
// params this pass (_topContentHeight/_bottomContentHeight, both default 0)
// so this icon row -- and a blueprint-only cost row below everything else --
// can reserve space without touching PlotHoverController's existing call
// site at all. BuildingHoverExtras (below) draws that row itself, using
// HoverCard.GetContentTopY()/GetContentBottomY() so it never has to
// duplicate HoverCard's internal layout math.
//
// Layout call: the building's own icon goes in the TOP LEFT of the body,
// matching sHoverCardBuildingWindow's ORIGINAL spec wording ("placed in the
// top left corner") -- an initial pass here had it top-right per a
// misreading of that day's request, corrected 2026-07-08 once flagged.
// Combined with the ORIGINAL spec's wording for the other two sprites --
// sHoverCardTimer "placed next to the Building Window, tops in line", and
// sHoverCardUnitWindow "on the other side of the card timer" from the
// Building Window -- the icon row reads LEFT TO RIGHT as:
//     [ Building Window ] [ Timer ] [ Item/Unit Window ]
// i.e. the Building Window anchors to the body's left margin, Timer sits
// immediately to its right, and the Item/Unit Window sits immediately to
// the Timer's right. All three columns' TOP edges align. This ordering is
// fully determined by combining the two specs above -- not a fresh guess --
// but the exact pixel gaps between columns (BUILDING_HOVER_ICON_GAP_X etc.)
// are new judgment calls this pass, worth a visual sanity check in-engine.
//
// Two hover contexts share ALL the data-gathering/drawing logic below
// (BuildingHoverExtras, BuildingHoverDescriptionText, etc.) but differ in
// exactly two ways, both threaded through an _isBlueprint bool:
//   - Placed building (BuildingHoverController, driven by oUnitControl's
//     Step/Draw): resource-limit reads as "remaining/total" (e.g. "300/400"
//     -- how much MORE this specific instance can still produce before
//     hitting its cap), read off the LIVE INSTANCE's own
//     resourceLimit/producedTotal (not the BuildingDefinition's base
//     resourceLimit) -- a Distant-plot building's resourceLimit may already
//     be +50% boosted by ApplyPlotBonuses (BuildingDefinitions.gml,
//     2026-07-07), so this correctly reflects its actual current cap, not
//     the un-boosted base value. Health reads the same way (GetCurrentHealth
//     off the live instance) -- see BuildingHoverHealthText. No cost row
//     (already paid for).
//   - Blueprint slot (BlueprintController, driven by its own Step/Draw
//     wiring, BlueprintScripts.gml): resource-limit reads as just the flat
//     BuildingDefinition.resourceLimit (no instance exists yet, nothing
//     produced); health reads as the flat BuildingDefinition.maxHealth.
//     PLUS a cost row along the card's bottom, one "[icon]Base (Discount)"
//     run per resource (CostToScribbleTextWithDiscount, ResourceUIScripts.gml
//     -- 2026-07-09, replacing an interim single-price version from earlier
//     that same day). Base price and the parenthesized discount price color
//     red INDEPENDENTLY of each other by _team's current affordability; the
//     discount price additionally renders in
//     BLUEPRINT_DISCOUNT_UNAVAILABLE_COLOR_TAG (dark gray, BlueprintScripts.gml)
//     whenever no currently open plot would actually grant the discount
//     (GetBestAvailablePlacementCost's discountAvailable), regardless of its
//     own affordability. The card's own TITLE (the building name) still
//     renders red if the building can't be placed anywhere right now at all
//     (no open owned plot, or unaffordable even at the cheapest available
//     price) -- unchanged from the interim version, still driven by
//     GetBestAvailablePlacementCost's blended cost + anyPlotAvailable.
//
// 2026-07-11 addition -- placed TRAINING buildings now show a queue row in
// that exact same bottom slot the blueprint cost row occupies (mutually
// exclusive with it -- a blueprint has no queue, a placed building has no
// cost left to pay). Left to right: the trained unit's small icon + how
// many are currently queued, a progress bar toward the next completion
// (black background, filled in HOVER_CARD_TEXT_COLOR -- a plain drawn
// rectangle, not a sprite/Scribble element), then the seconds remaining
// until that next completion (ceil'd so it doesn't misleadingly hit "0s"
// a fraction of a second early). Reads trainQueue/trainProgress/trainTime
// straight off the live instance (TrainingScripts.gml owns updating them).
// Placed NON-training buildings (resource buildings) show neither this row
// nor the cost row -- nothing to queue, nothing left to pay.
//
// 2026-07-12: also TEAM.PLAYER-only now -- "enemy buildings do not show
// training queues or progress" -- see BuildingHoverExtras.Layout's
// showQueueRow line.
//
// "What it does" (the card's normal body text, e.g. "Produces [icon]Wheat"/
// "Trains [icon]Peasant") is auto-generated from BuildingDefinition fields,
// not authored -- see BuildingHoverDescriptionText. 2026-07-09 follow-up:
// the resource/unit name is now preceded by that resource's/unit's own icon
// (ResourceIconTag for resources, the new UnitIconTag for units --
// UnitDefinitions.gml). The flavor window reuses BuildingDefinition.
// description -- an EXISTING field that was already defined on every
// registered building (BuildingDefinitions.gml) but never actually
// DISPLAYED anywhere before this pass (confirmed via a project-wide grep
// for ".description" -- it only appeared in the file that defines it).
// Rather than add a redundant new field for "flavor text", this pass just
// wires that already-authored-but-dormant field up as the flavor text. Per
// the 2026-07-08 request ("I will provide the flavor text later when I find
// the document containing them"), these existing descriptions are
// PLACEHOLDER flavor text until the real, document-sourced versions arrive
// -- don't treat current wording as final.
//
// Suppression / mutual exclusion: a building can never be hovered while
// its plot shows plot-hover data, because PlotHoverController only
// triggers on UN-OCCUPIED plots (PlotHoverScripts.gml) and a placed
// building's plot is, by definition, occupied -- no extra guard needed
// there, it just falls out of the existing design. The genuinely new
// conflict is the Blueprint UI panel: it's a GUI-space overlay drawn on
// top of the game world, so the mouse can simultaneously sit over a filled
// blueprint slot (GUI-space) AND whatever world-space plot/building
// happens to render underneath that same screen position (room-space,
// via mouse_x/mouse_y) -- without a fix, both a blueprint tooltip AND a
// plot/building tooltip could try to show at once. Fixed by having
// BlueprintController expose IsMouseOverPanel() (BlueprintScripts.gml,
// checks the whole grid's bounding rect, not just filled slots) and having
// BOTH PlotHoverSuppressed (PlotHoverScripts.gml) and
// BuildingHoverSuppressed (below) treat that as a suppression condition.
// -----------------------------------------------------------

#macro BUILDING_HOVER_ICON_ROW_GAP_TOP 4 // native, gap between the name plate and the icon row -- same value as HOVER_CARD_BODY_MARGIN_TOP, no reason for it to differ
#macro BUILDING_HOVER_ICON_GAP_X       4 // native, horizontal gap between adjacent icon-row columns (Item Window <-> Timer <-> Building Window)
#macro BUILDING_HOVER_ICON_LABEL_GAP_Y 2 // native, gap between an icon's bottom edge and its label text below it (Timer's rate/time text, the Item Window's resource-limit text)
#macro BUILDING_HOVER_ROW_TO_BODY_GAP  4 // native, gap between the icon row's bottom and the "what it does" body text below it
#macro BUILDING_HOVER_COST_ROW_GAP_TOP 4 // native, gap between the card's last content (flavor window, or body text if none) and the blueprint-only cost row / placed-training-building queue row -- see file header, these two rows are mutually exclusive and share the same slot
#macro BUILDING_HOVER_QUEUE_GAP_X      6 // already-scaled on-screen px, horizontal gap between the queue row's 3 sections (icon+count / progress bar / time remaining) -- unlike the icon-row gaps above, this is defined directly in on-screen px (not native*HOVER_CARD_SCALE) since it sits between a scaled sprite and unscaled Scribble text widths, which aren't directly comparable in native units -- see BuildingHoverExtras.Layout's queue-row block
#macro BUILDING_HOVER_QUEUE_BAR_HEIGHT 10 // native, progress bar height (scaled by HOVER_CARD_SCALE like everything else non-text)
#macro BUILDING_HOVER_QUEUE_BAR_MIN_WIDTH 20 // already-scaled on-screen px floor -- if the icon+count and time text somehow leave less than this, the bar still gets drawn at this width rather than vanishing/going negative (shouldn't happen at this card's normal width, but not asserted)

// Per-instance counter, same "why a global not a #macro" reasoning as
// HoverCard's global.__hoverCardNextId (HoverCardScripts.gml) -- keeps
// BuildingHoverExtras' own Scribble elements (timer/limit/cost text) from
// colliding in Scribble's (uniqueId + string) cache if more than one
// instance ever exists at once (e.g. world building hover AND blueprint
// hover, owned by BuildingHoverController and BlueprintController
// respectively).
global.__buildingHoverExtrasNextId = 0;

/// @function BuildingHoverTitleCase(_word)
/// @description Capitalizes the first letter only -- "wheat" -> "Wheat".
///        Used to turn a raw resource-name string (global.resources /
///        Cost's lowercase keys) into display text.
/// @param {String} _word
/// @returns {String}
function BuildingHoverTitleCase(_word) {
    if (string_length(_word) == 0) return _word;
    return string_upper(string_copy(_word, 1, 1)) + string_copy(_word, 2, string_length(_word) - 1);
}

/// @function BuildingHoverDescriptionText(_def)
/// @description The hover card's NORMAL body text -- a short, auto-
///        generated statement of what this building type mechanically
///        does, e.g. "Produces [icon]Wheat" / "Trains [icon]Peasant".
///        Distinct from the flavor window (BuildingDefinition.description)
///        -- see file header. 2026-07-09 request: the resource/unit name is
///        preceded by its own icon (ResourceIconTag/UnitIconTag). Singular
///        unit names are used as-is ("Trains Peasant", not "Trains
///        Peasants") to avoid inventing English pluralization rules that
///        would break on irregular names; flag if plural reads better and
///        is worth the risk.
/// @param {Struct.BuildingDefinition} _def
/// @returns {String}
function BuildingHoverDescriptionText(_def) {
    if (_def.productionResource != undefined) {
        return $"Produces {ResourceIconTag(_def.productionResource)}{BuildingHoverTitleCase(_def.productionResource)}";
    }

    if (_def.trainsUnit != undefined) {
        var _unitDef = GetUnitDefinition(_def.trainsUnit);
        return (_unitDef != undefined) ? $"Trains {UnitIconTag(_unitDef)}{_unitDef.name}" : "Trains a unit";
    }

    // Neither production nor training (e.g. a future "facility" building,
    // per the ORIGINAL hover-card spec's "training, resource, facility"
    // wording) -- nothing mechanical to auto-generate, so fall back to the
    // descriptive field directly rather than showing a blank line.
    return _def.description;
}

/// @function BuildingHoverTimerText(_def, _building, _isBlueprint)
/// @description The label drawn below the Timer icon -- "{rate} /sec" for
///        production buildings, "{trainTime} sec" for training buildings,
///        "" for anything else (no Timer icon is drawn at all in that
///        case -- see BuildingHoverExtras.Layout).
/// @param {Struct.BuildingDefinition} _def
/// @param {Id.Instance|Constant.NoOne} _building A placed building
///        instance, or noone when _isBlueprint is true.
/// @param {Bool} _isBlueprint
/// @returns {String}
function BuildingHoverTimerText(_def, _building, _isBlueprint) {
    if (_def.productionResource != undefined) {
        var _rate = _isBlueprint ? _def.productionRate : _building.productionRate;
        return $"{_rate} /sec";
    }

    if (_def.trainsUnit != undefined) {
        var _time = _isBlueprint ? _def.trainTime : _building.trainTime;
        return $"{_time} sec";
    }

    return "";
}

/// @function BuildingHoverResourceLimitText(_def, _building, _isBlueprint)
/// @description The label drawn below the Item/Unit Window, ONLY for
///        resource (production) buildings with a resourceLimit -- "" for
///        training buildings (they have no resourceLimit concept) and for
///        unlimited resource buildings (resourceLimit left undefined).
///        Blueprint hover shows just the flat limit ("400"); placed-
///        building hover shows "remaining/total" (e.g. "300/400" -- 300
///        more units before this INSTANCE depletes, 400 its current
///        total cap) -- 2026-07-08 request. Reads resourceLimit/
///        producedTotal off the LIVE INSTANCE (not _def) for the placed
///        case, since ApplyPlotBonuses (BuildingDefinitions.gml) may have
///        already boosted a Distant-plot instance's resourceLimit above
///        _def's base value -- this shows the instance's ACTUAL current
///        cap.
/// @param {Struct.BuildingDefinition} _def
/// @param {Id.Instance|Constant.NoOne} _building A placed building
///        instance, or noone when _isBlueprint is true.
/// @param {Bool} _isBlueprint
/// @returns {String}
function BuildingHoverResourceLimitText(_def, _building, _isBlueprint) {
    if (_def.productionResource == undefined) return "";

    if (_isBlueprint) {
        return (_def.resourceLimit == undefined) ? "" : string(_def.resourceLimit);
    }

    if (_building.resourceLimit == undefined) return "";
    return $"{_building.resourceLimit - _building.producedTotal}/{_building.resourceLimit}";
}

/// @function BuildingHoverHealthText(_def, _building, _isBlueprint)
/// @description The label drawn on a second line under the Item/Unit
///        Window, right below the production-amount line (2026-07-09
///        request: "under production amount's, add in health as well") --
///        unlike BuildingHoverResourceLimitText, this is NOT conditional on
///        productionResource -- every building has a maxHealth, so this
///        always returns a real value whenever the Item/Unit Window itself
///        is showing anything at all (see BuildingHoverExtras.Layout).
///        Blueprint hover shows just the flat BuildingDefinition.maxHealth
///        ("100"); placed-building hover shows "remaining/max" (e.g.
///        "80/100") via GetCurrentHealth (UnitDefinitions.gml -- already
///        generic over units AND buildings despite the name), read off the
///        LIVE INSTANCE so a Distant-plot-boosted building's already-larger
///        maxHealth (ApplyPlotBonuses, BuildingDefinitions.gml) is reflected
///        correctly, same reasoning as BuildingHoverResourceLimitText.
/// @param {Struct.BuildingDefinition} _def
/// @param {Id.Instance|Constant.NoOne} _building A placed building
///        instance, or noone when _isBlueprint is true.
/// @param {Bool} _isBlueprint
/// @returns {String}
function BuildingHoverHealthText(_def, _building, _isBlueprint) {
    if (_isBlueprint) return string(_def.maxHealth);
    return $"{GetCurrentHealth(_building)}/{_building.maxHealth}";
}

/// @function BuildingHoverItemIcon(_def)
/// @description Resolves the sprite/frame to draw inside the Item/Unit
///        Window (sHoverCardUnitWindow) -- a resource icon
///        (sResourceIcons, via ResourceIconIndex, ResourceUIScripts.gml)
///        for production buildings, or the trained unit's SMALL sprite
///        (UnitDefinition.smallSprite, frame 0) for training buildings.
///        2026-07-09 follow-up: previously used the unit's idle (walk-cycle)
///        sprite, which wasn't sized for this 28x28 window; now uses the
///        purpose-built "small" variant instead (see
///        BuildingHoverExtras.Layout/Draw for the vertical-centering math
///        this enables).
/// @param {Struct.BuildingDefinition} _def
/// @returns {Struct|Undefined} { sprite, image } or undefined if this
///        building type neither produces nor trains anything.
function BuildingHoverItemIcon(_def) {
    if (_def.productionResource != undefined) {
        return { sprite: sResourceIcons, image: ResourceIconIndex(_def.productionResource) };
    }

    if (_def.trainsUnit != undefined) {
        var _unitDef = GetUnitDefinition(_def.trainsUnit);
        return (_unitDef != undefined) ? { sprite: _unitDef.smallSprite, image: 0 } : undefined;
    }

    return undefined;
}

/// @function BuildingHoverExtras()
/// @description Owns the Scribble text elements (timer/resource-limit/cost
///        labels) and draws the "icon row" + blueprint-only cost row that
///        sit ABOVE and BELOW a HoverCard's own content respectively --
///        see file header for why this lives outside HoverCard itself
///        (shared by both the world-building and blueprint hover
///        contexts). Call Layout() every time the card's content changes
///        (mirrors HoverCard.Show()'s "safe to call every frame" design),
///        then pass its returned sizes into HoverCard.Show(), THEN call
///        Draw() right after HoverCard.Draw() so this row layers on top in
///        the right place.
function BuildingHoverExtras() constructor {
    __id = global.__buildingHoverExtrasNextId++;

    hasTimerText    = false;
    hasLimitText    = false;
    hasItemIcon     = false;
    showCostRow     = false;
    buildingSprite  = noone;
    itemIconSprite  = noone;
    itemIconImage   = 0;
    itemIconOffsetY = 0; // 2026-07-09: vertical draw offset for the item icon ONLY, see Layout/Draw -- 0 for the resource-icon case (already centered via the window's own middle-center origin), (spriteHeight/2)*HOVER_CARD_SCALE for the unit smallSprite case (bottom-center-anchored, so this centers it in the window instead)

    // 2026-07-11 addition -- placed training building queue row, see file
    // header. Mutually exclusive with showCostRow (one's blueprint-only,
    // the other's placed-only) but both share the same bottom slot/height
    // return value.
    showQueueRow     = false;
    queueIconSprite  = noone;
    queueIconImage   = 0;
    queueIconWidth   = 0; // already-scaled on-screen px, cached by Layout for Draw
    queueIconHeight  = 0;
    queueFraction    = 0; // 0-1, trainProgress / trainTime
    queueBarWidth    = 0; // already-scaled on-screen px, whatever's left over after the icon+count and time text -- computed fresh in Layout since it depends on both text widths
    queueRowHeight   = 0;

    timerText = scribble("", $"__buildingHoverExtras{__id}Timer__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_center, fa_top);

    limitText = scribble("", $"__buildingHoverExtras{__id}Limit__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_center, fa_top);

    costText = scribble("", $"__buildingHoverExtras{__id}Cost__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_left, fa_top)
        .wrap(HoverCardBodyWrapWidth());

    queueCountText = scribble("", $"__buildingHoverExtras{__id}QueueCount__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_left, fa_middle);

    queueTimeText = scribble("", $"__buildingHoverExtras{__id}QueueTime__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_right, fa_middle);

    /// @function Layout(_def, _building, _isBlueprint, _team)
    /// @description Sets this frame's text content and computes how much
    ///        extra vertical space the icon row (top) and cost row
    ///        (bottom, blueprint only) need -- feed the result straight
    ///        into HoverCard.Show()'s trailing params.
    /// @param {Struct.BuildingDefinition} _def
    /// @param {Id.Instance|Constant.NoOne} _building A placed building
    ///        instance, or noone when _isBlueprint is true.
    /// @param {Bool} _isBlueprint
    /// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY -- 2026-07-09 addition,
    ///        needed for the blueprint-only cost row's best-available-cost
    ///        lookup (GetBestAvailablePlacementCost, BlueprintScripts.gml)
    ///        and per-resource affordability coloring
    ///        (CostToScribbleTextWithDiscount, ResourceUIScripts.gml).
    ///        Unused when _isBlueprint is false, but still required since
    ///        this is one shared function -- callers always have a team
    ///        handy (BlueprintController owns one; BuildingHoverController
    ///        passes the hovered building's own instance team).
    /// @returns {Struct} { topContentHeight, bottomContentHeight } -- both
    ///        already-scaled on-screen px, see HoverCard.Show()'s doc.
    static Layout = function(_def, _building, _isBlueprint, _team) {
        buildingSprite = _def.sprite;

        var _timerString = BuildingHoverTimerText(_def, _building, _isBlueprint);
        hasTimerText = (_timerString != "");
        if (hasTimerText) {
            timerText = scribble(_timerString, $"__buildingHoverExtras{__id}Timer__")
                .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
                .align(fa_center, fa_top);
        }

        var _icon = BuildingHoverItemIcon(_def);
        hasItemIcon = (_icon != undefined);
        itemIconOffsetY = 0;
        if (hasItemIcon) {
            itemIconSprite = _icon.sprite;
            itemIconImage  = _icon.image;

            // Unit smallSprite is bottom-center anchored (see
            // BuildingHoverItemIcon's doc) -- drawing it at the window's own
            // center Y would put its BOTTOM half below the window instead of
            // centering it. Offsetting the draw Y downward by half the
            // sprite's own height re-centers it: window center Y + half
            // sprite height = the Y the bottom-anchor should sit at for the
            // sprite's vertical MIDPOINT to land on the window's center.
            // Resource icons (sResourceIcons, middle-center origin) need no
            // offset -- they already center correctly at the window's center.
            if (_def.trainsUnit != undefined) {
                itemIconOffsetY = (sprite_get_height(itemIconSprite) / 2) * HOVER_CARD_SCALE;
            }
        }

        // -- Production-amount + health label, under the Item/Unit Window.
        // 2026-07-09 request: health is now ALWAYS shown here (every
        // building has a maxHealth, unlike resourceLimit which only applies
        // to production buildings) -- production amount stays on its own
        // line above health when applicable, each prefixed with its own icon
        // (sUIHammer/sUIHeart) so the two numbers are never ambiguous next to
        // each other. --
        var _limitString  = BuildingHoverResourceLimitText(_def, _building, _isBlueprint);
        var _healthString = BuildingHoverHealthText(_def, _building, _isBlueprint);

        hasLimitText = hasItemIcon; // the label block only makes sense under an actual icon
        if (hasLimitText) {
            var _limitCombined = (_limitString != "")
                ? $"[sUIHammer,0]{_limitString}\n[sUIHeart,0]{_healthString}"
                : $"[sUIHeart,0]{_healthString}";

            limitText = scribble(_limitCombined, $"__buildingHoverExtras{__id}Limit__")
                .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
                .align(fa_center, fa_top);
        }

        // -- Icon row height: tallest of the 3 columns. Building Window is
        // a fixed height; Timer/Item columns add their label text's height
        // (native, unscaled -- text stays 1x per this project's standing
        // "layout scales, glyphs don't" convention) UNDER their icon, only
        // when that column actually has something to show. --
        var _buildingColHeight = sprite_get_height(sHoverCardBuildingWindow) * HOVER_CARD_SCALE;

        var _timerColHeight = 0;
        if (hasTimerText) {
            _timerColHeight = (sprite_get_height(sHoverCardTimer) * HOVER_CARD_SCALE)
                + (BUILDING_HOVER_ICON_LABEL_GAP_Y * HOVER_CARD_SCALE)
                + timerText.get_height();
        }

        var _itemColHeight = 0;
        if (hasItemIcon) {
            _itemColHeight = sprite_get_height(sHoverCardUnitWindow) * HOVER_CARD_SCALE;
            if (hasLimitText) {
                _itemColHeight += (BUILDING_HOVER_ICON_LABEL_GAP_Y * HOVER_CARD_SCALE) + limitText.get_height();
            }
        }

        var _rowHeight = max(_buildingColHeight, _timerColHeight, _itemColHeight);
        var _topContentHeight = _rowHeight + (BUILDING_HOVER_ICON_ROW_GAP_TOP * HOVER_CARD_SCALE) + (BUILDING_HOVER_ROW_TO_BODY_GAP * HOVER_CARD_SCALE);

        // -- Cost row (blueprint hover only). 2026-07-09 follow-up: shows
        // BOTH the base price and the parenthesized discount price side by
        // side ("[icon]Base (Discount)"), each colored red independently by
        // _team's current affordability -- and the discount price additionally
        // forced to BLUEPRINT_DISCOUNT_UNAVAILABLE_COLOR_TAG (dark gray,
        // BlueprintScripts.gml) whenever no currently open plot would
        // actually grant the discount (GetBestAvailablePlacementCost's
        // discountAvailable), regardless of whether it'd be affordable. --
        showCostRow = _isBlueprint;
        var _bottomContentHeight = 0;
        if (showCostRow) {
            var _best         = GetBestAvailablePlacementCost(_team, _def);
            var _discountCost = GetDiscountedCost(_def.cost, PLOT_BONUS_DISCOUNT_FRACTION);
            var _costString   = CostToScribbleTextWithDiscount(_def.cost, _discountCost, _best.discountAvailable, _team);
            showCostRow = (_costString != ""); // a free building has nothing to show -- no such building exists today, but don't reserve dead space if one ever does
            if (showCostRow) {
                costText = scribble(_costString, $"__buildingHoverExtras{__id}Cost__")
                    .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
                    .align(fa_left, fa_top)
                    .wrap(HoverCardBodyWrapWidth());

                _bottomContentHeight = (BUILDING_HOVER_COST_ROW_GAP_TOP * HOVER_CARD_SCALE) + costText.get_height();
            }
        }

        // -- Queue row (placed training buildings only) -- see file header.
        // Mutually exclusive with the cost row above (_isBlueprint gates
        // one, !_isBlueprint && trainsUnit gates the other), so there's no
        // conflict over _bottomContentHeight.
        //
        // 2026-07-12 request: "enemy buildings do not show training queues
        // or progress" -- _team is the hovered BUILDING's own team here
        // (see this function's doc comment), so gating on _team ==
        // TEAM.PLAYER directly hides this row for enemy training buildings
        // without touching the blueprint-only cost row above (blueprint
        // hover is always the player's own panel, never an enemy context).
        showQueueRow = (!_isBlueprint && _team == TEAM.PLAYER && _def.trainsUnit != undefined);
        if (showQueueRow) {
            var _unitDef = GetUnitDefinition(_def.trainsUnit);
            showQueueRow = (_unitDef != undefined);
        }
        if (showQueueRow) {
            // 2026-07-11 follow-up: uses the unit's small inline ICON
            // (UnitDefinition.icon, e.g. sPeasantIcon -- middle-center
            // anchored, 8x8 native) instead of smallSprite (the bigger,
            // bottom-anchored Item/Unit Window sprite) -- was smallSprite,
            // corrected per request. Also fixes an unflagged bug from last
            // pass: smallSprite is bottom-center anchored and needed a
            // vertical re-centering offset (see itemIconOffsetY above) that
            // the queue row never applied -- icon's middle-center anchor
            // needs no such offset, drawing correctly centered as-is.
            queueIconSprite = _unitDef.icon;
            queueIconImage  = 0;
            queueIconWidth  = (queueIconSprite != undefined) ? sprite_get_width(queueIconSprite)  * HOVER_CARD_SCALE : 0;
            queueIconHeight = (queueIconSprite != undefined) ? sprite_get_height(queueIconSprite) * HOVER_CARD_SCALE : 0;

            queueCountText = scribble(string(_building.trainQueue), $"__buildingHoverExtras{__id}QueueCount__")
                .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
                .align(fa_left, fa_middle);

            queueFraction = (_building.trainTime > 0)
                ? clamp(_building.trainProgress / _building.trainTime, 0, 1)
                : 0;

            // Seconds until the FRONT of the queue completes (not the whole
            // queue) -- ceil'd so it doesn't read "0s" a fraction of a
            // second before the unit actually spawns. "-" when nothing's
            // queued (trainProgress is always 0 then -- TrainingUpdateQueue
            // resets it the moment the queue empties) rather than a
            // misleading "0s"/"{trainTime}s".
            var _remainingString = (_building.trainQueue > 0 && _building.trainTime > 0)
                ? $"{ceil(_building.trainTime - _building.trainProgress)}s"
                : "-";
            // fa_left now (was fa_right) -- the time text follows the bar's
            // right edge rather than pinning to the row's fixed right edge,
            // see the bar-width comment below.
            queueTimeText = scribble(_remainingString, $"__buildingHoverExtras{__id}QueueTime__")
                .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
                .align(fa_left, fa_middle);

            // 2026-07-11 follow-up: the bar is now centered on the CARD's
            // full width, not just "whatever's left over" -- its left edge
            // sits (margin + icon + gap + count + gap) in from the card's
            // left edge, and its right edge is placed that SAME distance in
            // from the card's right edge (mirrored), rather than being sized
            // around the time text's width. The time text now trails the
            // bar instead of anchoring the row's right edge -- see Draw().
            var _barLeftOffset = (HOVER_CARD_BODY_MARGIN_X * HOVER_CARD_SCALE) + queueIconWidth
                + BUILDING_HOVER_QUEUE_GAP_X + queueCountText.get_width() + BUILDING_HOVER_QUEUE_GAP_X;
            queueBarWidth = max(BUILDING_HOVER_QUEUE_BAR_MIN_WIDTH, (HOVER_CARD_WIDTH * HOVER_CARD_SCALE) - (2 * _barLeftOffset));

            queueRowHeight = max(
                queueIconHeight,
                BUILDING_HOVER_QUEUE_BAR_HEIGHT * HOVER_CARD_SCALE,
                queueCountText.get_height(),
                queueTimeText.get_height()
            );

            _bottomContentHeight = (BUILDING_HOVER_COST_ROW_GAP_TOP * HOVER_CARD_SCALE) + queueRowHeight;
        }

        return { topContentHeight: _topContentHeight, bottomContentHeight: _bottomContentHeight };
    }

    /// @function Draw(_card, _alpha)
    /// @description Call once per Draw GUI event, immediately after
    ///        _card.Draw(_alpha) -- draws the icon row (building/timer/
    ///        item windows + their labels) and, if showCostRow, the
    ///        blueprint cost row below everything else.
    /// @param {Struct.HoverCard} _card
    /// @param {Real} _alpha
    static Draw = function(_card, _alpha) {
        var _rowTopY      = _card.GetContentTopY();
        var _cardLeftEdge = _card.x;

        // Building icon window -- top-left of the body (matches
        // sHoverCardBuildingWindow's ORIGINAL spec wording; see file
        // header for the 2026-07-08 top-right -> top-left correction).
        var _buildingHalfW   = (sprite_get_width(sHoverCardBuildingWindow) / 2) * HOVER_CARD_SCALE;
        var _buildingCenterX = _cardLeftEdge + (HOVER_CARD_BODY_MARGIN_X * HOVER_CARD_SCALE) + _buildingHalfW;
        var _buildingCenterY = _rowTopY + (sprite_get_height(sHoverCardBuildingWindow) / 2) * HOVER_CARD_SCALE;

        draw_sprite_ext(sHoverCardBuildingWindow, 0, _buildingCenterX, _buildingCenterY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);
        if (buildingSprite != noone) {
            draw_sprite_ext(buildingSprite, 0, _buildingCenterX, _buildingCenterY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);
        }

        var _cursorLeftEdge = _buildingCenterX + _buildingHalfW;

        // Timer icon + text -- immediately to the Building Window's RIGHT,
        // tops aligned (ORIGINAL spec, item D). sHoverCardTimer has a
        // TOP-CENTER origin (unlike the other two windows' middle-center),
        // so drawing it at Y = _rowTopY directly already puts its TOP edge
        // there -- same row-top alignment as the other two columns without
        // a half-height offset.
        if (hasTimerText) {
            var _timerHalfW   = (sprite_get_width(sHoverCardTimer) / 2) * HOVER_CARD_SCALE;
            var _timerCenterX = _cursorLeftEdge + (BUILDING_HOVER_ICON_GAP_X * HOVER_CARD_SCALE) + _timerHalfW;

            draw_sprite_ext(sHoverCardTimer, 0, _timerCenterX, _rowTopY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);

            var _timerTextY = _rowTopY + (sprite_get_height(sHoverCardTimer) * HOVER_CARD_SCALE) + (BUILDING_HOVER_ICON_LABEL_GAP_Y * HOVER_CARD_SCALE);
            DrawCardTextWithShadow(timerText, _timerCenterX, _timerTextY, _alpha);

            _cursorLeftEdge = _timerCenterX + _timerHalfW;
        }

        // Item/Unit window -- "on the other side of the card timer" from
        // the Building Window (ORIGINAL spec, item E), i.e. the RIGHTMOST
        // column.
        if (hasItemIcon) {
            var _itemHalfW   = (sprite_get_width(sHoverCardUnitWindow) / 2) * HOVER_CARD_SCALE;
            var _itemCenterX = _cursorLeftEdge + (BUILDING_HOVER_ICON_GAP_X * HOVER_CARD_SCALE) + _itemHalfW;
            var _itemCenterY = _rowTopY + (sprite_get_height(sHoverCardUnitWindow) / 2) * HOVER_CARD_SCALE;

            draw_sprite_ext(sHoverCardUnitWindow, 0, _itemCenterX, _itemCenterY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);
            // itemIconOffsetY re-centers a bottom-anchored unit smallSprite
            // within the window -- 0 for the middle-anchored resource icon
            // case, see Layout's comment on why.
            draw_sprite_ext(itemIconSprite, itemIconImage, _itemCenterX, _itemCenterY + itemIconOffsetY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);

            if (hasLimitText) {
                var _limitTextY = _rowTopY + (sprite_get_height(sHoverCardUnitWindow) * HOVER_CARD_SCALE) + (BUILDING_HOVER_ICON_LABEL_GAP_Y * HOVER_CARD_SCALE);
                DrawCardTextWithShadow(limitText, _itemCenterX, _limitTextY, _alpha);
            }
        }

        // Cost row -- blueprint hover only, along the bottom, below
        // whatever the card itself drew last (flavor window, or body text
        // if no flavor) -- 2026-07-08 request.
        if (showCostRow) {
            var _costX = _card.x + HOVER_CARD_BODY_MARGIN_X * HOVER_CARD_SCALE;
            var _costY = _card.GetContentBottomY() + BUILDING_HOVER_COST_ROW_GAP_TOP * HOVER_CARD_SCALE;
            DrawCardTextWithShadow(costText, _costX, _costY, _alpha);
        }

        // Queue row -- placed training buildings only, same bottom slot as
        // the cost row above (mutually exclusive, see file header).
        if (showQueueRow) {
            var _rowLeftX = _card.x + HOVER_CARD_BODY_MARGIN_X * HOVER_CARD_SCALE;
            var _rowTopY2 = _card.GetContentBottomY() + BUILDING_HOVER_COST_ROW_GAP_TOP * HOVER_CARD_SCALE;
            var _rowMidY  = _rowTopY2 + (queueRowHeight / 2);

            // Icon + count, bottom-left corner of the row.
            var _iconCenterX = _rowLeftX + (queueIconWidth / 2);
            if (queueIconSprite != undefined) {
                draw_sprite_ext(queueIconSprite, queueIconImage, _iconCenterX, _rowMidY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);
            }

            var _countX = _rowLeftX + queueIconWidth + BUILDING_HOVER_QUEUE_GAP_X;
            DrawCardTextWithShadow(queueCountText, _countX, _rowMidY, _alpha);

            // Progress bar -- black background, filled in HOVER_CARD_TEXT_COLOR,
            // per the request. Plain drawn rectangles, not a sprite/Scribble
            // element, same as DrawDragBox/other raw UI rects in this project.
            // 2026-07-11 follow-up: centered on the card's full width -- its
            // left edge sits _barX1 - _card.x in from the card's left edge,
            // and its right edge sits that SAME distance in from the card's
            // right edge (_card.x + HOVER_CARD_WIDTH*HOVER_CARD_SCALE),
            // mirroring the offset rather than sizing around the time text.
            var _barX1 = _countX + queueCountText.get_width() + BUILDING_HOVER_QUEUE_GAP_X;
            var _barLeftOffset = _barX1 - _card.x;
            var _barX2 = _card.x + (HOVER_CARD_WIDTH * HOVER_CARD_SCALE) - _barLeftOffset;
            if (_barX2 - _barX1 < BUILDING_HOVER_QUEUE_BAR_MIN_WIDTH) _barX2 = _barX1 + BUILDING_HOVER_QUEUE_BAR_MIN_WIDTH;
            var _barY1 = _rowMidY - (BUILDING_HOVER_QUEUE_BAR_HEIGHT * HOVER_CARD_SCALE / 2);
            var _barY2 = _rowMidY + (BUILDING_HOVER_QUEUE_BAR_HEIGHT * HOVER_CARD_SCALE / 2);

            draw_set_alpha(_alpha);
            draw_set_color(c_black);
            draw_rectangle(_barX1, _barY1, _barX2, _barY2, false);
            if (queueFraction > 0) {
                draw_set_color(HOVER_CARD_TEXT_COLOR);
                draw_rectangle(_barX1, _barY1, _barX1 + ((_barX2 - _barX1) * queueFraction), _barY2, false);
            }
            draw_set_alpha(1);

            // Time remaining -- now trails the bar's right edge (was pinned
            // to the row's fixed right edge, back when the bar's width was
            // sized around this text instead of mirrored/centered).
            var _timeX = _barX2 + BUILDING_HOVER_QUEUE_GAP_X;
            DrawCardTextWithShadow(queueTimeText, _timeX, _rowMidY, _alpha);
        }
    }
}

/// @function BuildingHoverSuppressed(_selectionController, _blueprintController)
/// @description True while the player is mid-action elsewhere and building
///        hover data should NOT trigger -- targeting, dragging a blueprint,
///        the mouse sitting over the Blueprint UI panel at all (see file
///        header on why this is needed -- GUI-space panel vs. room-space
///        building underneath it), or the Fate Engine overlay being open.
///        Same shape as PlotHoverSuppressed (PlotHoverScripts.gml).
/// @param {Struct.SelectionController} _selectionController
/// @param {Struct.BlueprintController} _blueprintController
/// @returns {Bool}
function BuildingHoverSuppressed(_selectionController, _blueprintController) {
    return _selectionController.isTargeting
        || _blueprintController.dragging
        || _blueprintController.IsMouseOverPanel()
        || global.fateEngineOverlayActive;
}

/// @function BuildingHoverController()
/// @description Owns one HoverCard + one BuildingHoverExtras and drives
///        them for placed building instances (oBuildingParent, any team --
///        this is informational only, not tied to who owns the building;
///        flag if hover data should be restricted to the player's own
///        buildings instead): the same 1-second dwell timer
///        (PLOT_HOVER_DELAY_STEPS) and fade (PLOT_HOVER_FADE_STEPS) as
///        plot hover, and the same cursor-relative quadrant anchoring.
///        Same "plain struct, owner calls Step()/Draw()" pattern as
///        PlotHoverController -- wire into oUnitControl alongside it.
function BuildingHoverController() constructor {
    card        = new HoverCard();
    extras      = new BuildingHoverExtras();
    hoverTarget = noone; // the oBuildingParent instance currently being dwelt on, or noone
    hoverTimer  = 0;     // real steps (NOT global.matchSpeed), same basis as PlotHoverController
    alpha       = 0;     // current fade level, 0-1

    // 2026-07-11 addition -- paired unit hover card (UnitHoverScripts.gml),
    // shown alongside this card whenever the hovered building trains a
    // unit. hasUnitCard gates both Draw() and whether PositionHoverCardPair
    // treats unitCard as a real secondary or not (noone -- see that
    // function's doc for why passing noone reproduces the original
    // single-card math exactly).
    unitCard    = new HoverCard();
    unitExtras  = new UnitHoverExtras();
    hasUnitCard = false;

    /// @function Step(_selectionController, _blueprintController)
    /// @description Call once per Step event. Same dwell/fade/positioning
    ///        structure as PlotHoverController.Step -- see that function's
    ///        doc comment (PlotHoverScripts.gml) for the general pattern.
    /// @param {Struct.SelectionController} _selectionController
    /// @param {Struct.BlueprintController} _blueprintController
    static Step = function(_selectionController, _blueprintController) {
        var _candidate = noone;
        if (!BuildingHoverSuppressed(_selectionController, _blueprintController)) {
            var _found = instance_position(mouse_x, mouse_y, oBuildingParent);
            if (_found != noone && GetBuildingDefinition(_found.object_index) != undefined) {
                _candidate = _found;
            }
        }

        if (_candidate != hoverTarget) {
            hoverTarget = _candidate;
            hoverTimer  = 0;
        } else if (_candidate != noone) {
            hoverTimer += 1;
        }

        var _shouldShow  = (hoverTarget != noone) && (hoverTimer >= PLOT_HOVER_DELAY_STEPS);
        var _targetAlpha = _shouldShow ? 1 : 0;
        var _fadeStep    = 1 / PLOT_HOVER_FADE_STEPS;
        alpha = (alpha < _targetAlpha)
            ? min(_targetAlpha, alpha + _fadeStep)
            : max(_targetAlpha, alpha - _fadeStep);

        if (_shouldShow) {
            var _def = GetBuildingDefinition(hoverTarget.object_index);

            var _sizes = extras.Layout(_def, hoverTarget, false, hoverTarget.team);
            card.Show(_def.name, BuildingHoverDescriptionText(_def), 0, 0, _def.description, _sizes.topContentHeight, _sizes.bottomContentHeight);

            // Paired unit card -- 2026-07-11 request, only for training
            // buildings. No live unit instance to read from (a training
            // building isn't tied to any one specific trained unit), so
            // _liveUnit is always noone here (max HP only). Cost row is now
            // ALWAYS shown (2026-07-11 follow-up) -- even though the
            // BUILDING is already placed, the unit's own training cost is
            // still directly relevant here: it's exactly what queuing
            // another one will spend (TrainingTryQueueUnit, TrainingScripts.gml)
            // -- see UnitHoverScripts.gml.
            hasUnitCard = (_def.trainsUnit != undefined);
            if (hasUnitCard) {
                var _unitDef = GetUnitDefinition(_def.trainsUnit);
                hasUnitCard = (_unitDef != undefined);
                if (hasUnitCard) {
                    ShowUnitHoverCard(unitCard, unitExtras, _unitDef, noone, true);
                }
            }

            var _mx = device_mouse_x_to_gui(0);
            var _my = device_mouse_y_to_gui(0);

            // 2026-07-11: anchoring is computed against BOTH cards together
            // (PositionHoverCardPair, HoverCardScripts.gml) when a unit card
            // is showing -- passing noone otherwise reproduces the original
            // single-card anchor/clamp math exactly. _secondaryAlwaysRight =
            // true (2026-07-11 follow-up): the unit card always sits on the
            // building card's right,