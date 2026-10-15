// AI decision-making -- AIBrain per computer team, posture state machine
// (build_up/defending/castle_defense), and supporting perception/economy/
// stationing/debug helpers. See AIControl.md.

#macro AI_THINK_INTERVAL    45   // frames between AI decisions (~0.75s at 60fps)
#macro AI_THREAT_RADIUS     250  // enemy-proximity radius that flags an owned building as threatened
#macro AI_CASTLE_THREAT_RADIUS 300 // same, for the AI's own castle -- larger since the castle itself is much bigger than an ordinary building
#macro AI_SIEGE_POWER_FRACTION 0.6 // fraction of CASTLE_MAX_HEALTH an available force's AI_ArmyPower must reach before committing to siege
#macro AI_POWER_HEALTH_WEIGHT 0.4 // AI_UnitPowerScore weight on current HP
#macro AI_POWER_DAMAGE_WEIGHT 5   // AI_UnitPowerScore weight on attackDamage
#macro AI_TANK_TARGET_RATIO   0.25 // AI_TryTrainComposition: desired minimum fraction of live army carrying "tank"
#macro AI_RANGED_TARGET_RATIO 0.25 // same, for "ranged"

#macro AI_STATION_MAX_STATIONED     6 // AI_TryStationUnits won't station more than this many total at once
#macro AI_STATION_MIN_GUARD_RESERVE 3 // AI_TryStationUnits won't drop the team's guard count below this
#macro AI_STATION_ATTEMPTS_PER_TICK 1 // AI_TryStationUnits stations at most this many per think tick

#macro AI_MIN_DEFENSIVE_ARMY_FRACTION 0.25 // floor on how much of the team's total army must stay in guard/defend/station -- see AI_MinDefensiveReserve
#macro AI_DEFEND_ENGAGE_RADIUS      120  // px: an enemy this close to a building means it is actually being attacked (vs. merely inside AI_THREAT_RADIUS of it) -- see AI_BuildingsEngagedByEnemy
#macro AI_DEFEND_TIER_WEIGHT        200  // px-equivalent penalty per plot tier when AI_Defending_Step picks which threatened building a unit reinforces
#macro AI_SPREAD_ATTEMPTS_PER_TICK  1    // AI_TryMaintainDefensiveSpread posts at most this many new defenders per think tick
#macro AI_PROBE_WINDOW_FRAMES       3600 // ~60s -- "early game" window during which AI_TryProbeAttack can fire at all
#macro AI_PROBE_INTERVAL_FRAMES     900  // ~15s -- minimum gap between successful probes within that window
#macro AI_PROBE_ATTACK_SIZE         2    // units sent per probe

#macro AI_SIEGE_POWER_FRACTION_AT_CAP 0.15 // AI_SiegePowerThreshold uses this instead of AI_SIEGE_POWER_FRACTION once AI_TeamAtArmyLimit is true
#macro AI_STATION_MIN_GUARD_RESERVE_AT_CAP 1 // AI_TryStationUnits' reserve floor once AI_TeamAtArmyLimit is true
#macro AI_STATION_FAVOR_POWER_CEILING 20 // AI_UnitFavorsStationing's flat cutoff on AI_UnitDefPowerScore -- see .md for which unit types clear it
#macro AI_GOLD_RESERVE_UNIT_COUNT 2 // AI_GoldReserveAmount reserves enough gold to redeploy this many stationed units at the cheapest registered stationCost

#macro AI_HESITANCY_DELAY_TICKS 15 // decision attempts skipped before one goes through -- 2026-08-16 follow-up, halved from 30 ("half all AI hesitancy") -- see .md for the skip-rate derivation

/// @function AIBrain(_team)
/// @description Top-level decision-maker for a computer-controlled team. Call Step() once per Step event. Owns a StateMachine over "build_up"/"defending"/"castle_defense" and dispatches through IssueOrderToUnits, the same path SelectionController uses. See .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY -- which side this brain plays.
function AIBrain(_team) constructor {
    team       = _team;
    thinkTimer = AI_THINK_INTERVAL;

    age           = 0;
    probeCooldown = 0;

    hesitancy = AI_HESITANCY_DELAY_TICKS * 1.5; // 2026-08-14: halved from x3 -- starts at 1.5x the reset value -- see .md

    fsm = new StateMachine(self);
    fsm.AddState("build_up",      new State(undefined, AI_BuildUp_Step,       undefined, undefined))
       .AddState("defending",     new State(undefined, AI_Defending_Step,     undefined, undefined))
       .AddState("castle_defense", new State(undefined, AI_CastleDefense_Step, undefined, undefined));
    fsm.ChangeState("build_up");

    /// @function Step()
    /// @description Ticks the think timer and, on expiry, runs one decision cycle through the AI's StateMachine. Includes an every-frame urgency interrupt that zeroes thinkTimer when under threat. See .md.
    /// @returns {Struct.AIBrain} self
    static Step = function() {
        if (global.tutorialActive) return self; // guided tutorial -- enemy fully paused, including its own internal clocks, see .md

        age += global.matchSpeed;
        if (probeCooldown > 0) probeCooldown -= global.matchSpeed;

        var _underThreat = AI_CastleUnderThreat(team) || (AI_DetectThreat(team) != noone);
        if (_underThreat && !fsm.Is("defending") && !fsm.Is("castle_defense")) {
            thinkTimer = 0;
        }

        thinkTimer -= global.matchSpeed;
        if (thinkTimer <= 0) {
            thinkTimer = AI_THINK_INTERVAL;
            fsm.Step();
        }
        return self;
    }
}

