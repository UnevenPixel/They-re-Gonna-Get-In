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

/// @function TryPlaceBlueprint(_team, _buildingType, _plot)
/// @description Resolves an attempt to place _buildingType at _plot for
///        _team: valid target is an unblocked oBuildingPlot owned by
///        _team; if valid and affordable, purchases the cost, spawns the
///        building, marks the plot blocked, consumes one blueprint, and
///        records it to analytics. Every rejection is logged via
///        show_debug_message and simply returns false -- caller decides
///        what "stays in the UI" / "try again later" means for it.
///
///        Extracted from BlueprintController.EndDrag so both the
///        player's mouse-drag flow AND a programmatic caller (the AI --
///        see AI_TryPlaceBlueprints in AIControl.gml) can place buildings
///        through identical cost/analytics/plot-blocking handling. EndDrag
///        now just resolves _plot from the cursor and calls this.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Asset.GMObject} _buildingType
/// @param {Id.Instance|Constant.NoOne} _plot Target oBuildingPlot, or
///        noone (e.g. nothing under the cursor) -- handled as a normal
///        rejection, not a crash.
/// @returns {Bool} True if the building was placed.
function TryPlaceBlueprint(_team, _buildingType, _plot) {
    if (_plot == noone || _plot.team != _team || _plot.blocked) {
        show_debug_message($"TryPlaceBlueprint: no valid owned/empty plot for {object_get_name(_buildingType)} (team {_team}).");
        return false;
    }

    var _def = GetBuildingDefinition(_buildingType);
    if (_def == undefined) {
        show_debug_message($"TryPlaceBlueprint: no BuildingDefinition registered for {object_get_name(_buildingType)}.");
        return false;
    }

    if (!_def.cost.CanAfford(_team)) {
        show_debug_message($"TryPlaceBlueprint: team {_team} can't afford {_def.name}.");
        return false;
    }

    Purchase(_def.cost, _team);

    var _building = instance_create_layer(_plot.x, _plot.y, "Instances", _buildingType);
    _building.team = _team; // overrides oBuildingParent's Create-time TEAM.PLAYER default -- see that file

    _plot.blocked = true;

    RemoveBlueprintOne(_team, _buildingType);

    AnalyticsRecordBuildingBuilt(_team, _buildingType);

    return true;
}

// -----------------------------------------------------------
// BlueprintController -- the Blueprint UI panel: a paginated 5x2 grid of
// 48x48 slots at the bottom of the screen. Drag a filled slot onto a plot
// the dragging team owns to place that building, if it's affordable.
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
#macro BLUEPRINT_SLOT_PADDING   4
#macro BLUEPRINT_GRID_COLS      5
#macro BLUEPRINT_GRID_ROWS      2
#macro BLUEPRINT_SLOTS_PER_PAGE 10 // BLUEPRINT_GRID_COLS * BLUEPRINT_GRID_ROWS

/// @function BlueprintController(_team)
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY -- whose blueprint
///        inventory (global.blueprints[_team]) this controller shows/drags.
function BlueprintController(_team) constructor {
    team           = _team;
    page           = 0;
    dragging       = false;
    dragStackIndex = -1; // index into global.blueprints[team], set while dragging

    /// @function GetOrigin()
    /// @description Top-left corner of the panel, centered horizontally at
    ///        the bottom of the GUI.
    /// @returns {Struct.Vector2}
    static GetOrigin = function() {
        var _panelW = BLUEPRINT_GRID_COLS * (BLUEPRINT_SLOT_SIZE + BLUEPRINT_SLOT_PADDING) + BLUEPRINT_SLOT_PADDING;
        var _panelH = BLUEPRINT_GRID_ROWS * (BLUEPRINT_SLOT_SIZE + BLUEPRINT_SLOT_PADDING) + BLUEPRINT_SLOT_PADDING;
        return new Vector2(
            (display_get_gui_width() - _panelW) / 2,
            display_get_gui_height() - _panelH - 8 // 8px margin off the bottom edge
        );
    }

    /// @function GetSlotRect(_slotIndex)
    /// @param {Real} _slotIndex 0..(BLUEPRINT_SLOTS_PER_PAGE - 1)
    /// @returns {Struct} { x1, y1, x2, y2 } GUI-space rect for that slot.
    static GetSlotRect = function(_slotIndex) {
        var _origin = GetOrigin();
        var _col = _slotIndex mod BLUEPRINT_GRID_COLS;
        var _row = _slotIndex div BLUEPRINT_GRID_COLS;
        var _x1  = _origin.x + BLUEPRINT_SLOT_PADDING + _col * (BLUEPRINT_SLOT_SIZE + BLUEPRINT_SLOT_PADDING);
        var _y1  = _origin.y + BLUEPRINT_SLOT_PADDING + _row * (BLUEPRINT_SLOT_SIZE + BLUEPRINT_SLOT_PADDING);
        return { x1: _x1, y1: _y1, x2: _x1 + BLUEPRINT_SLOT_SIZE, y2: _y1 + BLUEPRINT_SLOT_SIZE };
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

            draw_sprite(_def.sprite, 0, (_rect.x1 + _rect.x2) / 2, (_rect.y1 + _rect.y2) / 2);

            if (_stack.count > 1) {
                draw_set_halign(fa_right);
                draw_set_valign(fa_bottom);
                draw_set_color(c_white);
                draw_text(_rect.x2 - 2, _rect.y2 - 2, string(_stack.count));
            }
        }

        if (dragging) {
            var _stacks = global.blueprints[team];
            if (dragStackIndex >= 0 && dragStackIndex < array_length(_stacks)) {
                var _def = GetBuildingDefinition(_stacks[dragStackIndex].buildingType);
                if (_def != undefined) {
                    draw_sprite(_def.sprite, 0, device_mouse_x_to_gui(0), device_mouse_y_to_gui(0));
                }
            }
        }
    }
}
