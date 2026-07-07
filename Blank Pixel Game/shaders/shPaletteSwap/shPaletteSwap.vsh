// -----------------------------------------------------------
// shPaletteSwap -- vertex pass-through. No per-vertex work needed for this
// effect (the actual color substitution is entirely per-pixel, see
// shPaletteSwap.fsh) -- identical shape to shDitherDissolve.vsh, this
// project's other custom shader.
// -----------------------------------------------------------
attribute vec3 in_Position;
attribute vec4 in_Colour;
attribute vec2 in_TextureCoord;

varying vec2 v_texcoord;
varying vec4 v_colour;

void main() {
    vec4 object_space_pos = vec4(in_Position.x, in_Position.y, in_Position.z, 1.0);
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * object_space_pos;

    v_texcoord = in_TextureCoord;
    v_colour   = in_Colour;
}
