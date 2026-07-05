#macro COMBAT_PHASE_PURSUE  "pursue"
#macro COMBAT_PHASE_ATTACK  "attack"
#macro COMBAT_PHASE_RECOVER "recover"

/// @function Combat_Enter(_unit, _machine)
/// @description StateMachine onEnter for "combat". Resets phase/cooldown tracking
///        and starts from the idle sprite.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Combat_Enter(_unit, _machine) {
    _machine.data.phase             = COMBAT_PHASE_PURSUE;
    _machine.data.hitDealtThisSwing = false;
    _machine.data.cooldownTimer     = _unit.attackCooldown;

    _unit.sprite_index = _unit.sprIdle;
    _unit.image_index  = 0;
    _unit.image_speed  = global.matchSpeed;
}

/// @function Combat_Step(_unit, _machine)
/// @description StateMachine onStep for "combat". Drives the pursue/attack/recover
///        cycle against _unit.combatTarget, picking a new target via
///        ChooseCombatTarget() if the current one is gone, and reverting to
///        whichever of guard/defend it was interrupted from (UnitRevertFromCombat,
///        UnitCombatHelpers.gml) if there's no target or the target leashes
///        out of range -- "combat" is only ever entered from guard/defend
///        (UnitEnterCombat), so there's always a previous state to go back to.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Combat_Step(_unit, _machine) {

    // -----------------------------------------------------------
    // Target validation
    // -----------------------------------------------------------

    if (!instance_exists(_unit.combatTarget)) {
        _unit.combatTarget = ChooseCombatTarget(_unit);
        if (_unit.combatTarget == noone) {
            UnitRevertFromCombat(_machine);
            return;
        }
    }

    var _targetPos = new Vector2(_unit.combatTarget.x, _unit.combatTarget.y);
    var _dist      = _unit.agent.pos.Distance(_targetPos);

    if (_dist > _unit.attackLeashRange) {
        _unit.combatTarget = noone;
        UnitRevertFromCombat(_machine);
        return;
    }

    // -----------------------------------------------------------
    // Phase: PURSUE
    // -----------------------------------------------------------

    if (_machine.data.phase == COMBAT_PHASE_PURSUE) {
        _unit.sprite_index = _unit.sprIdle;
        UnitPursueTarget(_unit, _targetPos, _unit.combatTarget.agent.velocity);

        if (_machine.data.cooldownTimer > 0) _machine.data.cooldownTimer -= global.matchSpeed;

        if (_dist <= _unit.attackRange && _machine.data.cooldownTimer <= 0) {
            _machine.data.phase = COMBAT_PHASE_ATTACK;
            UnitBeginSwing(_unit, _machine);
        }
    }

    // -----------------------------------------------------------
    // Phase: ATTACK
    // -----------------------------------------------------------

    else if (_machine.data.phase == COMBAT_PHASE_ATTACK) {
        UnitIdleInPlace(_unit);
        UnitTryDealDamage(_unit, _unit.combatTarget, _machine);

        if (UnitAttackAnimComplete(_unit)) {
            _machine.data.phase         = COMBAT_PHASE_RECOVER;
            _machine.data.cooldownTimer = _unit.attackCooldownMax;
            UnitEndSwing(_unit, _machine);
        }
    }

    // -----------------------------------------------------------
    // Phase: RECOVER
    // -----------------------------------------------------------

    else if (_machine.data.phase == COMBAT_PHASE_RECOVER) {
        _machine.data.cooldownTimer -= global.matchSpeed;

        if (_dist > _unit.attackRange) {
            UnitPursueTarget(_unit, _targetPos, _unit.combatTarget.agent.velocity);
        } else {
            UnitIdleInPlace(_unit);
        }

        if (_machine.data.cooldownTimer <= 0) {
            _machine.data.phase = COMBAT_PHASE_PURSUE;
        }
    }
}

/// @function Combat_Exit(_unit, _machine)
/// @description StateMachine onExit for "combat". Ends any in-progress swing.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Combat_Exit(_unit, _machine) {
    UnitEndSwing(_unit, _machine);
}
