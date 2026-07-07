#macro COMBAT_XP_TIER_1        1  // Combat XP per kill, by victim's UnitDefinition.tier -- "XP Age Progression System" doc, 2026-07-06
#macro COMBAT_XP_TIER_2        3
#macro COMBAT_XP_TIER_3        5
#macro COMBAT_XP_STRUCTURE     5  // destroy any enemy building (oBuildingParent)
#macro COMBAT_XP_RESOURCE_BLDG 5  // ADDITIONAL XP on top of COMBAT_XP_STRUCTURE if that building is also an oResourceBuildingParent (+10 total) -- confirmed stacking, 2026-07-06
#macro STRATEGIC_XP_LOSE_UNIT  1  // to the LOSING team, every unit death -- doc's "Lose a unit" line, 2026-07-06

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
///        Resets _target.noDamageTimer to 0 on any hit, lethal or not, if
///        that field exists on it -- generic hook for oPlayerCastle/
///        oEnemyCastle's "no damage for 120s" Defensive XP timer
///        (CastleScripts.gml); harmless no-op for anything else.
///
///        Destroys _target the instant its health reaches 0 -- this is the
///        first place in the codebase anything can actually die. Also
///        closes the loop on AnalyticsRecordKill/AnalyticsRecordDeath
///        (AnalyticsScripts.gml), which existed already but had no death
///        event to call them from, and now awards Combat/Strategic XP (per
///        the 2026-07-06 "XP Age Progression System" doc):
///          - _target is a unit (has "fsm"): the LOSING team (_target.team)
///            gets STRATEGIC_XP_LOSE_UNIT regardless of _source. If _source
///            is a valid, team-tagged killer, its team also gets Combat XP
///            by the victim's UnitDefinition.tier (COMBAT_XP_TIER_1/2/3).
///          - _target is a building (has no "fsm"): if _source is a valid,
///            team-tagged killer, its team gets COMBAT_XP_STRUCTURE, PLUS
///            COMBAT_XP_RESOURCE_BLDG on top if _target is also an
///            oResourceBuildingParent (so destroying a resource building
///            nets +10 total, confirmed stacking).
///        Economic XP ("resource building depletes naturally") is NOT
///        wired here or anywhere -- no depletion mechanic exists yet, see
///        PATCH_NOTES.md.
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
///        AnalyticsRecordKill/Combat XP and as the reactive-on-hit combat
///        target. Optional -- omit if there's no single attributable attacker
///        (Strategic XP for the losing team and structure XP still needs a
///        team to credit though -- no _source means no Combat/Structure XP,
///        just the loss XP for a dead unit).
/// @returns {Bool} True if this call killed _target.
function ApplyDamage(_target, _amount, _source = noone) {
    if (!instance_exists(_target)) return false;

    if (!variable_instance_exists(_target, "maxHealth")) {
        show_debug_message($"ApplyDamage: {object_get_name(_target.object_index)} has no maxHealth -- not damageable (check its UnitDefinition/BuildingDefinition).");
        return false;
    }

    SetDamageTaken(_target, min(GetDamageTaken(_target) + _amount, _target.maxHealth));

    if (variable_instance_exists(_target, "noDamageTimer")) {
        _target.noDamageTimer = 0;
    }

    if (GetCurrentHealth(_target) > 0) {
        if (_source != noone && instance_exists(_source)
            && variable_instance_exists(_target, "fsm")
            && (_target.fsm.Is("guard") || _target.fsm.Is("defend"))) {
            UnitEnterCombat(_target, _source);
        }
        return false;
    }

    AnalyticsRecordDeath(_target.team, _target.object_index);

    var _hasKiller = (_source != noone && instance_exists(_source) && variable_instance_exists(_source, "team"));
    if (_hasKiller) {
        AnalyticsRecordKill(_source.team, _source.object_index);
    }

    var _isUnit = variable_instance_exists(_target, "fsm");
    if (_isUnit) {
        GainXP(_target.team, STRATEGIC_XP_LOSE_UNIT); // the losing team, regardless of whether there's an attributable killer

        if (_hasKiller) {
            var _def  = GetUnitDefinition(_target.object_index);
            var _tier = (_def != undefined) ? _def.tier : 1;
            var _tierXp = ((_tier >= 3) ? COMBAT_XP_TIER_3 : ((_tier == 2) ? COMBAT_XP_TIER_2 : COMBAT_XP_TIER_1));
            GainXP(_source.team, _tierXp);
        }
    } else {
        // Building destroyed -- always free up whatever plot it was built
        // on (BuildingFreePlot, PlotScripts.gml) so the plot is buildable
        // AND clickable/targetable again (2026-07-06), regardless of
        // whether there's an attributable killer. XP below still only
        // applies with one.
        BuildingFreePlot(_target);

        if (_hasKiller) {
            // COMBAT_XP_STRUCTURE always, plus COMBAT_XP_RESOURCE_BLDG on
            // top (not instead of) if it's also a resource building.
            GainXP(_source.team, COMBAT_XP_STRUCTURE);
            if (object_is_ancestor(_target.object_index, oResourceBuildingParent)) {
                GainXP(_source.team, COMBAT_XP_RESOURCE_BLDG);
            }
        }
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
/// @returns {Bool} True the frame the shot is fired, fals