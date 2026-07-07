// -----------------------------------------------------------
// Blueprint -- a team's placeable-building inventory. Each team owns an
// array of BlueprintStack entries (global.blueprints[team]); a stack is
// one building type + how many of it are currently available to place.
// Stacks are removed entirely once exhausted (see RemoveBlueprintOne), and
// the Blueprint UI grid (BlueprintController below) renders stacks
// directly into slots in array order -- so an exhausted stack's slot is
// simply taken over by whatever stack comes after it, same as any other
// "remove from a list" operation. No compaction step needed elsewhere.
//
// global.blueprints itself is initialized in oMatchControl/Create_0.gml,
// alongside global.resources -- see that file for why it's built as
// `[[], []]` rather than `array_create(2, [])` (same shared-reference
// hazard as the resources array had; each `[]` here is its own literal,
// evaluated fresh, so it's safe).
// -----------------------------------------------------------

/// @function BlueprintStack(_buildingType, _count)
/// @param {Asset.GMObject} _buildingType Object index of the building this
///        stack places, e.g. oWheatField -- keys into the
///        BuildingDefinition registry (see BuildingDefinitions.gml).
/// @param {Real} _count How many of this building can currently be placed.
function BlueprintStack(_buildingType, _count) constructor {
    buildingType = _buildingType;
    count        = _count;
}

/// @function AddBlueprint(_team, _buildingType, _count)
/// @description Adds blueprints to a team's inventory -- stacks onto an
///        existing entry of the same building type if one exists,
///        otherwise appends a new stack.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Asset.GMObject} _buildingType
/// @param {Real} [_count]
function AddBlueprint(_team, _buildingType, _count = 1) {
    var _stacks = global.blueprints[_team];
    for (var i = 0; i < array_length(_stacks); i++) {
        if (_stacks[i].buildingType == _buildingType) {
            _stacks[i].count += _count;
            return;
        }
    }
    array_push(_stacks, new BlueprintStack(_buildingType, _count));
}

/// @function RemoveBlueprintOne(_team, _buildingType)
/// @description Consumes one blueprint of the given type -- decrements its
///        stack, removing the stack entirely once it hits 0 (so the next
///        stack shifts into its slot when the UI grid re-renders).
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Asset.GMObject} _buildingType
/// @returns {Bool} True if a blueprint was found and consumed.
function RemoveBlueprintOne(_team, _buildingType) {
    var _stacks = global.blueprints[_team];
    for (var i = 0; i < array_length(_stacks); i++) {
        if (_stacks[i].buildingType == _buildingType) {
            _stacks[i].count -= 1;
            if (_stacks[i].count <= 0) {
                array_delete(_stacks, i, 1);
            }
            return true;
        }
    }
    return false;
}

#macro PLOT_BONUS_DISCOUNT_FRACTION 0.5 // 50% off placement cost -- 2026-07-07 "plot bonuses" request, see GetPlacementCost below
#macro BLUEPRINT_DISCOUNT_UNAVAILABLE_COLOR_TAG "c_dkgray" // 2026-07-09 request: the blueprint cost row's parenthesized discount price renders in this color whenever no currently open plot would actually grant the discount -- see CostToScribbleTextWithDiscount (ResourceUIScripts.gml)

/// @function GetPlacementCost(_def, _plot)
/// @description The actual Cost to charge for placing _def's building type
///        on _plot, after plot-based placement discounts (2026-07-07 "plot
///        bonuses" request, realizing the split oOuterPlotSpawner's header
///        comment already described as intended: "Resource buildings get a
///        placement bonus OUTSIDE the castle; unit-training buildings get
///        theirs INSIDE"):
///          - Resource buildings (_def.productionResource set) placed
///            OUTSIDE the castle (_plot.inside == false -- covers BOTH
///            Exterior and Distant/"far" plots) cost
///            PLOT_BONUS_DISCOUNT_FRACTION (50%) less.
///          - Training buildings (_def.trainsUnit set) placed on a CASTLE
///            plot (_plot.inside == true) cost the same 50% less.
///        A building is either a resource building or a training building
///        in every BuildingDefinition registered today (never both), and a
///        plot can't be both inside and !inside, so at most one discount
///        ever applies -- no stacking logic needed. If neither condition is
///        met, returns _def.cost UNCHANGED (the same instance, not a copy --
///        CanAfford/Purchase only read it, never mutate it).
///
///        Distant plots ALSO grant a stat bonus (maxHealth, and resourceLimit
///        for production buildings) on top of whichever discount applies
///        here -- that's handled separately by ApplyPlotBonuses
///        (BuildingDefinitions.gml), applied to the building AFTER it's
///        created, since it affects stats rather than cost.
/// @param {Struct.BuildingDefinition} _def
/// @param {Id.Instance} _plot An oBuildingPlot instance.
/// @returns {Struct.Cost}
function GetPlacementCost(_def, _plot) {
    return BuildingGetsDiscountOnPlot(_def, _plot) ? GetDiscountedCost(_def.cost, PLOT_BONUS_DISCOUNT_FRACTION) : _def.cost;
}

