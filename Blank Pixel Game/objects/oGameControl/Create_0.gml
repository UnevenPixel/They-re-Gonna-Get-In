RegisterAllOrders();
RegisterAllUnitDefinitions();
RegisterAllBuildingDefinitions();
RegisterAllRulerPortraits(); // RulerPortraitScripts.gml -- 2026-07-11 request
PaletteSwapInit(); // caches shPaletteSwap's sampler/uniform handles once -- 2026-07-10 request, see PaletteSwapScripts.gml

// Which ruler's portrait/data is active this match. Hardcoded to Conelius
// for now -- he's the only one registered (RegisterAllRulerPortraits).
// Set here (game start) rather than per-match so it's available before
// oUnitControl's Create runs and looks it up. Replace with a real
// character-select flow once one exists.
global.selectedRuler = "conelius";

// Steamworks requires steam_shutdown() to NOT be called when the game is
// ending because of game_restart() (Steam stays "running" across a
// restart). Set this true immediately before any future game_restart()
// call, then back to false right after -- see the Game End event.
global.isGameRestarting = false;