/// @function AI_GatherAvailableUnits(_team)
/// @description Every _team unit this think-cycle is free to redirect -- "guard" OR "defend" (both are uncommitted; see .md re: why "defend" must be included).
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

// ----- AI defensive posture -----

#macro AI_PLOT_TIER_REAR  0 // inside castle walls -- oBuildingPlot.inside
#macro AI_PLOT_TIER_MID   1 // near exterior plots -- !inside && !far
#macro AI_PLOT_TIER_FRONT 2 // far/exposed exterior plots -- oBuildingPlot.far

/// @function AI_BuildingPlotTier(_building)
/// @description Which defensive tier _building's plot falls into, derived from oBuildingPlot.inside/far. See .md.
/// @param {Id.Instance} _building An oBuildingParent instance.
/// @returns {Real} AI_PLOT_TIER_REAR/_MID/_FRONT. Defaults to _MID if no plot is found.
function AI_BuildingPlotTier(_building) {
    var _plot = instance_position(_building.x, _building.y, oBuildingPlot);
    if (_plot == noone) return AI_PLOT_TIER_MID;
    if (_plot.inside) return AI_PLOT_TIER_REAR;
    if (_plot.far) return AI_PLOT_TIER_FRONT;
    return AI_PLOT_TIER_MID;
}

/// @function AI_PartitionByPosture(_units)
/// @description Splits _units (expected: AI_GatherAvailableUnits' output) into guard/defend by current FSM state.
/// @param {Array<Id.Instance>} _units
/// @returns {Struct} { guard: Array<Id.Instance>, defend: Array<Id.Instance> }
function AI_PartitionByPosture(_units) {
    var _guard  = [];
    var _defend = [];
    for (var i = 0; i < array_length(_units); i++) {
        if (_units[i].fsm.Is("guard")) {
            array_push(_guard, _units[i]);
        } else if (_units[i].fsm.Is("defend")) {
            array_push(_defend, _units[i]);
        }
    }
    return { guard: _guard, defend: _defend };
}

/// @function AI_MinDefensiveReserve(_team)
/// @description How many units -- out of _team's TOTAL army (live + stationed) -- must stay in guard/defend/station at any given time. See .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Real} Rounded up.
function AI_MinDefensiveReserve(_team) {
    var _totalArmy = array_length(GatherTeamUnits(_team)) + AI_CurrentStationedCount(_team);
    return ceil(_totalArmy * AI_MIN_DEFENSIVE_ARMY_FRACTION);
}

/// @function AI_ReserveDefensiveUnits(_units, _reserveCount)
/// @description Splits _units (guard+defend) into reserved (kept back) and returns the SURPLUS, eligible for siege/probe. Reserves "defend" units first. See .md.
/// @param {Array<Id.Instance>} _units
/// @param {Real} _reserveCount
/// @returns {Array<Id.Instance>} The surplus, NOT the reserved units.
function AI_ReserveDefensiveUnits(_units, _reserveCount) {
    var _split  = AI_PartitionByPosture(_units);
    var _defend = _split.defend;
    var _guard  = _split.guard;

    var _reserved = [];

    var _defendReserve = min(_reserveCount, array_length(_defend));
    for (var i = 0; i < _defendReserve; i++) array_push(_reserved, _defend[i]);

    var _stillNeeded  = _reserveCount - _defendReserve;
    var _guardReserve = min(max(_stillNeeded, 0), array_length(_guard));
    for (var i = 0; i < _guardReserve; i++) array_push(_reserved, _guard[i]);

    var _surplus = [];
    for (var i = 0; i < array_length(_units); i++) {
        if (!array_contains(_reserved, _units[i])) array_push(_surplus, _units[i]);
    }
    return _surplus;
}

/// @function AI_UncoveredBuildingsByTier(_team)
/// @description Every _team-owned, placed building with ZERO live "defend" units posted to it, bucketed by AI_BuildingPlotTier, REAR-first. During Age I, training buildings are excluded from this PROACTIVE-coverage list only. See .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Array<Id.Instance>}
function AI_UncoveredBuildingsByTier(_team) {
    var _byTier = [[], [], []]; // index = AI_PLOT_TIER_*

    var _skipTraining = (global.age[_team] == 1);

    with (oBuildingParent) {
        if (team != _team) continue;
        if (_skipTraining && object_is_ancestor(object_index, oTrainingBuildingParent)) continue;
        array_push(_byTier[AI_BuildingPlotTier(id)], id);
    }

    var _defended = [];
    with (oUnitParent) {
        if (team == _team && fsm.Is("defend") && instance_exists(defendTarget)) {
            array_push(_defended, defendTarget);
        }
    }

    var _uncovered = [];
    for (var t = 0; t < array_length(_byTier); t++) {
        for (var i = 0; i < array_length(_byTier[t]); i++) {
            if (!array_contains(_defended, _byTier[t][i])) {
                array_push(_uncovered, _byTier[t][i]);
            }
        }
    }
    return _uncovered;
}

/// @function AI_TryMaintainDefensiveSpread(_team)
/// @description Proactively posts idle "guard" units to "defend" whichever owned building has zero defenders, REAR-tier first. Only pulls from "guard". See .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
function AI_TryMaintainDefensiveSpread(_team) {
    var _uncovered = AI_UncoveredBuildingsByTier(_team);
    if (array_length(_uncovered) == 0) return;

    var _guards = [];
    with (oUnitParent) {
        if (team == _team && fsm.Is("guard")) array_push(_guards, id);
    }
    if (array_length(_guards) == 0) return;

    var _attempts = min(AI_SPREAD_ATTEMPTS_PER_TICK, min(array_length(_uncovered), array_length(_guards)));
    for (var i = 0; i < _attempts; i++) {
        IssueOrderToUnits("defend", [_guards[i]], _uncovered[i]);
    }
}

