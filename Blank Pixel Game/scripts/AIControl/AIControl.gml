#macro AI_THINK_INTERVAL    45   // frames between AI decisions (~0.75s at 60fps) -- deliberately not every-frame, keeps behavior considered rather than twitchy
#macro AI_THREAT_RADIUS     250  // how close an enemy unit must get to one of a team's buildings before AI_DetectThreat flags it as a threat -- placeholder, not tuned against any real unit speed/reaction-time math
#macro AI_CASTLE_THREAT_RADIUS 300 // how close an enemy unit must get to a team's OWN castle before AI_CastleUnderThreat flags it -- larger than AI_THREAT_RADIUS since the castle itself (350x411) is much bigger than an ordinary 48x48 building being measured from its origin; placeholder, not tuned
#macro AI_SIEGE_POWER_FRACTION 0.6 // AI_ArmyPower(available units) must reach this fraction of CASTLE_MAX_HEALTH (CastleScripts.gml) before the AI commits to "siege" -- a rough "don't throw two peasants at the wall" gate, not a tuned balance number. Replaces the old flat AI_ATTACK_GROUP_SIZE headcount (2026-07-06).
#macro AI_POWER_HEALTH_WEIGHT 0.4 // AI_UnitPowerScore weight on current HP -- placeholder, see that function
#macro AI_POWER_DAMAGE_WEIGHT 5   // AI_UnitPowerScore weight on attackDamage -- placeholder, see that function
#macro AI_TANK_TARGET_RATIO   0.25 // AI_TryTrainComposition: desired minimum fraction of _team's live army carrying the "tank" tag before training anything else at a building that doesn't
#macro AI_RANGED_TARGET_RATIO 0.25 // same, for "ranged"

// 2026-07-12 additions -- "use stationed units" + "be more proactive...
// defend its buildings" request. All four placeholders, not tuned against
// any real balance pass, same status as every other AI macro above.
#macro AI_STATION_MAX_STATIONED     6 // AI_TryStationUnits won't station more than this many total (across every type) at once -- a soft cap on how much of the AI's economy it converts into passive bonuses
#macro AI_STATION_MIN_GUARD_RESERVE 3 // AI_TryStationUnits won't station a "guard" unit if doing so would drop the team's own available guard count below this
#macro AI_STATION_ATTEMPTS_PER_TICK 1 // AI_TryStationUnits stations at most this many units per think tick -- gradual, not a lump dump the instant units become available

