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
    _building.inside = _plot.inside; // lets training buildings check placement (see TrainingSpawnUnit, StationScripts.gml)

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
    // hover, this shows INSTANTLY (no dwell delay) -- 2026-07-09 request
    // ("remove the delay to show info") -- still fades in/out over
    // PLOT_HOVER_FADE_STEPS rather than popping, but there's no dwell timer
    // to gate it anymore (see UpdateHover below; the old hoverTimer field
    // this used for that gate has been removed entirely, it served no other
    // purpose).
    hoverCard       = new HoverCard();
    hoverExtras     = new BuildingHoverExtras();
    hoverStackIndex = -1; // index into global.blueprints[team] currently being dwelt on, or -1
    hoverAlpha      = 0;  // current fade level, 0-1

    // 2026-07-11 addition -- paired unit hover card (UnitHoverScripts.gml),
    // shown alongside hoverCard whenever the hovered blueprint trains a
    // unit, WITH a cost-to-produce row (unlike the placed-building context,
    // BuildingHoverController -- this building doesn't exist yet, so
    // showing what the trained unit costs to produce is actually useful
    // here). See BuildingHoverController's identical fields for the general
    // pattern this mirrors.
    unitHoverCard   = new HoverCard();
    unitHoverExtras = new UnitHoverExtras();
    hasUnitHoverCard = false;

    /// @function GetOrigin()
    /// @description Top-left corner of the panel -- fixed GUI position
    ///        (BLUEPRINT_UI_ORIGIN_X/Y), not derived from screen size.
    ///        Previously centered horizontally at the bottom of the GUI;
    ///        replaced with a fixed anchor per 2026-07-05 request.
    /// @returns {Struct.Vector2}
    static GetOrigin = function() {
        return new Vector2(BLUEPRINT_UI_ORIGIN_X, BLUEPRINT_UI_ORIGIN_Y);
    }

    /// @function GetSlotRect(_slotIndex)
    /// @description GUI-space rect for a slot, scaled by BLUEPRINT_UI_SCALE.
    ///        This is the single place slot size/padding get scaled, so
    ///        rendering (Draw) and interaction (TryBeginDrag) automatically
    ///        stay in sync -- a slot always occupies exactly the area it's
    ///        clickable in.
    /// @param {Real} _slotIndex 0..(BLUEPRINT_SLOTS_PER_PAGE - 1)
    /// @returns {Struct} { x1, y1, x2, y2 } GUI-space rect for that slot.
    static GetSlotRect = function(_slotIndex) {
        var _origin  = GetOrigin();
        var _col     = _slotIndex mod BLUEPRINT_GRID_COLS;
        var _row     = _slotIndex div BLUEPRINT_GRID_COLS;
        var _size    = BLUEPRINT_SLOT_SIZE * BLUEPRINT_UI_SCALE;
        var _padding = BLUEPRINT_SLOT_PADDING * BLUEPRINT_UI_SCALE;
        var _x1  = _origin.x + _padding + _col * (_size + _padding);
        var _y1  = _origin.y + _padding + _row * (_size + _padding);
        return { x1: _x1, y1: _y1, x2: _x1 + _size, y2: _y1 + _size };
    }

    /// @function GetStackIndexAtSlot(_slotIndex)
    /// @description Resolves a visible slot (on the current page) to an
    ///        index into global.blueprints[team], or -1 if that slot is
    ///        empty (past the end of the inventory).
    /// @param {Real} _slotIndex
    /// @returns {Real}
    static GetStackIndexAtSlot = function(_slotIndex) {
        var _stackIndex = (page * BLUEPRINT_SLOTS_PER_PAGE) + _slotIndex;
        return (_stackIndex < array_length(global.blueprints[team])) ? _stackIndex : -1;
    }

    /// @function TryBeginDrag()
    /// @description Call from a left-mouse-pressed check. Starts a drag if
    ///        the press landed on a filled slot.
    /// @returns {Bool} True if a drag was started -- callers should not
    ///        also start a competing drag (e.g. a unit-selection box) this
    ///        same frame.
    static TryBeginDrag = function() {
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        for (var i = 0; i < BLUEPRINT_SLOTS_PER_PAGE; i++) {
            var _stackIndex = GetStackIndexAtSlot(i);
            if (_stackIndex == -1) continue;

            var _rect = GetSlotRect(i);
            if (_mx >= _rect.x1 && _mx <= _rect.x2 && _my >= _rect.y1 && _my <= _rect.y2) {
                dragging       = true;
                dragStackIndex = _stackIndex;
                return true;
            }
        }
        return false;
    }

    /// @function CancelDrag()
    /// @description Cancels an in-progress drag without placing anything
    ///        (e.g. on right-click). The blueprint simply stays in the UI.
    static CancelDrag = function() {
        dragging       = false;
        dragStackIndex = -1;
    }

    /// @function EndDrag()
    /// @description Call from a left-mouse-released check while dragging
    ///        is true. Resolves the drop target from the cursor and hands
    ///        off to TryPlaceBlueprint (see that function's doc for the
    ///        actual placement/rejection logic) -- if it fails for any
    ///        reason, the blueprint simply stays in the UI, since it was
    ///        never removed from global.blueprints in the first place.
    static EndDrag = function() {
        if (!dragging) return;
        dragging = false;

        var _stacks = global.blueprints[team];
        if (dragStackIndex < 0 || dragStackIndex >= array_length(_stacks)) {
            dragStackIndex = -1;
            return;
        }

        var _buildingType = _stacks[dragStackIndex].buildingType;
        dragStackIndex = -1;

        var _plot = instance_position(mouse_x, mouse_y, oBuildingPlot);
        TryPlaceBlueprint(team, _buildingType, _plot);
    }

    /// @function IsMouseOverPanel()
    /// @description True while the mouse (GUI-space) sits anywhere within
    ///        the panel's full grid bounding rect -- not just over a FILLED
    ///        slot, unlike TryBeginDrag/GetHoveredStackIndex. Used by
    ///        PlotHoverSuppressed (PlotHoverScripts.gml) and
    ///        BuildingHoverSuppressed (BuildingHoverScripts.gml) to keep
    ///        plot/building world-space hover data from showing underneath
    ///        this GUI-space panel -- see BuildingHoverScripts.gml's file
    ///        header for why that conflict exists at all.
    /// @returns {Bool}
    static IsMouseOverPanel = function() {
        var _origin  = GetOrigin();
        var _size    = BLUEPRINT_SLOT_SIZE * BLUEPRINT_UI_SCALE;
        var _padding = BLUEPRINT_SLOT_PADDING * BLUEPRINT_UI_SCALE;
        var _width   = BLUEPRINT_GRID_COLS * (_size + _padding) + _padding;
        var _height  = BLUEPRINT_GRID_ROWS * (_size + _padding) + _padding;

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        return _mx >= _origin.x && _mx <= _origin.x + _width && _my >= _origin.y && _my <= _origin.y + _height;
    }

    /// @function GetHoveredStackIndex()
    /// @description Resolves the mouse's current GUI position to a FILLED
    ///        slot's stack index (into global.blueprints[team]), or -1 if
    ///        the mouse isn't over a filled slot. Same hit-test as
    ///        TryBeginDrag, but non-mutating (safe to call every Step just
    ///        to check, not only on a mouse press).
    /// @returns {Real}
    static GetHoveredStackIndex = function() {
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        for (var i = 0; i < BLUEPRINT_SLOTS_PER_PAGE; i++) {
            var _stackIndex = GetStackIndexAtSlot(i);
            if (_stackIndex == -1) continue;

            var _rect = GetSlotRect(i);
            if (_mx >= _rect.x1 && _mx <= _rect.x2 && _my >= _rect.y1 && _my <= _rect.y2) {
                return _stackIndex;
            }
        }
        return -1;
    }

    /// @function UpdateHover()
    /// @description Call once per Step event. Shows INSTANTLY the moment the
    ///        mouse sits over a filled slot -- no dwell delay, unlike plot/
    ///        building hover (2026-07-09 request) -- but still fades in/out
    ///        over PLOT_HOVER_FADE_STEPS rather than popping. Suppressed
    ///        entirely while dragging (showing a tooltip for the slot you're
    ///        mid-drag from would be noisy and it's already following the
    ///        cursor as a dragged icon).
    static UpdateHover = function() {
        hoverStackIndex = dragging ? -1 : GetHoveredStackIndex();

        var _shouldShow  = (hoverStackIndex != -1);
        var _targetAlpha = _shouldShow ? 1 : 0;
        var _fadeStep    = 1 / PLOT_HOVER_FADE_STEPS;
        hoverAlpha = (hoverAlpha < _targetAlpha)
            ? min(_targetAlpha, hoverAlpha + _fadeStep)
            : max(_targetAlpha, hoverAlpha - _fadeStep);

        if (_shouldShow) {
            var _stack = global.blueprints[team][hoverStackIndex];
            var _def   = GetBuildingDefinition(_stack.buildingType);
            if (_def == undefined) return;

            // Can this building be placed ANYWHERE right now, at all --
            // 2026-07-09 request. GetBestAvailablePlacementCost scans this
            // team's currently open (unblocked, unoccupied) plots and
            // returns the cheapest cost achievable among them; "placeable
            // anywhere" requires BOTH that at least one such plot exists AND
            // that its cost is actually affordable. If not, the card's
            // title (the building's own name) renders in red instead of the
            // default color -- reusing the same PLOT_HOVER_BAD_COLOR_TAG
            // Scribble color tag PlotHoverBonusText uses (PlotHoverScripts.gml).
            var _best            = GetBestAvailablePlacementCost(team, _def);
            var _canPlaceAnywhere = _best.anyPlotAvailable && _best.cost.CanAfford(team);
            var _titleText = _canPlaceAnywhere ? _def.name : $"[{PLOT_HOVER_BAD_COLOR_TAG}]{_def.name}[/c]";

            // _isBlueprint = true -- flat resource limit (not "remaining/
            // total") and the cost row along the bottom, per 2026-07-08
            // request -- see BuildingHoverScripts.gml. The cost row itself
            // independently re-derives the same best-available cost (via
            // GetBestAvailablePlacementCost inside Layout) for its own
            // per-resource red/default coloring.
            var _sizes = hoverExtras.Layout(_def, noone, true, team);
            hoverCard.Show(_titleText, BuildingHoverDescriptionText(_def), 0, 0, _def.description, _sizes.topContentHeight, _sizes.bottomContentHeight);

            // Paired unit card -- 2026-07-11 request, only for training
            // buildings. No live unit instance (nothing's been trained
            // yet), WITH the cost-to-produce row (showCostRow = true) --
            // see UnitHoverScripts.gml and this struct's field comments.
            hasUnitHoverCard = (_def.trainsUnit != undefined);
            if (hasUnitHoverCard) {
                var _unitDef = GetUnitDefinition(_def.trainsUnit);
                hasUnitHoverCard = (_unitDef != undefined);
                if (hasUnitHoverCard) {
                    ShowUnitHoverCard(unitHoverCard, unitHoverExtras, _unitDef, noone, true);
                }
            }

            var _mx = device_mouse_x_to_gui(0);
            var _my = device_mouse_y_to_gui(0);

            // 2026-07-11: anchoring computed against both cards together
            // when a unit card is showing -- see PositionHoverCardPair
            // (HoverCardScripts.gml).
            PositionHoverCardPair(_mx, _my, hoverCard, hasUnitHoverCard ? unitHoverCard : noone);
        }
    }

    /// @function DrawHoverCard()
    /// @description Call once per Draw GUI event, separately from Draw()
    ///        (the panel itself) so the caller can order it after every
    ///        other HUD element -- see oUnitControl/Draw_64.gml. No-ops
    ///        while fully faded out.
    static DrawHoverCard = function() {
        if (hoverAlpha <= 0) return;
        hoverCard.Draw(hoverAlpha);
        hoverExtras.Draw(hoverCard, hoverAlpha);

        if (hasUnitHoverCard) {
            unitHoverCard.Draw(hoverAlpha);
            unitHoverExtras.Draw(unitHoverCard, hoverAlpha);
        }
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event. Renders every slot
    ///        (empty ones as bordered squares) and the dragged icon
    ///        following the cursor, if a drag is in progress.
    static Draw = function() {
        for (var i = 0; i < BLUEPRINT_SLOTS_PER_PAGE; i++) {
            var _rect = GetSlotRect(i);

            draw_rectangle_color(_rect.x1, _rect.y1, _rect.x2, _rect.y2, c_black, c_black, c_black, c_black, false);
            draw_rectangle_color(_rect.x1, _rect.y1, _rect.x2, _rect.y2, c_white, c_white, c_white, c_white, true);

            var _stackIndex = GetStackIndexAtSlot(i);
            // Empty slot, or its icon is following the cursor instead.
            if (_stackIndex == -1 || _stackIndex == dragStackIndex) continue;

            var _stack = global.blueprints[team][_stackIndex];
            var _def   = GetBuildingDefinition(_stack.buildingType);
            if (_def == undefined) continue;

            draw_sprite_ext(_def.sprite, 0, (_rect.x1 + _rect.x2) / 2, (_rect.y1 + _rect.y2) / 2, BLUEPRINT_UI_SCALE, BLUEPRINT_UI_SCALE, 0, c_white, 1);

            if (_stack.count > 1) {
                draw_set_halign(fa_right);
                draw_set_valign(fa_bottom);
                // 2026-07-11 request: matches HOVER_CARD_TEXT_COLOR
                // (HoverCardScripts.gml) -- was c_white.
                draw_set_color(HOVER_CARD_TEXT_COLOR);
                draw_text(_rect.x2 - 2, _rect.y2 - 2, string(_stack.count));
            }
        }

        if (dragging) {
            var _stacks = global.blueprints[team];
            if (dragStackIndex >= 0 && dragStackIndex < array_length(_stacks)) {
                var _def = GetBuildingDefinition(_stacks[dragStackIndex].buildingType);
                if (_def != undefined) {
                    draw_sprite_ext(_def.sprite, 0, device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), BLUEPRINT_UI_SCALE, BLUEPRINT_UI_SCALE, 0, c_white, 1);
                }
            }
        }
    }
}
