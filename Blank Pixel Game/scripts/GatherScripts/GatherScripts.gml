// Spatial query helpers -- nearby obstacles/allies, castle lookups, room-wide
// team queries, and weighted combat target selection. See GatherScripts.md.

#macro UNIT_OBSTACLE_LOOK_RADIUS 140 // how far out a unit checks for buildings/environment to avoid -- see .md re: why this is wider than Steering_AvoidObstacles' own feeler length

/// @function GatherNearbyObstacles(_unit, _radius)
/// @description Gathers nearby buildings and environment solids into the { pos, radius } struct shape Steering_AvoidObstacles expects. Own-team buildings excluded; environment solids always included. See .md.
/// @param {Id.Instance} _unit
/// @param {Real} [_radius]
/// @returns {Array<Struct>} Array of { pos: Vector2, radius: Real }
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

/// @function GatherNearbyAllies(_unit, _radius)
/// @param {Id.Instance} _unit
/// @param {Real} [_radius]
/// @returns {Array<Struct.SteeringAgent>}
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

/// @function GetEnemyCastle(_unit)
/// @description The opposing team's Castle instance for a given unit.
/// @param {Id.Instance} _unit Unit whose team determines which castle counts as "enemy".
/// @returns {Id.Instance} The opposing team's castle instance.
function GetEnemyCastle(_unit){
    if (_unit.team == TEAM.PLAYER) {
        return instance_find(oEnemyCastle,0);
    }
    else{
        return instance_find(oPlayerCastle,0);
    }
}

/// @function GetTeamCastle(_team)
/// @description _team's OWN castle instance -- the inverse of GetEnemyCastle, which takes a unit and returns the opposing side's castle. See .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Id.Instance} _team's own castle instance.
function GetTeamCastle(_team) {
    if (_team == TEAM.PLAYER) {
        return instance_find(oPlayerCastle, 0);
    }
    else {
        return instance_find(oEnemyCastle, 0);
    }
}

/// @function _FindNearestEnemyInSweep(_unit, _castlePos, _radius)
/// @description SUPERSEDED -- no longer called anywhere, replaced by ChooseCombatTarget below. Left in place rather than deleted -- flag before removing. See .md.
/// @param {Id.Instance}    _unit
/// @param {Struct.Vector2} _castlePos
/// @param {Real}           _radius
/// @returns {Id.Instance|Constant.NoOne}
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

        // Weighted score: distance to unit matters more than distance to
        // castle (0.7 / 0.3 split).
        var _score = (_distToUnit * 0.7) + (_distToCastle * 0.3);
        if (_score < _bestScore) {
            _bestScore = _score;
            _best      = _other;
        }
    }

    ds_list_destroy(_list);
    return _best;
}

/// @function GatherTeamUnits(_team)
/// @description Every oUnitParent instance belonging to _team, anywhere in the room. No fog-of-war filtering yet. See .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Array<Id.Instance>}
function GatherTeamUnits(_team) {
    var _result = [];
    with (oUnitParent) {
        if (team == _team) {
            array_push(_result, id);
        }
    }
    return _result;
}

/// @function _FindNearestEnemy(_unit, _radius)
/// @description SUPERSEDED -- no longer called anywhere, replaced by ChooseCombatTarget below. Left in place rather than deleted -- flag before removing. See .md.
/// @param {Id.Instance} _unit
/// @param {Real}        _radius
/// @returns {Id.Instance|Constant.NoOne}
function _FindNearestEnemy(_unit, _radius) {
    var _list  = ds_list_create();
    var _count = collision_circle_list(
        _unit.x, _unit.y, _radius, oUnitParent, false, true, _list, false
    );

    var _best     = noone;
    var _bestDist = infinity;

    for (var i = 0; i < _count; i++) {
        var _other = _list[| i];
        if (_other == _unit) continue;
        if (_other.team == _unit.team) continue;

        var _dist = point_distance(_unit.x, _unit.y, _other.x, _other.y);
        if (_dist < _bestDist) {
            _bestDist = _dist;
            _best     = _other;
        }
    }

    ds_list_destroy(_list);
    return _best;
}

