// Training buildings -- unit queueing, per-type/army-wide limits, spawning,
// and the ambient queue progress bar. See TrainingScripts.md.

#macro STRATEGIC_XP_FIRST_DEPLOYMENT 5 // "First deployment of unit type" -- awarded once per team per unit type, see global.unitsDeployed (oMatchControl/Create_0.gml)

/// @function CountTeamUnitsOfType(_team, _unitType)
/// @description Counts live instances of one specific unit object type belonging to _team. Deliberately narrower than GatherTeamUnits -- see .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Asset.GMObject} _unitType e.g. oPeasantUnit.
/// @returns {Real}
function CountTeamUnitsOfType(_team, _unitType) {
    var _count = 0;
    with (_unitType) {
        if (team == _team) _count++;
    }
    return _count;
}

/// @function TrainingTypeLimit(_team, _unitType)
/// @description The current cap on how many _unitType units _team may have alive + queued at once: sum of unitsPerBuilding across every LIVE training building of _team that trains _unitType. Recomputed fresh every call -- see .md re: the "limit break" behavior this enables.
/// @param {Real} _team
/// @param {Asset.GMObject} _unitType
/// @returns {Real}
function TrainingTypeLimit(_team, _unitType) {
    var _limit = 0;
    with (oTrainingBuildingParent) {
        if (team == _team && trainsUnit == _unitType) {
            _limit += unitsPerBuilding;
        }
    }
    return _limit;
}

/// @function TrainingQueuedCountForType(_team, _unitType)
/// @description Total units of _unitType currently queued across every training building _team owns.
/// @param {Real} _team
/// @param {Asset.GMObject} _unitType
/// @returns {Real}
function TrainingQueuedCountForType(_team, _unitType) {
    var _queued = 0;
    with (oTrainingBuildingParent) {
        if (team == _team && trainsUnit == _unitType) {
            _queued += trainQueue;
        }
    }
    return _queued;
}

/// @function TrainingQueuedCountAll(_team)
/// @description Total units of ANY type currently queued across every training building _team owns -- used for the army-wide limit check.
/// @param {Real} _team
/// @returns {Real}
function TrainingQueuedCountAll(_team) {
    var _queued = 0;
    with (oTrainingBuildingParent) {
        if (team == _team) _queued += trainQueue;
    }
    return _queued;
}

/// @function TrainingTryQueueUnit(_building)
/// @description Attempts to add one unit to _building's training queue. Checks per-type cap, army-wide cap, then affordability -- see .md for the two-cap system. Deducts trainCost and increments the queue only if every check passes.
/// @param {Id.Instance} _building An oTrainingBuildingParent instance.
/// @returns {Bool} True if a unit was successfully queued.
function TrainingTryQueueUnit(_building) {
    var _team     = _building.team;
    var _unitType = _building.trainsUnit;

    if (_unitType == undefined) {
        show_debug_message($"TrainingTryQueueUnit: {object_get_name(_building.object_index)} has no trainsUnit -- check its BuildingDefinition.");
        return false;
    }

    var _typeLimit    = TrainingTypeLimit(_team, _unitType);
    var _typeExisting = CountTeamUnitsOfType(_team, _unitType) + CountTeamStationedUnitsOfType(_team, _unitType);
    var _typeQueued   = TrainingQueuedCountForType(_team, _unitType);
    if (_typeExisting + _typeQueued + 1 > _typeLimit) {
        show_debug_message($"TrainingTryQueueUnit: {object_get_name(_unitType)} is at its type limit for team {_team} ({_typeExisting} existing/stationed + {_typeQueued} queued, limit {_typeLimit}). Build more training buildings, or wait for losses.");
        return false;
    }

    var _armyLimit     = global.armyLimit[_team];
    var _armyExisting  = array_length(GatherTeamUnits(_team)) + CountTeamStationedUnits(_team);
    var _armyQueued    = TrainingQueuedCountAll(_team);
    if (_armyExisting + _armyQueued + 1 > _armyLimit) {
        show_debug_message($"TrainingTryQueueUnit: team {_team} is at its army limit ({_armyExisting} existing/stationed + {_armyQueued} queued, limit {_armyLimit}).");
        return false;
    }

    if (!_building.trainCost.CanAfford(_team)) {
        show_debug_message($"TrainingTryQueueUnit: team {_team} can't afford to queue {object_get_name(_unitType)}.");
        return false;
    }

    Purchase(_building.trainCost, _team);
    _building.trainQueue += 1;
    return true;
}

/// @function TrainingGetSpawnPoint(_building)
/// @description Point just outside _building's south edge to spawn a freshly-trained unit at, with random horizontal jitter so back-to-back spawns don't land stacked.
/// @param {Id.Instance} _building
/// @returns {Struct.Vector2}
function TrainingGetSpawnPoint(_building) {
    return new Vector2(
        _building.x + random_range(-12, 12),
        _building.y + _building.radius + 12
    );
}

