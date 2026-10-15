// The shared settings menu (sub-menu of PauseMenu/TitleMenu). See
// SettingsOverlayScripts.md.

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

#macro SETTINGS_HOVER_DELAY_MAX_SECONDS 5
#macro SETTINGS_HOVER_DELAY_SNAP_SECONDS 0.5
#macro SETTINGS_CURSOR_SCALE_MIN 1
#macro SETTINGS_CURSOR_SCALE_MAX 3

#macro SETTINGS_PANEL_FILL_COLOR   make_color_rgb(0x3A, 0x2E, 0x4A)
#macro SETTINGS_TAB_ACTIVE_COLOR   make_color_rgb(0x5A, 0x46, 0x6E)
#macro SETTINGS_TAB_INACTIVE_COLOR make_color_rgb(0x2A, 0x20, 0x36)
#macro SETTINGS_TAB_HOVER_COLOR    make_color_rgb(0x40, 0x32, 0x52)
#macro SETTINGS_DISABLED_COLOR     make_color_rgb(0x55, 0x55, 0x55)
#macro SETTINGS_TRACK_EMPTY_COLOR  make_color_rgb(0x1A, 0x14, 0x22)

/// @function DefaultGameSettings()
/// @description Every persisted setting at its default value.
/// @returns {Struct}
function DefaultGameSettings() {
    return {
        masterVolume: 1,
        musicVolume:  1,
        sfxVolume:    1,
        musicMuted:   false,
        sfxMuted:     false,
        fullscreen:   false,
        borderless:   false,
        gamma:        0.5, // 0.5 = neutral, not applied to anything yet
        hoverDelayBottomBar:  1.0, // seconds
        hoverDelayWorldItems: 1.0, // seconds
        cursorScale:  2, // whole numbers, SETTINGS_CURSOR_SCALE_MIN..MAX
    };
}

/// @function LoadGameSettings()
/// @description Loads global.gameSettings from SETTINGS_SAVE_FILE, falling
///        back to DefaultGameSettings() per missing key.
function LoadGameSettings() {
    var _d = DefaultGameSettings();

    ini_open(SETTINGS_SAVE_FILE);
    global.gameSettings = {
        masterVolume: ini_read_real("Audio", "masterVolume", _d.masterVolume),
        musicVolume:  ini_read_real("Audio", "musicVolume",  _d.musicVolume),
        sfxVolume:    ini_read_real("Audio", "sfxVolume",    _d.sfxVolume),
        musicMuted:   ini_read_real("Audio", "musicMuted",   _d.musicMuted  ? 1 : 0) != 0,
        sfxMuted:     ini_read_real("Audio", "sfxMuted",     _d.sfxMuted    ? 1 : 0) != 0,
        fullscreen:   ini_read_real("Graphics", "fullscreen", _d.fullscreen ? 1 : 0) != 0,
        borderless:   ini_read_real("Graphics", "borderless", _d.borderless ? 1 : 0) != 0,
        gamma:        ini_read_real("Graphics", "gamma", _d.gamma),
        hoverDelayBottomBar:  ini_read_real("Gameplay", "hoverDelayBottomBar",  _d.hoverDelayBottomBar),
        hoverDelayWorldItems: ini_read_real("Gameplay", "hoverDelayWorldItems", _d.hoverDelayWorldItems),
        cursorScale:  clamp(round(ini_read_real("Graphics", "cursorScale", _d.cursorScale)), SETTINGS_CURSOR_SCALE_MIN, SETTINGS_CURSOR_SCALE_MAX),
    };
    ini_close();
}

/// @function SaveGameSettings()
/// @description Writes global.gameSettings out to SETTINGS_SAVE_FILE.
function SaveGameSettings() {
    var _s = global.gameSettings;

    ini_open(SETTINGS_SAVE_FILE);
    ini_write_real("Audio", "masterVolume", _s.masterVolume);
    ini_write_real("Audio", "musicVolume",  _s.musicVolume);
    ini_write_real("Audio", "sfxVolume",    _s.sfxVolume);
    ini_write_real("Audio", "musicMuted",   _s.musicMuted  ? 1 : 0);
    ini_write_real("Audio", "sfxMuted",     _s.sfxMuted    ? 1 : 0);
    ini_write_real("Graphics", "fullscreen", _s.fullscreen ? 1 : 0);
    ini_write_real("Graphics", "borderless", _s.borderless ? 1 : 0);
    ini_write_real("Graphics", "gamma", _s.gamma);
    ini_write_real("Gameplay", "hoverDelayBottomBar",  _s.hoverDelayBottomBar);
    ini_write_real("Gameplay", "hoverDelayWorldItems", _s.hoverDelayWorldItems);
    ini_write_real("Graphics", "cursorScale", _s.cursorScale);
    ini_close();
}

