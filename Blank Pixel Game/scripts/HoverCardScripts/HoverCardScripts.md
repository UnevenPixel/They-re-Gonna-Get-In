# HoverCardScripts

General-purpose hover/tooltip data overlay: a name plate + a wrapped text body, plus an optional secondary "flavor text" region below the body. Auto-picks the smallest of 3 card sprites (`sHoverCardShort`/`Mid`/`Tall`) that fits whatever's currently shown. This is the base every specialized hover card builds on (`PlotHoverScripts.gml` first, then `BuildingHoverScripts.gml`, `UnitHoverScripts.gml`, `CastleBonusHoverScripts.gml`). Owner calls `Show()`/`Hide()` when hover state changes and `Draw()` once per Draw GUI event -- no `Step()`, purely static content.

Not tied to any specific data source (unit/building/event) -- it only knows a name, a body string, and an optional flavor string. A specialized overlay either wraps a `HoverCard` (calls its Show/Draw, then draws its own extra sprites at fixed offsets from the same x/y) or extends it directly.

## Scale convention

`HOVER_CARD_SCALE = 2` -- the card sprite and `sHoverCardDataWindow` render at 2x ("most UI items render at 2x," matches XpBarWidget/FateDrum). Text itself stays NATIVE (1x) glyph size -- no Scribble `.scale()` call on any text element. Only LAYOUT (positions, margins, wrap widths) scales by `HOVER_CARD_SCALE`, so native-sized glyphs sit correctly inside the visually-2x card. Every derived hover-card file (Building/Unit/CastleBonus/Plot) follows this same split.

## Sprites

All 3 card sprites (`sHoverCardShort`/`Mid`/`Tall`) share the same 133px native width and a top-left origin; only height differs (148/185/222 native). The top `HOVER_CARD_NAME_HEIGHT` (20 native) px of every card is a name plate baked into the art -- nothing else draws there.

`sHoverCardDataWindow`'s native width (121) exactly equals `HoverCardBodyWrapWidth()`'s native value (133 - 6*2), so the flavor window lines up flush with the body text's margins with no extra alignment math.

`sHoverCardBuildingWindow`/`sHoverCardTimer`/`sHoverCardUnitWindow` are the icon-row sprites used by `BuildingHoverScripts.gml`/`UnitHoverScripts.gml` -- registered here but not drawn by this file itself.

## Text and shadow

Every card uses Scribble instead of raw `draw_text_ext` specifically because `.wrap()`/`.get_height()` answer "does this fit in card X" ahead of drawing. `scribble(_string, _uniqueId)` is a cache lookup keyed on `(uniqueId + string)`, not a rebuild, so `Show()` just re-requests an element every call rather than mutating one in place (Scribble elements have no "change this text" setter). `global.__hoverCardNextId` gives each `HoverCard` instance a unique id so multiple simultaneous cards never collide in that cache.

All card text renders in `HOVER_CARD_TEXT_COLOR` (F1DEB6) with a 1px downward drop shadow via `DrawCardTextWithShadow()` -- a plain double-draw (shadow pass in `HOVER_CARD_SHADOW_COLOR`, main pass on top). The main pass blends with `c_white`, not `HOVER_CARD_TEXT_COLOR` -- Scribble's `.blend()` MULTIPLIES onto each glyph's baked-in color, so blending with the text color itself would double up (quietly darker/desaturated) and wash out any inline `[c_lime]`/`[c_red]` color-tagged run toward F1DEB6 instead of showing its real color. `c_white` is the multiplicative identity. The shadow pass is unaffected (black × anything is still black).

The name plate is horizontally centered; body/flavor text stay left-aligned.

## Extension points (topContentHeight / bottomContentHeight)

`Show()` accepts optional `_topContentHeight`/`_bottomContentHeight` (already-scaled on-screen px) so a specialized overlay can reserve space above the body text or below the flavor window for its own content, without touching any existing caller's call site (both default 0). The caller draws that content itself at `GetContentTopY()`/`GetContentBottomY()`. First used by `BuildingHoverScripts.gml`'s icon row (top) and blueprint cost row / training queue row (bottom, mutually exclusive with each other), then `UnitHoverScripts.gml`'s image+stat row (top) and cost row (bottom).

`_flavorFont` (added for `UnitHoverScripts.gml`) lets a caller override the flavor window's font -- defaults to the italic `HOVER_CARD_FLAVOR_FONT` so every original caller (plot/building/blueprint) is unaffected; the unit hover card repurposes that window for plain (non-italic) Station/Deploy Cost data instead of real flavor text.

## Card pairing

`PositionHoverCardPair()` positions a primary card (and optional secondary, e.g. a paired unit hover card) as one anchored group -- same quadrant-anchor-away-from-cursor + screen-edge clamp every single-card hover controller uses, but computed against the COMBINED width/height of both cards so the pair can't get clamped apart or pushed off-screen unevenly. Passing `_secondaryCard = noone` collapses this to exactly the original single-card math. `_secondaryAlwaysRight` (used by `BuildingHoverScripts.gml`'s training-building pairing) forces the secondary card to sit on the primary's right regardless of cursor quadrant, trading away the usual "primary nearest cursor" guarantee in the right-half-of-screen case.

## API

- `HoverCardScaledWidth()`, `HoverCardBodyWrapWidth()`, `HoverCardFlavorWrapWidth()` -- on-screen sizing helpers.
- `HoverCardRequiredHeight(_bodyHeight, _hasFlavor, _topContentHeight, _bottomContentHeight)`, `ChooseHoverCardSprite(_requiredHeight)` -- sizing/sprite-selection, used internally by `Show()`.
- `HOVER_CARD_PAIR_GAP`, `PositionHoverCardPair(...)` -- see Card pairing above.
- `DrawCardTextWithShadow(_element, _x, _y, _alpha)`.
- `HoverCard()` constructor -- `Show(_name, _body, _x, _y, _flavor, _topContentHeight, _bottomContentHeight, _flavorFont)`, `Hide()`, `GetWidth()`, `GetHeight()`, `GetContentTopY()`, `GetContentBottomY()`, `Draw(_alpha)`.

## Known assumptions / scope limits (flag if wrong)

- If content exceeds even `sHoverCardTall`, `Show()` sets `overflowed = true` but still draws at that size -- no truncation or scrolling exists.
- `HOVER_CARD_NAME_OFFSET_X` is currently unused (name is centered, not left-anchored) -- kept in case a future card variant wants the old behavior.
