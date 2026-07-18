// -----------------------------------------------------------
// SettingsOverlayScripts -- the shared settings menu. 2026-07-14 request.
//
// Opened as a SUB-MENU from two different places -- PauseMenu.OpenSettings()
// (mid-match, PauseMenuScripts.gml) and TitleMenu._OpenSettings() (title
// screen, TitleMenuScripts.gml). Both of those files' constructors now take
// a SettingsOverlay instance and store it, and both files' Update()/Draw()
// check settingsOverlay.isOpen FIRST and delegate to it instead of running
// their own logic that frame -- the same "isOpen early-exit" idiom
// FateEngineOverlay/PauseMenu already use against oUnitControl's Step_0.gml,
// just one level further down (a sub-menu deferring to ITS OWN sub-menu).
//
// Two separate SettingsOverlay INSTANCES exist -- one made in
// oUnitControl/Create_0.gml, one in oTitleMenu/Create_0.gml (they never
// coexist, since oUnitControl and oTitleMenu never coexist in the same
// room) -- but both read/write the SAME global.gameSettings struct (see
// LoadGameSettings/SaveGameSettings/ApplyGameSettings below), so a value
// changed on one screen is still in effect, and persisted to disk, the next
// time either screen is visited.
//
// Doesn't take/need any cross-controller dependencies the way
// FateEngineOverlay.Open()/PauseMenu.Open() do (selectionController,
// blueprintController, etc.) -- it never touches selection/targeting/drag
// state itself; it's always opened on top of an already-safe context
// (PauseMenu already reset all of that when IT opened; the title screen has
// none of it to begin with).
//
// Uses "a similar black overlay to other overlays" per the request -- same
// 0.75-alpha black dim rect PauseMenu/FateEngineOverlay both draw. Stacks
// harmlessly on top of PauseMenu's own dim when opened mid-match (just reads
// as slightly darker, which fits "you're now a menu deeper").
//
// Five tabs, buttons along the top of the panel per the request ("for now
// will be buttons along the top of the screen"): Gameplay, Controls, Audio,
// Graphics, Accessibility.
//   - Gameplay: "Restart Tutorial" and "Restart Progress" buttons. Restart
//     Progress opens the same Yes/No confirm shape PauseMenu/TitleMenu's own
//     confirms already use (DropDownMenuScripts.gml's shared row/hit-test
//     helpers), per explicit request. BOTH buttons are STUBS today --
//     RestartTutorial()/ResetPlayerProgress() are intentionally empty, since
//     no tutorial system and no meta-progression/save system exist anywhere
//     in the project yet (confirmed via grep). The confirm FLOW around
//     Restart Progress is fully wired and real; only the actual reset logic
//     is missing. See those two functions' own doc comments.
//   - Controls: visual-only readout (per explicit request -- "for now will
//     just be a visual only") of the game's REAL current control scheme,
//     read straight off every keyboard_check/mouse_check_button call in the
//     project -- see GetControlsList()'s own doc comment.
//   - Audio: Master/Music/SFX volume sliders + a mute toggle each. Master
//     is REAL and live (audio_master_gain(), a genuine project-wide
//     built-in) -- moving it/muting it has an actual effect right now.
//     Music/SFX are stored + persisted but NOT applied to anything yet --
//     there are no sound assets or audio_group split anywhere in this
//     project (confirmed via grep) for a per-group gain to apply TO. Real
//     hookup is a one-line audio_group_set_gain() call per group once those
//     exist.
//   - Graphics: Fullscreen toggle (real, window_set_fullscreen()) and
//     Borderless Windowed toggle (a vanilla window_set_showborder() +
//     resize-to-display approximation -- per the request's own framing,
//     "true" fullscreen borderless is intentionally left for the
//     marketplace extension being added separately; this just gets the
//     window into the right ballpark today, and is the obvious call site to
//     swap once that extension is in), plus a Gamma slider. Gamma is
//     STORED + PERSISTED but NOT applied to anything yet -- real gamma
//     correction needs a full-screen post-process shader (disable
//     GameMaker's automatic application_surface draw, take over final-frame
//     compositing for the ENTIRE game by hand, sample application_surface,
//     apply pow(rgb, 1/gamma), draw it back). That's a genuine engine-level
//     change with a large blast radius (get it wrong and NOTHING renders,
//     on both the title screen AND in gameplay) that deserves its own
//     dedicated, tested pass rather than being folded silently into this
//     settings-menu commit -- flagging rather than guessing at it blind.
//   - Accessibility: STUB per explicit request ("will be a stub for now,
//     unless you have an idea for it") -- drawn as 3 greyed-out, non-
//     interactive placeholder ideas (colorblind-friendly team colors, UI
//     text scale, reduce screen shake/flash) rather than a single blank
//     page, so there's something concrete to react to/veto. None of these
//     are wired to anything real.
//
// Persistence: global.gameSettings is loaded once at game boot
// (LoadAndApplyGameSettings(), called from oGameControl's Create event --
// that object is persistent:true and runs before any room, confirmed via
// its own .yy) from SETTINGS_SAVE_FILE (an .ini file, GameMaker's own
// ini_open/ini_read_real/ini_write_real/ini_close), falling back to
// DefaultGameSettings() for any missing key (first-ever boot, or a setting
// added in a later update). Every value change from the menu calls
// SaveGameSettings() immediately (a handful of writes per settings visit at
// most -- no need to batch/debounce) and, where a value has a real runtime
// effect today (master volume, fullscreen, borderless), ApplyGameSettings()
// too.
// -----------------------------------------------------------

#macro SETTINGS_SAVE_FILE "settings.ini"

