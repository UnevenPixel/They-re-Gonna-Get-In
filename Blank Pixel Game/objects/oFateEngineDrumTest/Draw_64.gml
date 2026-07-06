for (var i = 0; i < array_length(drums); i++) {
    drums[i].Draw();
}

// sFateEngineBody -- bottom-center origin (xorigin 120, yorigin 270),
// drawn AFTER the drums per 2026-07-05 request ("render the drums behind
// the body"). 2x scale puts its bottom edge flush with the GUI bottom
// edge with no extra offset math needed.
var _centerX = display_get_gui_width() / 2;
draw_sprite_ext(sFateEngineBody, 0, _centerX, display_get_gui_height(), 2, 2, 0, c_white, 1);

// Hover tooltip -- the "read the item it locked to" requirement. Only
// shows once a drum has actually landed (GetLockedItem returns undefined
// otherwise). Hit-test tolerance padded +48 beyond the orbit radius since
// items now render up to 96x96 (2x scale) and visually extend past it.
var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

for (var i = 0; i < array_length(drums); i++) {
    var _drum = drums[i];
    if (point_distance(_mx, _my, _drum.x, _drum.y) > _drum.radius + 48) continue;

    var _item = _drum.GetLockedItem();
    if (_item == undefined) continue;

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_text(_mx + 12, _my + 12, _item.label);
}
