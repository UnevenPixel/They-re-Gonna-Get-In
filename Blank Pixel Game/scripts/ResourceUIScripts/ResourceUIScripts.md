# ResourceUIScripts

`sResourceIcons` lookup/translation (for embedding resource icons in Scribble-formatted text) and the player's resource bar HUD.

`sResourceIcons` is a 10-frame sprite (16x16, origin Middle Center), one icon per BASE resource, in this fixed order: wood, wheat, water, iron, gold, meat, bones, coal, weapons, coins. `xp` and `fateTokens` are deliberately NOT in this strip -- xp isn't spent the way the base 10 are (see `ProgressionScripts.gml`), and fateTokens are for a specific future mechanic, not general spending -- neither gets an icon here.

`global.resourceIconOrder` is a plain global array (not a `#macro`) so it's allocated exactly once at game start rather than re-allocated every time something reads it -- a `#macro` expanding to an array literal would build a fresh array at every reference site, including every frame inside `DrawResourceBar`'s loop.

## Icon lookup

`ResourceIconIndex(_resource)`: resolves a base-resource name to its frame index (0-9) in `sResourceIcons`, or -1 if `_resource` isn't a base resource (e.g. "xp", "fateTokens", or unrecognized).

`ResourceIconTag(_resource)`: translates a base-resource name into the Scribble inline-sprite tag that renders its icon (`"[sResourceIcons,N]"`, see Scribble's sprite-tag syntax). Returns `""` if the resource has no icon.

## Cost-to-text

`CostToScribbleText(_cost)`: builds a Scribble-formatted string for a `Cost` struct -- one `"[sResourceIcons,N]<amount>"` run per non-zero base resource, in `global.resourceIconOrder` order, separated by double spaces. Feed the result into `draw_text_scribble`/`draw_text_scribble_ext` to render a building/unit's cost with icons inline (e.g. a blueprint tooltip) instead of spelling out resource names. xp/fateTokens are skipped even if non-zero (no icon to show).

`CostToScribbleTextWithDiscount(_baseCost, _discountCost, _discountAvailable, _team)`: builds the blueprint hover's cost row -- one `"[icon]BasePrice (DiscountPrice)"` run per non-zero base resource (2026-07-09 request). Base price and the parenthesized discount price are colored INDEPENDENTLY:
- Base price renders in `PLOT_HOVER_BAD_COLOR_TAG` (red, `PlotHoverScripts.gml`) if `_team` can't currently afford that amount, default color otherwise.
- Discount price renders in `BLUEPRINT_DISCOUNT_UNAVAILABLE_COLOR_TAG` (dark gray, `BlueprintScripts.gml`) whenever `_discountAvailable` is false -- i.e. no currently open plot would actually grant this building's discount, so the number is purely informational/theoretical right now, regardless of affordability. Only when `_discountAvailable` is true does it fall back to the same red-if-unaffordable/default-otherwise check the base price uses.

## Resource bar HUD

A single row of all 10 base-resource icons with the team's current count next to each. No drag/click state (unlike `BlueprintController`), so `DrawResourceBar` is a plain function, not a struct -- call once per Draw GUI event.

`(RESOURCE_BAR_ORIGIN_X, RESOURCE_BAR_ORIGIN_Y)` is the CENTER of the first (Wood) icon (2026-07-05 request), since `sResourceIcons` is origin-centered, same as every other UI sprite this project draws by center. Each subsequent icon sits `RESOURCE_BAR_ICON_SPACING` px to the right, center to center. The count text is drawn `RESOURCE_BAR_TEXT_GAP` px to the right of the icon's right EDGE (icon center + half icon width + gap), vertically centered on the icon.

2026-07-11: resource counts use `fntResource` (was the default GML font) in `HOVER_CARD_TEXT_COLOR` (`HoverCardScripts.gml`) -- matches every hover-data card's text color, so the bar reads as part of the same UI language instead of a separate default-white style. Resets to the default font (`-1`) at the end -- nothing else in this project calls `draw_set_font`, so every other `draw_text` call this frame relies on whatever font was last set; leaving `fntResource` active would leak into anything drawn after this in the same Draw GUI event.

## API

- `global.resourceIconOrder`.
- `ResourceIconIndex(_resource)`, `ResourceIconTag(_resource)`.
- `CostToScribbleText(_cost)`, `CostToScribbleTextWithDiscount(_baseCost, _discountCost, _discountAvailable, _team)`.
- `RESOURCE_BAR_ORIGIN_X`, `RESOURCE_BAR_ORIGIN_Y`, `RESOURCE_BAR_ICON_SPACING`, `RESOURCE_BAR_TEXT_GAP`, `DrawResourceBar(_team)`.

## 2026-10-15: spend popups and production-rate popup

- **Spend popups:** `Purchase` (`Economy.gml`, the single spend choke point -- building placement, unit training, station/deploy gold) calls `ResourceSpendPopupAdd` for TEAM.PLAYER spends. `DrawResourceBar` draws each as red `-##` above its resource's count, floating up `RESOURCE_SPEND_POPUP_RISE` (60 GUI px) and fading over 2.5 REAL seconds (`delta_time`, not matchSpeed). Same-resource spends overlap rather than merge. Resources with no bar icon (xp, fateTokens) are skipped.
- **Rate popup:** hovering the bar's bottom 22 native px (44 GUI px at the 2x UI scale; x limited to the 757 native px sprite width) slides `sMainUIResourceBarPopup` (the request called it `saMainUIResourceBarPopop`) up from below to cover the strip, ~8 steps with smoothstep. Icons and text ride the slide; the counts become `GetTeamResourceRates` values formatted `N/s` -- sum of `productionRate` x (1 + garrison bonuses) over the team's `oResourceBuildingParent`s, dark gray at 0, green above. Spending is ignored. Slide progress (`global.resourceBarPopupK`) is advanced inside `DrawResourceBar`, so it is frame-based and runs while the HUD draws.
- Assumptions: popup drawn at x=0 at 2x (same width as `sMainUIBarBottom`); popup is opaque so counts underneath are hidden; depleting buildings are destroyed so they drop out of the rate automatically.
