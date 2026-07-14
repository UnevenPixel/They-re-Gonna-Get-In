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
#macro TITLE_MENU_BUTTON_STAGGER       0.08 // seconds -- added delay per button index so they cascade in rather than arriving simultaneously. Judgment call -- not specified by the request, flag if a simultaneous arrival reads better.
#macro TITLE_MENU_TRANSITION_DURATION  0.9  // seconds -- covers the longest of the three concurrent transition animations (docking 0.6s, prompt exit 0.35s, last button's stagger+slide 3*0.08 + 0.45 = 0.69s) before the menu becomes interactive
#macro TITLE_MENU_HOVER_LERP           0.25 // per-step exponential-smoothing factor for the hover shift -- flat, no global.matchSpeed scaling (this screen exists entirely outside any match/timescale context)

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
    promptTypist    = scribble_typist();

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
    static _ButtonRect = function(_b) {
        var _w = _b.width  * TITLE_MENU_SCALE;
        var _h = _b.height * TITLE_MENU_SCALE;
        return {
            x1: _b.x - _w, y1: _b.y - (_h / 2),
            x2: _b.x,      y2: _b.y + (_h / 2)
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
                    promptTypist.in(TITLE_MENU_PROMPT_TYPE_SPEED, 0);
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

                if (stateTimer >= TITLE_MENU_TRANSITION_DURATION) {
                    titleX = titleDockedX;
                    titleY = titleDockedY;
                    for (var i = 0; i < array_length(buttons); i++) {
                        buttons[i].x = buttons[i].restX;
                    }
                    state      = "menu";
                    stateTimer = 0;
                }
                break;

            case "menu":
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
    ///        outline trick. Both copies share ONE scribble_typist
    ///        instance -- Scribble's typist advances off current_time (an
    ///        absolute, frame-constant timestamp), not a per-draw-call
    ///        counter, so calling .draw() 9 times in one frame with the
    ///        same typist reveals all 9 copies in perfect sync rather than
    ///        typing 9x too fast.
    static DrawPrompt = function() {
        var _r = TITLE_MENU_PROMPT_OUTLINE_PX;
        static _offsets = [
            [-1,-1], [0,-1], [1,-1],
            [-1, 0],         [1, 0],
            [-1, 1], [0, 1], [1, 1]
        ];

        for (var i = 0; i < array_length(_offsets); i++) {
            promptTextBlack.draw(promptX + _offsets[i][0] * _r, promptY + _offsets[i][1] * _r, promptTypist);
        }
        promptTextWhite.draw(promptX, promptY, promptTypist);
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
        }

        if (state == "menu" && exitConfirmActive) {
            DrawExitConfirm();
        }
    }
}
