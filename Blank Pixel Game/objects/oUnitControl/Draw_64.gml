draw_set_alpha(1);
orderMenu.Draw();
selectionController.DrawTargetingCursor();
blueprintController.Draw();
DrawResourceBar(TEAM.PLAYER);
xpBarWidget.Draw(); // lower HUD -- 2026-07-06 request
plotHoverController.Draw(); // plot hover data -- drawn last so it renders on top of everything else, 