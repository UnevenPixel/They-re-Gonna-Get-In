u_progress  = shader_get_uniform(shDitherDissolve, "u_progress");
u_invert    = shader_get_uniform(shDitherDissolve, "u_invert");

if (u_progress == -1 || u_invert == -1){
    show_debug_message("[oOpeningCredits] WARNING: one or more shader uniforms not found - check shDitherDissolve");
}

// State Machine
state       = ECreditsState.FADE_IN;
progress    = 0;
holdTimer   = 0;

//Timing (seconds)
fadeDuration = 2;
holdDuration = 1.5;

//Logo Positioning
logo = {
    x : room_width  * 0.5,
    y : room_height * 0.5
}