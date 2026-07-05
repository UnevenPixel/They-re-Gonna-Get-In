/// @function ApplyDamage(_target, _amount, _source)
/// @description The one real damage-application function in the codebase --
///        both melee (UnitTryDealDamage below) and ranged (ProjectileResolveHit,
///        ProjectileScripts.gml) route through this rather than touching
///        health directly. Works against units AND buildings -- both carry
///        maxHealth + damageTaken now (units via UnitApplyDefinition,
///        buildings via BuildingApplyDefinition; see GetDamageTaken,
///        UnitDefinitions.gml, for where each actually stores it).
///
///        Damage is tracked ONLY as damageTaken, never as a separate
///        "current health" field -- maxHealth can change later (a future
///        buff/debuff, a station/redeploy swap reapplying a UnitDefinition)
///        without also having to rewrite a second number in lockstep.
///        GetCurrentHealth (UnitDefinitions.gml) always derives the live
///        value fresh from maxHealth - damageTaken, so there's exactly one
///        source of truth. damageTaken is clamped to maxHealth here so it
///        can never overshoot into "more dead than dead."
///
///        Destroys _target the instant its health reaches 0 -- this is the
///        first place in the codebase anything can actually die. Also
///        closes the loop on AnalyticsRecordKill/AnalyticsRecordDeath
///        (AnalyticsScripts.gml), which existed already but had no death
///        event to call them from.
///
///        Non-lethal hits also drive "combat"'s reactive-on-hit trigger
///        (per design: combat is an interim state guard/defend pop into
///        when they need to fight, alongside the proximity-aggro trigger in
///        Guard_Step/Defend_Step) -- see UnitEnterCombat below. Only fires
///        if _target is a unit (has an fsm -- buildings don't) currently in
///        "guard" or "defend"; a unit already fighting (attack,
///        attackRanged, siege, combat, combatRanged) just keeps doing what
///        it was doing.
/// @param {Id.Instance} _target
/// @param {Real} _amount
/// @param {Id.Instance} [_source] The attacking unit, for kill-credit via
///        AnalyticsRecordKill and as the reactive-on-hit combat target.
///        Optional -- omit if there's no single attributable attacker.
/// @returns {Bool} True if this call killed _target.
function ApplyDamage(_target, _amount, _source = noone) {
    if (!instance_exists(_target)) return false;

    if (!variable_instance_exists(_target, "maxHealth")) {
        show_debug_message($"ApplyDamage: {object_get_name(_target.object_index)} has no maxHealth -- not damageable (check its UnitDefinition/BuildingDefinition).");
        return false;
    }

    SetDamageTaken(_target, min(GetDamageTaken(_target) + _amount, _target.maxHealth));

    if (GetCurrentHealth(_target) > 0) {
        if (_source != noone && instance_exists(_source)
            && variable_instance_exists(_target, "fsm")
            && (_target.fsm.Is("guard") || _target.fsm.Is("defend"))) {
            UnitEnterCombat(_target, _source);
        }
        return false;
    }

    AnalyticsRecordDeath(_target.team, _target.object_index);
    if (_source != noone && instance_exists(_source) && variable_instance_exists(_source, "team")) {
        AnalyticsRecordKill(_source.team, _source.object_index);
    }

    instance_destroy(_target);
    return true;
}

/// @function UnitEnterCombat(_unit, _target)
/// @description Shared entry point for both of combat's designed triggers:
///        proximity aggro (Guard_Step/Defend_Step, checked every step via
///        _FindNearestEnemy) and reactive-on-hit (ApplyDamage above, the
///        instant a guarding/defending unit takes damage). Picks "combat"
///        or "combatRanged" (UnitStateCombatRanged.gml) based on the unit's
///        "ranged" tag -- same UnitHasTag dispatch the "attack" order uses
///        (OrderWiring.gml) to pick "attack" vs "attackRanged".
/// @param {Id.Instance} _unit
/// @param {Id.Instance} _target
function UnitEnterCombat(_unit, _target) {
    _unit.combatTarget = _target;
    var _state = UnitHasTag(_unit, "ranged") ? "combatRanged" : "combat";
    _unit.fsm.ChangeState(_state);
}

/// @function UnitRevertFromCombat(_machine)
/// @description Shared "combat/combatRanged is done -- go back to whatever
///        guard/defend was interrupted" exit path. Combat is only ever
///        entered via UnitEnterCombat, called from guard/defend, so
///        _machine.previousName is always "guard" or "defend" at that point
///        -- RevertToPrevious (StateMachine.gml) goes back to exactly that.
///        Falls back to "guard" in the (should-never-happen) case combat
///        was somehow entered with no recorded previous state, so a unit
///        can never get stuck in combat forever with nowhere to revert to.
/// @param {Struct.StateMachine} _machine
function UnitRevertFromCombat(_machine) {
    if (_machine.previousName != undefined) {
        _machine.RevertToPrevious();
    } else {
        _machine.ChangeState("guard");
    }
}

