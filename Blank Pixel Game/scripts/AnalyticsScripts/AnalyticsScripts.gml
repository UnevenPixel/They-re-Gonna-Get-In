// Playtest analytics -- local collection only for now; Steam Stats API
// calls are written but commented out until the stat names exist on the
// Steamworks control panel. See AnalyticsScripts.md.

/// @function AnalyticsInit()
/// @description Resets all local playtest analytics for a new match. Call once from oMatchControl's Create event, alongside global.resources/global.blueprints/global.armyLimit.
function AnalyticsInit() {
    global.analytics = array_create(2, undefined);
    for (var i = 0; i < 2; i++) {
        global.analytics[i] = {
            unitsTrained:     ds_map_create(), // object_index -> count
            kills:            ds_map_create(), // object_index -> count
            deaths:           ds_map_create(), // object_index -> count
            buildingsBuilt:   ds_map_create(), // object_index -> count
            resourceProduced: { wood:0, wheat:0, water:0, iron:0, gold:0, meat:0, bones:0, coal:0, weapons:0, coins:0, xp:0, fateTokens:0 },
            resourceSpent:    { wood:0, wheat:0, water:0, iron:0, gold:0, meat:0, bones:0, coal:0, weapons:0, coins:0, xp:0, fateTokens:0 },
        };
    }

    global.analyticsMatchTimeSeconds = 0; // this match's elapsed real time -- see AnalyticsUpdateMatchTime
}

/// @function AnalyticsStatName(_prefix, _objectIndex)
/// @description Builds a Steam-API-friendly stat name from an object type, e.g. ("units_trained", oPeasantUnit) -> "units_trained_peasantunit". Strips the leading "o" naming convention.
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
/// @description Shared ds_map "increment or initialize to 1" helper, used by every count-based Record function below.
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
/// @description Records one _unitType unit completing training for _team. Wired from TrainingSpawnUnit (TrainingScripts.gml). Steam stat: "units_trained_<type>" (Integer, lifetime).
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
/// @description Records one _unitType unit (belonging to _team) scoring a kill. NOT WIRED ANYWHERE YET -- no "unit died" event exists yet. See .md. Steam stat: "kills_<type>".
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
/// @description Records one _unitType unit (belonging to _team) dying. Same "not wired anywhere yet" caveat as AnalyticsRecordKill. Steam stat: "deaths_<type>".
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
/// @description Records one _buildingType building being placed for _team. Wired from BlueprintController.EndDrag (BlueprintScripts.gml). Steam stat: "buildings_built_<type>".
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
/// @description Adds _amt to _team's running total of _resource produced. Wired from BuildingUpdateProduction (BuildingDefinitions.gml). Steam stat: "resource_produced_<resource>".
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
/// @description Adds _amt to _team's running total of _resource spent. Wired from Purchase (Economy.gml) -- the single choke point every cost flows through. Steam stat: "resource_spent_<resource>".
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
/// @description Accumulates real (wall-clock) elapsed seconds for the current match -- not scaled by global.matchSpeed, keeps counting through a matchSpeed-0 pause. Call once per Step (oMatchControl/Step_0.gml). Steam stat: "match_time_seconds" (lifetime, read-add-set). See .md re: batching.
function AnalyticsUpdateMatchTime() {
    global.analyticsMatchTimeSeconds += delta_time / 1000000;

    // Deliberately NOT calling steam_set_stat_int every Step even once
    // uncommented -- batch it periodically instead (see .md).
    // var _stat = "match_time_seconds";
    // steam_set_stat_int(_stat, steam_get_stat_int(_stat) + round(delta_time / 1000000));
}
