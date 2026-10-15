# BuildingDefinitions

Static, per-building-TYPE metadata (name, description, cost, sprite, resource production, training) used by the Blueprint UI for display/affordability, and by `BuildingApplyDefinition` to set up per-instance production/training state at Create time. Unlike `UnitDefinition` (`UnitDefinitions.gml`), most building data is never applied onto a shared generic instance -- every building type gets its own dedicated object (e.g. `oWheatField`), so there's no "generic instance that needs its stats filled in" the way `oPeasantUnit` needs `UnitApplyDefinition`. Production/training fields are the exception -- see `BuildingApplyDefinition`/`BuildingUpdateProduction` below.

## BuildingDefinition fields

| Field | Type | Notes |
|---|---|---|
| `name` | String | Display name, e.g. "Wheat Field". |
| `description` | String | Flavor/tooltip text. |
| `cost` | `Struct.Cost` | Placement cost (`Economy.gml`). |
| `sprite` | Sprite | Icon drawn in the Blueprint UI slot. |
| `productionResource` | String, optional | Key into the team's `global.resources` struct, e.g. `"wheat"`. Omitted (undefined) for buildings that don't produce anything. |
| `productionRate` | Real, optional | Units/sec at 1x match speed. Defaults to 0. |
| `trainsUnit` | GMObject, optional | Unit type this building trains. Omitted for non-training buildings. |
| `unitsPerBuilding` | Real, optional | How many `trainsUnit` units one live instance contributes to the team's per-type unit cap (`TrainingTypeLimit`, `TrainingScripts.gml`). Defaults to 0. |
| `trainCost` | `Struct.Cost`, optional | Cost paid per unit queued (separate from placement cost). Required if `trainsUnit` is set. |
| `trainTime` | Real, optional | Seconds per unit at 1x match speed. Defaults to 0. |
| `maxHealth` | Real, optional | Defaults to 200 -- an unbalanced placeholder; there's no sheet-sourced building-HP column yet. |
| `resourceLimit` | Real, optional | TOTAL lifetime units of `productionResource` this building may ever produce -- once reached, it depletes and self-destroys (`BuildingUpdateProduction`). Omitted (undefined) means unlimited production, per the "Resource_Infrastructure Buildings" doc, which only specifies limits for actual resource buildings. |
| `hitParticleColorDark`/`hitParticleColorBright` | Color, optional | Per-building override for `SpawnBuildingHitParticles`' (`GibScripts.gml`) color-interpolation range. Both undefined by default -- every building falls back to the shared gray until a future pass gives specific types their own colors ("we will make specific color coded particles for each building later, but default everything to shades of gray for now"). Checked independently, so setting only one still falls back to default for the other -- worth knowing if a future override looks half-applied. |

## Registry

`global.__buildingDefRegistry` keyed by `object_index`, mirroring `UnitDefinitions`' registry (same reasoning -- see that file). `RegisterBuildingDefinition`/`GetBuildingDefinition` are the set/get pair; `RegisterAllBuildingDefinitions()` registers every building type and is called once at game start (wired from `oGameControl`'s Create event), alongside `RegisterAllUnitDefinitions()`.

## Data provenance (RegisterAllBuildingDefinitions)

Cost/rate/maxHealth values are placeholders unless noted otherwise below -- tune freely.

