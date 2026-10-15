# oGibSurfaceControl

2026-07-12 request ("set up gibbing"). Owns the single persistent room-space surface every landed gib chunk/unique gib/blood pixel/instant splatter gets permanently stamped onto (see `GibScripts.gml`/`oGibDebris`), so a room full of accumulated gore costs one `draw_surface` call instead of thousands of live instances.

## Create_0

`global.gibSurface = surface_create(room_width, room_height)` -- sized to the room exactly (not larger), since every gib/particle spawn point is a live unit's position, always inside the room.

`depth = room_height + 1` (positive) -- reversed per a 2026-07-12 follow-up request ("change the gib surface to below everything"). Every y-sorted instance in this project (`oUnitParent`, etc., via `depth = -y`) only ever ranges from `-room_height` to 0, so any positive depth draws BEFORE all of them -- gore sits under units/buildings instead of on top.

## Step_0

Surfaces can be lost outside this project's control (window resize, alt-tab on some platforms, graphics device reset) -- GameMaker's standard defensive pattern is to check `surface_exists` every Step and recreate if it's gone. Recreating loses every gib stamped so far (a blank surface, same as room start) -- an accepted tradeoff of using a surface at all rather than tracking every stamp as data to redraw; flag if persisting stamps across a lost-surface event turns out to matter in practice.

## Draw_0

Draws the accumulated gore surface at room-space (0,0), at this instance's own depth (`room_height + 1`, set in Create) so it renders behind every y-sorted unit/building. Guards against a same-frame lost/not-yet-recreated surface (Step handles recreation every frame, but Draw could in principle run before Step on the very first frame depending on event order) rather than crashing on a bad surface id.
