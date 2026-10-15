# DropDownMenuScripts

Shared sprite-based rendering/layout for every drop-down/panel menu (`OrderMenu`, `CastleGarrisonMenu`, `SelectionSummaryMenu`): `sDropDownMenuTop`/`sDropDownMenuMiddle`/`sDropDowmMenuBottom` (note: asset name has a pre-existing typo, "Dropdow**m**", used verbatim -- not renamed).

## Layout

1. TOP sprite -- title, centered text, never hoverable.
2. MIDDLE sprite (2 frames, hover/not) -- every option row above the bottom-most.
3. BOTTOM sprite (2 frames) -- the last/bottom-most row only.

Stacked seamlessly top-to-bottom, no gaps. All three share `DROPDOWN_MENU_SCALE` (2x) and native width (133, one shared width for the whole stack), top-left origin. Option text/icon starts `DROPDOWN_MENU_TEXT_PAD_X` (6 native px) in from the row's left edge.

## Positioning

- `PositionDropDownMenuFromClick(_mx, _my, _rowCount)` -- anchors away from the triggering click (quadrant-based, same logic as hover cards' `PositionHoverCardPair`), offset by `PLOT_HOVER_CURSOR_GAP`. Used by `OrderMenu`/`CastleGarrisonMenu`. NOT used by `ArmyLimitMenu` (fixed HUD-icon trigger, no click to anchor from) or `SelectionSummaryMenu` (fixed top-left panel).
- `PositionDropDownMenuCentered(_rowCount)` -- centered on screen, for menus opened by a keyboard shortcut rather than a click (`PauseMenu`).

## API

- `DropDownMenuWidth()`, `DropDownMenuTitleHeight()`, `DropDownMenuRowHeight(_isBottom)`, `DropDownMenuTotalHeight(_rowCount)` -- on-screen (scaled) sizing.
- `DropDownMenuHitTest(_x, _y, _rowCount, _mx, _my)` → row index (option rows only, title excluded) or -1.
- `DrawDropDownMenuTitle(_x, _y, _text)`, `DrawDropDownMenuRowBackground(_x, _y, _isBottom, _hovered)` -- callers draw their own row content (icon/text) starting at `DropDownMenuRowContentX(_x)`; content differs per menu.