#macro COMBAT_TARGET_WEIGHT_HEALTH    1.0  // rewards LOW health remaining (damageTaken / maxHealth) -- finish off the wounded
#macro COMBAT_TARGET_WEIGHT_ATTACK    0.4  // rewards HIGH attackDamage (raw stat, not normalized) -- focus the biggest threat
#macro COMBAT_TARGET_WEIGHT_PROXIMITY 1.2  // rewards closeness to the deciding unit
#macro COMBAT_TARGET_WEIGHT_ACTIVITY  1.0  // rewards a candidate currently attacking one of ours -- castle > building > unit > idle
#macro COMBAT_TARGET_WEIGHT_CASTLE    0.8  // siege-only: rewards closeness to the castle being sieged -- only applied when _castlePos is passed

/// @function _CombatTargetActivityScore(_candidate)
/// @description Scores what _candidate is currently doing. Only ever called with an oUnitParent instance, so .fsm always exists.
/// @param {Id.Instance} _candidate
/// @returns {Real} 0..1
function _CombatTargetActivityScore(_candidate) {
    switch (_candidate.fsm.Current()) {
        case "siege":        return 1.0;
        case "attack":
        case "attackRanged": return 0.7;
        case "combat":
        case "combatRanged": return 0.3;
        default:             return 0; // guard, defend
    }
}

/// @function ChooseCombatTarget(_unit, _radius, _castlePos)
/// @description Picks the best enemy unit within _radius for _unit to fight, scoring every candidate on weighted health/attack/proximity/activity (+castle proximity if _castlePos given). Returns noone if no enemy unit is in range. See .md.
/// @param {Id.Instance} _unit
/// @param {Real} [_radius] Search radius around _unit. Defaults to _unit.attackAggroRadius (resolved in the body since _unit can't be referenced in the parameter list itself).
/// @param {Struct.Vector2} [_castlePos] Pass the castle being sieged to also weight closeness-to-castle -- Siege_Step is the only caller that should ever pass this.
/// @returns {Id.Instance|Constant.NoOne}
function ChooseCombatTarget(_unit, _radius = undefined, _castlePos = undefined) {
    _radius ??= _unit.attackAggroRadius;

    var _list  = ds_list_create();
    var _count = collision_circle_list(
        _unit.x, _unit.y, _radius, oUnitParent, false, true, _list, false
    );

    var _best      = noone;
    var _bestScore = -infinity;

    for (var i = 0; i < _count; i++) {
        var _c = _list[| i];
        if (_c == _unit) continue;
        if (_c.team == _unit.team) continue;

        var _dist = point_distance(_unit.x, _unit.y, _c.x, _c.y);

        var _healthFrac = (variable_instance_exists(_c, "maxHealth") && _c.maxHealth > 0)
            ? (GetDamageTaken(_c) / _c.maxHealth)
            : 0;
        var _attackStat = variable_instance_exists(_c, "attackDamage") ? _c.attackDamage : 0;
        var _proxScore  = 1 - clamp(_dist / _radius, 0, 1);
        var _activity   = _CombatTargetActivityScore(_c);

        var _score = (_healthFrac * COMBAT_TARGET_WEIGHT_HEALTH)
                   + (_attackStat * COMBAT_TARGET_WEIGHT_ATTACK)
                   + (_proxScore  * COMBAT_TARGET_WEIGHT_PROXIMITY)
                   + (_activity   * COMBAT_TARGET_WEIGHT_ACTIVITY);

        if (_castlePos != undefined) {
            var _distToCastle = point_distance(_c.x, _c.y, _castlePos.x, _castlePos.y);
            var _castleProx   = 1 - clamp(_distToCastle / _radius, 0, 1);
            _score += _castleProx * COMBAT_TARGET_WEIGHT_CASTLE;
        }

        if (_score > _bestScore) {
            _bestScore = _score;
            _best      = _c;
        }
    }

    ds_list_destroy(_list);
    return _best;
}
