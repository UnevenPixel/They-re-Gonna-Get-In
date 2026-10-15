// XP / Age / Fate Token tracking, built against the "XP Age Progression
// System" design doc. See ProgressionScripts.md.

#macro AGE_MAX                  4     // total ages -- placeholder, effects of higher ages not designed yet
#macro AGE_FATE_TOKEN_INTERVALS  5     // equal slices of the bar, each worth one Fate Token (20% each)

// XP required to fill each age's bar -- index 0 = Age I->II, 1 = Age
// II->III, 2 = Age III->IV (AGE_MAX - 1 entries; no bar to fill at AGE_MAX).
global.ageXpRequired = [100, 150, 200];

// Resource cost to execute an Age Up once its bar is full -- same indexing
// as global.ageXpRequired. WIP per the design doc -- gold-only for now.
global.ageUpCost = [
    new Cost([new ResourceCost("gold", 150)]),
    new Cost([new ResourceCost("gold", 250)]),
    new Cost([new ResourceCost("gold", 400)]),
];

/// @function AgeXpRequired(_age)
/// @description XP needed to fill _age's bar (to advance from _age to _age + 1). Returns undefined once _age >= AGE_MAX.
/// @param {Real} _age
/// @returns {Real|Undefined}
function AgeXpRequired(_age) {
    if (_age >= AGE_MAX) return undefined;
    return global.ageXpRequired[_age - 1];
}

/// @function AgeUpCost(_age)
/// @description The resource Cost to advance from _age to _age + 1. Same indexing/undefined rule as AgeXpRequired.
/// @param {Real} _age
/// @returns {Struct.Cost|Undefined}
function AgeUpCost(_age) {
    if (_age >= AGE_MAX) return undefined;
    return global.ageUpCost[_age - 1];
}

/// @function GainXP(_team, _amount)
/// @description Adds _amount XP to _team's current age bar (capped at AgeXpRequired, excess discarded). Awards one Fate Token per 20%-mark crossed (TEAM.ENEMY gets 1-3 random blueprints per mark instead -- see .md). Does NOT advance global.age itself -- raises global.ageUpReady once the bar fills; call TryAgeUp to actually advance. No-ops if _team is already at AGE_MAX.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Real} _amount XP to add. No-ops if <= 0.
function GainXP(_team, _amount) {
    if (_amount <= 0) return;
    if (global.age[_team] >= AGE_MAX) return; // topped out -- no bar left to fill

    var _required = AgeXpRequired(global.age[_team]);
    var _interval = _required / AGE_FATE_TOKEN_INTERVALS;

    var _xpBefore = global.resources[_team].xp;
    var _roomLeft = _required - _xpBefore;
    if (_roomLeft <= 0) return; // bar already full, waiting on a manual TryAgeUp

    var _toAdd   = min(_amount, _roomLeft); // excess beyond _required is discarded
    var _xpAfter = _xpBefore + _toAdd;

    global.resources[_team].xp = _xpAfter;
    AnalyticsRecordResourceProduced(_team, "xp", _toAdd);

    // Award a Fate Token for every 20%-mark crossed in (before, after] --
    // TEAM.ENEMY gets 1-3 random blueprints per milestone instead. See .md.
    var _tokensEarned = floor(_xpAfter / _interval) - floor(_xpBefore / _interval);
    if (_tokensEarned > 0) {
        if (_team == TEAM.ENEMY) {
            var _buildingTypes = ds_map_keys_to_array(global.__buildingDefRegistry);
            if (array_length(_buildingTypes) > 0) {
                for (var m = 0; m < _tokensEarned; m++) {
                    var _blueprintCount = irandom_range(1, 3);
                    for (var b = 0; b < _blueprintCount; b++) {
                        var _buildingType = _buildingTypes[irandom(array_length(_buildingTypes) - 1)];
                        AddBlueprint(_team, _buildingType, 1);
                    }
                }
            }
        } else {
            global.resources[_team].fateTokens += _tokensEarned;
            AnalyticsRecordResourceProduced(_team, "fateTokens", _tokensEarned);
        }
    }

    if (_xpAfter >= _required) {
        global.ageUpReady[_team] = true;
    }
}

/// @function TryAgeUp(_team)
/// @description Attempts to advance _team to the next age -- requires both a full age bar (global.ageUpReady) AND enough resources to cover AgeUpCost. On success: spends the cost, advances global.age, resets xp to 0, clears ageUpReady. Safe to call speculatively -- no-ops if not ready, already maxed, or unaffordable. See .md.
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
