// -----------------------------------------------------------
// Projectiles -- spawned by ranged units (see UnitTryFireProjectile,
// UnitCombatHelpers.gml) instead of dealing damage instantly. A
// projectile's REAL position (x/y, what everything else in the game would
// see if it looked) travels in a flat straight line from launch point to
// target point; the parabolic "arcs upward then lands" look is purely
// cosmetic, applied only in the Draw event (ProjectileDraw) as a vertical
// offset + a separately-computed rotation. image_angle itself is set once
// at spawn to the flat straight-line direction and never touched again --
// see ProjectileInit / ProjectileDraw for the split.
//
// Only one projectile type exists so far (oArcherProjectile), but this is
// written generically (oProjectileParent + UnitDefinition.projectileObject)
// so future ranged units can register their own without touching any of
// this file.
// -----------------------------------------------------------

/// @function SpawnProjectile(_unit, _target)
/// @description Spawns _unit's registered projectile object
///        (UnitDefinition.projectileObject) at _unit's position, aimed at
///        _target's position at THIS moment (not homing -- see
///        ProjectileInit). Snapshots _unit's current attackDamage as the
///        projectile's damage, so a later buff/debuff to _unit doesn't
///        retroactively change a shot already in flight. Logs and no-ops
///        if _unit's UnitDefinition has no projectileObject registered.
/// @param {Id.Instance} _unit
/// @param {Id.Instance} _target
/// @returns {Id.Instance|Constant.NoOne}
function SpawnProjectile(_unit, _target) {
    var _def = GetUnitDefinition(_unit.object_index);
    if (_def == undefined || _def.projectileObject == undefined) {
        show_debug_message($"SpawnProjectile: {object_get_name(_unit.object_index)} has no projectileObject registered -- check its UnitDefinition (UnitDefinitions.gml).");
        return noone;
    }

    var _proj = instance_create_layer(_unit.x, _unit.y, "Instances", _def.projectileObject);
    ProjectileInit(_proj, _unit, _target, _unit.attackDamage);
    return _proj;
}

/// @function ProjectileInit(_proj, _owner, _target, _damage, _speed, _arcHeight)
/// @description Sets up a freshly-created projectile's per-instance state.
///        Call once, immediately after instance_create_layer -- same
///        pattern as BuildingApplyDefinition/UnitApplyDefinition/
///        TrainingSpawnUnit (Create sets safe defaults, a script function
///        fills in the real values right after).
///
///        targetPos is captured ONCE here (the target's position at the
///        moment of firing) -- the projectile is not homing. If _target is
///        destroyed mid-flight, it keeps flying to that fixed point and
///        simply finds no one home when it lands (see ProjectileResolveHit).
/// @param {Id.Instance} _proj
/// @param {Id.Instance} _owner The firing unit -- stored for kill-credit
///        (ApplyDamage's _source) and so a stray shot can be attributed to
///        someone even after _owner itself is gone by the time it lands.
/// @param {Id.Instance} _target
/// @param {Real} _damage
/// @param {Real} [_speed] Pixels/sec at 1x match speed. Defaults to 240.
/// @param {Real} [_arcHeight] Peak visual arc height in pixels (Draw-event
///        only -- see ProjectileArcOffset). Defaults to 24.
function ProjectileInit(_proj, _owner, _target, _damage, _speed = 240, _arcHeight = 24) {
    _proj.owner  = _owner;
    _proj.team   = variable_instance_exists(_owner, "team") ? _owner.team : TEAM.PLAYER;
    _proj.target = _target;
    _proj.damage = _damage;

    _proj.startPos  = new Vector2(_proj.x, _proj.y);
    _proj.targetPos = instance_exists(_target) ? new Vector2(_target.x, _target.y) : _proj.startPos.Copy();

    _proj.travelDist = _proj.startPos.Distance(_proj.targetPos);
    _proj.speed      = _speed;
    _proj.travelTime = (_proj.speed > 0) ? (_proj.travelDist / _proj.speed) : 0; // seconds, at 1x match speed
    _proj.progress   = 0;
    _proj.arcHeight  = _arcHeight;

    // The REAL, stored image_angle -- flat straight-line direction, set
    // once and never touched again. ProjectileDraw computes its own
    // separate arc-following angle for rendering without ever writing back
    // to this.
    _proj.image_angle = _proj.startPos.AngleTo(_proj.targetPos);
}

