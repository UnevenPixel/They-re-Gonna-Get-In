// Particle burst fired when a resource building produces one whole unit --
// one icon particle + a handful of sparkle squares, both handled by
// oResourceProducedParticle. See ResourceParticleScripts.md.

#macro RESOURCE_PARTICLE_SQUARE_COUNT 6              // sparkle squares per burst, alongside the 1 icon particle
#macro RESOURCE_PARTICLE_LIFE         40              // steps at 1x match speed before a particle fades out and self-destroys
#macro RESOURCE_PARTICLE_SPEED_MIN    0.4             // px/step at 1x match speed
#macro RESOURCE_PARTICLE_SPEED_MAX    1.2
#macro RESOURCE_PARTICLE_GRAVITY      0.03            // px/step^2 added to vy every step, at 1x match speed
#macro RESOURCE_PARTICLE_GOLD_COLOR   make_color_rgb(255, 215, 0) // "gold" end of the square particles' color range; c_white is the other end

/// @function SpawnResourceProducedParticles(_building, _resource)
/// @description Spawns one icon particle (_resource's sResourceIcons frame) plus RESOURCE_PARTICLE_SQUARE_COUNT sparkle squares at _building's position. Icon drifts up; squares burst outward with an upward bias, then fall under gravity. All fade/self-destroy after RESOURCE_PARTICLE_LIFE steps. No-ops the icon particle if _resource has no icon (e.g. xp/fateTokens). See .md.
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
