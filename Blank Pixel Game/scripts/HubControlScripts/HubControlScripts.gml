// Resolves which hub-town NPCs are currently interactable and which
// dialogue tree opens for each. See HubControlScripts.md.

// 2026-08-13: no longer a strict mirror -- global.tutorialActive now spans
// the WHOLE first-time tutorial flow (beggar intro -> war room intro ->
// first match), while this struct's own (instance-scoped) tutorialActive
// field below only covers the Beggar's own conversation. See .md.
global.tutorialActive = false;

/// @function HubControl(_hubTownMenu)
/// @description Owns tutorial-gating state and per-NPC dialogue-tree resolution for HubTownMenu.
/// @param {Struct.HubTownMenu} _hubTownMenu
function HubControl(_hubTownMenu) constructor {
    hubTownMenu = _hubTownMenu;

    tutorialActive = false; // true from StartBeggarTutorial() until its OWN dialogue closes -- narrower than global.tutorialActive, see .md

    /// @function StartBeggarTutorial()
    /// @description Auto-opens the Beggar's dialogue tree and marks the tutorial active, disabling the Beggar option until it closes.
    static StartBeggarTutorial = function() {
        tutorialActive        = true;
        global.tutorialActive = true; // also flips on the broader flow-wide flag -- NOT cleared below, see .md
        hubTownMenu._OpenBeggarMain();
    }

    /// @function Update()
    /// @description Call once per Step, unconditionally (even while a dialogue is open). Detects the Beggar's own conversation finishing.
    static Update = function() {
        if (tutorialActive && !hubTownMenu.dialogueOverlay.isOpen) {
            tutorialActive = false; // Beggar's own conversation is done -- does NOT clear global.tutorialActive, see .md
            global.playerSaveData.hasSeenBeggarIntro = true;
            SavePlayerSaveData();
        }
    }

    /// @function IsOptionAvailable(_action)
    /// @description Whether _action's HubTownOption can currently be hovered/clicked.
    /// @param {String} _action
    /// @returns {Bool}
    static IsOptionAvailable = function(_action) {
        switch (_action) {
            case "beggar": return !tutorialActive;
            default:       return true;
        }
    }

    /// @function GetDialogueOpener(_action)
    /// @description Which function opens _action's current dialogue tree, or undefined if _action has none.
    /// @param {String} _action
    /// @returns {Function}
    static GetDialogueOpener = function(_action) {
        switch (_action) {
            case "beggar": return hubTownMenu._OpenBeggarMain;
            default:       return undefined;
        }
    }
}
