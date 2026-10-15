# OrderWiring

`RegisterAllOrders()` registers every player-issuable `Order` with the global order registry (`RegisterOrder`, `UnitSelection.gml`). Call once at game start -- wired from `oGameControl`'s Create event.

**Load-bearing note** (per CLAUDE.md -- this file drives `fsm.ChangeState` for guard/defend/attack/siege/station, flag before further changes): every order's `onIssue` guards against a unit that died between selection and this callback running (`instance_exists` check) -- see `PruneDeadSelected` in `UnitSelection.gml` and `NIGHTLY_REVIEW_2026-07-09.md` §3.1.

## guard

Default `onIssue`: `fsm.ChangeState("guard")`. No target needed.

## defend

`requiresTarget = true` (menu click starts targeting mode). Only own-team buildings are valid targets -- `_team` is the ordering side's own team, passed through by whatever's driving targeting (`SelectionController.UpdateTargeting`), so this works correctly regardless of which side issues "defend" (no hardcoded `TEAM.PLAYER` assumption).

**2026-07-13 bugfix, load-bearing**: `onIssue` calls `fsm.ChangeState("defend", true)` with `_force = true`. Without forcing, `ChangeState` no-ops if the unit is ALREADY in "defend" (`StateMachine.gml`) -- reassigning a unit that's already defending one building to a DIFFERENT one (e.g. `AI_Defending_Step` redirecting defenders to a newly-threatened building) would silently do nothing: `defendTarget` updates, but `Defend_Enter` never re-runs to rebuild the patrol waypoints from it, so the unit keeps patrolling its OLD building forever. Forcing re-entry makes every "defend" order -- reassignment or not -- actually (re)commit to whatever target was just set. This pairs with `Defend_Exit`'s own fix (`UnitStateDefend.gml`, see that file's doc comment) -- `Defend_Exit` no longer clears `defendTarget` on exit, which would otherwise wipe the new target just assigned above before `Defend_Enter` ever reads it. **Do not remove the `true` force argument or reintroduce a `defendTarget` clear in `Defend_Exit` without re-reading both halves of this fix together.**

## attack

`requiresTarget = true`. Only enemy (non-own-team) buildings are valid targets -- `_instance.team != _team` rather than `== TEAM.ENEMY`, same `_team`-passthrough fix as "defend", so this reads correctly no matter which side issues "attack".

**Load-bearing routing note**: the state a unit enters depends on its `UnitDefinition` tags -- "ranged"-tagged units (currently just Archer) go to "attackRanged" (`UnitStateAttackRanged.gml`, fires projectiles) instead of "attack" (`UnitStateAttackMelee.gml`, instant melee hit). Both states expect the exact same `attackBuildingTarget` contract, so this tag check is the only line that differs from a plain single-state dispatch. **Do not collapse this back to a single state without re-checking both attack states' contracts.**

## siege

No target click needed -- `GetEnemyCastle()` finds the castle automatically inside `Siege_Enter`. `onIssue` just flips every alive unit's state to "siege".

## station

2026-07-11: stationing is a real "station" state on every unit's `StateMachine` (`UnitStateStation.gml`, registered from `oUnitParent/Create_0.gml`). No target click needed, same as "siege" -- `Station_Enter` resolves the unit's own castle automatically.

2026-07-12: stationing costs gold (`UnitDefinition.stationCost`, via `GetUnitStationCost`, `StationScripts.gml`). Issuing to multiple selected units at once sorts them CHEAPEST FIRST, then walks the sorted list purchasing + dispatching one at a time -- per the request: "If multiple units are selected to station, and the player can't afford to station all of them... select the cheapest options to station, and do as many as the player can afford." A unit whose `Purchase` fails is skipped (not dispatched, nothing spent for it) and the loop CONTINUES rather than stopping outright -- today's cost is gold-only, so once the cheapest-remaining unit can't be afforded nothing pricier after it can either, but continuing (instead of breaking) keeps this correct if `stationCost` ever grows into a multi-resource `Cost`.

## combat

Intentionally NOT registered as a player-issuable order -- units enter it automatically (e.g. when attacked while guarding), it's not something a player should pick from a menu.

## API

- `RegisterAllOrders()` -- registers `"guard"`, `"defend"`, `"attack"`, `"siege"`, `"station"`.