/// @function AI_BuildUp_Step(_brain, _machine)
/// @description AI onStep for "build_up" -- default economy/training/massing posture. Priority order: castle threat -> building threat -> hesitancy-gated blueprints/training -> defensive spread -> stationing -> probe -> cap-surplus attack -> siege. See .md.
/// @param {Struct.AIBrain} _brain
/// @param {Struct.StateMachine} _machine
function AI_BuildUp_Step(_brain, _machine) {
    if (AI_CastleUnderThreat(_brain.team)) {
        _machine.ChangeState("castle_defense");
        return;
    }

    // 2026-08-16 follow-up ("do not switch AI state to defending buildings if there is no unit training
    // structures... cannot defend itself if it has no buildings") -- AI_TeamHasTrainingStructures added
    // as a second condition. Without this, a team that's lost every oTrainingBuildingParent instance
    // could still flip into "defending" over a threatened non-training building, then (per
    // AI_Defending_Step) fall into AI_TryReinforceDefense once it runs out of live units -- which tries
    // to queue training with nothing left to train from.
    // 2026-08-16 follow-up (round 2, "allow for defending with units in hand without training
    // buildings") -- OR'd with AI_TeamHasUnitsInHand: a team with no training buildings but units
    // already deployed or stationed clearly CAN defend itself, so it's only blocked from "defending"
    // when it has NEITHER a way to produce more units NOR any units to respond with right now. See .md.
    if (AI_DetectThreat(_brain.team) != noone && (AI_TeamHasTrainingStructures(_brain.team) || AI_TeamHasUnitsInHand(_brain.team))) {
        _machine.ChangeState("defending");
        return;
    }

    // Hesitancy delays only this block (placement + training) -- see .md.
    // Gated here rather than inside AI_TryTrainComposition because that
    // function's second call site (AI_TryReinforceDefense) must stay
    // un-delayed.
    if (_brain.hesitancy > 0) {
        _brain.hesitancy -= 1;
    } else {
        var _hiddenGold = AI_HideGoldReserve(_brain.team);
        AI_TryPlaceBlueprints(_brain.team);
        AI_TryTrainComposition(_brain.team);
        AI_RestoreGoldReserve(_brain.team, _hiddenGold);

        _brain.hesitancy = AI_HESITANCY_DELAY_TICKS;
    }

    AI_TryMaintainDefensiveSpread(_brain.team);
    AI_TryStationUnits(_brain.team);

    var _available     = AI_GatherAvailableUnits(_brain.team);
    var _reserveNeeded = max(0, AI_MinDefensiveReserve(_brain.team) - AI_CurrentStationedCount(_brain.team));
    var _surplus       = AI_ReserveDefensiveUnits(_available, _reserveNeeded);

    _surplus = AI_TryProbeAttack(_brain, _surplus);
    _surplus = AI_TryAttackSurplusAtCap(_brain, _surplus);

    if (array_length(_surplus) > 0 && AI_ArmyPower(_surplus) >= AI_SiegePowerThreshold(_brain.team)) {
        IssueOrderToUnits("siege", _surplus);
    }
}

/// @function AI_BuildingsEngagedByEnemy(_team, _buildings)
/// @description The subset of _buildings with an enemy unit within AI_DEFEND_ENGAGE_RADIUS (much tighter than AI_THREAT_RADIUS).
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Array<Id.Instance>} _buildings Buildings already flagged by AI_DetectThreats.
/// @returns {Array<Id.Instance>}
function AI_BuildingsEngagedByEnemy(_team, _buildings) {
    var _engaged = [];
    for (var b = 0; b < array_length(_buildings); b++) {
        var _bld   = _buildings[b];
        var _list  = ds_list_create();
        var _count = collision_circle_list(_bld.x, _bld.y, AI_DEFEND_ENGAGE_RADIUS, oUnitParent, false, true, _list, false);
        for (var i = 0; i < _count; i++) {
            if (_list[| i].team != _team) {
                array_push(_engaged, _bld);
                break;
            }
        }
        ds_list_destroy(_list);
    }
    return _engaged;
}

