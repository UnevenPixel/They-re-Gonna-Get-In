// Surfaces can be lost outside this project's control (window resize,
// alt-tab on some platforms, graphics device reset) -- GameMaker's
// standard defensive pattern is to check surface_exists every Step and
// recreate if it's gone. Recreating loses every gib stamped so far (a
// blank surface, same as room start) -- an accepted tradeoff of using a
// surface at all rather than tracking every stamp as data to redraw;
// flag if persisting stamps across a lost-surface event turns out to
// matter in practice.
if (!surface_exists(global.gibSurface)) {
    global.gibSurface = surface_create(room_width, room_height);
}
