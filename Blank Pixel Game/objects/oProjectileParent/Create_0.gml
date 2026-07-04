// Safe defaults only -- ProjectileInit (ProjectileScripts.gml) fills in the
// real values immediately after instance_create_layer, same pattern as
// BuildingApplyDefinition/UnitApplyDefinition/TrainingSpawnUnit. Nothing
// should ever run against these placeholder values (ProjectileInit runs the
// same step this Create event does, before the first Step), but they're
// here so a stray reference before that doesn't crash.
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
