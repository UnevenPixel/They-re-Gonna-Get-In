// -----------------------------------------------------------
// PaletteSwapScripts -- team-based unit recoloring via shPaletteSwap
// (shaders/shPaletteSwap/), 2026-07-10 request.
//
// Each unit type has its own "Pallete" sprite (matching this project's
// existing spelling of that asset name, e.g. sPeasantPallete --
// UnitDefinition.palette, UnitDefinitions.gml) with two 1px-wide frames:
// frame 0 lists the unit's ORIGINAL swappable colors (one texel per row),
// frame 1 lists the SAME row's replacement.
//
// The player's units draw with their unedited sprites -- per the request,
// that IS frame 0's colors, i.e. no shader involved at all for TEAM.PLAYER.
// Only TEAM.ENEMY units get shPaletteSwap bound, substituting frame 1 in.
// See PaletteSwapDrawUnit, called from oUnitParent/Draw_0.gml in place of a
// bare draw_self().
//
// Units with no Pallete sprite yet (as of this writing: only Mud Golem --
// see UnitDefinitions.gml's palette field doc) fall through to an unshaded
// draw_self() on BOTH teams -- this degrades gracefully rather than
// crashing or defaulting to some placeholder recolor.
// -----------------------------------------------------------

#macro PALETTE_SWAP_MAX_ROWS  16   // MUST match MAX_PALETTE_ROWS in shPaletteSwap.fsh -- kept in sync by convention only, no automatic check. See that file's comment for why this is a hard ceiling (today's real max is 7 rows, Soldier/Knight).
#macro PALETTE_SWAP_TOLERANCE 0.02 // per-pixel color-distance threshold for "counts as a palette match" (GLSL distance() over 0-1 RGB) -- generous enough to absorb 8-bit rounding (~0.004/channel), tight enough not to catch an unrelated authored color. Tune here if a unit's colors look wrong in-engine.

global.__paletteSwapSamplerFrom  = -1;
global.__paletteSwapSamplerTo    = -1;
global.__paletteSwapUniformFromRect = -1;
global.__paletteSwapUniformToRect   = -1;
global.__paletteSwapUniformSize  = -1;
global.__paletteSwapUniformTol   = -1;

/// @function PaletteSwapInit()
/// @description Caches shPaletteSwap's sampler/uniform handles once. Call
///        once at game start -- wired into oGameControl's Create event
///        alongside RegisterAllOrders()/RegisterAllUnitDefinitions()/
///        RegisterAllBuildingDefinitions(), mirroring this project's
///        existing "resolve shader handles once, not every draw call"
///        convention (oOpeningCredits/Create_0.gml) -- just cached globally
///        here instead of per-instance, since every TEAM.ENEMY unit shares
///        this one shader.
function PaletteSwapInit() {
    global.__paletteSwapSamplerFrom     = shader_get_sampler_index(shPaletteSwap, "u_paletteFrom");
    global.__paletteSwapSamplerTo       = shader_get_sampler_index(shPaletteSwap, "u_paletteTo");
    global.__paletteSwapUniformFromRect = shader_get_uniform(shPaletteSwap, "u_paletteFromRect");
    global.__paletteSwapUniformToRect   = shader_get_uniform(shPaletteSwap, "u_paletteToRect");
    global.__paletteSwapUniformSize     = shader_get_uniform(shPaletteSwap, "u_paletteSize");
    global.__paletteSwapUniformTol      = shader_get_uniform(shPaletteSwap, "u_tolerance");

    if (global.__paletteSwapSamplerFrom < 0 || global.__paletteSwapSamplerTo < 0
        || global.__paletteSwapUniformFromRect == -1 || global.__paletteSwapUniformToRect == -1
        || global.__paletteSwapUniformSize == -1 || global.__paletteSwapUniformTol == -1) {
        show_debug_message("[PaletteSwapInit] WARNING: one or more shPaletteSwap handles not found - check shPaletteSwap.fsh uniform/sampler names");
    }
}