/// @function TrainingSpawnUnit(_building)
/// @description Creates one _building.trainsUnit instance just outside the building, assigns it to _building's team, then sends it into "defend" patrolling the building. Re-derives guardRect and re-runs UnitApplyDefinition after the team override -- see .md for why both are needed. Awards STRATEGIC_XP_FIRST_DEPLOYMENT on a team's first spawn of a unit type. If _building.inside, routes to StationSpawnDirectly instead (no live unit ever exists) -- see .md. Notifies the guided tutorial (global.tutorialGuide.NotifyUnitTrained) on both branches -- 2026-08-13, see TutorialGuideScripts.md.
/// @param {Id.Instance} _building
function TrainingSpawnUnit(_building) {
    if (_building.inside) {
        StationSpawnDirectly(_building.team, _building.trainsUnit);
        AnalyticsRecordUnitTrained(_building.team, _building.trainsUnit);
        global.tutorialGuide.NotifyUnitTrained(_building.team, _building.trainsUnit);
        return;
    }

    var _spawnPos = TrainingGetSpawnPoint(_building);
    var _unit = instance_create_layer(_spawnPos.x, _spawnPos.y, "Instances", _building.trainsUnit);

    _unit.team      = _building.team;
    _unit.guardRect = GetTeamGuardRect(_unit.team);
    UnitApplyDefinition(_unit); // re-stamp with the correct team's stationed bonuses now baked in -- see .md

    _unit.defendTarget = _building;
    _unit.fsm.ChangeState("defend");

    AnalyticsRecordUnitTrained(_building.team, _building.trainsUnit);
    global.tutorialGuide.NotifyUnitTrained(_building.team, _building.trainsUnit);

    if (!array_contains(global.unitsDeployed[_building.team], _building.trainsUnit)) {
        array_push(global.unitsDeployed[_building.team], _building.trainsUnit);
        GainXP(_building.team, STRATEGIC_XP_FIRST_DEPLOYMENT);
    }
}

/// @function TrainingUpdateQueue(_building)
/// @description Time-based, match-speed-scaled training progress -- duration-based (trainTime seconds/unit), so a while loop handles multiple completions in one high-match-speed frame. Sets image_index as a placeholder training-active signal. No-ops if nothing queued or trainTime unconfigured. See .md.
/// @param {Id.Instance} _building
function TrainingUpdateQueue(_building) {
    _building.image_index = (_building.trainQueue > 0) ? 1 : 0;

    if (_building.trainQueue <= 0 || _building.trainTime <= 0) return;

    var _bonus = GetStationedPassiveBonuses(_building.team);

    var _dt = delta_time / 1000000; // microseconds -> seconds, same idiom as BuildingUpdateProduction
    _building.trainProgress += global.matchSpeed * _dt * (1 + _bonus.trainingSpeedBonus);

    while (_building.trainQueue > 0 && _building.trainProgress >= _building.trainTime) {
        _building.trainProgress -= _building.trainTime;
        _building.trainQueue    -= 1;
        TrainingSpawnUnit(_building);
    }

    if (_building.trainQueue <= 0) {
        _building.trainProgress = 0;
    }
}

#macro TRAINING_QUEUE_BAR_GAP_Y 2 // room-space px between the building's bbox_bottom and the bar's top edge

/// @function DrawTrainingQueueBars()
/// @description Draws every LIVE training building's queue progress as an always-on 1px-tall bar below its bbox, TEAM.PLAYER only. Call once per Draw GUI event (wired from oUnitControl/Draw_64.gml). See .md.
function DrawTrainingQueueBars() {
    // Full opacity regardless of whatever global alpha a previous Draw GUI
    // call left lingering (e.g. a hover card mid-fade).
    draw_set_alpha(1);

    with (oTrainingBuildingParent) {
        if (team != TEAM.PLAYER) continue;
        if (trainsUnit == undefined) continue;

        var _fraction = (trainTime > 0) ? clamp(trainProgress / trainTime, 0, 1) : 0;

        // Only X needs the room->GUI conversion; Y is converted once and the
        // bar drawn exactly 1 GUI px tall in screen space -- see .md.
        var _barTopY = bbox_bottom + TRAINING_QUEUE_BAR_GAP_Y;
        var _left    = WorldToGui(bbox_left,  _barTopY);
        var _right   = WorldToGui(bbox_right, _barTopY);

        draw_set_color(c_black);
        draw_rectangle(_left.x, _left.y, _right.x, _left.y + 1, false);
        if (_fraction > 0) {
            draw_set_color(HOVER_CARD_TEXT_COLOR);
            draw_rectangle(_left.x, _left.y, _left.x + (_right.x - _left.x) * _fraction, _left.y + 1, false);
        }
    }
}
