// -----------------------------------------------------------
// TitleMenuScripts -- the title/main menu screen. 2026-07-13 request.
// Owned by oTitleMenu (rmTitleMenu): Create_0 does `titleMenu = new TitleMenu();`,
// Step_0 does `titleMenu.Update();`, Draw_64 does `titleMenu.Draw();` -- same
// "plain struct + thin object wrapper" split every other controller in this
// project uses (PauseMenu, FateEngineOverlay, BlueprintController, ...).
//
// Sequence, per the request:
//   1. "fadeIn"    -- screen fades in from black (sTitleBackground alpha
//                     ramps 0->1 over a black draw_clear base).
//   2. "titleDrop" -- sTitle falls from off-screen-top to screen-center
//                     (both axes) using an easeOutBounce curve, so it
//                     visibly bounces once on landing.
//   3. "prompt"    -- "Press Any Key" typewriters in below the title
//                     (Scribble typist, [wave] tag), white text with a
//                     manually-drawn black outline (see DrawPrompt's own
//                     comment for why manual rather than Scribble's
//                     SDF .outline()). Waits here for any key/click/gamepad
//                     face button.
//   4. "transition"-- on input: prompt slides off the bottom of the screen,
//                     title eases from center to the docked top-right
//                     corner (TITLE_MENU_PADDING), and all four menu
//                     buttons slide in from off-screen-right to their rest
//                     position, staggered per row. All three run
//                     concurrently, not staged one-after-another.
//   5. "menu"      -- buttons are interactive: hover shifts a button left
//                     by TITLE_MENU_BUTTON_HOVER_SHIFT (smoothly, both
//                     ways), click fires that button's action. Exit opens
//                     a Yes/No confirm sub-panel (mirrors PauseMenu's
//                     RequestConfirm/CancelConfirm shape, built on the same
//                     shared DropDownMenuScripts.gml helpers -- not a
//                     literal shared struct instance, since PauseMenu's
//                     instance lives on oUnitControl in the gameplay room
//                     and doesn't exist here; this mirrors its pattern
//                     instead) before actually calling game_end().
//
// Sizing convention: sTitleBackground (960x540) / sTitle (320x180) / the
// four *Option button sprites are all authored at HALF the room's actual
// 1920x1080 resolution (960x540 exactly matches half of 1920x1080) --
// same "native art, doubled at draw time" convention already established
// by DROPDOWN_MENU_SCALE (DropDownMenuScripts.gml) and FATE_DRUM_ITEM_SCALE
// (FateEngineDrumScripts.gml). TITLE_MENU_SCALE (2) is applied to every
// sprite draw call in this file. Text is drawn at native/unscaled size,
// matching how every other piece of UI text in this project is already
// handled (e.g. DrawDropDownMenuTitle draws plain draw_text with no extra
// scale multiplier even though the panel sprite around it IS scaled).
//
// All four button sprites share origin "middle-right" (confirmed via their
// .yy -- xorigin == width, yorigin == height/2) and sTitle shares origin
// "top-right" (xorigin == width, yorigin == 0) -- deliberately, it seems,
// since that's exactly the corner each one needs to anchor to once docked/
// resting (title's top-right corner in the screen's top-right corner;
// each button's right edge at its resting right-padding). Positioning
// below relies on that rather than re-deriving offsets by hand.
// -----------------------------------------------------------

