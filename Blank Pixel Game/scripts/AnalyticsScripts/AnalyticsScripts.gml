// -----------------------------------------------------------
// Playtest analytics -- LOCAL COLLECTION ONLY for now. Every
// AnalyticsRecord* function below updates the in-memory global.analytics
// struct immediately. The actual Steam Stats API calls that would upload
// each number are written out but commented out, since none of these stat
// names exist yet on the Steamworks control panel -- see each function's
// doc comment for the exact API name it expects. Those need to be created
// there (as Integer stats, matching steam_set_stat_int's type) before
// uncommenting anything here.
//
// Scope: tracked per-team (global.analytics[TEAM.PLAYER]/[TEAM.ENEMY]),
// mirroring global.resources/global.blueprints/global.armyLimit. Only
// TEAM.PLAYER's numbers are ever meaningful to actually send to Steam --
// there's no Steam account for the AI side -- so every commented Steam
// call below is gated behind `if (_team == TEAM.PLAYER)`, even though the
// local struct keeps both teams' numbers (useful for internal balance
// analysis regardless of what ever reaches Steam).
//
// Steam stats are LIFETIME/persistent per Steam account by design (see
// steam_set_stat_int's own manual example: read the existing value, add
// the delta, set it back -- steam_set_stat_int("Total_XP",
// steam_get_stat_int("Total_XP") + 100)). The local global.analytics
// struct, by contrast, resets every match (AnalyticsInit runs once from
// oMatchControl's Create). That mismatch is intentional: locally you get
// this match's numbers; the (currently commented) Steam call accumulates
// the all-time total the same way the manual's own example does.
//
// "Lethality" (kills/deaths per unit type) is the one metric that ISN'T
// wired to anything yet -- see AnalyticsRecordKill/AnalyticsRecordDeath
// below for why, and flag back whether "lethality" should end up meaning
// raw kills, a kills/deaths ratio, or something damage-based once real
// combat resolution exists to compute it from.
// -----------------------------------------------------------

/// @function AnalyticsInit()
/// @description Resets all local playtest analytics for a new match. Call
///        once from oMatchControl's Create event, alongside
///        global.resources/global.blueprints/global.armyLimit.
function AnalyticsInit() {
    global.analytics = array_create(2, undefined);
    for (var i = 0; i < 2; i++) {
        global.analytics[i] = {
            unitsTrained:     ds_map_create(), // object_index -> count
            kills:            ds_map_create(), // object_index -> count
            deaths:           ds_map_create(), // object_index -> count
            buildingsBuilt:   ds_map_create(), // object_index -> count
            // xp/fateTokens added 2026-07-06 -- GainXP (ProgressionScripts.gml)
            // calls AnalyticsRecordResourceProduced(_team, "xp", ...) and
            // (_team, "fateTokens", ...), but neither key existed on this
            // struct, so struct_get returned undefined and
            // `undefined + _amt` crashed the instant any XP was ever
            // actually awarded (first repro: TrainingSpawnUnit's
            // first-deployment Strategic XP). Added to resourceSpent too
            // for symmetry -- nothing spends xp/fateTokens as a Cost today,
            // but Cost/ResourceCost already supports both as a resource
            // type, so this heads off the identical crash the moment
            // something does.
            resourceProduced: { wood:0, wheat:0, water:0, iron:0, gold:0, meat:0, bones:0, coal:0, weapons:0, coins:0, xp:0, fateTokens:0 },
            resourceSpent:    { wood:0, wheat:0, water:0, iron:0, gold:0, meat:0, bones:0, coal:0, weapons:0, coins:0, xp:0, fateTokens:0 },
        };
    }

    global.analyticsMatchTimeSeconds = 0; // this match's elapsed real time -- see AnalyticsUpdateMatchTime
}

