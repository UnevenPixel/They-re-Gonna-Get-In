// Drifts, gathers gravity, fades, self-destroys. Scaled by global.matchSpeed
// so effects pause with the match. See oResourceProducedParticle.md.
life -= global.matchSpeed;
if (life <= 0) {
    instance_destroy();
    exit;
}

x  += vx * global.matchSpeed;
y  += vy * global.matchSpeed;
vy += RESOURCE_PARTICLE_GRAVITY * global.matchSpeed;
