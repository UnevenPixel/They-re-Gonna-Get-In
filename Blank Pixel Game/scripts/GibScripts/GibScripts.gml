// -----------------------------------------------------------
// GibScripts -- 2026-07-12 request: "Set up gibbing for all units when
// they die (except the golem, we will handle his)." Owns the physics for
// flying debris (oGibDebris), the spawn helpers that configure one for a
// specific job (general chunk / a unit's own unique gib / a single-pixel
// blood particle), the instant (no-physics) blood splatter stamp, and the
// two orchestrators everything else calls: SpawnUnitHitBlood (non-lethal
// hit) and SpawnUnitDeathGibs (death) -- both called from ApplyDamage
// (UnitCombatHelpers.gml), the one choke point ALL damage in this game
// already routes through (melee AND ranged/projectile alike), so hooking
// there is the only place this needs to be wired in.
//
// Mud Golem is excluded from BOTH orchestrators entirely (hard-exits
// immediately) per explicit 2026-07-12 clarification -- "except the golem,
// we will handle his" covers hit particles too, not just the death
// sequence, since he's hit constantly in normal play and the request was
// clear this should be fully hands-off for him this pass.
//
// Every landed piece of debris (and every instant splatter) gets stamped
// onto global.gibSurface (oGibSurfaceControl.gml) and then either destroys
// itself (debris) or was never a live instance at all (splatter) -- gore
// accumulates as pixels on one surface, not as a permanently growing pile
// of live instances.
// -----------------------------------------------------------

#macro GIB_GRAVITY         0.15 // z-axis "fake gravity" decel, px/step^2 at 1x match speed -- placeholder, not tuned against any real fall-time target
#macro GIB_GROUND_FRICTION 0.9  // vx/vy multiplier applied every step (drag on the ground-plane fling) -- placeholder
#macro GIB_SPIN_SPEED       6    // max degrees/step spin (kind == "sprite" debris only), actual value randomized +/- this each spawn -- placeholder

#macro GIB_FLING_SPEED_MIN 0.5 // general chunks + unique gibs -- initial ground-plane fling speed range, away from the killer
#macro GIB_FLING_SPEED_MAX 2.2
#macro GIB_FLING_SPREAD     50  // degrees of random spread around the dead-away-from-killer direction
#macro GIB_POP_MIN          1.6 // initial vz ("pop" off the ground) range for chunks/unique gibs
#macro GIB_POP_MAX          3.2

#macro BLOOD_PIXEL_FLING_MIN 0.3 // single-pixel blood particles -- smaller/quicker arc than chunks
#macro BLOOD_PIXEL_FLING_MAX 1.6
#macro BLOOD_PIXEL_SPREAD     70  // wider spray than chunks -- droplets scatter more randomly than solid debris
#macro BLOOD_PIXEL_POP_MIN    0.8
#macro BLOOD_PIXEL_POP_MAX    2.2
#macro BLOOD_PIXEL_COLOR_DARK   make_color_rgb(90,  0, 0)
#macro BLOOD_PIXEL_COLOR_BRIGHT make_color_rgb(190, 20, 20)

#macro GIB_HIT_PARTICLE_MIN   2 // on-hit blood particle count range, part A of the 2026-07-12 request
#macro GIB_HIT_PARTICLE_MAX   4
#macro GIB_DEATH_PARTICLE_MIN 4 // on-death blood particle count range, part B
#macro GIB_DEATH_PARTICLE_MAX 8
#macro GIB_CHUNK_COUNT_MIN    3 // general-chunk burst size on death -- not specified by the request, picked to read as "a few pieces," not a pile
#macro GIB_CHUNK_COUNT_MAX    5

// 2026-07-12 follow-up ("add grey particles to buildings when they are
// hit") -- shares BLOOD_PIXEL_FLING_MIN/MAX/SPREAD/POP_MIN/MAX's physics
// profile via SpawnColorPixel (buildings getting hit is visually the same
// "small particle kicks off the impact point" beat as a unit bleeding, just
// a different color), so only the color range + count need their own
// macros. Flat grays, not tinted toward any particular building -- explicit
// placeholder per the request ("default everything to shades of gray for
// now"); BuildingDefinition.hitParticleColorDark/Bright (BuildingDefinitions.gml)
// lets a future pass override per building type without touching this file.
#macro BUILDING_HIT_PARTICLE_COLOR_DARK   make_color_rgb(70,  70,  70)
#macro BUILDING_HIT_PARTICLE_COLOR_BRIGHT make_color_rgb(170, 170, 170)
#macro GIB_BUILDING_HIT_PARTICLE_MIN 2 // count range not specified by the request -- matched to GIB_HIT_PARTICLE_MIN/MAX (unit on-hit blood) for a consistent "small burst" feel
#macro GIB_BUILDING_HIT_PARTICLE_MAX 4

