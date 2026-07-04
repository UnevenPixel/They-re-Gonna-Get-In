// Required by the Steamworks extension -- certain async events (including
// the Steam Async Event callbacks) only fire when this is called. steam_init()
// itself is automatic and should NOT be called manually.
steam_update();

if keyboard_check_pressed(vk_f1) show_debug_log(!is_debug_overlay_open());