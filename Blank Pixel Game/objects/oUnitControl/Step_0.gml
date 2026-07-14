// Fate Engine overlay -- 2026-07-13 request. Checked FIRST, before anything
// else this Step. While open, every other Step system below (selection,
// drag-select, menus, camera pan, every hover controller) is suppressed
// entirely -- the overlay's own Update() (button clicks + drum animation)
// is the ONLY input handled this frame. See FateEngineOverlayScripts.gml's
// header for the full open/close/freeze behavior and assumptions made.
if (fateEngineOverlay.isOpen) {
    fateEngineOverlay.Update();
    exit;
}

// Pause menu -- 2026-07-13 request. Checked SECOND, right after the Fate
// Engine overlay, for the same reason: while open, every other Step system
// below is suppressed entirely, and this early-exit sitting here (before
// the XP-bar click check just below) is what makes the two overlays
// mutually exclusive -- the XP bar can't open the Fate Engine overlay while
// paused, and (since the Fate Engine's own check above already exited if
// IT was open) Escape can't open the pause menu while the Fate Engine
// overlay is up either. See PauseMenuScripts.gml's header for full behavior.
if (pauseMenu.isOpen) {
    pauseMenu.Update();
    exit;
}

// Escape opens the pause menu -- checked before targeting/dragging/menu
// state below since Open() already cleanly resets all of that itself, same
// reasoning as the XP-bar-click Fate Engine check just below. 2026-07-13
// request.
if (keyboard_check_pressed(vk_escape)) {
    pauseMenu.Open(selectionController, orderMenu, castleGarrisonMenu, armyLimitMenu, blueprintController);
    exit;
}

// A press landing on the XP bar's own hit rect (XpBarWidgetHitRect(),
// XpBarScripts.gml) opens the Fate Engine overlay instead of anything
// else -- checked before targeting/dragging/menu state below since Open()
// already cleanly resets all of that itself (cancels targeting, cancels a
// blueprint drag, closes every dropdown) rather than needing to be gated
// behind it. 2026-07-13 request.
if (mouse_check_button_pressed(mb_left)) {
    var _xpBarRect = XpBarWidgetHitRect();
    var _guiX      = device_mouse_x_to_gui(0);
    var _guiY      = device_mouse_y_to_gui(0);
    if (_guiX >= _xpBarRect.x1 && _guiX <= _xpBarRect.x2 && _guiY >= _xpBarRect.y1 && _guiY <= _xpBarRect.y2) {
        fateEngineOverlay.Open(selectionController, orderMenu, castleGarrisonMenu, armyLimitMenu, blueprintController);
        exit; // opened -- don't let this same press cascade into selection/menu logic below
    }
}

// Prune units that died since being selected (combat's instance_destroy has
// no hook back into selection state) before anything else this frame reads
// selectionController.selected -- orderMenu's right-click-to-open path,
// IssueOrder, and unitSelectHoverController.Step below all depend on this
// running first. Fixes a crash flagged in NIGHTLY_REVIEW_2026-07-09.md
// (§3.1, critical) -- see PruneDeadSelected in UnitSelection.gml.
selectionController.PruneDeadSelected();

// orderMenu.Update() must run BEFORE this frame's open/select handling.
// OrderMenu.Update() treats a right-click as "dismiss" whenever isOpen
// is true. If we called Open() first and then Update() in the same
// Step, the same mouse_check_button_pressed(mb_right) that just opened
// the menu would still read true here and Update() would immediately
// close it again -- the menu would open and close within one frame and
// never actually be visible. Running Update() first means it only ever
// sees isOpen as it was at the START of the frame.
var _clickedOrder = orderMenu.Update();
if (_clickedOrder != undefined) {
    selectionController.IssueOrder(_clickedOrder);
    // IssueOrder handles entering targeting mode automatically
    // if the order has requiresTarget = true.
}

// castleGarrisonMenu.Update() must also run before this frame's open-click
// handling below, same same-frame open/close reasoning as orderMenu.Update()
// above -- see its comment. 2026-07-12: clicking a row now deploys one unit
// of that type (DeployStationedUnit, StationScripts.gml) -- undefined for
// a dismiss click or the "--" placeholder row, which DeployStationedUnit
// already treats as a safe no-op.
var _clickedGarrisonType = castleGarrisonMenu.Update();
if (_clickedGarrisonType != undefined) {
    DeployStationedUnit(TEAM.PLAYER, _clickedGarrisonType);
}

