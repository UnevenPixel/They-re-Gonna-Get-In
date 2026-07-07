draw_set_alpha(1);
orderMenu.Draw();
selectionController.DrawTargetingCursor();
blueprintController.Draw();
DrawResourceBar(TEAM.PLAYER);
xpBarWidget.Draw(); // lower HUD -- 2026-07-06 request
plotHoverController.Draw(); // plot hover data -- drawn last so it renders on top of everything else, 2026-07-06 request
buildingHoverController.Draw(); // placed building hover data -- 2026-07-08 request, same "on top" ordering
blueprintController.DrawHoverCard(); // blueprint slot hover data -- 2026-07-08 request, drawn after the panel + other tooltips
unitSelectHoverController.Draw(); // top-left single-unit-selected info card -- 2026-07-11 request