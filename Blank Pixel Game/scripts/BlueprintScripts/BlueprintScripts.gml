// A team's placeable-building inventory, placement-cost/discount rules, and
// the BlueprintController drag-to-place UI panel. See BlueprintScripts.md.

/// @function BlueprintStack(_buildingType, _count)
/// @param {Asset.GMObject} _buildingType Object index of the building this stack places.
/// @param {Real} _count How many of this building can currently be placed.
function BlueprintStack(_buildingType, _count) constructor {
    buildingType = _buildingType;
    count        = _count;
}

/// @function AddBlueprint(_team, _buildingType, _count)
/// @description Stacks onto an existing entry of the same building type if one exists, otherwise appends a new stack.
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
/// @description Decrements a stack, removing it entirely once it hits 0.
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

#macro PLOT_BONUS_DISCOUNT_FRACTION 0.5 // see BlueprintScripts.md
#macro BLUEPRINT_DISCOUNT_UNAVAILABLE_COLOR_TAG "c_dkgray"
#macro BLUEPRINT_AFFORDABLE_BORDER_COLOR   c_white
#macro BLUEPRINT_UNAFFORDABLE_BORDER_COLOR c_dkgray

/// @function GetPlacementCost(_def, _plot)
/// @description The Cost to charge for placing _def's building type on _plot, after any plot-based discount. See BlueprintScripts.md.
/// @param {Struct.BuildingDefinition} _def
/// @param {Id.Instance} _plot An oBuildingPlot instance.
/// @returns {Struct.Cost}
function GetPlacementCost(_def, _plot) {
    return BuildingGetsDiscountOnPlot(_def, _plot) ? GetDiscountedCost(_def.cost, PLOT_BONUS_DISCOUNT_FRACTION) : _def.cost;
}

/// @function BuildingGetsDiscountOnPlot(_def, _plot)
/// @description The discount-eligibility rule GetPlacementCost applies, factored out for reuse. See BlueprintScripts.md.
/// @param {Struct.BuildingDefinition} _def
/// @param {Id.Instance} _plot An oBuildingPlot instance.
/// @returns {Bool}
function BuildingGetsDiscountOnPlot(_def, _plot) {
    var _isResourceBuilding = _def.productionResource != undefined;
    var _isTrainingBuilding = _def.trainsUnit != undefined;
    return (_isResourceBuilding && !_plot.inside) || (_isTrainingBuilding && _plot.inside);
}

/// @function GetBestAvailablePlacementCost(_team, _def)
/// @description Cheapest cost _def's building type could be placed for right now among _team's currently placeable plots. See BlueprintScripts.md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Struct.BuildingDefinition} _def
/// @returns {Struct} { anyPlotAvailable: Bool, discountAvailable: Bool, cost: Struct.Cost }
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
/// @description Resolves a placement attempt: validates the plot, checks affordability, purchases, spawns the building, and consumes the blueprint. See BlueprintScripts.md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Asset.GMObject} _buildingType
/// @param {Id.Instance|Constant.NoOne} _plot Target oBuildingPlot, or noone.
/// @returns {Bool} True if the building was placed.
function TryPlaceBlueprint(_team, _buildingType, _plot) {
    // Guided-tutorial restriction (2026-08-13, extended twice same day: a LIST of allowed types -- the
    // "3 W's" phase permits Wheat Field and Sawmill -- and a per-phase plot SIDE via requireInside, since
    // the Peasant Ward phase needs INSIDE the walls, opposite every earlier phase) -- only checked for the
    // player, and only while global.tutorialGuide has one active. See TutorialGuideScripts.md.
    var _tutorialGated = (_team == TEAM.PLAYER && global.tutorialGuide.restrictionActive);
    if (_tutorialGated) {
        // _plot != noone MUST short-circuit before touching _plot.inside below -- noone has no
        // .inside to read, so evaluating that first (even inside a ternary) would error on a bad plot.
        var _plotOk = (_plot != noone) && (global.tutorialGuide.requireInside ? _plot.inside : !_plot.inside);
        if (!array_contains(global.tutorialGuide.allowedBuildingTypes, _buildingType) || !_plotOk) {
            show_debug_message($"TryPlaceBlueprint: blocked by guided-tutorial restriction ({object_get_name(_buildingType)}).");
            return false;
        }
    }

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
    _building.team = _team; // overrides oBuildingParent's Create-time TEAM.PLAYER default
    _building.inside = _plot.inside; // lets training buildings check placement (see TrainingSpawnUnit, StationScripts.gml)

    ApplyPlotBonuses(_building, _plot); // Distant-plot maxHealth/resourceLimit bonus, if any -- see BuildingDefinitions.gml

    _plot.occupied = true;

    RemoveBlueprintOne(_team, _buildingType);

    AnalyticsRecordBuildingBuilt(_team, _buildingType);

    if (_tutorialGated) global.tutorialGuide.CompleteRestriction(_buildingType); // checks this type off the phase's remaining requirements -- see TutorialGuideScripts.md

    return true;
}

