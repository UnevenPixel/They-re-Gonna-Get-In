selectionController = new SelectionController(oUnitParent, TEAM.PLAYER);
orderMenu = new OrderMenu();
blueprintController = new BlueprintController(TEAM.PLAYER);
xpBarWidget = new XpBarWidget(TEAM.PLAYER); // lower HUD -- 2026-07-06 request
plotHoverController = new PlotHoverController(); // un-occupied building plot hover data -- 2026-07-06 request
buildingHoverController = new BuildingHoverController(); // placed building hover data -- 2026-07-08 request
unitSelectHoverController = new UnitSelectHoverController(); // top-left single-unit-selected info card -- 2026-07-11 request