RegisterAllOrders();
RegisterAllUnitDefinitions();
RegisterAllBuildingDefinitions();
PaletteSwapInit(); // caches shPaletteSwap's sampler/uniform handles once -- 2026-07-10 request, see PaletteSwapScripts.gml

// Steamworks requires steam_shutdown() to NOT be called when the game is
// ending because of game_restart() (Steam stays "running" across a
// restart). Set this true immediately before a