/// @function AI_Defending_Step(_brain, _machine)
/// @description AI onStep for "defending" -- reactive response to threatened buildings. Distributes available units across every threatened building by nearest-with-tier-penalty score. Pauses economy/training except AI_TryReinforceDefense when the team has zero live units. See .md.
/// @param {Struct.AIBrain} _brain
/// @param {Struct.StateMachine} _machine
function AI_Defending_Step(_brain, _machine) {
    if (AI_CastleUnderThreat(_brain.team)) {
        _machine.ChangeState("castle_defense");
        return;
    }

    var _threatened = AI_DetectThreats(_brain.team);
    if (array_length(_threatened) == 0) {
        _machine.ChangeState("build_up");
        return;
    }

    // 2026-10-15: narrow to buildings an enemy is actually on top of, so responders aren't pulled to
    // neighbors that are only inside the wide threat radius -- see .md.
    var _engaged = AI_BuildingsEngagedByEnemy(_brain.team, _threatened);
    if (array_length(_engaged) > 0) _threatened = _engaged;

    if (array_length(GatherTeamUnits(_brain.team)) == 0) {
        AI_TryReinforceDefense(_brain.team);
    }

    var _available = AI_GatherAvailableUnits(_brain.team);
    if (array_length(_available) == 0) return;

    // Grouped into one IssueOrderToUnits call PER building so "defend" only
    // re-evaluates DefendBuildingWaypoints once per building this tick.
    var _groups = array_create(array_length(_threatened));
    for (var i = 0; i < array_length(_groups); i++) _groups[i] = [];

    var _tierPenalty = array_create(array_length(_threatened));
    for (var j = 0; j < array_length(_threatened); j++) {
        _tierPenalty[j] = AI_BuildingPlotTier(_threatened[j]) * AI_DEFEND_TIER_WEIGHT;
    }

    for (var i = 0; i < array_length(_available); i++) {
        var _unit      = _available[i];
        var _bestIndex = 0;
        var _bestScore = infinity;
        for (var j = 0; j < array_length(_threatened); j++) {
            var _score = point_distance(_unit.x, _unit.y, _threatened[j].x, _threatened[j].y) + _tierPenalty[j];
            if (_score < _bestScore) {
                _bestScore = _score;
                _bestIndex = j;
            }
        }
        array_push(_groups[_bestIndex], _unit);
    }

    for (var i = 0; i < array_length(_threatened); i++) {
        if (array_length(_groups[i]) > 0) {
            IssueOrderToUnits("defend", _groups[i], _threatened[i]);
        }
    }
}

#macro AI_REINFORCE_MAX_DEPLOYS 20 // safety cap on un-garrisons per tick in AI_TryReinforceDefense -- not a real gameplay number, just a runaway-loop guard

/// @function AI_FirstStationedType(_team)
/// @description The unitType of ANY one currently-stationed unit belonging to _team, or undefined if nothing's stationed. Iteration order isn't meaningful -- see .md.
/// @param {Real} _team
/// @returns {Asset.GMObject|Undefined}
function AI_FirstStationedType(_team) {
    var _found = undefined;
    with (oUnitStationed) {
        if (team == _team) {
            _found = unitData.unitType;
            break;
        }
    }
    return _found;
}

/// @function AI_TryReinforceDefense(_team)
/// @description Called from AI_Defending_Step when _team has zero live units. Un-garrisons every affordable stationed unit (up to AI_REINFORCE_MAX_DEPLOYS) and queues training via AI_TryTrainComposition, both un-gated by the gold reserve. See .md.
/// @param {Real} _team
function AI_TryReinforceDefense(_team) {
    var _deploys = 0;
    while (_deploys < AI_REINFORCE_MAX_DEPLOYS) {
        var _type = AI_FirstStationedType(_team);
        if (_type == undefined) break; // nothing left stationed
        if (!DeployStationedUnit(_team, _type)) break; // can't afford another -- stop rather than spin
        _deploys++;
    }

    AI_TryTrainComposition(_team);
}

/// @function AI_CastleDefense_Step(_brain, _machine)
/// @description AI onStep for "castle_defense" -- highest priority posture. Recalls every unit in guard/defend/siege (including a siege already committed against the enemy castle) to defend the home castle. Units already actively fighting are left alone. See .md.
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

// ----- AI perception -----

/// @function AI_DetectThreat(_team)
/// @description First _team-owned building with an enemy unit within AI_THREAT_RADIUS, or noone. Deliberately building-scoped, not castle-scoped -- see .md.
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

/// @function AI_DetectThreats(_team)
/// @description Plural counterpart to AI_DetectThreat -- every currently threatened _team-owned building, not just the first. See .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Array<Id.Instance>}
function AI_DetectThreats(_team) {
    var _found = [];
    with (oBuildingParent) {
        if (team != _team) continue;

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

        if (_threatened) array_push(_found, id);
    }
    return _found;
}

/// @function AI_CastleUnderThreat(_team)
/// @description True if any enemy unit is within AI_CASTLE_THREAT_RADIUS of _team's own castle. Checked first, ahead of AI_DetectThreat, in both build_up and defending.
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
/// @description Rough single-unit combat-power estimate: current HP and attackDamage, weighted and summed. Placeholder weights -- doesn't account for range, cooldown, melee vs ranged, or tags.
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

/// @function AI_TeamAtArmyLimit(_team)
/// @description True once _team's live + stationed + queued unit count has reached global.armyLimit[_team] -- the same saturation check TrainingTryQueueUnit uses. See .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Bool}
function AI_TeamAtArmyLimit(_team) {
    var _existing = array_length(GatherTeamUnits(_team)) + CountTeamStationedUnits(_team);
    var _queued   = TrainingQueuedCountAll(_team);
    return (_existing + _queued) >= global.armyLimit[_team];
}

/// @function AI_SiegePowerThreshold(_team)
/// @description The AI_ArmyPower an available force must reach before AI_BuildUp_Step commits it to "siege" -- drops to AI_SIEGE_POWER_FRACTION_AT_CAP once AI_TeamAtArmyLimit is true. See .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Real}
function AI_SiegePowerThreshold(_team) {
    var _fraction = AI_TeamAtArmyLimit(_team) ? AI_SIEGE_POWER_FRACTION_AT_CAP : AI_SIEGE_POWER_FRACTION;
    return CASTLE_MAX_HEALTH * _fraction;
}

// ----- AI economy -----

