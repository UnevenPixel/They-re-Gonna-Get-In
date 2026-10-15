# oPlotSpawner

Spawns the inside-castle building plot grid (5x5), mirrored for both sides (enemy positions = `room_width - player positions`, same axis `oCastleManager`/`oOuterPlotSpawner` mirror off), then self-destroys. The center 3x3 of the 5x5 grid is marked `blocked` (meta-progression-locked, not currently buildable); the outer ring is open.

Uses `SpawnBuildingPlot` (`scripts/PlotScripts`) so both sides get their plots and both are correctly team-tagged -- an earlier version only ever spawned the player's grid and never set `.team` on any of it.