#macro TITLE_MENU_SCALE                2    // native-res-doubled convention, see file header
#macro TITLE_MENU_PADDING              16   // native px -- title's corner padding once docked (request: "give it some padding, about 16px both vertically and horizontally"). Treated as a NATIVE value, scaled by TITLE_MENU_SCALE -- same native-vs-scaled interpretation DropDownMenuScripts.gml already established for its own 6px text buffer.
#macro TITLE_MENU_BUTTON_PADDING       32   // native px -- buttons' resting right-edge padding (request: "until they have about 32px padding on their right side")
#macro TITLE_MENU_BUTTON_HOVER_SHIFT   32   // native px -- how far a hovered button shifts left (request: "shift smoothly towards their left side by about 32px")
#macro TITLE_MENU_FADE_IN_DURATION     1.0  // seconds -- background fade from black
#macro TITLE_MENU_DROP_START_PAD       40   // native px of extra buffer above the screen the title starts from, so it visibly falls INTO frame
#macro TITLE_MENU_DROP_DURATION        0.9  // seconds -- title fall + bounce, landing at screen center
#macro TITLE_MENU_PROMPT_GAP           24   // native px between title's bottom edge and the "Press Any Key" prompt
#macro TITLE_MENU_PROMPT_TYPE_SPEED    1    // matches oAlphaDisclaimer's scribble_typist().in(1, 0) for a consistent typewriter feel across both screens
#macro TITLE_MENU_PROMPT_OUTLINE_PX    2    // screen px -- manual outline offset radius (text isn't scaled, see file header, so this is already a screen-space value)
#macro TITLE_MENU_PROMPT_EXIT_DURATION 0.35 // seconds -- quick slide off the bottom on input
#macro TITLE_MENU_DOCK_DURATION        0.6  // seconds -- title's move from center to the top-right corner
#macro TITLE_MENU_BUTTON_TOP_GAP       24   // native px between docked title's bottom edge and the first button row
#macro TITLE_MENU_BUTTON_ROW_GAP       12   // native px vertical gap between stacked button rows
#macro TITLE_MENU_BUTTON_SLIDE_DURATION 0.45 // seconds -- each button's own slide-in
#macro TITLE_MENU_BUTTON_STAGGER       0.08 // seconds -- added delay per button index so they cascade in rather than arriving simultaneously. Judgment call -- not specified by the request, flag if a simultaneous arrival reads better. Also reused for the social row below (same cascade feel, one fewer macro to keep in sync).
#macro TITLE_MENU_TRANSITION_DURATION  1.05 // seconds -- covers the longest of the concurrent transition animations (docking 0.6s, prompt exit 0.35s, last OPTION button's stagger+slide 3*0.08 + 0.45 = 0.69s, last SOCIAL icon's stagger+slide+landing-squash -- now right-to-left so the LAST to arrive is index 0, delay 5*0.08 + slide 0.45 + landing squash 0.18 = 1.03s) before the menu becomes interactive
#macro TITLE_MENU_HOVER_LERP           0.25 // per-step exponential-smoothing factor for the hover shift -- flat, no global.matchSpeed scaling (this screen exists entirely outside any match/timescale context)

// ---- social media row (2026-07-13 follow-up request) ----
#macro TITLE_MENU_SOCIAL_PADDING_X     32   // native px -- row's right edge padding from the screen's right edge. Not specified numerically by the request ("aligned to the bottom right side") -- matched to TITLE_MENU_BUTTON_PADDING for visual consistency with the option buttons' own right padding, flagging as a judgment call.
#macro TITLE_MENU_SOCIAL_PADDING_Y     32   // native px -- row's bottom edge padding, same reasoning as above
#macro TITLE_MENU_SOCIAL_GAP           12   // native px between adjacent icons
#macro TITLE_MENU_SOCIAL_BLINK_MIN     5    // seconds -- request: "periodically... every 5-6 seconds"
#macro TITLE_MENU_SOCIAL_BLINK_MAX     6    // seconds
#macro TITLE_MENU_SOCIAL_BLINK_FRAME_DURATION 0.08 // seconds per blink frame (frames 1-3) -- fast eye-blink feel, not specified, judgment call
#macro TITLE_MENU_SOCIAL_SQUASH_DURATION 0.18 // seconds -- one-shot squash-and-return pulse on hover-ENTER only ("just upon entering the bounds"), roughly 11 frames at 60fps for "a few frames" per the request. Also reused as the entrance's landing-squash duration (2026-07-14 request) -- same pulse shape, just triggered by "finished sliding in" instead of "mouse entered bounds".
#macro TITLE_MENU_SOCIAL_SQUASH_AMOUNT   0.35 // xscale peaks at 1+this, yscale dips to 1-this, at the pulse's midpoint -- not specified numerically, judgment call
#macro TITLE_MENU_SOCIAL_ENTRY_SQUASH_AMOUNT 0.3 // vertical squash while cascading in (2026-07-14 request: "squashing vertically until they settle") -- strongest (yscale 1-this) right as each icon starts sliding, fades to 0/normal exactly as it reaches its overshoot-settle landing. Not specified numerically, judgment call.

