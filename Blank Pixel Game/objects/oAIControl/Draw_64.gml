// AI debug readout, top-right anchored. See oAIControl.md.
draw_set_alpha(1);
draw_set_valign(fa_top);
draw_set_halign(fa_right);
draw_text(display_get_gui_width() - 8, 24,
    "AI State: " + string(brain.fsm.Current()) + "\n" +
    "AI Think Timer: " + string(brain.thinkTimer) + "\n" +
    "AI Hesitancy: " + string(brain.hesitancy) + "\n" +
    "Next: " + AI_DebugIntent(brain) + "\n" +
    AI_DebugQuotasText(brain.team)
);
