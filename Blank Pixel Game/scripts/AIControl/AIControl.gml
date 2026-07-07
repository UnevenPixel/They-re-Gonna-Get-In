#macro AI_THINK_INTERVAL    45   // frames between AI decisions (~0.75s at 60fps) -- deliberately not every-frame, keeps behavior considered rather than twitchy
#macro AI_THREAT_RADIUS     250  // how close an enemy unit must get to one of a team's buildings before AI_DetectThreat flags it as a threat -- placeholder, not tuned against any real unit speed/reaction-time math
#macro AI_CASTLE_THREAT_RADIUS 300 // how close an enemy unit must get to a team's OWN castle before AI_CastleUnderThreat flags it -- larger than AI_THREAT_RADIUS since the castle itself (350x411) is much bigger than an ordinary 48x48 building being measured from its origin; placeholder, not tuned
#macro AI_SIEGE_POWER_FRACTION 0.6 // AI_ArmyPower(available units) must reach this fraction of CASTLE_MAX_HEALTH (CastleScripts.gml) before the AI commits to "siege" -- a rough "don't throw two peasants at the wall" gate, not a tuned balance number. Replaces the old flat AI_ATTACK_GROUP_SIZE headcount (2026-07-06).
#macro AI_POWER_HEALTH_WEIGHT 0.4 // AI_UnitPowerScore weight on current HP -- placeholder, see that function
#macro AI_POWER_DAMAGE_WEIGHT 5   // AI_UnitPowerScore weight on attackDamage -- placeholder, see that function
#macro AI_TANK_TARGET_RATIO   0.25 // AI_TryTrainComposition: desired minimum fraction of _team's live army carrying the "tank" tag before training anything else at a building that doesn't
#macro AI_RANGED_TARGET_RATIO 0.25 // same, for "ranged"

