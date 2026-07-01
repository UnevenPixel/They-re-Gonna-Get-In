draw_set_alpha(1);
draw_set_valign(fa_top);
draw_set_halign(fa_left);
draw_text(8, 24, "AI State: " + string(brain.fsm.Current()) + "\nAI Think Timer: " + string(brain.thinkTimer));
