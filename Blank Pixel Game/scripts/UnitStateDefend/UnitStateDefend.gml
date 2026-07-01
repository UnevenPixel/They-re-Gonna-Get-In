#macro DEFEND_BUILDING_HALF  24   // half of 48x48
#macro DEFEND_PATROL_MARGIN  20   // how far outside the building edge the patrol path sits
#macro DEFEND_WAYPOINT_REACH 12   // how close the unit needs to get before advancing to next waypoint
#macro DEFEND_ARRIVE_RADIUS  48   // Steering_Arrive slow-down zone

/// @function DefendBuildingWaypoints(_building)
/// Builds the four patrol corner waypoints around a building.
/// @param {Id.Instance} _building
/// @returns {Array<Struct.Vector2>}
function DefendBuildingWaypoints(_building) {
    var _m = DEFEND_BUILDING_HALF + DEFEND_PATROL_MARGIN;
    var _bx = _building.x;
    var _by = _building.y;
    return [
        new Vector2(_bx - _m, _by - _m), // top-left
        new Vector2(_bx + _m, _by - _m), // top-right
        new Vector2(_bx + _m, _by + _m), // bottom-right
        new Vector2(_bx - _m, _by + _m)  // bottom-left
    ];
}

/// @function NearestWaypointIndex(_pos, _waypoints)
/// Returns the index of whichever waypoint in _waypoints is closest
/// to _pos. Used on entry to pick up the patrol from the nearest
/// corner rather than always snapping to corner 0.
/// @param {Struct.Vector2} _pos
/// @param {Array<Struct.Vector2>} _waypoints
/// @returns {Real}
function NearestWaypointIndex(_pos, _waypoints) {
    var _best  = 0;
    var _bestD = _pos.DistanceSquared(_waypoints[0]);
    for (var i = 1; i < array_length(_waypoints); i++) {
        var _d = _pos.DistanceSquared(_waypoints[i]);
        if (_d < _bestD) {
            _bestD = _d;
            _best  = i;
        }
    }
    return _best;
}

// -----------------------------------------------------------
// defend
// -----------------------------------------------------------

/// @function Defend_Enter(_unit, _machine)
/// @description StateMachine onEnter for "defend". Falls back to "guard" if the
///        target building is already gone; otherwise builds the patrol waypoints
///        and picks up the patrol from whichever corner is nearest the unit.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Defend_Enter(_unit, _machine) {
    if (!instance_exists(_unit.defendTarget)) {
        // Building was destroyed before the unit arrived -- fall back.
        _machine.ChangeState("guard");
        return;
    }

    var _waypoints = DefendBuildingWaypoints(_unit.defendTarget);
    _machine.data.waypoints     = _waypoints;
    _machine.data.waypointIndex = NearestWaypointIndex(
        _unit.agent.pos,
        _waypoints
    );
}

/// @function Defend_Step(_unit, _machine)
/// @description StateMachine onStep for "defend". Patrols the building's four
///        corner waypoints via Steering_Arrive, advancing to the next corner once
///        close enough. Falls back to "guard" if the building is destroyed mid-patrol.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Defend_Step(_unit, _machine) {
    // Building could be destroyed mid-patrol -- bail out gracefully.
    if (!instance_exists(_unit.defendTarget)) {
        _machine.ChangeState("guard");
        return;
    }

    var _waypoints = _machine.data.waypoints;
    var _idx       = _machine.data.waypointIndex;
    var _target    = _waypoints[_idx];

    // Advance to the next corner once close enough.
    if (_unit.agent.pos.Distance(_target) < DEFEND_WAYPOINT_REACH) {
        _machine.data.waypointIndex = (_idx + 1) mod array_length(_waypoints);
        _target = _waypoints[_machine.data.waypointIndex];
    }

    var _obstacles = GatherNearbyObstacles(_unit);

    _unit.controller.Begin();
    _unit.controller.Add(Steering_Arrive(_unit.agent, _target, DEFEND_ARRIVE_RADIUS), 1.2);
    _unit.controller.Add(Steering_AvoidObstacles(_unit.agent, _obstacles, 80),        1.8);
    _unit.controller.Add(
        Steering_Contain(_unit.agent, global.playAreaRect, PLAY_AREA_CONTAIN_MARGIN),
        PLAY_AREA_CONTAIN_WEIGHT
    );

    var _delta = _unit.controller.Apply();
    with(_unit){
        move_and_collide(_delta.x, _delta.y, [oBuildingParent, oEnvironmentSolid]);
    }
    _unit.agent.SyncFromInstance(_unit);

    UnitUpdateSprite(_unit);
}

/// @function Defend_Exit(_unit, _machine)
/// @description StateMachine onExit for "defend". Clears defendTarget so it
///        doesn't linger if the unit re-enters a different defend assignment later.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Defend_Exit(_unit, _machine) {
    // Clear the stored waypoints and target so they don't linger if the
    // unit re-enters a different defend assignment later.
    _unit.defendTarget = noone;
}