// BlueprintController -- the Blueprint UI panel: a paginated 5x2 grid of
// slots. Drag a filled slot onto an owned plot to place that building.
// See BlueprintScripts.md.

#macro BLUEPRINT_SLOT_SIZE      48
#macro BLUEPRINT_SLOT_PADDING   4
#macro BLUEPRINT_GRID_COLS      5
#macro BLUEPRINT_GRID_ROWS      2
#macro BLUEPRINT_SLOTS_PER_PAGE 10 // BLUEPRINT_GRID_COLS * BLUEPRINT_GRID_ROWS
#macro BLUEPRINT_UI_SCALE       2  // panel render/interact scale -- single source of truth
#macro BLUEPRINT_UI_ORIGIN_X    648 // fixed top-left anchor
#macro BLUEPRINT_UI_ORIGIN_Y    824

#macro BLUEPRINT_PAGE_ARROW_GAP    4  // native px gap between the grid and each arrow

// Carried-blueprint visuals -- see BlueprintScripts.md ("Carry animation").
#macro BLUEPRINT_CARRY_ANCHOR_FRACTION 0.25 // fraction down the sprite (from its top) that sits under the cursor
#macro BLUEPRINT_CARRY_GRAB_STEPS      10   // slot -> cursor
#macro BLUEPRINT_CARRY_PLACE_STEPS     14   // cursor -> plot
#macro BLUEPRINT_CARRY_RETURN_STEPS    8    // cursor -> slot (failed/cancelled), deliberately quick
#macro BLUEPRINT_CARRY_SWING_PER_PX    1.5  // target degrees of swing per GUI px of horizontal mouse movement this step
#macro BLUEPRINT_CARRY_SWING_MAX       35   // degrees
#macro BLUEPRINT_CARRY_SWING_STIFFNESS 0.15 // spring pull toward the target angle
#macro BLUEPRINT_CARRY_SWING_DAMPING   0.8  // velocity retained per step
#macro BLUEPRINT_DUST_COLOR_A          make_color_rgb(0x9F, 0x81, 0x55)
#macro BLUEPRINT_DUST_COLOR_B          make_color_rgb(0xAE, 0x8C, 0x5B)
#macro BLUEPRINT_DUST_COLOR_C          make_color_rgb(0x8E, 0x6D, 0x47)
#macro BLUEPRINT_DUST_COUNT            22
#macro BLUEPRINT_DUST_SPEED_MIN        0.8  // world px per step
#macro BLUEPRINT_DUST_SPEED_MAX        2.6
#macro BLUEPRINT_DUST_FRICTION         0.92
#macro BLUEPRINT_DUST_LIFE_MIN         20   // steps
#macro BLUEPRINT_DUST_LIFE_MAX         36
#macro BLUEPRINT_DUST_SIZE_MIN         1.5  // world px
#macro BLUEPRINT_DUST_SIZE_MAX         3
#macro BLUEPRINT_DUST_VERTICAL_SQUASH  0.6  // flattens the burst toward the ground plane

// Settings-driven dwell delay before the hover card shows. Reads
// global.gameSettings.hoverDelayBottomBar fresh every reference (same
// "#macro as dynamic expression" trick PLOT_HOVER_DELAY_STEPS uses,
// PlotHoverScripts.gml) -- see BlueprintScripts.md for history.
#macro BLUEPRINT_HOVER_DELAY_STEPS (global.gameSettings.hoverDelayBottomBar * 60)

