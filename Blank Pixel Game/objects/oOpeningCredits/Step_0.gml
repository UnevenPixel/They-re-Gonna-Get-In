var _dt = delta_time / 1000000;

switch (state) {
    case ECreditsState.FADE_IN:
        progress += _dt / fadeDuration;
        
        if (keyboard_check_pressed(vk_anykey)) progress = 1;
        
        if (progress >= 1){
            progress    = 1;
            state       = ECreditsState.HOLD;
        }
        break;
    
    case ECreditsState.HOLD:
        holdTimer += _dt;
        
        if (keyboard_check_pressed(vk_anykey)) holdTimer = holdDuration;
        
        if (holdTimer >= holdDuration){
            progress = 0;
            state = ECreditsState.FADE_OUT;
        }
        break;
    
    case ECreditsState.FADE_OUT:
        progress += _dt / fadeDuration;
        
        if (progress >= 1){
            state = ECreditsState.DONE;
            room_goto(rmDisclaimer); //Go to main menu instead after final build
        }
        break;
}