/// @function ProjectileUpdateMovement(_proj)
/// @description Advances _proj's REAL position (x/y) a fraction of the way
///        from startPos to targetPos, straight-line, match-speed-scaled --
///        same delta_time/global.matchSpeed idiom as
///        BuildingUpdateProduction/TrainingUpdateQueue. Resolves the hit
///        (ProjectileResolveHit) the instant progress reaches 1, including
///        immediately on the same step if travelTime is 0 (target was
///        already standing on the launch point).
///        Call once per Step (oProjectileParent/Step_0.gml).
/// @param {Id.Instance} _proj
function ProjectileUpdateMovement(_proj) {
    if (_proj.travelTime <= 0) {
        ProjectileResolveHit(_proj);
        return;
    }

    var _dt = delta_time / 1000000;
    _proj.progress += (global.matchSpeed * _dt) / _proj.travelTime;

    if (_proj.progress >= 1) {
        _proj.progress = 1;
        ProjectileResolveHit(_proj);
        return;
    }

    var _pos = _proj.startPos.GetLerp(_proj.targetPos, _proj.progress);
    _proj.x = _pos.x;
    _proj.y = _pos.y;
}

/// @function ProjectileResolveHit(_proj)
/// @description Called the moment _proj reaches the end of its flight.
///        Applies damage via ApplyDamage (UnitCombatHelpers.gml) if the
///        target is still around to hit, then destroys the projectile
///        either way -- a target that died mid-flight just means the shot
///        whiffs, it doesn't crash or linger.
/// @param {Id.Instance} _proj
function ProjectileResolveHit(_proj) {
    if (instance_exists(_proj.target)) {
        ApplyDamage(_proj.target, _proj.damage, _proj.owner);
    }
    instance_destroy(_proj);
}

/// @function ProjectileArcOffset(_proj, _progress)
/// @description Visual-only vertical offset for the parabolic arc -- 0 at
///        launch and landing, peaking at -_proj.arcHeight (negative = up on
///        screen, since GameMaker's y grows downward) at the midpoint of
///        flight. Purely cosmetic: _proj.x/_proj.y (the real,
///        collision/logic-relevant position, and what ProjectileResolveHit
///        acts on) stay on the flat line the whole flight -- only the DRAWN
///        position (ProjectileDraw) is affected.
/// @param {Id.Instance} _proj
/// @param {Real} _progress 0..1
/// @returns {Real}
function ProjectileArcOffset(_proj, _progress) {
    return -sin(pi * _progress) * _proj.arcHeight;
}

/// @function ProjectileDraw(_proj)
/// @description Draws _proj's sprite offset by its current arc height, with
///        a rotation that follows the arc's tangent -- steep nose-up at
///        launch, level at the apex, steep nose-down at landing -- instead
///        of the flat _proj.image_angle (which stays the straight-line
///        launch direction for the whole flight, see ProjectileInit).
///        Samples the arc's slope numerically (drawn position a hair
///        further along the flight, vs. right now) rather than
///        differentiating ProjectileArcOffset by hand, so the visible angle
///        can never drift out of sync with the visible offset -- they're
///        computed from the exact same function.
///        Call once per Draw (oProjectileParent/Draw_0.gml). Replaces the
///        default sprite draw entirely -- this object should NOT also get
///        a default (event-less) draw.
/// @param {Id.Instance} _proj
function ProjectileDraw(_proj) {
    var _p1 = _proj.progress;
    var _p2 = clamp(_p1 + 0.02, 0, 1);

    var _pos1 = _proj.startPos.GetLerp(_proj.targetPos, _p1);
    var _pos2 = _proj.startPos.GetLerp(_proj.targetPos, _p2);

    var _drawX = _pos1.x;
    var _drawY = _pos1.y + ProjectileArcOffset(_proj, _p1);
    var _drawX2 = _pos2.x;
    var _drawY2 = _pos2.y + ProjectileArcOffset(_proj, _p2);

    // _p1 == _p2 only at the very last frame (both already clamped to 1) --
    // fall back to the flat stored angle rather than feeding
    // point_direction two identical points (it returns 0, which would snap
    // the sprite level right before impact).
    var _drawAngle = (_p1 >= 1) ? _proj.image_angle : point_direction(_drawX, _drawY, _drawX2, _drawY2);

    draw_sprite_ext(
        _proj.sprite_index, _proj.image_index,
        _drawX, _drawY,
        _proj.image_xscale, _proj.image_yscale,
        _drawAngle,
        _proj.image_blend, _proj.image_alpha
    );
}
