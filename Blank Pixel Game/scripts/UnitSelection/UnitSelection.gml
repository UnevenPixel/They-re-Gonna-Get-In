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
        }

        return self;
    }

    /// @function BeginTargeting(_order)
    /// Enters target-selection mode for a given order. Called
    /// automatically by IssueOrder -- you shouldn't need to call this
    /// directly, but it's public in case you want to enter targeting
    /// mode programmatically (e.g. from a keyboard shortcut).
    /// @param {Struct.Order} _order
    /// @returns {Struct.SelectionController} self
    static BeginTargeting = function(_order) {
        _pendingOrder = _order;
        isTargeting   = true;
        return self;
    }

    /// @function CancelTargeting()
    /// Cancels target-selection mode without issuing anything.
    /// Call on right-click or Escape while isTargeting is true.
    /// @returns {Struct.SelectionController} self
    static CancelTargeting = function() {
        _pendingOrder = undefined;
        isTargeting   = false;
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
        if (_clicked == noone) {
            CancelTargeting();
            return false;
        }

        var _validator = _pendingOrder.targetValidator;
        var _valid = (_validator != undefined) ? _validator(_clicked, team) : true;

        if (_valid) {
            IssueOrderToUnits(_pendingOrder.name, selected, _clicked);
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
        draw_set_color(c_white);
        draw_text(_mx + 12, _my - 8, $"Select target for: {_pendingOrder.label}");
    }
}
