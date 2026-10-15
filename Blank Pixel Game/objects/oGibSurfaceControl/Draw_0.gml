// Draws the accumulated gore surface. Guards against a same-frame
// lost/not-yet-recreated surface. See oGibSurfaceControl.md.
if (surface_exists(global.gibSurface)) {
    draw_surface(global.gibSurface, 0, 0);
}