/// @function AI_CheapestStationCost()
/// @description The lowest UnitDefinition.stationCost across every registered unit type. Sizes the gold reserve floor. See .md.
/// @returns {Real} 0 if no unit types are registered (shouldn't happen).
function AI_CheapestStationCost() {
    var _types    = ds_map_keys_to_array(global.__unitDefRegistry);
    var _cheapest = infinity;
    for (var i = 0; i < array_length(_types); i++) {
        var _def = GetUnitDefinition(_types[i]);
        if (_def != undefined && _def.stationCost < _cheapest) _cheapest = _def.stationCost;
    }
    return (_cheapest == infinity) ? 0 : _cheapest;
}

/// @function AI_GoldReserveAmount(_team)
/// @description How much gold AI_BuildUp_Step's economy spending must leave untouched -- sized to cover redeploying AI_GOLD_RESERVE_UNIT_COUNT stationed units. See .md.
/// @param {Real} _team
/// @returns {Real}
function AI_GoldReserveAmount(_team) {
    return AI_GOLD_RESERVE_UNIT_COUNT * AI_CheapestStationCost();
}

/// @function AI_HideGoldReserve(_team)
/// @description Temporarily removes AI_GoldReserveAmount's worth of gold from _team's visible resources (clamped at 0). Must be paired with AI_RestoreGoldReserve using this call's return value in the same think tick. See .md.
/// @param {Real} _team
/// @returns {Real} The amount actually hidden -- pass this straight to AI_RestoreGoldReserve.
function AI_HideGoldReserve(_team) {
    var _reserve = AI_GoldReserveAmount(_team);
    var _hidden  = min(_reserve, global.resources[_team].gold);
    global.resources[_team].gold -= _hidden;
    return _hidden;
}

/// @function AI_RestoreGoldReserve(_team, _hiddenAmount)
/// @description Adds back exactly what the matching AI_HideGoldReserve call removed. Always succeeds.
/// @param {Real} _team
/// @param {Real} _hiddenAmount
function AI_RestoreGoldReserve(_team, _hiddenAmount) {
    global.resources[_team].gold += _hiddenAmount;
}

/// @function AI_FindEmptyOwnedPlot(_team, _preferInside)
/// @description First unblocked, unoccupied oBuildingPlot belonging to _team, or noone. Optional _preferInside does a first pass over inside-only plots. See .md re: known inside/outside preference gap.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Bool} [_preferInside] Defaults to false.
/// @returns {Id.Instance|Constant.NoOne}
function AI_FindEmptyOwnedPlot(_team, _preferInside = false) {
    if (_preferInside) {
        var _insideFound = noone;
        with (oBuildingPlot) {
            if (team == _team && !blocked && !occupied && inside) {
                _insideFound = id;
                break;
            }
        }
        if (_insideFound != noone) return _insideFound;
    }

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
/// @description Which of the 5 producible tier-1 resources (wheat/water/wood/gold/iron) _team currently has ZERO live oResourceBuildingParent actively producing.
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
/// @description Attempts to place AT MOST ONE blueprint _team owns onto an empty owned plot via TryPlaceBlueprint (2026-08-14: was unbounded -- placed every affordable stack in a single call). Pass 1 prioritizes replacing a missing resource producer; pass 2 (only reached if pass 1 placed nothing) is greedy "spend whatever's affordable first". Both iterate backwards since a successful placement can delete the stack, and both return immediately on the first successful placement. See .md.
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
                return; // 2026-08-14: one building per call -- see .md
            }
        }
    }

    for (var i = array_length(_stacks) - 1; i >= 0; i--) {
        var _buildingType = _stacks[i].buildingType;
        var _def = GetBuildingDefinition(_buildingType);
        if (_def == undefined || !_def.cost.CanAfford(_team)) continue;

        // A training building whose trained unit favors stationing seeks an
        // inside plot first -- see AI_FindEmptyOwnedPlot's doc comment.
        var _preferInside = false;
        if (_def.trainsUnit != undefined) {
            var _unitDef = GetUnitDefinition(_def.trainsUnit);
            _preferInside = (_unitDef != undefined) && AI_UnitFavorsStationing(_unitDef);
        }

        var _plot = AI_FindEmptyOwnedPlot(_team, _preferInside);
        if (_plot == noone) continue;

        if (TryPlaceBlueprint(_team, _buildingType, _plot)) {
            return; // 2026-08-14: one building per call -- see .md
        }
    }
}

/// @function AI_ArmyTagFraction(_team, _tag)
/// @description Fraction (0..1) of _team's CURRENT LIVE army carrying _tag per its UnitDefinition. Live units only -- see .md.
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
/// @description Composition-aware training: whichever of "tank"/"ranged" is furthest under its target ratio gets first crack at training this tick, then every other owned training building is attempted too. Still calls TrainingTryQueueUnit for the real cost/cap work. See .md.
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

// ----- AI stationing -----

/// @function AI_CurrentStationedCount(_team)
/// @description Total live oUnitStationed belonging to _team, any type. Thin wrapper around the shared CountTeamStationedUnits (StationScripts.gml).
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Real}
function AI_CurrentStationedCount(_team) {
    return CountTeamStationedUnits(_team);
}

/// @function AI_UnitStationedBonusValue(_def)
/// @description Sum of a unit type's stationedBonuses[].amount -- a rough "how much value does this unit type gain from being stationed" score. 0 for a unit with no stationedBonuses (e.g. Archer).
/// @param {Struct.UnitDefinition} _def
/// @returns {Real}
function AI_UnitStationedBonusValue(_def) {
    var _total = 0;
    for (var i = 0; i < array_length(_def.stationedBonuses); i++) {
        _total += _def.stationedBonuses[i].amount;
    }
    return _total;
}