/// @function PaletteSwapDrawUnit(_unit)
/// @description Draws _unit's current sprite/image_index -- substituting
///        colors via shPaletteSwap when _unit.palette is set AND its team
///        isn't TEAM.PLAYER, otherwise a plain unshaded draw_self() (exactly
///        what every unit did before this system existed). Call from
///        oUnitParent/Draw_0.gml in place of a bare draw_self().
///
///        ATLAS UV NOTE: sprite_get_uvs() resolves each palette frame's
///        actual sub-rectangle on its packed texture page -- NOT a raw 0-1
///        range -- since shPaletteSwap.fsh must sample a texture bound via
///        texture_set_stage() using that same sub-rectangle (see that
///        file's header comment for the full explanation and the
///        "assumes not rotated on the page" caveat).
///
///        2026-07-11 FIX: sprite_get_uvs()'s return array is NOT the
///        8-element TL/TR/BR/BL corner layout originally assumed here --
///        per GameMaker's actual docs it's a 4-element (left, top, right,
///        bottom) rect at indices 0-3; indices 4-7 are UNRELATED trim-crop
///        metadata (pixels trimmed from the sprite's left/top edges, and
///        width/height fractions retained on the page), not a second UV
///        corner. The original code read indices [4]/[5] as the
///        bottom-right corner, which for an untrimmed sprite (this
///        project's palette sprites have no transparent margin to trim)
///        are simply 0 -- so every unit's palette rect collapsed to
///        (u0, v0, 0, 0), sampling far outside the sprite's actual region
///        on the page and never matching any drawn pixel's color. This is
///        why AI/enemy units were not being recolored at all. Fixed by
///        using indices [2]/[3] (the real right/bottom) instead.
/// @param {Id.Instance} _unit An oUnitParent instance (or descendant).
function PaletteSwapDrawUnit(_unit) {
    if (_unit.team == TEAM.PLAYER || _unit.palette == undefined) {
        with (_unit) draw_self();
        return;
    }

    var _paletteSize = sprite_get_height(_unit.palette); // one row per swappable color

    var _fromTex = sprite_get_texture(_unit.palette, 0);
    var _toTex   = sprite_get_texture(_unit.palette, 1);

    var _fromUVs = sprite_get_uvs(_unit.palette, 0); // [0]=left,[1]=top,[2]=right,[3]=bottom (GameMaker's actual documented layout -- see fix note above; [4..7] are trim-crop metadata, NOT a second corner)
    var _toUVs   = sprite_get_uvs(_unit.palette, 1);

    shader_set(shPaletteSwap);

    texture_set_stage(global.__paletteSwapSamplerFrom, _fromTex);
    texture_set_stage(global.__paletteSwapSamplerTo,   _toTex);

    // Point-filtered, no repeat -- this is a 1px-wide color LOOKUP strip,
    // not a normal texture; bilinear filtering would blend adjacent palette
    // rows together and corrupt the color match.
    gpu_set_tex_filter_ext(global.__paletteSwapSamplerFrom, false);
    gpu_set_tex_filter_ext(global.__paletteSwapSamplerTo,   false);
    gpu_set_tex_repeat_ext(global.__paletteSwapSamplerFrom, false);
    gpu_set_tex_repeat_ext(global.__paletteSwapSamplerTo,   false);

    shader_set_uniform_f(global.__paletteSwapUniformFromRect, _fromUVs[0], _fromUVs[1], _fromUVs[2], _fromUVs[3]);
    shader_set_uniform_f(global.__paletteSwapUniformToRect,   _toUVs[0],   _toUVs[1],   _toUVs[2],   _toUVs[3]);
    shader_set_uniform_f(global.__paletteSwapUniformSize, _paletteSize);
    shader_set_uniform_f(global.__paletteSwapUniformTol,  PALETTE_SWAP_TOLERANCE);

    with (_unit) draw_self();

    shader_reset();
}
