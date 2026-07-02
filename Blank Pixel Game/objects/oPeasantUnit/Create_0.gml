// Inherit the parent event -- this runs UnitApplyDefinition(self), which
// pulls availableOrders and sprites (sprIdle/sprWalk/sprAttack) from this
// unit's registered UnitDefinition (see RegisterAllUnitDefinitions in
// scripts/UnitDefinitions). Nothing left to set here -- if a peasant ever
// needs something no other unit has, add it below event_inherited().
event_inherited();