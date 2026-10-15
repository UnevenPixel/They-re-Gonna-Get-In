// Game End -- skips steam_shutdown() when ending via game_restart() (Steam
// stays running across a restart). See oGameControl.md.
if (!global.isGameRestarting) {
    steam_shutdown();
}
global.isGameRestarting = false;
