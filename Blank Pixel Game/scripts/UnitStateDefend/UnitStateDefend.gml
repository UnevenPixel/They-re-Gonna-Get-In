#macro DEFEND_BUILDING_HALF  24   // half of 48x48
#macro DEFEND_PATROL_MARGIN  16    // how far outside the building edge the patrol path sits -- tightened from 20, 2026-07-06 ("4 px should look better")
#macro DEFEND_WAYPOINT_REACH 12   // how close the unit needs to get before advancing to next waypoint
#macro DEFEND_ARRIVE_RADIUS  16   // Steering_Arrive slow-down zone -- was 48, tightened alongside DEFEND_PATROL_MARGIN: the old value was nearly as big as the entire corner-to-corner patrol leg at the new, much smaller margin, which would have kept units decelerating for almost the whole loop instead of ever reaching a normal patrol speed

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
///        target is already gone; otherwise builds the patrol waypoints and
///        picks up the patrol from whichever waypoint is nearest the unit.
///        2026-07-06: _unit.defendTarget can now also be a castle
///        (oPlayerCastle/oEnemyCastle, AI_CastleDefense_Step in AIControl.gml)
///        -- neither is an oBuildingParent descendant (parentObjectId: null),
///        so !object_is_ancestor(..., oBuildingParent) reliably tells the two
///        apart without hardcoding either castle object name here. A castle
///        gets CastleDefendWaypoints (patrol spread along its actual front
///        wall, CastleScripts.gml) instead of DefendBuildingWaypoints' 4-corner
///        box, which assumes a 48x48 building and would be wrong for a
///        350x411 castle.
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
/// @description StateMachine onStep for "defend". Patrols the building's four
///        corner waypoints via Steering_Arrive, advancing to the next corner once
///        close enough. Falls back to "guard" if the building is destroyed mid-patrol.
///        Proximity-aggro check runs first, every step -- same "combat" is
///        an interim state defend pops into when it needs to fight pattern
///        as Guard_Step; see UnitEnterCombat (UnitCombatHelpers.gml).
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Defend_Step(_unit, _machine) {
    // -----------------------------------------------------------
    // Proximity aggro -- highest priority, checked before anything else.
    // -----------------------------------------------------------

    var _enemy = ChooseCombatTarget(_unit, _unit.attackAggroRadius);
    if (_enemy != noone) {
        UnitEnterCombat(_unit, _enemy);
        return;
    }

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

    var _obstacles = G