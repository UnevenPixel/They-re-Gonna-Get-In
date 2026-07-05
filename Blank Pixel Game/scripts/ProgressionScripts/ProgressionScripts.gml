// -----------------------------------------------------------
// ProgressionScripts -- XP / Age / Fate Token tracking.
//
// XP fills a per-team "age bar"; filling it advances global.age[_team]
// (capped at AGE_MAX) and resets the bar for the next age. Every time the
// bar crosses one of its 4 equal quarter-marks (25/50/75/100%), the team
// gets one Fate Token -- so a full bar-fill always nets exactly 4 tokens,
// with the 4th landing on the same call that ages the team up.
//
// Ages/blueprint-tier-acquisition odds are NOT designed yet (per
// 2026-07-04 discussion) -- this file only tracks the numbers. Nothing
// reads global.age to affect blueprint odds yet; that's future work.
// XP sources (what calls GainXP, and with how much) are also not wired up
// yet -- this is just the accumulator or that's the next task.
// -----------------------------------------------------------

#macro AGE_MAX                  4     // total ages -- placeholder, effects of higher ages not designed yet
#macro AGE_XP_REQUIRED           1000  // XP to fill one age's bar -- flat placeholder, same status as every other untuned number in this project; no per-age scaling designed yet (each age currently costs the same)
#macro AGE_FATE_TOKEN_INTERVALS  4     // equal slices of the bar, each worth one Fate Token

/// @function GainXP(_team, _amount)
/// @description Adds _amount XP to _team's current age bar. Awards one
///        Fate Token (global.resources[_team].fateTokens) for every one of
///        the bar's 4 equal quarter-marks (25/50/75/100%) crossed by this
///        gain -- computed from before/after position so a single large
///        gain that crosses more than one quarter-mark (or fills the bar
///        outright) still awards every token earned, not just one.
///
///        Advances global.age[_team] each time the bar fills, carrying any
///        XP overflow into the next age's bar via a while-loop (same
///        "don't lose the remainder" idea BuildingUpdateProduction uses
///        for whole-unit resource production) -- so one huge gain can
///        advance more than one age in a single call.
///
///        Once global.age[_team] is already at AGE_MAX, XP still
///        accumulates and still awards Fate Tokens at each quarter-mark,
///        but simply stops once the bar is full instead of overflowing
///        into a nonexistent next age -- any XP beyond that point this
///        call is discarded. This is a judgment call, not a designed
///        behavior (flag if a looping/prestige bar is wanted instead once
///        ages are actually designed).
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Real} _amount XP to add. No-ops if <= 0.
function GainXP(_team, _amount) {
    if (_amount <= 0) return;

    var _quarter    = AGE_XP_REQUIRED / AGE_FATE_TOKEN_INTERVALS;
    var _remaining  = _amount;

    while (_remaining > 0) {
        var _xpBefore = global.resources[_team].xp;
        var _roomLeft = AGE_XP_REQUIRED - _xpBefore;

        if (_roomLeft <= 0) {
            // Bar already full -- only possible at AGE_MAX (a mid-progress
            // age always advances/resets the moment its bar fills below).
            // Nothing more to do; discard the rest of this gain.
            break;
        }

        var _toAdd  = min(_remaining, _roomLeft);
        var _xpAfter = _xpBefore + _toAdd;

        global.resources[_team].xp = _xpAfter;
        _remaining -= _toAdd;
        AnalyticsRecordResourceProduced(_team, "xp", _toAdd);

        // Award a Fate Token for every quarter-mark crossed in (before, after].
        var _tokensEarned = floor(_xpAfter / _quarter) - floor(_xpBefore / _quarter);
        if (_tokensEarned > 0) {
            global.resources[_team].fateTokens += _tokensEarned;
            AnalyticsRecordResourceProduced(_team, "fateTokens", _tokensEarned);
        }

        if (_xpAfter >= AGE_XP_REQUIRED) {
            if (global.age[_team] >= AGE_MAX) {
                // Topped out -- bar stays full, no further age to reach.
                break;
            }
            global.age[_team] += 1;
            global.resources[_team].xp = 0;
        }
    }
}
