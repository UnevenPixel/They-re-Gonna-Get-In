precision mediump float;

varying vec2 v_texcoord;
varying vec4 v_colour;

// -----------------------------------------------------------
// shFateEngineGradientTint -- 2026-08-14 request: fade in a tint over the
// Fate Engine's play area (everything above the UI bar edge) when the
// overlay opens, strongest in the top-left corner and weakest in the
// bottom-right. Replaces the overlay's old flat, uniform 0.75-alpha dim
// rectangle with an animated diagonal gradient -- see
// FateEngineOverlayScripts.md.
//
// Applied to a plain draw_rectangle() spanning the play area, NOT a sprite
// draw -- v_texcoord is GameMaker's standard 0..1-across-the-primitive UV
// for an untextured primitive draw, so (unlike shFlagWave.fsh/
// shPaletteSwap.fsh, which sample a sprite packed onto a shared texture
// page) no atlas sub-rect correction is needed here -- there's no texture
// being sampled at all, this shader only ever reads v_texcoord/v_colour.
//
// u_alpha is the overlay's own intro-fade progress (0..1, GML-side via
// FateEngineOverlay's _IntroGradientProgress()) -- multiplies the
// per-pixel diagonal falloff below, so the WHOLE gradient fades in
// together rather than the strong corner appearing instantly at full
// strength while the rest ramps up.
// -----------------------------------------------------------

uniform float u_alpha; // overlay's own intro-fade progress, 0..1

void main() {
    // 1.0 at UV(0,0) (top-left), 0.0 at UV(1,1) (bottom-right) -- averaging
    // both axes keeps the falloff a clean diagonal rather than biasing
    // toward one edge over the other.
    float gradient = clamp(1.0 - ((v_texcoord.x + v_texcoord.y) * 0.5), 0.0, 1.0);

    gl_FragColor = vec4(v_colour.rgb, v_colour.a * gradient * u_alpha);
}