// ---- version/copyright footer (2026-07-13 follow-up request) ----
#macro TITLE_MENU_FOOTER_LINE_GAP      22   // native px between the two footer lines' baselines -- not specified, sized to comfortably clear fntResource's own line height

/// @function TitleMenuButton(_sprite, _action)
/// @description One menu button's static + animated state. _restX/_restY
///        are its final resting position (right-edge padded per
///        TITLE_MENU_BUTTON_PADDING, row-stacked below the docked title);
///        _startX is fully off-screen-right, sized off this button's own
///        width so narrower buttons (e.g. Exit) don't pop in early relative
///        to wider ones (e.g. Play).
/// @param {Asset.GMSprite} _sprite
/// @param {String} _action "play" | "settings" | "credits" | "exit"
function TitleMenuButton(_sprite, _action) constructor {
    sprite = _sprite;
    action = _action;
    width  = sprite_get_width(_sprite);
    height = sprite_get_height(_sprite);

    restX  = 0;
    restY  = 0;
    startX = 0;

    x      = 0;
    y      = 0;
    offset = 0; // current hover-shift offset, 0..TITLE_MENU_BUTTON_HOVER_SHIFT*TITLE_MENU_SCALE
}

/// @function TitleMenuSocialButton(_sprite, _platform, _animated)
/// @description One social-media icon's static + animated state. Origin is
///        middle-center for all six icons (confirmed via their .yy), unlike
///        TitleMenuButton's middle-right -- so positioning/hit-testing here
///        works from a centered rect instead. Only X is ever set once (row
///        layout, left-to-right); Y is what slides in from below the
///        screen. _animated is true only for Discord (sDiscordIcon, 4
///        frames: 0 = idle, 1-3 = blink) -- see _UpdateSocialButtons.
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

    // Blink state -- only ever advances if `animated` is true (Discord).
    frameIndex      = 0;
    blinking        = false;
    blinkFrameTimer = 0;
    blinkTimer      = _animated ? random_range(TITLE_MENU_SOCIAL_BLINK_MIN, TITLE_MENU_SOCIAL_BLINK_MAX) : 0;

    // Hover squash -- one-shot pulse fired only on hover-ENTER (see
    // _UpdateMenu's edge-detect against `hovered`), not held for the
    // duration of the hover. squashTimer counts down from
    // TITLE_MENU_SOCIAL_SQUASH_DURATION to 0; xscale/yscale are derived
    // from it each tick in _UpdateSocialButtons and consumed by
    // DrawSocialButtons.
    hovered     = false;
    squashTimer = 0;
    xscale      = 1;
    yscale      = 1;
}

