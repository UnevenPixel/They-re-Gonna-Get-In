// -----------------------------------------------------------
// Training buildings -- unit queueing, per-type and army-wide unit
// limits, and spawning. Every oTrainingBuildingParent instance gets its
// training fields (trainsUnit/unitsPerBuilding/trainCost/trainTime/
// trainQueue/trainProgress) from BuildingApplyDefinition (see
// BuildingDefinitions.gml), the same way resource buildings get their
// production fields.
//
// Two independent caps gate every new unit, per the design spec:
//   1. Per-type cap: unitsPerBuilding summed across every LIVE training
//      building of that team that trains this unit type (see
//      TrainingTypeLimit). Destroying a training building lowers this
//      cap immediately but never removes existing units -- that's the
//      intentional "limit break": units already trained stay alive, but
//      nothing new can be queued for that type until either more
//      training buildings go up, or losses bring the count back under
//      the (now lower) cap.
//   2. Army-wide cap: global.armyLimit[team], regardless of unit type or
//      station status.
//
// Both caps count existing units + everything currently queued ACROSS
// EVERY training building the team owns (not just the one being clicked)
// -- "the queue + existing friendly units + other friendly queues cannot
// exceed either limit," per the design spec.
// -----------------------------------------------------------

#macro STRATEGIC_XP_FIRST_DEPLOYMENT 5 // "First deployment of unit type" -- "XP Age Progression System" doc, 2026-07-06. Awarded once per team per unit type, the first time TrainingSpawnUnit ever spawns it -- see global.unitsDeployed (oMatchControl/Create_0.gml).

