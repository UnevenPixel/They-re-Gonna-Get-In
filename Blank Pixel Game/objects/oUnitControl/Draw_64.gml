// Fate Engine overlay -- 2026-07-13 request. Drawn FIRST, before every
// persistent UI bar sprite below, so its 0.75-alpha dim rectangle sits
// BEHIND the UI bar rather than covering it -- the bar and everything
// drawn after it in this event stay fully visible/on top while the
// overlay is open. No-ops (draws nothing) while closed.
fateEngineOverlay.Draw();

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
DrawCastleHealthWidget(TEAM.PLAYER); // castle health readout -- 2026-07-13 request, first of the new HUD widgets (HUDWidgetScripts.gml)
DrawArmyLimitWidget(TEAM.PLAYER); // army usage readout -- 2026-07-13 request, second HUD widget (HUDWidgetScripts.gml); its click-to-open "Unit Limits" dropdown (ArmyLimitMenu.gml) is drawn separately below, last, same "on top" ordering as the other dropdowns
xpBarWidget.Draw(); // lower HUD -- 2026-07-06 request
plotHoverController.Draw(); // plot hover data -- drawn last so it renders on top of everything else, 2026-07-06 request
buildingHoverController.Draw(); // placed building hover data -- 2026-07-08 request, same "on top" ordering
castleBonusHoverController.Draw(); // castle passive-bonus hover panel -- 2026-07-12 request, same "on top" ordering
blueprintController.DrawHoverCard(); // blueprint slot hover data -- 2026-07-08 request, drawn after the panel + other tooltips
unitSelectHoverController.Draw(); // top-left single-unit-selected info card -- 2026-07-11 request
selectionSummaryMenu.Draw(); // top-left multi-unit-selected panel + paired hover card -- 2026-07-12 request, same "on top" ordering
castleGarrisonMenu.Draw(); // castle-wall-click garrison dropdown -- 2026-07-11 request, drawn last so it renders on top of everything else, same "on top" ordering as the hover cards above
armyLimitMenu.Draw(); // "Unit Limits" dropdown, opened from the Army Limit Widget icon -- 2026-07-13 request, drawn last for the same "on top of everything else" reason as castleGarrisonMenu above

// Pause menu -- 2026-07-13 request. Drawn absolutely LAST, on top of the
// persistent UI bar and every other HUD element -- deliberately the
// OPPOSITE draw-order choice from the Fate Engine overlay (which draws its
// dim FIRST so the bar stays visible on top of it). Pausing is meant to
// cover everything, not just the room-space battlefield -- see
// PauseMenuScripts.gml's header for the full reasoning. No-ops (draws
// nothing) while closed.
pauseMenu.Draw();