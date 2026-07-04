#macro AI_THINK_INTERVAL    45   // frames between AI decisions (~0.75s at 60fps) -- deliberately not every-frame, keeps behavior considered rather than twitchy
#macro AI_ATTACK_GROUP_SIZE 5    // idle units massed before the AI commits to a siege push

/// @function AIBrain(_team)
/// @description Top-level decision-maker for a computer-controlled team. Call
///        Step() once per Step event; internally ticks a think timer and only
///        re-evaluates every AI_THINK_INTERVAL frames. Owns a StateMachine for
///        its own strategic posture (currently just "build_up") so future
///        behaviors -- defending, expanding, purchasing units -- slot in as new
///        AI states rather than growing one function into a monolith. Dispatches
///        orders through IssueOrderToUnits, the exact same path the player's
///        SelectionController uses, so AI and player units are driven identically
///        once an order is issued.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY -- which side this brain plays.
function AIBrain(_team) constructor {
    team       = _team;
    thinkTimer = AI_THINK_INTERVAL;

    fsm = new StateMachine(self);
    fsm.AddState("build_up", new State(undefined, AI_BuildUp_Step, undefined, undefined));
    fsm.ChangeState("build_up");

    /// @function Step()
    /// @description Call once per Step event. Ticks the think timer and, on
    ///        expiry, runs one decision cycle through the AI's StateMachine.
    ///        Scaled by global.matchSpeed so the AI thinks faster/slower in
    ///        step with everything else, and stops deciding entirely while
    ///        paused (matchSpeed 0) rather than continuing to think.
    /// @returns {Struct.AIBrain} self
    static Step = function() {
        thinkTimer -= global.matchSpeed;
        if (thinkTimer <= 0) {
            thinkTimer = AI_THINK_INTERVAL;
            fsm.Step();
        }
        return self;
    }
}

/// @function AI_BuildUp_Step(_brain, _machine)
/// @description AI onStep for "build_up" -- currently the only AI state. Each
///        think tick: spends any affordable blueprints (AI_TryPlaceBlueprints),
///        tries to queue training at every owned training building
///        (AI_TryTrainAtAllBuildings), then gathers every unit on _brain.team
///        (via GatherTeamUnits) and counts how many are idle (still in
///        "guard", i.e. not already committed to an order). Once
///        AI_ATTACK_GROUP_SIZE or more are idle, masses them and issues "siege"
///        against the enemy castle.
///
///        Economy and combat are both handled by this one state rather than
///        split into sibling AI states -- "build_up" already represents the
///        AI's economic buildup phase, and the original doc comment here
///        anticipated exactly this ("purchasing units" as a natural
///        extension). Split into real sibling states (e.g. "defend") once
///        the AI needs to react differently to threats rather than always
///        building/training/massing on the same cadence.
/// @param {Struct.AIBrain} _brain
/// @param {Struct.StateMachine} _machine
function AI_BuildUp_Step(_brain, _machine) {
    AI_TryPlaceBlueprints(_brain.team);
    AI_TryTrainAtAllBuildings(_brain.team);

    var _units = GatherTeamUnits(_brain.team);
    var _idle  = [];

    for (var i = 0; i < array_length(_units); i++) {
        var _u = _units[i];
        if (_u.fsm.Is("guard")) {
            array_push(_idle, _u);
        }
    }

    if (array_length(_idle) >= AI_ATTACK_GROUP_SIZE) {
        IssueOrderToUnits("siege", _idle);
    }
}

// -----------------------------------------------------------
// AI economy -- building placement + training. Both are deliberately
// greedy/simple (no build-order priority, no plot-category preference):
// spend whatever's affordable, train at every owned training building,
// every think tick. Reuses the exact same underlying functions the
// player's UI calls (TryPlaceBlueprint, TrainingTryQueueUnit) so AI-built
// structures and AI-trained units go through identical cost/limit/
// analytics handling as the player's.
// -----------------------------------------------------------

/// @function AI_FindEmptyOwnedPlot(_team)
/// @description First unblocked oBuildingPlot belonging to _team, or
///        noone. No inside/outside preference -- oOuterPlotSpawner's
///        header comment describes an intended future placement bonus
///        split (resource buildings outside, training buildings inside),
///        but no such bonus system exists yet to make that choice matter,
///        so this just grabs whichever empty owned plot it finds first.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Id.Instance|Constant.NoOne}
function AI_FindEmptyOwnedPlot(_team) {
    var _found = noone;
    with (oBuildingPlot) {
        if (team == _team && !blocked) {
            _found = id;
            break;
        }
    }
    return _found;
}

/// @function AI_TryPlaceBlueprints(_team)
/// @description Attempts to place every currently-affordable blueprint
///        _team owns onto any empty plot it owns, via TryPlaceBlueprint
///        (BlueprintScripts.gml) -- the same placement logic
///        BlueprintController.EndDrag uses for the player's mouse-drag
///        flow, just called directly with a plot the AI picked itself
///        instead of one resolved from the cursor.
///        Iterates global.blueprints[_team] BACKWARDS deliberately: a
///        successful placement calls RemoveBlueprintOne, which can delete
///        the stack it just consumed (array_delete) -- iterating from the
///        end means that deletion only ever shifts indices this loop has
///        already visited, never ones still to come.
/// @param {Real} _team
function AI_TryPlaceBlueprints(_team) {
    var _stacks = global.blueprints[_team];
    for (var i = array_length(_stacks) - 1; i >= 0; i--) {
        var _buildingType = _stacks[i].buildingType;
        var _def = GetBuildingDefinition(_buildingType);
        if (_def == undefined || !_def.cost.CanAfford(_team)) continue;

        var _plot = AI_FindEmptyOwnedPlot(_team);
        if (_plot == noone) continue;

        TryPlaceBlueprint(_team, _buildingType, _plot);
    }
}

/// @function AI_TryTrainAtAllBuildings(_team)
/// @description Attempts to queue one unit at every training building
///        _team owns, via TrainingTryQueueUnit (TrainingScripts.gml).
///        That function already does all the real work -- type/army
///        limit checks, affordability -- and is safe to call
///        speculatively every think tick: it just logs and returns false
///        if it can't queue right now, so there's no extra bookkeeping
///        needed here to avoid over-queueing.
/// @param {Real} _team
function AI_TryTrainAtAllBuildings(_team) {
    with (oTrainingBuildingParent) {
        if (team == _team) {
            TrainingTryQueueUnit(id);
        }
    }
}
