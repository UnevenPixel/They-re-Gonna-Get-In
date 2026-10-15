// Any key/gamepad press advances to the title menu. See oAlphaDisclaimer.md.
if (keyboard_check_pressed(vk_anykey) || gamepad_button_check_pressed(0, gp_face1)) {
    room_goto(rmTitleMenu);
}