// armyLimitMenu.Update() must also run before this frame's open-click
// handling below, same same-frame open/close reasoning as the menus
// above. 2026-07-13: clicking a row selects every currently DEPLOYED
// (live, not stationed) unit of that type -- SelectAllOfType
// (UnitSelection.gml).
var _clickedArmyLimitType = armyLimitMenu.Update();
if (_clickedArmyLimitType != undefined) {
    selectionController.SelectAllOfType(_clickedArmyLimitType);

    // 2026-07-13 request: instantly open the order menu whenever the
    // selection changes -- centered on screen (OpenCentered, OrderMenu.gml)
    // since this selection came from a HUD dropdown row, not a playfield
    // click, so there's no cursor position to anchor away from. No-ops via
    // OpenCentered's own empty-orders guard if the selected type has no
    // common orders (shouldn't happen for a live deployed unit, but not
    // assumed).
    var _armyLimitOrders = selectionController.AvailableOrders();
    if (array_length(_armyLimitOrders) > 0) {
        orderMenu.OpenCentered(_armyLimitOrders);
    }
}

// selectionSummaryMenu.Step() must also run before this frame's open-click
// handling below (same reason as the two menus above), AND before
// unitSelectHoverController.Step() further down -- so if a row click here
// narrows the selection to exactly one unit, that single-unit card shows
// correctly this SAME frame with no one-frame lag. Own hover/click handling
// (top-left panel, 2+ units selected -- SelectionSummaryMenu.gml, 2026-07-12
// request); sets consumedClick when a row was clicked, checked below.
selectionSummaryMenu.Step(selectionController);

// 2026-07-13 request: instantly open the order menu when a
// SelectionSummaryMenu row click narrows the selection (consumedClick set
// inside Step() above only when a row was actually clicked) -- centered on
// screen (OpenCentered, OrderMenu.gml) since this is a click on the panel
// itself, not on a unit/drag-box in the playfield, so the same "otherwise
// center it" rule from the request applies here too.
if (selectionSummaryMenu.consumedClick) {
    var _summaryOrders = selectionController.AvailableOrders();
    if (array_length(_summaryOrders) > 0) {
        orderMenu.OpenCentered(_summaryOrders);
    }
}

// blueprintController.UpdatePaging() must also run before this frame's
// open-click handling below, same same-frame reasoning as the menus above
// -- handles a click on either page arrow AND scroll-wheel paging while
// hovering the panel/arrows (BlueprintScripts.gml, 2026-07-13 request).
// Returns true if an arrow click was consumed this frame, checked below
// same as the other menus' consumedClick flags so that SAME press doesn't
// also fall through to the blueprint-drag/selection-drag logic further down.
var _clickedBlueprintArrow = blueprintController.UpdatePaging();

