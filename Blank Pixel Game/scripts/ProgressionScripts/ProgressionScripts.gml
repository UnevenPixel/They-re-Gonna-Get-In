// -----------------------------------------------------------
// ProgressionScripts -- XP / Age / Fate Token tracking.
//
// Reworked 2026-07-06 against the "XP Age Progression System" design doc
// (uploaded that day). Two behavior changes from the original version:
//
// 1. XP-to-fill-the-bar is no longer a flat 1000 for every age -- the doc
//    specifies escalating requirements per transition (Age I->II 100 XP,
//    II->III 150, III->IV 200). See global.ageXpRequired/AgeXpRequired.
//
// 2. Age no longer advances automatically the instant the bar fills. Per
//    the doc's "6. Age Advances" section: filling the bar just makes
//    Age Up available (global.ageUpReady) -- the player still has to pay a
//    resource cost (global.ageUpCost/AgeUpCost, gold-only per the doc's own
//    "work in progress, use gold as a starting point" note) via TryAgeUp
//    before the age actually advances and XP resets. There's no "Age Up"
//    HUD button wired to TryAgeUp yet -- that's a separate UI task.
//
// XP still fills a per-team "age bar"; every time the bar crosses one of
// its 5 equal 20%-marks (20/40/60/80/100%, 2026-07-06 rewarding-frequency
// change -- was 4 quarter-marks), the team gets one Fate Token. This part
// is untouched by the doc (which doesn't mention Fate Tokens at all) --
// confirmed 2026-07-06 that it's meant to keep layering on top of
// whatever XP system exists underneath.
//
// Ages/blueprint-tier-acquisition odds are still NOT designed yet (per
// 2026-07-04 discussion) -- this file only tracks the numbers. Nothing
// reads global.age to affect blueprint odds yet; that's future work.
// -----------------------------------------------------------

#macro AGE_MAX                  4     // total ages -- placeholder, effects of higher ages not designed yet
#macro AGE_FATE_TOKEN_INTERVALS  5     // equal slices of the bar, each worth one Fate Token -- 20% each, per 2026-07-06 change (was 4 / 25% each)

// XP required to fill each age's bar -- index 0 = Age I->II, 1 = Age
// II->III, 2 = Age III->IV (AGE_MAX - 1 entries; there's no bar to fill
// once already at AGE_MAX). Straight from the 2026-07-06 doc -- was a flat
// 1000 for every age before this.
global.ageXpRequired = [100, 150, 200];

// Resource cost to actually execute an Age Up once its bar is full -- same
// indexing as global.ageXpRequired. The doc flags these as WIP ("both are
// a work in progress but use gold as a starting point") -- gold-only for
// now, no other resource, so treat these numbers as placeholders same as
// everything else marked WIP in this project.
global.ageUpCost = [
    new Cost([new ResourceCost("gold", 150)]),
    new Cost([new ResourceCost("gold", 250)]),
    new Cost([new ResourceCost("gold", 400)]),
];

/// @function AgeXpRequired(_age)
/// @description XP needed to fill _age's bar (i.e. to advance from _age to
///        _age + 1). Returns undefined once _age >= AGE_MAX -- there's no
///        next age to fill toward.
/// @param {Real} _age
/// @returns {Real|Undefined}
function AgeXpRequired(_age) {
    if (_age >= AGE_MAX) return undefined;
    return global.ageXpRequired[_age - 1];
}

/// @function AgeUpCost(_age)
/// @description The resource Cost to advance from _age to _age + 1. See
///        AgeXpRequired -- same indexing, same undefined-at-AGE_MAX rule.
/// @param {Real} _age
/// @returns {Struct.Cost|Undefined}
function AgeUpCost(_age) {
    if (_age >= AGE_MAX) return undefined;
    return global.ageUpCost[_age - 1];
}

/// @function GainXP(_team, _amount)
/// @description Adds _amount XP to _team's current age bar (capped at
///        AgeXpRequired(global.age[_team]) -- XP beyond that is discarded
///        this call, not banked; see TryAgeUp for what happens once the
///        bar is full). Awards one Fate Token
///        (global.resources[_team].fateTokens) for every one of the bar's
///        5 equal 20%-marks (20/40/60/80/100%) crossed by this gain --
///        computed from before/after position so a single large gain that
///        crosses more than one mark still awards every token earned, not
///        just one.
///
///        Does NOT advance global.age[_team] itself anymore (2026-07-06
///        doc change) -- once the bar fills, this just raises
///        global.ageUpReady[_team] so the (not-yet-built) Age Up UI can
///        offer it; call TryAgeUp to actually spend the resources and
///        advance. No-ops entirely if _team is already at AGE_MAX (nothing
///        left to fill).
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Real} _amount XP to add. No-ops if <= 0.
function GainXP(_team, _amount) {
    if (_amount <= 0) return;
    if (global.age[_team] >= AGE_MAX) return; // topped out -- no bar left to fill

    var _required = AgeXpRequired(global.age[_team]);
    var _interval = _required / AGE_FATE_TOKEN_INTERVALS;

    var _xpBefore = global.resources[_team].xp;
    var _roomLeft = _required - _xpBefore;
    if (_roomLeft <= 0) return; // bar already full, waiting on a manual TryAgeUp -- see global.ageUpReady

    var _toAdd   = min(_amount, _roomLeft); // excess beyond _required is discarded -- age no longer auto-advances, so there's nowhere to carry it into yet
    var _xpAfter = _xpBefore + _toAdd;

    global.resources[_team].xp = _xpAfter;
    AnalyticsRecordResourceProduced(_team, "xp", _toAdd);

    // Award a Fate Token for every 20%-mark crossed in (before, after].
    var _tokensEarned = floor(_xpAfter / _interval) - floor(_xpBefore / _interval);
    if (_tokensEarned > 0) {
        global.resources[_team].fateTokens += _tokensEarned;
        AnalyticsRecordResourceProduced(_team, "fateTokens", _tokensEarned);
    }

    if (_xpAfter >= _required) {
        global.ageUpReady[_team] = true;
    }
}

/// @function TryAgeUp(_team)
/// @description Attempts to advance _team to the next age. Per the
///        2026-07-06 doc, this requires BOTH the age bar to already be
///        full (global.ageUpReady[_team]) AND enough resources to cover
///        AgeUpCost(global.age[_team]) -- filling the bar only unlocks the
///        option, it doesn't pay for itself. On success: spends the cost
///        (via Purchase, Economy.gml), advances global.age[_team], resets
///        that team's xp to 0, and clears ageUpReady. No-ops (returns
///        false) if the bar isn't full yet, already at AGE_MAX, or the
///        team can't currently afford it -- safe to call speculatively
///        (e.g. from a future "Age Up" button) without checking state
///        yourself first.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Bool} True if the age actually advanced.
function TryAgeUp(_team) {
    if (!global.ageUpReady[_team]) return false;
    if (global.age[_team] >= AGE_MAX) return false;

    var _cost = AgeUpCost(global.age[_team]);
    if (!Purchase(_cost, _team)) return false;

    global.age[_team] += 1;
    global.resources[_team].xp = 0;
    global.ageUpReady[_team] = false;
    return true;
}