/// @function BuildingGetsDiscountOnPlot(_def, _plot)
/// @description The actual discount-eligibility rule GetPlacementCost
///        applies, factored out (2026-07-09) so GetBestAvailablePlacementCost
///        below can reuse the exact same condition instead of re-deriving it
///        and risking drift between the two.
/// @param {Struct.BuildingDefinition} _def
/// @param {Id.Instance} _plot An oBuildingPlot instance.
/// @returns {Bool}
function BuildingGetsDiscountOnPlot(_def, _plot) {
    var _isResourceBuilding = _def.productionResource != undefined;
    var _isTrainingBuilding = _def.trainsUnit != undefined;
    return (_isResourceBuilding && !_plot.inside) || (_isTrainingBuilding && _plot.inside);
}

/// @function GetBestAvailablePlacementCost(_team, _def)
/// @description Scans every oBuildingPlot _team owns that's currently
///        PLACEABLE (not blocked, not occupied) and returns the cheapest
///        cost _def's building type could actually be placed for right now,
///        plus whether any such plot exists at all -- 2026-07-09 request
///        ("can't afford the blueprint anywhere, including any plots that
///        would give it a discount"). Since GetPlacementCost's discount is a
///        binary per-building-type/plot-side switch, never a partial or
///        blended amount (see BuildingGetsDiscountOnPlot), "cheapest
///        available" collapses to just: the discounted cost if AT LEAST ONE
///        available plot would grant it, otherwise the full base cost, as
///        long as at least one available plot exists of any kind at all.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Struct.BuildingDefinition} _def
/// @returns {Struct} { anyPlotAvailable: Bool, discountAvailable: Bool, cost: Struct.Cost }
///        discountAvailable (2026-07-09 addition) -- whether at least one
///        currently open plot would actually grant _def's discount, exposed
///        separately from `cost` so callers that need to show BOTH the base
///        and discounted price side by side (see CostToScribbleTextWithDiscount,
///        ResourceUIScripts.gml) don't have to re-scan plots themselves.
function GetBestAvailablePlacementCost(_team, _def) {
    var _anyPlotAvailable            = false;
    var _discountEligiblePlotAvailable = false;

    with (oBuildingPlot) {
        if (team == _team && !blocked && !occupied) {
            _anyPlotAvailable = true;
            if (BuildingGetsDiscountOnPlot(_def, self)) _discountEligiblePlotAvailable = true;
        }
    }

    var _cost = _discountEligiblePlotAvailable ? GetDiscountedCost(_def.cost, PLOT_BONUS_DISCOUNT_FRACTION) : _def.cost;
    return { anyPlotAvailable: _anyPlotAvailable, discountAvailable: _discountEligiblePlotAvailable, cost: _cost };
}