/// @function BlueprintController(_team)
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY -- whose blueprint inventory this controller shows/drags.
function BlueprintController(_team) constructor {
    team           = _team;
    page           = 0;
    dragging       = false;
    dragStackIndex = -1; // index into global.blueprints[team], set while dragging
    carry          = undefined; // visual state of the carried blueprint (outlives `dragging` through the place/return animation) -- see UpdateCarry
    dustParticles  = [];        // world-space placement impact particles

    hoverCard       = new HoverCard();
    hoverExtras     = new BuildingHoverExtras();
    hoverStackIndex = -1; // index into global.blueprints[team] currently being dwelt on, or -1
    hoverTimer      = 0;  // real steps (NOT global.matchSpeed), same basis as BLUEPRINT_HOVER_DELAY_STEPS
    hoverAlpha      = 0;  // current fade level, 0-1

    // Paired unit hover card (UnitHoverScripts.gml), shown alongside
    // hoverCard when the hovered blueprint trains a unit -- see BlueprintScripts.md.
    unitHoverCard   = new HoverCard();
    unitHoverExtras = new UnitHoverExtras();
    hasUnitHoverCard = false;

    /// @function GetOrigin()
    /// @description Top-left corner of the panel -- fixed GUI position.
    /// @returns {Struct.Vector2}
    static GetOrigin = function() {
        return new Vector2(BLUEPRINT_UI_ORIGIN_X, BLUEPRINT_UI_ORIGIN_Y);
    }

    /// @function GetSlotRect(_slotIndex)
    /// @description GUI-space rect for a slot, scaled by BLUEPRINT_UI_SCALE.
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
    /// @description Resolves a visible slot (on the current page) to an index into global.blueprints[team], or -1 if empty.
    /// @param {Real} _slotIndex
    /// @returns {Real}
    static GetStackIndexAtSlot = function(_slotIndex) {
        var _stackIndex = (page * BLUEPRINT_SLOTS_PER_PAGE) + _slotIndex;
        return (_stackIndex < array_length(global.blueprints[team])) ? _stackIndex : -1;
    }

    /// @function GetPageCount()
    /// @description How many pages this team's inventory spans -- always at least 1.
    /// @returns {Real}
    static GetPageCount = function() {
        return max(1, ceil(array_length(global.blueprints[team]) / BLUEPRINT_SLOTS_PER_PAGE));
    }

    /// @function ClampPage()
    /// @description Snaps `page` back into [0, GetPageCount() - 1]. See BlueprintScripts.md.
    /// @returns {Struct.BlueprintController} self
    static ClampPage = function() {
        page = clamp(page, 0, GetPageCount() - 1);
        return self;
    }

    /// @function NextPage()
    /// @description Advances to the next page, if one exists.
    /// @returns {Struct.BlueprintController} self
    static NextPage = function() {
        if (page < GetPageCount() - 1) page += 1;
        return self;
    }

    /// @function PrevPage()
    /// @description Goes back to the previous page, if one exists.
    /// @returns {Struct.BlueprintController} self
    static PrevPage = function() {
        if (page > 0) page -= 1;
        return self;
    }

    /// @function GetPageArrowRects()
    /// @description GUI-space rects for the prev/next page arrows, flanking the grid.
    /// @returns {Struct} { prev, next }, each { x1, y1, x2, y2 }.
    static GetPageArrowRects = function() {
        var _origin      = GetOrigin();
        var _size        = BLUEPRINT_SLOT_SIZE * BLUEPRINT_UI_SCALE;
        var _padding     = BLUEPRINT_SLOT_PADDING * BLUEPRINT_UI_SCALE;
        var _panelWidth  = BLUEPRINT_GRID_COLS * (_size + _padding) + _padding;
        var _panelHeight = BLUEPRINT_GRID_ROWS * (_size + _padding) + _padding;
        var _gap         = BLUEPRINT_PAGE_ARROW_GAP * BLUEPRINT_UI_SCALE;
        var _arrowW      = sprite_get_width(sLeftArrow) * BLUEPRINT_UI_SCALE;
        var _arrowH      = sprite_get_height(sLeftArrow) * BLUEPRINT_UI_SCALE;
        var _top         = _origin.y + (_panelHeight - _arrowH) / 2; // vertically centered on the panel

        // each arrow's edge opposite its pointing direction sits _gap from the panel's matching side
        var _prev = {
            x1: _origin.x - _gap - _arrowW, y1: _top,
            x2: _origin.x - _gap,           y2: _top + _arrowH
        };
        var _next = {
            x1: _origin.x + _panelWidth + _gap,           y1: _top,
            x2: _origin.x + _panelWidth + _gap + _arrowW, y2: _top + _arrowH
        };
        return { prev: _prev, next: _next };
    }

    /// @function UpdatePaging()
    /// @description Call once per Step. Handles arrow clicks and scroll-wheel paging over the panel.
    /// @returns {Bool} True if a click was consumed by an arrow this frame -- treat like consumedClick.
    static UpdatePaging = function() {
        ClampPage();

        var _mx    = device_mouse_x_to_gui(0);
        var _my    = device_mouse_y_to_gui(0);
        var _rects = GetPageArrowRects();

        var _onPrev = (_mx >= _rects.prev.x1 && _mx <= _rects.prev.x2 && _my >= _rects.prev.y1 && _my <= _rects.prev.y2);
        var _onNext = (_mx >= _rects.next.x1 && _mx <= _rects.next.x2 && _my >= _rects.next.y1 && _my <= _rects.next.y2);

        var _clickedArrow = false;
        if (mouse_check_button_pressed(mb_left)) {
            if (_onPrev && page > 0) {
                PrevPage();
                _clickedArrow = true;
            } else if (_onNext && page < GetPageCount() - 1) {
                NextPage();
                _clickedArrow = true;
            }
        }

        // IsMouseOverPanel() already covers both arrows -- no need to re-check _onPrev/_onNext here.
        if (IsMouseOverPanel()) {
            if (mouse_wheel_up())   PrevPage();
            if (mouse_wheel_down()) NextPage();
        }

        return _clickedArrow;
    }

    /// @function TryBeginDrag()
    /// @description Call from a left-mouse-pressed check. Starts a drag if the press landed on a filled slot.
    /// @returns {Bool} True if a drag was started.
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
                _BeginCarry(_stackIndex, (_rect.x1 + _rect.x2) / 2, (_rect.y1 + _rect.y2) / 2);
                return true;
            }
        }
        return false;
    }

    /// @function CancelDrag()
    /// @description Cancels an in-progress drag without placing anything. The blueprint stays in the UI.
    static CancelDrag = function() {
        if (dragging) _BeginCarryReturn(false);
        dragging       = false;
        dragStackIndex = -1;
    }

    /// @function EndDrag()
    /// @description Call from a left-mouse-released check while dragging. Resolves the drop target and hands off to TryPlaceBlueprint.
    static EndDrag = function() {
        if (!dragging) return;
        dragging = false;

        var _stacks = global.blueprints[team];
        if (dragStackIndex < 0 || dragStackIndex >= array_length(_stacks)) {
            dragStackIndex = -1;
            carry = undefined;
            return;
        }

        var _buildingType = _stacks[dragStackIndex].buildingType;
        dragStackIndex = -1;

        var _plot = instance_position(mouse_x, mouse_y, oBuildingPlot);
        if (TryPlaceBlueprint(team, _buildingType, _plot)) {
            var _building = instance_position(_plot.x, _plot.y, oBuildingParent);
            _BeginCarryPlace(_building);
        } else {
            _BeginCarryReturn(true);
        }

        ClampPage(); // snap back if that placement emptied the last page
    }

    /// @function _CarryAnchorOffset(_sprite, _scale)
    /// @description Vector from the grab point (under the cursor) to the sprite's origin: sprite horizontally centered, BLUEPRINT_CARRY_ANCHOR_FRACTION down from its top.
    /// @param {Asset.GMSprite} _sprite
    /// @param {Real} _scale
    /// @returns {Struct.Vector2}
    static _CarryAnchorOffset = function(_sprite, _scale) {
        return new Vector2(
            (sprite_get_xoffset(_sprite) - sprite_get_width(_sprite) / 2) * _scale,
            (sprite_get_yoffset(_sprite) - BLUEPRINT_CARRY_ANCHOR_FRACTION * sprite_get_height(_sprite)) * _scale
        );
    }

    /// @function GetCarryState()
    /// @description Current draw state of the carried blueprint: sprite origin position (GUI), rotation (degrees), scale. Undefined when nothing is carried.
    /// @returns {Struct|Undefined} { x, y, rot, scale }
    static GetCarryState = function() {
        if (carry == undefined) return undefined;
        var _c = carry;

        if (_c.phase == "grab" || _c.phase == "held") {
            var _o  = _CarryAnchorOffset(_c.sprite, BLUEPRINT_UI_SCALE);
            var _ex = _c.pivotX + _o.x * dcos(_c.rot) + _o.y * dsin(_c.rot); // rotate the offset about the grab point
            var _ey = _c.pivotY - _o.x * dsin(_c.rot) + _o.y * dcos(_c.rot);
            if (_c.phase == "grab") {
                var _k = _CarryEase(_c.t / BLUEPRINT_CARRY_GRAB_STEPS);
                return { x: lerp(_c.startX, _ex, _k), y: lerp(_c.startY, _ey, _k), rot: _c.rot, scale: BLUEPRINT_UI_SCALE };
            }
            return { x: _ex, y: _ey, rot: _c.rot, scale: BLUEPRINT_UI_SCALE };
        }

        var _k2 = _CarryEase(_c.t / _c.duration);
        return {
            x: lerp(_c.startX, _c.endX, _k2),
            y: lerp(_c.startY, _c.endY, _k2),
            rot: lerp(_c.startRot, 0, _k2),
            scale: lerp(_c.startScale, _c.endScale, _k2)
        };
    }

    /// @function _CarryEase(_t)
    /// @description Smoothstep, clamped.
    /// @param {Real} _t 0..1
    /// @returns {Real}
    static _CarryEase = function(_t) {
        _t = clamp(_t, 0, 1);
        return _t * _t * (3 - 2 * _t);
    }

    /// @function _BeginCarry(_stackIndex, _slotX, _slotY)
    /// @description Starts the carried-blueprint visual at its slot; it glides to the cursor over BLUEPRINT_CARRY_GRAB_STEPS.
    /// @param {Real} _stackIndex
    /// @param {Real} _slotX Slot center, GUI.
    /// @param {Real} _slotY
    static _BeginCarry = function(_stackIndex, _slotX, _slotY) {
        var _def = GetBuildingDefinition(global.blueprints[team][_stackIndex].buildingType);
        if (_def == undefined) { carry = undefined; return; }
        var _mx = device_mouse_x_to_gui(0);
        carry = {
            sprite: _def.sprite, phase: "grab", t: 0,
            stackIndex: _stackIndex, hideSlot: true, failedSound: false,
            slotX: _slotX, slotY: _slotY, // the slot sprite is drawn centered here (origin == slot center)
            startX: _slotX, startY: _slotY,
            pivotX: _mx, pivotY: device_mouse_y_to_gui(0), lastMouseX: _mx,
            rot: 0, rotVel: 0,
            startRot: 0, startScale: BLUEPRINT_UI_SCALE, endX: 0, endY: 0, endScale: BLUEPRINT_UI_SCALE,
            duration: 1, building: noone, landX: 0, landY: 0
        };
    }

    /// @function _BeginCarryReturn(_failed)
    /// @description Sends the carried blueprint quickly back to its slot. _failed is true for a rejected placement (plays the failure sound), false for a plain cancel.
    /// @param {Bool} _failed
    static _BeginCarryReturn = function(_failed) {
        if (carry == undefined) return;
        var _s = GetCarryState();
        carry.phase = "return"; carry.t = 0; carry.duration = BLUEPRINT_CARRY_RETURN_STEPS;
        carry.startX = _s.x; carry.startY = _s.y; carry.startRot = _s.rot; carry.startScale = _s.scale;
        carry.endX = carry.slotX; carry.endY = carry.slotY; carry.endScale = BLUEPRINT_UI_SCALE;
        carry.hideSlot = true;
        if (_failed) {
            // audio_play_sound(sndPlacementFailed, 1, false, PerceptualGain(global.gameSettings.sfxVolume)); // negative sound against failed placement
        }
    }

    /// @function _BeginCarryPlace(_building)
    /// @description Glides the carried blueprint from the cursor onto the just-placed _building (hidden until it lands), then bursts dust.
    /// @param {Id.Instance|Constant.NoOne} _building
    static _BeginCarryPlace = function(_building) {
        if (carry == undefined) return;
        if (!instance_exists(_building)) { carry = undefined; return; }
        var _s    = GetCarryState();
        var _land = WorldToGui(_building.x, _building.y);
        carry.phase = "place"; carry.t = 0; carry.duration = BLUEPRINT_CARRY_PLACE_STEPS;
        carry.startX = _s.x; carry.startY = _s.y; carry.startRot = _s.rot; carry.startScale = _s.scale;
        carry.endX = _land.x; carry.endY = _land.y;
        carry.endScale = display_get_gui_width() / camera_get_view_width(view_camera[0]); // world draw scale
        carry.hideSlot = false; // the stack was already consumed/decremented
        carry.building = _building;
        _building.visible = false; // revealed on landing
    }

    /// @function UpdateCarry()
    /// @description Call once per Step (any time, even with nothing carried). Advances the carry animation, the swing spring, and placement dust.
    static UpdateCarry = function() {
        // dust
        for (var i = array_length(dustParticles) - 1; i >= 0; i--) {
            var _p = dustParticles[i];
            _p.x += _p.vx; _p.y += _p.vy;
            _p.vx *= BLUEPRINT_DUST_FRICTION; _p.vy *= BLUEPRINT_DUST_FRICTION;
            _p.life -= 1;
            if (_p.life <= 0) array_delete(dustParticles, i, 1);
        }

        if (carry == undefined) return;
        var _c = carry;

        if (_c.phase == "grab" || _c.phase == "held") {
            var _mx = device_mouse_x_to_gui(0);
            _c.pivotX = _mx;
            _c.pivotY = device_mouse_y_to_gui(0);

            // fake physics: swing target opposes this step's horizontal mouse movement (moving left -> bottom swings right = positive rotation)
            var _target = clamp(-(_mx - _c.lastMouseX) * BLUEPRINT_CARRY_SWING_PER_PX, -BLUEPRINT_CARRY_SWING_MAX, BLUEPRINT_CARRY_SWING_MAX);
            _c.lastMouseX = _mx;
            _c.rotVel = (_c.rotVel + (_target - _c.rot) * BLUEPRINT_CARRY_SWING_STIFFNESS) * BLUEPRINT_CARRY_SWING_DAMPING;
            _c.rot += _c.rotVel;

            if (_c.phase == "grab") {
                _c.t += 1;
                if (_c.t >= BLUEPRINT_CARRY_GRAB_STEPS) _c.phase = "held";
            }
            return;
        }

        _c.t += 1;
        if (_c.t >= _c.duration) {
            if (_c.phase == "place" && instance_exists(_c.building)) {
                _c.building.visible = true;
                _SpawnPlaceDust(_c.building);
            }
            carry = undefined;
        }
    }

    /// @function _SpawnPlaceDust(_building)
    /// @description Bursts dust from the base of _building outward in all directions (flattened toward the ground).
    /// @param {Id.Instance} _building
    static _SpawnPlaceDust = function(_building) {
        var _baseY = _building.y + (sprite_get_height(_building.sprite_index) - sprite_get_yoffset(_building.sprite_index));
        for (var i = 0; i < BLUEPRINT_DUST_COUNT; i++) {
            var _dir  = random(360);
            var _spd  = random_range(BLUEPRINT_DUST_SPEED_MIN, BLUEPRINT_DUST_SPEED_MAX);
            var _life = irandom_range(BLUEPRINT_DUST_LIFE_MIN, BLUEPRINT_DUST_LIFE_MAX);
            array_push(dustParticles, {
                x: _building.x + random_range(-20, 20), y: _baseY,
                vx: lengthdir_x(_spd, _dir), vy: lengthdir_y(_spd, _dir) * BLUEPRINT_DUST_VERTICAL_SQUASH,
                life: _life, maxLife: _life,
                size: random_range(BLUEPRINT_DUST_SIZE_MIN, BLUEPRINT_DUST_SIZE_MAX),
                color: choose(BLUEPRINT_DUST_COLOR_A, BLUEPRINT_DUST_COLOR_B, BLUEPRINT_DUST_COLOR_C)
            });
        }
    }

    /// @function DrawCarry()
    /// @description Draws placement dust and the carried blueprint sprite. Internal helper for Draw().
    static DrawCarry = function() {
        var _guiScale = display_get_gui_width() / camera_get_view_width(view_camera[0]);
        for (var i = 0; i < array_length(dustParticles); i++) {
            var _p   = dustParticles[i];
            var _pos = WorldToGui(_p.x, _p.y);
            var _sz  = _p.size * _guiScale;
            draw_set_alpha(_p.life / _p.maxLife);
            draw_rectangle_color(_pos.x - _sz / 2, _pos.y - _sz / 2, _pos.x + _sz / 2, _pos.y + _sz / 2, _p.color, _p.color, _p.color, _p.color, false);
        }
        draw_set_alpha(1);

        var _s = GetCarryState();
        if (_s != undefined) {
            draw_sprite_ext(carry.sprite, 0, _s.x, _s.y, _s.scale, _s.scale, _s.rot, c_white, 1);
        }
    }

    /// @function IsMouseOverPanel()
    /// @description True while the mouse (GUI-space) sits anywhere within the panel's grid bounding rect or either page arrow.
    /// @returns {Bool}
    static IsMouseOverPanel = function() {
        var _origin  = GetOrigin();
        var _size    = BLUEPRINT_SLOT_SIZE * BLUEPRINT_UI_SCALE;
        var _padding = BLUEPRINT_SLOT_PADDING * BLUEPRINT_UI_SCALE;
        var _width   = BLUEPRINT_GRID_COLS * (_size + _padding) + _padding;
        var _height  = BLUEPRINT_GRID_ROWS * (_size + _padding) + _padding;

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        if (_mx >= _origin.x && _mx <= _origin.x + _width && _my >= _origin.y && _my <= _origin.y + _height) {
            return true;
        }

        var _arrowRects = GetPageArrowRects();
        var _onPrev = (_mx >= _arrowRects.prev.x1 && _mx <= _arrowRects.prev.x2 && _my >= _arrowRects.prev.y1 && _my <= _arrowRects.prev.y2);
        var _onNext = (_mx >= _arrowRects.next.x1 && _mx <= _arrowRects.next.x2 && _my >= _arrowRects.next.y1 && _my <= _arrowRects.next.y2);
        return _onPrev || _onNext;
    }

    /// @function GetHoveredStackIndex()
    /// @description Resolves the mouse's GUI position to a filled slot's stack index, or -1. Same hit-test as TryBeginDrag, non-mutating.
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
    /// @description Call once per Step. Dwell timer before the hover card shows, then fades in/out. Suppressed while dragging. See BlueprintScripts.md.
    static UpdateHover = function() {
        var _candidate = dragging ? -1 : GetHoveredStackIndex();

        if (_candidate != hoverStackIndex) {
            hoverStackIndex = _candidate;
            hoverTimer      = 0;
        } else if (_candidate != -1) {
            hoverTimer += 1;
        }

        var _shouldShow  = (hoverStackIndex != -1) && (hoverTimer >= BLUEPRINT_HOVER_DELAY_STEPS);
        var _targetAlpha = _shouldShow ? 1 : 0;
        var _fadeStep    = 1 / PLOT_HOVER_FADE_STEPS;
        hoverAlpha = (hoverAlpha < _targetAlpha)
            ? min(_targetAlpha, hoverAlpha + _fadeStep)
            : max(_targetAlpha, hoverAlpha - _fadeStep);

        if (_shouldShow) {
            var _stack = global.blueprints[team][hoverStackIndex];
            var _def   = GetBuildingDefinition(_stack.buildingType);
            if (_def == undefined) return;

            // Title renders red if not placeable anywhere right now -- see BlueprintScripts.md.
            var _best            = GetBestAvailablePlacementCost(team, _def);
            var _canPlaceAnywhere = _best.anyPlotAvailable && _best.cost.CanAfford(team);
            var _titleText = _canPlaceAnywhere ? _def.name : $"[{PLOT_HOVER_BAD_COLOR_TAG}]{_def.name}[/c]";

            // _isBlueprint = true -- flat resource limit + cost row (BuildingHoverScripts.gml).
            var _sizes = hoverExtras.Layout(_def, noone, true, team);
            hoverCard.Show(_titleText, BuildingHoverDescriptionText(_def), 0, 0, _def.description, _sizes.topContentHeight, _sizes.bottomContentHeight);

            // Paired unit card, training buildings only -- no live unit instance yet.
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

            PositionHoverCardPair(_mx, _my, hoverCard, hasUnitHoverCard ? unitHoverCard : noone);
        }
    }

    /// @function DrawHoverCard()
    /// @description Call once per Draw GUI event, separately from Draw() -- see oUnitControl/Draw_64.gml. No-ops while fully faded out.
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
    /// @description Call once per Draw GUI event. Renders every slot, plus the carried blueprint and placement dust. See BlueprintScripts.md.
    static Draw = function() {
        for (var i = 0; i < BLUEPRINT_SLOTS_PER_PAGE; i++) {
            var _rect = GetSlotRect(i);

            var _stackIndex = GetStackIndexAtSlot(i);

            var _stack = (_stackIndex != -1) ? global.blueprints[team][_stackIndex] : undefined;
            var _def   = (_stack != undefined) ? GetBuildingDefinition(_stack.buildingType) : undefined;

            var _borderColor = BLUEPRINT_AFFORDABLE_BORDER_COLOR;
            if (_def != undefined) {
                var _best = GetBestAvailablePlacementCost(team, _def);
                var _canPlaceAnywhere = _best.anyPlotAvailable && _best.cost.CanAfford(team);
                _borderColor = _canPlaceAnywhere ? BLUEPRINT_AFFORDABLE_BORDER_COLOR : BLUEPRINT_UNAFFORDABLE_BORDER_COLOR;
            }

            draw_rectangle_color(_rect.x1, _rect.y1, _rect.x2, _rect.y2, c_black, c_black, c_black, c_black, false);
            draw_rectangle_color(_rect.x1, _rect.y1, _rect.x2, _rect.y2, _borderColor, _borderColor, _borderColor, _borderColor, true);

            // Empty slot, or its icon is following the cursor instead.
            if (_stackIndex == -1 || (carry != undefined && carry.hideSlot && _stackIndex == carry.stackIndex)) continue;
            if (_def == undefined) continue;

            draw_sprite_ext(_def.sprite, 0, (_rect.x1 + _rect.x2) / 2, (_rect.y1 + _rect.y2) / 2, BLUEPRINT_UI_SCALE, BLUEPRINT_UI_SCALE, 0, c_white, 1);

            if (_stack.count > 1) {
                draw_set_halign(fa_right);
                draw_set_valign(fa_bottom);
                draw_set_color(HOVER_CARD_TEXT_COLOR);
                draw_text(_rect.x2 - 2, _rect.y2 - 2, string(_stack.count));
            }
        }

        DrawCarry();

        DrawPageArrows();
    }

    /// @function DrawPageArrows()
    /// @description Draws the prev/next page arrows and a "page N/M" counter (only shown once there's more than one page). Internal helper for Draw().
    static DrawPageArrows = function() {
        var _rects     = GetPageArrowRects();
        var _pageCount = GetPageCount();

        DrawOnePageArrow(_rects.prev, true,  page > 0);
        DrawOnePageArrow(_rects.next, false, page < _pageCount - 1);

        if (_pageCount > 1) {
            var _origin      = GetOrigin();
            var _size        = BLUEPRINT_SLOT_SIZE * BLUEPRINT_UI_SCALE;
            var _padding     = BLUEPRINT_SLOT_PADDING * BLUEPRINT_UI_SCALE;
            var _panelWidth  = BLUEPRINT_GRID_COLS * (_size + _padding) + _padding;
            var _panelHeight = BLUEPRINT_GRID_ROWS * (_size + _padding) + _padding;

            draw_set_halign(fa_center);
            draw_set_valign(fa_top);
            draw_set_color(HOVER_CARD_TEXT_COLOR);
            draw_text(_origin.x + _panelWidth / 2, _origin.y + _panelHeight + 4, $"{page + 1}/{_pageCount}");
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
        }
    }

    /// @function DrawOnePageArrow(_rect, _pointsLeft, _enabled)
    /// @description Draws one page arrow sprite: frame 1 when hovered and enabled, frame 0 otherwise, 50% alpha when disabled.
    /// @param {Struct} _rect { x1, y1, x2, y2 }
    /// @param {Bool} _pointsLeft
    /// @param {Bool} _enabled
    static DrawOnePageArrow = function(_rect, _pointsLeft, _enabled) {
        var _sprite = _pointsLeft ? sLeftArrow : sRightArrow;
        var _mx     = device_mouse_x_to_gui(0);
        var _my     = device_mouse_y_to_gui(0);
        var _hover  = (_mx >= _rect.x1 && _mx <= _rect.x2 && _my >= _rect.y1 && _my <= _rect.y2);
        var _frame  = (_enabled && _hover) ? 1 : 0;
        var _alpha  = _enabled ? 1 : 0.5;

        // rect is the sprite's top-left bounds; shift by the sprite's own origin so any origin works
        var _drawX = _rect.x1 + sprite_get_xoffset(_sprite) * BLUEPRINT_UI_SCALE;
        var _drawY = _rect.y1 + sprite_get_yoffset(_sprite) * BLUEPRINT_UI_SCALE;
        draw_sprite_ext(_sprite, _frame, _drawX, _drawY, BLUEPRINT_UI_SCALE, BLUEPRINT_UI_SCALE, 0, c_white, _alpha);
    }
}
