# JSDoc / Feather header audit -- Script Assets

**Status: resolved.** Every function below has since had a full `@function`/`@param`/`@returns` header added (the vendored Scribble library was left untouched, as noted). This file is kept as a record of what the audit originally found. See the end of this document for a couple of real bugs the pass surfaced along the way.

Scanned 25 project script files under `scripts/` (24 contain at least one function; `Enumerators/Enumerators.gml` is enum-only). The vendored Scribble text library (`scribble_*` / `__scribble_*`, 118 files) was excluded -- it's third-party code, not maintained in this project.

- **148** total functions/methods found
- **46** have *no* doc comment at all -- Feather shows nothing on hover for these
- **99** have a doc block but are missing the `@function` tag CLAUDE.md requires
- **32** return a value but have no `@returns`/`@return` tag
- **44** are missing an `@param` entry for at least one declared parameter

Two separate problems here, worth treating differently:

1. **Zero-hover functions (46)** -- these genuinely show nothing when you hover in the IDE. This is the actionable list below.
2. **Missing `@function` tag (near-universal, 99/102 doc'd functions)** -- every documented function in this codebase uses `@param`/`@return` but never `@function`, and consistently writes `@return` instead of the `@returns` CLAUDE.md specifies. This reads as an established (if non-compliant) house style rather than scattered mistakes -- flagging per project convention rather than assuming it's intentional. Feather still shows the description/param/return info on hover without `@function`, so this is a compliance gap, not a functionality gap.

---

## Functions with no doc comment at all (fix first)

| File | Line | Function | Params |
|---|---|---|---|
| `Animation/Animation.gml` | 1 | `AnimationLibrary` | _idle, _walk, _attack, _special |
| `Economy/Economy.gml` | 1 | `ResourceCost` | _resource, _amt |
| `Economy/Economy.gml` | 8 | `Cost` | _costs |
| `Economy/Economy.gml` | 58 | `CanAfford` | _team |
| `Economy/Economy.gml` | 79 | `Puchase` | _costStruct, _team |
| `Math/Math.gml` | 92 | `GetAdd` | _other |
| `Math/Math.gml` | 96 | `GetSubtract` | _other |
| `Math/Math.gml` | 100 | `GetScale` | _scalar |
| `Math/Math.gml` | 104 | `GetDivide` | _scalar |
| `Math/Math.gml` | 108 | `GetMultiply` | _other |
| `Math/Math.gml` | 112 | `GetNegate` | -- |
| `Math/Math.gml` | 143 | `GetNormalize` | -- |
| `Math/Math.gml` | 159 | `GetClampLength` | _max |
| `Math/Math.gml` | 179 | `GetRotate` | _deg |
| `Math/Math.gml` | 192 | `GetLerp` | _other, _t |
| `Math/Math.gml` | 205 | `GetReflect` | _normal |
| `Math/Math.gml` | 314 | `ShapeRect` | _x1, _y1, _x2, _y2 |
| `Math/Math.gml` | 320 | `getCenter` | -- |
| `OrderMenu/OrderMenu.gml` | 5 | `OrderMenu` | -- |
| `OrderWiring/OrderWiring.gml` | 5 | `RegisterAllOrders` | -- |
| `UnitScripts/UnitScripts.gml` | 1 | `ChooseCombatTarget` | _unit |
| `UnitScripts/UnitScripts.gml` | 5 | `UnitDataBlock` | -- |
| `UnitStateAttackMelee/UnitStateAttackMelee.gml` | 29 | `Attack_Enter` | _unit, _machine |
| `UnitStateAttackMelee/UnitStateAttackMelee.gml` | 45 | `Attack_Step` | _unit, _machine |
| `UnitStateAttackMelee/UnitStateAttackMelee.gml` | 195 | `Attack_Exit` | _unit, _machine |
| `UnitStateCombat/UnitStateCombat.gml` | 5 | `Combat_Enter` | _unit, _machine |
| `UnitStateCombat/UnitStateCombat.gml` | 15 | `Combat_Step` | _unit, _machine |
| `UnitStateCombat/UnitStateCombat.gml` | 88 | `Combat_Exit` | _unit, _machine |
| `UnitStateDefend/UnitStateDefend.gml` | 44 | `Defend_Enter` | _unit, _machine |
| `UnitStateDefend/UnitStateDefend.gml` | 59 | `Defend_Step` | _unit, _machine |
| `UnitStateDefend/UnitStateDefend.gml` | 95 | `Defend_Exit` | _unit, _machine |
| `UnitStateGuard/UnitStateGuard.gml` | 84 | `Guard_Enter` | _unit, _machine |
| `UnitStateGuard/UnitStateGuard.gml` | 95 | `Guard_Step` | _unit, _machine |
| `UnitStateGuard/UnitStateGuard.gml` | 168 | `Guard_Draw` | _unit, _machine |
| `UnitStateGuard/UnitStateGuard.gml` | 178 | `Guard_Exit` | _unit, _machine |
| `UnitStateSiege/UnitStateSiege.gml` | 11 | `Siege_Enter` | _unit, _machine |
| `UnitStateSiege/UnitStateSiege.gml` | 30 | `Siege_Step` | _unit, _machine |
| `UnitStateSiege/UnitStateSiege.gml` | 209 | `Siege_Exit` | _unit, _machine |
| `draw_text_scribble/draw_text_scribble.gml` | 19 | `draw_text_scribble` | _x, _y, _string, _reveal |
| `draw_text_scribble_ext/draw_text_scribble_ext.gml` | 20 | `draw_text_scribble_ext` | _x, _y, _string, _width, _reveal |
| `string_height_scribble/string_height_scribble.gml` | 8 | `string_height_scribble` | _string |
| `string_height_scribble_ext/string_height_scribble_ext.gml` | 9 | `string_height_scribble_ext` | _string, _width |
| `string_length_scribble/string_length_scribble.gml` | 8 | `string_length_scribble` | _string |
| `string_width_scribble/string_width_scribble.gml` | 8 | `string_width_scribble` | _string |
| `string_width_scribble_ext/string_width_scribble_ext.gml` | 9 | `string_width_scribble_ext` | _string, _width |

Note: the seven `scribble`/`string_*_scribble`/`draw_text_scribble*` rows above are wrapper scripts in the vendored Scribble library. They're technically third-party, but unlike the `scribble_*`/`__scribble_*` internals they're the public API surface you'd actually call from your own code -- worth a header pass even though the rest of the library was excluded from this audit.

## Documented, but incomplete

| File | Line | Function | Missing @function | Missing @param | Missing @returns |
|---|---|---|---|---|---|
| `GatherScripts/GatherScripts.gml` | 12 | `GatherNearbyObstacles` | yes |  |  |
| `GatherScripts/GatherScripts.gml` | 38 | `GatherNearbyAllies` | yes |  |  |
| `GatherScripts/GatherScripts.gml` | 56 | `GetEnemyCastle` |  | _unit | yes |
| `GatherScripts/GatherScripts.gml` | 69 | `_FindNearestEnemyInSweep` | yes |  |  |
| `Math/Math.gml` | 4 | `Vector2` | yes |  | yes |
| `Math/Math.gml` | 13 | `Copy` | yes |  |  |
| `Math/Math.gml` | 20 | `Set` | yes |  |  |
| `Math/Math.gml` | 27 | `ToArray` | yes |  |  |
| `Math/Math.gml` | 32 | `toString` | yes |  |  |
| `Math/Math.gml` | 42 | `Add` | yes |  |  |
| `Math/Math.gml` | 50 | `Subtract` | yes |  |  |
| `Math/Math.gml` | 58 | `Scale` | yes |  |  |
| `Math/Math.gml` | 66 | `Divide` | yes |  |  |
| `Math/Math.gml` | 74 | `Multiply` | yes |  |  |
| `Math/Math.gml` | 81 | `Negate` | yes |  |  |
| `Math/Math.gml` | 121 | `Length` | yes |  |  |
| `Math/Math.gml` | 126 | `LengthSquared` | yes |  |  |
| `Math/Math.gml` | 131 | `Normalize` | yes |  |  |
| `Math/Math.gml` | 149 | `ClampLength` | yes |  |  |
| `Math/Math.gml` | 171 | `Rotate` | yes |  |  |
| `Math/Math.gml` | 186 | `Lerp` | yes |  |  |
| `Math/Math.gml` | 198 | `Reflect` | yes |  |  |
| `Math/Math.gml` | 215 | `Dot` | yes |  |  |
| `Math/Math.gml` | 221 | `Cross` | yes |  |  |
| `Math/Math.gml` | 227 | `Distance` | yes |  |  |
| `Math/Math.gml` | 233 | `DistanceSquared` | yes |  |  |
| `Math/Math.gml` | 240 | `Angle` | yes |  |  |
| `Math/Math.gml` | 246 | `AngleTo` | yes |  |  |
| `Math/Math.gml` | 253 | `Equals` | yes |  |  |
| `Math/Math.gml` | 259 | `IsZero` | yes |  |  |
| `Math/Math.gml` | 270 | `Vector2Zero` | yes |  |  |
| `Math/Math.gml` | 275 | `Vector2One` | yes |  |  |
| `Math/Math.gml` | 280 | `Vector2Up` | yes |  |  |
| `Math/Math.gml` | 285 | `Vector2Down` | yes |  |  |
| `Math/Math.gml` | 290 | `Vector2Left` | yes |  |  |
| `Math/Math.gml` | 295 | `Vector2Right` | yes |  |  |
| `Math/Math.gml` | 302 | `Vector2FromAngle` | yes |  |  |
| `Math/Math.gml` | 308 | `Vector2FromArray` | yes |  |  |
| `OrderMenu/OrderMenu.gml` | 17 | `Open` | yes |  |  |
| `OrderMenu/OrderMenu.gml` | 35 | `Close` | yes |  |  |
| `OrderMenu/OrderMenu.gml` | 47 | `Update` | yes |  |  |
| `OrderMenu/OrderMenu.gml` | 77 | `Draw` | yes |  |  |
| `StateMachine/StateMachine.gml` | 16 | `StateMachine` |  |  | yes |
| `StateMachine/StateMachine.gml` | 27 | `AddState` | yes |  |  |
| `StateMachine/StateMachine.gml` | 34 | `HasState` | yes |  |  |
| `StateMachine/StateMachine.gml` | 39 | `Current` | yes |  |  |
| `StateMachine/StateMachine.gml` | 45 | `Is` | yes |  |  |
| `StateMachine/StateMachine.gml` | 55 | `ChangeState` | yes |  |  |
| `StateMachine/StateMachine.gml` | 82 | `RevertToPrevious` | yes |  |  |
| `StateMachine/StateMachine.gml` | 91 | `Step` | yes |  |  |
| `StateMachine/StateMachine.gml` | 101 | `Draw` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 10 | `SteeringAgent` | yes |  | yes |
| `SteeringBehaviors/SteeringBehaviors.gml` | 24 | `Speed` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 29 | `Heading` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 40 | `ApplyKnockback` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 46 | `IsStaggered` | yes | _threshold |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 51 | `SyncToInstance` | yes | _inst |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 59 | `SyncFromInstance` | yes | _inst |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 69 | `SteeringController` | yes |  | yes |
| `SteeringBehaviors/SteeringBehaviors.gml` | 82 | `Begin` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 91 | `Add` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 104 | `Apply` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 143 | `Steering_Seek` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 157 | `Steering_Flee` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 174 | `Steering_Arrive` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 192 | `Steering_Pursue` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 205 | `Steering_Evade` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 221 | `Steering_Wander` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 243 | `Steering_Separation` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 277 | `Steering_Alignment` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 303 | `Steering_Cohesion` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 356 | `Steering_AvoidObstacles` | yes |  |  |
| `SteeringBehaviors/SteeringBehaviors.gml` | 418 | `Steering_Contain` | yes |  |  |
| `UnitCombatHelpers/UnitCombatHelpers.gml` | 9 | `UnitTryDealDamage` | yes |  |  |
| `UnitCombatHelpers/UnitCombatHelpers.gml` | 40 | `UnitAttackAnimComplete` | yes |  |  |
| `UnitCombatHelpers/UnitCombatHelpers.gml` | 52 | `UnitPursueTarget` | yes |  |  |
| `UnitCombatHelpers/UnitCombatHelpers.gml` | 82 | `UnitIdleInPlace` | yes |  |  |
| `UnitCombatHelpers/UnitCombatHelpers.gml` | 95 | `UnitBeginSwing` | yes |  |  |
| `UnitCombatHelpers/UnitCombatHelpers.gml` | 108 | `UnitEndSwing` | yes |  |  |
| `UnitScripts/UnitScripts.gml` | 34 | `UnitUpdateSprite` | yes |  |  |
| `UnitScripts/UnitScripts.gml` | 62 | `InitPlayArea` | yes |  |  |
| `UnitScripts/UnitScripts.gml` | 97 | `IssueOrderToUnits` | yes |  |  |
| `UnitSelection/UnitSelection.gml` | 18 | `Order` | yes |  |  |
| `UnitSelection/UnitSelection.gml` | 39 | `RegisterOrder` | yes |  |  |
| `UnitSelection/UnitSelection.gml` | 45 | `GetOrder` | yes |  |  |
| `UnitSelection/UnitSelection.gml` | 55 | `GetCommonOrders` | yes |  |  |
| `UnitSelection/UnitSelection.gml` | 97 | `SelectionController` | yes |  | yes |
| `UnitSelection/UnitSelection.gml` | 109 | `BeginDrag` | yes |  |  |
| `UnitSelection/UnitSelection.gml` | 120 | `EndDrag` | yes |  |  |
| `UnitSelection/UnitSelection.gml` | 156 | `GetDragRect` | yes |  |  |
| `UnitSelection/UnitSelection.gml` | 164 | `AvailableOrders` | yes |  |  |
| `UnitSelection/UnitSelection.gml` | 175 | `IssueOrder` | yes |  |  |
| `UnitSelection/UnitSelection.gml` | 197 | `BeginTargeting` | yes |  |  |
| `UnitSelection/UnitSelection.gml` | 206 | `CancelTargeting` | yes |  |  |
| `UnitSelection/UnitSelection.gml` | 217 | `UpdateTargeting` | yes |  |  |
| `UnitSelection/UnitSelection.gml` | 254 | `DrawDragBox` | yes |  |  |
| `UnitSelection/UnitSelection.gml` | 263 | `DrawTargetingCursor` | yes |  |  |
| `UnitStateAttackMelee/UnitStateAttackMelee.gml` | 14 | `NearestBuildingEdgePoint` | yes |  |  |
| `UnitStateDefend/UnitStateDefend.gml` | 9 | `DefendBuildingWaypoints` | yes |  |  |
| `UnitStateDefend/UnitStateDefend.gml` | 27 | `NearestWaypointIndex` | yes |  |  |
| `UnitStateGuard/UnitStateGuard.gml` | 23 | `GuardPickWaypoint` | yes |  |  |

## Fully compliant

- `StateMachine/StateMachine.gml:6` `State`

---

## Bugs found while writing headers (not fixed -- flagging for you)

Writing accurate `@param`/`@returns` docs meant reading every function's actual body, which turned up a few things unrelated to documentation:

1. **`UnitStateAttackMelee.gml:143`** calls `_FindNearestEnemy(_unit, _unit.attackAggroRadius)` -- this function doesn't exist anywhere in the project. The only related function is `_FindNearestEnemyInSweep(_unit, _castlePos, _radius)` in `GatherScripts.gml`, which takes three args and is the one `UnitStateSiege.gml` actually calls. This will throw a runtime error the first time a unit in "attack" reaches that aggro check (i.e. almost immediately). Looks like a rename that didn't get propagated to this call site.
2. **`UnitStateGuard.gml:40`** -- `if (variable_instance_exists(_unit,"team")) continue;` inside `GuardPickWaypoint`'s ally-scan loop. This checks `_unit` (the unit doing the picking) instead of `_other` (the candidate ally), and skips when the variable *exists* rather than when it's missing. As written, it `continue`s past every ally whenever `_unit` has a `team` variable -- which, given `oUnitParent`'s Create event, is always. That would make the "avoid already-claimed waypoints" logic silently never execute the claim check as intended -- worth a look.
3. Carried over from the code review: `oPeasantUnit`/`oUnitParent`'s `availableOrders` includes `"station"`, which is never registered in `RegisterAllOrders()` and is silently dropped from the order menu with no diagnostic.

None of these were touched -- they're state/order wiring, which is flagged as load-bearing.
