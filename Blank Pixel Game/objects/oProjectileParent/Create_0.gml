// Safe placeholder defaults -- ProjectileInit overwrites all of this
// immediately after instance_create_layer. See oProjectileParent.md.
owner  = noone;
team   = TEAM.PLAYER;
target = noone;
damage = 0;

startPos  = new Vector2(x, y);
targetPos = new Vector2(x, y);

travelDist = 0;
speed      = 240;
travelTime = 0;
progress   = 0;
arcHeight  = 24;

image_angle = 0;
