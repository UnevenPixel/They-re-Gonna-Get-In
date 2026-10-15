// Initializes every per-match global (resources/blueprints/age/army limit/
// starting loadout/analytics). See oMatchControl.md.

global.matchSpeed = 1; // direct multiplier (2 = 2x speed), not a preset-table index. [0,1,2,3]
layer_set_visible("GamePlayUI",true);

// NOT array_create(2, {...}) -- see .md re: the shared-reference hazard.
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
        xp         : 0,
        fateTokens : 0
    };
}

// global.blueprints[team] is an array of BlueprintStack (BlueprintScripts.gml).
// [[], []] -- NOT array_create(2, []) -- same shared-reference hazard as
// global.resources above.
global.blueprints = [[], []];

global.age = [1, 1]; // current age per team, 1-4 (AGE_MAX, ProgressionScripts.gml)

global.ageUpReady = [false, false]; // per-team "age bar full, waiting on TryAgeUp" flag

// Per-team set of unit types ever deployed -- Strategic XP, see .md.
global.unitsDeployed = [[], []];

global.armyLimit = [6, 6]; // per-team cap on total live + queued units, any type/station status

// STARTING RESOURCES -- symmetric loadout for both teams. See .md.
for (var i = 0; i < 2; i++) {
    global.resources[i].wood  = 100;
    global.resources[i].water = 100;
    global.resources[i].iron  = 100;
    global.resources[i].gold  = 100;
    global.resources[i].wheat = 100;
}

// STARTING BLUEPRINTS -- fixed, deliberate loadout (2026-08-13), same for
// both sides. Every other blueprint is earned through the Fate Engine. See .md.
var _startingBlueprints = [
    oWheatField, oPeasantWard, oWaterPump, oSawmill
];
for (var i = 0; i < 2; i++) {
    for (var j = 0; j < array_length(_startingBlueprints); j++) {
        AddBlueprint(i, _startingBlueprints[j], 1);
    }
}

// Booger's guided-tutorial HUD presence (2026-08-13) -- only auto-starts
// the intro script for a genuinely first-time run (global.tutorialActive,
// set by the War Room flow). Always created regardless, same as every other
// global here, so BlueprintScripts.gml's TryPlaceBlueprint can always safely
// read global.tutorialGuide.restrictionActive. See TutorialGuideScripts.md.
global.tutorialGuide = new TutorialGuide();
if (global.tutorialActive) {
    global.tutorialGuide.StartIntroScript();
}

// The Dealer's tutorial-continuation ambush scene (2026-08-14 follow-up) --
// always created, same "always exists, only ever armed conditionally"
// pattern as global.tutorialGuide above. Armed via BeginWait() from
// TutorialGuideScripts.gml's own _TryAdvancePhase() once the guided
// tutorial's LAST phase completes -- see DealerIntroScripts.md.
global.dealerIntro = new DealerIntroScene();

AnalyticsInit();
