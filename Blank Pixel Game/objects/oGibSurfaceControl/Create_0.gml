// oGibSurfaceControl -- 2026-07-12 request ("set up gibbing"). Owns the
// single persistent room-space surface every landed gib chunk/unique gib/
// blood pixel/instant splatter gets permanently stamped onto (see
// GibScripts.gml/oGibDebris), so a room full of accumulated gore costs one
// draw_surface call instead of thousands of live instances.
//
// Sized to the room exactly (not larger) -- every gib/particle spawn point
// is a live unit's position, which is always inside the room, so nothing
// should ever need to stamp outside these bounds.
//
// depth = room_height + 1 (positive): reversed per 2026-07-12 follow-up
// request ("change the gib surface to below everything"). Every y-sorted
// instance in this project (oUnitParent, etc. via depth = -y) only ever
// ranges from -room_height to 0, so any positive depth draws BEFORE all of
// them -- gore now sits under units/buildings instead of on top.
global.gibSurface = surface_create(room_width, room_height);
depth = room_height + 1;
