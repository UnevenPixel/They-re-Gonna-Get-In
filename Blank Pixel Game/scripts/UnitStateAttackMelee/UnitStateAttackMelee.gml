#macro ATTACK_BUILDING_HALF   24   // half of 48x48, for edge-distance calc
#macro ATTACK_PHASE_APPROACH  "approach"  // moving toward the building
#macro ATTACK_PHASE_SWING     "swing"     // playing attack animation on building
#macro ATTACK_PHASE_RECOVER   "recover"   // cooldown after a building swing
#macro ATTACK_PHASE_DEFENDER  "defender"  // temporarily fighting a defending unit

/// @function NearestBuildingEdgePoint(_building, _fromPos)
/// Returns the nearest point on the building's bounding box edge
/// to the given position -- used so the unit targets the surface
/// of the building rather than its center, which would put the
/// attack trigger point 24px inside the building.
///
/// 2026-07-13 bugfix ("soldiers in the center of the wheat field" report):
/// a plain clamp() of _fromPos to the box only produces a point ON the
/// edge when _fromPos starts OUTSIDE the box -- if _fromPos is already
/// INSIDE (both axes already within range), clamp() is a no-op and just
/// hands back _fromPos itself, i.e. "the nearest edge point" degenerates
/// into wherever the unit already happens to be standing, dead center
/// included. That's reachable in practice because buildings were dropped
/// from units' hard collision list back on 2026-07-06 (move_and_collide
/// only checks oEnvironmentSolid now) -- Steering_AvoidObstacles is a soft
/// lookahead force, not a wall, so a unit converging on a small building
/// alongside allies (separation pressure) or approaching at a sharp angle
/// can clip past the corner the feeler missed and end up inside. Once
/// inside, Attack_Step/AttackRanged_Step read _distToEdge as ~0 and the
/// unit just locks in place right there instead of continuing out to the
/// real surface.
///
/// Now explicitly detects the inside case and pushes back out to whichever
/// side has the least penetration depth, same "always a real point on the
/// actual perimeter, never the interior" guarantee CastleFrontEdgePoint
/// (CastleScripts.gml) already gives for the castle (it sidesteps this
/// entirely by always returning a fixed edge-line X rather than blending
/// toward _fromPos). Since this function is called fresh every step, a
/// unit that's already stuck inside from before this fix self-corrects
/// the very next frame -- UnitPursueTarget just steers it out to the
/// newly-correct edge point (buildings still don't hard-block movement,
/// so nothing stops it walking back out).
/// @param {Id.Instance}    _building
/// @param {Struct.Vector2} _fromPos
/// @returns {Struct.Vector2}
function NearestBuildingEdgePoint(_building, _fromPos) {
    var _bx = _building.x;
    var _by = _building.y;
    var _hw = ATTACK_BUILDING_HALF;
    var _hh = ATTACK_BUILDING_HALF;

    var _left   = _bx - _hw;
    var _right  = _bx + _hw;
    var _top    = _by - _hh;
    var _bottom = _by + _hh;

    var _insideX = (_fromPos.x > _left && _fromPos.x < _right);
    var _insideY = (_fromPos.y > _top  && _fromPos.y < _bottom);

    if (_insideX && _insideY) {
        // _fromPos is inside the box -- clamp() alone would just hand back
        // _fromPos itself here. Push out to the shallowest side instead.
        var _distLeft   = _fromPos.x - _left;
        var _distRight  = _right - _fromPos.x;
        var _distTop    = _fromPos.y - _top;
        var _distBottom = _bottom - _fromPos.y;

        var _minDist = min(_distLeft, _distRight, _distTop, _distBottom);

        if (_minDist == _distLeft)       return new Vector2(_left, _fromPos.y);
        else if (_minDist == _distRight) return new Vector2(_right, _fromPos.y);
        else if (_minDist == _distTop)   return new Vector2(_fromPos.x, _top);
        else                              return new Vector2(_fromPos.x, _bottom);
    }

    var _cx = clamp(_fromPos.x, _left, _right);
    var _cy = clamp(_fromPos.y, _top, _bottom);
    return new Vector2(_cx, _cy);
}

// -----------------------------------------------------------
// attack
// -----------------------------------------------------------

/// @function Attack_Enter(_unit, _machine)
/// @description StateMachine onEnter for "attack". Bails back to "guard" if the
///        building target is already gone; otherwise resets phase/cooldown/defender
///        tracking and starts from the idle sprite.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Attack_Enter(_unit, _machine) {
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

