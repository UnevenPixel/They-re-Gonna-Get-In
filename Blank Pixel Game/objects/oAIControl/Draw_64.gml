// Moved to top-right, 2026-07-12 request -- the top-left corner is now
// occupied by the drop-down menus (Orders/Castle/Selected, DropDownMenuScripts.gml
// family) and the single-unit/multi-unit selection cards, which this debug
// text used to overlap.
//
// 2026-07-13 addition ("add AI debug data... stating its quotas, and what
// it is intending to do next") -- appends AI_DebugIntent (next action
// preview) and AI_DebugQuotasText (army/station/composition/siege
// numbers) below the existing state/timer lines. Both are read-only debug
// helpers, AIControl.gml.
draw_set_alpha(1);
draw_set_valign(fa_top);
draw_set_halign(fa_right);
draw_text(display_get_gui_width() - 8, 24,
    "AI State: " + string(brain.fsm.Current()) + "\n" +
    "AI Think Timer: " + string(brain.thinkTimer) + "\n" +
    "Next: " + AI_DebugIntent(brain) + "\n" +
    AI_DebugQuotasText(brain.team)
);
