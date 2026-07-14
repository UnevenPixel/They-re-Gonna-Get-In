// 2026-07-13 request: "Wire in the disclaimer screen to go to this menu
// instead" -- now leads into the new title menu (rmTitleMenu,
// TitleMenuScripts.gml) rather than straight into gameplay. The title
// menu's own "Play" button is what now goes to rmTestGameplay.
if (keyboard_check_pressed(vk_anykey) || gamepad_button_check_pressed(0, gp_face1)) {
    room_goto(rmTitleMenu);
}