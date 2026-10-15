// Shared damage-application and melee/ranged attack-swing helpers, called
// from unit FSM states. See UnitCombatHelpers.md.

#macro COMBAT_XP_TIER_1        1  // Combat XP per kill, by victim's UnitDefinition.tier
#macro COMBAT_XP_TIER_2        3
#macro COMBAT_XP_TIER_3        5
#macro COMBAT_XP_STRUCTURE     5  // destroy any enemy building (oBuildingParent)
#macro COMBAT_XP_RESOURCE_BLDG 5  // ADDITIONAL XP on top of COMBAT_XP_STRUCTURE if that building is also an oResourceBuildingParent
#macro STRATEGIC_XP_LOSE_UNIT  1  // to the LOSING team, every unit death

/// @function ApplyDamage(_target, _amount, _source)
/// @description The one real damage-application function in the codebase -- both melee and ranged damage route through this. Works against units and buildings. Destroys _target at 0 health and awards Combat/Strategic XP + gib effects. See .md for the full XP/gib rules.
/// @param {Id.Instance} _target
/// @param {Real} _amount
/// @param {Id.Instance} [_source] The attacking unit, for kill-credit and the reactive-on-hit combat target. Optional -- omit if there's no single attributable attacker.
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
            SpawnUnitHitBlood(_target, _source); // no-ops for Mud Golem internally
        } else {
            SpawnBuildingHitParticles(_target, _source);
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

        // Must run BEFORE instance_destroy below (reads _target.x/y/object_index).
        SpawnUnitDeathGibs(_target, _source);
    } else {
        // Building destroyed -- always free up whatever plot it was built on,
        // regardless of whether there's an attributable killer.
        BuildingFreePlot(_target);

        if (_hasKiller) {
            GainXP(_source.team, COMBAT_XP_STRUCTURE);
            if (object_is_ancestor(_target.object_index, oResourceBuildingParent)) {
                GainXP(_source.team, COMBAT_XP_RESOURCE_BLDG);
            }

            // Cross-team only (no reward for self-destruction). Guarded by
            // GetBuildingDefinition != undefined so this never hands out a
            // blueprint for a non-placeable type (oPlayerCastle/oEnemyCastle).
            if (_source.team != _target.team) {
                var _destroyedDef = GetBuildingDefinition(_target.object_index);
                if (_destroyedDef != undefined) {
                    AddBlueprint(_source.team, _target.object_index, 1);
                }
            }
        }
    }

    instance_destroy(_target);
    return true;
}

/// @function UnitEnterCombat(_unit, _target)
/// @description Shared entry point for both of combat's triggers -- proximity aggro and reactive-on-hit. Picks "combat" or "combatRanged" based on the unit's "ranged" tag.
/// @param {Id.Instance} _unit
/// @param {Id.Instance} _target
function UnitEnterCombat(_unit, _target) {
    _unit.combatTarget = _target;
    var _state = UnitHasTag(_unit, "ranged") ? "combatRanged" : "combat";
    _unit.fsm.ChangeState(_state);
}

/// @function UnitRevertFromCombat(_machine)
/// @description Shared "combat/combatRanged is done -- go back to guard/defend" exit path. Falls back to "guard" if no previous state was recorded. See .md.
/// @param {Struct.StateMachine} _machine
function UnitRevertFromCombat(_machine) {
    if (_machine.previousName != undefined) {
        _machine.RevertToPrevious();
    } else {
        _machine.ChangeState("guard");
    }
}

/// @function UnitTryDealDamage(_unit, _target, _machine)
/// @description Attempts to deal damage at the correct animation frame. Guards against multiple hits per swing via _machine.data.hitDealtThisSwing. The single melee damage choke point -- see .md for the Knight/Bomb Goblin special cases.
/// @param {Id.Instance} _unit
/// @param {Id.Instance} _target Any instance with maxHealth (unit or building).
/// @param {Struct}      _machine
/// @returns {Bool} True the frame the hit lands, false every other frame.
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

    // TODO: knockback (units only, buildings don't move) -- not implemented.
    //   if (object_is_ancestor(_target.object_index, oUnitParent)) {
    //       var _dir = Vector2FromAngle(_unit.agent.pos.AngleTo(
    //           new Vector2(_target.x, _target.y)), 1);
    //       _target.agent.ApplyKnockback(_dir.Scale(knockbackStrength));
    //   }

    return true;
}

/// @function UnitTryFireProjectile(_unit, _target, _machine)
/// @description Ranged counterpart to UnitTryDealDamage -- same once-per-swing/hit-frame gating, but spawns a projectile aimed at _target instead of applying damage immediately (resolves later via ProjectileResolveHit).
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
/// @description Returns true when the current attack animation has fully played through.
/// @param {Id.Instance} _unit
/// @returns {Bool}
function UnitAttackAnimComplete(_unit) {
    return _unit.image_index >= sprite_get_number(_unit.sprAttack) - 1;
}

/// @function UnitPursueTarget(_unit, _targetPos, _targetVelocity, _feelerLength)
/// @description Standard pursue + separation + obstacle avoidance + play area containment. Reused across combat/attack/siege/defend pursuit phases. Calls UnitUpdateSprite after movement.
/// @param {Id.Instance}    _unit
/// @param {Struct.Vector2} _targetPos
/// @param {Struct.Vector2} [_targetVelocity] Pass undefined/Vector2(0,0) for stationary targets.
/// @param {Real} [_feelerLength] Steering_AvoidObstacles lookahead. Default 80 -- Siege's ADVANCE phase passes a longer one, see .md.
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

    // oBuildingParent deliberately excluded -- units only collide with real
    // static geometry now. See .md.
    var _delta = _unit.controller.Apply();
    with(_unit){
        move_and_collide(_delta.x, _delta.y, [oEnvironmentSolid]);
    }
    _unit.agent.SyncFromInstance(_unit);

    UnitUpdateSprite(_unit);
}

/// @function UnitIdleInPlace(_unit)
/// @description Idles in place this frame (zero steering, still applies knockback and collision). Brakes the agent first -- see .md for why "zero steering" alone doesn't stop a moving unit. Calls UnitUpdateSprite.
/// @param {Id.Instance} _unit
function UnitIdleInPlace(_unit) {
    _unit.agent.Brake();
    _unit.controller.Begin();
    var _delta = _unit.controller.Apply();
    with(_unit){
        move_and_collide(_delta.x, _delta.y, [oEnvironmentSolid]);
    }
    _unit.agent.SyncFromInstance(_unit);
    UnitUpdateSprite(_unit);
}

/// @function UnitBeginSwing(_unit, _machine)
/// @description Enters the attack animation on a unit and resets swing tracking.
/// @param {Id.Instance} _unit
/// @param {Struct}      _machine
function UnitBeginSwing(_unit, _machine) {
    _machine.data.hitDealtThisSwing = false;
    _unit.sprite_index = _unit.sprAttack;
    _unit.image_index  = 0;
    _unit.image_speed  = global.matchSpeed;
    // Do NOT touch image_xscale here -- keep facing the direction the unit
    // was already facing when the swing started.
}

/// @function UnitEndSwing(_unit, _machine)
/// @description Restores idle sprite and writes cooldown back to the instance. Call at the end of any swing and from all Exit callbacks.
/// @param {Id.Instance} _unit
/// @param {Struct}      _machine
function UnitEndSwing(_unit, _machine) {
    _unit.sprite_index = _unit.sprIdle;
    _unit.image_index  = 0;
    _unit.image_speed  = global.matchSpeed;
    _unit.attackCooldown = max(_machine.data.cooldownTimer, 0);
}
