// -----------------------------------------------------------
// Order registration (call once, e.g. a game-start script)
// -----------------------------------------------------------

/// @function RegisterAllOrders()
/// @description Registers every player-issuable Order with the global order
///        registry (see RegisterOrder in UnitSelection.gml). Call once at game
///        start -- currently wired from oGameControl's Create event.
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
        function(_instance, _team) {
            // Only own-team buildings are valid defend targets. _team is
            // the ordering side's own team, passed through by whatever's
            // driving targeting (see SelectionController.UpdateTargeting) --
            // no more hardcoded TEAM.PLAYER assumption, so this now works
            // the same regardless of which side issues "defend".
            return object_is_ancestor(_instance.object_index, oBuildingParent)
                && _instance.team == _team;
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
        function(_instance, _team) {
            // Only enemy (non-own-team) buildings are valid attack targets.
            // Same _team-passthrough fix as "defend" above -- "!= _team"
            // rather than "== TEAM.ENEMY" so this reads correctly no matter
            // which side is issuing "attack".
            return object_is_ancestor(_instance.object_index, oBuildingParent)
                && _instance.team != _team;
        }
    ));

    RegisterOrder(new Order("siege", "Siege Castle", function(_units, _context) {
        // No target click needed -- GetEnemyCastle() finds the castle
        // automatically inside Siege_Enter. Just flip the state.
        for (var i = 0; i < array_length(_units); i++) {
            _units[i].fsm.ChangeState("siege");
        }
    }));

    // "station" is registered so it legally appears in availableOrders /
    // the order menu (and doesn't trip GetCommonOrders' registry lookup),
    // but it's an intentional no-op for now -- stationing units inside
    // castle walls depends on castle-interior placement, which isn't
    // built yet. Deliberately NOT using the default onIssue (which would
    // call fsm.ChangeState("station") against a state that doesn't
    // exist on any unit's StateMachine, spamming an "unregistered state"
    // debug message on every click). Replace this stub once stationing
    // is designed.
    RegisterOrder(new Order("station", "Station", function(_units, _context) {
        // Intentionally does nothing yet.
    }));

    // "combat" is intentionally NOT registered as a player-issuable
    // order -- units enter it automatically (e.g. when attacked while
    // guarding), it's not something a player should pick from a menu.
}
