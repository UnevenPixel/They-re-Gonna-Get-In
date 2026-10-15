# CreditsOverlayScripts

The title screen's Credits sub-menu. Same `isOpen` + `Open()`/`Close()`/`Update()`/`Draw()` shape as `SettingsOverlay` -- `TitleMenu` holds a `CreditsOverlay` instance and delegates to it first whenever `isOpen`.

## Content

Full credits string supplied as Scribble markup (font/color tags + inline sprite portraits), built once at construction (content never changes). Font substitution: `fntDataCard` for headers, `FntDataCardItalics` for names/roles (note capital F -- the real asset name; a lowercase-f version doesn't exist and would silently fail to resolve as a Scribble font tag). Color tags (`c_white`/`c_lime`/etc.) and sprite tags (`sCreditsIcons`, `sConnorPowellCredit`, etc.) resolve automatically with zero registration -- Scribble auto-registers `c_*` constants and resolves unknown tags via `asset_get_index()`.

Panel height is measured off the built Scribble element's own `get_height()` (not guessed), clamped to fit the screen.

## API

- `CreditsOverlay()` -- plain struct, owner (`TitleMenu`) calls `Update()`/`Draw()`.
  - `Open()`, `Close()` -- Escape or clicking Back also closes.
