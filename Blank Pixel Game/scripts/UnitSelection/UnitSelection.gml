// -----------------------------------------------------------
// Order -- a single issuable command.
// -----------------------------------------------------------

/// @function Order(_name, _label, _onIssue, _requiresTarget, _targetValidator)
/// @param {String} _name   Matches an entry in a unit's availableOrders
///        AND a registered StateMachine state name, e.g. "guard".
/// @param {String} _label  Display text for the dropdown menu, e.g. "Guard".
/// @param {Function} [_onIssue] (_units, _context) -> void. Defaults to
///        just calling fsm.ChangeState(_name) on every unit. Override for
///        orders that need extra setup -- see scr_orders_example.gml.
/// @param {Bool} [_requiresTarget] If true, picking this order from the
///        menu does NOT issue it immediately -- the controller instead
///        enters target-selection mode and waits for a qualifying click.
///        See SelectionController.BeginTargeting().
/// @param {Function} [_targetValidator] (_instance, _team) -> Bool. Only
///        used when _requiresTarget is true. Decides whether a clicked
///        instance is a legal target for this order. _team is the
///        "own team" perspective of whoever is issuing the order (see
///        SelectionController.team) -- always pass it through rather
///        than hardcoding a team constant, so the same validator works
///        no matter which side is issuing the order.
function Order(_name, _label, _onIssue = undefined, _requiresTarget = false, _targetValidator = undefined) constructor {
    name  = _name;
    label = _label;
    requiresTarget  = _requiresTarget;
    targetValidator = _targetValidator;
    onIssue = (_onIssue != undefined) ? _onIssue : function(_units, _context) {
        for (var i = 0; i < array_length(_units); i++) {
            // IssueOrderToUnits is shared by the player's SelectionController
            // and the AI controller -- SelectionController prunes dead units
            // out of `selected` once per Step (see PruneDeadSelected), but
            // the AI path doesn't go through that, and even the player path
            // can't guarantee nothing died in the instant between the prune
            // and this callback running. Guard here too, matching how every
            // other cross-instance reference in the codebase is guarded
            // (attackBuildingTarget, combatTarget, defendTarget, etc.) --
            // flagged in NIGHTLY_REVIEW_2026-07-09.md as the one place this
            // pattern was missing.
            if (!instance_exists(_units[i])) continue;
            _units[i].fsm.ChangeState(name);
        }
    }
}

// -----------------------------------------------------------
// Order registry -- every order the game knows about, keyed by
// name. Register once at game start; both the menu and the
// common-orders lookup read from this.
// -----------------------------------------------------------

global.__orderRegistry = {};

/// @function RegisterOrder(_order)
/// @param {Struct.Order} _order
function RegisterOrder(_order) {
    variable_struct_set(global.__orderRegistry, _order.name, _order);
}

/// @function GetOrder(_name)
/// @param {String} _name
/// @returns {Struct.Order|Undefined}
function GetOrder(_name) {
    return variable_struct_exists(global.__orderRegistry, _name)
        ? variable_struct_get(global.__orderRegistry, _name)
        : undefined;
}

/// @function GetCommonOrders(_units)
/// @param {Array<Id.Instance>} _units
/// @returns {Array<Struct.Order>} Orders every unit in _units has in its
///         availableOrders, resolved against the registry. Empty array
///         if _units is empty or shares nothing in common.
function GetCommonOrders(_units) {
    if (array_length(_units) == 0) return [];

    // Guard: if the first unit doesn't have availableOrders at all,
    // return empty rather than crashing. This fires if a unit type
    // forgot to declare the variable -- check its Create event.
    if (!variable_instance_exists(_units[0], "availableOrders")) {
        show_debug_message($"GetCommonOrders: {object_get_name(_units[0].object_index)} is missing 'availableOrders'. Declare it in its Create event.");
        return [];
    }

    var _common = _units[0].availableOrders;
    for (var i = 1; i < array_length(_units); i++) {
        if (!variable_instance_exists(_units[i], "availableOrders")) continue;
        var _next = [];
        var _otherOrders = _units[i].availableOrders;
        for (var j = 0; j < array_length(_common); j++) {
            if (array_contains(_otherOrders, _common[j])) {
                array_push(_next, _common[j]);
            }
        }
        _common = _next;
        if (array_length(_common) == 0) break;
    }

    var _resolved = [];
    for (var i = 0; i < array_length(_common); i++) {
        var _order = GetOrder(_common[i]);
        if (_order != undefined) array_push(_resolved, _order);
    }
    return _resolved;
}

// -----------------------------------------------------------
// SelectionController -- drag box + current selection.
// One instance for the player; create it once, persistent.
// -----------------------------------------------------------

