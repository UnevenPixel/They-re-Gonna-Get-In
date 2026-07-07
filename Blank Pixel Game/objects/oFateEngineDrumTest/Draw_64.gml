// Dark overlay behind the whole Fate Engine -- drawn first so the
// backing rects, drums, and body all render on top of it. 2026-07-06
// request.
draw_set_color(c_black);
draw_set_alpha(0.6);
draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
draw_set_alpha(1);

// Per-drum backing rectangle -- #E1D3EA, 50x69, centered on each drum,
// drawn behind that drum's icons (after the overlay, before
// drums[i].Draw()). 2026-07-06 request.
draw_set_color(make_color_rgb(0xE1, 0xD3, 0xEA));
for (var i = 0; i < array_length(drums); i++) {
    var _drum = drums[i];
    draw_rectangle(_drum.x - 50, _drum.y - 69, _drum.x + 50, _drum.y + 69, false);
}

for (var i = 0; i < array_length(drums); i++) {
    drums[i].Draw();
}

// sFateEngineBody -- bottom-center origin (xorigin 120, yorigin 270),
// drawn AFTER the drums per 2026-07-05 request ("render the drums behind
// the body"). 2x scale; bottom edge anchored to bodyBottomY (set in
// Create_0), which sits 268px above the GUI's bottom edge per the
// 2026-07-06 "clear the UI bottom bar" request.
var _centerX = display_get_gui_width() / 2;
draw_sprite_ext(sFateEngineBody, 0, _centerX, bodyBottomY, 2, 2, 0, c_white, 1);

// Hover tooltip -- the "read the item it locked to" requirement. Only
// shows once a drum has actually landed (GetLockedItem returns undefined
// otherwise).
//
// Rectangular hit test (not circular), per 2026-07-06 request: drums are
// only 104px apart center-to-center, so a circular radius generous enough
// to cover a drum's vertical footprint (items render up to 96x96 and can
// sit well above/below center via the depth-based offsetY) also reached
// into neighboring drums horizontally, highlighting more than one at once.
// Width and height are now tested independently -- half-width (44) is a
// placeholder chosen to leave a gap at the 52px half-spacing; tune freely.
var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);

for (var i = 0; i < array_length(drums); i++) {
    var _drum = drums[i];
    var _halfW = 44;
    var _halfH = _drum.radius + 48;
    if (abs(_mx - _drum.x) > _halfW || abs(_my - _drum.y) > _halfH) continue;

    var _item = _drum.GetLockedItem();
    if (_item == undefined) continue;

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_text(_mx + 12, _my + 12, _item.label);
}
