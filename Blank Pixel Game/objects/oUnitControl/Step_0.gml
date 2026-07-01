// While in targeting mode, drag-box selection and normal left-click
// are suspended -- UpdateTargeting() consumes the click instead.
if (selectionController.isTargeting) {
    selectionController.UpdateTargeting();
} else {
    if (mouse_check_button_pressed(mb_left)) {
        selectionController.BeginDrag();
    }
    if (mouse_check_button_released(mb_left)) {
        selectionController.EndDrag(keyboard_check(vk_shift));
    }

    if (mouse_check_button_pressed(mb_right) && array_length(selectionController.selected) > 0 && !orderMenu.isOpen) {
        var _orders = selectionController.AvailableOrders();
        orderMenu.Open(device_mouse_x_to_gui(0), device_mouse_y_to_gui(0), _orders);
    }
}

var _clickedOrder = orderMenu.Update();
if (_clickedOrder != undefined) {
    selectionController.IssueOrder(_clickedOrder);
    // IssueOrder handles entering targeting mode automatically
    // if the order has requiresTarget = true.
}
