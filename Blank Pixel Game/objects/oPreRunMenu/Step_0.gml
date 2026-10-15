// Pause menu -- checked first; while open, only its own Update() runs.
if (hubPauseMenu.isOpen) {
    hubPauseMenu.Update();
    exit;
}

if (keyboard_check_pressed(vk_escape)) {
    hubPauseMenu.Open();
    exit;
}

preRunMenu.Update();
