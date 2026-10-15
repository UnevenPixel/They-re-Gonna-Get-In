// Player-side HUD draw. Order is deliberate -- later calls render on top.
// See oUnitControl.md.

global.tutorialGuide.Draw_Behind(); // absolutely FIRST -- Booger is "the lowest item in the UI", see TutorialGuideScripts.md

fateEngineOverlay.Draw(); // first, so its dim rect sits BEHIND the UI bar below
global.dealerIntro.Draw_Behind(); // 2026-08-14 -- AFTER fateEngineOverlay.Draw() so her portrait/leaning-sprite render on top of the (possibly already-revealed) Fate Engine background, see DealerIntroScripts.md

draw_sprite_ext(sRulerBar,0,0,1080,2,2,0,c_white,1);
draw_sprite_ext(sMainUIBarBottom,0,0,1080,2,2,0,c_white,1);
draw_sprite_ext(sUISpellsCloth,0,1348,1035,2,2,0,c_white,1);

rulerPortraitController.Draw(27, 1080, 2);
global.tutorialGuide.Draw_Front(); // hands, always above the bar -- see TutorialGuideScripts.md
global.dealerIntro.Draw_Front(); // 2026-08-14 -- her portrait's "last frame" drawn over the UI bar, see DealerIntroScripts.md

DrawTrainingQueueBars(); // room-space positions converted to GUI space, see .md

global.tutorialGuide.Draw_Bubble(); // 2026-08-14: speech bubble moved to its OWN, LATER call site (after the training queue bars) so it renders on top of them instead of underneath -- see TutorialGuideScripts.md
global.dealerIntro.Draw_Bubble(fateEngineOverlay); // 2026-08-14 -- needs fateEngineOverlay passed for the machine-stage bubble's positioning, see DealerIntroScripts.md

draw_set_alpha(1);
orderMenu.Draw();
blueprintController.Draw();
DrawResourceBar(TEAM.PLAYER);
DrawCastleHealthWidget(TEAM.PLAYER);
DrawArmyLimitWidget(TEAM.PLAYER);
DrawSpeedButtons();
xpBarWidget.Draw();
plotHoverController.Draw(); // hover/tooltip layer, deliberately last-ish -- see .md for the full stack order
buildingHoverController.Draw();
castleBonusHoverController.Draw();
blueprintController.DrawHoverCard();
unitSelectHoverController.Draw();
selectionSummaryMenu.Draw();
castleGarrisonMenu.Draw();
armyLimitMenu.Draw();

pauseMenu.Draw(); // absolutely LAST, on top of everything -- opposite draw-order choice from the overlay above, see .md
