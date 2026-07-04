// Inherit oProjectileParent -- sprite is set via spriteId above, everything
// else (owner/target/damage/motion state) comes from ProjectileInit right
// after this instance is created (see SpawnProjectile, ProjectileScripts.gml).
event_inherited();
