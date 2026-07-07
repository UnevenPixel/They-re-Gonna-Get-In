precision mediump float;

varying vec2 v_texcoord;
varying vec4 v_colour;

// -----------------------------------------------------------
// shPaletteSwap -- 2026-07-10 request. Per-unit team recoloring: each unit
// type has its own "Pallete" sprite (sPeasantPallete, sArcherPallete, etc. --
// matching this project's existing spelling of that asset name) with two
// frames, 1px wide, one texel per row:
//   frame 0 -- the unit's ORIGINAL colors that are allowed to be swapped.
//   frame 1 -- the REPLACEMENT for the SAME row (row Y means the same color
//              slot in both frames).
// The player's units draw unshaded (frame-0 colors, i.e. as authored) --
// this shader is only ever bound for the AI opponent's units, substituting
// frame-1's colors in. See PaletteSwapDrawUnit (PaletteSwapScripts.gml) for
// the GML side of this.
//
// Both palette frames are bound here as two SEPARATE texture stages
// (u_paletteFrom/u_paletteTo) rather than one shared image, since GameMaker
// sprite frames aren't guaranteed to land next to each other on a texture
// page.
//
// ATLAS UV WARNING: u_paletteFromRect/u_paletteToRect are NOT simple 0-1
// sampling ranges -- GameMaker packs sprites onto shared texture pages, so a
// texture bound via texture_set_stage must be sampled using that sprite
// frame's OWN sub-rectangle within the page (sprite_get_uvs(), GML side),
// not raw 0-1 UVs. These four floats are (u0, v0, u1, v1) -- the frame's
// top-left and bottom-right corners on its texture page, taken from
// sprite_get_uvs()'s indices [0,1,2,3] (GameMaker's actual documented
// (left,top,right,bottom) layout -- indices [4..7] are unrelated trim-crop
// metadata, NOT a second corner; an earlier version of PaletteSwapDrawUnit
// read [4]/[5] by mistake, which silently zeroed this rect for untrimmed
// sprites and broke recoloring entirely -- fixed 2026-07-11, see
// PaletteSwapScripts.gml). This assumes the palette sprite is NOT stored
// rotated on its page (GameMaker's default texture-packer behavior when
// "Allow sprite rotating" is off, which is this project's default) -- if
// that setting is ever enabled and a palette sprite happens to get packed
// rotated, this naive corner extraction will sample the wrong axis and
// colors will look scrambled. Flag if that happens in-engine.
//
// GLSL ES 1.0 loop-bound restriction (same reasoning as
// shDitherDissolve.fsh's bayer4x4 comment): the for-loop bound below MUST be
// a compile-time constant, so u_paletteSize (the REAL row count, which
// varies per unit -- 2/3/7/7 rows for Archer/Peasant/Soldier/Knight as of
// this writing) is checked with an early break instead of driving the loop
// bound directly. MAX_PALETTE_ROWS is a hard ceiling on how many distinct
// colors any one unit's palette can ever list -- 16 gives headroom over
// today's max of 7; bump this constant (and PALETTE_SWAP_MAX_ROWS in
// PaletteSwapScripts.gml, kept in sync by convention only -- there's no
// automatic check the two match) if a future unit needs more rows.
// -----------------------------------------------------------
#define MAX_PALETTE_ROWS 16

uniform sampler2D u_paletteFrom;
uniform sampler2D u_paletteTo;
uniform vec4      u_paletteFromRect; // (u0, v0, u1, v1) on the texture page
uniform vec4      u_paletteToRect;   // (u0, v0, u1, v1) on the texture page
uniform float     u_paletteSize;     // real row count for THIS unit's palette (<= MAX_PALETTE_ROWS)
uniform float     u_tolerance;       // per-pixel color distance still counted as a match (8-bit rounding tolerant, not loose enough to catch unrelated colors)

void main() {
    vec4 texel = texture2D(gm_BaseTexture, v_texcoord);

    if (texel.a < 0.01) {
        discard;
    }

    vec3 outColor = texel.rgb;

    for (int i = 0; i < MAX_PALETTE_ROWS; i++) {
        if (float(i) >= u_paletteSize) break;

        // Center of row i, remapped from the palette's LOCAL 0-1 space into
        // its actual sub-rectangle on the shared texture page.
        float t = (float(i) + 0.5) / u_paletteSize;

        vec2 fromUV = vec2(
            mix(u_paletteFromRect.x, u_paletteFromRect.z, 0.5),
            mix(u_paletteFromRect.y, u_paletteFromRect.w, t)
        );
        vec4 fromColor = texture2D(u_paletteFrom, fromUV);

        if (distance(texel.rgb, fromColor.rgb) < u_tolerance) {
            vec2 toUV = vec2(
                mix(u_paletteToRect.x, u_paletteToRect.z, 0.5),
                mix(u_paletteToRect.y, u_paletteToRect.w, t)
            );
            outColor = texture2D(u_paletteTo, toUV).rgb;
        }
    }

    gl_FragColor = vec4(outColor, texel.a) * v_colour;
}
