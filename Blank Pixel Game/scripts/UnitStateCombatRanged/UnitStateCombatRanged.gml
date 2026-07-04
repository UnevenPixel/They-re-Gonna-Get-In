// -----------------------------------------------------------
// combatRanged -- ranged counterpart to "combat" (UnitStateCombat.gml).
// Entered via UnitEnterCombat (UnitCombatHelpers.gml) instead of "combat"
// for units tagged "ranged" -- same dispatch the "attack" order uses to pick
// "attack" vs "attackRanged" (OrderWiring.gml).
//
// Deliberately a structural duplicate of Combat_Enter/Combat_Step/Combat_Exit
// rather than a branch inside them -- same reasoning as
// UnitStateAttackRanged.gml (see its file header): this codebase already
// hit a bug from sharing one state's functions across multiple orders, so
// each gets its own dedicated functions even at the cost of near-identical
// files. The only behavioral difference from "combat" is at the attack
// trigger: UnitTryFireProjectile spawns a projectile instead of
// UnitTryDealDamage applying damage on the spot.
//
// Reuses the COMBAT_PHASE_PURSUE/ATTACK/RECOVER macros from
// UnitStateCombat.gml -- GML macros are global regardless of which file
// defines them, nothing to redeclare here.
// -----------------------------------------------------------

/// @function CombatRanged_Enter(_unit, _machine)
/// @description StateMachine onEnter for "combatRanged". Same shape as
///        Combat_Enter.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function CombatRanged_Enter(_unit, _machine) {
    _machine.data.phase             = COMBAT_PHASE_PURSUE;
    _machine.data.hitDealtThisSwing = false;
    _machine.data.cooldownTimer     = _unit.attackCooldown;

    _unit.sprite_index = _unit.sprIdle;
    _unit.image_index  = 0;
    _unit.image_speed  = global.matchSpeed;
}

/// @function CombatRanged_Step(_unit, _machine)
/// @description StateMachine onStep for "combatRanged". Same
///        pursue/attack/recover cycle as Combat_Step against
///        _unit.combatTarget, but the ATTACK phase calls UnitTryFireProjectile
///        instead of UnitTryDealDamage. Reverts to whichever of guard/defend
///        it was interrupted from (UnitRevertFromCombat) when there's no
///        target or it leashes out of range -- same as Combat_Step.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function CombatRanged_Step(_unit, _machine) {

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
    // Phase: ATTACK (firing at _unit.combatTarget)
    // -----------------------------------------------------------

    else if (_machine.data.phase == COMBAT_PHASE_ATTACK) {
        UnitIdleInPlace(_unit);
        UnitTryFireProjectile(_unit, _unit.combatTarget, _machine);

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

/// @function CombatRanged_Exit(_unit, _machine)
/// @description StateMachine onExit for "combatRanged". Same as Combat_Exit.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function CombatRanged_Exit(_unit, _machine) {
    UnitEndSwing(_unit, _machine);
}
