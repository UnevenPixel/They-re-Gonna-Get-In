// Pause menu -- checked first; while open, only its own Update() runs.
if (hubPauseMenu.isOpen) {
    hubPauseMenu.Update();
    exit;
}

// Escape opens the pause menu -- suppressed while the Beggar's dialogue is
// on screen so it doesn't pop up mid-conversation. See HubPauseMenuScripts.md.
if (!hubTownMenu.dialogueOverlay.isOpen && keyboard_check_pressed(vk_escape)) {
    hubPauseMenu.Open();
    exit;
}

hubTownMenu.Update();
