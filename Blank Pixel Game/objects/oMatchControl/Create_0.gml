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
        wood       : 0,
        wheat      : 0,
        water      : 0,
        iron       : 0,
        gold       : 0,
        meat       : 0,
        bones      : 0,
        coal       : 0,
        weapons    : 0,
        coins      : 0,
        // xp/fateTokens (added 2026-07-04, see ProgressionScripts.gml): kept
        // in the same per-team struct as the spendable resources above so
        // Cost/CanAfford/Purchase (Economy.gml) keep working generically --
        // but xp isn't spent the way the others are; GainXP consumes it
        // automatically as it fills each age's bar.
        xp         : 0,
        fateTokens : 0
    };
}

// global.blueprints[team] is an array of BlueprintStack (BlueprintScripts.gml).
// [[], []] -- NOT array_create(2, []) -- same shared-reference hazard as
// global.resources above; each [] here is its own literal, evaluated
// fresh, so it's safe.
global.blueprints = [[], []];

// Current age per team (1-4, see AGE_MAX in ProgressionScripts.gml). Ages
// and blueprint-tier-acquisition odds aren't designed yet (2026-07-04) --
// this only tracks the number; nothing reads it to affect blueprint odds
// yet. Plain 2-slot array, not array_create(2, ...) -- both start at the
// same flat number, no shared-reference hazard (see global.armyLimit below).
global.age = [1, 1];

// Per-team "age bar is full, waiting on a manual Age Up" flag -- see
// TryAgeUp (ProgressionScripts.gml). 2026-07-06 doc change: age no longer
// advances the instant XP fills: GainXP raises this, TryAgeUp (not yet
// wired to any UI) is what actually spends the resources and advances.
global.ageUpReady = [false, false];

// Per-team set of unit types (object_index) ever deployed (TrainingSpawnUnit,
// TrainingScripts.gml) -- "First deployment of unit type" Strategic XP,
// 2026-07-06 doc. [[], []] -- NOT array_create(2, []), same shared-reference
// hazard as global.blueprints above.
global.unitsDeployed = [[], []];

// Per-team cap on total live + queued units, regardless of type or
// station status -- see TrainingTryQueueUnit (TrainingScripts.gml). A
// plain 2-slot array (not array_create(2, ...)) since both start at the
// same flat number, not a shared reference -- no aliasing hazard here.
global.armyLimit = [6, 6];

// STARTING RESOURCES -- confirmed loadout (per econ clarification,
// 2026-07-03): every SIDE starts each match with 50 wood, 50 water, 50
// iron, 50 gold, 50 wheat -- applied symmetrically to both teams, since
// the AI opponent now needs the same economy as the player to actually
// build/train (see AI_TryPlaceBlueprints/AI_TryTrainComposition,
// AIControl.gml). Everything else (meat/bones/coal/weapons/coins) stays
// at 0 -- coins isn't part of the starting loadout. Wheat Field's cost was
// corrected 2026-07-05 to 20 water + 10 wood (see BuildingDefinitions.gml),
// so it's now fully affordable from this starting loadout same as every
// other tier-1 building here.
for (var i = 0; i < 2; i++) {
    global.resources[i].wood  = 50;
    global.resources[i].water = 50;
    global.resources[i].iron  = 50;
    global.resources[i].gold  = 50;
    global.resources[i].wheat = 50;
}

// TEST DATA: one of every registered building blueprint per side, for
// playtesting -- 2026-07-05 request. The final build only starts the
// player with one of each of the 4 tier-1 RESOURCE blueprints specifically
// (Water Pump/Sawmill/Gold Mine/Iron 