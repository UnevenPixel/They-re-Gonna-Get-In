// Global (not instance-scoped) since other systems need to scale by this
// too -- currently resource production (BuildingUpdateProduction in
// BuildingDefinitions.gml). Direct multiplier, e.g. 2 = 2x speed -- not an
// index into a preset table.
global.matchSpeed = 1; //[0,1,2,3]
layer_set_visible("GamePlayUI",true);

// NOT array_create(2, {...}) -- that evaluates the struct literal once and
// stores the SAME reference in both slots, so TEAM.PLAYER and TEAM.ENEMY
// would silently share one resource pool. The loop evaluates a fresh
// struct literal per iteration instead, so each team gets its own.
global.resources = array_create(2, undefined);
for (var i = 0; i < 2; i++) {
    global.resources[i] = {
        wood    : 0,
        wheat   : 0,
        water   : 0,
        iron    : 0,
        gold    : 0,
        meat    : 0,
        bones   : 0,
        coal    : 0,
        weapons : 0,
        coins   : 0
    };
}

// global.blueprints[team] is an array of BlueprintStack (BlueprintScripts.gml).
// [[], []] -- NOT array_create(2, []) -- same shared-reference hazard as
// global.resources above; each [] here is its own literal, evaluated
// fresh, so it's safe.
global.blueprints = [[], []];

// Per-team cap on total live + queued units, regardless of type or
// station status -- see TrainingTryQueueUnit (TrainingScripts.gml). A
// plain 2-slot array (not array_create(2, ...)) since both start at the
// same flat number, not a shared reference -- no aliasing hazard here.
global.armyLimit = [6, 6];

// STARTING RESOURCES -- confirmed loadout (per econ clarification,
// 2026-07-03): every SIDE starts each match with