/// @function PerceptualGain(_linear)
/// @description Squares a linear 0..1 value for perceptually-even volume.
///        Applies to Music/SFX; Master stays linear. See .md.
/// @param {Real} _linear 0..1
/// @returns {Real}
function PerceptualGain(_linear) {
    return _linear * _linear;
}

/// @function ApplyGameSettings()
/// @description Pushes global.gameSettings onto the actual runtime state
///        (master/music gain, fullscreen/borderless). See .md.
function ApplyGameSettings() {
    var _s = global.gameSettings;

    audio_master_gain(_s.masterVolume);

    if (variable_global_exists("titleMusicInstance") && audio_is_playing(global.titleMusicInstance)) {
        audio_sound_gain(global.titleMusicInstance, _s.musicMuted ? 0 : PerceptualGain(_s.musicVolume), 0);
    }

    window_enable_borderless_fullscreen(_s.borderless); // set before fullscreen -- only affects future toggles
    window_set_fullscreen(_s.fullscreen);
}

/// @function LoadAndApplyGameSettings()
/// @description LoadGameSettings() then ApplyGameSettings() in one call.
function LoadAndApplyGameSettings() {
    LoadGameSettings();
    ApplyGameSettings();
}

/// @function GetControlsList()
/// @description The real, currently-bound control scheme. Visual-only readout, no rebinding.
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
/// @description The shared settings menu. Plain struct, owner calls
///        Update() once per Step and Draw() once per Draw GUI.
function SettingsOverlay() constructor {
    if (!variable_global_exists("gameSettings")) LoadAndApplyGameSettings();

    isOpen     = false;
    activeTab  = 0;
    hoveredTab = -1;

    tabs         = ["Gameplay", "Controls", "Audio", "Graphics", "Accessibility"];
    controlsList = GetControlsList();

    draggingSlider = undefined; // undefined | "master" | "music" | "sfx" | "hoverDelayBottomBar" | "hoverDelayWorldItems" | "cursorScale"
    draggingGamma  = false;

    confirmRestartProgress = false;
    confirmHoveredIndex    = -1;
    confirmOptions         = ["Yes", "No"];

    /// @function Open()
    /// @description Opens the settings overlay, always resetting to the Gameplay tab. No-ops if already open.
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
    /// @returns {Struct.SettingsOverlay} self
    static Close = function() {
        isOpen                 = false;
        draggingSlider          = undefined;
        draggingGamma           = false;
        confirmRestartProgress  = false;
        return self;
    }

    /// @function RestartTutorial()
    /// @description Resets every tutorial-progress field to default and saves.
    static RestartTutorial = function() {
        ResetTutorialProgress();
    }

    /// @function _ShouldShowRestartTutorial()
    /// @description Whether the Restart Tutorial button is visible/clickable
    ///        this frame -- hidden anywhere but the main title, and hidden
    ///        while the tutorial is currently in progress. See .md.
    /// @returns {Bool}
    static _ShouldShowRestartTutorial = function() {
        return (room == rmTitleMenu) && !global.tutorialActive;
    }

    /// @function ResetPlayerProgress()
    /// @description STUB -- see .md for the planned implementation.
    static ResetPlayerProgress = function() {
        // Intentionally empty -- see .md.
    }

    /// @function _PanelRect()
    /// @returns {Struct} { x1, y1, x2, y2 }
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
    /// @returns {Real} GUI-space Y where per-tab content starts.
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

    /// @function _GameplayHoverRowRects()
    /// @returns {Struct} { bottomBar, worldItems }, each { sliderX, y }
    static _GameplayHoverRowRects = function() {
        var _panel = _PanelRect();
        var _x     = _panel.x1 + SETTINGS_CONTENT_PAD_X;

        return {
            bottomBar:  { sliderX: _x, y: _ContentRowY(2) + (SETTINGS_ROW_HEIGHT / 2) + 20 },
            worldItems: { sliderX: _x, y: _ContentRowY(3) + (SETTINGS_ROW_HEIGHT / 2) + 20 },
        };
    }

    /// @function _AudioRowRects()
    /// @returns {Struct} { master: {sliderX, y}, music: {sliderX, toggleX, y}, sfx: {sliderX, toggleX, y} }
    static _AudioRowRects = function() {
        var _panel   = _PanelRect();
        var _sliderX = _panel.x1 + SETTINGS_CONTENT_PAD_X;
        var _toggleX = _sliderX + SETTINGS_SLIDER_WIDTH + 80;

        return {
            master: { sliderX: _sliderX, y: _ContentRowY(0) + (SETTINGS_ROW_HEIGHT / 2) },
            music:  { sliderX: _sliderX, toggleX: _toggleX, y: _ContentRowY(1) + (SETTINGS_ROW_HEIGHT / 2) },
            sfx:    { sliderX: _sliderX, toggleX: _toggleX, y: _ContentRowY(2) + (SETTINGS_ROW_HEIGHT / 2) },
        };
    }

    /// @function _GraphicsRowRects()
    /// @returns {Struct} { fullscreenToggleX, fullscreenY, borderlessToggleX, borderlessY, gammaSliderX, gammaY, cursorSliderX, cursorY }
    static _GraphicsRowRects = function() {
        var _panel = _PanelRect();
        var _x     = _panel.x1 + SETTINGS_CONTENT_PAD_X;

        return {
            fullscreenToggleX: _x, fullscreenY: _ContentRowY(0) + (SETTINGS_ROW_HEIGHT / 2),
            borderlessToggleX: _x, borderlessY: _ContentRowY(1) + (SETTINGS_ROW_HEIGHT / 2),
            gammaSliderX: _x, gammaY: _ContentRowY(2) + (SETTINGS_ROW_HEIGHT / 2) + 20,
            cursorSliderX: _x, cursorY: _ContentRowY(3) + (SETTINGS_ROW_HEIGHT / 2) + 20,
        };
    }

    /// @function _SliderTrackRect(_x, _y)
    /// @param {Real} _x
    /// @param {Real} _y Track's vertical center.
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
    /// @description Converts a GUI-space mouse X into a 0..1 slider value.
    /// @param {Struct} _trackRect
    /// @param {Real} _mx
    /// @returns {Real}
    static _SliderValueFromMouseX = function(_trackRect, _mx) {
        return clamp((_mx - _trackRect.x1) / (_trackRect.x2 - _trackRect.x1), 0, 1);
    }

    /// @function _HoverDelaySecondsFromMouseX(_trackRect, _mx)
    /// @description Converts mouse X into a hover-delay value in seconds, snapped to SETTINGS_HOVER_DELAY_SNAP_SECONDS.
    /// @param {Struct} _trackRect
    /// @param {Real} _mx
    /// @returns {Real}
    static _HoverDelaySecondsFromMouseX = function(_trackRect, _mx) {
        var _raw = _SliderValueFromMouseX(_trackRect, _mx) * SETTINGS_HOVER_DELAY_MAX_SECONDS;
        return round(_raw / SETTINGS_HOVER_DELAY_SNAP_SECONDS) * SETTINGS_HOVER_DELAY_SNAP_SECONDS;
    }

    /// @function _CursorScaleFromMouseX(_trackRect, _mx)
    /// @description Converts mouse X into a whole-number cursor scale, SETTINGS_CURSOR_SCALE_MIN..MAX.
    /// @param {Struct} _trackRect
    /// @param {Real} _mx
    /// @returns {Real}
    static _CursorScaleFromMouseX = function(_trackRect, _mx) {
        var _steps = SETTINGS_CURSOR_SCALE_MAX - SETTINGS_CURSOR_SCALE_MIN;
        return SETTINGS_CURSOR_SCALE_MIN + round(_SliderValueFromMouseX(_trackRect, _mx) * _steps);
    }

    /// @function _PointInRect(_px, _py, _rect)
    /// @param {Real} _px
    /// @param {Real} _py
    /// @param {Struct} _rect { x1, y1, x2, y2 }
    /// @returns {Bool}
    static _PointInRect = function(_px, _py, _rect) {
        return (_px >= _rect.x1 && _px <= _rect.x2 && _py >= _rect.y1 && _py <= _rect.y2);
    }

    /// @function Update()
    /// @description Call once per Step while this overlay might be open.
    /// @returns {Struct.SettingsOverlay} self
    static Update = function() {
        if (!isOpen) return self;

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        if (confirmRestartProgress) {
            var _pos = PositionDropDownMenuCentered(array_length(confirmOptions));
            confirmHoveredIndex = DropDownMenuHitTest(_pos.x, _pos.y, array_length(confirmOptions), _mx, _my);

            if (keyboard_check_pressed(vk_escape)) {
                confirmRestartProgress = false;
                return self;
            }
            if (mouse_check_button_pressed(mb_left)) {
                if (confirmHoveredIndex == 0) ResetPlayerProgress(); // "Yes"
                confirmRestartProgress = false;
            }
            return self;
        }

        if (draggingSlider != undefined || draggingGamma) {
            if (!mouse_check_button(mb_left)) {
                draggingSlider = undefined;
                draggingGamma  = false;
                SaveGameSettings();
            } else if (draggingSlider == "cursorScale") {
                var _c = _GraphicsRowRects();
                global.gameSettings.cursorScale = _CursorScaleFromMouseX(_SliderTrackRect(_c.cursorSliderX, _c.cursorY), _mx);
            } else if (draggingGamma) {
                var _g = _GraphicsRowRects();
                global.gameSettings.gamma = _SliderValueFromMouseX(_SliderTrackRect(_g.gammaSliderX, _g.gammaY), _mx);
            } else if (draggingSlider == "hoverDelayBottomBar" || draggingSlider == "hoverDelayWorldItems") {
                var _hoverRows = _GameplayHoverRowRects();
                if (draggingSlider == "hoverDelayBottomBar") {
                    global.gameSettings.hoverDelayBottomBar = _HoverDelaySecondsFromMouseX(_SliderTrackRect(_hoverRows.bottomBar.sliderX, _hoverRows.bottomBar.y), _mx);
                } else {
                    global.gameSettings.hoverDelayWorldItems = _HoverDelaySecondsFromMouseX(_SliderTrackRect(_hoverRows.worldItems.sliderX, _hoverRows.worldItems.y), _mx);
                }
            } else {
                var _rows = _AudioRowRects();
                if (draggingSlider == "master") {
                    global.gameSettings.masterVolume = _SliderValueFromMouseX(_SliderTrackRect(_rows.master.sliderX, _rows.master.y), _mx);
                    ApplyGameSettings();
                } else if (draggingSlider == "music") {
                    global.gameSettings.musicVolume = _SliderValueFromMouseX(_SliderTrackRect(_rows.music.sliderX, _rows.music.y), _mx);
                    ApplyGameSettings();
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
            return self;
        }

        if (mouse_check_button_pressed(mb_left) && _PointInRect(_mx, _my, _BackButtonRect())) {
            Close();
            return self;
        }

        switch (activeTab) {
            case 0: _UpdateGameplayTab(_mx, _my); break;
            case 1: break;
            case 2: _UpdateAudioTab(_mx, _my); break;
            case 3: _UpdateGraphicsTab(_mx, _my); break;
            case 4: break;
        }

        return self;
    }

    /// @function _UpdateGameplayTab(_mx, _my)
    /// @param {Real} _mx
    /// @param {Real} _my
    static _UpdateGameplayTab = function(_mx, _my) {
        if (!mouse_check_button_pressed(mb_left)) return;

        var _rects = _GameplayButtonRects();
        if (_ShouldShowRestartTutorial() && _PointInRect(_mx, _my, _rects.restartTutorial)) {
            RestartTutorial();
            return;
        }
        if (_PointInRect(_mx, _my, _rects.restartProgress)) {
            confirmRestartProgress = true;
            confirmHoveredIndex    = -1;
            return;
        }

        var _hoverRows = _GameplayHoverRowRects();
        var _bottomBarTrack  = _SliderTrackRect(_hoverRows.bottomBar.sliderX, _hoverRows.bottomBar.y);
        var _worldItemsTrack = _SliderTrackRect(_hoverRows.worldItems.sliderX, _hoverRows.worldItems.y);

        if (_PointInRect(_mx, _my, _bottomBarTrack)) {
            draggingSlider = "hoverDelayBottomBar";
            global.gameSettings.hoverDelayBottomBar = _HoverDelaySecondsFromMouseX(_bottomBarTrack, _mx);
            return;
        }
        if (_PointInRect(_mx, _my, _worldItemsTrack)) {
            draggingSlider = "hoverDelayWorldItems";
            global.gameSettings.hoverDelayWorldItems = _HoverDelaySecondsFromMouseX(_worldItemsTrack, _mx);
            return;
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
            ApplyGameSettings();
            return;
        }
        if (_PointInRect(_mx, _my, _SliderTrackRect(_rows.sfx.sliderX, _rows.sfx.y))) {
            draggingSlider = "sfx";
            global.gameSettings.sfxVolume = _SliderValueFromMouseX(_SliderTrackRect(_rows.sfx.sliderX, _rows.sfx.y), _mx);
            return;
        }

        if (_PointInRect(_mx, _my, _ToggleRect(_rows.music.toggleX, _rows.music.y))) {
            global.gameSettings.musicMuted = !global.gameSettings.musicMuted;
            ApplyGameSettings();
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
        var _cursorTrack = _SliderTrackRect(_rows.cursorSliderX, _rows.cursorY);
        if (_PointInRect(_mx, _my, _cursorTrack)) {
            draggingSlider = "cursorScale";
            global.gameSettings.cursorScale = _CursorScaleFromMouseX(_cursorTrack, _mx);
            return;
        }
        if (_PointInRect(_mx, _my, _SliderTrackRect(_rows.gammaSliderX, _rows.gammaY))) {
            draggingGamma = true;
            global.gameSettings.gamma = _SliderValueFromMouseX(_SliderTrackRect(_rows.gammaSliderX, _rows.gammaY), _mx);
            return;
        }
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event. No-ops if not open.
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
        if (_ShouldShowRestartTutorial()) {
            _DrawActionButton(_rects.restartTutorial, "Restart Tutorial");
        }
        _DrawActionButton(_rects.restartProgress, "Restart Progress");

        var _hoverRows = _GameplayHoverRowRects();
        var _s         = global.gameSettings;
        _DrawSlider(
            _hoverRows.bottomBar.sliderX, _hoverRows.bottomBar.y,
            _s.hoverDelayBottomBar / SETTINGS_HOVER_DELAY_MAX_SECONDS,
            "Bottom Bar Hover Delay", false,
            $"{string_format(_s.hoverDelayBottomBar, 1, 1)}s"
        );
        _DrawSlider(
            _hoverRows.worldItems.sliderX, _hoverRows.worldItems.y,
            _s.hoverDelayWorldItems / SETTINGS_HOVER_DELAY_MAX_SECONDS,
            "World Item Hover Delay", false,
            $"{string_format(_s.hoverDelayWorldItems, 1, 1)}s"
        );
    }

    /// @function DrawControlsTab()
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

        _DrawSlider(_rows.master.sliderX, _rows.master.y, _s.masterVolume, "Master", false);

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

        var _borderlessLabel = "Borderless Fullscreen" + (_s.fullscreen ? "" : " (applies next time Fullscreen is on)");
        _DrawToggle(_rows.borderlessToggleX, _rows.borderlessY, _s.borderless, _borderlessLabel);

        _DrawSlider(_rows.gammaSliderX, _rows.gammaY, _s.gamma, "Gamma", false);

        _DrawSlider(
            _rows.cursorSliderX, _rows.cursorY,
            (_s.cursorScale - SETTINGS_CURSOR_SCALE_MIN) / (SETTINGS_CURSOR_SCALE_MAX - SETTINGS_CURSOR_SCALE_MIN),
            "Cursor Size", false,
            $"{_s.cursorScale}x"
        );
    }

    /// @function DrawAccessibilityTab()
    /// @description Stub tab -- 3 greyed-out, non-interactive placeholder ideas.
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

    /// @function _DrawSlider(_x, _y, _value, _label, _muted, [_valueText])
    /// @description Draws one labeled slider -- track, filled portion, round handle.
    /// @param {Real} _x Track's left edge.
    /// @param {Real} _y Track's vertical center.
    /// @param {Real} _value 0..1
    /// @param {String} _label
    /// @param {Bool} _muted
    /// @param {String} [_valueText] Overrides the default "NN%" readout.
    static _DrawSlider = function(_x, _y, _value, _label, _muted, _valueText = undefined) {
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
        draw_text(_track.x2 + 40, _y, _valueText ?? (string(round(_value * 100)) + "%"));
    }

    /// @function _DrawToggle(_x, _y, _on, _label)
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
