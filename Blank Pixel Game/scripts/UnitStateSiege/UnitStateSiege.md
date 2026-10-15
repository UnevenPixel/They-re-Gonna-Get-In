# UnitStateSiege

FSM state "siege" -- marches on the enemy castle, cycling ADVANCE -> ASSAULT -> SWING -> RECOVER, with an ENGAGE_GUARD sub-phase that breaks off to fight any enemy unit swept up within `siegeSweepRadius` (or the tighter `attackAggroRadius` once assaulting) before resuming the castle.

**FLAGGED / load-bearing** -- part of the guard/defend/combat/attack/siege state wiring per CLAUDE.md. Any change here needs sign-off; this pass is comment-only, logic is untouched.

## Castle edge targeting

Uses `CastleFrontEdgePoint` (`CastleScripts.gml`), NOT the generic `NearestBuildingEdgePoint` (`UnitStateAttackMelee.gml`) -- that function assumes every building is 48x48 (`ATTACK_BUILDING_HALF`), which a castle is nowhere close to, and clamps against all 4 sides rather than just the one facing the room's center. Siege targets anywhere along the castle's actual front edge (its real bbox, whichever side faces the room's middle) instead of a single fixed point clamped into a wrong-sized box.

## ENGAGE_GUARD phase

Unlike attack's DEFENDER phase, this is entered PROACTIVELY (the unit went looking for this fight via a sweep, not a reactive aggro check), so it commits until the guard is dead or fully retreats -- both out of `siegeSweepRadius` AND retreating away from the castle (not just a threat that briefly stepped outside the radius) -- rather than returning to the castle the moment the guard leaves aggro range.

## ADVANCE phase

Sweeps for the nearest enemy unit within `siegeSweepRadius` every frame; if found, breaks off to ENGAGE_GUARD. Uses a longer obstacle-avoidance feeler (120, vs. the default 80 in `UnitPursueTarget`) -- this is a long march across open ground toward the castle, so spotting a building earlier gives the avoidance steering more room to curve smoothly around it instead of reacting at the last moment right against a corner, which is what tends to snag a unit in place. This fixed a real report ("units have a chance to get caught on buildings" during siege).

## ASSAULT phase

The unit is at the castle walls. Guard sweeping still runs here but at the tighter `attackAggroRadius` (defaulting to 96 if unset) -- the unit shouldn't chase a guard halfway across the map when it's already at the walls. If pushed back from the edge (knockback, pathing), closes the gap again rather than swinging from too far away.

## SWING phase

Never interrupted -- once a swing on the castle starts, it always completes, unlike attack's DEFENDER interrupt logic.

## RECOVER phase

Keeps checking for guards during cooldown -- a fresh wave of defenders arriving during recovery is engaged before the next swing rather than letting them pile up unchecked.

## API

- `SIEGE_PHASE_ADVANCE/ENGAGE_GUARD/ASSAULT/SWING/RECOVER`.
- `Siege_Enter(_unit, _machine)`, `Siege_Step(_unit, _machine)`, `Siege_Exit(_unit, _machine)`.
