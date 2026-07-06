// Drifts, gently gathers downward gravity, fades, then self-destroys.
// Scaled by global.matchSpeed like every other timed/animated thing in
// this project (cooldowns, production, projectile flight), so effects
// pause along with the match instead of continuing to animate at 0x speed.
life -= global.matchSpeed;
if (life <= 0) {
    instance_destroy();
    exit;
}

x  += vx * global.matchSpeed;
y  += vy * global.matchSpeed;
vy += RESOURCE_PARTICLE_GRAVITY * global.matchSpeed;
