// Unit selection and order-issuing -- Order, the order registry, and
// SelectionController (drag box + selection + target-selection mode). See UnitSelection.md.

/// @function Order(_name, _label, _onIssue, _requiresTarget, _targetValidator)
/// @param {String} _name   Matches an entry in a unit's availableOrders AND a registered StateMachine state name, e.g. "guard".
/// @param {String} _label  Display text for the dropdown menu, e.g. "Guard".
/// @param {Function} [_onIssue] (_units, _context) -> void. Defaults to calling fsm.ChangeState(_name) on every unit (existence-guarded, see .md).
/// @param {Bool} [_requiresTarget] If true, picking this order does NOT issue immediately -- enters target-selection mode instead. See SelectionController.BeginTargeting().
/// @param {Function} [_targetValidator] (_instance, _team) -> Bool. Only used when _requiresTarget is true.
function Order(_name, _label, _onIssue = undefined, _requiresTarget = false, _targetValidator = undefined) constructor {
    name  = _name;
    label = _label;
    requiresTarget  = _requiresTarget;
    targetValidator = _targetValidator;
    onIssue = (_onIssue != undefined) ? _onIssue : function(_units, _context) {
        for (var i = 0; i < array_length(_units); i++) {
            if (!instance_exists(_units[i])) continue;
            _units[i].fsm.ChangeState(name);
        }
    }
}

// Order registry -- every order the game knows about, keyed by name.
// Register once at game start; both the menu and the common-orders lookup read from this.
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
/// @returns {Array<Struct.Order>} Orders every unit in _units has in its availableOrders, resolved against the registry. Empty array if _units is empty or shares nothing in common.
function GetCommonOrders(_units) {
    if (array_length(_units) == 0) return [];

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

// Below this GUI y (out of a 1920x1080 GUI), the screen is bottom-panel UI
// real estate rather than the playfield -- see .md.
#macro SELECTION_DRAG_MIN_GUI_Y 812

/// @function SelectionController(_unitObject, _team)
/// @param {Asset.GMObject} _unitObject The object type (or parent) to consider selectable, e.g. obj_unit.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY -- whichever side owns this controller. Not player-exclusive despite the name of the object that currently instantiates it (oUnitControl).
function SelectionController(_unitObject, _team) constructor {
    unitObject       = _unitObject;
    team             = _team;
    selected         = [];
    dragging         = false;
    dragStartX       = 0;
    dragStartY       = 0;
    _pendingOrder    = undefined; // Order awaiting a target click
    isTargeting      = false;     // true while waiting for the player to click a target
    _targetingJustBegan = false;  // swallows the same-frame click that opened targeting mode -- see .md

    /// @function BeginDrag()
    /// @description Call from a Left Pressed / mouse-down check in Step. No-ops if the press starts at or below SELECTION_DRAG_MIN_GUI_Y. See .md.
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
    /// @description Call from a Left Released / mouse-up check in Step.
    /// @param {Bool} [_additive] Hold-shift behavior: add to selection instead of replacing it.
    /// @returns {Struct.SelectionController} self
    static EndDrag = function(_additive = false) {
        if (!dragging) return self;
        dragging = false;

        var _x1 = min(dragStartX, mouse_x);
        var _y1 = min(dragStartY, mouse_y);
        var _x2 = max(dragStartX, mouse_x);
        var _y2 = max(dragStartY, mouse_y);

        // A drag smaller than this is treated as a click, not a box.
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
    /// @returns {Struct} { x1, y1, x2, y2 } of the in-progress drag box. Only meaningful while `dragging` is true.
    static GetDragRect = function() {
        return {
            x1: min(dragStartX, mouse_x), y1: min(dragStartY, mouse_y),
            x2: max(dragStartX, mouse_x), y2: max(dragStartY, mouse_y)
        };
    }

    /// @function PruneDeadSelected()
    /// @description Removes any selected unit that no longer exists from `selected`. Called once per Step from oUnitControl/Step_0.gml, before anything else that frame reads `selected`. See .md.
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
    /// @description Instantly clears the current selection and cancels target-selection mode if active. Does NOT touch `dragging`. See .md.
    /// @returns {Struct.SelectionController} self
    static Deselect = function() {
        selected = [];
        if (isTargeting) CancelTargeting();
        return self;
    }

    /// @function SelectAllOfType(_unitType)
    /// @description Selects every live instance of _unitType on this controller's own team, replacing the current selection. Excludes stationed units -- see .md.
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
    /// @description Issues a named order to the current selection, or enters target-selection mode if the order requires a target first. Internally calls IssueOrderToUnits so player and AI share the same Order.onIssue path. See .md for the clear-selection timing.
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
    /// @description Enters target-selection mode for a given order. Called automatically by IssueOrder. Sets _targetingJustBegan -- see .md.
    /// @param {Struct.Order} _order
    /// @returns {Struct.SelectionController} self
    static BeginTargeting = function(_order) {
        _pendingOrder        = _order;
        isTargeting          = true;
        _targetingJustBegan  = true;
        return self;
    }

    /// @function CancelTargeting()
    /// @description Cancels target-selection mode without issuing anything. Call on right-click or Escape while isTargeting is true.
    /// @returns {Struct.SelectionController} self
    static CancelTargeting = function() {
        _pendingOrder        = undefined;
        isTargeting          = false;
        _targetingJustBegan  = false;
        return self;
    }

    /// @function UpdateTargeting()
    /// @description Call from Step while isTargeting is true. Handles the left-click target pick and validates it against the order's targetValidator. See .md for the same-frame-click guard and the occupied-plot click-through. Returns true the frame a valid target is clicked (order issued); false every other frame.
    /// @returns {Bool}
    static UpdateTargeting = function() {
        if (!isTargeting) return false;

        if (_targetingJustBegan) {
            _targetingJustBegan = false;
            return false;
        }

        if (mouse_check_button_pressed(mb_right)) {
            CancelTargeting();
            return false;
        }

        if (!mouse_check_button_pressed(mb_left)) return false;

        // Check every clickable parent -- buildings are the expected target
        // for defend, but other orders might target units or environment
        // objects, so we check all instances at the cursor and let the
        // validator decide.
        var _clicked = instance_position(mouse_x, mouse_y, all);

        // Occupied plots click through to the building on top -- see .md.
        // Checks `occupied`, NOT `blocked` (an unrelated meta-progression flag).
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
            selected = []; // deselect now that the order has actually gone out
            CancelTargeting();
            return true;
        }

        // Clicked something invalid -- stay in targeting mode so the player
        // can try again rather than silently canceling.
        return false;
    }

    /// @function DrawDragBox()
    /// @description Draws the in-progress drag box. Call from a room-space Draw event (NOT Draw GUI) -- this rectangle is in room coordinates.
    static DrawDragBox = function() {
        if (!dragging) return;
        var _r = GetDragRect();
        draw_rectangle_color(_r.x1, _r.y1, _r.x2, _r.y2, c_white, c_white, c_white, c_white, true);
    }
}