/// @function AnalyticsStatName(_prefix, _objectIndex)
/// @description Builds a Steam-API-friendly stat name from an object
///        type, e.g. ("units_trained", oPeasantUnit) ->
///        "units_trained_peasantunit". Strips the leading "o" from the
///        object name (this codebase's object-naming convention, see
///        CLAUDE.md) so stat names read cleanly on the Steamworks
///        dashboard.
/// @param {String} _prefix
/// @param {Asset.GMObject} _objectIndex
/// @returns {String}
function AnalyticsStatName(_prefix, _objectIndex) {
    var _name = object_get_name(_objectIndex);
    if (string_char_at(_name, 1) == "o") {
        _name = string_delete(_name, 1, 1);
    }
    return _prefix + "_" + string_lower(_name);
}

/// @function AnalyticsMapIncrement(_map, _key)
/// @description Shared ds_map "increment or initialize to 1" helper, used
///        by every count-based Record function below.
/// @param {Id.DsMap} _map
/// @param {Asset.GMObject} _key
/// @returns {Real} The new count.
function AnalyticsMapIncrement(_map, _key) {
    var _count = ds_map_exists(_map, _key) ? _map[? _key] : 0;
    _count += 1;
    ds_map_set(_map, _key, _count);
    return _count;
}

/// @function AnalyticsRecordUnitTrained(_team, _unitType)
/// @description Records one _unitType unit completing training for
///        _team. Wired from TrainingSpawnUnit (TrainingScripts.gml) --
///        fires once per unit that actually finishes training, not once
///        per queue slot filled.
///        Steam stat: "units_trained_<type>" (Integer, lifetime total --
///        create per unit type on the Steamworks control panel before
///        uncommenting).
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Asset.GMObject} _unitType
function AnalyticsRecordUnitTrained(_team, _unitType) {
    AnalyticsMapIncrement(global.analytics[_team].unitsTrained, _unitType);

    if (_team == TEAM.PLAYER) {
        // var _stat = AnalyticsStatName("units_trained", _unitType);
        // steam_set_stat_int(_stat, steam_get_stat_int(_stat) + 1);
    }
}

/// @function AnalyticsRecordKill(_team, _unitType)
/// @description Records one _unitType unit (belonging to _team) scoring a
///        kill. NOT WIRED ANYWHERE YET -- there's no "unit died" event in
///        the codebase to call this from. UnitTryDealDamage's actual
///        damage calculation is still an unimplemented TODO
///        (UnitCombatHelpers.gml), so nothing currently determines when a
///        unit dies, let alone who killed it. This function (and
///        AnalyticsRecordDeath below) exist so "lethality" has somewhere
///        to record to the moment real damage/death logic exists -- call
///        both from wherever a unit's hp finally reaches 0. Deliberately
///        not inventing death detection here; combat/damage resolution is
///        out of scope for this task and flagged separately.
///        Steam stat: "kills_<type>" (Integer, lifetime total).
/// @param {Real} _team Team the KILLING unit belongs to.
/// @param {Asset.GMObject} _unitType Object type of the killing unit.
function AnalyticsRecordKill(_team, _unitType) {
    AnalyticsMapIncrement(global.analytics[_team].kills, _unitType);

    if (_team == TEAM.PLAYER) {
        // var _stat = AnalyticsStatName("kills", _unitType);
        // steam_set_stat_int(_stat, steam_get_stat_int(_stat) + 1);
    }
}

/// @function AnalyticsRecordDeath(_team, _unitType)
/// @description Records one _unitType unit (belonging to _team) dying.
///        Same "not wired anywhere yet" caveat as AnalyticsRecordKill --
///        see that function's doc for why.
///        Steam stat: "deaths_<type>" (Integer, lifetime total).
/// @param {Real} _team Team the DYING unit belongs to.
/// @param {Asset.GMObject} _unitType
function AnalyticsRecordDeath(_team, _unitType) {
    AnalyticsMapIncrement(global.analytics[_team].deaths, _unitType);

    if (_team == TEAM.PLAYER) {
        // var _stat = AnalyticsStatName("deaths", _unitType);
        // steam_set_stat_int(_stat, steam_get_stat_int(_stat) + 1);
    }
}