/// @function TryPlaceBlueprint(_team, _buildingType, _plot)
/// @description Resolves an attempt to place _buildingType at _plot for
///        _team: valid target is an owned oBuildingPlot that's neither
///        blocked (a meta-progression-locked slot -- see
///        oPlotSpawner/Create_0.gml, unrelated to whether anything's built
///        there) nor already occupied (a building is currently standing on
///        it); if valid and affordable (at _plot's discounted cost -- see
///        GetPlacementCost), purchases that cost, spawns the building,
///        applies _plot's Distant-plot stat bonus if any (see
///        ApplyPlotBonuses, BuildingDefinitions.gml), marks the plot
///        occupied, consumes one blueprint, and records it to analytics.
///        Every rejection is logged via show_debug_message and simply
///        returns false -- caller decides what "stays in the UI" / "try
///        again later" means for it.
///
///        Extracted from BlueprintController.EndDrag so both the
///        player's mouse-drag flow AND a programmatic caller (the AI --
///        see AI_TryPlaceBlueprints in AIControl.gml) can place buildings
///        through identical cost/analytics/plot-occupancy handling. EndDrag
///        now just resolves _plot from the cursor and calls this.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Asset.GMObject} _buildingType
/// @param {Id.Instance|Constant.NoOne} _plot Target oBuildingPlot, or
///        noone (e.g. nothing under the cursor) -- handled as a normal
///        rejection, not a crash.
/// @returns {Bool} True if the building was placed.
function TryPlaceBlueprint(_team, _buildingType, _plot) {
    if (_plot == noone || _plot.team != _team || _plot.blocked || _plot.occupied) {
        show_debug_message($"TryPlaceBlueprint: no valid owned/empty plot for {object_get_name(_buildingType)} (team {_team}).");
        return false;
    }

    var _def = GetBuildingDefinition(_buildingType);
    if (_def == undefined) {
        show_debug_message($"TryPlaceBlueprint: no BuildingDefinition registered for {object_get_name(_buildingType)}.");
        return false;
    }

    var _cost = GetPlacementCost(_def, _plot);
    if (!_cost.CanAfford(_team)) {
        show_debug_message($"TryPlaceBlueprint: team {_team} can't afford {_def.name}.");
        return false;
    }

    Purchase(_cost, _team);

    var _building = instance_create_layer(_plot.x, _plot.y, "Instances", _buildingType);
    _building.team = _team; // overrides oBuildingParent's Create-time TEAM.PLAYER default -- see that file

    ApplyPlotBonuses(_building, _plot); // Distant-plot maxHealth/resourceLimit bonus, if any -- see BuildingDefinitions.gml

    _plot.occupied = true;

    RemoveBlueprintOne(_team, _buildingType);

    AnalyticsRecordBuildingBuilt(_team, _buildingType);

    return true;
}

// -----------------------------------------------------------
// BlueprintController -- the Blueprint UI panel: a paginated 5x2 grid of
// 48x48 slots (rendered/interacted at BLUEPRINT_UI_SCALE, see below),
// anchored top-left at a fixed GUI position. Drag a filled slot onto a
// plot the dragging team owns to place that building, if it's affordable.
//
// One instance per player-facing controller (currently created by
// oUnitControl, mirroring how it owns selectionController/orderMenu). An
// AI-driven controller could use its own instance the same way
// SelectionController already supports TEAM.ENEMY.
//
// Pagination: GetStackIndexAtSlot()/GetSlotRect() already key off `page`,
// so a second page works the moment inventory exceeds
// BLUEPRINT_SLOTS_PER_PAGE -- but there's no next/prev page button wired
// up yet, since nothing can exceed one page right now (only one building
// type exists). Add page-nav input once that's actually needed.
// -----------------------------------------------------------

#macro BLUEPRINT_SLOT_SIZE      48
#macro BLUEPRINT_SLOT_PADDING   1
#macro BLUEPRINT_GRID_COLS      5
#macro BLUEPRINT_GRID_ROWS      2
#macro BLUEPRINT_SLOTS_PER_PAGE 10 // BLUEPRINT_GRID_COLS * BLUEPRINT_GRID_ROWS
#macro BLUEPRINT_UI_SCALE       2  // panel render/interact scale -- 2026-07-05 request; slot size/padding/icon draws all scale off this, single source of truth
#macro BLUEPRINT_UI_ORIGIN_X    660 // fixed top-left anchor (2026-07-05 request) -- replaced the old bottom-centered GetOrigin()
#macro BLUEPRINT_UI_ORIGIN_Y    830

/// @function BlueprintController(_team)
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY -- whose blueprint
///        inventory (global.blueprints[_team]) this controller shows/drags.
function BlueprintController(_team) constructor {
    team           = _team;
    page           = 0;
    dragging       = false;
    dragStackIndex = -1; // index into global.blueprints[team], set while dragging

    // Slot hover tooltip -- 2026-07-08 request ("slightly tweaking the
    // normal blueprint hover data"). Same HoverCard+BuildingHoverExtras pair
    // BuildingHoverController uses for placed buildings (BuildingHoverScripts.gml)
    // -- see that file for why the two hover contexts share their drawing
    // logic and differ only via the _isBlueprint flag. UNLIKE plot/building
    // hover, this shows INSTANTLY (no dwell delay) -- 2026-07-09 req