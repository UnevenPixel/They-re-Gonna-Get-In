# StationScripts

Turns a live unit into an invisible, no-FSM garrison entry stored at its team's castle (and back out again), the gold cost/spend for doing so in either direction, and the passive bonuses currently-stationed units grant their team.

## Core idea

A stationed unit is an `oUnitStationed` instance: no sprite, no Step, no Draw, holding nothing but `team` and the live unit's preserved `UnitDataBlock` (`unitData` — see `UnitScripts.md`/`UnitScripts.gml`). Redeploying just hands that same struct back to a fresh live instance and re-runs `UnitApplyDefinition`. Station/deploy costs the same gold either direction (`UnitDefinition.stationCost`), and while a unit sits stationed it contributes to `GetStationedPassiveBonuses` for its team.

## API

### Stationing / redeploying

- `StationCastleCorner(_castle)` → `Vector2` — fixed storage point (castle's top-left bbox corner). Arbitrary since `oUnitStationed` never renders.
- `UnitBecomeStationed(_unit)` — creates the `oUnitStationed` at `_unit`'s team castle, hands over `_unit.unitData` as-is, destroys `_unit` directly (not via `ApplyDamage` — doesn't award "lost a unit" XP).
- `StationSpawnDirectly(_team, _unitType)` — builds a stationed unit with no live battlefield appearance at all (used when a training building sits on an inside plot — see `TrainingSpawnUnit`, `TrainingScripts.gml`). Spawns a real instance just long enough to get a correctly-stamped `UnitDataBlock`, then immediately stations it. Does NOT award `STRATEGIC_XP_FIRST_DEPLOYMENT`.
- `GetUnitStationCost(_unitType)` → `Struct.Cost` — wraps `UnitDefinition.stationCost` into a spendable `Cost` (`Economy.gml`). Same price both directions.
- `StationDeploySpawnPoint(_castle)` → `Vector2` — point just outside the castle's FRONT edge (whichever side actually faces the room center) for a redeployed unit to appear at.
- `DeployStationedUnit(_team, _unitType)` → `Bool` — redeploys ONE stationed unit of `_unitType` back onto the battlefield. Charges `GetUnitStationCost` via `Purchase` BEFORE anything else (unaffordable = pure no-op). Picks whichever matching `oUnitStationed` is found first if more than one exists (not a "healthiest"/"oldest" pick). New unit defaults to `"guard"` (no training-building context to default to `"defend"` against). `_unitType == undefined` is a safe no-op (lets a dismiss-click/placeholder-row pass straight through).

### Passive stationed bonuses (2026-07-12)

Every registered unit's "Stationed Effect" passive (`UnitDefinition.passives`) is flavor text; `UnitDefinition.stationedBonuses` is its structured, functional counterpart, and everything below is what actually reads it.

- `StationedBonuses()` — plain struct, one field per bonus type (all additive fractions, 0.05 = +5%):
  | Field | Contributed by |
  |---|---|
  | `allResourceProductionBonus` | Peasant |
  | `goldProductionBonus` | Bomb Goblin (gold only, stacks with the above) |
  | `unitHealthBonus` | Mud Golem + Soldier (shared pool) |
  | `unitDamageBonus` | Soldier |
  | `trainingSpeedBonus` | Knight |
  | `counts` | `{objectName: count}` map of what's stationed, for display |

  Archer's "Ranged attacks from the wall" is **not** represented here — that would mean a garrisoned unit actively firing on enemies (a new combat mechanic), not a stat multiplier. Explicitly out of scope as of 2026-07-12 (skipped per user clarification); flag before adding it later.

- `GetStationedPassiveBonuses(_team)` → `Struct.StationedBonuses` — scans every live `oUnitStationed` on `_team` once, sums each unit type's `UnitDefinition.stationedBonuses` entries (one linear stack per unit, matching each passive's own "(stacks per X stationed)" wording) via dynamic struct access (`entry.type + "Bonus"`). Recomputed fresh every call, never cached — same convention as `TrainingTypeLimit` (`TrainingScripts.gml`).

### Consumers

| Consumer | File | What it reads |
|---|---|---|
| Resource production rate | `BuildingUpdateProduction`, `BuildingDefinitions.gml` | `allResourceProductionBonus` (always) + `goldProductionBonus` (only when `productionResource == "gold"`) |
| Training progress rate | `TrainingUpdateQueue`, `TrainingScripts.gml` | `trainingSpeedBonus` |
| Unit max HP / attack damage | `UnitApplyDefinition`, `UnitDefinitions.gml` | `unitHealthBonus` / `unitDamageBonus`, baked in **once at spawn/redeploy time** |
| Castle hover panel | `CastleBonusHoverController`, `CastleBonusHoverScripts.gml` | Every field, for display |
| AI stationing policy | `AI_TryStationUnits`, `AIControl.gml` | Indirectly, via `stationCost` — stations units to generate these bonuses |

## Known assumptions / scope limits (flag if wrong)

- **HP/damage bonuses are NOT retroactive.** They're baked into `maxHealth`/`attackDamage` at the moment `UnitApplyDefinition` runs (unit spawn or redeploy) via `round(base * (1 + bonus))`. An already-live unit does not gain HP/damage the instant a new Mud Golem/Soldier gets stationed, and does not lose it if that unit is later deployed back out. Doing this fully dynamically would mean tracking base vs. effective stats separately and recomputing every live unit on every station/deploy change — a real systemic change to combat health tracking, deliberately out of scope for this pass.
- **Team must be final before `UnitApplyDefinition` runs**, or the wrong team's bonus gets baked in. Every spawn path that overrides `team` AFTER `instance_create_layer` (per the HAZARD comment in `oUnitParent/Create_0.gml`) must re-call `UnitApplyDefinition` afterward — `DeployStationedUnit` and `TrainingSpawnUnit` both do; `StationSpawnDirectly` doesn't need to (its live instance is destroyed immediately, before `maxHealth`/`attackDamage` are ever read).
- Knight's flavor text ("+5% unit production speed") doesn't say "(stacks per Knight stationed)" the way every other unit's does, but `GetStationedPassiveBonuses` always stacks linearly per unit by design — applied the same way for consistency rather than special-casing Knight to a flat one-time bonus.
