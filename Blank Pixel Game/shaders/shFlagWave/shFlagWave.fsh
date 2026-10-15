precision mediump float;

varying vec2 v_texcoord;
varying vec4 v_colour;

// -----------------------------------------------------------
// shFlagWave -- 2026-08-06 request: a "flag wave" distortion applied to the
// title screen's option buttons, with intensity ramping up on hover and
// dropping all the way back to a fully undistorted look when not hovered.
//
// Two-octave sine UV displacement (a primary wave plus a smaller,
// differently-timed secondary wave layered on top so the motion doesn't
// read as one mechanical, perfectly-repeating ripple), plus a subtle
// brightness wobble along the same wave to fake light catching the
// "fabric" as it moves. Adapted from Sara's "Animating Pixel Art Fabric
// with Unity Shader" (dev.to, 2025) -- a 2D sprite-space technique (UV
// distortion, not vertex displacement), since these are flat GUI sprites,
// not a 3D mesh, which is what most flag-wave tutorials actually target.
// That article's own formulas:
//   wave1 = sin(time*waveSpeed + uv.x*waveFrequency)
//   wave2 = sin(time*waveSpeed2 + uv.x*waveFrequency2) * amplitudeRatio
//   displacement = (wave1 + wave2) * dampeningPower
// -- reproduced below with this project's own naming/macro conventions.
//
// u_intensity is the actual point of the request: at 0, every wave term
// this shader computes still runs, but gets multiplied by 0 before it can
// touch the sampled UV or the brightness -- so the sprite renders pixel-
// identical to a plain unshaded draw_sprite_ext. Ramps to 1 at full hover.
// The caller (TitleMenuScripts.gml) drives this straight off each button's
// existing smoothed hover-shift value rather than a second, separate timer.
//
// ATLAS UV correction (same reasoning/approach as shPaletteSwap.fsh's own
// header): v_texcoord here is this sprite's ACTUAL sub-rectangle position
// on its shared texture page, not a clean local 0-1 range -- GameMaker
// packs sprites onto shared pages. Doing the wave math directly in
// v_texcoord space would make the wave's phase barely move at all across
// the button's width (since a packed sprite's own UV sub-rect is usually
// small, e.g. 0.1-wide, not the full 0-1 the frequency constants below
// assume) and would displace sampling into whatever's packed NEXT to this
// sprite on the page. u_spriteRect (u0,v0,u1,v1), passed from GML via
// sprite_get_uvs() exactly like shPaletteSwap.fsh's rect uniforms, lets
// this remap into the sprite's own LOCAL 0-1 space for the wave math, then
// back into atlas space to actually sample gm_BaseTexture. Same "assumes
// the sprite isn't packed rotated on its page" caveat shPaletteSwap.fsh
// already accepts (this project's default packer setting) rather than
// solving that in every custom shader that touches UVs.
// -----------------------------------------------------------

uniform float u_time;       // seconds, free-running (current_time/1000 -- see TitleMenuScripts.gml) -- NOT paused/scaled by global.matchSpeed, this screen has no match to speed up or pause
uniform float u_intensity;  // 0 (fully undistorted) .. 1 (full wave) -- per-button, already eased by the caller
uniform vec4  u_spriteRect; // (u0, v0, u1, v1) -- this sprite's own sub-rect on its texture page, sprite_get_uvs() GML-side

#define WAVE1_SPEED     3.2
#define WAVE1_FREQUENCY 6.0
#define WAVE2_SPEED     5.4  // deliberately not a simple multiple of WAVE1_SPEED -- keeps the two waves drifting in and out of phase with each other instead of settling into one fixed, repeating combined shape
#define WAVE2_FREQUENCY 13.2
#define WAVE2_AMPLITUDE 0.6  // secondary wave's weight relative to the primary -- source article's own value, keeps it a variation rather than an equally-strong second wave
#define WAVE_AMPLITUDE  0.035 // max UV displacement, in this sprite's OWN local 0-1 units, at full intensity -- small on purpose: these are small UI buttons, not a big sheet of cloth
#define LIGHT_AMPLITUDE 0.25   // how much the wave's peaks/valleys brighten/darken the sprite at full intensity -- fakes cloth catching light as it ripples

void main() {
    vec2 rectMin  = u_spriteRect.xy;
    vec2 rectMax  = u_spriteRect.zw;
    vec2 rectSize = rectMax - rectMin;

    vec2 localUV = (v_texcoord - rectMin) / rectSize; // 0..1 within THIS sprite

    float wave1 = sin((u_time * WAVE1_SPEED) + (localUV.x * WAVE1_FREQUENCY));
    float wave2 = sin((u_time * WAVE2_SPEED) + (localUV.x * WAVE2_FREQUENCY)) * WAVE2_AMPLITUDE;
    float wave  = wave1 + wave2;

    float displacement = wave * WAVE_AMPLITUDE * u_intensity;

    vec2 sampleUV = v_texcoord + vec2(0.0, displacement * rectSize.y);
    // Clamp rather than let a peak/trough sample past this sprite's own
    // sub-rect into whatever's packed next to it on the page -- costs a
    // couple of flattened pixel rows right at the sprite's own top/bottom
    // edge, which the small WAVE_AMPLITUDE above already makes hard to
    // notice, in exchange for zero risk of visible atlas bleed.
    sampleUV.y = clamp(sampleUV.y, rectMin.y, rectMax.y);

    vec4 texel = texture2D(gm_BaseTexture, sampleUV);

    if (texel.a < 0.01) {
        discard;
    }

    float light = 1.0 + (wave * LIGHT_AMPLITUDE * u_intensity);
    texel.rgb *= light;

    gl_FragColor = texel * v_colour;
}