/// @function AI_UnitDefPowerScore(_def)
/// @description Definition-level counterpart to AI_UnitPowerScore, evaluated off maxHealth/attackDamage instead of a live instance's current HP.
/// @param {Struct.UnitDefinition} _def
/// @returns {Real}
function AI_UnitDefPowerScore(_def) {
    return (_def.maxHealth * AI_POWER_HEALTH_WEIGHT) + (_def.attackDamage * AI_POWER_DAMAGE_WEIGHT);
}

/// @function AI_UnitFavorsStationing(_def)
/// @description Whether _def's unit type is more valuable stationed than fielded -- true only when it gains something from stationing AND its power sits below AI_STATION_FAVOR_POWER_CEILING. See .md.
/// @param {Struct.UnitDefinition} _def
/// @returns {Bool}
function AI_UnitFavorsStationing(_def) {
    return AI_UnitStationedBonusValue(_def) > 0 && AI_UnitDefPowerScore(_def) < AI_STATION_FAVOR_POWER_CEILING;
}

/// @function AI_TryStationUnits(_team)
/// @description Called once per think tick from AI_BuildUp_Step (never while defending/castle_defense). Stations eligible "guard" units (nonzero stationed-bonus value), weakest-power-first, respecting a reserve floor. See .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
function AI_TryStationUnits(_team) {
    if (AI_CurrentStationedCount(_team) >= AI_STATION_MAX_STATIONED) return;

    var _reserveFloor = AI_TeamAtArmyLimit(_team) ? AI_STATION_MIN_GUARD_RESERVE_AT_CAP : AI_STATION_MIN_GUARD_RESERVE;

    var _guards = [];
    with (oUnitParent) {
        if (team == _team && fsm.Is("guard")) array_push(_guards, id);
    }
    if (array_length(_guards) <= _reserveFloor) return;

    var _eligible = [];
    for (var i = 0; i < array_length(_guards); i++) {
        var _def = GetUnitDefinition(_guards[i].object_index);
        if (_def != undefined && AI_UnitStationedBonusValue(_def) > 0) {
            array_push(_eligible, _guards[i]);
        }
    }
    if (array_length(_eligible) == 0) return;

    array_sort(_eligible, function(_a, _b) {
        var _powerDiff = AI_UnitPowerScore(_a) - AI_UnitPowerScore(_b);
        if (_powerDiff != 0) return _powerDiff;
        return GetUnitDefinition(_a.object_index).stationCost - GetUnitDefinition(_b.object_index).stationCost;
    });

    var _spareCount = array_length(_guards) - _reserveFloor;
    var _attempts   = min(AI_STATION_ATTEMPTS_PER_TICK, min(_spareCount, array_length(_eligible)));
    for (var i = 0; i < _attempts; i++) {
        IssueOrderToUnits("station", [_eligible[i]]);
    }
}

// ----- AI early-game probe attacks -----

/// @function AI_TryProbeAttack(_brain, _surplus)
/// @description Called once per think tick from AI_BuildUp_Step, after the defensive-floor reserve has been carved out of _surplus. Sends up to AI_PROBE_ATTACK_SIZE units at one random standing enemy building during the early-game window. See .md.
/// @param {Struct.AIBrain} _brain
/// @param {Array<Id.Instance>} _surplus Units already cleared for offense this tick.
/// @returns {Array<Id.Instance>} _surplus minus whatever units were sent on a probe (unchanged if nothing fired).
function AI_TryProbeAttack(_brain, _surplus) {
    if (_brain.age >= AI_PROBE_WINDOW_FRAMES) return _surplus;
    if (_brain.probeCooldown > 0) return _surplus;
    if (array_length(_surplus) < AI_PROBE_ATTACK_SIZE) return _surplus;

    var _enemyTeam = (_brain.team == TEAM.PLAYER) ? TEAM.ENEMY : TEAM.PLAYER;
    var _targets = [];
    with (oBuildingParent) {
        if (team == _enemyTeam) array_push(_targets, id);
    }
    if (array_length(_targets) == 0) return _surplus;

    var _target = _targets[irandom(array_length(_targets) - 1)];

    var _split   = AI_PartitionByPosture(_surplus);
    var _raiders = [];
    for (var i = 0; i < array_length(_split.guard) && array_length(_raiders) < AI_PROBE_ATTACK_SIZE; i++) {
        array_push(_raiders, _split.guard[i]);
    }
    for (var i = 0; i < array_length(_split.defend) && array_length(_raiders) < AI_PROBE_ATTACK_SIZE; i++) {
        array_push(_raiders, _split.defend[i]);
    }

    IssueOrderToUnits("attack", _raiders, _target);
    _brain.probeCooldown = AI_PROBE_INTERVAL_FRAMES;

    var _remaining = [];
    for (var i = 0; i < array_length(_surplus); i++) {
        if (!array_contains(_raiders, _surplus[i])) array_push(_remaining, _surplus[i]);
    }
    return _remaining;
}

/// @function AI_CanReplaceDeployedUnits(_team)
/// @description True once _team could plausibly rebuild whatever it's about to commit to an attack -- resource-ready (a training building can afford its own cost right now) OR composition-ready (2+ distinct trained types). See .md.
/// @param {Real} _team
/// @returns {Bool}
function AI_CanReplaceDeployedUnits(_team) {
    var _distinctTypes = [];
    var _resourceReady = false;

    with (oTrainingBuildingParent) {
        if (team != _team || trainsUnit == undefined) continue;
        if (!array_contains(_distinctTypes, trainsUnit)) array_push(_distinctTypes, trainsUnit);
        if (!_resourceReady && trainCost.CanAfford(_team)) _resourceReady = true;
    }

    return _resourceReady || (array_length(_distinctTypes) >= 2);
}

