#macro GUARD_ARRIVE_RADIUS    40  // deceleration zone around each waypoint
#macro GUARD_ARRIVE_THRESHOLD 24  // distance at which the unit is considered "arrived"
#macro GUARD_WAIT_MIN         90  // minimum idle frames at a waypoint (~1.5s at 60fps)
#macro GUARD_WAIT_MAX         240 // maximum idle frames at a waypoint (~4s at 60fps)
#macro GUARD_EDGE_PADDING     24  // keeps waypoints away from the rect edges
#macro GUARD_MIN_SEPARATION   40  // minimum distance between any two claimed waypoints
#macro GUARD_PICK_RETRIES     8   // how many times to retry before giving up and
                                  // accepting a slightly-occupied point rather than
                                  // leaving the unit unable to find anywhere to go

/// Picks a random point inside _rect that isn't already claimed by
/// another waiting ally. Retries up to GUARD_PICK_RETRIES times;
/// returns the best candidate found even if all retries hit conflicts.
///
/// Claimed positions are read from nearby units' `guardWaypointClaimed`
/// variable, which every guard unit writes to itself when it picks a
/// waypoint and clears on Guard_Exit.
///
/// @function GuardPickWaypoint(_unit, _rect)
/// @param {Id.Instance} _unit   The unit picking the waypoint (excluded
///                              from its own conflict check).
/// @param {Struct} _rect        { x1, y1, x2, y2 }
/// @returns {Struct.Vector2}
function GuardPickWaypoint(_unit, _rect) {
    var _pad      = GUARD_EDGE_PADDING;
    var _best     = undefined;
    var _bestDist = 0; // furthest minimum-distance-to-any-claim found so far

    // Gather claimed waypoints from nearby allies once, outside the
    // retry loop, so we're not re-querying the collision list every attempt.
    var _claimed = [];
    var _list    = ds_list_create();
    var _count   = collision_rectangle_list(
        _rect.x1, _rect.y1, _rect.x2, _rect.y2,
        oUnitParent, false, true, _list, false
    );
    for (var i = 0; i < _count; i++) {
        var _other = _list[| i];
        if (_other == _unit) continue;
        // Room-start instance-creation-order hazard: all room-placed instances
        // exist before any of their Create events run, so a sibling found here
        // may not have reached `team = TEAM.PLAYER/ENEMY;` in its own Create yet.
        // Treat it as "not a valid ally to check" rather than crash.
        if (!variable_instance_exists(_other, "team")) continue;
        if (_other.team != _unit.team) continue;
        if (!variable_instance_exists(_other, "guardWaypointClaimed")) continue;
        // Defensive: guardWaypointClaimed can legitimately be `undefined`
        // between a unit's own Create running and Guard_Enter assigning it
        // a real Vector2. Skip anything that isn't an actual struct rather
        // than trusting the value blindly.
        if (!is_struct(_other.guardWaypointClaimed)) continue;
        array_push(_claimed, _other.guardWaypointClaimed);
    }
    ds_list_destroy(_list);

    // Retry loop: find the candidate furthest from all existing claims.
    repeat (GUARD_PICK_RETRIES) {
        var _candidate = new Vector2(
            random_range(_rect.x1 + _pad, _rect.x2 - _pad),
            random_range(_rect.y1 + _pad, _rect.y2 - _pad)
        );

        // Find the minimum distance from this candidate to any claimed point.
        var _minDist = infinity;
        for (var i = 0; i < array_length(_claimed); i++) {
            var _d = _candidate.Distance(_claimed[i]);
            if (_d < _minDist) _minDist = _d;
        }

        // No claims at all -- first candidate is always fine.
        if (_minDist == infinity) {
            _best = _candidate;
            break;
        }

        // Keep whichever candidate is furthest from its nearest claim
        // (maximises separation across all retries).
        if (_minDist > _bestDist) {
            _bestDist = _minDist;
            _best     = _candidate;
        }

        // Early exit: this candidate is comfortably clear of everyone.
        if (_minDist >= GUARD_MIN_SEPARATION) break;
    }

    return _best;
}

// -----------------------------------------------------------
// guard
// -----------------------------------------------------------

/// @function Guard_Enter(_unit, _machine)
/// @description StateMachine onEnter for "guard". Initializes the waypoint claim
///        so other units can safely read it, then picks the unit's first waypoint.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Guard_Enter(_unit, _machine) {
    // Initialise the claim variable so other units can always safely
    // read it, even before this unit has picked its first waypoint.
    _unit.guardWaypointClaimed = new Vector2(_unit.x, _unit.y);

    _machine.data.waypoint  = GuardPickWaypoint(_unit, _unit.guardRect);
    _unit.guardWaypointClaimed = _machine.data.waypoint;
    _machine.data.waiting   = false;
    _machine.data.waitTimer = 0;
}

