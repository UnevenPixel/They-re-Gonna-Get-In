# oProjectileParent

Base object for ranged-unit projectiles (`oArcherProjectile`, etc.). See `ProjectileScripts.gml` for the real logic -- this object is almost entirely delegation.

## Create_0

Safe placeholder defaults only (`owner`/`team`/`target`/`damage`/`startPos`/`targetPos`/`travelDist`/`speed`/`travelTime`/`progress`/`arcHeight`/`image_angle`) -- `ProjectileInit` (`ProjectileScripts.gml`) fills in the real values immediately after `instance_create_layer`, same pattern as `BuildingApplyDefinition`/`UnitApplyDefinition`/`TrainingSpawnUnit`. Nothing should ever run against these placeholder values (`ProjectileInit` runs the same step this Create event does, before the first Step), but they're here so a stray reference before that doesn't crash.

## Step_0

`ProjectileUpdateMovement(self)` -- straight-line real-position movement + hit resolution. The cosmetic arc is entirely a Draw-event concern; nothing here.

## Draw_0

`ProjectileDraw(self)` -- overrides the default sprite draw entirely (arc-offset + arc-following-angle rendering, see `ProjectileScripts.gml`). Do not add a plain `draw_self()` anywhere else on this object; it would double-draw.
