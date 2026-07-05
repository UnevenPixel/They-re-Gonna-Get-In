team = TEAM.PLAYER;
radius = sprite_width / 2;

// Safe defaults only -- BuildingApplyDefinition (BuildingDefinitions.gml)
// overwrites both with the real registered values immediately after
// event_inherited() reaches here, same "Create sets placeholders, a script
// function fills in the real ones right after" pattern as
// UnitApplyDefinition/oProjectileParent. maxHealth/damageTaken here purely
// so nothing crashes if some future building type's Create somehow runs
// without ever reaching BuildingApplyDefinition.
maxHealth   = 0;
damageTaken = 0;