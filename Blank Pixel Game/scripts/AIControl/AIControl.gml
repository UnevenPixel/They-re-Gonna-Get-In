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
///        castle first and escalat