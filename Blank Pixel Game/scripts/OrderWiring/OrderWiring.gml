// -----------------------------------------------------------
// Order registration (call once, e.g. a game-start script)
// -----------------------------------------------------------

function RegisterAllOrders() {
    RegisterOrder(new Order("guard", "Guard"));   // default onIssue: fsm.ChangeState("guard")
    RegisterOrder(new Order(
        "defend",
        "Defend Building",
        function(_units, _context) {
            // _context is the clicked building instance.
            for (var i = 0; i < array_length(_units); i++) {
                _units[i].defendTarget = _context;
                _units[i].fsm.ChangeState("defend");
            }
        },
        true, // requiresTarget = true -- menu click starts targeting mode
        function(_instance) {
            // Only own-team buildings are valid defend targets.
            return object_is_ancestor(_instance.object_index, oBuildingParent)
                && _instance.team == "player";
        }
    ));

    // "attack" needs a target to actually be useful -- onIssue here
    // expects _context to be the clicked building/unit instance, set
    // on each unit before transitioning. Replace with however your
    // combat states actually consume a target (e.g. writing into
    // _machine.data instead, if using the StateMachine.data pattern).
    RegisterOrder(new Order(
        "attack",
        "Attack Building",
        function(_units, _context) {
            for (var i = 0; i < array_length(_units); i++) {
                _units[i].attackBuildingTarget = _context;
                _units[i].fsm.ChangeState("attack");
            }
        },
        true, // requiresTarget
        function(_instance) {
            // Only enemy buildings are valid attack targets.
            return object_is_ancestor(_instance.object_index, oBuildingParent)
                && _instance.team == "enemy";
        }
    ));

    RegisterOrder(new Order("siege", "Siege Castle", function(_units, _context) {
        // No target click needed -- GetEnemyCastle() finds the castle
        // automatically inside Siege_Enter. Just flip the state.
        for (var i = 0; i < array_length(_units); i++) {
            _units[i].fsm.ChangeState("siege");
        }
    }));

    // "combat" is intentionally NOT registered as a player-issuable
    // order -- units enter it automatically (e.g. when attacked while
    // guarding), it's not something a player should pick from a menu.
}
