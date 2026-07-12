draw_sprite_ext(sRulerBar,0,0,1080,2,2,0,c_white,1);
draw_sprite_ext(sMainUIBarBottom,0,0,1080,2,2,0,c_white,1);
draw_sprite_ext(sUISpellsCloth,0,1348,1035,2,2,0,c_white,1);

// Animated ruler portrait -- 2026-07-11 request. Drawn on top of sRulerBar,
// bottom-left anchored (matches the portrait sprite's own origin) at
// (27, 1080) scale 2x, same scale convention as HOVER_CARD_SCALE.
rulerPortraitController.Draw(27, 1080, 2);

// Training building queue bars -- 2026-07-11 request. Room-space positions
// converted to GUI space (WorldToGui, CameraScripts.gml) so these render
// from THIS Draw GUI event and stay above every room-space Draw call
// (units, particles, other buildings) regardless of instance depth.
DrawTrainingQueueBars();

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
selectionSummaryMenu.Draw(); // top-left multi-unit-selected panel + paired hover card -- 2026-07-12 request, same "on top" ordering
castleGarrisonMenu.Draw(); // castle-wall-click garris