// Below this GUI y (out of a 1920x1080 GUI, per 2026-07-05 request), the
// screen is bottom-panel UI real estate (blueprint panel, etc.) rather
// than the playfield -- a press that STARTS down there should never kick
// off a world-space unit-selection drag, even over empty panel padding a
// widget's own hit-test doesn't claim. See BeginDrag below.
#macro SELECTION_DRAG_MIN_GUI_Y 812

/// @function SelectionController(_unitObject, _team)
/// @param {Asset.GMObject} _unitObject The object type (or parent) to
///        consider selectable, e.g. obj_unit.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY -- whichever side owns
///        this controller. Not player-exclusive despite the name of the
///        object that currently instantiates it (oUnitControl) -- an
///        AI-driven controller could use this same struct with
///        _team = TEAM.ENEMY.
function SelectionController(_unitObject, _team) constructor {
    unitObject       = _unitObject;
    team             = _team;
    selected         = [];
    dragging         = false;
    dragStartX       = 0;
    dragStartY       = 0;
    _pendingOrder    = undefined; // Order awaiting a target click
    isTargeting      = false;     // true while waiting for the player to click a target
    _targetingJustBegan = false;  // swallows the same-frame click that opened targeting mode -- see BeginTargeting/UpdateTargeting

    /// @function BeginDrag()
    /// Call from a Left Pressed / mouse-down check in Step. No-ops (leaves
    /// dragging false) if the press starts at or below
    /// SELECTION_DRAG_MIN_GUI_Y -- that's bottom-panel UI space, not the
    /// playfield, so a press there should never start a world-space
    /// selection box, even over panel padding no widget's own hit-test
    /// claims. Only where the drag STARTS is checked; a drag that begins
    /// above the line and is dragged down past it is unaffected.
    /// @returns {Struct.SelectionController} self
    static BeginDrag = function() {
        if (device_mouse_y_to_gui(0) >= SELECTION_DRAG_MIN_GUI_Y) {
            return self;
        }

        dragging   = true;
        dragStartX = mouse_x;
        dragStartY = mouse_y;
        return self;
    }

    /// @function EndDrag(_additive)
    /// Call from a Left Released / mouse-up check in Step.
    /// @param {Bool} [_additive] Hold-shift behavior: add to selection
    ///        instead of replacing it.
    /// @returns {Struct.SelectionController} self
    static EndDrag = function(_additive = false) {
        if (!dragging) return self;
        dragging = false;

        var _x1 = min(dragStartX, mouse_x);
        var _y1 = min(dragStartY, mouse_y);
        var _x2 = max(dragStartX, mouse_x);
        var _y2 = max(dragStartY, mouse_y);

        // A drag smaller than this is treated as a click, not a box --
        // avoids accidentally clearing selection on a tiny mouse jitter.
        var _isClick = (_x2 - _x1 < 4) && (_y2 - _y1 < 4);

        var _found = [];
        if (_isClick) {
            var _inst = instance_position(mouse_x, mouse_y, unitObject);
            if (_inst != noone && _inst.team == team) {
                array_push(_found, _inst);
            }
        } else {
            var _list = ds_list_create();
            var _count = collision_rectangle_list(_x1, _y1, _x2, _y2, unitObject, false, true, _list, false);
            for (var i = 0; i < _count; i++) {
                if (_list[| i].team == team) {
                    array_push(_found, _list[| i]);
                }
            }
            ds_list_destroy(_list);
        }

        selected = _additive ? array_concat(selected, _found) : _found;
        return self;
    }

    /// @function GetDragRect()
    /// @returns {Struct} { x1, y1, x2, y2 } of the in-progress drag box.
    ///         Only meaningful while `dragging` is true.
    static GetDragRect = function() {
        return {
            x1: min(dragStartX, mouse_x), y1: min(dragStartY, mouse_y),
            x2: max(dragStartX, mouse_x), y2: max(dragStartY, mouse_y)
        };
    }

    /// @function PruneDeadSelected()
    /// Removes any selected unit that no longer exists (died since being
    /// selected) from `selected`. ApplyDamage (UnitCombatHelpers.gml)
    /// destroys units directly via instance_destroy with no hook back into
    /// selection state, so nothing else keeps `selected` in sync -- without
    /// this, AvailableOrders/IssueOrder/UnitSelectHoverController.Step can
    /// all dereference a freed instance. Called once per Step from
    /// oUnitControl/Step_0.gml, before anything else that frame reads
    /// `selected`, rather than guarding every read site individually.
    /// Flagged in NIGHTLY_REVIEW_2026-07-09.md (§3.1, critical).
    /// @returns {Struct.SelectionController} self
    static PruneDeadSelected = function() {
        var _alive = [];
        for (var i = 0; i < array_length(selected); i++) {
            if (instance_exists(selected[i])) {
                array_push(_alive, selected[i]);
            }
        }
        selected = _alive;
        return self;
    }

    /// @function Deselect()
    /// @description Instantly clears the current selection and cancels
    ///        target-selection mode if active -- does NOT touch `dragging`
    ///        (a drag box is a mouse-button-held gesture, not a persistent
    ///        state, so there's nothing meaningful to cancel there; EndDrag
    ///        still resolves normally on mouse-up). 2026-07-13: added for
    ///        the Fate Engine overlay's Open() ("all selections will be
    ///        unselected instantly, and submenus will close") -- the only
    ///        prior way to clear `selected` was the two inline
    ///        `selected = []` assignments inside IssueOrder/UpdateTargeting,
    ///        neither of which fit an external caller wanting a clean-slate
    ///        reset outside the normal order-issuing flow.
    /// @returns {Struct.SelectionController} self
    static Deselect = function() {
        selected = [];
        if (isTargeting) CancelTargeting();
        return self;
    }

    /// @function SelectAllOfType(_unitType)
    /// @description Selects every live instance of _unitType belonging to
    ///        this controller's own team, replacing whatever was
    ///        previously selected -- 2026-07-13 request (Army Limit
    ///        Widget's "Unit Limits" dropdown, ArmyLimitMenu.gml: "select
    ///        all deployed units of that type"). "Deployed" means live
    ///        oUnitParent instances actually on the battlefield --
    ///        stationed (garrisoned) units of the same type are
    ///        deliberately NOT included; they're a different object
    ///        (oUnitStationed), have no FSM, and were never selectable to
    ///        begin with, same reasoning AI_GatherAvailableUnits
    ///        (AIControl.gml) uses to treat live and stationed units as
    ///        separate pools entirely.
    /// @param {Asset.GMObject} _unitType e.g. oPeasantUnit.
    /// @returns {Struct.SelectionController} self
    static SelectAllOfType = function(_unitType) {
        var _team = team; // capture before `with` changes the instance context
        var _found = [];
        with (_unitType) {
            if (team == _team) array_push(_found, id);
        }
        selected = _found;
        return self;
    }

    /// @function AvailableOrders()
    /// @returns {Array<Struct.Order>} Orders common to the current selection.
    static AvailableOrders = function() {
        return GetCommonOrders(selected);
    }

    /// @function IssueOrder(_orderName, _context)
    /// Issues a named order to the current selection, or enters
    /// target-selection mode if the order requires a target first.
    /// Internally calls IssueOrderToUnits so the player and AI go
    /// through the exact same Order.onIssue path.
    ///
    /// Clears `selected` the instant the order actually goes out (i.e.
    /// immediately here for a no-target order like "guard"/"siege" -- a
    /// targeted order like "defend"/"attack" doesn't clear until
    /// UpdateTargeting's successful-click branch, since nothing has
    /// actually been issued yet at this point for those). Per 2026-07-06
    /// request: units deselect once given an order.
    /// @param {String} _orderName
    /// @param {*} [_context]
    /// @returns {Struct.SelectionController} self
    static IssueOrder = function(_orderName, _context = undefined) {
        var _order = GetOrder(_orderName);
        if (_order == undefined) {
            show_debug_message($"SelectionController: unknown order '{_orderName}'");
            return self;
        }

        if (_order.requiresTarget) {
            BeginTargeting(_order);
        } else {
            IssueOrderToUnits(_orderName, selected, _context);
            selected = [];
        }

        return self;
    }

    /// @function BeginTargeting(_order)
    /// Enters target-selection mode for a given order. Called
    /// automatically by IssueOrder -- you shouldn't need to call this
    /// directly, but it's public in case you want to enter targeting
    /// mode programmatically (e.g. from a keyboard shortcut).
    ///
    /// Sets _targetingJustBegan so the very next UpdateTargeting call (which,
    /// per oUnitControl/Step_0.gml, runs in the SAME Step event as the menu
    /// click that got here via IssueOrder) doesn't immediately consume that
    /// same physical mouse press -- see UpdateTargeting for why that was a
    /// real bug (2026-07-06: "sometimes does not bring up the targeting
    /// reticle").
    /// @param {Struct.Order} _order
    /// @returns {Struct.SelectionController} self
    static BeginTargeting = function(_order) {
        _pendingOrder        = _order;
        isTargeting          = true;
        _targetingJustBegan  = true;
        return self;
    }

    /// @function CancelTargeting()
    /// Cancels target-selection mode without issuing anything.
    /// Call on right-click or Escape while isTargeting is true.
    /// @returns {Struct.SelectionController} self
    static CancelTargeting = function() {
        _pendingOrder        = undefined;
        isTargeting          = false;
        _targetingJustBegan  = false;
        return self;
    }

    /// @function UpdateTargeting()
    /// Call from Step while isTargeting is true. Handles the left-click
    /// target pick and validates it against the order's targetValidator.
    /// Returns true the frame a valid target is clicked (order issued);
    /// false every other frame.
    /// @returns {Bool}
    static UpdateTargeting = function() {
        if (!isTargeting) return false;

        // BeginTargeting (called from IssueOrder, itself called from
        // oUnitControl/Step_0.gml the instant orderMenu.Update() reports a
        // click) runs in the SAME Step event as this first UpdateTargeting
        // call -- mouse_check_button_pressed(mb_left) below is still true
        // for the rest of that Step, since it's the exact same physical
        // press that selected "Defend Building" from the menu. Without this
        // guard, that stale press gets read as the player's target click,
        // resolving against wherever the cursor happened to be sitting on
        // the menu (almost never a valid target) and canceling targeting
        // mode before the reticle is ever drawn -- 2026-07-06: "sometimes
        // does not bring up the targeting reticle." Swallow exactly that
        // one same-frame press and start reading clicks for real next Step.
        if (_targetingJustBegan) {
            _targetingJustBegan = false;
            return false;
        }

        if (mouse_check_button_pressed(mb_right)) {
            CancelTargeting();
            return false;
        }

        if (!mouse_check_button_pressed(mb_left)) return false;

        // Check every clickable parent -- buildings are the expected
        // target for defend, but other orders might target units or
        // environment objects, so we check all instances at the cursor
        // and let the validator decide.
        var _clicked = instance_position(mouse_x, mouse_y, all);

        // An occupied oBuildingPlot is never destroyed once something is
        // built on it (TryPlaceBlueprint, BlueprintScripts.gml -- it just
        // sets occupied = true) and sits at the exact same x/y as the
        // building placed on it, so instance_position(..., all) can
        // resolve to the plot instead of the building underneath it --
        // the plot fails every real targetValidator (it's not an
        // oBuildingParent), so the click would otherwise silently do
        // nothing. Per 2026-07-06 request ("strip its mask... regain it
        // once nothing's built on it"): rather than an actual mask/sprite
        // swap (every mask in this project, sPlot included, is rectangle/
        // bbox collision, not precise -- an empty mask would need a new,
        // hand-authored sprite asset), an occupied plot is click-through
        // here, and we re-resolve against oBuildingParent (which matches
        // the building sitting on top of it). NOTE: this checks `occupied`,
        // NOT `blocked` -- blocked is an unrelated meta-progression flag
        // (see oPlotSpawner/Create_0.gml's interior-grid lockout), corrected
        // same day after conflating the two. An UNOCCUPIED plot (blocked or
        // not) has nothing built on it and is unaffected -- still a normal
        // target in its own right.
        if (_clicked != noone && _clicked.object_index == oBuildingPlot && _clicked.occupied) {
            _clicked = instance_position(mouse_x, mouse_y, oBuildingParent);
        }

        if (_clicked == noone) {
            CancelTargeting();
            return false;
        }

        var _validator = _pendingOrder.targetValidator;
        var _valid = (_validator != undefined) ? _validator(_clicked, team) : true;

        if (_valid) {
            IssueOrderToUnits(_pendingOrder.name, selected, _clicked);
            selected = []; // deselect now that the order has actually gone out -- 2026-07-06
            CancelTargeting();
            return true;
        }

        // Clicked something, but it wasn't a valid target -- stay in
        // targeting mode so the player can try again rather than
        // silently canceling.
        return false;
    }

    /// @function DrawDragBox()
    /// Draws the in-progress drag box. Call from a room-space Draw
    /// event (NOT Draw GUI) -- this rectangle is in room coordinates.
    static DrawDragBox = function() {
        if (!dragging) return;
        var _r = GetDragRect();
        draw_rectangle_color(_r.x1, _r.y1, _r.x2, _r.y2, c_white, c_white, c_white, c_white, true);
    }

    /// @function DrawTargetingCursor()
    /// Draws a targeting cursor hint while in target-selection mode.
    /// Call from a Draw GUI event. Replace the draw calls here with
    /// whatever cursor sprite fits your UI.
    static DrawTargetingCursor = function() {
        if (!isTargeting) return;
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        draw_set_color(c_yellow);
        draw_circle(_mx, _my, 8, true);
        // 2026-07-11 request: matches HOVER_CARD_TEXT_COLOR
        // (HoverCardScripts.gml) -- was c_white. The yellow targeting
        // reticle itself is left alone -- it's a cursor/state indicator,
        // not body text.
        draw_set_color(HOVER_CARD_TEXT_COLOR);
        draw_text(_mx + 12, _my - 8, $"Select target for: {_pendingOrder.label}");
    }
}
