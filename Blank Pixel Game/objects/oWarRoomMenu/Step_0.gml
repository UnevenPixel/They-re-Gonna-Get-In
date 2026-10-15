// Pause menu -- checked first; while open, only its own Update() runs.
if (hubPauseMenu.isOpen) {
    hubPauseMenu.Update();
    exit;
}

// Escape opens the pause menu -- suppressed while Connelius's/Booger's
// tutorial dialogue is on screen so it doesn't pop up mid-conversation.
// Same guard oHubTownMenu uses for the Beggar. See WarRoomMenuScripts.md.
if (!warRoomMenu.dialogueOverlay.isOpen && keyboard_check_pressed(vk_escape)) {
    hubPauseMenu.Open();
    exit;
}

warRoomMenu.Update();
