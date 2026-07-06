// Inherit oResourceBuildingParent -> oBuildingParent: team/radius, then
// BuildingApplyDefinition (production state) and the Step-event production
// tick (BuildingUpdateProduction) -- all from this building's registered
// BuildingDefinition. Nothing else to set here -- BuildingDefinition
// (BuildingDefinitions.gml) already supplies name/cost/sprite/production
// for the blueprint UI and the production system alike.
event_inherited();
