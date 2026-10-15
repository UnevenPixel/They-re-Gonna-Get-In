# UnitHoverScripts

A second, paired hover card showing a trained unit type's own stats/passives. Distinct from every other hover card in two ways:

1. It doesn't stand alone -- it always appears next to another card (a training building's blueprint-UI card, or its placed-building hover card), and the pair anchors away from the cursor as one combined group (see `PositionHoverCardPair`, `HoverCardScripts.gml`).
2. It can ALSO appear on its own, fixed in the GUI's top-left corner, whenever exactly one unit is selected (`UnitSelectHoverController` below) -- no mouse-anchoring, no dwell/fade, just instant show/hide tied to selection state ("it's not a hover tooltip, it's tied to a deliberate player action").

## Layout (shared by all three contexts)

- Top row: the unit's FULL-size sprite (`UnitDefinition.sprites.idle`, not `smallSprite` -- that's the Item/Unit Window's purpose-built icon, this wants the real in-world sprite) centered inside an `sHoverCardBuildingWindow`-sized box (the larger of the two icon-row windows), using the same bottom-anchor half-height offset `BuildingHoverExtras` uses for `smallSprite` -- `sprites.idle` is also bottom-center anchored, so the same math applies unchanged. "HP:"/"DMG:" stat text sits to the right of that box, vertically centered against it -- written as literal text labels, not icons like `BuildingHoverExtras`' `sUIHeart`/`sUIHammer`.
- Main body (`HoverCard`'s own `_body` slot): the unit's "Deployed Effect" passive description (`UnitHoverDeployedPassiveText`) -- falls back to the unit's flavor description if no such passive entry exists, so this never renders blank.
- Flavor window (`HoverCard`'s own `_flavor` slot, but with `HOVER_CARD_BODY_FONT` instead of the usual italic `HOVER_CARD_FLAVOR_FONT` -- see `HoverCard.Show()`'s `_flavorFont` param): "Station/Deploy Cost: [gold icon]\<amount\>" followed by the "Stationed Effect" passive description on its own line. Not italicized like every other card's flavor text -- it's repurposing that same window/position for different, non-flavor content.
- HP display differs by context, driven by `_liveUnit` (noone or an actual instance) rather than a separate bool -- there's no live unit instance to read from in either blueprint-UI or placed-training-building context (a training building isn't tied to one specific trained unit), so both naturally want "max HP only"; only the single-selection context has a real instance to read `GetCurrentHealth` off.
- Cost-to-produce row along the bottom is BLUEPRINT-ONLY -- neither the placed-training-building hover nor the single-selection card shows it (the unit/building already exists in both, nothing left to "produce"). Reuses the plain `CostToScribbleText` -- no plot-discount concept applies to training cost, that was placement-specific for buildings.

## API

- `UnitHoverFindPassive(_unitDef, _passiveName)` -- linear scan by `name` field on `_unitDef.passives` (still documented as inert, shape-not-designed-yet data). Returns undefined rather than throwing if no match.
- `UnitHoverDeployedPassiveText(_unitDef)`, `UnitHoverStationFlavorText(_unitDef)`.
- `UnitHoverExtras()` -- owns the top-row/cost-row Scribble elements. `Layout(_unitDef, _liveUnit, _showCostRow)` returns `{ topContentHeight, bottomContentHeight }`. `Draw(_card, _alpha)` call right after `_card.Draw(_alpha)`.
- `ShowUnitHoverCard(_card, _extras, _unitDef, _liveUnit, _showCostRow)` -- shared `Show()` call used by all 3 owners (`BuildingHoverController`, `BlueprintController`, `UnitSelectHoverController`), so identical body/flavor/font wiring doesn't drift across 3 copies.
- `UNIT_SELECT_HOVER_MARGIN_X/Y` -- fixed top-left GUI position, clear of the resource bar and XpBarWidget, no overlap check needed against either.
- `UnitSelectHoverController()` -- owns a `HoverCard` + `UnitHoverExtras`, shown fixed top-left whenever exactly one unit is selected, showing that unit's own live remaining/max HP, no cost row. `Step(_selectionController)`/`Draw()`.