/// @function AI_TryAttackSurplusAtCap(_brain, _surplus)
/// @description Once _brain.team is at its army cap AND AI_CanReplaceDeployedUnits says it's ready, redirects _surplus to attack one random ordinary enemy building instead of leaving it idle. A new outlet layered ahead of the siege check -- does not change AI_SiegePowerThreshold. See .md.
/// @param {Struct.AIBrain} _brain
/// @param {Array<Id.Instance>} _surplus
/// @returns {Array<Id.Instance>} Whatever's LEFT of _surplus -- empty if a target was found, unchanged otherwise.
function AI_TryAttackSurplusAtCap(_brain, _surplus) {
    if (array_length(_surplus) == 0) return _surplus;
    if (!AI_TeamAtArmyLimit(_brain.team)) return _surplus;
    if (!AI_CanReplaceDeployedUnits(_brain.team)) return _surplus;

    var _enemyTeam = (_brain.team == TEAM.PLAYER) ? TEAM.ENEMY : TEAM.PLAYER;
    var _targets = [];
    with (oBuildingParent) {
        if (team == _enemyTeam) array_push(_targets, id);
    }
    if (array_length(_targets) == 0) return _surplus; // nothing but the castle left -- let the siege check below handle it, unchanged

    var _target = _targets[irandom(array_length(_targets) - 1)];
    IssueOrderToUnits("attack", _surplus, _target);
    return [];
}

// ----- AI debug introspection -----
// READ-ONLY: mirrors real gating logic for oAIControl/Draw_64.gml's debug
// readout without issuing orders or spending anything. See .md re: the
// duplication-drift risk against the real functions.

/// @function AI_WouldTrainSucceed(_building)
/// @description Dry-run mirror of TrainingTryQueueUnit's three gates (type limit, army-wide limit, affordability) for one additional unit, without spending anything.
/// @param {Id.Instance} _building An oTrainingBuildingParent instance.
/// @returns {Bool}
function AI_WouldTrainSucceed(_building) {
    var _unitType = _building.trainsUnit;
    if (_unitType == undefined) return false;

    var _team = _building.team;

    var _typeLimit    = TrainingTypeLimit(_team, _unitType);
    var _typeExisting = CountTeamUnitsOfType(_team, _unitType) + CountTeamStationedUnitsOfType(_team, _unitType);
    var _typeQueued   = TrainingQueuedCountForType(_team, _unitType);
    if (_typeExisting + _typeQueued + 1 > _typeLimit) return false;

    var _armyLimit    = global.armyLimit[_team];
    var _armyExisting = array_length(GatherTeamUnits(_team)) + CountTeamStationedUnits(_team);
    var _armyQueued   = TrainingQueuedCountAll(_team);
    if (_armyExisting + _armyQueued + 1 > _armyLimit) return false;

    return _building.trainCost.CanAfford(_team);
}

/// @function AI_NextAffordableBlueprintName(_team)
/// @description First blueprint _team currently holds that's both affordable and has a free plot to go on, or undefined. Mirrors AI_TryPlaceBlueprints' second (greedy) pass only.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {String|Undefined}
function AI_NextAffordableBlueprintName(_team) {
    var _stacks = global.blueprints[_team];
    for (var i = array_length(_stacks) - 1; i >= 0; i--) {
        var _def = GetBuildingDefinition(_stacks[i].buildingType);
        if (_def == undefined || !_def.cost.CanAfford(_team)) continue;
        if (AI_FindEmptyOwnedPlot(_team) == noone) continue;
        return _def.name;
    }
    return undefined;
}

/// @function AI_NextTrainableUnitName(_team)
/// @description First owned training building that would successfully queue a unit right now (AI_WouldTrainSucceed), or undefined.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {String|Undefined}
function AI_NextTrainableUnitName(_team) {
    var _name = undefined;
    with (oTrainingBuildingParent) {
        if (team == _team && AI_WouldTrainSucceed(id)) {
            var _unitDef = GetUnitDefinition(trainsUnit);
            _name = (_unitDef != undefined) ? _unitDef.name : object_get_name(trainsUnit);
            break;
        }
    }
    return _name;
}

/// @function AI_TeamHasTrainingStructures(_team)
/// @description Whether _team owns at least one live oTrainingBuildingParent instance. 2026-08-16 follow-up ("cannot defend itself if it has no buildings") -- gates AI_BuildUp_Step's transition into "defending" ALONGSIDE AI_TeamHasUnitsInHand below (either one is enough), see .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Bool}
function AI_TeamHasTrainingStructures(_team) {
    var _found = false;
    with (oTrainingBuildingParent) {
        if (team == _team) {
            _found = true;
            break;
        }
    }
    return _found;
}

/// @function AI_TeamHasUnitsInHand(_team)
/// @description Whether _team currently has any units to actually respond with -- live/deployed (GatherTeamUnits) OR stationed/garrisoned (AI_CurrentStationedCount). 2026-08-16 follow-up ("allow for defending with units in hand without training buildings") -- a team with no oTrainingBuildingParent instances can still clearly defend itself if it already has units on hand, deployed or garrisoned; stationed units in particular don't need a training building at all to be un-garrisoned (see AI_TryReinforceDefense). See AI_TeamHasTrainingStructures()/.md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Bool}
function AI_TeamHasUnitsInHand(_team) {
    if (array_length(GatherTeamUnits(_team)) > 0) return true;
    return AI_CurrentStationedCount(_team) > 0;
}

