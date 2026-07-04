// Inherit oBuildingParent (team, radius), then set up production state
// (productionResource/productionRate/productionAccumulator) from this
// building's registered BuildingDefinition -- see BuildingApplyDefinition
// in BuildingDefinitions.gml. Every oResourceBuildingParent child gets
// this automatically; Step_0.gml ticks it via BuildingUpdateProduction.
event_inherited();
BuildingApplyDefinition(self);