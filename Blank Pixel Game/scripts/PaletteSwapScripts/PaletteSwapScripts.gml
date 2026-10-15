// Team-based unit recoloring via shPaletteSwap -- TEAM.ENEMY units only,
// TEAM.PLAYER draws unshaded. See PaletteSwapScripts.md.

#macro PALETTE_SWAP_MAX_ROWS  16   // must match MAX_PALETTE_ROWS in shPaletteSwap.fsh (kept in sync by convention only)
#macro PALETTE_SWAP_TOLERANCE 0.02 // per-pixel color-distance threshold for "counts as a palette match" -- tune here if a unit's colors look wrong in-engine

global.__paletteSwapSamplerFrom  = -1;
global.__paletteSwapSamplerTo    = -1;
global.__paletteSwapUniformFromRect = -1;
global.__paletteSwapUniformToRect   = -1;
global.__paletteSwapUniformSize  = -1;
global.__paletteSwapUniformTol   = -1;

/// @function PaletteSwapInit()
/// @description Caches shPaletteSwap's sampler/uniform handles once. Call once at game start -- wired into oGameControl's Create event alongside RegisterAllOrders()/RegisterAllUnitDefinitions()/RegisterAllBuildingDefinitions().
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
/// @description Draws _unit's current sprite/image_index, substituting colors via shPaletteSwap when _unit.palette is set AND its team isn't TEAM.PLAYER, otherwise a plain unshaded draw_self(). Call from oUnitParent/Draw_0.gml in place of a bare draw_self(). See .md.
/// @param {Id.Instance} _unit An oUnitParent instance (or descendant).
function PaletteSwapDrawUnit(_unit) {
    if (_unit.team == TEAM.PLAYER || _unit.palette == undefined) {
        with (_unit) draw_self();
        return;
    }

    PaletteSwapBegin(_unit.palette);
    with (_unit) draw_self();
    shader_reset();
}

/// @function PaletteSwapDrawSprite(_palette, _team, _sprite, _frame, _x, _y, _xscale)
/// @description Draws a plain sprite (no unit instance), recolored via shPaletteSwap when _palette is set AND _team isn't TEAM.PLAYER, otherwise unshaded.
/// @param {Asset.GMSprite|Undefined} _palette The unit's Pallete sprite, or undefined for none.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Asset.GMSprite} _sprite
/// @param {Real} _frame
/// @param {Real} _x
/// @param {Real} _y
/// @param {Real} _xscale 1 or -1.
function PaletteSwapDrawSprite(_palette, _team, _sprite, _frame, _x, _y, _xscale) {
    var _swap = (_team != TEAM.PLAYER && _palette != undefined);
    if (_swap) PaletteSwapBegin(_palette);
    draw_sprite_ext(_sprite, _frame, _x, _y, _xscale, 1, 0, c_white, 1);
    if (_swap) shader_reset();
}

/// @function PaletteSwapBegin(_palette)
/// @description Binds shPaletteSwap with _palette's from/to rows. Caller must shader_reset() after drawing. Shared setup extracted from PaletteSwapDrawUnit.
/// @param {Asset.GMSprite} _palette
function PaletteSwapBegin(_palette) {
    var _paletteSize = sprite_get_height(_palette); // one row per swappable color

    var _fromTex = sprite_get_texture(_palette, 0);
    var _toTex   = sprite_get_texture(_palette, 1);

    // LOAD-BEARING: indices [0..3] are (left, top, right, bottom); [4..7]
    // are unrelated trim-crop metadata, NOT a second UV corner. Using
    // [4]/[5] here previously collapsed every rect to zero-size and broke
    // enemy recoloring entirely -- see .md's 2026-07-11 fix note. Do not
    // revert to [4]/[5].
    var _fromUVs = sprite_get_uvs(_palette, 0);
    var _toUVs   = sprite_get_uvs(_palette, 1);

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
}
