# PlotScripts

Small helper pair for `oBuildingPlot` creation and cleanup. `oBuildingPlot`'s `inside`/`far`/`blocked`/`occupied`/`team` fields are declared as Object Properties (IDE-level, with defaults) rather than set in its Create event -- an existing convention, not introduced here.

## SpawnBuildingPlot

Creates one `oBuildingPlot` on the "Plots" layer and sets its classification fields directly, instead of every spawner (`oPlotSpawner`, `oOuterPlotSpawner`) repeating `instance_create_layer` + five field assignments inline.

`_inside` marks a plot inside the castle walls -- resource buildings get a placement bonus OUTSIDE the castle, unit-training buildings get theirs INSIDE (see `oBuildingPlot`). `_far` marks an exposed "far" outer plot (more danger of being attacked, bigger stat bonus for anything placed there, see `ApplyPlotBonuses`/`GetPlacementCost`) -- meaningless when `_inside` is true, callers pass `false`.

## BuildingFreePlot

Called right before a building is destroyed (combat death in `ApplyDamage`, `UnitCombatHelpers.gml`, or resource depletion in `BuildingUpdateProduction`, `BuildingDefinitions.gml`) to free up the plot it was built on -- clears `occupied` so the plot is buildable again AND, per the 2026-07-06 click-through fix in `UnitSelection.gml`'s `UpdateTargeting`, clickable/targetable again.

Does NOT touch `blocked` -- that's a separate, meta-progression-owned flag (`oPlotSpawner/Create_0.gml`) unrelated to whether a building currently sits here. Conflating the two was a 2026-07-06 mistake, corrected the same day by introducing `occupied` as its own field.

No plot reference is stored on building instances -- `TryPlaceBlueprint` (`BlueprintScripts.gml`) always spawns a building at its plot's exact x/y and never destroys the plot, so this looks the plot up by position instead (`instance_position`). No-op if no plot exists at the building's position (e.g. a future placement path that doesn't use a plot at all).

## API

- `SpawnBuildingPlot(_x, _y, _inside, _far, _team)`.
- `BuildingFreePlot(_building)`.
