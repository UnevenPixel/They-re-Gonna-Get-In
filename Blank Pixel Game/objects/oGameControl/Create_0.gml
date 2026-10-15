// One-time game-start registration + settings/save-data load. See
// oGameControl.md.
RegisterAllOrders();
RegisterAllUnitDefinitions();
RegisterAllBuildingDefinitions();
RegisterAllRulerPortraits();
PaletteSwapInit();
CursorInit(); // hides the system cursor; Draw GUI End draws the custom one
TitleMenuFlagWaveInit();

LoadAndApplyGameSettings(); // player settings (audio/fullscreen/borderless/gamma) -- see .md
LoadAndApplyPlayerSaveData(); // player save data (progression/unlocks/tutorial-seen) -- see .md

global.selectedRuler = "conelius"; // hardcoded -- only ruler registered; see .md

global.isGameRestarting = false; // Steamworks shutdown-lifecycle guard, see Other_3 / .md
