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
///
///        2026-07-12 addition ("set up gibbing" request) -- the FIRST
///        on-hit/on-death visual hook in this codebase (previously
///        "nothing in this codebase runs on unit death at all", per Mud
///        Golem's Deployed Effect note, UnitDefinitions.gml). Every
///        non-lethal hit against a UNIT (buildings don't bleed) spawns 2-4
///        blood pixels (SpawnUnitHitBlood, GibScripts.gml). The instant a
///        unit dies, BEFORE instance_destroy below, it gets the full gib
///        sequence (SpawnUnitDeathGibs) -- splatter + general chunks +
///        its own unique gib + 4-8 more blood pixels. Both hard-exit
///        immediately for Mud Golem specifically (excluded entirely per
///        explicit request -- see SpawnUnitHitBlood/SpawnUnitDeathGibs' own
///        doc comments).
///
///        2026-07-12 follow-up -- non-lethal hits against a BUILDING now
///        spawn 2-4 gray placeholder particles (SpawnBuildingHitParticles,
///        GibScripts.gml) in the same else branch, mirroring
///        SpawnUnitHitBlood's unit case. No building death-particle
///        equivalent to SpawnUnitDeathGibs exists yet -- the request only
///        covered the hit reaction, not destruction; the lethal/building
///        branch below still only calls BuildingFreePlot.
///
///        Routes through this ONE function for both melee (UnitTryDealDamage)
///        and ranged (ProjectileResolveHit) damage, same as everything
///        else ApplyDamage already does -- no changes needed anywhere else.
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
        var _isUnitHit = variable_instance_exists(_target, "fsm");

        if (_isUnitHit) {
            SpawnUnitHitBlood(_target, _source); // 2026-07-12 -- GibScripts.gml, no-ops for Mud Golem internally
        } else {
            SpawnBuildingHitParticles(_target, _source); // 2026-07-12 follow-up -- GibScripts.gml, gray placeholder particles
        }

        if (_source != noone && instance_exists(_source)
            && _isUnitHit
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

        // 2026-07-12 -- must run BEFORE instance_destroy below (reads
        // _target.x/y/object_index); no-ops for Mud Golem internally. See
        // this function's doc comment and GibScripts.gml.
        SpawnUnitDeathGibs(_target, _source);
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
/// 2026-07-12 follow-up additions -- this is the single melee damage choke
/// point (attack-vs-building, attack's DEFENDER sub-phase vs a unit, combat,
/// AND siege all route through here, see each state's own file), so both
/// land here rather than in any one state:
///   - Knight's productionBuildingDamageBonus (UnitDefinitions.gml, +50%)
///     applies when _target is an oResourceBuildingParent (production
///     building only -- not training buildings or the castle), per its
///     own flavor text ("Bonus damage against production buildings").
///   - Bomb Goblin ("die when it explodes" request) sets
///     _unit.pendingSelfDestruct = true the instant its swing actually
///     connects, instead of destroying it synchronously here -- this
///     function runs INSIDE the attacking unit's own FSM step (_unit ==
///     id), and every caller (Attack_Step/UnitStateCombat/UnitStateSiege)
///     keeps reading _unit's fields immediately after this call returns
///     (UnitAttackAnimComplete, UnitEndSwing, etc.); destroying it here
///     would run that code against an already-destroyed instance. The flag
///     is consumed AFTER fsm.Step() finishes for the frame, in
///     oUnitParent/Step_0.gml, once it's safe.
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

    var _damage = _unit.attackDamage;
    var _attackerDef = GetUnitDefinition(_unit.object_index);
    if (_attackerDef != undefined && _attackerDef.productionBuildingDamageBonus > 0
        && object_is_ancestor(_target.object_index, oResourceBuildingParent)) {
        _damage = round(_damage * (1 + _attackerDef.productionBuildingDamageBonus));
    }

    ApplyDamage(_target, _damage, _unit);

    if (_unit.object_index == oBombGoblinUnit) {
        _unit.pendingSelfDestruct = true;
    }

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

/// @function UnitPursueTarget(_unit, _targetPos, _targetVelocity, _feelerLength)
/// Standard pursue + separation + obstacle avoidance + play area containment.
/// Reused across combat/attack/siege/defend pursuit phases.
/// Calls UnitUpdateSprite after movement so sprite and facing are always
/// current without each state needing to do it explicitly.
///
/// @param {Id.Instance}    _unit
/// @param {Struct.Vector2} _targetPos
/// @param {Struct.Vector2} [_targetVelocity] Pass undefined/Vector2(0,0) for stationary targets.
/// @param {Real} [_feelerLength] Steering_AvoidObstacles lookahead -- default
///        80 (unchanged behavior everywhere except where a caller opts into
///        a longer one). Siege_Step's ADVANCE phase passes a longer feeler
///        (2026-07-06) since that's a long, deliberate march across open
///        ground toward the castle where getting snagged on a building was
///        reported -- earlier detection gives the existing avoidance logic
///        more room to curve around smoothly instead of reacting at the
///        last moment, which is what tends to catch on corners.
function UnitPursueTarget(_unit, _targetPos, _targetVelocity = undefined, _feelerLength = 80) {
    _targetVelocity ??= new Vector2(0, 0);

    var _obstacles = GatherNearbyObstacles(_unit);
    var _allies    = GatherNearbyAllies(_unit, 48);

    _unit.controller.Begin();
    _unit.controller.Add(
        Steering_Pursue(_unit.agent, _targetPos, _targetVelocity), 1.2
    );
    _unit.controller.Add(Steering_Separation(_unit.agent, _allies, 28),                    1.0);
    _unit.controller.Add(Steering_AvoidObstacles(_unit.agent, _obstacles, _feelerLength),  1.8);
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

/// @function UnitIdleInPlace(_unit)
/// Idles in place this frame (zero steering, still applies knockback
/// and collision). Calls UnitUpdateSprite so a standing unit still
/// shows the correct idle sprite after a hit reaction.
///
/// Brakes the agent first (SteeringAgent.Brake, SteeringBehaviors.gml) --
/// "zero steering" does NOT mean "zero speed" on its own: Begin()/Apply()
/// with no Add() calls leaves agent.velocity completely untouched (every
/// Steering_* behavior decelerates by computing desired-minus-velocity,
/// but doing nothing at all provides no opposing force whatsoever), so
/// without braking here, a unit that arrives at this call with leftover
/// momentum from whatever pursuit got it here just keeps gliding in that
/// same direction every subsequent step, indefinitely. This is what caused
/// siege units to keep sliding into/through the castle wall after reaching
/// attack range instead of actually stopping to fight -- 2026-07-06:
/// "once they reach the castle edge, they should stop walking." Also fixes
/// the same latent issue for every other caller (attack/attackRanged/
/// combat/combatRanged), not just siege.
/// @param {Id.Instance} _unit
function UnitIdleInPlace(_unit) {
    _unit.agent.Brake();
    _unit.controller.Begin();
    var _delta = _unit.controller.Apply();
    // oBuildingParent dropped from this collision list, 2026-07-06 -- see
    // UnitPursueTarget above for the full rationale (units no longer
    // physically collide with buildings, only oEnvironmentSolid).
    with(_unit){
        move_and_collide(_delta.x, _delta.y, [oEnvironmentSolid]);
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
