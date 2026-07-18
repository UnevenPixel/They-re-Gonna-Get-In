// Title/main menu screen -- 2026-07-13 request. See TitleMenuScripts.gml
// for the full state sequence and every layout/animation constant.
//
// settingsOverlay -- 2026-07-14 request. Instantiated BEFORE titleMenu
// below, which takes it as a constructor param; Settings is now a real
// sub-menu (_OpenSettings()) rather than a stub. See SettingsOverlayScripts.gml.
settingsOverlay = new SettingsOverlay();
titleMenu = new TitleMenu(settingsOverlay);
