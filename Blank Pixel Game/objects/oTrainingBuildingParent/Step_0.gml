// Time-based, match-speed-scaled training progress -- see
// TrainingUpdateQueue in TrainingScripts.gml. Every oTrainingBuildingParent
// child (oPeasantWard, etc.) gets this for free; buildings with an empty
// queue simply no-op here every frame.
event_inherited();
TrainingUpdateQueue(self);