// 2026-07-12 follow-up ("don't steamroll me") -- four related tuning
// knobs for AI_MinDefensiveReserve/AI_TryProbeAttack/AI_TryMaintainDefensiveSpread
// below. All placeholders, not tuned against a real balance pass, same
// status as every AI macro in this file.
#macro AI_MIN_DEFENSIVE_ARMY_FRACTION 0.25 // floor on how much of the team's TOTAL army (live units + stationed) must stay in guard/defend/station at any given time -- siege/probe commitments can never dip below this, see AI_MinDefensiveReserve
#macro AI_DEFEND_TIER_WEIGHT        200  // px-equivalent penalty added per plot tier (MID/FRONT) when AI_Defending_Step picks which threatened building an available unit reinforces -- biases responders toward REAR buildings without overriding a unit that's overwhelmingly closer to a FRONT one
#macro AI_SPREAD_ATTEMPTS_PER_TICK  1    // AI_TryMaintainDefensiveSpread posts at most this many new defenders per think tick -- gradual, not a lump reassignment
#macro AI_PROBE_WINDOW_FRAMES       3600 // ~60s at 60fps -- "early game" window during which AI_TryProbeAttack can fire at all
#macro AI_PROBE_INTERVAL_FRAMES     900  // ~15s -- minimum gap between successful probes within that window
#macro AI_PROBE_ATTACK_SIZE         2    // units sent per probe

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

    // 2026-07-12 follow-up additions -- age gates AI_TryProbeAttack's
    // "early game" window (AI_PROBE_WINDOW_FRAMES), probeCooldown gates how
    // often it can fire within that window (AI_PROBE_INTERVAL_FRAMES).
    // Both tick every frame in Step() below, scaled by global.matchSpeed
    // same as thinkTimer, regardless of which posture the brain is
    // currently in -- "early game" is wall-clock since this brain was
    // created, not time spent specifically in build_up.
    age           = 0;
    probeCooldown = 0;

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
    ///
    ///        2026-07-12 addition ("faster reaction" request): an urgency
    ///        interrupt runs EVERY frame, ahead of the normal timer --
    ///        if the team is under threat (AI_CastleUnderThreat or
    ///        AI_DetectThreat) and the brain hasn't already reacted (isn't
    ///        already in "defending"/"castle_defense"), thinkTimer is
    ///        zeroed so the fsm.Step() below fires THIS same frame instead
    ///        of waiting out the rest of AI_THINK_INTERVAL (up to ~0.75s).
    ///        Only the cheap threat checks themselves run every frame --
    ///        the full decision cycle (training/blueprints/composition/
    ///        siege/station math) still only ever runs on an actual think
    ///        tick, so this doesn't make the AI generally twitchy, just
    ///        fast to notice "under attack." Once already reacting
    ///        (defending/castle_defense), the interrupt backs off and lets
    ///        the normal AI_THINK_INTERVAL cadence resume for follow-up
    ///        decisions within that posture.
    /// @returns {Struct.AIBrain} self
    static Step = function() {
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

// -----------------------------------------------------------
// AI defensive posture -- 2026-07-12 follow-up ("don't steamroll me"):
// plot-tier classification, a fraction-of-total-army reserve floor that
// siege/probe commitments must respect, and proactive coverage spread
// across owned buildings. Replaces the old flat AI_ReserveGuardUnits
// (guard-only, flat headcount of 2) with something that scales with army
// size and protects already-posted "defend" units FIRST, not just idle
// "guard" ones.
// -----------------------------------------------------------

#macro AI_PLOT_TIER_REAR  0 // inside castle walls -- oBuildingPlot.inside (oPlotSpawner's castle grid)
#macro AI_PLOT_TIER_MID   1 // near exterior plots -- !inside && !far (oOuterPlotSpawner's "near" band)
#macro AI_PLOT_TIER_FRONT 2 // far/exposed exterior plots -- oBuildingPlot.far (oOuterPlotSpawner's "far" band)

/// @function AI_BuildingPlotTier(_building)
/// @description Which defensive tier _building's plot falls into, derived
///        from the SAME oBuildingPlot.inside/far fields SpawnBuildingPlot
///        (PlotScripts.gml) already tags every plot with -- "the different
///        groups of plots" the 2026-07-12 request refers to are literally
///        this existing inside/near/far grouping (oPlotSpawner's castle
///        grid = REAR, oOuterPlotSpawner's "near"/"far" bands = MID/FRONT),
///        not a new geometry system. Looked up by position
///        (instance_position), the same technique BuildingFreePlot
///        (PlotScripts.gml) already uses -- no plot reference is stored on
///        building instances anywhere in this codebase.
/// @param {Id.Instance} _building An oBuildingParent instance.
/// @returns {Real} AI_PLOT_TIER_REAR/_MID/_FRONT. Defaults to _MID if no
///        plot is found at _building's position (shouldn't happen -- every
///        building is spawned exactly on a plot -- but MID is the least
///        consequential tier to guess wrong on either side).
function AI_BuildingPlotTier(_building) {
    var _plot = instance_position(_building.x, _building.y, oBuildingPlot);
    if (_plot == noone) return AI_PLOT_TIER_MID;
    if (_plot.inside) return AI_PLOT_TIER_REAR;
    if (_plot.far) return AI_PLOT_TIER_FRONT;
    return AI_PLOT_TIER_MID;
}

/// @function AI_PartitionByPosture(_units)
/// @description Splits _units (expected: AI_GatherAvailableUnits' guard+
///        defend output) into two arrays by current FSM state. Shared by
///        AI_ReserveDefensiveUnits and AI_TryProbeAttack, both of which
///        need to prefer one posture over the other rather than treating
///        the combined pool as interchangeable.
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
/// @description How many units -- out of _team's TOTAL army, every live
///        oUnitParent PLUS every currently-stationed oUnitStationed -- must
///        stay in guard/defend/station at any given time. 2026-07-12
///        request: "Don't commit a large force to siege. Leave at least
///        1/4 of its army to defend/guard/station at any given time."
///        AI_ReserveDefensiveUnits enforces this against whatever's still
///        uncommitted (guard+defend); stationed units already count toward
///        it automatically since they can't be sent to siege/probe/attack
///        at all -- they're a different object (oUnitStationed, not
///        oUnitParent) -- see AI_BuildUp_Step's _reserveNeeded subtraction.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Real} Rounded up -- a 5-unit army reserves 2, not 1.25.
function AI_MinDefensiveReserve(_team) {
    var _totalArmy = array_length(GatherTeamUnits(_team)) + AI_CurrentStationedCount(_team);
    return ceil(_totalArmy * AI_MIN_DEFENSIVE_ARMY_FRACTION);
}

/// @function AI_ReserveDefensiveUnits(_units, _reserveCount)
/// @description Splits _units (guard+defend) into "reserved" (kept back)
///        and returns the SURPLUS -- everything else, eligible for siege/
///        probe commitment. Reserves DEFEND units FIRST, up to
///        _reserveCount, since they're already actively posted defending a
///        specific building -- pulling an idle GUARD unit instead costs
///        nothing extra to "keep". Guard only fills whatever gap remains
///        after defend is exhausted. If _units contains fewer than
///        _reserveCount total, ALL of them are reserved (surplus may be
///        empty) -- an empty or under-strength siege/probe commitment is
///        preferable to dropping the team's own defensive floor.
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
/// @description Every _team-owned, currently-placed building with ZERO
///        live "defend" units currently posted at it (no unit's
///        defendTarget points to it), bucketed into AI_BuildingPlotTier
///        and returned REAR-first, then MID, then FRONT. 2026-07-12
///        request: "spreads its defensive force around its buildings, and
///        the different groups of plots, prioritizing its rear... plots
///        for protection over the front plots." Recomputed fresh every
///        call (same "don't cache, recompute" convention as
///        GetStationedPassiveBonuses/TrainingTypeLimit) -- building/unit
///        counts are small enough that this is cheap.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Array<Id.Instance>}
function AI_UncoveredBuildingsByTier(_team) {
    var _byTier = [[], [], []]; // index = AI_PLOT_TIER_*

    with (oBuildingParent) {
        if (team != _team) continue;
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
/// @description Proactively posts idle "guard" units to "defend" whichever
///        of _team's own buildings currently has zero defenders,
///        REAR-tier first (see AI_UncoveredBuildingsByTier). Only ever
///        pulls from "guard" -- never reassigns an already-"defend" unit,
///        matching AI_ReserveDefensiveUnits' same "guard is the flexible
///        pool, defend stays put" philosophy -- and posts at most
///        AI_SPREAD_ATTEMPTS_PER_TICK per think tick, gradual rather than a
///        lump reassignment. Called from AI_BuildUp_Step BEFORE
///        AI_TryStationUnits: physical coverage at every building takes
///        priority over the passive stationed-bonus optimization, since a
///        completely undefended building can be lost outright while a
///        delayed stationing is only a missed economic edge.
///
///        Scope note: only guarantees each building has AT LEAST ONE
///        defender, not any particular garrison size per building --
///        going further (e.g. 2+ defenders on a high-value building) would
///        need its own request/tuning pass.
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
/// @description AI onStep for "build_up" -- the AI's default economic/
///        training/massing posture. Each think tick: checks the AI's OWN
///        castle first and hands off to "castle_defense" if it's under
///        attack (see AI_CastleUnderThreat -- this outranks the ordinary
///        building-threat check right below it), then checks for an
///        ordinary threatened building and hands off to "defending" if one
///        exists (see AI_DetectThreat). Otherwise, in order:
///          1. Spends affordable blueprints (AI_TryPlaceBlueprints,
///             composition-aware -- replacing a depleted/missing resource
///             producer takes priority).
///          2. Queues training (AI_TryTrainComposition, weighted toward
///             under-represented tags).
///          3. Posts idle guards to cover any undefended owned building,
///             rear-tier plots first (AI_TryMaintainDefensiveSpread,
///             2026-07-12 -- physical coverage before economic tuning).
///          4. Stations a few idle units for their passive bonuses
///             (AI_TryStationUnits).
///          5. Gathers every AVAILABLE unit (AI_GatherAvailableUnits) and
///             carves out AI_MinDefensiveReserve's floor
///             (AI_ReserveDefensiveUnits, 2026-07-12 replacement for the
///             old flat 2-guard AI_ReserveGuardUnits -- "leave at least
///             1/4 of its army to defend/guard/station at any given
///             time") -- whatever's left is _surplus.
///          6. Offers _surplus to AI_TryProbeAttack (2026-07-12 addition --
///             small early-game harassment against an ordinary enemy
///             building, separate from the siege threshold below).
///          7. Whatever's left of _surplus after that, once its combined
///             AI_ArmyPower reaches AI_SiegePowerThreshold(), commits to
///             "siege" against the enemy castle.
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
    AI_TryMaintainDefensiveSpread(_brain.team);
    AI_TryStationUnits(_brain.team);

    var _available     = AI_GatherAvailableUnits(_brain.team);
    var _reserveNeeded = max(0, AI_MinDefensiveReserve(_brain.team) - AI_CurrentStationedCount(_brain.team));
    var _surplus       = AI_ReserveDefensiveUnits(_available, _reserveNeeded);

    _surplus = AI_TryProbeAttack(_brain, _surplus);

    if (array_length(_surplus) > 0 && AI_ArmyPower(_surplus) >= AI_SiegePowerThreshold()) {
        IssueOrderToUnits("siege", _surplus);
    }
}

/// @function AI_Defending_Step(_brain, _machine)
/// @description AI onStep for "defending" -- entered from "build_up" the
///        instant AI_DetectThreat finds an owned building with an enemy
///        unit nearby. Every think tick while here: checks the AI's OWN
///        castle first and escalates to "castle_defense" if it comes under
///        attack too (same priority ordering as AI_BuildUp_Step -- the
///        castle always outranks an ordinary building), then re-checks
///        building threats (reverting to "build_up" the moment nothing's
///        threatened anymore) and, while any persist, sends every
///        currently AVAILABLE unit (AI_GatherAvailableUnits) to "defend"
///        one of them -- reusing the existing player-facing "defend"
///        order/state unchanged, so responders patrol it and auto-engage
///        anything that wanders into their attackAggroRadius (Defend_Step's
///        existing proximity-aggro check, UnitStateDefend.gml) with zero
///        new combat logic needed.
///
///        2026-07-12 change ("moving units to defend different
///        buildings"): now uses AI_DetectThreats (plural) instead of just
///        the first threatened building AI_DetectThreat finds, and
///        distributes _available across ALL of them -- each unit is
///        assigned to whichever threatened building scores lowest
///        (distance PLUS a tier penalty, not a flat/even split), so
///        responders already close to one threatened building don't get
///        routed across the map to another. Previously every available
///        unit was dumped on the single first-found building, leaving any
///        other simultaneously threatened building completely undefended.
///
///        2026-07-12 follow-up ("prioritizing its rear... plots for
///        protection over the front plots"): the per-building score is now
///        distance + AI_BuildingPlotTier(building) * AI_DEFEND_TIER_WEIGHT
///        -- REAR (inside castle) buildings get no penalty, MID and FRONT
///        buildings get progressively larger ones, biasing responders
///        toward rear buildings whenever the choice is close without
///        overriding a unit that's overwhelmingly nearer a FRONT building.
///
///        Economy/training pause while defending (does not call
///        AI_TryPlaceBlueprints/AI_TryTrainComposition/AI_TryStationUnits)
///        -- a deliberate scope choice, not an oversight; flag if the AI
///        should keep building through a skirmish instead.
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

    var _available = AI_GatherAvailableUnits(_brain.team);
    if (array_length(_available) == 0) return;

    // Nearest-building assignment -- see file header above for why this
    // beats a flat split. Grouped into one IssueOrderToUnits call PER
    // building (not one call per unit) so "defend" only re-evaluates
    // DefendBuildingWaypoints once per building this tick, matching the
    // batching every other IssueOrderToUnits caller already does.
    var _groups = array_create(array_length(_threatened));
    for (var i = 0; i < array_length(_groups); i++) _groups[i] = [];

    // 2026-07-12: per-building tier penalty computed once, not per-unit
    // (see file header's "prioritizing rear" addition).
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

/// @function AI_DetectThreats(_team)
/// @description Plural counterpart to AI_DetectThreat, added 2026-07-12
///        ("moving units to defend different buildings" request) --
///        returns EVERY currently threatened _team-owned building instead
///        of stopping at the first one found. Used by AI_Defending_Step,
///        which needs the full list to distribute defenders across every
///        threatened building, not just detect that one exists. Same per-
///        building AI_THREAT_RADIUS collision check as AI_DetectThreat;
///        that function is kept as-is (cheap early-exit "is ANYTHING
///        threatened at all" check -- used by AI_BuildUp_Step's posture-
///        transition guard and AIBrain.Step's urgency interrupt, neither
///        of which needs the full list) rather than rewritten in terms of
///        this one, so the common case (nothing threatened) doesn't pay
///        for building an array it doesn't need.
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

// -----------------------------------------------------------
// AI stationing -- 2026-07-12 "use stationed units" request. The AI now
// deliberately converts some of its own idle "guard" units into stationed
// units for their passive bonuses (GetStationedPassiveBonuses,
// StationScripts.gml), the same way a player would via the castle
// garrison dropdown -- just automated, gradual, and reserve-aware so it
// doesn't hollow out its own standing defense to do it.
// -----------------------------------------------------------

/// @function AI_CurrentStationedCount(_team)
/// @description Total live oUnitStationed belonging to _team, any type.
///        Used by AI_TryStationUnits to respect AI_STATION_MAX_STATIONED.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Real}
function AI_CurrentStationedCount(_team) {
    var _count = 0;
    with (oUnitStationed) {
        if (team == _team) _count++;
    }
    return _count;
}

/// @function AI_UnitStationedBonusValue(_def)
/// @description Sum of a unit type's stationedBonuses[].amount -- a rough
///        single-number "how much value does this unit type gain from
///        being stationed" score, same rough-heuristic spirit as
///        AI_UnitPowerScore. 0 for any unit with no stationedBonuses at
///        all (Archer today, per its own "skip for now" scope note in
///        UnitDefinitions.gml) -- such units are NEVER worth auto-
///        stationing, see AI_TryStationUnits.
/// @param {Struct.UnitDefinition} _def
/// @returns {Real}
function AI_UnitStationedBonusValue(_def) {
    var _total = 0;
    for (var i = 0; i < array_length(_def.stationedBonuses); i++) {
        _total += _def.stationedBonuses[i].amount;
    }
    return _total;
}

/// @function AI_TryStationUnits(_team)
/// @description Called once per think tick from AI_BuildUp_Step (never
///        while defending/castle_defense -- see that state's own doc
///        comment). No-ops immediately if _team is already at
///        AI_STATION_MAX_STATIONED. Otherwise gathers every "guard" unit
///        (NOT "defend" -- those are already actively posted at a
///        building, never pulled for this).
///
///        2026-07-12 follow-up ("make sure it is placing some buildings
///        with units that have higher benefits to station than to be
///        abroad") -- only units with a NONZERO AI_UnitStationedBonusValue
///        are even eligible (stationing an Archer today would be pure
///        waste, zero benefit either way); among those, the WEAKEST in
///        combat (lowest AI_UnitPowerScore) go first -- a unit that
///        contributes little in a fight loses little by sitting in the
///        garrison instead, same logic the request's own Peasant example
///        makes (weak melee, but a real stationed production bonus).
///        stationCost is only a final tiebreaker now (cheaper first),
///        preserving some of the old greedy-affordability behavior when
///        power scores are equal.
///
///        The AI_STATION_MIN_GUARD_RESERVE floor is still checked against
///        the TOTAL guard count (not just eligible ones) -- ineligible
///        guards (no stationed bonus) still count as "kept back" even
///        though they'd never be picked anyway. Posts up to
///        AI_STATION_ATTEMPTS_PER_TICK per tick, same gradual-not-lump-dump
///        reasoning as before.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
function AI_TryStationUnits(_team) {
    if (AI_CurrentStationedCount(_team) >= AI_STATION_MAX_STATIONED) return;

    var _guards = [];
    with (oUnitParent) {
        if (team == _team && fsm.Is("guard")) array_push(_guards, id);
    }
    if (array_length(_guards) <= AI_STATION_MIN_GUARD_RESERVE) return;

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

    var _spareCount = array_length(_guards) - AI_STATION_MIN_GUARD_RESERVE;
    var _attempts   = min(AI_STATION_ATTEMPTS_PER_TICK, min(_spareCount, array_length(_eligible)));
    for (var i = 0; i < _attempts; i++) {
        IssueOrderToUnits("station", [_eligible[i]]);
    }
}

// -----------------------------------------------------------
// AI early-game probe attacks -- 2026-07-12 request ("add an early game
// 'probe attack', where it sends a few units to attack enemy buildings").
// Small, cheap harassment, deliberately separate from "siege" (which
// targets the enemy CASTLE specifically and requires
// AI_SiegePowerThreshold's much higher army-power bar) -- a probe targets
// an ordinary enemy building via the same "attack" order/state a player
// uses (Attack_Enter/Attack_Step, UnitStateAttackMelee.gml), through
// IssueOrderToUnits, same as every other AI-issued order in this file.
// -----------------------------------------------------------

/// @function AI_TryProbeAttack(_brain, _surplus)
/// @description Called once per think tick from AI_BuildUp_Step, AFTER the
///        defensive-floor reserve has already been carved out of _surplus
///        -- probes draw from the SAME uncommitted pool siege does, so
///        they respect AI_MIN_DEFENSIVE_ARMY_FRACTION too. No-ops (returns
///        _surplus unchanged) if: _brain.age is past AI_PROBE_WINDOW_FRAMES
///        (early game only), _brain.probeCooldown hasn't expired yet,
///        _surplus has fewer than AI_PROBE_ATTACK_SIZE units to spare, or
///        the enemy currently owns no building at all. On a successful
///        probe, picks ONE random currently-standing enemy oBuildingParent
///        (never the castle -- "attack" order is building-only, matching
///        its existing player-facing scope, see OrderWiring.gml) and sends
///        up to AI_PROBE_ATTACK_SIZE units at it, preferring GUARD units
///        over DEFEND units within _surplus (same "leave posted defenders
///        alone if there's any other option" priority
///        AI_ReserveDefensiveUnits uses), then resets the cooldown. Does
///        NOT check the target building's own defenses -- a probe that
///        gets its raiders killed against a defended building is expected
///        behavior for a probe (that IS the information it's gathering),
///        not a bug.
/// @param {Struct.AIBrain} _brain
/// @param {Array<Id.Instance>} _surplus Units already cleared for offense
///        this tick (AI_ReserveDefensiveUnits' output in AI_BuildUp_Step).
/// @returns {Array<Id.Instance>} _surplus minus whatever units were sent
///        on a probe (unchanged if nothing fired).
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