#macro SETTINGS_PANEL_WIDTH          1100
#macro SETTINGS_PANEL_HEIGHT         700
#macro SETTINGS_TAB_HEIGHT           50
#macro SETTINGS_TAB_GAP              8
#macro SETTINGS_TAB_TOP_PAD          20
#macro SETTINGS_CONTENT_PAD_X        40
#macro SETTINGS_CONTENT_TOP_PAD      20
#macro SETTINGS_ROW_HEIGHT           50
#macro SETTINGS_ROW_GAP              18
#macro SETTINGS_SLIDER_WIDTH         320
#macro SETTINGS_SLIDER_HEIGHT        14
#macro SETTINGS_SLIDER_HANDLE_R      9
#macro SETTINGS_TOGGLE_SIZE          24
#macro SETTINGS_ACTION_BUTTON_WIDTH  240
#macro SETTINGS_ACTION_BUTTON_HEIGHT 44
#macro SETTINGS_BACK_BUTTON_WIDTH    160
#macro SETTINGS_BACK_BUTTON_HEIGHT   44

// Same dark-purple "temporary UI" palette FateEngineOverlay's buttons
// already established (FateEngineOverlayScripts.gml's DrawOneButton) --
// reused for visual consistency rather than inventing a second palette,
// since no dedicated settings-panel sprite exists yet either.
#macro SETTINGS_PANEL_FILL_COLOR   make_color_rgb(0x3A, 0x2E, 0x4A)
#macro SETTINGS_TAB_ACTIVE_COLOR   make_color_rgb(0x5A, 0x46, 0x6E)
#macro SETTINGS_TAB_INACTIVE_COLOR make_color_rgb(0x2A, 0x20, 0x36)
#macro SETTINGS_TAB_HOVER_COLOR    make_color_rgb(0x40, 0x32, 0x52)
#macro SETTINGS_DISABLED_COLOR     make_color_rgb(0x55, 0x55, 0x55)
#macro SETTINGS_TRACK_EMPTY_COLOR  make_color_rgb(0x1A, 0x14, 0x22)

/// @function DefaultGameSettings()
/// @description Every persisted setting at its default value. Used both to
///        seed global.gameSettings on first-ever boot (no settings.ini yet)
///        and as the fallback for any individual key missing from an
///        existing ini (e.g. a setting added in a later update).
/// @returns {Struct}
function DefaultGameSettings() {
    return {
        masterVolume: 1,
        musicVolume:  1,
        sfxVolume:    1,
        masterMuted:  false,
        musicMuted:   false,
        sfxMuted:     false,
        fullscreen:   false,
        borderless:   false,
        gamma:        0.5, // 0.5 == neutral/no correction -- see file header, not applied to anything yet
    };
}

/// @function LoadGameSettings()
/// @description Loads global.gameSettings from SETTINGS_SAVE_FILE, falling
///        back to DefaultGameSettings() for any key the ini doesn't have.
///        Idempotent -- safe to call more than once (re-reads from disk
///        each time), though today only oGameControl's Create event does,
///        once, at game boot. Does NOT push the loaded values onto the
///        actual runtime/window state -- see ApplyGameSettings(), or just
///        call LoadAndApplyGameSettings() to do both.
function LoadGameSettings() {
    var _d = DefaultGameSettings();

    ini_open(SETTINGS_SAVE_FILE);
    global.gameSettings = {
        masterVolume: ini_read_real("Audio", "masterVolume", _d.masterVolume),
        musicVolume:  ini_read_real("Audio", "musicVolume",  _d.musicVolume),
        sfxVolume:    ini_read_real("Audio", "sfxVolume",    _d.sfxVolume),
        masterMuted:  ini_read_real("Audio", "masterMuted",  _d.masterMuted ? 1 : 0) != 0,
        musicMuted:   ini_read_real("Audio", "musicMuted",   _d.musicMuted  ? 1 : 0) != 0,
        sfxMuted:     ini_read_real("Audio", "sfxMuted",     _d.sfxMuted    ? 1 : 0) != 0,
        fullscreen:   ini_read_real("Graphics", "fullscreen", _d.fullscreen ? 1 : 0) != 0,
        borderless:   ini_read_real("Graphics", "borderless", _d.borderless ? 1 : 0) != 0,
        gamma:        ini_read_real("Graphics", "gamma", _d.gamma),
    };
    ini_close();
}

/// @function SaveGameSettings()
/// @description Writes global.gameSettings out to SETTINGS_SAVE_FILE.
///        Called once per change from SettingsOverlay.
function SaveGameSettings() {
    var _s = global.gameSettings;

    ini_open(SETTINGS_SAVE_FILE);
    ini_write_real("Audio", "masterVolume", _s.masterVolume);
    ini_write_real("Audio", "musicVolume",  _s.musicVolume);
    ini_write_real("Audio", "sfxVolume",    _s.sfxVolume);
    ini_write_real("Audio", "masterMuted",  _s.masterMuted ? 1 : 0);
    ini_write_real("Audio", "musicMuted",   _s.musicMuted  ? 1 : 0);
    ini_write_real("Audio", "sfxMuted",     _s.sfxMuted    ? 1 : 0);
    ini_write_real("Graphics", "fullscreen", _s.fullscreen ? 1 : 0);
    ini_write_real("Graphics", "borderless", _s.borderless ? 1 : 0);
    ini_write_real("Graphics", "gamma", _s.gamma);
    ini_close();
}

