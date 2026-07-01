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
    /// @returns {Struct.AIBrain} self
    static Step = function() {
        thinkTimer--;
        if (thinkTimer <= 0) {
            thinkTimer = AI_THINK_INTERVAL;
            fsm.Step();
        }
        return self;
    }
}

/// @function AI_BuildUp_Step(_brain, _machine)
/// @description AI onStep for "build_up" -- currently the only AI state. Gathers
///        every unit on _brain.team (via GatherTeamUnits) and counts how many are
///        idle (still in "guard", i.e. not already committed to an order). Once
///        AI_ATTACK_GROUP_SIZE or more are idle, masses them and issues "siege"
///        against the enemy castle.
///
///        This is intentionally the simplest policy that proves the whole
///        pipeline end to end (perception -> decision -> IssueOrderToUnits) --
///        it does not yet defend, expand, place buildings, or purchase units.
///        Extend this function, or add sibling AI states (e.g. "defend"), as
///        real strategy comes together.
/// @param {Struct.AIBrain} _brain
/// @param {Struct.StateMachine} _machine
function AI_BuildUp_Step(_brain, _machine) {
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
