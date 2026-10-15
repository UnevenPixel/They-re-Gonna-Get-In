# oTrainingBuildingParent

Base object for every unit-training building (`oPeasantWard`, `oBarracks`, `oArcheryRange`, `oRoundTable`, `oBoomHut`, `oBogFoundry`). Inherits `oBuildingParent` (team, radius).

## Create_0

`event_inherited()` then `BuildingApplyDefinition(self)` sets up training state from this building's registered `BuildingDefinition`.

## Step_0

`event_inherited()` then `TrainingUpdateQueue(self)` -- time-based, match-speed-scaled training progress (`TrainingScripts.gml`). Buildings with an empty queue simply no-op here every frame.
