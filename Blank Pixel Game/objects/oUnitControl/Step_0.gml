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

// selectionSummaryMenu.Step() must also run before this frame's open-click
// handling below (same reason as the two menus above), AND before
// unitSelectHoverController.Step() further down -- so if a row click here
// narrows the selection to exactly one unit, that single-unit card shows
// correctly this SAME frame with no one-frame lag. Own hover/click handling
// (top-left panel, 2+ units selected -- SelectionSummaryMenu.gml, 2026-07-12
// request); sets consumedClick when a row was clicked, checked below.
selectionSummaryMenu.Step(selectionController);

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
    if (mouse_check_button_pressed(mb_left) && !castleGarrisonMenu.consumedClick && !selectionSummaryMenu.consumedClick) {
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

        if (_clickedCastleWall != noone) {
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
    }

    if (mouse_check_button_pressed(mb_right) && array_length(selectionController.selected) > 0 && !orderMenu.isOpen) {
        var _orders = selectionController.AvailableOrders();
        orderMenu.Open(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), _orde