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
function AI_BuildUp_Step(_brain, _ma