/// @function Attack_Step(_unit, _machine)
/// @description StateMachine onStep for "attack". Drives the approach/swing/recover
///        cycle against attackBuildingTarget, with a DEFENDER sub-phase that
///        interrupts to fight off a nearby enemy unit before resuming the building.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Attack_Step(_unit, _machine) {

    // -----------------------------------------------------------
    // Building validation -- check every frame
    // -----------------------------------------------------------

    if (!instance_exists(_unit.attackBuildingTarget)) {
        // Building is gone -- job done, return to guard.
        _machine.ChangeState("guard");
        return;
    }

    var _buildingPos  = new Vector2(_unit.attackBuildingTarget.x, _unit.attackBuildingTarget.y);
    var _edgePos      = NearestBuildingEdgePoint(_unit.attackBuildingTarget, _unit.agent.pos);
    var _distToEdge   = _unit.agent.pos.Distance(_edgePos);

    // -----------------------------------------------------------
    // Phase: DEFENDER (highest priority -- always checked first)
    // If a defender was engaged, keep fighting it until it's gone
    // or it retreats out of aggro range, then fall back to the
    // building. Swapping back to APPROACH (not SWING) means the
    // unit will re-check distance and cooldown cleanly.
    // -----------------------------------------------------------

    if (_machine.data.phase == ATTACK_PHASE_DEFENDER) {

        var _def = _machine.data.defenderTarget;
        if (!instance_exists(_def)) {
            // Defender dead -- resume on the building.
            _machine.data.defenderTarget = noone;
            _machine.data.phase          = ATTACK_PHASE_APPROACH;
            UnitEndSwing(_unit, _machine);
            return;
        }

        var _defPos  = new Vector2(_def.x, _def.y);
        var _defDist = _unit.agent.pos.Distance(_defPos);

        if (_defDist > _unit.attackLeashRange) {
            // Defender retreated far enough -- resume on the building.
            _machine.data.defenderTarget = noone;
            _machine.data.phase          = ATTACK_PHASE_APPROACH;
            UnitEndSwing(_unit, _machine);
            return;
        }

        // Pursue and attack the defender using the same three-sub-phase
        // logic as the combat state, but driven from inside attack's
        // DEFENDER phase rather than a separate FSM state, so the
        // building target is preserved throughout.
        if (_machine.data.cooldownTimer > 0) _machine.data.cooldownTimer -= global.matchSpeed;

        if (_defDist > _unit.attackRange) {
            _unit.sprite_index = _unit.sprIdle;
            UnitPursueTarget(_unit, _defPos, _def.agent.velocity);
        } else if (_machine.data.cooldownTimer <= 0) {
            // In range and ready to swing.
            if (_unit.sprite_index != _unit.sprAttack) {
                UnitBeginSwing(_unit, _machine);
            }

            UnitIdleInPlace(_unit);
            UnitTryDealDamage(_unit, _def, _machine);

            if (UnitAttackAnimComplete(_unit)) {
                _machine.data.cooldownTimer = _unit.attackCooldownMax;
                UnitEndSwing(_unit, _machine);
            }
        } else {
            // Cooldown ticking -- stand close, wait for next swing.
            UnitIdleInPlace(_unit);
        }

        return; // don't fall through to building phases this frame
    }

    // -----------------------------------------------------------
    // Aggro check -- runs every frame outside of DEFENDER phase.
    // If a nearby enemy unit enters aggro range, interrupt the
    // current building phase and engage them first.
    // Note: only interrupts APPROACH or RECOVER, not mid-SWING.
    // A swing already in progress always completes first.
    // -----------------------------------------------------------

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

    // -----------------------------------------------------------
    // Phase: APPROACH
    // -----------------------------------------------------------

    if (_machine.data.phase == ATTACK_PHASE_APPROACH) {
        _unit.sprite_index = _unit.sprIdle;

        // Seek the nearest edge point rather than the center, so
        // the unit's attack range triggers at the building's surface.
        UnitPursueTarget(_unit, _edgePos, new Vector2(0, 0));

        if (_machine.data.cooldownTimer > 0) _machine.data.cooldownTimer -= global.matchSpeed;

        if (_distToEdge <= _unit.attackRange && _machine.data.cooldownTimer <= 0) {
            _machine.data.phase = ATTACK_PHASE_SWING;
            UnitBeginSwing(_unit, _machine);
        }
    }

    // -----------------------------------------------------------
    // Phase: SWING (attacking the building)
    // -----------------------------------------------------------

    else if (_machine.data.phase == ATTACK_PHASE_SWING) {
        UnitIdleInPlace(_unit);
        UnitTryDealDamage(_unit, _unit.attackBuildingTarget, _machine);

        if (UnitAttackAnimComplete(_unit)) {
            _machine.data.phase         = ATTACK_PHASE_RECOVER;
            _machine.data.cooldownTimer = _unit.attackCooldownMax;
            UnitEndSwing(_unit, _machine);
        }
    }

    // -----------------------------------------------------------
    // Phase: RECOVER (cooldown between building swings)
    // -----------------------------------------------------------

    else if (_machine.data.phase == ATTACK_PHASE_RECOVER) {
        _machine.data.cooldownTimer -= global.matchSpeed;

        // Hug the building edge during recovery so the unit is
        // already in position when the cooldown expires.
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

/// @function Attack_Exit(_unit, _machine)
/// @description StateMachine onExit for "attack". Ends any in-progress swing and
///        clears building/defender target tracking.
/// @param {Id.Instance} _unit
/// @param {Struct.StateMachine} _machine
function Attack_Exit(_unit, _machine) {
    UnitEndSwing(_unit, _machine);
    _unit.attackBuildingTarget = noone;
    _machine.data.defenderTarget = noone;
}
