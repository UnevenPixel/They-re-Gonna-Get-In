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
    if (mouse_check_button_pressed(mb_left)) {
        // A press that lands on a friendly training building queues one
        // unit instead of starting a selection box or a blueprint drag --
        // checked first since it's a room-space instance click (blueprint
        // slots are GUI-space, so there's no overlap either way, but
        // logically "click a building I own" should win over "start
        // dragging a selection box under it").
        var _trainingBuilding = instance_position(mouse_x, mouse_y, oTrainingBuildingParent);
        if (_trainingBuilding != noone && _trainingBuilding.team == TEAM.PLAYER) {
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
        orderMenu.Open(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), _orders);
    }
}

// Edge-of-screen camera panning -- independent of selection/order/targeting
// state above, so the player can still scroll the view while dragging a
// selection box, mid-order-menu, etc.
UpdateCameraPan();
