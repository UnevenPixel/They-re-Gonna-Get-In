# oBuildingParent

Base object for every building type. Always 48x48 per CLAUDE.md convention.

## Create_0

`team = TEAM.PLAYER` (default), `radius = sprite_width / 2`.

`maxHealth`/`damageTaken` are set to safe placeholder defaults (0) here -- `BuildingApplyDefinition` (`BuildingDefinitions.gml`) overwrites both with the real registered values immediately after `event_inherited()` reaches here, same "Create sets placeholders, a script function fills in the real ones right after" pattern as `UnitApplyDefinition`/`oProjectileParent`. Purely so nothing crashes if some future building type's Create somehow runs without ever reaching `BuildingApplyDefinition`.

`inside = false` (safe default) -- only `TryPlaceBlueprint` actually sets this (copied from the target `oBuildingPlot`'s own `inside`, see `BlueprintScripts.gml`). Declared here so any building instance placed directly in the room editor (never touching `TryPlaceBlueprint`) still has a defined value for `TrainingSpawnUnit`'s inside-plot check instead of erroring on an undefined variable read.
