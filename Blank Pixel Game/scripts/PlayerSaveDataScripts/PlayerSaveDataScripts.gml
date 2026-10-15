// Persistent player save data (progression/unlocks/tutorial flags), stored
// as JSON. See PlayerSaveDataScripts.md for API and design notes.

#macro PLAYER_SAVE_FILE "playersavedata.json"

/// @function DefaultPlayerSaveData()
/// @description Every save field at its default value.
/// @returns {Struct}
function DefaultPlayerSaveData() {
    return {
        hasSeenBeggarIntro:  false,
        hasSeenWarRoomIntro: false,
        tutorialCompleted:   false,
    };
}

/// @function LoadPlayerSaveData()
/// @description Reads PLAYER_SAVE_FILE, falling back to defaults per-field
///        for anything missing/invalid. Does not touch global.playerSaveData.
/// @returns {Struct}
function LoadPlayerSaveData() {
    var _defaults = DefaultPlayerSaveData(); // fallback source, per-field

    if (!file_exists(PLAYER_SAVE_FILE)) {
        return _defaults;
    }

    var _buffer = buffer_load(PLAYER_SAVE_FILE);
    if (_buffer == -1) {
        return _defaults;
    }
    var _raw = buffer_read(_buffer, buffer_string);
    buffer_delete(_buffer);

    var _loaded = undefined;
    try {
        _loaded = json_parse(_raw);
    } catch (_err) {
        _loaded = undefined;
    }

    if (!is_struct(_loaded)) {
        return _defaults;
    }

    return {
        hasSeenBeggarIntro: variable_struct_exists(_loaded, "hasSeenBeggarIntro")
            ? _loaded.hasSeenBeggarIntro
            : _defaults.hasSeenBeggarIntro,
        hasSeenWarRoomIntro: variable_struct_exists(_loaded, "hasSeenWarRoomIntro")
            ? _loaded.hasSeenWarRoomIntro
            : _defaults.hasSeenWarRoomIntro,
        tutorialCompleted: variable_struct_exists(_loaded, "tutorialCompleted")
            ? _loaded.tutorialCompleted
            : _defaults.tutorialCompleted,
    };
}

/// @function SavePlayerSaveData()
/// @description Writes global.playerSaveData to PLAYER_SAVE_FILE as JSON.
function SavePlayerSaveData() {
    var _json = json_stringify(global.playerSaveData, true);

    var _buffer = buffer_create(string_byte_length(_json) + 1, buffer_fixed, 1);
    buffer_write(_buffer, buffer_string, _json);
    buffer_save(_buffer, PLAYER_SAVE_FILE);
    buffer_delete(_buffer);
}

/// @function LoadAndApplyPlayerSaveData()
/// @description Loads PlayerSaveData into global.playerSaveData. Call once at boot.
function LoadAndApplyPlayerSaveData() {
    global.playerSaveData = LoadPlayerSaveData();
}

/// @function ResetTutorialProgress()
/// @description Resets tutorial-progress fields to default and saves.
function ResetTutorialProgress() {
    var _defaults = DefaultPlayerSaveData();
    global.playerSaveData.hasSeenBeggarIntro  = _defaults.hasSeenBeggarIntro;
    global.playerSaveData.hasSeenWarRoomIntro = _defaults.hasSeenWarRoomIntro;
    global.playerSaveData.tutorialCompleted   = _defaults.tutorialCompleted;
    SavePlayerSaveData();
}

/// @function CompleteTutorial()
/// @description Marks the tutorial fully finished -- call when the player's
///        current run ends (match end/win/loss, or a manual End Match).
///        Idempotent; safe to call on every later run's end too, not just
///        the first. See .md.
function CompleteTutorial() {
    global.tutorialActive = false;
    if (!global.playerSaveData.tutorialCompleted) {
        global.playerSaveData.tutorialCompleted = true;
        SavePlayerSaveData();
    }
}
