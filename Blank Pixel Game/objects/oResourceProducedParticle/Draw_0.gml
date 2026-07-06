// Icon particles show the actual resource's sResourceIcons frame; square
// particles are a small flat-color square. Both fade out over their
// lifetime (life/lifeMax) rather than popping out abruptly.
var _alpha = clamp(life / lifeMax, 0, 1);

if (kind == "icon") {
    draw_sprite_ext(sResourceIcons, resourceIndex, x, y, 1, 1, 0, c_white, _alpha);
} else {
    draw_set_alpha(_alpha);
    draw_set_color(color);
    draw_rectangle(x - squareSize / 2, y - squareSize / 2, x + squareSize / 2, y + squareSize / 2, false);
    draw_set_alpha(1);
}
