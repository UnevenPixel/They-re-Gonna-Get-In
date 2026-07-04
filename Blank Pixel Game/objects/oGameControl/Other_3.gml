// Steamworks requires steam_shutdown() to be called when the game actually
// ends -- but NOT when the game is ending because of a game_restart() call,
// since Steam itself stays running across a restart. global.isGameRestarting
// (set in this object's Create event) is the guard: whatever code calls
// game_restart() should set it true immediately beforehand, e.g.
//     global.isGameRestarting = true;
//     game_restart();
// so this event can skip the shutdown call for that one case.
if (!global.isGameRestarting) {
    steam_shutdown();
}
global.isGameRestarting = false;
