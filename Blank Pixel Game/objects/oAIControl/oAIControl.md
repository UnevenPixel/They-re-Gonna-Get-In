# oAIControl

Hosts one `AIBrain` (see `AIControl.gml`) -- hardcoded to `TEAM.ENEMY` for now. This object represents "the" AI opponent; if the game ever needs the AI to play `TEAM.PLAYER` (e.g. an automated player-side test), promote `team` to a creation-code-set variable the same way `oUnitControl`'s team assumption would need to change.

## Create_0 / Step_0

`brain = new AIBrain(TEAM.ENEMY)`. `Step_0` just calls `brain.Step()`.

## Draw_64

Debug readout, top-right anchored (moved from top-left 2026-07-12 -- that corner is now occupied by the drop-down menus and selection cards). Shows AI state, think timer, hesitancy (`AI_HESITANCY_DELAY_TICKS`, added 2026-08-06 alongside the think timer, matching this HUD's existing "surface every AI countdown" convention), `AI_DebugIntent` (next-action preview, 2026-07-13), and `AI_DebugQuotasText` (army/station/composition/siege numbers, 2026-07-13) -- both read-only debug helpers from `AIControl.gml`.
