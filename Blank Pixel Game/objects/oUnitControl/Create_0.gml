// Instantiates every player-side HUD/input controller this object owns.
// See oUnitControl.md.
selectionController = new SelectionController(oUnitParent, TEAM.PLAYER);
orderMenu = new OrderMenu();
blueprintController = new BlueprintController(TEAM.PLAYER);
xpBarWidget = new XpBarWidget(TEAM.PLAYER); // lower HUD
plotHoverController = new PlotHoverController(); // un-occupied building plot hover data
buildingHoverController = new BuildingHoverController(); // placed building hover data
unitSelectHoverController = new UnitSelectHoverController(); // top-left single-unit-selected info card
rulerPortraitController = new RulerPortraitController(GetRulerPortraitDefinition(global.selectedRuler)); // animated ruler portrait on the UI bar
castleGarrisonMenu = new CastleGarrisonMenu(); // castle-wall-click garrison dropdown
selectionSummaryMenu = new SelectionSummaryMenu(); // top-left multi-unit-selected panel
castleBonusHoverController = new CastleBonusHoverController(); // castle hover panel listing active stationed passive bonuses
armyLimitMenu = new ArmyLimitMenu(); // "Unit Limits" dropdown, opened by clicking the Army Limit Widget icon
fateEngineOverlay = new FateEngineOverlay(); // Fate Engine session overlay, opened by clicking the XP bar
settingsOverlay = new SettingsOverlay(); // shared settings sub-menu -- instantiated BEFORE pauseMenu, which takes it as a constructor param
pauseMenu = new PauseMenu(settingsOverlay); // pause menu, opened via Escape; settings is a real sub-menu of this (OpenSettings())
