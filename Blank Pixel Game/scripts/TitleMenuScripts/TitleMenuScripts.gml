// The title/main menu screen. See TitleMenuScripts.md.

#macro TITLE_MENU_SCALE                2
#macro TITLE_MENU_PADDING              16   // native px
#macro TITLE_MENU_BUTTON_PADDING       32   // native px
#macro TITLE_MENU_BUTTON_HOVER_SHIFT   32   // native px
#macro TITLE_MENU_FADE_IN_DURATION     1.0  // seconds
#macro TITLE_MENU_DROP_START_PAD       40   // native px
#macro TITLE_MENU_DROP_DURATION        0.9  // seconds
#macro TITLE_MENU_PROMPT_GAP           24   // native px
#macro TITLE_MENU_PROMPT_TYPE_SPEED    1
#macro TITLE_MENU_PROMPT_OUTLINE_PX    2    // screen px
#macro TITLE_MENU_PROMPT_EXIT_DURATION 0.35 // seconds
#macro TITLE_MENU_DOCK_DURATION        0.6  // seconds
#macro TITLE_MENU_BUTTON_TOP_GAP       24   // native px
#macro TITLE_MENU_BUTTON_ROW_GAP       12   // native px
#macro TITLE_MENU_BUTTON_SLIDE_DURATION 0.45 // seconds
#macro TITLE_MENU_BUTTON_STAGGER       0.08 // seconds, per button index
#macro TITLE_MENU_TRANSITION_DURATION  1.05 // seconds -- covers the longest concurrent animation
#macro TITLE_MENU_HOVER_LERP           0.25

#macro TITLE_MENU_SOCIAL_PADDING_X     32   // native px
#macro TITLE_MENU_SOCIAL_PADDING_Y     32   // native px
#macro TITLE_MENU_SOCIAL_GAP           12   // native px
#macro TITLE_MENU_SOCIAL_BLINK_MIN     5    // seconds
#macro TITLE_MENU_SOCIAL_BLINK_MAX     6    // seconds
#macro TITLE_MENU_SOCIAL_BLINK_FRAME_DURATION 0.08 // seconds per blink frame
#macro TITLE_MENU_SOCIAL_SQUASH_DURATION 0.18 // seconds -- hover-enter pulse; also entrance landing-squash duration
#macro TITLE_MENU_SOCIAL_SQUASH_AMOUNT   0.35
#macro TITLE_MENU_SOCIAL_ENTRY_SQUASH_AMOUNT 0.3

#macro TITLE_MENU_FOOTER_LINE_GAP      22   // native px

// Flag-wave hover shader uniform handles -- see TitleMenuFlagWaveInit(), TitleMenuScripts.md.
global.__titleFlagWaveUniformTime      = -1;
global.__titleFlagWaveUniformIntensity = -1;
global.__titleFlagWaveUniformRect      = -1;

/// @function TitleMenuFlagWaveInit()
/// @description Caches shFlagWave's uniform handles once. Call once at game start.
function TitleMenuFlagWaveInit() {
    global.__titleFlagWaveUniformTime      = shader_get_uniform(shFlagWave, "u_time");
    global.__titleFlagWaveUniformIntensity = shader_get_uniform(shFlagWave, "u_intensity");
    global.__titleFlagWaveUniformRect      = shader_get_uniform(shFlagWave, "u_spriteRect");

    if (global.__titleFlagWaveUniformTime == -1 || global.__titleFlagWaveUniformIntensity == -1 || global.__titleFlagWaveUniformRect == -1) {
        show_debug_message("[TitleMenuFlagWaveInit] WARNING: one or more shFlagWave handles not found - check shFlagWave.fsh uniform names");
    }
}

/// @function TitleMenuButton(_sprite, _action)
/// @description One menu button's static + animated state.
/// @param {Asset.GMSprite} _sprite
/// @param {String} _action "play" | "settings" | "credits" | "exit"
function TitleMenuButton(_sprite, _action) constructor {
    sprite = _sprite;
    action = _action;
    width  = sprite_get_width(_sprite);
    height = sprite_get_height(_sprite);

    restX  = 0; // resting position, right-edge padded
    restY  = 0;
    startX = 0; // off-screen start position

    x      = 0;
    y      = 0;
    offset = 0; // current hover-shift offset, 0..TITLE_MENU_BUTTON_HOVER_SHIFT*TITLE_MENU_SCALE
}