/// @function TitleMenu()
/// @description The title screen. See file header for the full state
///        sequence. Not a GM instance -- a plain struct owned by oTitleMenu,
///        same pattern as PauseMenu/FateEngineOverlay/BlueprintController.
function TitleMenu() constructor {
    state      = "fadeIn";
    stateTimer = 0;

    // ---- title ----
    var _guiW = display_get_gui_width();
    var _guiH = display_get_gui_height();

    titleW = sprite_get_width(sTitle)  * TITLE_MENU_SCALE;
    titleH = sprite_get_height(sTitle) * TITLE_MENU_SCALE;

    titleCenterX = (_guiW / 2) + (titleW / 2); // origin is top-right, so the box's LEFT edge sits at guiCenterX when X = guiCenterX + halfWidth
    titleCenterY = (_guiH / 2) - (titleH / 2);
    titleDropStartY = -titleH - (TITLE_MENU_DROP_START_PAD * TITLE_MENU_SCALE);

    titleDockedX = _guiW - (TITLE_MENU_PADDING * TITLE_MENU_SCALE);
    titleDockedY = TITLE_MENU_PADDING * TITLE_MENU_SCALE;

    titleX = titleCenterX;
    titleY = titleDropStartY;

    // ---- prompt ("Press Any Key") ----
    promptX      = _guiW / 2;
    promptRestY  = titleCenterY + titleH + (TITLE_MENU_PROMPT_GAP * TITLE_MENU_SCALE);
    promptExitY  = _guiH + 64; // safely below the bottom edge
    promptY      = promptRestY;

    promptTextWhite = scribble("[fntResource][c_white][wave]Press Any Key[/wave]").align(fa_center, fa_middle);
    promptTextBlack = scribble("[fntResource][c_black][wave]Press Any Key[/wave]").align(fa_center, fa_middle);

    // Two typists, not one -- a scribble_typist resets its reveal progress
    // (__associate() -> reset()) any time the text element it just ticked
    // differs from the one before it. Sharing a single typist between the
    // black-outline element and the white element meant every white draw
    // call reset the reveal right after the black copies had ticked it
    // forward, so only the first character or so ever showed. Driving both
    // typists with identical .in() calls at the same moment keeps them in
    // lockstep since each only ticks once per frame regardless.
    promptTypistWhite = scribble_typist();
    promptTypistBlack = scribble_typist();

    // ---- menu buttons (Play / Settings / Credits / Exit, request order) ----
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

    // ---- social media row (2026-07-13 follow-up request) ----
    // Order given in the request -- "makes little difference" per the
    // request itself, so used as-given rather than re-sorted: Steam, X,
    // Itch.io, Discord, TikTok, YouTube. Only Discord is animated
    // (sDiscordIcon's 4 frames -- see TitleMenuSocialButton).
    socialButtons = [
        new TitleMenuSocialButton(sSteamIcon,   "steam",   false),
        new TitleMenuSocialButton(sXIcon,       "x",       false),
        new TitleMenuSocialButton(sItchIOIcon,  "itch",    false),
        new TitleMenuSocialButton(sDiscordIcon, "discord", true),
        new TitleMenuSocialButton(sTikTokIcon,  "tiktok",  false),
        new TitleMenuSocialButton(sYouTubeIcon, "youtube", false),
    ];

    // Right-aligned row: total width first, then walk left-to-right from
    // the row's left edge (rowRight - totalWidth) so the LAST icon's right
    // edge lands exactly at the padded right edge -- "aligned to the
    // bottom right side of the screen, arranged from left to right".
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
        _s.startY = _guiH + _sh; // fully off-screen below
        _s.x      = _s.restX;
        _s.y      = _s.startY;

        _socialCursorX += _sw + (TITLE_MENU_SOCIAL_GAP * TITLE_MENU_SCALE);
    }

    // ---- exit confirm sub-panel (mirrors PauseMenu's Yes/No shape) ----
    exitConfirmActive        = false;
    exitConfirmHoveredIndex  = -1;
    exitConfirmOptions       = ["Yes", "No"];
    exitConfirmX             = 0;
    exitConfirmY             = 0;

    // -----------------------------------------------------------
    // Easing helpers -- standard public-domain formulas (easings.net).
    // -----------------------------------------------------------

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
    /// @description Standard "back" ease-out -- overshoots past 1.0 partway
    ///        through, then settles back to exactly 1.0 at _t=1. Used for
    ///        the social icons' 2026-07-14 entrance request ("overshooting
    ///        their final position, then landing").
    /// @param {Real} _t 0..1
    /// @returns {Real}
    static _EaseOutBack = function(_t) {
        var _c1 = 1.70158;
        var _c3 = _c1 + 1;
        var _x  = _t - 1;
        return 1 + _c3 * _x * _x * _x + _c1 * _x * _x;
    }

    /// @function _AnyInputPressed()
    /// @description Same keyboard/gamepad combo oAlphaDisclaimer's "press
    ///        any key to continue" already uses, plus a left mouse click
    ///        (addition beyond the literal request -- flagging, since a
    ///        title screen conventionally also accepts a click).
    /// @returns {Bool}
    static _AnyInputPressed = function() {
        return keyboard_check_pressed(vk_anykey)
            || gamepad_button_check_pressed(0, gp_face1)
            || mouse_check_button_pressed(mb_left);
    }

    /// @function _ButtonRect(_b)
    /// @param {Struct.TitleMenuButton} _b
    /// @returns {Struct} { x1, y1, x2, y2 }
    /// @description Hover hit-test rect for a menu option. The right edge
    ///        is pinned to the screen's right edge rather than the
    ///        sprite's own right edge (origin is middle-right, so that
    ///        would normally be _b.x) -- this keeps the hoverable area
    ///        covering the button's screen-edge padding gap and, more
    ///        importantly, the space the button vacates when it shifts
    ///        left on hover (TITLE_MENU_BUTTON_HOVER_SHIFT), so the mouse
    ///        doesn't fall outside the hit box and flicker the hover state
    ///        as soon as the button starts moving away from the cursor.
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
                room_goto(rmTestGameplay);
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
    /// @description Origin is middle-center for these (unlike
    ///        _ButtonRect's middle-right), so the rect is centered on x/y.
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
    /// @description 2026-07-13 request: "leave their weblink handles when
    ///        clicked commented out so I can input the correct URLs" --
    ///        click detection/dispatch is fully live below, but every
    ///        actual url_open() call is deliberately commented out with a
    ///        placeholder link. Uncomment + fill in the real URL per
    ///        platform when ready; nothing else needs to change.
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
    /// @description Internal -- drives Discord's idle/blink cycle plus every
    ///        icon's hover-squash pulse. Every non-animated icon skips the
    ///        blink block and stays on frameIndex 0 (their sprites only have
    ///        one frame anyway), but the squash block below runs for ALL six
    ///        icons regardless of `animated`. Runs only while state == "menu"
    ///        (started fresh each time the row finishes sliding in, so a
    ///        blink -- or a squash left over from a pre-slide hover -- never
    ///        triggers mid-slide).
    /// @param {Real} _dt
    static _UpdateSocialButtons = function(_dt) {
        for (var i = 0; i < array_length(socialButtons); i++) {
            var _b = socialButtons[i];

            // Hover squash -- one-shot pulse, ticks down regardless of
            // `animated`. squashTimer is only ever set (in _UpdateMenu, on
            // hover-ENTER) while state == "menu", so this is a no-op the
            // rest of the time.
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
                    _b.frameIndex      = 1; // frame 0 is idle -- blink starts on frame 1
                    _b.blinkFrameTimer = 0;
                }
            }
        }
    }

    /// @function _OpenSettings()
    /// @description STUB -- per explicit request, treated the same as
    ///        _OpenCredits() below for this pass (no shared settings
    ///        overlay exists yet). Intentionally empty; clicking "Settings"
    ///        currently does nothing observable.
    static _OpenSettings = function() {
        // Intentionally empty -- see file header / PATCH_NOTES.md.
    }

    /// @function _OpenCredits()
    /// @description STUB -- per explicit request ("credits will bring up
    ///        the credits (we will add this shortly)"). Intentionally
    ///        empty; clicking "Credits" currently does nothing observable.
    static _OpenCredits = function() {
        // Intentionally empty -- see file header / PATCH_NOTES.md.
    }

    /// @function Update()
    /// @description Call once per Step event.
    static Update = function() {
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

                // Social row -- "shifting from under the bottom of the
                // screen when the menu options appear", same trigger point
                // (this "transition" state) as the option buttons above.
                // 2026-07-14 request: stagger RIGHT TO LEFT (reverse of the
                // option buttons' left-to-right, and reverse of the row's
                // own left-to-right layout order -- so index 5/youtube,
                // the row's rightmost icon, starts first), overshoot the
                // landing (_EaseOutBack instead of _EaseOutQuad), squash
                // vertically while cascading in (fades out exactly as each
                // icon reaches its landing), then a one-shot horizontal
                // squash pulse right at landing. Entirely a function of
                // stateTimer -- no separate per-icon timer/flag needed,
                // consistent with how _dockT/_promptT above are computed.
                for (var i = 0; i < array_length(socialButtons); i++) {
                    var _s     = socialButtons[i];
                    var _delay = (array_length(socialButtons) - 1 - i) * TITLE_MENU_BUTTON_STAGGER;
                    var _since = stateTimer - _delay;
                    var _st    = clamp(_since / TITLE_MENU_BUTTON_SLIDE_DURATION, 0, 1);

                    _s.y = lerp(_s.startY, _s.restY, _EaseOutBack(_st));

                    if (_since < TITLE_MENU_BUTTON_SLIDE_DURATION) {
                        // Still cascading in -- vertical squash fades to 0
                        // as _st approaches 1 (i.e. right as it lands).
                        var _entrySquash = (1 - _st) * TITLE_MENU_SOCIAL_ENTRY_SQUASH_AMOUNT;
                        _s.yscale = 1 - _entrySquash;
                        _s.xscale = 1 + _entrySquash;
                    } else {
                        // Landed -- one-shot horizontal squash pulse, same
                        // sin(t*pi) shape as the hover-squash pulse, timed
                        // off "time since this icon's slide finished" so it
                        // needs no separate armed/edge-detected state.
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
    /// @description Internal -- button hover/click + exit confirm, only
    ///        while state == "menu".
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
                if (exitConfirmHoveredIndex == 0) { // "Yes"
                    game_end();
                } else {
                    // "No", or a click anywhere else -- cancel back to the
                    // menu, same "miss-click treated as No" rule PauseMenu's
                    // confirm sub-menu already uses.
                    exitConfirmActive = false;
                }
            }
            return; // don't fall through to button hover/click while confirming
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
                break; // one click can only ever hit one button
            }
        }

        // Social row -- no hover-shift (the request only described the
        // hover-shift-left behavior for the four option buttons above, not
        // these); instead a one-shot horizontal squash pulse fires just on
        // hover-ENTER (2026-07-14 request: "squash horizontally... for a
        // few frames when hovered over (just upon entering the bounds)").
        // Edge-detected against `hovered` so it fires once per entry, not
        // continuously while the cursor sits inside the bounds; the actual
        // squashTimer countdown + xscale/yscale math lives in
        // _UpdateSocialButtons so it keeps ticking via _dt rather than being
        // tied to this click-handling pass.
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
    /// @description Internal -- draws the "Press Any Key" wave/typewriter
    ///        text, white with a manually-offset black outline. Scribble
    ///        does have a real SDF outline (.outline()/.sdf_outline(),
    ///        __scribble_class_element.gml) but its own comments tie it to
    ///        SDF-imported fonts ("useful for fixing problems with SDF
    ///        glyph outline") and fntResource is a plain bitmap font with
    ///        no SDF configuration -- rather than risk an outline that
    ///        silently doesn't render (or renders wrong) on a non-SDF font,
    ///        this draws the black copy 8 times at a small pixel offset
    ///        behind the white copy instead, the standard font-agnostic
    ///        outline trick. The black and white copies are two separate
    ///        scribble text elements (they carry different embedded
    ///        [c_black]/[c_white] tags) and each needs its OWN
    ///        scribble_typist (promptTypistBlack / promptTypistWhite) --
    ///        a typist's __associate() step calls reset() whenever the
    ///        element it just ticked differs from the one before it, so a
    ///        single shared typist alternating between the black and white
    ///        elements every frame wiped its own progress back to 0 right
    ///        after advancing, which only ever revealed the first
    ///        character or so (the "just flashes the P" bug). Both typists
    ///        are started together in Update() with identical .in() calls
    ///        and only tick once per frame regardless of draw-call count,
    ///        so they stay in lockstep.
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
    /// @description Internal -- draws all six social icons at their
    ///        current animated position/frame. Discord's frameIndex is
    ///        whatever _UpdateSocialButtons last set (0 idle, 1-3 blink);
    ///        every other icon stays 0 (their sprites are single-frame
    ///        anyway, so this is harmless even before "menu" state starts
    ///        driving it). xscale/yscale fold in the hover-squash pulse
    ///        (_UpdateSocialButtons) on top of the base TITLE_MENU_SCALE --
    ///        both default to 1 outside a pulse, so this is a no-op then.
    static DrawSocialButtons = function() {
        for (var i = 0; i < array_length(socialButtons); i++) {
            var _s = socialButtons[i];
            draw_sprite_ext(_s.sprite, _s.frameIndex, _s.x, _s.y, TITLE_MENU_SCALE * _s.xscale, TITLE_MENU_SCALE * _s.yscale, 0, c_white, 1);
        }
    }

    /// @function DrawVersionFooter()
    /// @description Internal -- bottom-left version/copyright text, request
    ///        verbatim: version number on top (GM_version -- "the Windows
    ///        Version Number function", the built-in constant that holds
    ///        whatever's set in Game Options > Windows > General > Version,
    ///        i.e. option_windows_version, currently 0.0.4.10), "iCon
    ///        Studios TX LLC" (matches option_windows_company_info verbatim)
    ///        + a copyright symbol + "2026-2027" below it. Uses chr(169) for
    ///        the copyright symbol rather than a
    ///        \uXXXX-style escape (GML string literals don't support those)
    ///        or pasting the raw © glyph directly into the source (avoids
    ///        any risk of the file's own encoding mangling a literal
    ///        special character). Same
    ///        draw_set_font(fntResource) / draw_set_font(-1) reset
    ///        convention ResourceUIScripts.gml/HUDWidgetScripts.gml already
    ///        use. Alpha follows the same fade-in as the background/title
    ///        rather than popping in abruptly -- not specified either way
    ///        by the request.
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

        draw_text(_x, _companyY, "iCon Studios TX LLC " + chr(169) + "2026-2027");
        draw_text(_x, _versionY, "v" + GM_version);

        draw_set_alpha(1);
        draw_set_color(c_white);
        draw_set_font(-1);
    }

    /// @function DrawExitConfirm()
    /// @description Internal -- Yes/No confirm panel, built on the same
    ///        shared DropDownMenuScripts.gml helpers PauseMenu's confirm
    ///        sub-menu uses (title/row background/hit-test/sizing).
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

        // Background -- fades in from black (request: "have the background
        // fade from black").
        var _bgAlpha = (state == "fadeIn") ? clamp(stateTimer / TITLE_MENU_FADE_IN_DURATION, 0, 1) : 1;
        draw_sprite_ext(sTitleBackground, 0, 0, 0, TITLE_MENU_SCALE, TITLE_MENU_SCALE, 0, c_white, _bgAlpha);

        // Version/copyright footer -- always present, bottom-left, fades in
        // alongside the background.
        DrawVersionFooter();

        // Title -- always drawn once it exists past fadeIn (titleY starts
        // off-screen during "fadeIn" itself, so this is harmless before
        // titleDrop begins too).
        if (state != "fadeIn") {
            draw_sprite_ext(sTitle, 0, titleX, titleY, TITLE_MENU_SCALE, TITLE_MENU_SCALE, 0, c_white, 1);
        }

        if (state == "prompt" || state == "transition") {
            DrawPrompt();
        }

        if (state == "transition" || state == "menu") {
            for (var i = 0; i < array_length(buttons); i++) {
                var _b = buttons[i];
                draw_sprite_ext(_b.sprite, 0, _b.x, _b.y, TITLE_MENU_SCALE, TITLE_MENU_SCALE, 0, c_white, 1);
            }
            DrawSocialButtons();
        }

        if (state == "menu" && exitConfirmActive) {
            DrawExitConfirm();
        }
    }
}
