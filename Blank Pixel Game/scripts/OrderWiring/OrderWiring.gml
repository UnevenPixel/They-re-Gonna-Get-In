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
                // Guard against a unit that died between selection/order-
                // issue and this callback running -- see PruneDeadSelected
                // in UnitSelection.gml and NIGHTLY_REVIEW_2026-07-09.md §3.1.
                if (!instance_exists(_units[i])) continue;
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
    //
    // FLAG (FSM/order wiring -- CLAUDE.md calls this load-bearing): the
    // state a unit enters now depends on its UnitDefinition tags --
    // "ranged"-tagged units (currently just Archer) go to "attackRanged"
    // (UnitStateAttackRanged.gml, fires projectiles) instead of "attack"
    // (UnitStateAttackMelee.gml, instant melee hit). Both states expect the
    // exact same attackBuildingTarget contract, so this is the only line
    // that changed in this order's onIssue.
    RegisterOrder(new Order(
        "attack",
        "Attack Building",
        function(_units, _context) {
            for (var i = 0; i < array_length(_units); i++) {
                // Same dead-unit guard as "defend" above.
                if (!instance_exists(_units[i])) continue;
                _units[i].attackBuildingTarget = _context;
                var _state = UnitHasTag(_units[i], "ranged") ? "attackRanged" : "attack";
                _units[i].fsm.ChangeState(_state);
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
            // Same dead-unit guard as "defend"/"attack" above.
            if (!instance_exists(_units[i])) continue;
            _units[i].fsm.ChangeState("siege");
        }
    }));

    // "station" -- 2026-07-11: stationing is now built (UnitStateStation.gml
    // registers a real "station" state on every unit's StateMachine, see
    // oUnitParent/Create_0.gml). No target click needed, same as "siege" --
    // Station_Enter resolves the unit's own castle automatically.
    //
    // 2026-07-12: stationing now costs gold (UnitDefinition.stationCost,
    // via GetUnitStationCost -- StationScripts.gml). Issuing to multiple
    // selected units at once sorts them CHEAPEST FIRST, then walks the
    // sorted list purchasing + dispatching one at a time -- per the
    // request: "If multiple units are selected to station, and the player
    // can't afford to station all of them... selecting the cheapest
    // options to station, and do as many as the player can afford." A unit
    // whose Purchase fails is simply skipped (not dispatched, nothing
    // spent for it) and the loop continues rather than stopping outright --
    // today's cost is gold-only, so once the cheapest-remaining unit can't
    // be afforded nothing pricier after it can either, but continuing
    // (instead of breaking) keeps this correct if stationCost ever grows
    // into a multi-resource Cost.
    RegisterOrder(new Order("station", "Station", function(_units, _context) {
        var _alive = [];
        for (var i = 0; i < array_length(_units); i++) {
            if (instance_exists(_units[i])) array_push(_alive, _units[i]);
        }

        array_sort(_alive, function(_a, _b) {
            return GetUnitDefinition(_a.object_index).stationCost - GetUnitDefinition(_b.object_index).stationCost;
        });

        for (var i = 0; i < array_length(_alive); i++) {
            var _unit = _alive[i];
            if (!Purchase(GetUnitStationCost(_unit.object_index), _unit.team)) {
                show_debug_message($"station order: team {_unit.team} can't afford to station {object_get_name(_unit.object_index)} ({GetUnitDefinition(_unit.object_index).stationCost}g) -- skipping.");
                continue;
            }
            _unit.fsm.ChangeState("station");
        }
    }));

    // "combat" is intentionally NOT registered as a player-issuable
    // order -- units enter it automatically (e.g. when attacked while
    // guarding), it's not something a player should pick from a menu.
}
