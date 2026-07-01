draw_clear(c_black);

if (state == ECreditsState.DONE) exit;
    
var _shader_progress = 0;
var _shader_invert = 0;

switch(state) {
    case ECreditsState.FADE_IN:
        _shader_progress = progress;
        _shader_invert = 0.0;
        break;
    
    case ECreditsState.HOLD:
        _shader_progress = 1.0;
        _shader_invert = 0.0;
        break;
    case ECreditsState.FADE_OUT:
        _shader_progress = progress;
        _shader_invert = 1.0;
        break;
}

shader_set(shDitherDissolve);
shader_set_uniform_f(u_progress, _shader_progress);
shader_set_uniform_f(u_invert, _shader_invert);

draw_sprite(sStudioLogo, 0, logo.x,logo.y);

shader_reset();