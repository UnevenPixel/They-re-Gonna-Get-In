# PaletteSwapScripts

Team-based unit recoloring via `shPaletteSwap` (`shaders/shPaletteSwap/`), 2026-07-10 request.

Each unit type has its own "Pallete" sprite (matching this project's existing spelling of that asset name, e.g. `sPeasantPallete` -- `UnitDefinition.palette`, `UnitDefinitions.gml`) with two 1px-wide frames: frame 0 lists the unit's ORIGINAL swappable colors (one texel per row), frame 1 lists the SAME row's replacement.

The player's units draw with their unedited sprites -- per the request, that IS frame 0's colors, i.e. no shader involved at all for `TEAM.PLAYER`. Only `TEAM.ENEMY` units get `shPaletteSwap` bound, substituting frame 1 in. See `PaletteSwapDrawUnit`, called from `oUnitParent/Draw_0.gml` in place of a bare `draw_self()`.

Units with no Pallete sprite yet (as of this writing: only Mud Golem -- see `UnitDefinitions.gml`'s `palette` field doc) fall through to an unshaded `draw_self()` on BOTH teams -- this degrades gracefully rather than crashing or defaulting to some placeholder recolor.

## PaletteSwapInit

Caches `shPaletteSwap`'s sampler/uniform handles once. Call once at game start -- wired into `oGameControl`'s Create event alongside `RegisterAllOrders()`/`RegisterAllUnitDefinitions()`/`RegisterAllBuildingDefinitions()`, mirroring this project's existing "resolve shader handles once, not every draw call" convention (`oOpeningCredits/Create_0.gml`) -- just cached globally here instead of per-instance, since every `TEAM.ENEMY` unit shares this one shader.

## PaletteSwapDrawUnit

Draws a unit's current sprite/`image_index`, substituting colors via `shPaletteSwap` when `_unit.palette` is set AND its team isn't `TEAM.PLAYER`, otherwise a plain unshaded `draw_self()` (exactly what every unit did before this system existed). Call from `oUnitParent/Draw_0.gml` in place of a bare `draw_self()`.

**Atlas UV note**: `sprite_get_uvs()` resolves each palette frame's actual sub-rectangle on its packed texture page -- NOT a raw 0-1 range -- since `shPaletteSwap.fsh` must sample a texture bound via `texture_set_stage()` using that same sub-rectangle (see that file's header comment for the full explanation and the "assumes not rotated on the page" caveat).

**2026-07-11 fix, load-bearing (see the inline `LOAD-BEARING` flag in the code)**: `sprite_get_uvs()`'s return array is NOT the 8-element TL/TR/BR/BL corner layout originally assumed here -- per GameMaker's actual docs it's a 4-element (left, top, right, bottom) rect at indices 0-3; indices 4-7 are UNRELATED trim-crop metadata (pixels trimmed from the sprite's left/top edges, and width/height fractions retained on the page), not a second UV corner. The original code read indices `[4]`/`[5]` as the bottom-right corner, which for an untrimmed sprite (this project's palette sprites have no transparent margin to trim) are simply 0 -- so every unit's palette rect collapsed to `(u0, v0, 0, 0)`, sampling far outside the sprite's actual region on the page and never matching any drawn pixel's color. This is why AI/enemy units were not being recolored at all. Fixed by using indices `[2]`/`[3]` (the real right/bottom) instead. **Do not revert to indices [4]/[5].**

Point-filtered, no-repeat texture stages (`gpu_set_tex_filter_ext`/`gpu_set_tex_repeat_ext`) -- this is a 1px-wide color LOOKUP strip, not a normal texture; bilinear filtering would blend adjacent palette rows together and corrupt the color match.

## API

- `PALETTE_SWAP_MAX_ROWS` (must match `MAX_PALETTE_ROWS` in `shPaletteSwap.fsh` -- kept in sync by convention only, no automatic check; today's real max is 7 rows, Soldier/Knight), `PALETTE_SWAP_TOLERANCE` (per-pixel color-distance threshold, generous enough to absorb 8-bit rounding ~0.004/channel, tight enough not to catch an unrelated authored color -- tune here if a unit's colors look wrong in-engine).
- `PaletteSwapInit()`.
- `PaletteSwapDrawUnit(_unit)`.

## 2026-10-14: shared setup extracted

Shader/uniform setup moved out of `PaletteSwapDrawUnit` into `PaletteSwapBegin(_palette)` (behavior unchanged; caller must `shader_reset()`). New `PaletteSwapDrawSprite(_palette, _team, _sprite, _frame, _x, _y, _xscale)` draws a bare sprite with the same enemy-only recolor -- used by the stationed castle roam.
