# UnitStateStation

FSM state "station" -- walks a unit to its OWN team's castle front edge, then hands off to `UnitBecomeStationed` to convert it into a garrisoned unit.

**FLAGGED / load-bearing** -- part of the guard/defend/combat/attack/siege state wiring per CLAUDE.md. Any change here needs sign-off; this pass is comment-only, logic is untouched.

The "station" order (`OrderWiring.gml`) walks a unit to its own team's castle front edge (`CastleFrontEdgePoint`, `CastleScripts.gml`) -- there's no separate literal "gate" object anywhere in the project; this is the closest existing "castle access point" abstraction, and a comment already in `oUnitParent/Create_0.gml` calls this same edge "the castle gate" when describing the eventual redeploy path, so that interpretation is reused here.

On arrival (within `STATION_GATE_REACH`), hands off to `UnitBecomeStationed` (`StationScripts.gml`), which destroys the live unit and creates an invisible `oUnitStationed` holding its `UnitDataBlock`. Nothing after that call may touch `_unit` again.

Uses the same longer obstacle-avoidance feeler (120) `Siege_Step`'s ADVANCE phase uses (`UnitStateSiege.gml`) -- marching back to the castle can be just as long a trip across open ground as a siege advance, so the same snag-avoidance reasoning applies.

## API

- `STATION_GATE_REACH` -- mirrors `DEFEND_WAYPOINT_REACH` (`UnitStateDefend.gml`).
- `Station_Enter(_unit, _machine)`, `Station_Step(_unit, _machine)`.
