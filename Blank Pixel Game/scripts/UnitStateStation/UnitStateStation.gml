// FSM state "station" -- walk to the team's own castle front edge, then
// convert into a garrisoned oUnitStationed. FLAGGED/load-bearing state file.
// See UnitStateStation.md.

#macro STATION_GATE_REACH 12 // how close to the castle's front edge before the unit transforms into oUnitStationed -- mirrors DEFEND_WAYPOINT_REACH

/// @function Station_Enter(_unit, _machine)
/// @description StateMachine onEnter for "station". Falls back to "guard" if _unit's own team has no castle on the board; otherwise stores the castle for Station_Step to walk toward.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Station_Enter(_unit, _machine) {
    var _castle = GetTeamCastle(_unit.team);
    if (!instance_exists(_castle)) {
        // No castle found -- nothing to station at.
        _machine.ChangeState("guard");
        return;
    }

    _machine.data.castle = _castle;

    _unit.sprite_index = _unit.sprIdle;
    _unit.image_index  = 0;
    _unit.image_speed  = global.matchSpeed;
}

/// @function Station_Step(_unit, _machine)
/// @description StateMachine onStep for "station". Walks _unit toward its own castle's front edge (same CastleFrontEdgePoint target siege uses against the enemy castle); once within STATION_GATE_REACH, hands off to UnitBecomeStationed and stops -- that call destroys _unit, so nothing after it may touch _unit again.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Station_Step(_unit, _machine) {
    if (!instance_exists(_machine.data.castle)) {
        // Castle destroyed mid-march -- nowhere left to station.
        _machine.ChangeState("guard");
        return;
    }

    var _edgePos    = CastleFrontEdgePoint(_machine.data.castle, _unit.agent.pos);
    var _distToEdge = _unit.agent.pos.Distance(_edgePos);

    if (_distToEdge <= STATION_GATE_REACH) {
        UnitBecomeStationed(_unit); // destroys _unit -- see StationScripts.gml
        return;
    }

    // Same longer obstacle-avoidance feeler Siege_Step's ADVANCE phase uses
    // -- see .md.
    UnitPursueTarget(_unit, _edgePos, new Vector2(0, 0), 120);
}
