#macro UNIT_OBSTACLE_LOOK_RADIUS 140 // how far out a unit checks for buildings/environment to avoid -- was 96 (2026-07-06); that left barely any margin beyond Steering_AvoidObstacles' own feeler length (up to 80, more for a longer siege-march feeler -- see UnitPursueTarget), so obstacles were only ever spotted right at the tip of the feeler with almost no room to steer around them smoothly. Widening this doesn't change avoidance LOGIC, just how early an obstacle is seen -- part of the 2026-07-06 fix for siege units getting caught on buildings en route to the castle.

/// @function GatherNearbyObstacles(_unit, _radius)
/// Gathers nearby buildings and environment solids into the
/// { pos, radius } struct shape Steering_AvoidObstacles expects.
/// Buildings of the unit's OWN team are excluded -- a unit shouldn't
/// treat its own castle/barracks as an obstacle to steer around;
/// environment solids have no team and are always included.
///
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
/// @desc Get the opposing team's Castle instance for a given unit.
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
/// @desc _team's OWN castle instance -- the inverse of GetEnemyCastle above,
///       which takes a UNIT and returns the OPPOSING side's castle. This
///       takes a TEAM directly and returns that same team's castle. Added
///       2026-07-06 for AI castle-defense threat detection
///       (AI_CastleUnderThreat, AIControl.gml), which needs to check
///       proximity to a team's own castle rather than the enemy's.
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
/// @description SUPERSEDED -- no longer called anywhere as of ChooseCombatTarget
///        below, which folds this function's castle-weighting in as an optional
///        axis (pass _castlePos) alongside health/attack/proximity/activity.
///        Left in place rather than deleted -- flag before removing outright,
///        in case something still wants a pure distance-only castle-weighted
///        pick without the rest of ChooseCombatTarget's criteria.
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

// -----------------------------------------------------------
// Room-wide queries -- for high-level decision-making (currently
// just the AI controller), as opposed to the radius-limited
// steering/aggro queries above. Centralizing "what can team X see"
// here means that when fog of war extends past castle walls (once
// building placement ships), a visibility filter only needs to be
// added in these functions rather than at every call site.
// -----------------------------------------------------------

/// @function GatherTeamUnits(_team)
/// @description Every oUnitParent instance belonging to _team, anywhere in the
///        room. No fog-of-war filtering yet -- the only currently-hidden area is
///        inside castle walls, and nothing spawns there yet, so every unit is
///        visible to everyone. See file header for where that filter will go.
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
/// @description SUPERSEDED -- no longer called anywhere as of ChooseCombatTarget
///        below, which replaces every call site this fed (Guard_Step,
///        Defend_Step, Attack_Step, AttackRanged_Step) with a weighted pick.
///        Left in place rather than deleted -- flag before removing outright,
///        in case something still wants a plain nearest-enemy lookup with no
///        weighting at all.
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

// -----------------------------------------------------------
// Weighted combat target selection -- ChooseCombatTarget replaces the old
// "always returns noone" stub that used to live in UnitScripts.gml (moved
// here to sit next to the two functions it supersedes). Unifies every
// previous unweighted "just grab the nearest enemy" pick
// (_FindNearestEnemy/_FindNearestEnemyInSweep above) into one real,
// tunable decision.
//
// Called wherever combat/attack/siege need to pick which enemy UNIT to
// fight: entering "combat"/"combatRanged" and re-acquiring when the current
// target dies (Combat_Step/CombatRanged_Step -- already wired to call this),
// the defender-interrupt in "attack"/"attackRanged" (Attack_Step/
// AttackRanged_Step), the aggro trigger in "guard"/"defend" (Guard_Step/
// Defend_Step), and the guard-sweep in "siege" (Siege_Step). NOT used for
// picking what BUILDING or CASTLE to attack -- that's still player-order-
// driven (attackBuildingTarget) or GetEnemyCastle(), untouched.
//
// Weights below are placeholders, per instruction -- tune freely, nothing
// else depends on these specific numbers. Health/proximity/castle are
// normalized 0..1 before weighting; attackDamage is NOT normalized (its raw
// value is multiplied by its weight directly) -- fine for a first-pass
// placeholder since every candidate is compared on the same combined scale,
// but flag if you'd rather every axis were normalized to 0..1 for easier
// tuning later.
// -----------------------------------------------------------

#macro COMBAT_TARGET_WEIGHT_HEALTH    1.0  // rewards LOW health remaining (damageTaken / maxHealth) -- finish off the wounded
#macro COMBAT_TARGET_WEIGHT_ATTACK    0.4  // rewards HIGH attackDamage (raw stat, not normalized) -- focus the biggest threat
#macro COMBAT_TARGET_WEIGHT_PROXIMITY 1.2  // rewards closeness to the deciding unit
#macro COMBAT_TARGET_WEIGHT_ACTIVITY  1.0  // rewards a candidate currently attacking one of ours -- castle > building > unit > idle
#macro COMBAT_TARGET_WEIGHT_CASTLE    0.8  // siege-only: rewards closeness to the castle being sieged -- only applied when _castlePos is passed; preserves what _FindNearestEnemyInSweep used to do for "siege" specifically

/// @function _CombatTargetActivityScore(_candidate)
/// @description Scores what _candidate is currently doing -- the "whether
///        it is attacking a unit, building, or castle" criterion.
///        Sieging our castle scores highest (the biggest threat), then
///        attacking one of our buildings, then already fighting one of our
///        units, then idle (guard/defend) scores 0. Only ever called with
///        an oUnitParent instance (everything that reaches it comes from a
///        collision_circle_list against oUnitParent), so .fsm always exists.
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
/// @description Picks the best enemy unit within _radius for _unit to fight,
///        scoring every candidate on four weighted criteria: how low its
///        health is, how high its attackDamage is, how close it is, and
///        what it's currently attacking (see _CombatTargetActivityScore).
///        Returns noone if no enemy unit is in range -- same contract the
///        old stub and _FindNearestEnemy both had, so every caller's
///        existing "if (_unit.combatTarget == noone)" check keeps working
///        unchanged.
/// @param {Id.Instance} _unit
/// @param {Real} [_radius] Search radius around _unit. Defaults to
///        _unit.attackAggroRadius (same idiom as UnitPursueTarget's
///        _targetVelocity default -- can't reference _unit directly in the
///        parameter list itself, so it's resolved in the body instead).
/// @param {Struct.Vector2} [_castlePos] Pass the castle being sieged to also
///        weight closeness-to-castle (COMBAT_TARGET_WEIGHT_CASTLE) --
///        Siege_Step is the only caller that should ever pass this.
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
        var _c = _list[| i]