// While in targeting mode, drag-box selection and normal left-click are
// suspended -- UpdateTargeting() consumes the click instead. A blueprint
// drag suspends the same things for the same reason, and takes priority
// over starting a new selection box (see the final else branch below).
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
    // castleGarrisonMenu/selectionSummaryMenu.consumedClick guard, 2026-07-12:
    // both menus can now handle a left click themselves (deploy / narrow-
    // select) -- without this, that SAME press would also fall through to
    // the castle/training/blueprint/drag logic below and immediately
    // clobber whatever the menu just did (e.g. a drag-select clearing the
    // selection a SelectionSummaryMenu row click just set). This was
    // already a latent gap for castleGarrisonMenu's click-to-deploy (added
    // last pass, never actually hit it since deploying doesn't touch
    // selection) -- fixed here for both since SelectionSummaryMenu's click-
    // to-select makes it immediately observable.
    if (mouse_check_button_pressed(mb_left) && !castleGarrisonMenu.consumedClick && !selectionSummaryMenu.consumedClick && !armyLimitMenu.consumedClick && !_clickedBlueprintArrow) {
        // A press that lands on the Army Limit Widget's icon (a fixed
        // GUI-space HUD icon, HUDWidgetScripts.gml -- NOT a room-space
        // instance like the castle wall/training buildings below) opens
        // the "Unit Limits" dropdown instead of anything else. Checked
        // FIRST: the icon sits well below SELECTION_DRAG_MIN_GUI_Y
        // (UnitSelection.gml), so it could never have started a drag-
        // select anyway, but a click there in GUI space could still
        // coincidentally land on a room-space instance depending on
        // camera position -- checking this first avoids that ambiguity
        // entirely. 2026-07-13 request.
        var _armyLimitRect        = ArmyLimitWidgetIconRect();
        var _guiX                 = device_mouse_x_to_gui(0);
        var _guiY                 = device_mouse_y_to_gui(0);
        var _clickedArmyLimitIcon = (_guiX >= _armyLimitRect.x1 && _guiX <= _armyLimitRect.x2 && _guiY >= _armyLimitRect.y1 && _guiY <= _armyLimitRect.y2);

        // A press that lands on the castle's own mask opens the garrison
        // dropdown instead of starting a selection box -- but only if it
        // ISN'T also on an inside plot. oPlotSpawner spawns inside-castle
        // plots literally within the castle's own footprint, so a plot
        // click would otherwise also register as a castle-mask hit; the
        // 2026-07-11 request is explicit that this must open for "the
        // castle wall itself, not the plots in the castle", so plots are
        // checked FIRST and take priority. Restricted to oPlayerCastle
        // (not oEnemyCastle) -- the garrison dropdown is player-castle-only,
        // same restriction as everything else in oUnitControl.
        var _clickedPlot       = instance_position(mouse_x, mouse_y, oBuildingPlot);
        var _clickedCastleWall = (_clickedPlot == noone) ? instance_position(mouse_x, mouse_y, oPlayerCastle) : noone;

        // A press that lands on a friendly training building queues one
        // unit instead of starting a selection box or a blueprint drag --
        // checked first since it's a room-space instance click (blueprint
        // slots are GUI-space, so there's no overlap either way, but
        // logically "click a building I own" should win over "start
        // dragging a selection box under it").
        var _trainingBuilding = instance_position(mouse_x, mouse_y, oTrainingBuildingParent);

        if (_clickedArmyLimitIcon) {
            armyLimitMenu.Open(BuildArmyLimitRows(TEAM.PLAYER));
        } else if (_clickedCastleWall != noone) {
            castleGarrisonMenu.Open(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), BuildCastleGarrisonRows(TEAM.PLAYER));
        } else if (_trainingBuilding != noone && _trainingBuilding.team == TEAM.PLAYER) {
            TrainingTryQueueUnit(_trainingBuilding);
        // A press that lands on a filled blueprint slot starts a
        // blueprint drag instead of a unit-selection box -- only one of
        // the two should ever start from the same press.
        } else if (!blueprintController.TryBeginDrag()) {
            selectionController.BeginDrag();
        }
    }
    if (mouse_check_button_released(mb_left)) {
        selectionController.EndDrag(keyboard_check(vk_shift));

        // 2026-07-13 request: instantly open the order menu the moment a
        // drag-box or single-unit click populates the selection -- EndDrag
        // covers both (the "_isClick" branch inside it, UnitSelection.gml).
        // Anchored at this same release point via the ordinary click-anchor
        // rule (Open(), OrderMenu.gml -- PositionDropDownMenuFromClick),
        // matching the request's "open it with the same anchoring rules it
        // normally uses" for this path. No-ops via Open()'s own empty-orders
        // guard if the release cleared the selection (empty-space click,
        // non-additive) or landed on units with no common order.
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

// Edge-of-screen camera panning -- independent of selection/order/targeting
// state above, so the player can still scroll the view while dragging a
// selection box, mid-order-menu, etc.
UpdateCameraPan();

// XP bar HUD -- milestone reveals + token tosses, independent of
// everything above. 2026-07-06 request.
xpBarWidget.Step();

// Un-occupied building plot hover data -- independent of everything above
// except that it reads selectionController/blueprintController's state to
// suppress itself while the player is targeting/dragging. 2026-07-06 request.
plotHoverController.Step(selectionController, blueprintController);

// Placed building hover data -- same suppression inputs as plot hover
// above, plus its own check against the Blueprint UI panel (see
// BuildingHoverScripts.gml). 2026-07-08 request.
buildingHoverController.Step(selectionController, blueprintController);

// Castle passive-bonus hover panel -- 2026-07-12 request. Same suppression
// inputs as building hover above, PLUS forced-off while castleGarrisonMenu
// is open (its own explicit "only visible if the garrison menu isn't
// open" requirement) -- see CastleBonusHoverScripts.gml.
castleBonusHoverController.Step(selectionController, blueprintController, castleGarrisonMenu.isOpen);

// Blueprint UI slot hover data (tooltip) -- 2026-07-08 request. Separate
// from blueprintController.Draw()'s panel rendering; suppressed internally
// while dragging (BlueprintScripts.gml's UpdateHover).
blueprintController.UpdateHover();

// Top-left single-unit-selected info card -- 2026-07-11 request. Instant
// show/hide tied to selectionController.selected, independent of mouse
// position/dwell -- see UnitSelectHoverController (UnitHoverScripts.gml).
// Mutually exclusive with selectionSummaryMenu above (that one only shows
// at 2+ selected, this one only at exactly 1) -- both occupy the same
// top-left corner.
unitSelectHoverController.Step(selectionController);

// Animated ruler portrait -- 2026-07-11 request. Independent of everything
// above; always animating regardless of selection/order/targeting state.
rulerPortraitController.Step();
