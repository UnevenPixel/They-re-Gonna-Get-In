// Player-side input dispatch. ORDER MATTERS throughout -- see oUnitControl.md
// for the full same-frame-open/close and click-consumption reasoning behind
// every ordering choice below before reordering anything.

// The Dealer's tutorial-continuation ambush scene (2026-08-14 follow-up) --
// checked FIRST, ahead of even the Fate Engine overlay gate below, since this
// scene owns/drives that overlay directly for a stretch of its own runtime
// (see DealerIntroScripts.gml's Update(), which calls fateEngineOverlay.Update()
// itself while suppressing). Ticks unconditionally (cheap no-op during its own
// "inactive"/"waiting"/"done" phases, so normal play is untouched by this call
// right up until she actually appears). See .md.
global.dealerIntro.Update(fateEngineOverlay, selectionController, orderMenu, castleGarrisonMenu, armyLimitMenu, blueprintController);
if (global.dealerIntro.IsSuppressingInput()) {
    // 2026-08-15 bugfix: hover controllers must still Step() during the Dealer scene, even though
    // everything else this frame is suppressed -- otherwise a hover card already on screen the moment
    // she popped up stays FROZEN (last Step()'d state, never re-evaluated) instead of easing away, and
    // can sit on top of her dialogue. TutorialCharacterSpeaking() (PlotHoverScripts.gml), now checked by
    // PlotHoverSuppressed()/BuildingHoverSuppressed(), is what actually fades these to invisible while
    // she's up -- this call just needs to keep happening so that fade can run. See .md.
    plotHoverController.Step(selectionController, blueprintController);
    buildingHoverController.Step(selectionController, blueprintController);
    castleBonusHoverController.Step(selectionController, blueprintController, castleGarrisonMenu.isOpen);
    unitSelectHoverController.Step(selectionController);
    exit;
}

// Overlay gate -- checked next (after the Dealer-scene gate above); while
// open, only its own Update() runs.
if (fateEngineOverlay.isOpen) {
    fateEngineOverlay.Update();
    // 2026-08-16 follow-up -- must keep ticking while the overlay is open so the token-drag
    // interaction (StepTokenDrag(), see XpBarScripts.gml) works "while the fate engine is open" as
    // requested; this gate would otherwise skip xpBarWidget.Step() entirely (see the other call
    // below, in "Independent systems"). Same "caller keeps ticking a system this gate would
    // otherwise skip" pattern global.dealerIntro.Update()'s own fateEngineOverlay.Update() call
    // above already uses, just in the other direction. See .md.
    xpBarWidget.Step(fateEngineOverlay);
    exit;
}

// Pause menu -- checked second, for the same full-suppression reason. This
// pair of early-exits is what makes the two overlays mutually exclusive.
if (pauseMenu.isOpen) {
    pauseMenu.Update();
    exit;
}

// Escape opens the pause menu -- Open() resets targeting/dragging/menu
// state itself, so no extra guard is needed here. Deliberately NOT
// suppressed by the guided-tutorial restriction below -- see .md.
if (keyboard_check_pressed(vk_escape)) {
    pauseMenu.Open(selectionController, orderMenu, castleGarrisonMenu, armyLimitMenu, blueprintController);
    exit;
}

// Guided tutorial -- ticks whenever Booger is present in any capacity
// (appearing/idle/disappearing), independent of whether input is currently
// restricted (she still needs to finish animating down after the
// restriction below has already cleared). See TutorialGuideScripts.md.
if (global.tutorialGuide.state != "hidden") {
    global.tutorialGuide.Update();
}

