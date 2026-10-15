// Pre-run (Campaign select) screen -- 2026-08-10 request. See
// PreRunMenuScripts.gml for the full behavior. Same "plain struct + thin
// object wrapper" split as oHubTownMenu.
preRunMenu = new PreRunMenu();

// 2026-08-13: Escape pause menu (Options/Return to Desktop/Return to Title
// Menu) -- same shared shape as oHubTownMenu. See HubPauseMenuScripts.md.
settingsOverlay = new SettingsOverlay();
hubPauseMenu    = new HubPauseMenu(settingsOverlay);