/// @function CountTeamUnitsOfType(_team, _unitType)
/// @description Counts live instances of one specific unit object type
///        belonging to _team. Deliberately narrower than GatherTeamUnits
///        (GatherScripts.gml) -- that allocates a full array of every unit
///        on the team; this only needs a count of one type, so it filters
///        directly in the `with` loop instead.
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
/// @description The current cap on how many _unitType units _team may
///        have alive + queued at once: sum of unitsPerBuilding across
///        every LIVE oTrainingBuildingParent belonging to _team whose
///        trainsUnit matches _unitType. Recomputed fresh every call
///        (not cached anywhere) so destroying or building a training
///        building changes the cap immediately -- see file header for
///        why that's the intended "limit break" behavior.
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
/// @description Total units of _unitType currently queued across EVERY
///        training building _team owns -- "other friendly queues" count
///        against the same per-type cap as the queue being added to.
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
/// @description Total units of ANY type currently queued across every
///        training building _team owns -- used for the army-wide limit
///        check (global.armyLimit), which doesn't care about unit type.
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
/// @description Attempts to add one unit to _building's training queue.
///        Checks, in order: (1) this unit type's cap (existing units of
///        that type + everything queued for that type across every
///        training building the team owns -- TrainingTypeLimit), (2) the
///        team's army-wide cap (existing units of ANY type + everything
///        queued for ANY type -- global.armyLimit), (3) affordability of
///        trainCost. Deducts trainCost and increments the queue only if
///        every check passes. Every rejection is logged via
///        show_debug_message and simply leaves the queue unchanged --
///        same convention as BlueprintController.EndDrag's rejection
///        paths (BlueprintScripts.gml), no popup yet.
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
    var _typeExisting = CountTeamUnitsOfType(_team, _unitType);
    var _typeQueued   = TrainingQueuedCountForType(_team, _unitType);
    if (_typeExisting + _typeQueued + 1 > _typeLimit) {
        show_debug_message($"TrainingTryQueueUnit: {object_get_name(_unitType)} is at its type limit for team {_team} ({_typeExisting} existing + {_typeQueued} queued, limit {_typeLimit}). Build more training buildings, or wait for losses.");
        return false;
    }

    var _armyLimit    = global.armyLimit[_team];
    var _armyExisting = array_length(GatherTeamUnits(_team));
    var _armyQueued   = TrainingQueuedCountAll(_team);
    if (_armyExisting + _armyQueued + 1 > _armyLimit) {
        show_debug_message($"TrainingTryQueueUnit: team {_team} is at its army limit ({_armyExisting} existing + {_armyQueued} queued, limit {_armyLimit}).");
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
/// @description Point just outside _building's south edge to spawn a
///        freshly-trained unit at, with a small random horizontal jitter
///        so back-to-back spawns (e.g. several units completing in the
///        same frame at high match speed) don't land perfectly stacked.
/// @param {Id.Instance} _building
/// @returns {Struct.Vector2}
function TrainingGetSpawnPoint(_building) {
    return new Vector2(
        _building.x + random_range(-12, 12),
        _building.y + _building.radius + 12
    );
}

/// @function TrainingSpawnUnit(_building)
/// @description Creates one _building.trainsUnit instance just outside the
///        building, assigns it to _building's team (overriding
///        oUnitParent's Create-time hardcoded TEAM.PLAYER default -- same
///        override pattern BlueprintController.EndDrag uses for
///        buildings, see BlueprintScripts.gml), then immediately sends it
///        into "defend", patrolling _building -- per the design: units
///        built from training buildings default to defend, pointed at
///        the building that trained them.
///
///        Also re-derives guardRect for the correct team right after the
///        override: oUnitParent's Create already ran (inside
///        instance_create_layer, synchronously) using the stale default
///        team, so guardRect/fsm both briefly reflect TEAM.PLAYER even
///        when spawning for TEAM.ENEMY. In practice this is harmless --
///        Guard_Enter's wasted waypoint pick is immediately discarded and
///        Guard_Exit cleans up guardWaypointClaimed the moment we
///        ChangeState("defend") below -- but the stale guardRect would
///        otherwise linger on the instance for whenever it later returns
///        to "guard" (e.g. its defend target is destroyed). Recomputing
///        it here is a minimal, self-contained fix; flagging it rather
///        than changing oUnitParent's Create to accept a team parameter,
///        which would be a bigger change touching every unit spawn path.
///
///        Also awards STRATEGIC_XP_FIRST_DEPLOYMENT the first time
///        _building.team ever spawns this unit type, tracked via
///        global.unitsDeployed[team] (oMatchControl/Create_0.gml) --
///        "First deployment of unit type" from the 2026-07-06 "XP Age
///        Progression System" doc. Every SUBSEQUENT spawn of that same
///        type is a no-op here (checked via array_contains).
///
///        2026-07-11: if _building.inside is true (set from the plot it was
///        placed on -- see TryPlaceBlueprint, BlueprintScripts.gml), skips
///        all of the above entirely and instead calls StationSpawnDirectly
///        (StationScripts.gml), per "Any training buildings that builds a
///        unit when on an inside plot will immediately build a stationed
///        unit instead." Deliberately does NOT award
///        STRATEGIC_XP_FIRST_DEPLOYMENT for that path -- see
///        StationSpawnDirectly's doc comment for why (flagged as a judgment
///        call, not an explicit spec answer).
/// @param {Id.Instance} _building
function TrainingSpawnUnit(_building) {
    if (_building.inside) {
        StationSpawnDirectly(_building.team, _building.trainsUnit);
        AnalyticsRecordUnitTrained(_building.team, _building.trainsUnit);
        return;
    }

    var _spawnPos = TrainingGetSpawnPoint(_building);
    var _unit = instance_create_layer(_spawnPos.x, _spawnPos.y, "Instances", _building.trainsUnit);

    _unit.team      = _building.team;
    _unit.guardRect = GetTeamGuardRect(_unit.team);

    _unit.defendTarget = _building;
    _unit.fsm.ChangeState("defend");

    AnalyticsRecordUnitTrained(_building.team, _building.trainsUnit);

    if (!array_contains(global.unitsDeployed[_building.team], _building.trainsUnit)) {
        array_push(global.unitsDeployed[_building.team], _building.trainsUnit);
        GainXP(_building.team, STRATEGIC_XP_FIRST_DEPLOYMENT);
    }
}

/// @function TrainingUpdateQueue(_building)
/// @description Time-based, match-speed-scaled training progress. Unlike
///        BuildingUpdateProduction's rate-based accumulator (units/sec,
///        BuildingDefinitions.gml), this is duration-based (trainTime
///        seconds per unit), so it uses a while loop instead of a single
///        floor() -- at high match speeds a single frame's delta can
///        cross more than one trainTime, and every whole completion in
///        that frame should still spawn its unit, not just one per frame.
///
///        trainProgress resets to 0 once the queue empties -- leftover
///        partial progress is NOT banked for a future queued unit added
///        later. Deliberate simplification; flag if you'd rather partial
///        progress persist across an empty gap.
///
///        Also sets image_index -- 2026-07-11 request: frame 1 while
///        actively training (trainQueue > 0), frame 0 otherwise. A
///        placeholder ambient "something's happening here" signal ahead of
///        a real animation; every training sprite gets pointed at frame 1
///        regardless of whether it's actually been authored with one yet
///        -- GameMaker's default instance drawing wraps image_index via
///        mod(image_index, image_number), so this is a no-op glitch-wise
///        on any sprite that doesn't have a second frame yet, per the
///        request ("won't harm anything"). Set BEFORE the no-op early
///        return below so idle buildings still correctly revert to frame 0.
///
///        No-op (for progress purposes) if nothing is queued, or if
///        trainTime isn't configured (<= 0 would otherwise loop forever).
///        Call once per Step from a training building (wired from
///        oTrainingBuildingParent/Step_0.gml, so every training building
///        gets this automatically).
/// @param {Id.Instance} _building
function TrainingUpdateQueue(_building) {
    _building.image_index = (_building.trainQueue > 0) ? 1 : 0;

    if (_building.trainQueue <= 0 || _building.trainTime <= 0) return;

    var _dt = delta_time / 1000000; // microseconds -> seconds, same idiom as BuildingUpdateProduction
    _building.trainProgress += global.matchSpeed * _dt;

    while (_building.trainQueue > 0 && _building.trainProgress >= _building.trainTime) {
        _building.trainProgress -= _building.trainTime;
        _building.trainQueue    -= 1;
        TrainingSpawnUnit(_building);
    }

    if (_building.trainQueue <= 0) {
        _building.trainProgress = 0;
    }
}

// -----------------------------------------------------------
// Ambient queue progress bar -- 2026-07-11 request. A 1px-tall bar just
// below every training building's bbox, always drawn (not hover-gated) so
// there's a signal even when no hover card is showing. Drawn from a Draw
// GUI event (see DrawTrainingQueueBars) rather than each building's own
// room-space Draw so it renders above every room-space Draw call --
// units, particles, other buildings -- regardless of instance depth,
// per the request ("make sure it draws to the UI layer... stays over
// units, particles, and other buildings").
// -----------------------------------------------------------

#macro TRAINING_QUEUE_BAR_GAP_Y 2 // room-space px between the building's bbox_bottom and the bar's top edge -- not specified by the request, kept small so the bar doesn't visually merge with the building sprite's own bottom edge

/// @function DrawTrainingQueueBars()
/// @description Draws every LIVE training building's queue progress as a
///        1px-tall (exactly 1 on-screen GUI pixel, regardless of camera
///        zoom -- see the Y math below) bar spanning its bbox width,
///        TRAINING_QUEUE_BAR_GAP_Y below its bbox_bottom. Black background,
///        filled left-to-right in HOVER_CARD_TEXT_COLOR (HoverCardScripts.gml)
///        by trainProgress / trainTime -- same fill/background convention
///        as the hover card's queue row (BuildingHoverScripts.gml), just
///        always-on instead of hover-gated.
///
///        TEAM.PLAYER only -- 2026-07-12 request ("enemy buildings do not
///        show training queues or progress"). Previously flagged as NOT
///        team-restricted (matching BuildingHoverController's general
///        "informational, not ownership-gated" precedent); that's now an
///        explicit exception to that precedent for training queues
///        specifically, not a change to BuildingHoverController itself.
///
///        Call once per Draw GUI event (wired from oUnitControl/Draw_64.gml).
function DrawTrainingQueueBars() {
    // Full opacity regardless of whatever global alpha a previous Draw GUI
    // call left lingering (e.g. a hover card mid-fade) -- draw_rectangle
    // respects draw_set_alpha, unlike the draw_sprite_ext calls elsewhere
    // in this event which each pass their own alpha explicitly.
    draw_set_alpha(1);

    with (oTrainingBuildingParent) {
        if (team != TEAM.PLAYER) continue;
        if (trainsUnit == undefined) continue;

        var _fraction = (trainTime > 0) ? clamp(trainProgress / trainTime, 0, 1) : 0;

        // Only X actually needs the room->GUI conversion to track camera
        // pan/zoom correctly; Y is converted once (left/right share the
        // same world Y, so they share the same GUI Y) and then the bar is
        // drawn exactly 1 GUI px tall directly in screen space -- converting
        // TWO world Y's and taking their difference could end up rendering
        // thicker or thinner than 1px if the camera's ever zoomed relative
        // to the GUI (not currently true per UpdateCameraPan's "no vertical
        // panning" comment, but this is correct either way).
        var _barTopY = bbox_bottom + TRAINING_QUEUE_BAR_GAP_Y;
        var _left    = WorldToGui(bbox_left,  _barTopY);
        var _right   = WorldToGui(bbox_right, _barTopY);

        draw_set_color(c_black);
        draw_rectangle(_left.x, _left.y, _right.x, _left.y + 1, false);
        if (_fraction > 0) {
            draw_set_color(HOVER_CAR