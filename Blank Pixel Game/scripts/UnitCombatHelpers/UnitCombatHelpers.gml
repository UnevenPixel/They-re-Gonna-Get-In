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
///        was s