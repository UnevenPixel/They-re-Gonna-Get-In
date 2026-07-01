precision mediump float;

varying vec2 v_texcoord;
varying vec4 v_colour;

uniform float u_progress; // 0.0 to 1.0 — dissolve front position (top to bottom)
uniform float u_invert;   // 0.0 = dissolve in, 1.0 = dissolve out

// 4x4 Bayer ordered dither matrix — GLSL ES 1.0 safe (no dynamic indexing)
float bayer4x4(vec2 frag_coord) {
    float x = mod(floor(frag_coord.x), 4.0);
    float y = mod(floor(frag_coord.y), 4.0);

    float val = 0.0;

    if (x < 0.5) {
        if      (y < 0.5) val =  0.0;
        else if (y < 1.5) val =  8.0;
        else if (y < 2.5) val =  2.0;
        else               val = 10.0;
    } else if (x < 1.5) {
        if      (y < 0.5) val = 12.0;
        else if (y < 1.5) val =  4.0;
        else if (y < 2.5) val = 14.0;
        else               val =  6.0;
    } else if (x < 2.5) {
        if      (y < 0.5) val =  3.0;
        else if (y < 1.5) val = 11.0;
        else if (y < 2.5) val =  1.0;
        else               val =  9.0;
    } else {
        if      (y < 0.5) val = 15.0;
        else if (y < 1.5) val =  7.0;
        else if (y < 2.5) val = 13.0;
        else               val =  5.0;
    }

    return (val + 1.0) / 17.0;
}

void main() {
    vec4 texel = texture2D(gm_BaseTexture, v_texcoord);

    // Discard fully transparent pixels regardless of dissolve state
    if (texel.a < 0.01) discard;

    float band = 0.15;

    // Scale progress so the front fully clears the top (0) and bottom (1) edges
    float scaled = u_progress * (1.0 + band) - band * 0.5;

    // Fade in  — pixel visible when front has passed its Y position (top to bottom)
    // Fade out — pixel visible when front has NOT yet reached its Y position
    float reveal = clamp((scaled - v_texcoord.y) / band + 0.5, 0.0, 1.0);
    float remain = clamp((v_texcoord.y - scaled) / band + 0.5, 0.0, 1.0);

    float dissolve_amount = (u_invert > 0.5) ? remain : reveal;

    float bayer = bayer4x4(gl_FragCoord.xy);

    if (dissolve_amount < bayer) discard;

    gl_FragColor = texel * v_colour;
}