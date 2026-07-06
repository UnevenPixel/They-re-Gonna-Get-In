// -----------------------------------------------------------
// ResourceParticleScripts -- the little burst of particles a resource
// building fires off every time it produces one whole unit of its
// resource. One particle shows the actual resource's icon (sResourceIcons,
// via ResourceIconIndex -- see ResourceUIScripts.gml); the rest are tiny
// 1-2px squares colored somewhere between gold and white, for a bit of
// sparkle around the real icon. Both particle "kinds" are handled by one
// object (oResourceProducedParticle) rather than two, since they share
// identical drift/gravity/fade/self-destroy behavior and differ only in
// what Draw does with them -- see that object's Create/Step/Draw.
//
// Wired from PlayResourceProducedEffect (BuildingDefinitions.gml), which
// BuildingUpdateProduction already calls exactly once per whole unit
// produced (even when several are produced in one frame).
// -----------------------------------------------------------

#macro RESOURCE_PARTICLE_SQUARE_COUNT 6              // sparkle squares per burst, alongside the 1 icon particle
#macro RESOURCE_PARTICLE_LIFE         40              // steps at 1x match speed before a particle fades out and self-destroys
#macro RESOURCE_PARTICLE_SPEED_MIN    0.4             // px/step at 1x match speed
#macro RESOURCE_PARTICLE_SPEED_MAX    1.2
#macro RESOURCE_PARTICLE_GRAVITY      0.03            // px/step^2 added to vy every step, at 1x match speed
#macro RESOURCE_PARTICLE_GOLD_COLOR   make_color_rgb(255, 215, 0) // "gold" end of the square particles' color range; c_white is the other end

/// @function SpawnResourceProducedParticles(_building, _resource)
/// @description Spawns one icon particle (the actual _resource's
///        sResourceIcons frame) plus RESOURCE_PARTICLE_SQUARE_COUNT tiny
///        square particles (1-2px, color randomly interpolated between
///        RESOURCE_PARTICLE_GOLD_COLOR and c_white) at _building's
///        position. The icon particle drifts straight up; squares burst
///        outward at a random angle/speed with a slight upward bias, then
///        gravity takes over. All particles fade out and self-destroy
///        after RESOURCE_PARTICLE_LIFE steps -- see
///        oResourceProducedParticle's Step/Draw.
///
///        No-ops the icon particle (squares still spawn) if _resource
///        isn't one of the 10 base resources sResourceIcons covers (e.g.
///        xp/fateTokens have no icon -- see ResourceIconIndex).
/// @param {Id.Instance} _building
/// @param {String} _resource
function SpawnResourceProducedParticles(_building, _resource) {
    var _iconIndex = ResourceIconIndex(_resource);
    if (_iconIndex != -1) {
        var _icon = instance_create_layer(_building.x, _building.y, "Instances", oResourceProducedParticle);
        _icon.kind          = "icon";
        _icon.resourceIndex = _iconIndex;
        _icon.vx            = 0;
        _icon.vy            = -RESOURCE_PARTICLE_SPEED_MIN; // gentle straight-up rise, no burst spread
        _icon.life          = RESOURCE_PARTICLE_LIFE;
        _icon.lifeMax        = RESOURCE_PARTICLE_LIFE;
    }

    repeat (RESOURCE_PARTICLE_SQUARE_COUNT) {
        var _angle  = random(360);
        var _speed  = random_range(RESOURCE_PARTICLE_SPEED_MIN, RESOURCE_PARTICLE_SPEED_MAX);

        var _square = instance_create_layer(_building.x, _building.y, "Instances", oResourceProducedParticle);
        _square.kind       = "square";
        _square.color      = merge_color(RESOURCE_PARTICLE_GOLD_COLOR, c_white, random(1));
        _square.squareSize = irandom_range(1, 2);
        _square.vx         = lengthdir_x(_speed, _angle);
        _square.vy         = lengthdir_y(_speed, _angle) - RESOURCE_PARTICLE_SPEED_MIN; // bias the burst upward
        _square.life       = RESOURCE_PARTICLE_LIFE;
        _square.lifeMax    = RESOURCE_PARTICLE_LIFE;
    }
}
