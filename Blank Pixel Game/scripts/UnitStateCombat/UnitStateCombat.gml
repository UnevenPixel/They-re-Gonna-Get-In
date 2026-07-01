#macro COMBAT_PHASE_PURSUE  "pursue"
#macro COMBAT_PHASE_ATTACK  "attack"
#macro COMBAT_PHASE_RECOVER "recover"

function Combat_Enter(_unit, _machine) {
    _machine.data.phase             = COMBAT_PHASE_PURSUE;
    _machine.data.hitDealtThisSwing = false;
    _machine.data.cooldownTimer     = _unit.attackCooldown;

    sprite_index = _unit.sprIdle;
    image_index  = 0;
    image_speed  = 1;
}

function Combat_Step(_unit, _machine) {

    // -----------------------------------------------------------
    // Target validation
    // -----------------------------------------------------------

    if (!instance_exists(_unit.combatTarget)) {
        _unit.combatTarget = ChooseCombatTarget(_unit);
        if (_unit.combatTarget == noone) {
            _machine.ChangeState("guard");
            return;
        }
    }

    var _targetPos = new Vector2(_unit.combatTarget.x, _unit.combatTarget.y);
    var _dist      = _unit.agent.pos.Distance(_targetPos);

    if (_dist > _unit.attackLeashRange) {
        _unit.combatTarget = noone;
        _machine.ChangeState("guard");
        return;
    }

    // -----------------------------------------------------------
    // Phase: PURSUE
    // -----------------------------------------------------------

    if (_machine.data.phase == COMBAT_PHASE_PURSUE) {
        sprite_index = _unit.sprIdle;
        UnitPursueTarget(_unit, _targetPos, _unit.combatTarget.agent.velocity);

        if (_machine.data.cooldownTimer > 0) _machine.data.cooldownTimer--;

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
        _machine.data.cooldownTimer--;

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

function Combat_Exit(_unit, _machine) {
    UnitEndSwing(_unit, _machine);
}
