// Room-space, at this instance's own depth (room_height + 1, set in
// Create) -- draws the accumulated gore BEHIND every y-sorted unit/
// building, per the 2026-07-12 follow-up request's depth spec. Guard
// against a same-frame lost/not-yet-recreated surface (Step above handles
// recreation every frame, but Draw could in principle run before Step on
// the very first frame depending on event order) rather than crashing on a
// bad surface id.
if (surface_exists(global.gibSurface)) {
    draw_surface(global.gibSurface, 0, 0);
}