/// @function AIBrain(_team)
/// @description Top-level decision-maker for a computer-controlled team. Call
///        Step() once per Step event; internally ticks a think timer and only
///        re-evaluates every AI_THINK_INTERVAL frames. Owns a StateMachine for
///        its own strategic posture -- "build_up" (economy/training/siege-
///        massing), "defending" (reactive response to a threatened ordinary
///        building, added 2026-07-06), and "castle_defense" (the AI's own
///        castle under attack, added 2026-07-06 -- outranks both of the
///        others, see AI_CastleUnderThreat) -- so future postures slot in as
///        new AI states rather than growing one function into a monolith.
///        Dispatches orders through IssueOrderToUnits, the exact same path
///        the player's SelectionController uses, so AI and player units are
///        driven identically once an order is issued.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY -- which side this brain plays.
function AIBrain(_team) constructor {
    team       = _team;
    thinkTimer = AI_THINK_INTERVAL;

    fsm = new StateMachine(self);
    fsm.AddState("build_up",      new State(undefined, AI_BuildUp_Step,       undefined, undefined))
       .AddState("defending",     new State(undefined, AI_Defending_Step,     undefined, undefined))
       .AddState("castle_defense", new State(undefined, AI_CastleDefense_Step, undefined, undefined));
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

/// @function AI_GatherAvailableUnits(_team)
/// @description Every _team unit this think-cycle is free to redirect --
///        "guard" (default idle patrol) OR "defend" (patrolling whatever
///        building trained it, per TrainingSpawnUnit's default -- NOT the
///        same as committed). Treating only "guard" as available (the
///        original 2026-07-05 behavior) was a real bug: TrainingSpawnUnit
///        always sends a freshly trained unit straight into "defend", and a
///        unit only ever falls back to "guard" if that specific building is
///        later destroyed -- so under normal play, every AI-trained unit
///        would sit in "defend" forever and the old idle-count (which only
///        checked "guard") would likely never climb high enough to trigger
///        a siege push at all. Units already committed to combat/attack/
///        attackRanged/siege/combatRanged are correctly excluded either way
///        -- this pass doesn't recall units mid-task.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Array<Id.Instance>}
function AI_GatherAvailableUnits(_team) {
    var _units     = GatherTeamUnits(_team);
    var _available = [];
    for (var i = 0; i < array_length(_units); i++) {
        var _u = _units[i];
        if (_u.fsm.Is("guard") || _u.fsm.Is("defend")) {
            array_push(_available, _u);
        }
    }
    return _available;
}

/// @function AI_BuildUp_Step(_brain, _machine)
/// @description AI onStep for "build_up" -- the AI's default economic/
///        training/massing posture. Each think tick: checks the AI's OWN
///        castle first and hands off to "castle_defense" if it's under
///        attack (see AI_CastleUnderThreat -- this outranks the ordinary
///        building-threat check right below it), then checks for an
///        ordinary threatened building and hands off to "defending" if one
///        exists (see AI_DetectThreat). Otherwise spends affordable
///        blueprints (AI_TryPlaceBlueprints, composition-aware -- replacing
///        a depleted/missing resource producer takes priority) and queues
///        training (AI_TryTrainComposition, weighted toward under-
///        represented tags) -- then gathers every AVAILABLE unit
///        (AI_GatherAvailableUnits) and, once their combined AI_ArmyPower
///        reaches AI_SiegePowerThreshold(), commits all of them to "siege"
///        against the enemy castle.
/// @param {Struct.AIBrain} _brain
/// @param {Struct.StateMachine} _machine
function AI_BuildUp_Step(_brain, _machine) {
    if (AI_CastleUnderThreat(_brain.team)) {
        _machine.ChangeState("castle_defense");
        return;
    }

    if (AI_DetectThreat(_brain.team) != noone) {
        _machine.ChangeState("defending");
        return;
    }

    AI_TryPlaceBlueprints(_brain.team);
    AI_TryTrainComposition(_brain.team);

    var _available = AI_GatherAvailableUnits(_brain.team);
    if (array_length(_available) > 0 && AI_ArmyPower(_available) >= AI_SiegePowerThreshold()) {
        IssueOrderToUnits("siege", _available);
    }
}

/// @function AI_Defending_Step(_brain, _machine)
/// @description AI onStep for "defending" -- entered from "build_up" the
///        instant AI_DetectThreat finds an owned building with an enemy
///        unit nearby. Every think tick while here: checks the AI's OWN
///        castle first and escalates to "castle_defense" if it comes under
///        attack too (same priority ordering as AI_BuildUp_Step -- the
///        castle always outranks an ordinary building), then re-checks the
///        building threat (reverting to "build_up" the moment nothing's
///        threatened anymore) and, while one persists, sends every
///        currently AVAILABLE unit (AI_GatherAvailableUnits) to "defend"
///        the threatened building -- reusing the existing player-facing
///        "defend" order/state unchanged, so responders patrol it and
///        auto-engage anything that wanders into their attackAggroRadius
///        (Defend_Step's existing proximity-aggro check,
///        UnitStateDefend.gml) with zero new combat logic needed.
///        Economy/training pause while defending (does not call
///        AI_TryPlaceBlueprints/AI_TryTrainComposition) -- a deliberate
///        scope choice, not an oversight; flag if the AI should keep
///        building through a skirmish instead.
/// @param {Struct.AIBrain} _brain
/// @param {Struct.StateMachine} _machine
function AI_Defending_Step(_brain, _machine) {
    if (AI_CastleUnderThreat(_brain.team)) {
        _machine.ChangeState("castle_defense");
        return;
    }

    var _threatenedBuilding = AI_DetectThreat(_brain.team);
    if (_threatenedBuilding == noone) {
        _machine.ChangeState("build_up");
        return;
    }

    var _available = AI_GatherAvailableUnits(_brain.team);
    if (array_length(_available) > 0) {
        IssueOrderToUnits("defend", _available, _threatenedBuilding);
    }
}

/// @function AI_CastleDefense_Step(_brain, _machine)
/// @description AI onStep for "castle_defense" -- the AI's HIGHEST priority
///        posture, added 2026-07-06 per explicit request: "if it is under
///        siege, top priority should be to defeat enemies attacking the
///        castle." Entered from either "build_up" or "defending" the
///        instant AI_CastleUnderThreat is true, checked ahead of everything
///        else in both those states. Losing the castle loses the match
///        outright, so this recalls units the other two postures
///        deliberately leave alone: every unit currently in "guard",
///        "defend", OR "siege" -- including a siege already committed
///        against the ENEMY castle -- is redirected to "defend" the home
///        castle instead. This is the one behavior change from the prior
///        pass's explicitly-flagged scope boundary ("deliberately does NOT
///        recall units already mid-siege"); recalling an in-progress siege
///        is now intentional; the AI will happily abandon an attack on the
///        enemy castle to save its own. Units already actively fighting
///        (combat/combatRanged/attack/attackRanged) are left alone --
///        pulling a unit out of a live engagement to redirect it elsewhere
///        tends to just get it killed mid-retreat rather than help; letting
///        it finish/lose that fight and naturally fall back to guard/defend
///        is safer, and the next think tick will catch it. Redirected units
///        get CastleDefendWaypoints (CastleScripts.gml), NOT
///        DefendBuildingWaypoints -- see Defend_Enter (UnitStateDefend.gml)
///        for the castle-vs-building branch this depends on. Reverts to
///        "build_up" the instant the castle is clear again; if an ordinary
///        building is still threatened at that point, "build_up" will
///        notice on its own very next think tick and hand off to
///        "defending" -- no special fallthrough needed here.
/// @param {Struct.AIBrain} _brain
/// @param {Struct.StateMachine} _machine
function AI_CastleDefense_Step(_brain, _machine) {
    if (!AI_CastleUnderThreat(_brain.team)) {
        _machine.ChangeState("build_up");
        return;
    }

    var _castle = GetTeamCastle(_brain.team);
    if (!instance_exists(_castle)) return; // shouldn't happen if AI_CastleUnderThreat was true -- stay safe anyway

    var _units    = GatherTeamUnits(_brain.team);
    var _recalled = [];
    for (var i = 0; i < array_length(_units); i++) {
        var _u = _units[i];
        if (_u.fsm.Is("guard") || _u.fsm.Is("defend") || _u.fsm.Is("siege")) {
            array_push(_recalled, _u);
        }
    }

    if (array_length(_recalled) > 0) {
        IssueOrderToUnits("defend", _recalled, _castle);
    }
}

// -----------------------------------------------------------
// AI perception -- threat detection + rough combat-power estimation.
// Both added 2026-07-06 alongside the "defending" state and the
// strength-based siege trigger above.
// -----------------------------------------------------------

/// @function AI_DetectThreat(_team)
/// @description Finds the first _team-owned building (oBuildingParent) with
///        an enemy oUnitParent within AI_THREAT_RADIUS of it,  or noone if
///        nothing's threatened. Deliberately building-scoped, not castle-
///        scoped: redirecting responders through the existing "defend"
///        order (UnitStateDefend.gml) only works cleanly against a real
///        48x48-ish oBuildingParent -- DefendBuildingWaypoints hardcodes
///        that box size (DEFEND_BUILDING_HALF). The castle is a completely
///        different size (see CastleFrontEdgePoint, CastleScripts.gml, and
///        the whole front-edge-targeting fix this same file needed for
///        siege) -- reusing "defend" against it directly would resurrect
///        that exact size-mismatch bug, which is why AI_CastleUnderThreat/
///        AI_CastleDefense_Step (below) are a separate castle-scoped path
///        rather than folded into this function -- CastleDefendWaypoints
///        (CastleScripts.gml) solves the size mismatch for that path
///        specifically, but this one stays building-only on purpose.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Id.Instance|Constant.NoOne} The threatened building, or noone.
function AI_DetectThreat(_team) {
    var _found = noone;
    with (oBuildingParent) {
        if (team == _team) {
            var _list  = ds_list_create();
            var _count = collision_circle_list(x, y, AI_THREAT_RADIUS, oUnitParent, false, true, _list, false);

            var _threatened = false;
            for (var i = 0; i < _count; i++) {
                if (_list[| i].team != _team) {
                    _threatened = true;
                    break;
                }
            }
            ds_list_destroy(_list);

            if (_threatened) {
                _found = id;
                break;
            }
        }
    }
    return _found;
}

/// @function AI_CastleUnderThreat(_team)
/// @description True if any enemy oUnitParent is within
///        AI_CASTLE_THREAT_RADIUS of _team's OWN castle (GetTeamCastle,
///        GatherScripts.gml). Added 2026-07-06, the castle-scoped
///        counterpart to AI_DetectThreat (which deliberately only watches
///        ordinary oBuildingParent buildings, never the castle -- see that
///        function's header for why). Checked FIRST, ahead of
///        AI_DetectThreat, in both "build_up" and "defending" -- losing the
///        castle loses the match outright, so nothing else the AI could be
///        doing outranks defending it.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Bool}
function AI_CastleUnderThreat(_team) {
    var _castle = GetTeamCastle(_team);
    if (!instance_exists(_castle)) return false;

    var _list  = ds_list_create();
    var _count = collision_circle_list(_castle.x, _castle.y, AI_CASTLE_THREAT_RADIUS, oUnitParent, false, true, _list, false);

    var _threatened = false;
    for (var i = 0; i < _count; i++) {
        if (_list[| i].team != _team) {
            _threatened = true;
            break;
        }
    }
    ds_list_destroy(_list);
    return _threatened;
}

/// @function AI_UnitPowerScore(_unit)
/// @description Rough single-unit combat-power estimate: current HP and
///        attackDamage, weighted and summed. Placeholder weights
///        (AI_POWER_HEALTH_WEIGHT/AI_POWER_DAMAGE_WEIGHT) -- not a balanced
///        formula, just enough to stop the AI from treating a fresh
///        peasant and a fresh mud golem as equally "one unit" toward a
///        siege decision. Doesn't account for attackRange, attackCooldownMax,
///        ranged vs melee, or any tag -- tune/extend freely.
/// @param {Id.Instance} _unit
/// @returns {Real}
function AI_UnitPowerScore(_unit) {
    return (GetCurrentHealth(_unit) * AI_POWER_HEALTH_WEIGHT) + (_unit.attackDamage * AI_POWER_DAMAGE_WEIGHT);
}

/// @function AI_ArmyPower(_units)
/// @description Sum of AI_UnitPowerScore across every unit in _units.
/// @param {Array<Id.Instance>} _units
/// @returns {Real}
function AI_ArmyPower(_units) {
    var _total = 0;
    for (var i = 0; i < array_length(_units); i++) {
        _total += AI_UnitPowerScore(_units[i]);
    }
    return _total;
}

/// @function AI_SiegePowerThreshold()
/// @description The AI_ArmyPower an available force must reach before
///        AI_BuildUp_Step commits it to "siege" -- AI_SIEGE_POWER_FRACTION
///        of CASTLE_MAX_HEALTH (CastleScripts.gml). Both the fraction and
///        CASTLE_MAX_HEALTH itself (500) are explicitly-flagged placeholders
///        elsewhere already -- this inherits that same "not balanced yet"
///        status, just gives the AI SOME sense of scale instead of a flat
///        headcount that ignores castle HP entirely.
/// @returns {Real}
function AI_SiegePowerThreshold() {
    return CASTLE_MAX_HEALTH * AI_SIEGE_POWER_FRACTION;
}

// -----------------------------------------------------------
// AI economy -- building placement + training. Reuses the exact same
// underlying functions the player's UI calls (TryPlaceBlueprint,
// TrainingTryQueueUnit) so AI-built structures and AI-trained units go
// through identical cost/limit/analytics handling as the player's.
//
// Both were originally "deliberately greedy/simple" (spend whatever's
// affordable, train at every building, no priority at all) -- reworked
// 2026-07-06 to prioritize replacing a missing/depleted resource producer
// (AI_MissingResourceProducers) ahead of anything else, and to weight
// training toward under-represented unit tags (AI_ArmyTagFraction)
// instead of "first building checked wins." Both still fall back to the
// old greedy behavior once their respective priority is satisfied, so
// affordable spend never just sits idle.
// -----------------------------------------------------------

/// @function AI_FindEmptyOwnedPlot(_team)
/// @description First unblocked, unoccupied oBuildingPlot belonging to
///        _team, or noone -- excludes both meta-progression-locked slots
///        (blocked, see oPlotSpawner/Create_0.gml) and slots that already
///        have a building on them (occupied, TryPlaceBlueprint,
///        BlueprintScripts.gml). No inside/outside preference -- STILL
///        true as of 2026-07-07, but the reason changed: the placement
///        bonus split oOuterPlotSpawner's header comment describes
///        (resource buildings outside, training buildings inside, extra
///        stat bonus on Distant/"far" plots) is now REAL (see
///        GetPlacementCost, BlueprintScripts.gml, and ApplyPlotBonuses,
///        BuildingDefinitions.gml) -- this function just doesn't take
///        advantage of it yet. The AI will happily place a training
///        building on an Exterior plot at full price when a discounted
///        Castle plot sits empty, and never seeks out Distant plots for
///        their maxHealth/resourceLimit bonus. Flagging as a real
///        (if minor) AI inefficiency, not fixing here -- out of scope for
///        the "set up those bonuses" request this comment was updated for.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Id.Instance|Constant.NoOne}
function AI_FindEmptyOwnedPlot(_team) {
    var _found = noone;
    with (oBuildingPlot) {
        if (team == _team && !blocked && !occupied) {
            _found = id;
            break;
        }
    }
    return _found;
}

/// @function AI_MissingResourceProducers(_team)
/// @description Which of the 5 producible tier-1 resources (wheat/water/
///        wood/gold/iron) _team currently has ZERO live
///        oResourceBuildingParent actively producing. Resource buildings
///        self-destroy on hitting their lifetime resourceLimit
///        (BuildingUpdateProduction, BuildingDefinitions.gml) and nothing
///        replaces them automatically -- this is what lets
///        AI_TryPlaceBlueprints notice and prioritize a replacement.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Array<String>}
function AI_MissingResourceProducers(_team) {
    var _resourceTypes = ["wheat", "water", "wood", "gold", "iron"]; // the 5 resources with a tier-1 producer building today
    var _present = [];

    with (oResourceBuildingParent) {
        if (team == _team && productionResource != undefined && !array_contains(_present, productionResource)) {
            array_push(_present, productionResource);
        }
    }

    var _missing = [];
    for (var i = 0; i < array_length(_resourceTypes); i++) {
        if (!array_contains(_present, _resourceTypes[i])) {
            array_push(_missing, _resourceTypes[i]);
        }
    }
    return _missing;
}

/// @function AI_TryPlaceBlueprints(_team)
/// @description Attempts to place blueprints _team owns onto empty owned
///        plots, via TryPlaceBlueprint (BlueprintScripts.gml) -- the same
///        placement logic BlueprintController.EndDrag uses for the
///        player's mouse-drag flow, just called directly with a plot the
///        AI picked itself instead of one resolved from the cursor.
///
///        Pass 1: if AI_MissingResourceProducers says _team has zero live
///        producers for some resource, any held blueprint that produces
///        one of those resources gets first claim on this tick's
///        affordability. Pass 2: every remaining affordable blueprint,
///        same greedy "spend whatever's affordable" behavior as before --
///        so gold doesn't sit idle once every resource is covered.
///
///        Both passes iterate global.blueprints[_team] BACKWARDS
///        deliberately: a successful placement calls RemoveBlueprintOne,
///        which can delete the stack it just consumed (array_delete) --
///        iterating from the end means that deletion only ever shifts
///        indices this loop has already visited, never ones still to come.
/// @param {Real} _team
function AI_TryPlaceBlueprints(_team) {
    var _stacks  = global.blueprints[_team];
    var _missing = AI_MissingResourceProducers(_team);

    if (array_length(_missing) > 0) {
        for (var i = array_length(_stacks) - 1; i >= 0; i--) {
            var _buildingType = _stacks[i].buildingType;
            var _def = GetBuildingDefinition(_buildingType);
            if (_def == undefined || _def.productionResource == undefined) continue;
            if (!array_contains(_missing, _def.productionResource))         continue;
            if (!_def.cost.CanAfford(_team))                                continue;

            var _plot = AI_FindEmptyOwnedPlot(_team);
            if (_plot == noone) continue;

            if (TryPlaceBlueprint(_team, _buildingType, _plot)) {
                _missing = AI_MissingResourceProducers(_team); // just filled one -- recheck before the next candidate
                if (array_length(_missing) == 0) break;
            }
        }
    }

    for (var i = array_length(_stacks) - 1; i >= 0; i--) {
        var _buildingType = _stacks[i].buildingType;
        var _def = GetBuildingDefinition(_buildingType);
        if (_def == undefined || !_def.cost.CanAfford(_team)) continue;

        var _plot = AI_FindEmptyOwnedPlot(_team);
        if (_plot == noone) continue;

        TryPlaceBlueprint(_team, _buildingType, _plot);
    }
}

/// @function AI_ArmyTagFraction(_team, _tag)
/// @description Fraction (0..1) of _team's CURRENT LIVE army (every unit,
///        any type) that carries _tag per its UnitDefinition. Live units
///        only -- deliberately doesn't count what's still queued/training
///        (unlike the hard caps in TrainingScripts.gml, which must count
///        queued units to avoid overshooting a limit). Composition
///        targeting here is a soft preference, not a hard cap, and using
///        only live counts means a big finished wave relaxes the
///        preference immediately instead of waiting on a queue that's
///        already committed to finish first.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {String} _tag
/// @returns {Real} 0 if the team has no units at all.
function AI_ArmyTagFraction(_team, _tag) {
    var _units = GatherTeamUnits(_team);
    var _total = array_length(_units);
    if (_total == 0) return 0;

    var _tagged = 0;
    for (var i = 0; i < _total; i++) {
        if (UnitHasTag(_units[i], _tag)) _tagged++;
    }
    return _tagged / _total;
}

/// @function AI_TryTrainComposition(_team)
/// @description Composition-aware replacement for the old "queue at every
///        owned training building, every tick, no preference." Still calls
///        TrainingTryQueueUnit (TrainingScripts.gml) for the real
///        cost/cap/affordability work -- this only decides which buildings
///        get first crack at this tick's budget. Checks AI_ArmyTagFraction
///        for "tank" then "ranged" against AI_TANK_TARGET_RATIO/
///        AI_RANGED_TARGET_RATIO; whichever is furthest under target (tank
///        checked first) becomes _wantTag, and every owned building that
///        trains a _wantTag-tagged unit is attempted first. Every OTHER
///        owned training building (not already attempted above) is then
///        attempted too, so affordable training never sits idle once
///        composition goals are met, or for buildings training an untagged
///        unit entirely.
/// @param {Real} _team
function AI_TryTrainComposition(_team) {
    var _wantTag = undefined;
    if (AI_ArmyTagFraction(_team, "tank") < AI_TANK_TARGET_RATIO) {
        _wantTag = "tank";
    } else if (AI_ArmyTagFraction(_team, "ranged") < AI_RANGED_TARGET_RATIO) {
        _wantTag = "ranged";
    }

    var _attempted = [];
    if (_wantTag != undefined) {
        with (oTrainingBuildingParent) {
            if (team == _team && trainsUnit != undefined) {
                var _def = GetUnitDefinition(trainsUnit);
                if (_def != undefined && array_contains(_def.tags, _wantTag)) {
                    TrainingTryQueueUnit(id);
                    array_push(_attempted, id);
                }
            }
        }
    }

    with (oTrainingBuildingParent) {
        if (team == _team && !array_contains(_attempted, id)) {
            TrainingTryQueueUnit(id);
        }
    }
}
