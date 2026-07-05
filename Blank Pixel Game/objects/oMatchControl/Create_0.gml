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

// Per-team cap on total live + queued units, regardless of type or
// station status -- see TrainingTryQueueUnit (TrainingScripts.gml). A
// plain 2-slot array (not array_create(2, ...)) since both start at the
// same flat number, not a shared reference -- no aliasing hazard here.
global.armyLimit = [6, 6];

// STARTING RESOURCES -- confirmed loadout (per econ clarification,
// 2026-07-03): every SIDE starts each match with 50 wood, 50 water, 50
// iron, 50 gold, 50 wheat -- applied symmetrically to both teams, since
// the AI opponent now needs the same economy as the player to actually
// build/train (see AI_TryPlaceBlueprints/AI_TryTrainAtAllBuildings,
// AIControl.gml). Everything else (meat/bones/coal/weapons/coins)
// intentionally stays at 0 -- coins isn't part of the starting loadout, so
// note that the Wheat Field blueprint below (15 wood + 10 coins) can't
// actually be placed by either side until coins comes from somewhere (a
// real acquisition/trading system isn't built yet); the Peasant Ward
// blueprint (40 wheat + 40 water) is unaffected and fully testable.
for (var i = 0; i < 2; i++) {
    global.resources[i].wood  = 50;
    global.resources[i].water = 50;
    global.resources[i].iron  = 50;
    global.resources[i].gold  = 50;
    global.resources[i].wheat = 50;
}

// TEST DATA: a few Wheat Field / Peasant Ward blueprints per side so the
// drag-to-place (player) and AI-placement (AI_TryPlaceBlueprints) flows
// are both testable end-to-end before a real blueprint-acquisition
// system exists. Remove/replace once that system is designed.
AddBlueprint(TEAM.PLAYER, oWheatField, 3);
AddBlueprint(TEAM.PLAYER, oPeasantWard, 1);
AddBlueprint(TEAM.ENEMY, oWheatField, 3);
AddBlueprint(TEAM.ENEMY, oPeasantWard, 1);

// Resets this match's local playtest-analytics counters -- see
// AnalyticsScripts.gml.
AnalyticsInit();