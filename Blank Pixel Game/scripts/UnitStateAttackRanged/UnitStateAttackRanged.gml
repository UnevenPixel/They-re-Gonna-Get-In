// FSM state "attackRanged" -- ranged counterpart to "attack"
// (UnitStateAttackMelee.gml). FLAGGED/load-bearing state file.
// See UnitStateAttackRanged.md for why this is a near-duplicate, not a branch.

/// @function AttackRanged_Enter(_unit, _machine)
/// @description StateMachine onEnter for "attackRanged". Same shape as Attack_Enter.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function AttackRanged_Enter(_unit, _machine) {
    if (!instance_exists(_unit.attackBuildingTarget)) {
        _machine.ChangeState("guard");
        return;
    }

    _machine.data.phase             = ATTACK_PHASE_APPROACH;
    _machine.data.hitDealtThisSwing = false;
    _machine.data.cooldownTimer     = _unit.attackCooldown;
    _machine.data.defenderTarget    = noone;

    _unit.sprite_index = _unit.sprIdle;
    _unit.image_index  = 0;
    _unit.image_speed  = global.matchSpeed;
}

/// @function AttackRanged_Step(_unit, _machine)
/// @description StateMachine onStep for "attackRanged". Same approach/swing/recover/defender cycle as Attack_Step, but both swing points call UnitTryFireProjectile instead of UnitTryDealDamage.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function AttackRanged_Step(_unit, _machine) {

    // Building validation -- check every frame.
    if (!instance_exists(_unit.attackBuildingTarget)) {
        _machine.ChangeState("guard");
        return;
    }

    var _edgePos    = NearestBuildingEdgePoint(_unit.attackBuildingTarget, _unit.agent.pos);
    var _distToEdge = _unit.agent.pos.Distance(_edgePos);

    // Phase: DEFENDER (highest priority -- always checked first).
    if (_machine.data.phase == ATTACK_PHASE_DEFENDER) {

        var _def = _machine.data.defenderTarget;
        if (!instance_exists(_def)) {
            _machine.data.defenderTarget = noone;
            _machine.data.phase          = ATTACK_PHASE_APPROACH;
            UnitEndSwing(_unit, _machine);
            return;
        }

        var _defPos  = new Vector2(_def.x, _def.y);
        var _defDist = _unit.agent.pos.Distance(_defPos);

        if (_defDist > _unit.attackLeashRange) {
            _machine.data.defenderTarget = noone;
            _machine.data.phase          = ATTACK_PHASE_APPROACH;
            UnitEndSwing(_unit, _machine);
            return;
        }

        if (_machine.data.cooldownTimer > 0) _machine.data.cooldownTimer -= global.matchSpeed;

        if (_defDist > _unit.attackRange) {
            _unit.sprite_index = _unit.sprIdle;
            UnitPursueTarget(_unit, _defPos, _def.agent.velocity);
        } else if (_machine.data.cooldownTimer <= 0) {
            if (_unit.sprite_index != _unit.sprAttack) {
                UnitBeginSwing(_unit, _machine);
            }

            UnitIdleInPlace(_unit);
            UnitTryFireProjectile(_unit, _def, _machine);

            if (UnitAttackAnimComplete(_unit)) {
                _machine.data.cooldownTimer = _unit.attackCooldownMax;
                UnitEndSwing(_unit, _machine);
            }
        } else {
            UnitIdleInPlace(_unit);
        }

        return; // don't fall through to building phases this frame
    }

    // Aggro check -- runs every frame outside of DEFENDER phase.
    if (_machine.data.phase != ATTACK_PHASE_SWING) {
        var _defender = ChooseCombatTarget(_unit, _unit.attackAggroRadius);
        if (_defender != noone) {
            _machine.data.defenderTarget    = _defender;
            _machine.data.phase             = ATTACK_PHASE_DEFENDER;
            _machine.data.hitDealtThisSwing = false;
            _unit.sprite_index = _unit.sprIdle;
            return;
        }
    }

    // Phase: APPROACH.
    if (_machine.data.phase == ATTACK_PHASE_APPROACH) {
        _unit.sprite_index = _unit.sprIdle;

        UnitPursueTarget(_unit, _edgePos, new Vector2(0, 0));

        if (_machine.data.cooldownTimer > 0) _machine.data.cooldownTimer -= global.matchSpeed;

        if (_distToEdge <= _unit.attackRange && _machine.data.cooldownTimer <= 0) {
            _machine.data.phase = ATTACK_PHASE_SWING;
            UnitBeginSwing(_unit, _machine);
        }
    }

    // Phase: SWING (firing at the building).
    else if (_machine.data.phase == ATTACK_PHASE_SWING) {
        UnitIdleInPlace(_unit);
        UnitTryFireProjectile(_unit, _unit.attackBuildingTarget, _machine);

        if (UnitAttackAnimComplete(_unit)) {
            _machine.data.phase         = ATTACK_PHASE_RECOVER;
            _machine.data.cooldownTimer = _unit.attackCooldownMax;
            UnitEndSwing(_unit, _machine);
        }
    }

    // Phase: RECOVER.
    else if (_machine.data.phase == ATTACK_PHASE_RECOVER) {
        _machine.data.cooldownTimer -= global.matchSpeed;

        if (_distToEdge > _unit.attackRange) {
            UnitPursueTarget(_unit, _edgePos, new Vector2(0, 0));
        } else {
            UnitIdleInPlace(_unit);
        }

        if (_machine.data.cooldownTimer <= 0) {
            _machine.data.phase = ATTACK_PHASE_APPROACH;
        }
    }
}

/// @function AttackRanged_Exit(_unit, _machine)
/// @description StateMachine onExit for "attackRanged". Same as Attack_Exit.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function AttackRanged_Exit(_unit, _machine) {
    UnitEndSwing(_unit, _machine);
    _unit.attackBuildingTarget    = noone;
    _machine.data.defenderTarget = noone;
}