// -----------------------------------------------------------
// oGibDebris physics -- called from that object's Step/Draw events.
// -----------------------------------------------------------

/// @function GibDebrisStep(_debris)
/// @description Per-step fake-gravity update for one oGibDebris instance.
///        Ground position (x, y) slides via vx/vy, dragged down every step
///        by GIB_GROUND_FRICTION -- the "flung away from who killed them"
///        half of the request. z is a SEPARATE, purely visual height,
///        pulled back down by GIB_GRAVITY every step -- the "arch" half;
///        it never feeds back into x/y. Landing is detected the instant z
///        crosses back down through 0 having been above it (guards
///        against triggering on the spawn frame, before the initial "pop"
///        has even been applied) -- at that point this "stops moving" per
///        the request, and GibDebrisLand stamps + destroys it.
/// @param {Id.Instance} _debris An oGibDebris instance.
function GibDebrisStep(_debris) {
    with (_debris) {
        x  += vx * global.matchSpeed;
        y  += vy * global.matchSpeed;
        vx *= GIB_GROUND_FRICTION;
        vy *= GIB_GROUND_FRICTION;

        var _wasAboveGround = (z > 0);
        z  += vz * global.matchSpeed;
        vz -= GIB_GRAVITY * global.matchSpeed;

        angle += spinSpeed * global.matchSpeed;

        if (_wasAboveGround && z <= 0) {
            z = 0;
            GibDebrisLand(id);
        }
    }
}

/// @function GibDebrisDraw(_debris)
/// @description Draws one still-flying oGibDebris at (x, y - z) -- the z
///        offset is what makes the arch visible. kind == "pixel" draws a
///        flat-color pixelSize square (same draw_rectangle idiom as
///        oResourceProducedParticle's "square" kind); kind == "sprite"
///        draws gibSprite's frame with the current rotation.
/// @param {Id.Instance} _debris An oGibDebris instance.
function GibDebrisDraw(_debris) {
    with (_debris) {
        if (kind == "pixel") {
            draw_set_color(pixelColor);
            draw_rectangle(x - pixelSize / 2, y - z - pixelSize / 2, x + pixelSize / 2, y - z + pixelSize / 2, false);
        } else {
            draw_sprite_ext(gibSprite, frame, x, y - z, 1, 1, angle, c_white, 1);
        }
    }
}

/// @function GibDebrisLand(_debris)
/// @description Stamps _debris's current appearance onto global.gibSurface
///        at its final resting (x, y) -- z is already 0 by the time this
///        runs (GibDebrisStep clamps it before calling this) -- then
///        destroys the live instance. No-ops the stamp (still destroys)
///        if the surface has been lost and not yet recreated this frame
///        (oGibSurfaceControl.Step normally beats every oGibDebris to it,
///        but this is a cheap belt-and-suspenders check rather than
///        assuming event order).
/// @param {Id.Instance} _debris An oGibDebris instance.
function GibDebrisLand(_debris) {
    if (surface_exists(global.gibSurface)) {
        surface_set_target(global.gibSurface);
        with (_debris) {
            if (kind == "pixel") {
                draw_set_color(pixelColor);
                draw_rectangle(x - pixelSize / 2, y - pixelSize / 2, x + pixelSize / 2, y + pixelSize / 2, false);
            } else {
                draw_sprite_ext(gibSprite, frame, x, y, 1, 1, angle, c_white, 1);
            }
        }
        surface_reset_target();
    }

    instance_destroy(_debris);
}

// -----------------------------------------------------------
// Spawn helpers -- configure one oGibDebris (sprite or pixel kind) with a
// fling direction "away from who killed them" (GibFlingAngle), then hand
// off to GibDebrisStep every following Step until it lands.
// -----------------------------------------------------------

