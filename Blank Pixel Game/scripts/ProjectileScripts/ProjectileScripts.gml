// Ranged-unit projectiles -- real position travels a flat straight line
// (collision/logic-relevant); the visual arc is Draw-event-only cosmetic.
// See ProjectileScripts.md.

/// @function SpawnProjectile(_unit, _target)
/// @description Spawns _unit's registered projectile (UnitDefinition.projectileObject) at _unit's position, aimed at _target's CURRENT position (not homing). Snapshots _unit's attackDamage. Logs and no-ops if no projectileObject is registered.
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
/// @description Sets up a freshly-created projectile's per-instance state. Call once, immediately after instance_create_layer. targetPos is captured ONCE at spawn -- not homing. See .md.
/// @param {Id.Instance} _proj
/// @param {Id.Instance} _owner The firing unit -- stored for kill-credit (ApplyDamage's _source).
/// @param {Id.Instance} _target
/// @param {Real} _damage
/// @param {Real} [_speed] Pixels/sec at 1x match speed. Defaults to 240.
/// @param {Real} [_arcHeight] Peak visual arc height in pixels (Draw-event only). Defaults to 24.
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
    // separate arc-following angle for rendering without writing back here.
    _proj.image_angle = _proj.startPos.AngleTo(_proj.targetPos);
}

/// @function ProjectileUpdateMovement(_proj)
/// @description Advances _proj's REAL x/y a fraction of the way from startPos to targetPos, straight-line, match-speed-scaled. Resolves the hit the instant progress reaches 1. Call once per Step (oProjectileParent/Step_0.gml).
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
/// @description Called the moment _proj reaches the end of its flight. Applies damage if the target still exists, then destroys the projectile either way.
/// @param {Id.Instance} _proj
function ProjectileResolveHit(_proj) {
    if (instance_exists(_proj.target)) {
        ApplyDamage(_proj.target, _proj.damage, _proj.owner);
    }
    instance_destroy(_proj);
}

/// @function ProjectileArcOffset(_proj, _progress)
/// @description Visual-only vertical offset for the parabolic arc -- 0 at launch/landing, peaking at -arcHeight at the midpoint. Purely cosmetic -- the real x/y stay on the flat line. See .md.
/// @param {Id.Instance} _proj
/// @param {Real} _progress 0..1
/// @returns {Real}
function ProjectileArcOffset(_proj, _progress) {
    return -sin(pi * _progress) * _proj.arcHeight;
}

/// @function ProjectileDraw(_proj)
/// @description Draws _proj's sprite offset by its current arc height, with a rotation that follows the arc's tangent instead of the flat stored image_angle. Call once per Draw (oProjectileParent/Draw_0.gml); replaces the default sprite draw entirely. See .md.
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

    // _p1 == _p2 only at the very last frame -- fall back to the flat
    // stored angle rather than feeding point_direction two identical points
    // (it returns 0, which would snap the sprite level right before impact).
    var _drawAngle = (_p1 >= 1) ? _proj.image_angle : point_direction(_drawX, _drawY, _drawX2, _drawY2);

    draw_sprite_ext(
        _proj.sprite_index, _proj.image_index,
        _drawX, _drawY,
        _proj.image_xscale, _proj.image_yscale,
        _drawAngle,
        _proj.image_blend, _proj.image_alpha
    );
}
