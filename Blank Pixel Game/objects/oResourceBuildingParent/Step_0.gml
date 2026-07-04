// Frame-rate-independent, match-speed-scaled, whole-integer-safe resource
// production -- see BuildingUpdateProduction in BuildingDefinitions.gml.
// Every oResourceBuildingParent child (oWheatField, etc.) gets this for
// free; buildings with no production registered (productionRate 0) simply
// no-op here every frame.
BuildingUpdateProduction(self);
