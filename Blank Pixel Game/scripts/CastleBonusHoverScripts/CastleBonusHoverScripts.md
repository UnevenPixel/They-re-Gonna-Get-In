# CastleBonusHoverScripts

A hover menu on the player's castle, shown only while the garrison menu isn't open, listing all currently applied stationed-passive bonuses. Owns a `HoverCard` (`HoverCardScripts.gml`) shown while the mouse dwells over the player's OWN castle (`oPlayerCastle` only -- same restriction `CastleGarrisonMenu` already applies: the garrison dropdown, and now this panel, are player-castle-only, not informational for the enemy castle).

Same dwell/fade/cursor-anchor pattern as `PlotHoverController`/`BuildingHoverController` -- deliberately reuses `PLOT_HOVER_DELAY_STEPS`/`PLOT_HOVER_FADE_STEPS`/`PLOT_HOVER_CURSOR_GAP` rather than inventing new timing macros for a third near-identical hover controller. `PLOT_HOVER_DELAY_STEPS` is settings-driven (Gameplay tab's "World Item Hover Delay") -- this controller picks that up automatically.

Suppressed whenever `CastleGarrisonMenu.isOpen` is true (passed in by the caller each Step) so the two panels never overlap on screen.

## API

- `CastleBonusHoverBodyText(_bonuses)` -- one "+X% Label" line per currently non-zero field on a `StationedBonuses` struct, joined with "\n". Falls back to "No active bonuses." if every field is 0 (nothing team-relevant stationed, or only Archers -- Archer's Stationed Effect contributes nothing here, see `stationedBonuses`' doc comment in `UnitDefinitions.gml`).
- `CastleBonusHoverController()` -- plain struct, owner calls `Step(_selectionController, _blueprintController, _garrisonMenuOpen)`/`Draw()`.
