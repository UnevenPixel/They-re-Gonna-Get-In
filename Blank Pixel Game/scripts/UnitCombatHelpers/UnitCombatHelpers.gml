/// Attempts to deal damage at the correct animation frame.
/// Guards against multiple hits per swing via _machine.data.hitDealtThisSwing.
/// Returns true the frame the hit lands, false every other frame.
///
/// @param {Id.Instance} _unit
/// @param {Id.Instance} _target Any instance with hp (unit or building).
/// @param {Struct}      _machine
/// @return {Bool}
function UnitTryDealDamage(_unit, _target, _machine) {
    if (_machine.data.hitDealtThisSwing) return false;

    var _currentFrame = floor(image_index);
    if (_currentFrame < _unit.attackHitFrame) return false;

    _machine.data.hitDealtThisSwing = true;

    if (!instance_exists(_target)) return false;

    // TODO: damage calculation
    // Replace this block with your actual damage system.
    // Suggested inputs:
    //   _unit.attackDamage      -- base damage stat on the attacker
    //   _target.defense         -- target's defense/armor stat
    //   A crit/miss roll if your game uses one
    // Suggested outputs:
    //   Call TakeDamage(_amount) on the target, or modify _target.hp directly.
    // Knockback (units only, buildings don't move):
    //   if (object_is_ancestor(_target.object_index, oUnitParent)) {
    //       var _dir = Vector2FromAngle(_unit.agent.pos.AngleTo(
    //           new Vector2(_target.x, _target.y)), 1);
    //       _target.agent.ApplyKnockback(_dir.Scale(knockbackStrength));
    //   }

    return true;
}

/// Returns true when the current attack animation has fully played through.
/// @param {Id.Instance} _unit
/// @return {Bool}
function UnitAttackAnimComplete(_unit) {
    return image_index >= sprite_get_number(_unit.sprAttack) - 1;
}

/// Standard pursue + separation + obstacle avoidance + play area containment.
/// Reused across combat/attack/siege/defend pursuit phases.
/// Calls UnitUpdateSprite after movement so sprite and facing are always
/// current without each state needing to do it explicitly.
///
/// @param {Id.Instance}    _unit
/// @param {Struct.Vector2} _targetPos
/// @param {Struct.Vector2} [_targetVelocity] Pass undefined/Vector2(0,0) for stationary targets.
function UnitPursueTarget(_unit, _targetPos, _targetVelocity = undefined) {
    _targetVelocity ??= new Vector2(0, 0);

    var _obstacles = GatherNearbyObstacles(_unit);
    var _allies    = GatherNearbyAllies(_unit, 48);

    _unit.controller.Begin();
    _unit.controller.Add(
        Steering_Pursue(_unit.agent, _targetPos, _targetVelocity), 1.2
    );
    _unit.controller.Add(Steering_Separation(_unit.agent, _allies, 28),        1.0);
    _unit.controller.Add(Steering_AvoidObstacles(_unit.agent, _obstacles, 80), 1.8);
    _unit.controller.Add(
        Steering_Contain(_unit.agent, global.playAreaRect, PLAY_AREA_CONTAIN_MARGIN),
        PLAY_AREA_CONTAIN_WEIGHT
    );

    var _delta = _unit.controller.Apply();
    with(_unit){
        move_and_collide(_delta.x, _delta.y, [oBuildingParent, oEnvironmentSolid]);
    }
    _unit.agent.SyncFromInstance(_unit);

    UnitUpdateSprite(_unit);
}

/// Idles in place this frame (zero steering, still applies knockback
/// and collision). Calls UnitUpdateSprite so a standing unit still
/// shows the correct idle sprite after a hit reaction.
/// @param {Id.Instance} _unit
function UnitIdleInPlace(_unit) {
    _unit.controller.Begin();
    var _delta = _unit.controller.Apply();
    with(_unit){
        move_and_collide(_delta.x, _delta.y, [oBuildingParent, oEnvironmentSolid]);
    }
    _unit.agent.SyncFromInstance(_unit);
    UnitUpdateSprite(_unit);
}

/// Enters the attack animation on a unit and resets swing tracking.
/// @param {Id.Instance} _unit
/// @param {Struct}      _machine
function UnitBeginSwing(_unit, _machine) {
    _machine.data.hitDealtThisSwing = false;
    sprite_index = _unit.sprAttack;
    image_index  = 0;
    image_speed  = 1;
    // Do NOT touch image_xscale here -- the unit should keep facing
    // the direction it was already facing when the swing started.
}

/// Restores idle sprite and writes cooldown back to the instance.
/// Call at the end of any swing and from all Exit callbacks.
/// @param {Id.Instance} _unit
/// @param {Struct}      _machine
function UnitEndSwing(_unit, _machine) {
    sprite_index = _unit.sprIdle;
    image_index  = 0;
    image_speed  = 1;
    _unit.attackCooldown = max(_machine.data.cooldownTimer, 0);
}