/// @function AnalyticsRecordBuildingBuilt(_team, _buildingType)
/// @description Records one _buildingType building being placed for
///        _team. Wired from BlueprintController.EndDrag
///        (BlueprintScripts.gml) -- fires once per building actually
///        placed on a plot, not once per blueprint granted.
///        Steam stat: "buildings_built_<type>" (Integer, lifetime total).
/// @param {Real} _team
/// @param {Asset.GMObject} _buildingType
function AnalyticsRecordBuildingBuilt(_team, _buildingType) {
    AnalyticsMapIncrement(global.analytics[_team].buildingsBuilt, _buildingType);

    if (_team == TEAM.PLAYER) {
        // var _stat = AnalyticsStatName("buildings_built", _buildingType);
        // steam_set_stat_int(_stat, steam_get_stat_int(_stat) + 1);
    }
}

/// @function AnalyticsRecordResourceProduced(_team, _resource, _amt)
/// @description Adds _amt to _team's running total of _resource
///        produced. Wired from BuildingUpdateProduction
///        (BuildingDefinitions.gml).
///        Steam stat: "resource_produced_<resource>" (Integer, lifetime
///        total).
/// @param {Real} _team
/// @param {String} _resource Matches a key in global.resources, e.g. "wheat".
/// @param {Real} _amt
function AnalyticsRecordResourceProduced(_team, _resource, _amt) {
    var _s = global.analytics[_team].resourceProduced;
    struct_set(_s, _resource, struct_get(_s, _resource) + _amt);

    if (_team == TEAM.PLAYER) {
        // var _stat = "resource_produced_" + _resource;
        // steam_set_stat_int(_stat, steam_get_stat_int(_stat) + _amt);
    }
}

/// @function AnalyticsRecordResourceSpent(_team, _resource, _amt)
/// @description Adds _amt to _team's running total of _resource spent.
///        Wired from Purchase (Economy.gml) -- the single choke point
///        every cost (building placement, unit training) already flows
///        through, so this covers every spend automatically without
///        touching each call site individually.
///        Steam stat: "resource_spent_<resource>" (Integer, lifetime total).
/// @param {Real} _team
/// @param {String} _resource
/// @param {Real} _amt
function AnalyticsRecordResourceSpent(_team, _resource, _amt) {
    var _s = global.analytics[_team].resourceSpent;
    struct_set(_s, _resource, struct_get(_s, _resource) + _amt);

    if (_team == TEAM.PLAYER) {
        // var _stat = "resource_spent_" + _resource;
        // steam_set_stat_int(_stat, steam_get_stat_int(_stat) + _amt);
    }
}

/// @function AnalyticsUpdateMatchTime()
/// @description Accumulates real (wall-clock) elapsed seconds for the
///        current match -- deliberately NOT scaled by global.matchSpeed,
///        since "time spent in a match" is about actual playtest session
///        length, not simulated game time, and deliberately keeps
///        counting through a matchSpeed-0 pause for the same reason.
///        Call once per Step (wired from oMatchControl/Step_0.gml).
///        Steam stat: "match_time_seconds" (Integer, LIFETIME total
///        across every match played -- read-add-set, same idiom as every
///        other Record function here, NOT a per-match overwrite).
function AnalyticsUpdateMatchTime() {
    global.analyticsMatchTimeSeconds += delta_time / 1000000;

    // Deliberately NOT calling steam_set_stat_int every Step even once
    // uncommented -- that's an enormous number of API calls over a play
    // session for one slowly-growing number. Batch it instead: call
    // something like the block below periodically (e.g. once every N
    // seconds via its own timer, or once at whatever "match over" ends up
    // being) rather than every frame.
    // var _stat = "match_time_seconds";
    // steam_set_stat_int(_stat, steam_get_stat_int(_stat) + round(delta_time / 1000000));
}
