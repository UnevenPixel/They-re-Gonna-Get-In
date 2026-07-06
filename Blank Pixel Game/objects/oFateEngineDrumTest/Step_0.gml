for (var i = 0; i < array_length(drums); i++) {
    drums[i].Step();
}

// Manual test controls -- click a spinning drum to stop it (lands
// wherever it happens to land; there's no real reward-resolution yet to
// target a specific result). Click a stopped drum to spin it again.
if (mouse_check_button_pressed(mb_left)) {
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);

    for (var i = 0; i < array_length(drums); i++) {
        var _drum = drums[i];
        if (point_distance(_mx, _my, _drum.x, _drum.y) > _drum.radius + 48) continue; // +48: same visual-footprint tolerance as the Draw_64 hover check

        if (_drum.state == "spinning") {
            _drum.Stop();
        } else if (_drum.state == "stopped") {
            _drum.Spin();
        }
    }
}