/// @function ApplyGameSettings()
/// @description Pushes global.gameSettings onto the actual runtime state --
///        audio_master_gain() for master volume/mute, window_set_fullscreen()
///        for fullscreen, and the vanilla window_set_showborder() +
///        resize-to-display approximation for borderless (see file header --
///        "true" borderless is intentionally left to the marketplace
///        extension being added separately). Music/SFX volume and gamma are
///        deliberately NOT applied here -- see file header for why (no audio
///        groups / no post-process shader exist yet to apply them to).
function ApplyGameSettings() {
    var _s = global.gameSettings;

    audio_master_gain(_s.masterMuted ? 0 : _s.masterVolume);

    window_set_fullscreen(_s.fullscreen);

    // Vanilla borderless-windowed approximation -- only meaningful while
    // NOT fullscreen (fullscreen already covers the whole screen with no
    // border by definition).
    if (!_s.fullscreen) {
        window_set_showborder(!_s.borderless);
        if (_s.borderless) {
            window_set_position(0, 0);
            window_set_size(display_get_width(), display_get_height());
        }
    }
}

/// @function LoadAndApplyGameSettings()
/// @description Convenience wrapper -- LoadGameSettings() then
///        ApplyGameSettings() in one call. What oGameControl's Create event
///        actually calls at boot.
function LoadAndApplyGameSettings() {
    LoadGameSettings();
    ApplyGameSettings();
}

/// @function GetControlsList()
/// @description The real, currently-bound control scheme, read straight off
///        every keyboard_check/mouse_check_button call in the project
///        (confirmed via grep -- oUnitControl/Step_0.gml, UnitSelection.gml,
///        every drop-down menu's shared click handling, TitleMenuScripts.gml).
///        Visual-only per explicit request ("Controls for now will just be
///        a visual only") -- no rebinding, just a readout. OrderMenu's
///        per-row mnemonic hotkeys (AssignMnemonics(), OrderMenu.gml) are
///        deliberately NOT listed as their own fixed binding -- which
///        letter maps to which order changes depending on what's selected,
///        so they're called out as their own contextual line instead.
/// @returns {Array<Struct>} Array of { action, key }.
function GetControlsList() {
    return [
        { action: "Select Unit / Drag-Select",     key: "Left Click / Drag" },
        { action: "Add to Selection",               key: "Shift + Left Click" },
        { action: "Move / Attack / Context Order",  key: "Right Click" },
        { action: "Order Menu Shortcuts",            key: "Highlighted Letter" },
        { action: "Pause",                           key: "Escape" },
    ];
}