- **Wheat Field**: cost corrected 2026-07-05 to the real sheet-sourced value (`water 20 + wood 10`) -- previously `wood 15 + coins 10`, which pre-dated the sheet's "Wheat Farm" row being consulted for this exact building.
- **Peasant Ward / Boom Hut / Bog Foundry / Barracks / Archery Range / Round Table**: build cost and `trainsUnit`/`unitsPerBuilding`/`trainCost`/`trainTime` are real, sheet-sourced values (Item Costs sheet for build cost, Unit Stats sheet for the rest) -- not placeholders. `maxHealth` for all of these IS still a placeholder (the sheet has no building-HP column).
- **Water Pump / Sawmill / Gold Mine / Iron Mine** (the remaining 4 tier-1 resource buildings, alongside Wheat Field above): cost and production rate are real, sheet-sourced values (Item Costs sheet, "Production Buildings" section). All 5 tier-1 resource buildings share `maxHealth = 100` and `resourceLimit = 300` -- both per the "Resource_Infrastructure Buildings" doc (which lists every Tier 1 resource building at "Resource Limit: 300"; maxHealth isn't in that doc either, but per explicit direction "each resource building should keep their 100 max health").

## BuildingApplyDefinition

Looks up a building's `BuildingDefinition` by `object_index` and sets up per-instance runtime state. Production fields (resource buildings) AND training fields (training buildings) are BOTH set unconditionally regardless of which kind of building this is -- a resource building simply gets `trainsUnit == undefined`/`trainQueue == 0` (which `TrainingUpdateQueue` treats as a no-op), and a training building gets `productionRate == 0` (which `BuildingUpdateProduction` treats as a no-op). Call once from a building's Create event, after `event_inherited()` (team/radius) and after `RegisterAllBuildingDefinitions()` has run at game start.

`maxHealth`/`damageTaken` mirror the pair units carry (`UnitApplyDefinition`, `UnitDefinitions.gml`), but `damageTaken` lives directly on the building instance rather than nested in a `unitData`-style wrapper -- buildings have no station/redeploy concept to preserve it across. `GetDamageTaken` (`UnitCombatHelpers.gml`) already knows to check for `unitData` first and fall back to this flat field.

## ApplyPlotBonuses

2026-07-07 "plot bonuses" request. Every building placed on a Distant/"far" plot (`PlotScripts.gml`/`oOuterPlotSpawner`) gets +50% `maxHealth` (`PLOT_BONUS_DISTANT_MULTIPLIER`), regardless of type. Production (resource) buildings ALSO get +50% `resourceLimit` -- no explicit building-type check is needed for this half, since training buildings never have a `resourceLimit` set (`BuildingApplyDefinition` leaves it undefined for them), so the bonus naturally no-ops there, exactly matching "only the health bonus applies to training buildings." No-ops entirely for Castle/Exterior/Blocked plots (`far == false`).

Placement-cost discounts (the OTHER half of the 2026-07-07 request) are handled separately -- see `GetPlacementCost`, `BlueprintScripts.gml`.

Must be called AFTER the building's own Create event has already run `BuildingApplyDefinition` -- GameMaker runs a new instance's Create event synchronously before `instance_create_layer` returns, so this is safe to call right after that returns. This function only multiplies whatever baseline `BuildingApplyDefinition` already set; it doesn't set up production/training state itself.

## BuildingUpdateProduction

Delta-time-based resource production, scaled by `global.matchSpeed`. Accumulates fractional progress on the instance (`productionAccumulator`) instead of adding a flat amount per frame, so production is frame-rate independent and never caps at "at most one whole unit per frame" -- a rate high enough to cross several whole units within a single frame (stacked bonuses, or a slow frame) still awards all of them, each triggering its own `PlayResourceProducedEffect` call, since resources are whole-integer-only (`Economy.gml`). No-op if the building has no production (`productionRate <= 0`). Wired from `oResourceBuildingParent`/`Step_0.gml`, so every resource building gets this automatically.

**Depletion** (2026-07-06, "Resource_Infrastructure Buildings" doc): if the building has a `resourceLimit`, production is capped at that TOTAL lifetime amount -- a tick that would push `producedTotal` past it is clamped to exactly fill the remaining room instead of overshooting. The instant the cap is reached, the building awards its team `ECONOMIC_XP_DEPLETION` XP (unblocking the XP doc's Economic XP category, which had nothing to hook into before this), frees its plot (`BuildingFreePlot`, `PlotScripts.gml`, so it's buildable/clickable again), and self-destroys via `instance_destroy` -- same bare removal already used for combat deaths (`ApplyDamage`, `UnitCombatHelpers.gml`), since there's no dedicated building-destroy cleanup step to mirror. No depletion VFX/SFX exists yet -- flag if one's wanted.

**Stationed bonus scaling** (2026-07-12): rate is scaled by the team's current stationed passive bonuses (`GetStationedPassiveBonuses`, `StationScripts.gml`) -- `allResourceProductionBonus` (Peasant) applies to every resource; `goldProductionBonus` (Bomb Goblin) applies only when `productionResource == "gold"` and stacks additively on top of the all-resource bonus. This is exactly the "stacked bonuses crossing several whole units in one frame" case the accumulator design above already anticipated.

## PlayResourceProducedEffect

Called exactly once per whole unit of resource produced (so more than once per frame at high rates, each with its own particle burst). Spawns `SpawnResourceProducedParticles` (`ResourceParticleScripts.gml`) at the building's position -- no sound/popup text yet, just the particles requested 2026-07-05.

## API

- `BuildingDefinition(_data)` constructor.
- `global.__buildingDefRegistry`, `RegisterBuildingDefinition(_objectIndex, _definition)`, `GetBuildingDefinition(_objectIndex)`, `RegisterAllBuildingDefinitions()`.
- `BuildingApplyDefinition(_building)`.
- `PLOT_BONUS_DISTANT_MULTIPLIER`, `ApplyPlotBonuses(_building, _plot)`.
- `ECONOMIC_XP_DEPLETION`, `BuildingUpdateProduction(_building)`.
- `PlayResourceProducedEffect(_building, _resource)`.
