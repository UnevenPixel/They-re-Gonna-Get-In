// Hub town screen -- 2026-08-06 request. See HubTownMenuScripts.gml for the
// full behavior (options, hover-dim effect). Same "plain struct + thin
// object wrapper" split as oTitleMenu.
hubTownMenu = new HubTownMenu();

// 2026-08-13: Escape pause menu (Options/Return to Desktop/Return to Title
// Menu) -- same shared shape as oPreRunMenu. See HubPauseMenuScripts.md.
settingsOverlay = new SettingsOverlay();
hubPauseMenu    = new HubPauseMenu(settingsOverlay);
