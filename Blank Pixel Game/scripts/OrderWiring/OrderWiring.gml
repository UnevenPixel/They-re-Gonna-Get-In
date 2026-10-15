// Registers every player-issuable Order (guard/defend/attack/siege/station)
// with the global order registry. LOAD-BEARING: drives fsm.ChangeState for
// guard/defend/attack/siege/station -- flag before changing (CLAUDE.md).
// See OrderWiring.md.

/// @function RegisterAllOrders()
/// @description Registers every player-issuable Order (see RegisterOrder, UnitSelection.gml). Call once at game start -- wired from oGameControl's Create event. See .md.
function RegisterAllOrders() {
    RegisterOrder(new Order("guard", "Guard"));   // default onIssue: fsm.ChangeState("guard")
    RegisterOrder(new Order(
        "defend",
        "Defend Building",
        function(_units, _context) {
            // _context is the clicked building instance.
            for (var i = 0; i < array_length(_units); i++) {
                if (!instance_exists(_units[i])) continue;
                _units[i].defendTarget = _context;
                // LOAD-BEARING: _force = true is required so a unit already
                // in "defend" actually re-enters on reassignment -- see .md
                // (pairs with Defend_Exit's own fix, UnitStateDefend.gml).
                // Do not remove without re-reading both halves together.
                _units[i].fsm.ChangeState("defend", true);
            }
        },
        true, // requiresTarget = true -- menu click starts targeting mode
        function(_instance, _team) {
            // Only own-team buildings are valid defend targets.
            return object_is_ancestor(_instance.object_index, oBuildingParent)
                && _instance.team == _team;
        }
    ));

    // LOAD-BEARING: state routing depends on UnitDefinition tags -- see .md.
    // Do not collapse to a single state without re-checking both attack
    // states' attackBuildingTarget contracts.
    RegisterOrder(new Order(
        "attack",
        "Attack Building",
        function(_units, _context) {
            for (var i = 0; i < array_length(_units); i++) {
                if (!instance_exists(_units[i])) continue;
                _units[i].attackBuildingTarget = _context;
                var _state = UnitHasTag(_units[i], "ranged") ? "attackRanged" : "attack";
                _units[i].fsm.ChangeState(_state);
            }
        },
        true, // requiresTarget
        function(_instance, _team) {
            // Only enemy (non-own-team) buildings are valid attack targets.
            return object_is_ancestor(_instance.object_index, oBuildingParent)
                && _instance.team != _team;
        }
    ));

    RegisterOrder(new Order("siege", "Siege Castle", function(_units, _context) {
        // No target click needed -- GetEnemyCastle() finds the castle
        // automatically inside Siege_Enter. Just flip the state.
        for (var i = 0; i < array_length(_units); i++) {
            if (!instance_exists(_units[i])) continue;
            _units[i].fsm.ChangeState("siege");
        }
    }));

    /// station costs gold and, when issued to multiple units at once, sorts
    /// cheapest-first and dispatches as many as affordable -- see .md.
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

    // "combat" is intentionally NOT registered as a player-issuable order --
    // units enter it automatically, not something a player picks from a menu.
}
