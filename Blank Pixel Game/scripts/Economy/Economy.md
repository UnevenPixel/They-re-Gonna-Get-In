# Economy

Core resource-cost primitives used by every purchasable thing in the game (buildings, units, blueprints): `ResourceCost` (one resource/amount pair), `Cost` (an aggregated struct summing an array of `ResourceCost` entries into one field per resource type), and the shared `Purchase`/`CanAfford`/`GetDiscountedCost` functions.

`Cost` carries a field for every resource in `global.resources` (wood, wheat, water, iron, gold, meat, bones, coal, weapons, coins) plus `xp`/`fateTokens` -- the latter two are included for consistency (`CanAfford`/`Purchase` walk `global.resources` generically) even though nothing is expected to cost XP directly; Fate Tokens are the more likely future spend once that system exists (see `ProgressionScripts.gml`).

`GetDiscountedCost(_cost, _fraction)` returns a NEW `Cost` with every field reduced by `_fraction` and rounded to the nearest whole unit (this project's resources are whole-integer-only) -- does not mutate `_cost`. Built for the plot-bonuses feature (see `GetPlacementCost`, `BlueprintScripts.gml`, which applies this when a building is placed on a plot that discounts its type).

`Purchase` deducts from `global.resources[_team]` and calls `AnalyticsRecordResourceSpent` for every resource actually spent (amount > 0), only if `CanAfford` passes first.

## API

- `ResourceCost(_resource, _amt)`.
- `Cost(_costs)` -- `CanAfford(_team)`.
- `GetDiscountedCost(_cost, _fraction)`.
- `Purchase(_costStruct, _team)`.