/// @function UnitTryDealDamage(_unit, _target, _machine)
/// Attempts to deal damage at the correct animation frame.
/// Guards against multiple hits per swing via _machine.data.hitDealtThisSwing.
/// Returns true the frame the hit lands, false every other frame.
///
/// @param {Id.Instance} _unit
/// @param {Id.Instance} _target Any instance with maxHealth (unit or building).
/// @param {Struct}      _machine
/// @returns {Bool}
function UnitTryDealDamage(_unit, _target, _machine) {
    if (_machine.data.hitDealtThisSwing) return false;

    var _currentFrame = floor(_unit.image_index);
    if (_currentFrame < _unit.attackHitFrame) return false;

    _machine.data.hitDealtThisSwing = true;

    if (!instance_exists(_target)) return false;

    ApplyDamage(_target, _unit.attackDamage, _unit);

    // Knockback (units only, buildings don't move) -- not implemented,
    // left as the same suggestion this TODO always had:
    //   if (object_is_ancestor(_target.object_index, oUnitParent)) {
    //       var _dir = Vector2FromAngle(_unit.agent.pos.AngleTo(
    //           new Vector2(_target.x, _target.y)), 1);
    //       _target.agent.ApplyKnockback(_dir.Scale(knockbackStrength));
    //   }

    return true;
}

/// @function UnitTryFireProjectile(_unit, _target, _machine)
/// @description Ranged counterpart to UnitTryDealDamage -- same
///        once-per-swing / hit-frame gating (_machine.data.hitDealtThisSwing,
///        _unit.attackHitFrame), but spawns a projectile (SpawnProjectile,
///        ProjectileScripts.gml) aimed at _target instead of applying
///        damage immediately. Damage resolves later, when the projectile
///        arrives (ProjectileResolveHit) -- not the frame this returns true.
/// @param {Id.Instance} _unit
/// @param {Id.Instance} _target
/// @param {Struct}      _machine
/// @returns {Bool} True the frame the shot is fired, false every other frame.
function UnitTryFireProjectile(_unit, _target, _machine) {
    if (_machine.data.hitDealtThisSwing) return false;

    var _currentFrame = floor(_unit.image_index);
    if (_currentFrame < _unit.attackHitFrame) return false;

    _machine.data.hitDealtThisSwing = true;

    if (!instance_exists(_target)) return false;

    SpawnProjectile(_unit, _target);

    return true;
}

/// @function UnitAttackAnimComplete(_unit)
/// Returns true when the current attack animation has fully played through.
/// @param {Id.Instance} _unit
/// @returns {Bool}
function UnitAttackAnimComplete(_unit) {
    return _unit.image_index >= sprite_get_number(_unit.sprAttack) - 1;
}

/// @function UnitPursueTarget(_unit, _targetPos, _targetVelocity)
/// Standard pursue + separation + obstacle avoidance + play area containment.
/// Reused across combat/attack/siege/defend pursuit phases.
/// Calls UnitUpdateSprite after movement so sprite and facing are always
/// current without each state needing to do it explicitly.
///
/// @param {Id.Instance}    _unit
/// @param {Struct.Vector2} _targetPos
/// @param {Struct.Vector2} [_targetVelocity] Pass undefined/Vector2(0,0) for stationary targets.
function UnitPursueTarget(_unit, _targetPos, _targetVelocity = undefined) {
    _targetVelocity ??= new Vector2(0, 0);

    var _obstacles = GatherNearbyObstacles(_unit);
    var _allies    = GatherNearbyAllies(_unit, 48);

    _unit.controller.Begin();
    _unit.controller.Add(
        Steering_Pursue(_unit.agent, _targetPos, _targetVelocity), 1.2
    );
    _unit.controller.Add(Steering_Separation(_unit.agent, _allies, 28),        1.0);
    _unit.controller.Add(Steering_AvoidObstacles(_unit.agent, _obstacles, 80), 1.8);
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

/// @function UnitIdleInPlace(_unit)
/// Idles in place this frame (zero steering, still applies knockback
/// and collision). Calls UnitUpdateSprite so a standing unit still
/// shows the correct idle sprite after a hit reaction.
/// @param {Id.Instance} _unit
function UnitIdleInPlace(_unit) {
    _unit.controller.Begin();
    var _delta = _unit.controller.Apply();
    with(_unit){
        move_and_collide(_delta.x, _delta.y, [oBuildingParent, oEnvironmentSolid]);
    }
    _unit.agent.SyncFromInstance(_unit);
    UnitUpdateSprite(_unit);
}

/// @function UnitBeginSwing(_unit, _machine)
/// Enters the attack animation on a unit and resets swing tracking.
/// @param {Id.Instance} _unit
/// @param {Struct}      _machine
function UnitBeginSwing(_unit, _machine) {
    _machine.data.hitDealtThisSwing = false;
    _unit.sprite_index = _unit.sprAttack;
    _unit.image_index  = 0;
    _unit.image_speed  = global.matchSpeed;
    // Do NOT touch image_xscale here -- the unit should keep facing
    // the direction it was already facing when the swing started.
}

/// @function UnitEndSwing(_unit, _machine)
/// Restores idle sprite and writes cooldown back to the instance.
/// Call at the end of any swing and from all Exit callbacks.
/// @param {Id.Instance} _unit
/// @param {Struct}      _machine
function UnitEndSwing(_unit, _machine) {
    _unit.sprite_index = _unit.sprIdle;
    _unit.image_index  = 0;
    _unit.image_speed  = global.matchSpeed;
    _unit.attackCooldown = max(_machine.data.cooldownTimer, 0);
}
