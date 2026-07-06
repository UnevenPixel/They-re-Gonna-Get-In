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
    draw_rectangle(_drum.x - 50, _drum.y - 69, _drum.x + 50, _drum