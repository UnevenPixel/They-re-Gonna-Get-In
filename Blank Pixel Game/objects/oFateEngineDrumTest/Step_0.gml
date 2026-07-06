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
        // Rectangular hit test (not circular) -- see Draw_64 for why: a
        // circular radius wide enough to cover a drum's vertical footprint
        // also reached into neighboring drums horizontally, since they're
        // only 