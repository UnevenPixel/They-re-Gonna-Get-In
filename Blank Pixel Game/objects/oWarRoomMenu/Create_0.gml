// War room screen -- 2026-08-13 request, sits between the hub town and the
// pre-run (Campaign select) screen. See WarRoomMenuScripts.gml for the full
// behavior. Same "plain struct + thin object wrapper" split as oPreRunMenu.
warRoomMenu = new WarRoomMenu();

// Escape pause menu -- same shared shape as oHubTownMenu/oPreRunMenu. See
// HubPauseMenuScripts.md.
settingsOverlay = new SettingsOverlay();
hubPauseMenu    = new HubPauseMenu(settingsOverlay);