/// @function GibFlingAngle(_x, _y, _sourceX, _sourceY, _spread)
/// @description Direction (degrees) debris flung from (_x, _y) should
///        travel: straight out along the line from the killer through the
///        victim (point_direction(_sourceX, _sourceY, _x, _y)), plus
///        random +/-_spread degrees of scatter so a burst doesn't fly in
///        a single perfect line. Falls back to a fully random angle if
///        _sourceX is undefined -- no attributable killer (e.g. _source
///        was noone/already gone by the time ApplyDamage ran).
/// @param {Real} _x
/// @param {Real} _y
/// @param {Real|Undefined} _sourceX
/// @param {Real|Undefined} _sourceY
/// @param {Real} _spread Degrees of random scatter around the base angle.
/// @returns {Real}
function GibFlingAngle(_x, _y, _sourceX, _sourceY, _spread) {
    var _base = (_sourceX == undefined) ? random(360) : point_direction(_sourceX, _sourceY, _x, _y);
    return _base + random_range(-_spread, _spread);
}

/// @function SpawnGibDebrisSprite(_x, _y, _sourceX, _sourceY, _sprite)
/// @description Spawns one sprite-kind oGibDebris at (_x, _y) -- used for
///        both the shared sGeneralChunks burst and a unit's own unique
///        gibSprite. Picks a random frame if _sprite has more than one
///        (sGeneralChunks/sGeneralSplatters do; per-unit gibs are single-
///        frame, this is a no-op there) and a random starting rotation +
///        spin. Fling direction/speed and initial "pop" per
///        GIB_FLING_SPEED_MIN/MAX/GIB_FLING_SPREAD/GIB_POP_MIN/MAX.
/// @param {Real} _x
/// @param {Real} _y
/// @param {Real|Undefined} _sourceX Killer's x, or undefined if unattributed.
/// @param {Real|Undefined} _sourceY Killer's y, or undefined if unattributed.
/// @param {Asset.GMSprite} _sprite
/// @returns {Id.Instance} The spawned oGibDebris.
function SpawnGibDebrisSprite(_x, _y, _sourceX, _sourceY, _sprite) {
    var _angle = GibFlingAngle(_x, _y, _sourceX, _sourceY, GIB_FLING_SPREAD);
    var _speed = random_range(GIB_FLING_SPEED_MIN, GIB_FLING_SPEED_MAX);

    var _debris = instance_create_layer(_x, _y, "Instances", oGibDebris);
    _debris.kind      = "sprite";
    _debris.gibSprite = _sprite;
    _debris.frame     = irandom(max(sprite_get_number(_sprite) - 1, 0));
    _debris.angle     = random(360);
    _debris.spinSpeed = random_range(-GIB_SPIN_SPEED, GIB_SPIN_SPEED);
    _debris.vx        = lengthdir_x(_speed, _angle);
    _debris.vy        = lengthdir_y(_speed, _angle);
    _debris.vz        = random_range(GIB_POP_MIN, GIB_POP_MAX);
    return _debris;
}

/// @function SpawnColorPixel(_x, _y, _sourceX, _sourceY, _colorDark, _colorBright)
/// @description Spawns one pixel-kind oGibDebris at (_x, _y) -- a single
///        1px flat-color dot, randomly interpolated between _colorDark and
///        _colorBright (same merge_color(..., random(1)) idiom
///        SpawnResourceProducedParticles uses for its gold-to-white square
///        particles). Fling direction/speed and initial "pop" per
///        BLOOD_PIXEL_FLING_MIN/MAX/BLOOD_PIXEL_SPREAD/BLOOD_PIXEL_POP_MIN/MAX
///        -- smaller and wider-scattering than SpawnGibDebrisSprite's
///        chunks. Generalized 2026-07-12 follow-up (was SpawnBloodPixel,
///        hardcoded to blood-red) so SpawnBuildingHitParticles' gray
///        particles can reuse the exact same physics profile -- the
///        BLOOD_PIXEL_* physics macro names are stale (kept as-is to avoid
///        an unrelated rename) but now describe "single pixel particle"
///        physics generically, not blood specifically.
/// @param {Real} _x
/// @param {Real} _y
/// @param {Real|Undefined} _sourceX Killer's/attacker's x, or undefined if unattributed.
/// @param {Real|Undefined} _sourceY Killer's/attacker's y, or undefined if unattributed.
/// @param {Constant.Color} _colorDark
/// @param {Constant.Color} _colorBright
/// @returns {Id.Instance} The spawned oGibDebris.
function SpawnColorPixel(_x, _y, _sourceX, _sourceY, _colorDark, _colorBright) {
    var _angle = GibFlingAngle(_x, _y, _sourceX, _sourceY, BLOOD_PIXEL_SPREAD);
    var _speed = random_range(BLOOD_PIXEL_FLING_MIN, BLOOD_PIXEL_FLING_MAX);

    var _debris = instance_create_layer(_x, _y, "Instances", oGibDebris);
    _debris.kind       = "pixel";
    _debris.pixelColor = merge_color(_colorDark, _colorBright, random(1));
    _debris.pixelSize  = 1;
    _debris.vx         = lengthdir_x(_speed, _angle);
    _debris.vy         = lengthdir_y(_speed, _angle);
    _debris.vz         = random_range(BLOOD_PIXEL_POP_MIN, BLOOD_PIXEL_POP_MAX);
    return _debris;
}