// While a restriction is active, the ONLY input this Step handles is a
// blueprint drag/placement and a training-building click -- actual
// enforcement (allowed building type/side, and now unit-training counts --
// see TutorialGuideScripts.md's "Player action restriction") lives in
// TryPlaceBlueprint/TrainingTryQueueUnit themselves, so a disallowed attempt
// just silently fails the same way an unaffordable one already does.
// Everything else (selection, orders, castle garrison, army limit, Fate
// Engine) is suppressed for the duration.
//
// 2026-08-13: training-building clicks added here (mirrors the unrestricted
// block's own plot-then-training-then-drag ordering below, trimmed to just
// training+drag since plots/walls/army-limit aren't part of any restricted
// phase). Needed starting with the guided tutorial's Peasant Ward phase,
// whose completion depends on actually queuing units AFTER placing the
// Ward -- every earlier phase only ever needed the placement itself, so this
// gate never had to let a click reach TrainingTryQueueUnit before. See .md.
if (global.tutorialGuide.restrictionActive) {
    blueprintController.UpdatePaging();
    blueprintController.UpdateHover();
blueprintController.UpdateCarry(); // carry animation + placement dust

    if (blueprintController.dragging) {
        if (mouse_check_button_released(mb_left)) blueprintController.EndDrag();
        if (mouse_check_button_pressed(mb_right)) blueprintController.CancelDrag();
    } else if (mouse_check_button_pressed(mb_left)) {
        var _tutorialTrainingBuilding = instance_position(mouse_x, mouse_y, oTrainingBuildingParent);
        if (_tutorialTrainingBuilding != noone && _tutorialTrainingBuilding.team == TEAM.PLAYER) {
            TrainingTryQueueUnit(_tutorialTrainingBuilding);
        } else {
            blueprintController.TryBeginDrag();
        }
    }

    // 2026-08-14 request: "don't block hover displays during the tutorial if Booger isn't speaking."
    // These are the same hover .Step() calls the unrestricted "Independent systems" block runs further
    // down -- that block never runs once this gate's exit fires below, so hover data never got refreshed
    // (and the hover cards effectively went stale/blank) for the ENTIRE duration of a restriction before
    // this fix, not just while she was actually talking.
    // 2026-08-15 bugfix: now called UNCONDITIONALLY (was gated behind global.tutorialGuide.state != "idle")
    // -- that old guard meant a hover card already on screen the moment she went idle/talking was simply
    // never Step()'d again, so it stayed FROZEN in its last state (fully visible) instead of easing away,
    // and could sit on top of her speech bubble. TutorialCharacterSpeaking() (PlotHoverScripts.gml), now
    // checked by PlotHoverSuppressed()/BuildingHoverSuppressed(), is what actually fades these cards out
    // while she's idle -- Step() just needs to keep running so that fade can happen. See .md.
    plotHoverController.Step(selectionController, blueprintController);
    buildingHoverController.Step(selectionController, blueprintController);
    castleBonusHoverController.Step(selectionController, blueprintController, castleGarrisonMenu.isOpen);
    unitSelectHoverController.Step(selectionController);

    exit;
}

// XP bar click opens the Fate Engine overlay -- checked before
// targeting/dragging/menu state since Open() resets all of that itself.
// 2026-08-13: gated behind !global.tutorialGuide.fateEngineLocked -- the
// guided tutorial locks the Fate Engine for its entire duration (not just
// while restrictionActive), so the click is still consumed (exit either
// way) but silently does nothing while locked, same "consume the click,
// no-op if blocked" convention the restriction gate above already uses.
if (mouse_check_button_pressed(mb_left)) {
    var _xpBarRect = XpBarWidgetHitRect();
    var _guiX      = device_mouse_x_to_gui(0);
    var _guiY      = device_mouse_y_to_gui(0);
    if (_guiX >= _xpBarRect.x1 && _guiX <= _xpBarRect.x2 && _guiY >= _xpBarRect.y1 && _guiY <= _xpBarRect.y2) {
        if (!global.tutorialGuide.fateEngineLocked) {
            fateEngineOverlay.Open(selectionController, orderMenu, castleGarrisonMenu, armyLimitMenu, blueprintController);
        }
        exit; // opened (or blocked) -- don't let this same press cascade into selection/menu logic below
    }
}

// Speed buttons (pause / 1x / 2x / 3x) -- fixed HUD buttons, sets global.matchSpeed directly. Only reachable here, i.e. not
// while the Fate Engine, pause menu, Dealer scene, or a tutorial restriction owns input. Click is consumed either way.
if (mouse_check_button_pressed(mb_left)) {
    var _speedButton = SpeedButtonAtMouse();
    if (_speedButton != -1) {
        global.matchSpeed = _speedButton;
        exit;
    }
}

// Prune units that died since being selected -- combat's instance_destroy
// has no hook back into selection state. Must run before anything below
// reads selectionController.selected (fixes NIGHTLY_REVIEW_2026-07-09.md §3.1).
selectionController.PruneDeadSelected();

// Every menu .Update() below MUST run before this frame's open-click
// handling further down -- see .md for the same-frame open/close bug this
// avoids.
var _clickedOrder = orderMenu.Update();
if (_clickedOrder != undefined) {
    selectionController.IssueOrder(_clickedOrder);
    // IssueOrder handles entering targeting mode automatically
    // if the order has requiresTarget = true.
}

var _clickedGarrisonType = castleGarrisonMenu.Update();
if (_clickedGarrisonType != undefined) {
    DeployStationedUnit(TEAM.PLAYER, _clickedGarrisonType);
}

