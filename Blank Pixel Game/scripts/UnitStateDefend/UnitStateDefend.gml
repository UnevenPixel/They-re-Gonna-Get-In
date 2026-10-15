// FSM state "defend" -- patrol a building's (or castle's) perimeter, fighting
// off anything that wanders into aggro range. FLAGGED/load-bearing state
// file. See UnitStateDefend.md.

#macro DEFEND_BUILDING_HALF  24   // half of 48x48
#macro DEFEND_PATROL_MARGIN  16    // how far outside the building edge the patrol path sits
#macro DEFEND_WAYPOINT_REACH 12   // how close the unit needs to get before advancing to next waypoint
#macro DEFEND_ARRIVE_RADIUS  16   // Steering_Arrive slow-down zone -- tightened alongside DEFEND_PATROL_MARGIN, see .md

/// @function DefendBuildingWaypoints(_building)
/// @description Builds the four patrol corner waypoints around a building.
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
/// @description Returns the index of whichever waypoint in _waypoints is closest to _pos. Used on entry to pick up the patrol from the nearest corner rather than always snapping to corner 0.
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

/// @function Defend_Enter(_unit, _machine)
/// @description StateMachine onEnter for "defend". Falls back to "guard" if the target is already gone; otherwise builds the patrol waypoints and picks up the patrol from whichever waypoint is nearest the unit. Handles both building and castle targets -- see .md.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Defend_Enter(_unit, _machine) {
    if (!instance_exists(_unit.defendTarget)) {
        // Target was destroyed before the unit arrived -- fall back.
        _machine.ChangeState("guard");
        return;
    }

    var _target    = _unit.defendTarget;
    var _isCastle  = !object_is_ancestor(_target.object_index, oBuildingParent);
    var _waypoints = _isCastle ? CastleDefendWaypoints(_target) : DefendBuildingWaypoints(_target);

    _machine.data.waypoints     = _waypoints;
    _machine.data.waypointIndex = NearestWaypointIndex(
        _unit.agent.pos,
        _waypoints
    );
}

/// @function Defend_Step(_unit, _machine)
/// @description StateMachine onStep for "defend". Patrols the waypoints via Steering_Arrive, advancing to the next one once close enough. Falls back to "guard" if the target is destroyed mid-patrol. Proximity-aggro check runs first, every step -- see .md.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Defend_Step(_unit, _machine) {
    // Proximity aggro -- highest priority, checked before anything else.
    var _enemy = ChooseCombatTarget(_unit, _unit.attackAggroRadius);
    if (_enemy != noone) {
        UnitEnterCombat(_unit, _enemy);
        return;
    }

    // Target could be destroyed mid-patrol -- bail out gracefully.
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

    // oBuildingParent deliberately excluded -- units only hard-collide with
    // oEnvironmentSolid. The building being defended is never in this list
    // to begin with. See .md.
    var _delta = _unit.controller.Apply();
    with(_unit){
        move_and_collide(_delta.x, _delta.y, [oEnvironmentSolid]);
    }
    _unit.agent.SyncFromInstance(_unit);

    UnitUpdateSprite(_unit);
}

/// @function Defend_Exit(_unit, _machine)
/// @description StateMachine onExit for "defend". Deliberately does NOT touch defendTarget -- do not add `_unit.defendTarget = noone` here. It previously did, which broke reassigning a defending unit to a new target and broke defend surviving a combat interruption. Full bugfix writeup in UnitStateDefend.md -- read it before changing this function.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Defend_Exit(_unit, _machine) {
    // Intentionally empty -- see doc comment above and .md.
}