/// @function SpawnBloodPixel(_x, _y, _sourceX, _sourceY)
/// @description Thin BLOOD_PIXEL_COLOR_DARK/BRIGHT wrapper around
///        SpawnColorPixel -- unchanged behavior/signature from before the
///        2026-07-12 generalization, every existing call site is untouched.
/// @param {Real} _x
/// @param {Real} _y
/// @param {Real|Undefined} _sourceX Killer's/attacker's x, or undefined if unattributed.
/// @param {Real|Undefined} _sourceY Killer's/attacker's y, or undefined if unattributed.
/// @returns {Id.Instance} The spawned oGibDebris.
function SpawnBloodPixel(_x, _y, _sourceX, _sourceY) {
    return SpawnColorPixel(_x, _y, _sourceX, _sourceY, BLOOD_PIXEL_COLOR_DARK, BLOOD_PIXEL_COLOR_BRIGHT);
}

/// @function DrawBloodSplatterInstant(_x, _y)
/// @description Stamps one random sGeneralSplatters frame directly onto
///        global.gibSurface at (_x, _y), at a random rotation -- NO live
///        instance, no physics, per the request ("instantly draw the
///        blood splatters"). No-ops if the surface has been lost and not
///        yet recreated this frame.
/// @param {Real} _x
/// @param {Real} _y
function DrawBloodSplatterInstant(_x, _y) {
    if (!surface_exists(global.gibSurface)) return;

    surface_set_target(global.gibSurface);
    var _frame = irandom(sprite_get_number(sGeneralSplatters) - 1);
    draw_sprite_ext(sGeneralSplatters, _frame, _x, _y, 1, 1, random(360), c_white, 1);
    surface_reset_target();
}

// -----------------------------------------------------------
// Orchestrators -- called from ApplyDamage (UnitCombatHelpers.gml), the
// single choke point every damage source (melee AND ranged/projectile)
// already routes through.
// -----------------------------------------------------------

/// @function SpawnUnitHitBlood(_unit, _source)
/// @description Part A of the 2026-07-12 blood-particle request: spawns
///        GIB_HIT_PARTICLE_MIN-MAX (2-4) blood pixels at _unit's position
///        every time it takes a NON-LETHAL hit. Mud Golem is fully
///        excluded (hard exit) -- see this file's header comment for why.
/// @param {Id.Instance} _unit The unit that was just hit (still alive).
/// @param {Id.Instance} _source The attacker, or noone -- passed straight
///        through to SpawnBloodPixel's fling-direction calculation.
function SpawnUnitHitBlood(_unit, _source) {
    if (_unit.object_index == oMudGolemUnit) return;

    var _hasSource = (_source != noone && instance_exists(_source));
    var _sourceX   = _hasSource ? _source.x : undefined;
    var _sourceY   = _hasSource ? _source.y : undefined;

    repeat (irandom_range(GIB_HIT_PARTICLE_MIN, GIB_HIT_PARTICLE_MAX)) {
        SpawnBloodPixel(_unit.x, _unit.y, _sourceX, _sourceY);
    }
}

