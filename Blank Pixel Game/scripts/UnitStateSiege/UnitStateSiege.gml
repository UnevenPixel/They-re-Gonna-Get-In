#macro SIEGE_PHASE_ADVANCE       "advance"       // marching toward castle, clearing guards
#macro SIEGE_PHASE_ENGAGE_GUARD  "engage_guard"  // actively fighting a guard unit
#macro SIEGE_PHASE_ASSAULT       "assault"       // close to the castle, hitting it
#macro SIEGE_PHASE_SWING         "swing"         // mid-animation swing on the castle
#macro SIEGE_PHASE_RECOVER       "recover"       // cooldown between castle hits

// -----------------------------------------------------------
// siege
// -----------------------------------------------------------

/// @function Siege_Enter(_unit, _machine)
/// @description StateMachine onEnter for "siege". Falls back to "guard" if no
///        enemy castle is found; otherwise stores the castle and resets
///        phase/cooldown/guard-target tracking.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Siege_Enter(_unit, _machine) {
    var _castle = GetEnemyCastle(_unit);
    if (!instance_exists(_castle)) {
        // No castle found -- nothing to besiege.
        _machine.ChangeState("guard");
        return;
    }

    _machine.data.castle            = _castle;
    _machine.data.phase             = SIEGE_PHASE_ADVANCE;
    _machine.data.guardTarget       = noone;
    _machine.data.hitDealtThisSwing = false;
    _machine.data.cooldownTimer     = _unit.attackCooldown;

    _unit.sprite_index = _unit.sprIdle;
    _unit.image_index  = 0;
    _unit.image_speed  = global.matchSpeed;
}

