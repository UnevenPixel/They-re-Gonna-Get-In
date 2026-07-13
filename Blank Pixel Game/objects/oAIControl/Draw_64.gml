// Moved to top-right, 2026-07-12 request -- the top-left corner is now
// occupied by the drop-down menus (Orders/Castle/Selected, DropDownMenuScripts.gml
// family) and the single-unit/multi-unit selection cards, which this debug
// text used to overlap.
draw_set_alpha(1);
draw_set_valign(fa_top);
draw_set_halign(fa_right);
draw_text(display_get_gui_width() - 8, 24, "AI State: " + string(brain.fsm.Current()) + "\nAI Think Timer: " + string(brain.thinkTimer));
