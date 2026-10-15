// Recreates the gib surface if lost (window resize/alt-tab/device reset).
// Loses accumulated stamps -- accepted tradeoff, see oGibSurfaceControl.md.
if (!surface_exists(global.gibSurface)) {
    global.gibSurface = surface_create(room_width, room_height);
}