/// @function Siege_Step(_unit, _machine)
/// @description StateMachine onStep for "siege". Drives advance/assault/swing/recover
///        against the enemy castle, with an ENGAGE_GUARD sub-phase that breaks off
///        to fight any enemy unit swept up within siegeSweepRadius (or the tighter
///        attackAggroRadius once assaulting) before resuming the castle.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Siege_Step(_unit, _machine) {

    // -----------------------------------------------------------
    // Castle validation
    // -----------------------------------------------------------

    if (!instance_exists(_machine.data.castle)) {
        // Castle destroyed -- siege objective complete.
        _machine.ChangeState("guard");
        return;
    }

    var _castlePos  = new Vector2(_machine.data.castle.x, _machine.data.castle.y);
    var _edgePos    = NearestBuildingEdgePoint(_machine.data.castle, _unit.agent.pos);
    var _distToEdge = _unit.agent.pos.Distance(_edgePos);

    // -----------------------------------------------------------
    // Phase: ENGAGE_GUARD
    // Fight a guard unit to completion before resuming advance.
    // Unlike attack's DEFENDER phase, this was entered proactively
    // (the unit went looking for this fight), so it commits until
    // the guard is dead or retreats, rather than returning to the
    // castle the moment the guard leaves aggro range.
    // -----------------------------------------------------------

    if (_machine.data.phase == SIEGE_PHASE_ENGAGE_GUARD) {
        var _guard = _machine.data.guardTarget;

        if (!instance_exists(_guard)) {
            // Guard defeated -- back to advancing.
            _machine.data.guardTarget = noone;
            _machine.data.phase       = SIEGE_PHASE_ADVANCE;
            UnitEndSwing(_unit, _machine);
            return;
        }

        var _guardPos  = new Vector2(_guard.x, _guard.y);
        var _guardDist = _unit.agent.pos.Distance(_guardPos);

        // If the guard has fully fled the siege sweep zone AND is
        // retreating away from the castle (i.e. no longer a threat
        // to the assault), let them go and resume.
        var _guardDistToCastle = point_distance(_guard.x, _guard.y, _machine.data.castle.x, _machine.data.castle.y);
        if (_guardDist > _unit.siegeSweepRadius && _guardDistToCastle > _unit.siegeSweepRadius) {
            _machine.data.guardTarget = noone;
            _machine.data.phase       = SIEGE_PHASE_ADVANCE;
            UnitEndSwing(_unit, _machine);
            return;
        }

        if (_machine.data.cooldownTimer > 0) _machine.data.cooldownTimer -= global.matchSpeed;

        if (_guardDist > _unit.attackRange) {
            _unit.sprite_index = _unit.sprIdle;
            UnitPursueTarget(_unit, _guardPos, _guard.agent.velocity);
        } else if (_machine.data.cooldownTimer <= 0) {
            if (_unit.sprite_index != _unit.sprAttack) {
                UnitBeginSwing(_unit, _machine);
            }
            UnitIdleInPlace(_unit);
            UnitTryDealDamage(_unit, _guard, _machine);

            if (UnitAttackAnimComplete(_unit)) {
                _machine.data.cooldownTimer = _unit.attackCooldownMax;
                UnitEndSwing(_unit, _machine);
            }
        } else {
            UnitIdleInPlace(_unit);
        }

        return; // don't fall through this frame
    }

    // -----------------------------------------------------------
    // Phase: ADVANCE
    // March toward the castle. On each frame, sweep for the
    // nearest enemy unit within siegeSweepRadius -- if one is
    // found, break off and engage it before continuing.
    // -----------------------------------------------------------

    if (_machine.data.phase == SIEGE_PHASE_ADVANCE) {
        _unit.sprite_index = _unit.sprIdle;

        var _nearestGuard = ChooseCombatTarget(_unit, _unit.siegeSweepRadius, _castlePos);
        if (_nearestGuard != noone) {
            _machine.data.guardTarget       = _nearestGuard;
            _machine.data.phase             = SIEGE_PHASE_ENGAGE_GUARD;
            _machine.data.hitDealtThisSwing = false;
            return;
        }

        if (_machine.data.cooldownTimer > 0) _machine.data.cooldownTimer -= global.matchSpeed;

        UnitPursueTarget(_unit, _edgePos, new Vector2(0, 0));

        if (_distToEdge <= _unit.attackRange && _machine.data.cooldownTimer <= 0) {
            _machine.data.phase = SIEGE_PHASE_ASSAULT;
        }
    }

    // -----------------------------------------------------------
    // Phase: ASSAULT
    // The unit is at the castle walls. Guard sweeping still runs
    // here but with a tighter radius (the unit shouldn't chase a
    // guard halfway across the map when it's already at the walls).
    // Swing takes priority once in range and off cooldown.
    // -----------------------------------------------------------

    else if (_machine.data.phase == SIEGE_PHASE_ASSAULT) {
        _unit.sprite_index = _unit.sprIdle;

        if (_machine.data.cooldownTimer > 0) _machine.data.cooldownTimer -= global.matchSpeed;

        // Reactive defender check at a tighter radius while assaulting.
        var _nearestGuard = ChooseCombatTarget(_unit, _unit.attackAggroRadius ?? 96, _castlePos);
        if (_nearestGuard != noone) {
            _machine.data.guardTarget       = _nearestGuard;
            _machine.data.phase             = SIEGE_PHASE_ENGAGE_GUARD;
            _machine.data.hitDealtThisSwing = false;
            return;
        }

        if (_distToEdge <= _unit.attackRange && _machine.data.cooldownTimer <= 0) {
            _machine.data.phase = SIEGE_PHASE_SWING;
            UnitBeginSwing(_unit, _machine);
        } else if (_distToEdge > _unit.attackRange) {
            // Castle pushed us back (knockback, pathing) -- close the gap.
            UnitPursueTarget(_unit, _edgePos, new Vector2(0, 0));
        } else {
            UnitIdleInPlace(_unit);
        }
    }

    // -----------------------------------------------------------
    // Phase: SWING (attacking the castle)
    // Never interrupted -- swings always complete once started.
    // -----------------------------------------------------------

    else if (_machine.data.phase == SIEGE_PHASE_SWING) {
        UnitIdleInPlace(_unit);
        UnitTryDealDamage(_unit, _machine.data.castle, _machine);

        if (UnitAttackAnimComplete(_unit)) {
            _machine.data.phase         = SIEGE_PHASE_RECOVER;
            _machine.data.cooldownTimer = _unit.attackCooldownMax;
            UnitEndSwing(_unit, _machine);
        }
    }

    // -----------------------------------------------------------
    // Phase: RECOVER (between castle swings)
    // -----------------------------------------------------------

    else if (_machine.data.phase == SIEGE_PHASE_RECOVER) {
        _machine.data.cooldownTimer -= global.matchSpeed;

        // Keep checking for guards during cooldown -- a fresh wave of
        // defenders arriving during recovery should be engaged before
        // the next swing rather than letting them pile up.
        var _nearestGuard = ChooseCombatTarget(_unit, _unit.attackAggroRadius ?? 96, _castlePos);
        if (_nearestGuard != noone) {
            _machine.data.guardTarget       = _nearestGuard;
            _machine.data.phase             = SIEGE_PHASE_ENGAGE_GUARD;
            _machine.data.hitDealtThisSwing = false;
            return;
        }

        if (_distToEdge > _unit.attackRange) {
            UnitPursueTarget(_unit, _edgePos, new Vector2(0, 0));
        } else {
            UnitIdleInPlace(_unit);
        }

        if (_machine.data.cooldownTimer <= 0) {
            _machine.data.phase = SIEGE_PHASE_ASSAULT;
        }
    }
}

/// @function Siege_Exit(_unit, _machine)
/// @description StateMachine onExit for "siege". Ends any in-progress swing and
///        clears the guard-target tracking.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Siege_Exit(_unit, _machine) {
    UnitEndSwing(_unit, _machine);
    _machine.data.guardTarget = noone;
}