/// @function TitleMenuSocialButton(_sprite, _platform, _animated)
/// @description One social-media icon's static + animated state. _animated
///        is true only for Discord (blink cycle).
/// @param {Asset.GMSprite} _sprite
/// @param {String} _platform "steam" | "x" | "itch" | "discord" | "tiktok" | "youtube"
/// @param {Bool} _animated
function TitleMenuSocialButton(_sprite, _platform, _animated) constructor {
    sprite   = _sprite;
    platform = _platform;
    animated = _animated;
    width    = sprite_get_width(_sprite);
    height   = sprite_get_height(_sprite);

    restX  = 0;
    restY  = 0;
    startY = 0;

    x = 0;
    y = 0;

    frameIndex      = 0;
    blinking        = false;
    blinkFrameTimer = 0;
    blinkTimer      = _animated ? random_range(TITLE_MENU_SOCIAL_BLINK_MIN, TITLE_MENU_SOCIAL_BLINK_MAX) : 0;

    hovered     = false;
    squashTimer = 0;
    xscale      = 1;
    yscale      = 1;
}

/// @function TitleMenu(_settingsOverlay, _creditsOverlay)
/// @description The title screen. Plain struct owned by oTitleMenu.
/// @param {Struct.SettingsOverlay} _settingsOverlay
/// @param {Struct.CreditsOverlay} _creditsOverlay
function TitleMenu(_settingsOverlay, _creditsOverlay) constructor {
    state           = "fadeIn";
    stateTimer      = 0;
    settingsOverlay = _settingsOverlay;
    creditsOverlay  = _creditsOverlay;

    var _guiW = display_get_gui_width();
    var _guiH = display_get_gui_height();

    titleW = sprite_get_width(sTitle)  * TITLE_MENU_SCALE;
    titleH = sprite_get_height(sTitle) * TITLE_MENU_SCALE;

    titleCenterX = (_guiW / 2) + (titleW / 2); // origin is top-right
    titleCenterY = (_guiH / 2) - (titleH / 2);
    titleDropStartY = -titleH - (TITLE_MENU_DROP_START_PAD * TITLE_MENU_SCALE);

    titleDockedX = _guiW - (TITLE_MENU_PADDING * TITLE_MENU_SCALE);
    titleDockedY = TITLE_MENU_PADDING * TITLE_MENU_SCALE;

    titleX = titleCenterX;
    titleY = titleDropStartY;

    promptX      = _guiW / 2;
    promptRestY  = titleCenterY + titleH + (TITLE_MENU_PROMPT_GAP * TITLE_MENU_SCALE);
    promptExitY  = _guiH + 64;
    promptY      = promptRestY;

    promptTextWhite = scribble("[fntResource][c_white][wave]Press Any Key[/wave]").align(fa_center, fa_middle);
    promptTextBlack = scribble("[fntResource][c_black][wave]Press Any Key[/wave]").align(fa_center, fa_middle);

    promptTypistWhite = scribble_typist(); // separate typists per element -- see .md
    promptTypistBlack = scribble_typist();

    buttons = [
        new TitleMenuButton(sPlayOption,     "play"),
        new TitleMenuButton(sSettingsOption, "settings"),
        new TitleMenuButton(sCreditsOption,  "credits"),
        new TitleMenuButton(sExitOption,     "exit"),
    ];

    var _rowY = titleDockedY + titleH + (TITLE_MENU_BUTTON_TOP_GAP * TITLE_MENU_SCALE);
    for (var i = 0; i < array_length(buttons); i++) {
        var _b = buttons[i];
        var _rowH = _b.height * TITLE_MENU_SCALE;

        _b.restX  = _guiW - (TITLE_MENU_BUTTON_PADDING * TITLE_MENU_SCALE);
        _b.restY  = _rowY + (_rowH / 2);
        _b.startX = _guiW + (_b.width * TITLE_MENU_SCALE);
        _b.x      = _b.startX;
        _b.y      = _b.restY;

        _rowY += _rowH + (TITLE_MENU_BUTTON_ROW_GAP * TITLE_MENU_SCALE);
    }

    hoveredButtonIndex = -1;

    socialButtons = [
        new TitleMenuSocialButton(sSteamIcon,   "steam",   false),
        new TitleMenuSocialButton(sXIcon,       "x",       false),
        new TitleMenuSocialButton(sItchIOIcon,  "itch",    false),
        new TitleMenuSocialButton(sDiscordIcon, "discord", true),
        new TitleMenuSocialButton(sTikTokIcon,  "tiktok",  false),
        new TitleMenuSocialButton(sYouTubeIcon, "youtube", false),
    ];

    var _socialTotalW = 0;
    for (var i = 0; i < array_length(socialButtons); i++) {
        _socialTotalW += socialButtons[i].width * TITLE_MENU_SCALE;
    }
    _socialTotalW += (array_length(socialButtons) - 1) * (TITLE_MENU_SOCIAL_GAP * TITLE_MENU_SCALE);

    var _socialRowRight = _guiW - (TITLE_MENU_SOCIAL_PADDING_X * TITLE_MENU_SCALE);
    var _socialCursorX  = _socialRowRight - _socialTotalW;

    for (var i = 0; i < array_length(socialButtons); i++) {
        var _s = socialButtons[i];
        var _sw = _s.width  * TITLE_MENU_SCALE;
        var _sh = _s.height * TITLE_MENU_SCALE;

        _s.restX  = _socialCursorX + (_sw / 2);
        _s.restY  = _guiH - (TITLE_MENU_SOCIAL_PADDING_Y * TITLE_MENU_SCALE) - (_sh / 2);
        _s.startY = _guiH + _sh;
        _s.x      = _s.restX;
        _s.y      = _s.startY;

        _socialCursorX += _sw + (TITLE_MENU_SOCIAL_GAP * TITLE_MENU_SCALE);
    }

    exitConfirmActive        = false;
    exitConfirmHoveredIndex  = -1;
    exitConfirmOptions       = ["Yes", "No"];
    exitConfirmX             = 0;
    exitConfirmY             = 0;

    /// @function _EaseOutBounce(_t)
    /// @param {Real} _t 0..1
    /// @returns {Real}
    static _EaseOutBounce = function(_t) {
        var _n1 = 7.5625;
        var _d1 = 2.75;
        if (_t < 1 / _d1) {
            return _n1 * _t * _t;
        } else if (_t < 2 / _d1) {
            _t -= 1.5 / _d1;
            return _n1 * _t * _t + 0.75;
        } else if (_t < 2.5 / _d1) {
            _t -= 2.25 / _d1;
            return _n1 * _t * _t + 0.9375;
        } else {
            _t -= 2.625 / _d1;
            return _n1 * _t * _t + 0.984375;
        }
    }

    /// @function _EaseInQuad(_t)
    /// @param {Real} _t 0..1
    /// @returns {Real}
    static _EaseInQuad = function(_t) {
        return _t * _t;
    }

    /// @function _EaseOutQuad(_t)
    /// @param {Real} _t 0..1
    /// @returns {Real}
    static _EaseOutQuad = function(_t) {
        return 1 - (1 - _t) * (1 - _t);
    }

    /// @function _EaseInOutQuad(_t)
    /// @param {Real} _t 0..1
    /// @returns {Real}
    static _EaseInOutQuad = function(_t) {
        return (_t < 0.5) ? (2 * _t * _t) : (1 - power(-2 * _t + 2, 2) / 2);
    }

    /// @function _EaseOutBack(_t)
    /// @description Overshoots past 1.0 partway through, then settles to exactly 1.0.
    /// @param {Real} _t 0..1
    /// @returns {Real}
    static _EaseOutBack = function(_t) {
        var _c1 = 1.70158;
        var _c3 = _c1 + 1;
        var _x  = _t - 1;
        return 1 + _c3 * _x * _x * _x + _c1 * _x * _x;
    }

    /// @function _AnyInputPressed()
    /// @returns {Bool}
    static _AnyInputPressed = function() {
        return keyboard_check_pressed(vk_anykey)
            || gamepad_button_check_pressed(0, gp_face1)
            || mouse_check_button_pressed(mb_left);
    }

    /// @function _ButtonRect(_b)
    /// @description Hover hit-test rect. Right edge pinned to the screen's
    ///        right edge (not the sprite's) so the hoverable area still
    ///        covers the button once it shifts left on hover.
    /// @param {Struct.TitleMenuButton} _b
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _ButtonRect = function(_b) {
        var _w = _b.width  * TITLE_MENU_SCALE;
        var _h = _b.height * TITLE_MENU_SCALE;
        return {
            x1: _b.x - _w, y1: _b.y - (_h / 2),
            x2: display_get_gui_width(), y2: _b.y + (_h / 2)
        };
    }

    /// @function _HandleButtonAction(_action)
    /// @param {String} _action
    static _HandleButtonAction = function(_action) {
        switch (_action) {
            case "play":
                audio_sound_gain(global.titleMusicInstance, 0, 1000);
                call_later(1, time_source_units_seconds, function() {
                    audio_stop_sound(global.titleMusicInstance);
                });
                room_goto(rmHubTown);
                break;

            case "settings":
                _OpenSettings();
                break;

            case "credits":
                _OpenCredits();
                break;

            case "exit":
                exitConfirmActive       = true;
                exitConfirmHoveredIndex = -1;
                var _pos = PositionDropDownMenuCentered(array_length(exitConfirmOptions));
                exitConfirmX = _pos.x;
                exitConfirmY = _pos.y;
                break;
        }
    }

    /// @function _SocialButtonRect(_b)
    /// @description Origin is middle-center for these (unlike _ButtonRect's middle-right).
    /// @param {Struct.TitleMenuSocialButton} _b
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _SocialButtonRect = function(_b) {
        var _w = _b.width  * TITLE_MENU_SCALE;
        var _h = _b.height * TITLE_MENU_SCALE;
        return {
            x1: _b.x - (_w / 2), y1: _b.y - (_h / 2),
            x2: _b.x + (_w / 2), y2: _b.y + (_h / 2)
        };
    }

    /// @function _HandleSocialClick(_platform)
    /// @description Itch.io's URL is a placeholder (commented out) pending the real link.
    /// @param {String} _platform
    static _HandleSocialClick = function(_platform) {
        switch (_platform) {
            case "steam":
                url_open("https://store.steampowered.com/app/4423330/Theyre_Gonna_Get_In/?beta=0");
                break;
            case "x":
                url_open("https://x.com/iConStudioTX?s=20");
                break;
            case "itch":
                // url_open("https://PLACEHOLDER.itch.io/");
                break;
            case "discord":
                url_open("https://discord.gg/VzxFeQWBvT");
                break;
            case "tiktok":
                url_open("https://www.tiktok.com/@iconstudiotx?is_from_webapp=1&sender_device=pc");
                break;
            case "youtube":
                url_open("https://www.youtube.com/channel/UCQpEH_l7WOSHoGN_jV-S_fw");
                break;
        }
    }

    /// @function _UpdateSocialButtons(_dt)
    /// @description Drives Discord's blink cycle plus every icon's hover-squash pulse. state == "menu" only.
    /// @param {Real} _dt
    static _UpdateSocialButtons = function(_dt) {
        for (var i = 0; i < array_length(socialButtons); i++) {
            var _b = socialButtons[i];

            if (_b.squashTimer > 0) {
                _b.squashTimer = max(0, _b.squashTimer - _dt);

                var _squashT      = 1 - (_b.squashTimer / TITLE_MENU_SOCIAL_SQUASH_DURATION);
                var _squashAmount = sin(_squashT * pi) * TITLE_MENU_SOCIAL_SQUASH_AMOUNT;
                _b.xscale = 1 + _squashAmount;
                _b.yscale = 1 - _squashAmount;
            } else {
                _b.xscale = 1;
                _b.yscale = 1;
            }

            if (!_b.animated) continue;

            if (_b.blinking) {
                _b.blinkFrameTimer += _dt;
                if (_b.blinkFrameTimer >= TITLE_MENU_SOCIAL_BLINK_FRAME_DURATION) {
                    _b.blinkFrameTimer = 0;
                    _b.frameIndex     += 1;
                    if (_b.frameIndex > 3) {
                        _b.frameIndex = 0;
                        _b.blinking   = false;
                        _b.blinkTimer = random_range(TITLE_MENU_SOCIAL_BLINK_MIN, TITLE_MENU_SOCIAL_BLINK_MAX);
                    }
                }
            } else {
                _b.blinkTimer -= _dt;
                if (_b.blinkTimer <= 0) {
                    _b.blinking        = true;
                    _b.frameIndex      = 1;
                    _b.blinkFrameTimer = 0;
                }
            }
        }
    }

    /// @function _OpenSettings()
    /// @description Opens the shared SettingsOverlay sub-menu.
    static _OpenSettings = function() {
        settingsOverlay.Open();
    }

    /// @function _OpenCredits()
    /// @description Opens the shared CreditsOverlay sub-menu.
    static _OpenCredits = function() {
        creditsOverlay.Open();
    }

    /// @function Update()
    /// @description Call once per Step event.
    static Update = function() {
        if (settingsOverlay.isOpen) {
            settingsOverlay.Update();
            return;
        }

        if (creditsOverlay.isOpen) {
            creditsOverlay.Update();
            return;
        }

        var _dt = delta_time / 1000000;
        stateTimer += _dt;

        switch (state) {
            case "fadeIn":
                if (stateTimer >= TITLE_MENU_FADE_IN_DURATION) {
                    state      = "titleDrop";
                    stateTimer = 0;
                }
                break;

            case "titleDrop":
                var _t = clamp(stateTimer / TITLE_MENU_DROP_DURATION, 0, 1);
                titleY = lerp(titleDropStartY, titleCenterY, _EaseOutBounce(_t));

                if (_t >= 1) {
                    titleY     = titleCenterY;
                    state      = "prompt";
                    stateTimer = 0;
                    promptTypistWhite.in(TITLE_MENU_PROMPT_TYPE_SPEED, 0);
                    promptTypistBlack.in(TITLE_MENU_PROMPT_TYPE_SPEED, 0);
                }
                break;

            case "prompt":
                if (_AnyInputPressed()) {
                    state      = "transition";
                    stateTimer = 0;
                }
                break;

            case "transition":
                var _dockT = clamp(stateTimer / TITLE_MENU_DOCK_DURATION, 0, 1);
                var _dockE = _EaseInOutQuad(_dockT);
                titleX = lerp(titleCenterX, titleDockedX, _dockE);
                titleY = lerp(titleCenterY, titleDockedY, _dockE);

                var _promptT = clamp(stateTimer / TITLE_MENU_PROMPT_EXIT_DURATION, 0, 1);
                promptY = lerp(promptRestY, promptExitY, _EaseInQuad(_promptT));

                for (var i = 0; i < array_length(buttons); i++) {
                    var _b     = buttons[i];
                    var _delay = i * TITLE_MENU_BUTTON_STAGGER;
                    var _bt    = clamp((stateTimer - _delay) / TITLE_MENU_BUTTON_SLIDE_DURATION, 0, 1);
                    _b.x = lerp(_b.startX, _b.restX, _EaseOutQuad(_bt));
                }

                // Social row staggers right-to-left (reverse of the option
                // buttons and the row's own layout order) -- see .md.
                for (var i = 0; i < array_length(socialButtons); i++) {
                    var _s     = socialButtons[i];
                    var _delay = (array_length(socialButtons) - 1 - i) * TITLE_MENU_BUTTON_STAGGER;
                    var _since = stateTimer - _delay;
                    var _st    = clamp(_since / TITLE_MENU_BUTTON_SLIDE_DURATION, 0, 1);

                    _s.y = lerp(_s.startY, _s.restY, _EaseOutBack(_st));

                    if (_since < TITLE_MENU_BUTTON_SLIDE_DURATION) {
                        var _entrySquash = (1 - _st) * TITLE_MENU_SOCIAL_ENTRY_SQUASH_AMOUNT;
                        _s.yscale = 1 - _entrySquash;
                        _s.xscale = 1 + _entrySquash;
                    } else {
                        var _landT = clamp((_since - TITLE_MENU_BUTTON_SLIDE_DURATION) / TITLE_MENU_SOCIAL_SQUASH_DURATION, 0, 1);
                        var _landSquash = sin(_landT * pi) * TITLE_MENU_SOCIAL_SQUASH_AMOUNT;
                        _s.xscale = 1 + _landSquash;
                        _s.yscale = 1 - _landSquash;
                    }
                }

                if (stateTimer >= TITLE_MENU_TRANSITION_DURATION) {
                    titleX = titleDockedX;
                    titleY = titleDockedY;
                    for (var i = 0; i < array_length(buttons); i++) {
                        buttons[i].x = buttons[i].restX;
                    }
                    for (var i = 0; i < array_length(socialButtons); i++) {
                        socialButtons[i].y      = socialButtons[i].restY;
                        socialButtons[i].xscale = 1;
                        socialButtons[i].yscale = 1;
                    }
                    state      = "menu";
                    stateTimer = 0;
                }
                break;

            case "menu":
                _UpdateSocialButtons(_dt);
                _UpdateMenu();
                break;
        }
    }

    /// @function _UpdateMenu()
    /// @description Button hover/click + exit confirm, only while state == "menu".
    static _UpdateMenu = function() {
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        if (exitConfirmActive) {
            exitConfirmHoveredIndex = DropDownMenuHitTest(exitConfirmX, exitConfirmY, array_length(exitConfirmOptions), _mx, _my);

            if (keyboard_check_pressed(vk_escape)) {
                exitConfirmActive = false;
                return;
            }

            if (mouse_check_button_pressed(mb_left)) {
                if (exitConfirmHoveredIndex == 0) {
                    game_end();
                } else {
                    exitConfirmActive = false;
                }
            }
            return;
        }

        hoveredButtonIndex = -1;
        for (var i = 0; i < array_length(buttons); i++) {
            var _b    = buttons[i];
            var _rect = _ButtonRect(_b);
            var _hovered = (_mx >= _rect.x1 && _mx <= _rect.x2 && _my >= _rect.y1 && _my <= _rect.y2);

            if (_hovered) hoveredButtonIndex = i;

            var _targetOffset = _hovered ? (TITLE_MENU_BUTTON_HOVER_SHIFT * TITLE_MENU_SCALE) : 0;
            _b.offset += (_targetOffset - _b.offset) * TITLE_MENU_HOVER_LERP;
            _b.x = _b.restX - _b.offset;

            if (_hovered && mouse_check_button_pressed(mb_left)) {
                _HandleButtonAction(_b.action);
                break;
            }
        }

        for (var i = 0; i < array_length(socialButtons); i++) {
            var _s    = socialButtons[i];
            var _rect = _SocialButtonRect(_s);
            var _hoveredSocial = (_mx >= _rect.x1 && _mx <= _rect.x2 && _my >= _rect.y1 && _my <= _rect.y2);

            if (_hoveredSocial && !_s.hovered) {
                _s.squashTimer = TITLE_MENU_SOCIAL_SQUASH_DURATION;
            }
            _s.hovered = _hoveredSocial;

            if (_hoveredSocial && mouse_check_button_pressed(mb_left)) {
                _HandleSocialClick(_s.platform);
                break;
            }
        }
    }

    /// @function DrawPrompt()
    /// @description Draws the "Press Any Key" wave/typewriter text with a manual outline. See .md.
    static DrawPrompt = function() {
        var _r = TITLE_MENU_PROMPT_OUTLINE_PX;
        static _offsets = [
            [-1,-1], [0,-1], [1,-1],
            [-1, 0],         [1, 0],
            [-1, 1], [0, 1], [1, 1]
        ];

        for (var i = 0; i < array_length(_offsets); i++) {
            promptTextBlack.draw(promptX + _offsets[i][0] * _r, promptY + _offsets[i][1] * _r, promptTypistBlack);
        }
        promptTextWhite.draw(promptX, promptY, promptTypistWhite);
    }

    /// @function DrawSocialButtons()
    /// @description Draws all six social icons at their current animated position/frame.
    static DrawSocialButtons = function() {
        for (var i = 0; i < array_length(socialButtons); i++) {
            var _s = socialButtons[i];
            draw_sprite_ext(_s.sprite, _s.frameIndex, _s.x, _s.y, TITLE_MENU_SCALE * _s.xscale, TITLE_MENU_SCALE * _s.yscale, 0, c_white, 1);
        }
    }

    /// @function DrawVersionFooter()
    /// @description Bottom-left version/copyright text.
    static DrawVersionFooter = function() {
        var _guiH = display_get_gui_height();
        var _bgAlpha = (state == "fadeIn") ? clamp(stateTimer / TITLE_MENU_FADE_IN_DURATION, 0, 1) : 1;

        draw_set_font(fntResource);
        draw_set_halign(fa_left);
        draw_set_valign(fa_bottom);
        draw_set_color(HOVER_CARD_TEXT_COLOR);
        draw_set_alpha(_bgAlpha);

        var _x         = TITLE_MENU_PADDING * TITLE_MENU_SCALE;
        var _companyY  = _guiH - (TITLE_MENU_PADDING * TITLE_MENU_SCALE);
        var _versionY  = _companyY - (TITLE_MENU_FOOTER_LINE_GAP * TITLE_MENU_SCALE);

        draw_text(_x, _companyY, "iCon Studios TX LLC " + chr(169) + "2026-2027"); // chr(169) = copyright symbol
        draw_text(_x, _versionY, "v" + GM_version);

        draw_set_alpha(1);
        draw_set_color(c_white);
        draw_set_font(-1);
    }

    /// @function DrawExitConfirm()
    /// @description Yes/No confirm panel, built on the shared DropDownMenuScripts.gml helpers.
    static DrawExitConfirm = function() {
        DrawDropDownMenuTitle(exitConfirmX, exitConfirmY, "Exit Game?");

        var _rowY = exitConfirmY + DropDownMenuTitleHeight();
        for (var i = 0; i < array_length(exitConfirmOptions); i++) {
            var _isBottom = (i == array_length(exitConfirmOptions) - 1);
            var _rowH     = DropDownMenuRowHeight(_isBottom);

            DrawDropDownMenuRowBackground(exitConfirmX, _rowY, _isBottom, (i == exitConfirmHoveredIndex));

            draw_set_color(HOVER_CARD_TEXT_COLOR);
            draw_set_halign(fa_left);
            draw_set_valign(fa_middle);
            draw_text(DropDownMenuRowContentX(exitConfirmX), _rowY + (_rowH / 2), exitConfirmOptions[i]);

            _rowY += _rowH;
        }
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event.
    static Draw = function() {
        draw_clear(c_black);

        var _bgAlpha = (state == "fadeIn") ? clamp(stateTimer / TITLE_MENU_FADE_IN_DURATION, 0, 1) : 1;
        draw_sprite_ext(sTitleBackground, 0, 0, 0, TITLE_MENU_SCALE, TITLE_MENU_SCALE, 0, c_white, _bgAlpha);

        DrawVersionFooter();

        if (state != "fadeIn") {
            draw_sprite_ext(sTitle, 0, titleX, titleY, TITLE_MENU_SCALE, TITLE_MENU_SCALE, 0, c_white, 1);
        }

        if (state == "prompt" || state == "transition") {
            DrawPrompt();
        }

        if (state == "transition" || state == "menu") {
            shader_set(shFlagWave);
            shader_set_uniform_f(global.__titleFlagWaveUniformTime, current_time / 1000);
            for (var i = 0; i < array_length(buttons); i++) {
                var _b         = buttons[i];
                var _intensity = _b.offset / (TITLE_MENU_BUTTON_HOVER_SHIFT * TITLE_MENU_SCALE);
                var _rect      = sprite_get_uvs(_b.sprite, 0); // [0]=left,[1]=top,[2]=right,[3]=bottom
                shader_set_uniform_f(global.__titleFlagWaveUniformIntensity, _intensity);
                shader_set_uniform_f(global.__titleFlagWaveUniformRect, _rect[0], _rect[1], _rect[2], _rect[3]);
                draw_sprite_ext(_b.sprite, 0, _b.x, _b.y, TITLE_MENU_SCALE, TITLE_MENU_SCALE, 0, c_white, 1);
            }
            shader_reset();
            DrawSocialButtons();
        }

        if (state == "menu" && exitConfirmActive) {
            DrawExitConfirm();
        }

        settingsOverlay.Draw();
        creditsOverlay.Draw();
    }
}