/// @function SettingsOverlay()
/// @description The shared settings menu -- see file header for full
///        behavior. Not a GM instance -- a plain struct, same pattern as
///        every other overlay/menu (PauseMenu, FateEngineOverlay). Owner
///        (oUnitControl or oTitleMenu, via PauseMenu/TitleMenu -- see file
///        header) calls Update() once per Step while relevant and Draw()
///        once per Draw GUI.
function SettingsOverlay() constructor {
    // Defensive -- guarantees global.gameSettings exists by the time
    // anything reads it, regardless of boot order, even though oGameControl
    // (persistent, runs first) is the only thing expected to call this
    // today. Idempotent (LoadGameSettings() just re-reads the same file).
    if (!variable_global_exists("gameSettings")) LoadAndApplyGameSettings();

    isOpen     = false;
    activeTab  = 0; // index into tabs -- reset to 0 (Gameplay) every Open(), see Open()'s own comment
    hoveredTab = -1;

    tabs         = ["Gameplay", "Controls", "Audio", "Graphics", "Accessibility"];
    controlsList = GetControlsList();

    // Audio tab -- which slider (if any) the mouse is currently dragging.
    // undefined | "master" | "music" | "sfx"
    draggingSlider = undefined;

    // Graphics tab -- gamma uses the same drag mechanism as the audio
    // sliders, tracked separately since it lives on a different tab and
    // isn't a volume.
    draggingGamma = false;

    // Gameplay tab -- Restart Progress' own Yes/No confirm, same local
    // "pendingConfirmAction"-style sub-state PauseMenu/TitleMenu each
    // already use for their own confirms, rather than a shared confirm
    // struct (no such shared thing exists in this project -- each menu
    // owns its own).
    confirmRestartProgress = false;
    confirmHoveredIndex    = -1;
    confirmOptions         = ["Yes", "No"];

    /// @function Open()
    /// @description Opens the settings overlay on top of whatever's already
    ///        showing (a paused game or the title screen's main menu) --
    ///        always resets to the Gameplay tab, a judgment call for
    ///        predictability over remembering the last-viewed tab across
    ///        visits; flag if remembering reads better once tried. No-ops
    ///        if already open.
    /// @returns {Struct.SettingsOverlay} self
    static Open = function() {
        if (isOpen) return self;
        isOpen                 = true;
        activeTab              = 0;
        hoveredTab              = -1;
        draggingSlider          = undefined;
        draggingGamma           = false;
        confirmRestartProgress  = false;
        confirmHoveredIndex     = -1;
        return self;
    }

    /// @function Close()
    /// @description Closes the settings overlay, revealing whichever parent
    ///        menu/screen was already open underneath (neither PauseMenu's
    ///        nor TitleMenu's own state is touched by this struct, so
    ///        there's nothing to "restore" -- it was never disturbed).
    /// @returns {Struct.SettingsOverlay} self
    static Close = function() {
        isOpen                 = false;
        draggingSlider          = undefined;
        draggingGamma           = false;
        confirmRestartProgress  = false;
        return self;
    }

    /// @function RestartTutorial()
    /// @description STUB -- no tutorial system exists anywhere in the
    ///        project yet (confirmed via grep, zero matches for
    ///        "tutorial"). Intentionally empty; clicking "Restart Tutorial"
    ///        currently does nothing observable. Ready to wire up the
    ///        moment a tutorial exists to restart.
    static RestartTutorial = function() {
        // Intentionally empty -- see file header / PATCH_NOTES.md.
    }

    /// @function ResetPlayerProgress()
    /// @description STUB -- no meta-progression/save system exists anywhere
    ///        in the project yet (confirmed via grep -- no ini_write/
    ///        game_save/equivalent calls anywhere before this file).
    ///        Deliberately does NOT alias to PauseMenu's "Restart"
    ///        (room_restart(), which resets the CURRENT MATCH) -- that's
    ///        a separate, already-existing button/concept, and conflating
    ///        the two would be misleading once a real save system exists
    ///        and this needs to do something bigger. The Yes/No confirm
    ///        flow around this (see Update()) is fully wired and real; only
    ///        the actual reset logic is missing.
    static ResetPlayerProgress = function() {
        // Intentionally empty -- see file header / PATCH_NOTES.md.
    }

    // ---------------------------------------------------------------
    // Layout -- internal rect/position helpers. Computed fresh each call
    // (cheap, no state) so Draw() and Update() always agree on hit boxes,
    // same "derive, don't duplicate" idiom as FateEngineButtonRects/
    // ArmyLimitWidgetIconRect.
    // ---------------------------------------------------------------

    /// @function _PanelRect()
    /// @returns {Struct} { x1, y1, x2, y2 } -- the settings panel, centered on screen.
    static _PanelRect = function() {
        var _w  = SETTINGS_PANEL_WIDTH;
        var _h  = SETTINGS_PANEL_HEIGHT;
        var _x1 = (display_get_gui_width()  - _w) / 2;
        var _y1 = (display_get_gui_height() - _h) / 2;
        return { x1: _x1, y1: _y1, x2: _x1 + _w, y2: _y1 + _h };
    }

    /// @function _TabRects()
    /// @returns {Array<Struct>} one { x1, y1, x2, y2 } per entry in tabs.
    static _TabRects = function() {
        var _panel = _PanelRect();
        var _count = array_length(tabs);
        var _tabW  = (SETTINGS_PANEL_WIDTH - (SETTINGS_CONTENT_PAD_X * 2) - (SETTINGS_TAB_GAP * (_count - 1))) / _count;
        var _y1    = _panel.y1 + SETTINGS_TAB_TOP_PAD;
        var _y2    = _y1 + SETTINGS_TAB_HEIGHT;

        var _rects = [];
        var _x = _panel.x1 + SETTINGS_CONTENT_PAD_X;
        for (var i = 0; i < _count; i++) {
            array_push(_rects, { x1: _x, y1: _y1, x2: _x + _tabW, y2: _y2 });
            _x += _tabW + SETTINGS_TAB_GAP;
        }
        return _rects;
    }

    /// @function _ContentTopY()
    /// @returns {Real} GUI-space Y where per-tab content starts, just below the tab bar.
    static _ContentTopY = function() {
        var _panel = _PanelRect();
        return _panel.y1 + SETTINGS_TAB_TOP_PAD + SETTINGS_TAB_HEIGHT + SETTINGS_CONTENT_TOP_PAD;
    }

    /// @function _ContentRowY(_index)
    /// @param {Real} _index 0-based row index within the current tab's content.
    /// @returns {Real}
    static _ContentRowY = function(_index) {
        return _ContentTopY() + _index * (SETTINGS_ROW_HEIGHT + SETTINGS_ROW_GAP);
    }

    /// @function _BackButtonRect()
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _BackButtonRect = function() {
        var _panel = _PanelRect();
        var _x2 = _panel.x2 - SETTINGS_CONTENT_PAD_X;
        var _x1 = _x2 - SETTINGS_BACK_BUTTON_WIDTH;
        var _y2 = _panel.y2 - 24;
        var _y1 = _y2 - SETTINGS_BACK_BUTTON_HEIGHT;
        return { x1: _x1, y1: _y1, x2: _x2, y2: _y2 };
    }

    /// @function _GameplayButtonRects()
    /// @returns {Struct} { restartTutorial, restartProgress }, each { x1, y1, x2, y2 }
    static _GameplayButtonRects = function() {
        var _panel = _PanelRect();
        var _x1    = _panel.x1 + SETTINGS_CONTENT_PAD_X;

        var _y0 = _ContentRowY(0);
        var _y1 = _ContentRowY(1);

        return {
            restartTutorial: { x1: _x1, y1: _y0, x2: _x1 + SETTINGS_ACTION_BUTTON_WIDTH, y2: _y0 + SETTINGS_ACTION_BUTTON_HEIGHT },
            restartProgress: { x1: _x1, y1: _y1, x2: _x1 + SETTINGS_ACTION_BUTTON_WIDTH, y2: _y1 + SETTINGS_ACTION_BUTTON_HEIGHT },
        };
    }

    /// @function _AudioRowRects()
    /// @returns {Struct} { master, music, sfx }, each { sliderX, toggleX, y }
    static _AudioRowRects = function() {
        var _panel   = _PanelRect();
        var _sliderX = _panel.x1 + SETTINGS_CONTENT_PAD_X;
        var _toggleX = _sliderX + SETTINGS_SLIDER_WIDTH + 80;

        return {
            master: { sliderX: _sliderX, toggleX: _toggleX, y: _ContentRowY(0) + (SETTINGS_ROW_HEIGHT / 2) },
            music:  { sliderX: _sliderX, toggleX: _toggleX, y: _ContentRowY(1) + (SETTINGS_ROW_HEIGHT / 2) },
            sfx:    { sliderX: _sliderX, toggleX: _toggleX, y: _ContentRowY(2) + (SETTINGS_ROW_HEIGHT / 2) },
        };
    }

    /// @function _GraphicsRowRects()
    /// @returns {Struct} { fullscreenToggleX, fullscreenY, borderlessToggleX, borderlessY, gammaSliderX, gammaY }
    static _GraphicsRowRects = function() {
        var _panel = _PanelRect();
        var _x     = _panel.x1 + SETTINGS_CONTENT_PAD_X;

        return {
            fullscreenToggleX: _x, fullscreenY: _ContentRowY(0) + (SETTINGS_ROW_HEIGHT / 2),
            borderlessToggleX: _x, borderlessY: _ContentRowY(1) + (SETTINGS_ROW_HEIGHT / 2),
            // Extra 20px gap -- gamma is a slider (taller visually, with its
            // own label above it) sitting just below the two toggles, not
            // another toggle row.
            gammaSliderX: _x, gammaY: _ContentRowY(2) + (SETTINGS_ROW_HEIGHT / 2) + 20,
        };
    }

    /// @function _SliderTrackRect(_x, _y)
    /// @description Track rect for a slider whose LEFT edge starts at
    ///        (_x, _y) (_y is the track's vertical center).
    /// @param {Real} _x
    /// @param {Real} _y
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _SliderTrackRect = function(_x, _y) {
        return {
            x1: _x, y1: _y - (SETTINGS_SLIDER_HEIGHT / 2),
            x2: _x + SETTINGS_SLIDER_WIDTH, y2: _y + (SETTINGS_SLIDER_HEIGHT / 2)
        };
    }

    /// @function _ToggleRect(_x, _y)
    /// @param {Real} _x Box's left edge.
    /// @param {Real} _y Box's vertical center.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _ToggleRect = function(_x, _y) {
        return {
            x1: _x, y1: _y - (SETTINGS_TOGGLE_SIZE / 2),
            x2: _x + SETTINGS_TOGGLE_SIZE, y2: _y + (SETTINGS_TOGGLE_SIZE / 2)
        };
    }

    /// @function _SliderValueFromMouseX(_trackRect, _mx)
    /// @description Converts a GUI-space mouse X into a 0..1 slider value,
    ///        clamped to the track's own bounds.
    /// @param {Struct} _trackRect
    /// @param {Real} _mx
    /// @returns {Real}
    static _SliderValueFromMouseX = function(_trackRect, _mx) {
        return clamp((_mx - _trackRect.x1) / (_trackRect.x2 - _trackRect.x1), 0, 1);
    }

    /// @function _PointInRect(_px, _py, _rect)
    /// @param {Real} _px
    /// @param {Real} _py
    /// @param {Struct} _rect { x1, y1, x2, y2 }
    /// @returns {Bool}
    static _PointInRect = function(_px, _py, _rect) {
        return (_px >= _rect.x1 && _px <= _rect.x2 && _py >= _rect.y1 && _py <= _rect.y2);
    }

    // ---------------------------------------------------------------
    // Update
    // ---------------------------------------------------------------

    /// @function Update()
    /// @description Call once per Step while this overlay might be open --
    ///        both PauseMenu.Update() and TitleMenu.Update() delegate here
    ///        FIRST (before their own logic) whenever isOpen is true.
    ///        No-ops entirely if not open.
    /// @returns {Struct.SettingsOverlay} self
    static Update = function() {
        if (!isOpen) return self;

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        // Restart Progress confirm sub-panel -- same shared row/hit-test
        // helpers PauseMenu/TitleMenu's own confirms use.
        if (confirmRestartProgress) {
            var _pos = PositionDropDownMenuCentered(array_length(confirmOptions));
            confirmHoveredIndex = DropDownMenuHitTest(_pos.x, _pos.y, array_length(confirmOptions), _mx, _my);

            if (keyboard_check_pressed(vk_escape)) {
                confirmRestartProgress = false;
                return self;
            }
            if (mouse_check_button_pressed(mb_left)) {
                if (confirmHoveredIndex == 0) ResetPlayerProgress(); // "Yes"
                confirmRestartProgress = false; // "Yes", "No", or a miss-click all close the confirm either way
            }
            return self;
        }

        // Slider/gamma dragging takes priority over everything else below
        // while the mouse button is held -- follows the cursor every step,
        // independent of which row it started over, standard "drag anywhere
        // once grabbed" slider feel.
        if (draggingSlider != undefined || draggingGamma) {
            if (!mouse_check_button(mb_left)) {
                draggingSlider = undefined;
                draggingGamma  = false;
                SaveGameSettings();
            } else if (draggingGamma) {
                var _g = _GraphicsRowRects();
                global.gameSettings.gamma = _SliderValueFromMouseX(_SliderTrackRect(_g.gammaSliderX, _g.gammaY), _mx);
            } else {
                var _rows = _AudioRowRects();
                if (draggingSlider == "master") {
                    global.gameSettings.masterVolume = _SliderValueFromMouseX(_SliderTrackRect(_rows.master.sliderX, _rows.master.y), _mx);
                    ApplyGameSettings();
                } else if (draggingSlider == "music") {
                    global.gameSettings.musicVolume = _SliderValueFromMouseX(_SliderTrackRect(_rows.music.sliderX, _rows.music.y), _mx);
                } else if (draggingSlider == "sfx") {
                    global.gameSettings.sfxVolume = _SliderValueFromMouseX(_SliderTrackRect(_rows.sfx.sliderX, _rows.sfx.y), _mx);
                }
            }
            return self;
        }

        if (keyboard_check_pressed(vk_escape)) {
            Close();
            return self;
        }

        // Tab bar -- always live, regardless of which tab is active.
        var _tabRects = _TabRects();
        hoveredTab = -1;
        for (var i = 0; i < array_length(_tabRects); i++) {
            if (_PointInRect(_mx, _my, _tabRects[i])) {
                hoveredTab = i;
                break;
            }
        }
        if (hoveredTab != -1 && mouse_check_button_pressed(mb_left)) {
            activeTab = hoveredTab;
            return self; // switching tabs consumes the click -- don't also register it against the PREVIOUS tab's content this same frame
        }

        if (mouse_check_button_pressed(mb_left) && _PointInRect(_mx, _my, _BackButtonRect())) {
            Close();
            return self;
        }

        switch (activeTab) {
            case 0: _UpdateGameplayTab(_mx, _my); break;
            case 1: break; // Controls -- visual only, nothing to update
            case 2: _UpdateAudioTab(_mx, _my); break;
            case 3: _UpdateGraphicsTab(_mx, _my); break;
            case 4: break; // Accessibility -- stub, nothing to update
        }

        return self;
    }

    /// @function _UpdateGameplayTab(_mx, _my)
    /// @param {Real} _mx
    /// @param {Real} _my
    static _UpdateGameplayTab = function(_mx, _my) {
        if (!mouse_check_button_pressed(mb_left)) return;

        var _rects = _GameplayButtonRects();
        if (_PointInRect(_mx, _my, _rects.restartTutorial)) {
            RestartTutorial();
        } else if (_PointInRect(_mx, _my, _rects.restartProgress)) {
            confirmRestartProgress = true;
            confirmHoveredIndex    = -1;
        }
    }

    /// @function _UpdateAudioTab(_mx, _my)
    /// @param {Real} _mx
    /// @param {Real} _my
    static _UpdateAudioTab = function(_mx, _my) {
        if (!mouse_check_button_pressed(mb_left)) return;

        var _rows = _AudioRowRects();

        if (_PointInRect(_mx, _my, _SliderTrackRect(_rows.master.sliderX, _rows.master.y))) {
            draggingSlider = "master";
            global.gameSettings.masterVolume = _SliderValueFromMouseX(_SliderTrackRect(_rows.master.sliderX, _rows.master.y), _mx);
            ApplyGameSettings();
            return;
        }
        if (_PointInRect(_mx, _my, _SliderTrackRect(_rows.music.sliderX, _rows.music.y))) {
            draggingSlider = "music";
            global.gameSettings.musicVolume = _SliderValueFromMouseX(_SliderTrackRect(_rows.music.sliderX, _rows.music.y), _mx);
            return;
        }
        if (_PointInRect(_mx, _my, _SliderTrackRect(_rows.sfx.sliderX, _rows.sfx.y))) {
            draggingSlider = "sfx";
            global.gameSettings.sfxVolume = _SliderValueFromMouseX(_SliderTrackRect(_rows.sfx.sliderX, _rows.sfx.y), _mx);
            return;
        }

        if (_PointInRect(_mx, _my, _ToggleRect(_rows.master.toggleX, _rows.master.y))) {
            global.gameSettings.masterMuted = !global.gameSettings.masterMuted;
            ApplyGameSettings();
            SaveGameSettings();
            return;
        }
        if (_PointInRect(_mx, _my, _ToggleRect(_rows.music.toggleX, _rows.music.y))) {
            global.gameSettings.musicMuted = !global.gameSettings.musicMuted;
            SaveGameSettings();
            return;
        }
        if (_PointInRect(_mx, _my, _ToggleRect(_rows.sfx.toggleX, _rows.sfx.y))) {
            global.gameSettings.sfxMuted = !global.gameSettings.sfxMuted;
            SaveGameSettings();
            return;
        }
    }

    /// @function _UpdateGraphicsTab(_mx, _my)
    /// @param {Real} _mx
    /// @param {Real} _my
    static _UpdateGraphicsTab = function(_mx, _my) {
        if (!mouse_check_button_pressed(mb_left)) return;

        var _rows = _GraphicsRowRects();

        if (_PointInRect(_mx, _my, _ToggleRect(_rows.fullscreenToggleX, _rows.fullscreenY))) {
            global.gameSettings.fullscreen = !global.gameSettings.fullscreen;
            ApplyGameSettings();
            SaveGameSettings();
            return;
        }
        if (_PointInRect(_mx, _my, _ToggleRect(_rows.borderlessToggleX, _rows.borderlessY))) {
            global.gameSettings.borderless = !global.gameSettings.borderless;
            ApplyGameSettings();
            SaveGameSettings();
            return;
        }
        if (_PointInRect(_mx, _my, _SliderTrackRect(_rows.gammaSliderX, _rows.gammaY))) {
            draggingGamma = true;
            global.gameSettings.gamma = _SliderValueFromMouseX(_SliderTrackRect(_rows.gammaSliderX, _rows.gammaY), _mx);
            return;
        }
    }

    // ---------------------------------------------------------------
    // Draw
    // ---------------------------------------------------------------

    /// @function Draw()
    /// @description Call once per Draw GUI event -- both PauseMenu.Draw()
    ///        and TitleMenu.Draw() call this LAST (on top of everything
    ///        else) whenever isOpen is true. No-ops if not open.
    static Draw = function() {
        if (!isOpen) return;

        draw_set_color(c_black);
        draw_set_alpha(0.75);
        draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
        draw_set_alpha(1);

        var _panel = _PanelRect();
        draw_set_color(SETTINGS_PANEL_FILL_COLOR);
        draw_rectangle(_panel.x1, _panel.y1, _panel.x2, _panel.y2, false);
        draw_set_color(c_white);
        draw_rectangle(_panel.x1, _panel.y1, _panel.x2, _panel.y2, true);

        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text((_panel.x1 + _panel.x2) / 2, _panel.y1 - 30, "Settings");

        DrawTabBar();

        switch (activeTab) {
            case 0: DrawGameplayTab(); break;
            case 1: DrawControlsTab(); break;
            case 2: DrawAudioTab(); break;
            case 3: DrawGraphicsTab(); break;
            case 4: DrawAccessibilityTab(); break;
        }

        _DrawActionButton(_BackButtonRect(), "Back");

        if (confirmRestartProgress) DrawRestartProgressConfirm();

        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    }

    /// @function DrawTabBar()
    /// @description Internal helper for Draw() -- the 5 tab buttons along
    ///        the top of the panel, highlighted per active/hovered state.
    static DrawTabBar = function() {
        var _rects = _TabRects();
        for (var i = 0; i < array_length(tabs); i++) {
            var _rect    = _rects[i];
            var _active  = (i == activeTab);
            var _hovered = (i == hoveredTab);

            draw_set_color(_active ? SETTINGS_TAB_ACTIVE_COLOR : (_hovered ? SETTINGS_TAB_HOVER_COLOR : SETTINGS_TAB_INACTIVE_COLOR));
            draw_rectangle(_rect.x1, _rect.y1, _rect.x2, _rect.y2, false);
            draw_set_color(c_white);
            draw_rectangle(_rect.x1, _rect.y1, _rect.x2, _rect.y2, true);

            draw_set_halign(fa_center);
            draw_set_valign(fa_middle);
            draw_set_color(_active ? c_white : HOVER_CARD_TEXT_COLOR);
            draw_text((_rect.x1 + _rect.x2) / 2, (_rect.y1 + _rect.y2) / 2, tabs[i]);
        }
    }

    /// @function DrawGameplayTab()
    static DrawGameplayTab = function() {
        var _rects = _GameplayButtonRects();
        _DrawActionButton(_rects.restartTutorial, "Restart Tutorial");
        _DrawActionButton(_rects.restartProgress, "Restart Progress");
    }

    /// @function DrawControlsTab()
    /// @description Visual-only readout of the game's actual current
    ///        control scheme -- see GetControlsList()'s own doc comment for
    ///        where every entry came from.
    static DrawControlsTab = function() {
        var _panel = _PanelRect();
        var _x     = _panel.x1 + SETTINGS_CONTENT_PAD_X;

        draw_set_valign(fa_middle);

        for (var i = 0; i < array_length(controlsList); i++) {
            var _y     = _ContentRowY(i) + (SETTINGS_ROW_HEIGHT / 2);
            var _entry = controlsList[i];

            draw_set_halign(fa_left);
            draw_set_color(HOVER_CARD_TEXT_COLOR);
            draw_text(_x, _y, _entry.action);

            draw_set_halign(fa_right);
            draw_set_color(c_white);
            draw_text(_panel.x2 - SETTINGS_CONTENT_PAD_X, _y, _entry.key);
        }
    }

    /// @function DrawAudioTab()
    static DrawAudioTab = function() {
        var _rows = _AudioRowRects();
        var _s    = global.gameSettings;

        _DrawSlider(_rows.master.sliderX, _rows.master.y, _s.masterVolume, "Master", _s.masterMuted);
        _DrawToggle(_rows.master.toggleX, _rows.master.y, _s.masterMuted, "Mute");

        _DrawSlider(_rows.music.sliderX, _rows.music.y, _s.musicVolume, "Music", _s.musicMuted);
        _DrawToggle(_rows.music.toggleX, _rows.music.y, _s.musicMuted, "Mute");

        _DrawSlider(_rows.sfx.sliderX, _rows.sfx.y, _s.sfxVolume, "SFX", _s.sfxMuted);
        _DrawToggle(_rows.sfx.toggleX, _rows.sfx.y, _s.sfxMuted, "Mute");
    }

    /// @function DrawGraphicsTab()
    static DrawGraphicsTab = function() {
        var _rows = _GraphicsRowRects();
        var _s    = global.gameSettings;

        _DrawToggle(_rows.fullscreenToggleX, _rows.fullscreenY, _s.fullscreen, "Fullscreen");

        var _borderlessLabel = "Borderless Windowed" + (_s.fullscreen ? " (windowed only)" : "");
        _DrawToggle(_rows.borderlessToggleX, _rows.borderlessY, _s.borderless, _borderlessLabel);

        _DrawSlider(_rows.gammaSliderX, _rows.gammaY, _s.gamma, "Gamma", false);
    }

    /// @function DrawAccessibilityTab()
    /// @description STUB per explicit request ("Accessibility will be a
    ///        stub for now, unless you have an idea for it") -- the rows
    ///        below are exactly that idea, drawn greyed-out/non-interactive
    ///        (Update() never checks hits against this tab) rather than a
    ///        single blank message, so there's something concrete to react
    ///        to/veto. None of these are wired to anything real yet.
    static DrawAccessibilityTab = function() {
        var _panel = _PanelRect();
        var _x     = _panel.x1 + SETTINGS_CONTENT_PAD_X;

        draw_set_halign(fa_left);
        draw_set_valign(fa_middle);
        draw_set_color(SETTINGS_DISABLED_COLOR);

        var _ideas = ["Colorblind-Friendly Team Colors", "UI Text Scale", "Reduce Screen Shake && Flash Effects"];
        for (var i = 0; i < array_length(_ideas); i++) {
            draw_text(_x, _ContentRowY(i) + (SETTINGS_ROW_HEIGHT / 2), _ideas[i] + " -- Coming Soon");
        }

        draw_set_color(HOVER_CARD_TEXT_COLOR);
        draw_text(_x, _ContentRowY(array_length(_ideas) + 1) + (SETTINGS_ROW_HEIGHT / 2), "More accessibility options are planned -- let us know what you need.");
    }

    /// @function DrawRestartProgressConfirm()
    /// @description Internal helper for Draw() -- the Yes/No confirm
    ///        sub-panel for Restart Progress, same shared row-drawing shape
    ///        PauseMenu.DrawMenuList()/TitleMenu's own confirm use.
    static DrawRestartProgressConfirm = function() {
        var _pos = PositionDropDownMenuCentered(array_length(confirmOptions));
        DrawDropDownMenuTitle(_pos.x, _pos.y, "Restart Progress?");

        var _rowY = _pos.y + DropDownMenuTitleHeight();
        for (var i = 0; i < array_length(confirmOptions); i++) {
            var _isBottom = (i == array_length(confirmOptions) - 1);
            var _rowH     = DropDownMenuRowHeight(_isBottom);

            DrawDropDownMenuRowBackground(_pos.x, _rowY, _isBottom, (i == confirmHoveredIndex));

            draw_set_color(HOVER_CARD_TEXT_COLOR);
            draw_set_halign(fa_left);
            draw_set_valign(fa_middle);
            draw_text(DropDownMenuRowContentX(_pos.x), _rowY + (_rowH / 2), confirmOptions[i]);

            _rowY += _rowH;
        }
    }

    /// @function _DrawSlider(_x, _y, _value, _label, _muted)
    /// @description Draws one labeled slider -- track, filled portion,
    ///        round handle -- greyed when _muted. Used by the Audio tab's 3
    ///        volume sliders and the Graphics tab's gamma slider (which
    ///        passes _muted = false -- it has no mute concept).
    /// @param {Real} _x Track's left edge.
    /// @param {Real} _y Track's vertical center.
    /// @param {Real} _value 0..1
    /// @param {String} _label
    /// @param {Bool} _muted
    static _DrawSlider = function(_x, _y, _value, _label, _muted) {
        var _track = _SliderTrackRect(_x, _y);

        draw_set_halign(fa_left);
        draw_set_valign(fa_middle);
        draw_set_color(HOVER_CARD_TEXT_COLOR);
        draw_text(_x, _y - 20, _label);

        draw_set_color(_muted ? SETTINGS_DISABLED_COLOR : SETTINGS_TRACK_EMPTY_COLOR);
        draw_rectangle(_track.x1, _track.y1, _track.x2, _track.y2, false);

        var _fillX = _track.x1 + (_track.x2 - _track.x1) * _value;
        draw_set_color(_muted ? SETTINGS_DISABLED_COLOR : c_white);
        draw_rectangle(_track.x1, _track.y1, _fillX, _track.y2, false);
        draw_circle(_fillX, _y, SETTINGS_SLIDER_HANDLE_R, false);

        draw_set_color(HOVER_CARD_TEXT_COLOR);
        draw_set_halign(fa_right);
        draw_text(_track.x2 + 40, _y, string(round(_value * 100)) + "%");
    }

    /// @function _DrawToggle(_x, _y, _on, _label)
    /// @description Draws one small checkbox-style toggle + its label to
    ///        the right. Used for the 3 mute toggles (Audio) and the
    ///        Fullscreen/Borderless toggles (Graphics).
    /// @param {Real} _x Box's left edge.
    /// @param {Real} _y Box's vertical center.
    /// @param {Bool} _on
    /// @param {String} _label
    static _DrawToggle = function(_x, _y, _on, _label) {
        var _rect = _ToggleRect(_x, _y);

        draw_set_color(_on ? c_white : SETTINGS_TRACK_EMPTY_COLOR);
        draw_rectangle(_rect.x1, _rect.y1, _rect.x2, _rect.y2, false);
        draw_set_color(c_white);
        draw_rectangle(_rect.x1, _rect.y1, _rect.x2, _rect.y2, true);

        draw_set_halign(fa_left);
        draw_set_valign(fa_middle);
        draw_set_color(HOVER_CARD_TEXT_COLOR);
        draw_text(_rect.x2 + 12, _y, _label);
    }

    /// @function _DrawActionButton(_rect, _label, [_enabled])
    /// @description Same plain rectangle+text button style
    ///        FateEngineOverlay's temporary buttons use (DrawOneButton,
    ///        FateEngineOverlayScripts.gml) -- reused verbatim rather than
    ///        redeclared, since no generic button sprite exists anywhere in
    ///        the project.
    /// @param {Struct} _rect { x1, y1, x2, y2 }
    /// @param {String} _label
    /// @param {Bool} [_enabled]
    static _DrawActionButton = function(_rect, _label, _enabled = true) {
        draw_set_color(_enabled ? SETTINGS_TAB_ACTIVE_COLOR : SETTINGS_DISABLED_COLOR);
        draw_rectangle(_rect.x1, _rect.y1, _rect.x2, _rect.y2, false);
        draw_set_color(c_white);
        draw_rectangle(_rect.x1, _rect.y1, _rect.x2, _rect.y2, true);

        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(_enabled ? c_white : make_color_rgb(0xAA, 0xAA, 0xAA));
        draw_text((_rect.x1 + _rect.x2) / 2, (_rect.y1 + _rect.y2) / 2, _label);
    }
}
