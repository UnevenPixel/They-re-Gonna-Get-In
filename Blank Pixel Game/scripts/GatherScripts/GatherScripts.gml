#macro UNIT_OBSTACLE_LOOK_RADIUS 96 // how far out a unit checks for buildings/environment to avoid

/// Gathers nearby buildings and environment solids into the
/// { pos, radius } struct shape Steering_AvoidObstacles expects.
/// Buildings of the unit's OWN team are excluded -- a unit shouldn't
/// treat its own castle/barracks as an obstacle to steer around;
/// environment solids have no team and are always included.
///
/// @param {Id.Instance} _unit
/// @param {Real} [_radius]
/// @return {Array<Struct>} Array of { pos: Vector2, radius: Real }
function GatherNearbyObstacles(_unit, _radius = UNIT_OBSTACLE_LOOK_RADIUS) {
    var _result = [];

    var _buildingList = ds_list_create();
    var _buildingCount = collision_circle_list(_unit.x, _unit.y, _radius, oBuildingParent, false, true, _buildingList, false);
    for (var i = 0; i < _buildingCount; i++) {
        var _b = _buildingList[| i];
        array_push(_result, { pos: new Vector2(_b.x, _b.y), radius: _b.radius });
    }
    ds_list_destroy(_buildingList);

    var _envList = ds_list_create();
    var _envCount = collision_circle_list(_unit.x, _unit.y, _radius, oEnvironmentSolid, false, true, _envList, false);
    for (var i = 0; i < _envCount; i++) {
        var _e = _envList[| i];
        array_push(_result, { pos: new Vector2(_e.x, _e.y), radius: _e.radius });
    }
    ds_list_destroy(_envList);

    return _result;
}


/// @param {Id.Instance} _unit
/// @param {Real} [_radius]
/// @return {Array<Struct.SteeringAgent>}
function GatherNearbyAllies(_unit, _radius = 48) {
    var _result = [];
    var _list   = ds_list_create();
    var _count  = collision_circle_list(_unit.x, _unit.y, _radius, oUnitParent, false, true, _list, false);

    for (var i = 0; i < _count; i++) {
        var _other = _list[| i];
        if (_other == _unit) continue;
        if (_other.team != _unit.team) continue;
        array_push(_result, _other.agent);
    }

    ds_list_destroy(_list);
    return _result;
}

/// @function GetEnemyCastle(_team)
/// @desc Get the opposing teams Castle Instance to Return
function GetEnemyCastle(_unit){
    if _unit.team = "player"{
        return instance_find(oEnemyCastle,0);
    }
    else{
        return instance_find(oPlayerCastle,0);
    }
}

/// @param {Id.Instance}    _unit
/// @param {Struct.Vector2} _castlePos
/// @param {Real}           _radius
/// @return {Id.Instance|Constant.NoOne}
function _FindNearestEnemyInSweep(_unit, _castlePos, _radius) {
    var _list  = ds_list_create();
    var _count = collision_circle_list(
        _unit.x, _unit.y, _radius, oUnitParent, false, true, _list, false
    );

    var _best      = noone;
    var _bestScore = infinity;

    for (var i = 0; i < _count; i++) {
        var _other = _list[| i];
        if (_other == _unit) continue;
        if (_other.team == _unit.team) continue;

        var _distToUnit   = point_distance(_unit.x, _unit.y, _other.x, _other.y);
        var _distToCastle = point_distance(_other.x, _other.y, _castlePos.x, _castlePos.y);

        // Weighted score: distance to unit matters more than distance
        // to castle (0.7 / 0.3 split). Tune these if you want siege
        // units to prioritise clearing the area around the castle more
        // aggressively vs. just engaging whatever is nearest to them.
        var _score = (_distToUnit * 0.7) + (_distToCastle * 0.3);
        if (_score < _bestScore) {
            _bestScore = _score;
            _best      = _other;
        }
    }

    ds_list_destroy(_list);
    return _best;
}