/// @function SpawnBuildingHitParticles(_building, _source)
/// @description The building equivalent of SpawnUnitHitBlood -- 2026-07-12
///        follow-up ("add grey particles to buildings when they are hit").
///        Spawns GIB_BUILDING_HIT_PARTICLE_MIN-MAX (2-4) single-pixel
///        particles at _building's position every time it takes a NON-
///        LETHAL hit, reusing the exact same pixel-kind oGibDebris physics
///        as blood (SpawnColorPixel) but in gray tones -- buildings don't
///        bleed. No Mud Golem-style exclusion (buildings have no such
///        concept). Reads an optional per-building color override off
///        BuildingDefinition.hitParticleColorDark/Bright (BuildingDefinitions.gml);
///        falls back to the shared BUILDING_HIT_PARTICLE_COLOR_DARK/BRIGHT
///        grays when either is unset (every building today).
/// @param {Id.Instance} _building The building that was just hit (still alive).
/// @param {Id.Instance} _source The attacker, or noone -- passed straight
///        through to SpawnColorPixel's fling-direction calculation.
function SpawnBuildingHitParticles(_building, _source) {
    var _hasSource = (_source != noone && instance_exists(_source));
    var _sourceX   = _hasSource ? _source.x : undefined;
    var _sourceY   = _hasSource ? _source.y : undefined;

    var _def = GetBuildingDefinition(_building.object_index);
    var _colorDark = (_def != undefined && _def.hitParticleColorDark != undefined)
        ? _def.hitParticleColorDark
        : BUILDING_HIT_PARTICLE_COLOR_DARK;
    var _colorBright = (_def != undefined && _def.hitParticleColorBright != undefined)
        ? _def.hitParticleColorBright
        : BUILDING_HIT_PARTICLE_COLOR_BRIGHT;

    repeat (irandom_range(GIB_BUILDING_HIT_PARTICLE_MIN, GIB_BUILDING_HIT_PARTICLE_MAX)) {
        SpawnColorPixel(_building.x, _building.y, _sourceX, _sourceY, _colorDark, _colorBright);
    }
}

/// @function SpawnUnitDeathGibs(_unit, _source)
/// @description The full on-death gib sequence, per the 2026-07-12
///        request. Mud Golem is fully excluded (hard exit) -- "we will
///        handle his," see this file's header comment. For every other
///        unit, in order:
///          1. Instant blood splatter (DrawBloodSplatterInstant) --
///             always, including Bomb Goblin.
///          2. GIB_CHUNK_COUNT_MIN-MAX (3-5) general chunks
///             (SpawnGibDebrisSprite w/ sGeneralChunks) -- only if this
///             unit's UnitDefinition.usesGeneralChunks is true (false for
///             Bomb Goblin only, see UnitDefinitions.gml).
///          3. This unit's own unique gib (SpawnGibDebrisSprite w/
///             UnitDefinition.gibSprite) -- only if one is registered
///             (undefined for Bomb Goblin -- no sprite exists for it yet).
///          4. GIB_DEATH_PARTICLE_MIN-MAX (4-8) blood pixels (part B of
///             the blood-particle request) -- always, including Bomb
///             Goblin.
///        Must be called BEFORE the caller destroys _unit -- reads
///        _unit.x/_unit.y/_unit.object_index, all of which need the
///        instance to still exist.
/// @param {Id.Instance} _unit The unit that just died (still exists -- not destroyed yet).
/// @param {Id.Instance} _source The killer, or noone -- passed straight
///        through to every spawn helper's fling-direction calculation.
function SpawnUnitDeathGibs(_unit, _source) {
    if (_unit.object_index == oMudGolemUnit) return;

    var _hasSource = (_source != noone && instance_exists(_source));
    var _sourceX   = _hasSource ? _source.x : undefined;
    var _sourceY   = _hasSource ? _source.y : undefined;

    DrawBloodSplatterInstant(_unit.x, _unit.y);

    var _def = GetUnitDefinition(_unit.object_index);
    if (_def != undefined) {
        if (_def.usesGeneralChunks) {
            repeat (irandom_range(GIB_CHUNK_COUNT_MIN, GIB_CHUNK_COUNT_MAX)) {
                SpawnGibDebrisSprite(_unit.x, _unit.y, _sourceX, _sourceY, sGeneralChunks);
            }
        }
        if (_def.gibSprite != undefined) {
            SpawnGibDebrisSprite(_unit.x, _unit.y, _sourceX, _sourceY, _def.gibSprite);
        }
    }

    repeat (irandom_range(GIB_DEATH_PARTICLE_MIN, GIB_DEATH_PARTICLE_MAX)) {
        SpawnBloodPixel(_unit.x, _unit.y, _sourceX, _sourceY);
    }
}
