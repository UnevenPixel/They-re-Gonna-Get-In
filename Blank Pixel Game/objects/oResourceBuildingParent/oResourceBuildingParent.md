# oResourceBuildingParent

Base object for every resource-producing building (`oWheatField`, `oWaterPump`, `oSawmill`, `oGoldMine`, `oIronMine`). Inherits `oBuildingParent` (team, radius).

## Create_0

`event_inherited()` then `BuildingApplyDefinition(self)` sets up production state (`productionResource`/`productionRate`/`productionAccumulator`) from this building's registered `BuildingDefinition` (`BuildingDefinitions.gml`). Every child gets this automatically.

## Step_0

`event_inherited()` then `BuildingUpdateProduction(self)` -- frame-rate-independent, match-speed-scaled, whole-integer-safe resource production. Buildings with no production registered (`productionRate 0`) simply no-op here every frame.