/// @function Guard_Step(_unit, _machine)
/// @description StateMachine onStep for "guard". Alternates between waiting at
///        the current waypoint (random dwell time) and steering toward it once a
///        new one is picked; releases the old waypoint claim when arriving.
///        Proximity-aggro check runs first, every step: "combat" was
///        designed as an interim state guard pops into when it needs to
///        fight (see UnitEnterCombat, UnitCombatHelpers.gml) -- the other
///        trigger, reactive-on-hit, lives in ApplyDamage instead, since it
///        needs to fire the instant damage lands, not once per step.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Guard_Step(_unit, _machine) {
    // -----------------------------------------------------------
    // Proximity aggro -- highest priority, checked before anything else.
    // -----------------------------------------------------------

    var _enemy = ChooseCombatTarget(_unit, _unit.attackAggroRadius);
    if (_enemy != noone) {
        UnitEnterCombat(_unit, _enemy);
        return;
    }

    // -----------------------------------------------------------
    // Waiting at a waypoint
    // -----------------------------------------------------------

    if (_machine.data.waiting) {
        _machine.data.waitTimer -= global.matchSpeed; // 0 at matchSpeed 0 -- wait freezes instead of ticking down during a pause

        // Stand still while waiting -- UnitIdleInPlace still applies
        // knockback and collision so the unit isn't frozen solid if hit.
        UnitIdleInPlace(_unit);

        if (_machine.data.waitTimer <= 0) {
            // Pick a new waypoint, avoiding spots already claimed by allies.
            _machine.data.waypoint     = GuardPickWaypoint(_unit, _unit.guardRect);
            _unit.guardWaypointClaimed = _machine.data.waypoint;
            _machine.data.waiting      = false;
        }

        return;
    }

    // -----------------------------------------------------------
    // Moving toward the current waypoint
    // -----------------------------------------------------------

    var _dist = _unit.agent.pos.Distance(_machine.data.waypoint);

    if (_dist < GUARD_ARRIVE_THRESHOLD) {
        // Arrived -- kill any residual velocity so the unit doesn't
        // keep nudging back and forth around the waypoint during the wait.
        _unit.agent.velocity.Set(0, 0);
        _machine.data.waiting   = true;
        _machine.data.waitTimer = irandom_range(GUARD_WAIT_MIN, GUARD_WAIT_MAX);
        UnitIdleInPlace(_unit);
        return;
    }

    var _obstacles = GatherNearbyObstacles(_unit);
    var _allies = GatherNearbyAllies(_unit,64);

    _unit.controller.Begin();
    _unit.controller.Add(
        Steering_Arrive(_unit.agent, _machine.data.waypoint, GUARD_ARRIVE_RADIUS),
        1.0
    );
    _unit.controller.Add(
        Steering_AvoidObstacles(_unit.agent, _obstacles, 80),
        1.8
    );
    
    _unit.controller.Add(
        Steering_Separation(_unit.agent, _allies, 8),
        0.4
    );
    _unit.controller.Add(
        Steering_Contain(_unit.agent, _unit.guardRect, 8),
        1.5
    );
    _unit.controller.Add(
        Steering_Contain(_unit.agent, global.playAreaRect, PLAY_AREA_CONTAIN_MARGIN),
        PLAY_AREA_CONTAIN_WEIGHT
    );

    // oBuildingParent dropped from this collision list, 2026-07-06 --
    // units no longer physically collide with buildings, only with real
    // static geometry (oEnvironmentSolid). Steering_AvoidObstacles above
    // still sees buildings (GatherNearbyObstacles, GatherScripts.gml, is
    // unchanged) and steers around them cosmetically; a unit can now clip
    // through one if avoidance doesn't fully route around it, which is
    // accepted as harmless per that request.
    var _delta = _unit.controller.Apply();
    with(_unit){
        move_and_collide(_delta.x, _delta.y, [oEnvironmentSolid]);
    }
    _unit.agent.SyncFromInstance(_unit);

    UnitUpdateSprite(_unit);
}

/// @function Guard_Draw(_unit, _machine)
/// @description StateMachine onDraw for "guard". Debug visualization -- shows the
///        waiting flag and a line to the current waypoint.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Guard_Draw(_unit,_machine){
    
}

/// @function Guard_Exit(_unit, _machine)
/// @description StateMachine onExit for "guard". Releases the claimed waypoint so
///        it's no longer counted as occupied for other units picking a position.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Guard_Exit(_un