var _clickedArmyLimitType = armyLimitMenu.Update();
if (_clickedArmyLimitType != undefined) {
    selectionController.SelectAllOfType(_clickedArmyLimitType);

    // Instantly open the order menu centered on screen -- this selection
    // came from a HUD dropdown row, not a playfield click, so there's no
    // cursor position to anchor away from.
    var _armyLimitOrders = selectionController.AvailableOrders();
    if (array_length(_armyLimitOrders) > 0) {
        orderMenu.OpenCentered(_armyLimitOrders);
    }
}

// Must also run before this frame's open-click handling, AND before
// unitSelectHoverController.Step() below, so a narrowed selection shows
// correctly this same frame with no one-frame lag.
selectionSummaryMenu.Step(selectionController);

if (selectionSummaryMenu.consumedClick) {
    var _summaryOrders = selectionController.AvailableOrders();
    if (array_length(_summaryOrders) > 0) {
        orderMenu.OpenCentered(_summaryOrders);
    }
}

var _clickedBlueprintArrow = blueprintController.UpdatePaging();

// While targeting, drag-select and normal left-click are suspended --
// UpdateTargeting() consumes the click instead. A blueprint drag takes
// priority over starting a new selection box for the same reason.
if (selectionController.isTargeting) {
    selectionController.UpdateTargeting();
} else if (blueprintController.dragging) {
    if (mouse_check_button_released(mb_left)) {
        blueprintController.EndDrag();
    }
    if (mouse_check_button_pressed(mb_right)) {
        blueprintController.CancelDrag();
    }
} else {
    // consumedClick guard: without this, the same press a menu above just
    // consumed for deploy/select would ALSO fall through and clobber what
    // the menu just did -- see .md.
    if (mouse_check_button_pressed(mb_left) && !castleGarrisonMenu.consumedClick && !selectionSummaryMenu.consumedClick && !armyLimitMenu.consumedClick && !_clickedBlueprintArrow) {
        // Army Limit Widget icon -- fixed GUI-space HUD icon, checked first
        // to avoid ambiguity with a room-space instance under the same
        // screen point (see .md).
        var _armyLimitRect        = ArmyLimitWidgetIconRect();
        var _guiX                 = device_mouse_x_to_gui(0);
        var _guiY                 = device_mouse_y_to_gui(0);
        var _clickedArmyLimitIcon = (_guiX >= _armyLimitRect.x1 && _guiX <= _armyLimitRect.x2 && _guiY >= _armyLimitRect.y1 && _guiY <= _armyLimitRect.y2);

        // Plots are checked FIRST since oPlotSpawner spawns inside-castle
        // plots within the castle's own footprint -- the garrison dropdown
        // is for the wall itself, not the plots inside it. Player castle only.
        var _clickedPlot       = instance_position(mouse_x, mouse_y, oBuildingPlot);
        var _clickedCastleWall = (_clickedPlot == noone) ? instance_position(mouse_x, mouse_y, oPlayerCastle) : noone;

        var _trainingBuilding = instance_position(mouse_x, mouse_y, oTrainingBuildingParent);

        if (_clickedArmyLimitIcon) {
            armyLimitMenu.Open(BuildArmyLimitRows(TEAM.PLAYER));
        } else if (_clickedCastleWall != noone) {
            castleGarrisonMenu.Open(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), BuildCastleGarrisonRows(TEAM.PLAYER));
        } else if (_trainingBuilding != noone && _trainingBuilding.team == TEAM.PLAYER) {
            TrainingTryQueueUnit(_trainingBuilding);
        } else if (!blueprintController.TryBeginDrag()) {
            selectionController.BeginDrag();
        }
    }
    if (mouse_check_button_released(mb_left)) {
        selectionController.EndDrag(keyboard_check(vk_shift));

        // Instantly open the order menu the moment a drag-box or
        // single-unit click populates the selection, anchored at this
        // release point.
        var _dragOrders = selectionController.AvailableOrders();
        if (array_length(_dragOrders) > 0) {
            orderMenu.Open(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), _dragOrders);
        }
    }

    if (mouse_check_button_pressed(mb_right) && array_length(selectionController.selected) > 0 && !orderMenu.isOpen) {
        var _orders = selectionController.AvailableOrders();
        orderMenu.Open(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), _orders);
    }
}

// Independent systems -- run every Step regardless of the above.
UpdateCameraPan();
xpBarWidget.Step(fateEngineOverlay); // 2026-08-16 follow-up -- now takes the overlay reference, see the other call above and StepTokenDrag()/.md
plotHoverController.Step(selectionController, blueprintController);
buildingHoverController.Step(selectionController, blueprintController);
castleBonusHoverController.Step(selectionController, blueprintController, castleGarrisonMenu.isOpen);
blueprintController.UpdateHover();
blueprintController.UpdateCarry(); // carry animation + placement dust
unitSelectHoverController.Step(selectionController);
rulerPortraitController.Step();