/// @function AI_TeamHasSpareGuard(_team)
/// @description Whether _team has at least one unit currently in "guard".
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Bool}
function AI_TeamHasSpareGuard(_team) {
    var _found = false;
    with (oUnitParent) {
        if (team == _team && fsm.Is("guard")) {
            _found = true;
            break;
        }
    }
    return _found;
}

/// @function AI_NextStationCandidateName(_team)
/// @description Dry-run mirror of AI_TryStationUnits' own eligibility/selection logic -- returns the unit type name that WOULD be stationed next, or undefined.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {String|Undefined}
function AI_NextStationCandidateName(_team) {
    if (AI_CurrentStationedCount(_team) >= AI_STATION_MAX_STATIONED) return undefined;

    var _reserveFloor = AI_TeamAtArmyLimit(_team) ? AI_STATION_MIN_GUARD_RESERVE_AT_CAP : AI_STATION_MIN_GUARD_RESERVE;

    var _guards = [];
    with (oUnitParent) {
        if (team == _team && fsm.Is("guard")) array_push(_guards, id);
    }
    if (array_length(_guards) <= _reserveFloor) return undefined;

    var _best      = undefined;
    var _bestScore = infinity;
    for (var i = 0; i < array_length(_guards); i++) {
        var _def = GetUnitDefinition(_guards[i].object_index);
        if (_def == undefined || AI_UnitStationedBonusValue(_def) <= 0) continue;
        var _score = AI_UnitPowerScore(_guards[i]);
        if (_score < _bestScore) {
            _bestScore = _score;
            _best      = _def;
        }
    }
    return (_best != undefined) ? _best.name : undefined;
}

/// @function AI_DebugIntent(_brain)
/// @description Debug-only, READ-ONLY preview of what _brain's next think tick would do if it ran right now. Mirrors the real posture priority order but stops at the first applicable action. See .md.
/// @param {Struct.AIBrain} _brain
/// @returns {String}
function AI_DebugIntent(_brain) {
    var _team = _brain.team;

    if (_brain.fsm.Is("castle_defense")) return "Defending own castle";
    if (_brain.fsm.Is("defending"))      return "Defending threatened building(s)";

    if (AI_CastleUnderThreat(_team))     return "About to defend own castle";
    if (AI_DetectThreat(_team) != noone) return "About to defend a building";

    var _blueprintName = AI_NextAffordableBlueprintName(_team);
    if (_blueprintName != undefined) return "Placing: " + _blueprintName;

    var _trainName = AI_NextTrainableUnitName(_team);
    if (_trainName != undefined) return "Training: " + _trainName;

    if (array_length(AI_UncoveredBuildingsByTier(_team)) > 0 && AI_TeamHasSpareGuard(_team)) {
        return "Posting a defender";
    }

    var _stationName = AI_NextStationCandidateName(_team);
    if (_stationName != undefined) return "Stationing: " + _stationName;

    var _available     = AI_GatherAvailableUnits(_team);
    var _reserveNeeded = max(0, AI_MinDefensiveReserve(_team) - AI_CurrentStationedCount(_team));
    var _surplus       = AI_ReserveDefensiveUnits(_available, _reserveNeeded);

    if (array_length(_surplus) > 0 && AI_ArmyPower(_surplus) >= AI_SiegePowerThreshold(_team)) {
        return "Attacking (siege)";
    }

    if (_brain.age < AI_PROBE_WINDOW_FRAMES && _brain.probeCooldown <= 0 && array_length(_surplus) >= AI_PROBE_ATTACK_SIZE) {
        return "Probing an enemy building";
    }

    return "Idle / accumulating";
}

/// @function AI_DebugQuotasText(_team)
/// @description One "\n"-joined block of the raw quota numbers driving _team's AI decisions this tick. Recomputed fresh every call. See .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {String}
function AI_DebugQuotasText(_team) {
    var _armyLive      = array_length(GatherTeamUnits(_team));
    var _stationed     = AI_CurrentStationedCount(_team);
    var _armyQueued    = TrainingQueuedCountAll(_team);
    var _armyLimit     = global.armyLimit[_team];
    var _capSuffix     = AI_TeamAtArmyLimit(_team) ? " (CAP)" : "";

    var _tankPct   = string(round(AI_ArmyTagFraction(_team, "tank")   * 100));
    var _tankTgt   = string(round(AI_TANK_TARGET_RATIO   * 100));
    var _rangedPct = string(round(AI_ArmyTagFraction(_team, "ranged") * 100));
    var _rangedTgt = string(round(AI_RANGED_TARGET_RATIO * 100));

    var _available     = AI_GatherAvailableUnits(_team);
    var _reserveNeeded = max(0, AI_MinDefensiveReserve(_team) - _stationed);
    var _surplus       = AI_ReserveDefensiveUnits(_available, _reserveNeeded);
    var _surplusPower  = string(round(AI_ArmyPower(_surplus)));
    var _siegeNeeded   = string(round(AI_SiegePowerThreshold(_team)));

    return
        "Army: " + string(_armyLive) + "L+" + string(_stationed) + "S+" + string(_armyQueued) + "Q/" + string(_armyLimit) + _capSuffix + "\n" +
        "Stationed: " + string(_stationed) + "/" + string(AI_STATION_MAX_STATIONED) + "\n" +
        "Tank: " + _tankPct + "%/" + _tankTgt + "%  Ranged: " + _rangedPct + "%/" + _rangedTgt + "%\n" +
        "Siege power: " + _surplusPower + "/" + _siegeNeeded;
}
