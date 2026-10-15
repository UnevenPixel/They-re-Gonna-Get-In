// The dialogue box system -- DialogueOverlay struct (speaker name/text +
// response options, hover/click, drawing). See DialogueOverlayScripts.md.

#macro DIALOGUE_MAX_OPTIONS 4
#macro DIALOGUE_SCALE 2 // native (1x) values below are scaled by this at use sites -- see .md

#macro DIALOGUE_NAME_TEXT_X         30
#macro DIALOGUE_NAME_TEXT_Y         22
#macro DIALOGUE_SPEAKER_TEXT_X      30
#macro DIALOGUE_SPEAKER_TEXT_Y      43
#macro DIALOGUE_SPEAKER_TEXT_WRAP_W 312
#macro DIALOGUE_OPTION_START_X       15
#macro DIALOGUE_OPTION_START_Y       215
#macro DIALOGUE_OPTION_TEXT_OFFSET_X 6
#macro DIALOGUE_OPTION_TEXT_OFFSET_Y 12
#macro DIALOGUE_OPTION_ROW_GAP       2 // final on-screen px, added after scaling -- see .md

#macro DIALOGUE_SPEAKER_TEXT_COLOR make_color_hsv(color_get_hue(HOVER_CARD_TEXT_COLOR), color_get_saturation(HOVER_CARD_TEXT_COLOR), 50) // same hue/sat as option text, value fixed at 50 -- see .md

#macro DIALOGUE_FADE_STEPS 15 // ~1/4 sec fade in/out, same step-based lerp idiom PLOT_HOVER_FADE_STEPS uses -- see .md

#macro DIALOGUE_CENTER_SLOT_WIDTH 1280 // horizontal "slot" the box centers within -- 2/3 of the nominal 1920 GUI width, see .md

#macro DIALOGUE_PORTRAIT_SCALE    DIALOGUE_SCALE // matches the box's own scale

#macro DIALOGUE_TYPEWRITER_CHARS_PER_SECOND 40 // speakerText reveal rate -- judgment call, tune to taste, see .md

#macro DIALOGUE_TEXT_BLIP_OVERLAP_MS 20 // per-character speaker-sound throttle allowance -- judgment call, see .md
#macro DIALOGUE_TEXT_BLIP_PITCH_MIN 0.9 // per-character speaker-sound pitch variation range -- judgment call, see .md
#macro DIALOGUE_TEXT_BLIP_PITCH_MAX 1.1
#macro DIALOGUE_TEXT_BLIP_GAIN_SCALE 0.1 // 2026-08-30 follow-up -- flat attenuation on top of the Settings SFX slider, see .md
#macro DIALOGUE_TEXT_INPUT_MAX_LENGTH 20 // signing-line text field cap -- judgment call, see .md

// Per-instance counter so simultaneous overlays don't collide in Scribble's cache.
global.__dialogueOverlayNextId = 0;

/// @function DialogueOptionSprite(_index)
/// @description Option-row sprite for a given position (0 = 1st option, etc.).
/// @param {Real} _index 0..DIALOGUE_MAX_OPTIONS-1
/// @returns {Asset.GMSprite}
function DialogueOptionSprite(_index) {
    static _sprites = [sDialogueUIOptionA, sDialogueUIOptionB, sDialogueUIOptionC, sDialogueUIOptionD];
    return _sprites[clamp(_index, 0, DIALOGUE_MAX_OPTIONS - 1)];
}

/// @function DialogueBoxFrame(_optionCount)
/// @description sDialogueUIBack's frame index for a given number of response options.
/// @param {Real} _optionCount
/// @returns {Real}
function DialogueBoxFrame(_optionCount) {
    return clamp(_optionCount, 1, DIALOGUE_MAX_OPTIONS) - 1;
}

/// @function DialogueOverlay()
/// @description The dialogue box overlay. Plain struct -- owner calls
///        Update() once per Step and Draw() once per Draw GUI while isOpen.
function DialogueOverlay() constructor {
    isOpen  = false;
    closing = false; // true while fading out after Close() -- isOpen stays true until the fade finishes, see .md
    alpha   = 0;      // 0..1 current fade level, drives both the box and the background dim
    x       = 0; // GUI-space top-left corner of the box
    y       = 0;

    options            = [];
    hoveredOption       = -1;
    onSelect            = undefined;
    lastSelectedOption  = -1;
    lastSelectedText    = "";
    optionsItalic       = false;

    exitEnabled = true;
    hoveredExit = false;
    onExit      = undefined;

    name     = ""; // "" = no name line drawn
    portrait = undefined; // Asset.GMSprite, or undefined for none -- see .md

    speakerRevealChars = 0; // typewriter progress for speakerText only -- see .md

    speakerSound           = undefined; // Asset.GMSound blip, or undefined -- see .md
    speakerRawText         = "";        // pre-Scribble plain string, used only for the per-char blip's whitespace check -- see .md
    speakerSoundFinishTime = current_time; // earliest current_time() the next per-char blip may fire -- see .md

    textInputEnabled = false; // whether option row 0 is a "signing line" text field instead of a real option -- see .md
    textInputValue   = "";    // current typed value -- also how callers read the result after Close(), see .md
    __textInputLastRenderedValue = undefined; // internal cache, avoids rebuilding textInputText's Scribble element every frame -- see .md

    __id = global.__dialogueOverlayNextId++;

    nameText = scribble("", $"__dialogue{__id}Name__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_left, fa_top);

    speakerText = scribble("", $"__dialogue{__id}Speaker__")
        .starting_format(HOVER_CARD_BODY_FONT, DIALOGUE_SPEAKER_TEXT_COLOR)
        .align(fa_left, fa_top)
        .wrap(DIALOGUE_SPEAKER_TEXT_WRAP_W * DIALOGUE_SCALE);

    textInputText = scribble("", $"__dialogue{__id}TextInput__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_left, fa_middle);

    optionTexts = array_create(DIALOGUE_MAX_OPTIONS);
    for (var i = 0; i < DIALOGUE_MAX_OPTIONS; i++) {
        var _optionWrapW = (sprite_get_width(DialogueOptionSprite(i)) - (DIALOGUE_OPTION_TEXT_OFFSET_X * 2)) * DIALOGUE_SCALE;
        optionTexts[i] = scribble("", $"__dialogue{__id}Option{i}__")
            .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
            .align(fa_left, fa_middle)
            .wrap(_optionWrapW);
    }

    /// @function Open(_name, _speaker, _options, _onSelect, _exitEnabled, _onExit, _optionsItalic, _nameColor, _portrait, _speakerSound, _textInputEnabled, _textInputInitialValue)
    /// @description Shows the dialogue box, centered within a 1280px-wide
    ///        horizontal slot (2/3 of the nominal 1920 GUI width) that is
    ///        itself centered on screen. Safe to call while already open -- replaces the current
    ///        content in place, instantly (no fade). Fades in from scratch
    ///        when not already open. See .md.
    /// @param {String} _name Speaker name, drawn in _nameColor. "" for none.
    /// @param {String} _speaker Body text, wrapped to DIALOGUE_SPEAKER_TEXT_WRAP_W.
    /// @param {Array<String>} _options 1..DIALOGUE_MAX_OPTIONS response strings.
    /// @param {Function} [_onSelect] callback(_index, _text) on response click.
    /// @param {Bool} [_exitEnabled] Whether the exit button is shown/clickable.
    /// @param {Function} [_onExit] callback() on exit-button click.
    /// @param {Bool} [_optionsItalic] Renders every option in the italic font.
    /// @param {Color} [_nameColor] _name's color. Defaults to HOVER_CARD_TEXT_COLOR.
    /// @param {Asset.GMSprite} [_portrait] Character portrait, bottom-right anchored. Undefined for none.
    /// @param {Asset.GMSound} [_speakerSound] Per-character throttled blip sound. Undefined for none. See .md.
    /// @param {Bool} [_textInputEnabled] Shows a typable "signing line" in option row 0 instead of a real option -- see .md.
    /// @param {String} [_textInputInitialValue] Seeds textInputValue when _textInputEnabled is true (lets a caller re-open with a prior value preserved).
    /// @returns {Struct.DialogueOverlay} self
    static Open = function(_name, _speaker, _options, _onSelect = undefined, _exitEnabled = true, _onExit = undefined, _optionsItalic = false, _nameColor = HOVER_CARD_TEXT_COLOR, _portrait = undefined, _speakerSound = undefined, _textInputEnabled = false, _textInputInitialValue = "") {
        if (array_length(_options) > DIALOGUE_MAX_OPTIONS) {
            show_debug_message($"[DialogueOverlay.Open] WARNING: {array_length(_options)} options given, only the first {DIALOGUE_MAX_OPTIONS} will be shown");
        }

        var _count = min(array_length(_options), DIALOGUE_MAX_OPTIONS);
        options = array_create(_count);
        array_copy(options, 0, _options, 0, _count); // array_copy mutates dest in place, doesn't return one

        hoveredOption  = -1;
        onSelect       = _onSelect;
        exitEnabled    = _exitEnabled;
        hoveredExit    = false;
        onExit         = _onExit;
        name           = _name;
        optionsItalic  = _optionsItalic;
        portrait       = _portrait;

        nameText = scribble(_name, $"__dialogue{__id}Name__")
            .starting_format(HOVER_CARD_BODY_FONT, _nameColor)
            .align(fa_left, fa_top);

        speakerText = scribble(_speaker, $"__dialogue{__id}Speaker__")
            .starting_format(HOVER_CARD_BODY_FONT, DIALOGUE_SPEAKER_TEXT_COLOR)
            .align(fa_left, fa_top)
            .wrap(DIALOGUE_SPEAKER_TEXT_WRAP_W * DIALOGUE_SCALE);

        speakerRevealChars = 0; // every new line (cold-open or node switch) types out fresh -- see .md

        speakerSound           = _speakerSound;
        speakerRawText         = _speaker;
        speakerSoundFinishTime = current_time; // allow an immediate blip on this line's first revealed character -- see .md

        textInputEnabled = _textInputEnabled;
        if (textInputEnabled) {
            textInputValue  = _textInputInitialValue; // preserves a prior signing attempt across re-opens -- see .md
            keyboard_string = textInputValue;
        } else if (keyboard_string != "") {
            keyboard_string = ""; // don't let stray typing leak into a later text-input node -- see .md
        }
        __textInputLastRenderedValue = undefined; // forces textInputText to rebuild next Draw(), see .md

        var _optionFont = optionsItalic ? HOVER_CARD_FLAVOR_FONT : HOVER_CARD_BODY_FONT;
        for (var i = 0; i < array_length(options); i++) {
            var _optionWrapW = (sprite_get_width(DialogueOptionSprite(i)) - (DIALOGUE_OPTION_TEXT_OFFSET_X * 2)) * DIALOGUE_SCALE;
            optionTexts[i] = scribble(options[i], $"__dialogue{__id}Option{i}__")
                .starting_format(_optionFont, HOVER_CARD_TEXT_COLOR)
                .align(fa_left, fa_middle)
                .wrap(_optionWrapW);
        }

        var _slotX1 = (display_get_gui_width() - DIALOGUE_CENTER_SLOT_WIDTH) / 2;
        x = _slotX1 + (DIALOGUE_CENTER_SLOT_WIDTH - sprite_get_width(sDialogueUIBack) * DIALOGUE_SCALE) / 2;
        y = (display_get_gui_height() - sprite_get_height(sDialogueUIBack) * DIALOGUE_SCALE) / 2;

        alpha  = isOpen ? 1 : 0; // already open -> switch instantly, fully visible; first open -> start the fade-in
        closing = false;         // cancels any fade-out already in progress -- see Close()'s doc comment
        isOpen  = true;
        return self;
    }

    /// @function Close()
    /// @description Starts the fade-out. isOpen stays true and Update() keeps
    ///        running until the fade finishes, at which point isOpen actually
    ///        goes false. Safe to call from inside an onSelect that's about to
    ///        call Open() again -- Open() cancels the fade-out and treats it
    ///        as an instant content switch instead. See .md.
    /// @returns {Struct.DialogueOverlay} self
    static Close = function() {
        if (!isOpen || closing) return self;
        closing       = true;
        hoveredOption = -1;
        hoveredExit   = false;
        if (textInputEnabled) keyboard_string = ""; // don't leak stray typed text if exited mid-signing -- see .md
        return self;
    }

    /// @function SetExitEnabled(_enabled)
    /// @description Toggles the exit button's enabled state.
    /// @param {Bool} _enabled
    /// @returns {Struct.DialogueOverlay} self
    static SetExitEnabled = function(_enabled) {
        exitEnabled = _enabled;
        if (!exitEnabled) hoveredExit = false;
        return self;
    }

    /// @function _ExitRect()
    /// @description sDialogueUIExit's on-screen rect.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _ExitRect = function() {
        var _w  = sprite_get_width(sDialogueUIExit)  * DIALOGUE_SCALE;
        var _h  = sprite_get_height(sDialogueUIExit) * DIALOGUE_SCALE;
        var _x1 = x + sprite_get_width(sDialogueUIBack) * DIALOGUE_SCALE - _w;
        var _y1 = y - _h;
        return { x1: _x1, y1: _y1, x2: _x1 + _w, y2: _y1 + _h };
    }

    /// @function _HitTestExit(_mx, _my)
    /// @description Whether the given GUI-space point is over the exit button.
    /// @param {Real} _mx
    /// @param {Real} _my
    /// @returns {Bool}
    static _HitTestExit = function(_mx, _my) {
        if (!exitEnabled) return false;
        var _rect = _ExitRect();
        return (_mx >= _rect.x1 && _mx <= _rect.x2 && _my >= _rect.y1 && _my <= _rect.y2);
    }

    /// @function _PortraitDrawPosition()
    /// @description Draw-call (x, y) for `portrait`, bottom-left anchored with
    ///        no buffer in either direction -- derived from the sprite's own
    ///        origin so it works regardless of which corner that origin sits
    ///        in. Any on-screen buffer is expected to come from the portrait
    ///        sprite's own origin, not from this math. Slides in from the left
    ///        in lockstep with the fade (alpha) -- see .md.
    /// @returns {Struct} { x, y }
    static _PortraitDrawPosition = function() {
        var _left   = 0;
        var _bottom = display_get_gui_height();
        var _halfWidth   = (sprite_get_width(portrait) * DIALOGUE_PORTRAIT_SCALE) / 2;
        var _slideOffset = (1 - alpha) * _halfWidth; // alpha 0 -> half sprite width left of rest position; alpha 1 -> 0, see .md
        return {
            x: _left - _slideOffset + (sprite_get_xoffset(portrait) * DIALOGUE_PORTRAIT_SCALE),
            y: _bottom - ((sprite_get_height(portrait) - sprite_get_yoffset(portrait)) * DIALOGUE_PORTRAIT_SCALE)
        };
    }

    /// @function _HitTestOption(_mx, _my)
    /// @description Which option row (0-based) the given GUI-space point falls inside, or -1.
    /// @param {Real} _mx
    /// @param {Real} _my
    /// @returns {Real}
    static _HitTestOption = function(_mx, _my) {
        var _optionX = x + (DIALOGUE_OPTION_START_X * DIALOGUE_SCALE);
        var _optionW = sprite_get_width(DialogueOptionSprite(0)) * DIALOGUE_SCALE;
        if (_mx < _optionX || _mx > _optionX + _optionW) return -1;

        var _rowY = y + (DIALOGUE_OPTION_START_Y * DIALOGUE_SCALE);
        if (textInputEnabled) {
            _rowY += (sprite_get_height(DialogueOptionSprite(0)) * DIALOGUE_SCALE) + DIALOGUE_OPTION_ROW_GAP; // signing line occupies row 0's slot -- see .md
        }
        for (var i = 0; i < array_length(options); i++) {
            var _rowH = sprite_get_height(DialogueOptionSprite(i)) * DIALOGUE_SCALE;
            if (_my >= _rowY && _my <= _rowY + _rowH) return i;
            _rowY += _rowH + DIALOGUE_OPTION_ROW_GAP;
        }
        return -1;
    }

    /// @function Update()
    /// @description Call once per Step while this overlay might be open.
    ///        Drives the fade in/out; no hover/click handling while fading out. See .md.
    /// @returns {Struct.DialogueOverlay} self
    static Update = function() {
        if (!isOpen) return self;

        if (closing) {
            alpha -= 1 / DIALOGUE_FADE_STEPS;
            if (alpha <= 0) {
                alpha   = 0;
                closing = false;
                isOpen  = false;
            }
            return self;
        }

        if (alpha < 1) alpha = min(1, alpha + (1 / DIALOGUE_FADE_STEPS));

        var _prevRevealChars = speakerRevealChars;
        speakerRevealChars += DIALOGUE_TYPEWRITER_CHARS_PER_SECOND * (delta_time / 1000000); // microseconds -> seconds, same idiom as BuildingUpdateProduction -- see .md

        // Per-character speaker blip -- mirrors (doesn't reuse) the vendored
        // Scribble Typist's own sound_per_char() throttle formula
        // (current_time + 1000*audio_sound_length(...) - overlap), hand-rolled
        // here rather than migrating this typewriter off .reveal() and onto
        // the separate Typist class. See .md.
        if (speakerSound != undefined && floor(speakerRevealChars) > floor(_prevRevealChars) && current_time >= speakerSoundFinishTime) {
            var _charIndex = floor(speakerRevealChars); // 1-based index of the just-revealed character in speakerRawText
            var _char = (_charIndex >= 1 && _charIndex <= string_length(speakerRawText)) ? string_char_at(speakerRawText, _charIndex) : "";
            if (_char != "" && _char != " " && _char != "\n") {
                // gain ties into the Settings menu's SFX slider/mute (SettingsOverlayScripts.gml) --
                // same PerceptualGain() squared curve Music already uses; master gain doesn't need
                // factoring in separately, audio_master_gain() already applies to every sound
                // globally. Pitch is randomized per-blip so rapid repeats don't sound robotic --
                // both use audio_play_sound's extended (gain, offset, pitch) form, confirmed
                // supported by this project's GameMaker version via the vendored Scribble
                // library's own __scribble_play_sound() usage. See .md.
                var _gain  = (global.gameSettings.sfxMuted ? 0 : PerceptualGain(global.gameSettings.sfxVolume)) * DIALOGUE_TEXT_BLIP_GAIN_SCALE;
                var _pitch = random_range(DIALOGUE_TEXT_BLIP_PITCH_MIN, DIALOGUE_TEXT_BLIP_PITCH_MAX);
                audio_play_sound(speakerSound, 1, false, _gain, 0, _pitch);
                speakerSoundFinishTime = current_time + (1000 * audio_sound_length(speakerSound)) - DIALOGUE_TEXT_BLIP_OVERLAP_MS;
            }
        }

        if (textInputEnabled) {
            var _raw = keyboard_string;
            _raw = string_replace_all(_raw, "\n", ""); // single-line field only -- see .md
            _raw = string_replace_all(_raw, "\r", "");
            _raw = string_replace_all(_raw, "\t", "");
            if (string_length(_raw) > DIALOGUE_TEXT_INPUT_MAX_LENGTH) {
                _raw = string_copy(_raw, 1, DIALOGUE_TEXT_INPUT_MAX_LENGTH);
            }
            if (_raw != keyboard_string) keyboard_string = _raw;
            textInputValue = keyboard_string;
        }

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        hoveredExit = _HitTestExit(_mx, _my);
        if (hoveredExit && mouse_check_button_pressed(mb_left)) {
            Close();
            if (onExit != undefined) onExit();
            return self;
        }

        hoveredOption = _HitTestOption(_mx, _my);

        if (hoveredOption != -1 && mouse_check_button_pressed(mb_left)) {
            var _index = hoveredOption;
            var _text  = options[_index];

            lastSelectedOption = _index;
            lastSelectedText   = _text;

            Close();

            if (onSelect != undefined) onSelect(_index, _text);
        }

        return self;
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event. No-ops if not open. The
    ///        background dim and every element fade together via alpha. See .md.
    static Draw = function() {
        if (!isOpen) return;

        draw_set_color(c_black);
        draw_set_alpha(0.75 * alpha);
        draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
        draw_set_alpha(1);

        if (portrait != undefined) {
            var _portraitPos = _PortraitDrawPosition();
            draw_sprite_ext(portrait, 0, _portraitPos.x, _portraitPos.y, DIALOGUE_PORTRAIT_SCALE, DIALOGUE_PORTRAIT_SCALE, 0, c_white, alpha);
        }

        var _totalRows = array_length(options) + (textInputEnabled ? 1 : 0); // signing line counts as its own visual row -- see .md
        draw_sprite_ext(sDialogueUIBack, DialogueBoxFrame(_totalRows), x, y, DIALOGUE_SCALE, DIALOGUE_SCALE, 0, c_white, alpha);

        if (name != "") {
            DrawCardTextWithShadow(nameText, x + (DIALOGUE_NAME_TEXT_X * DIALOGUE_SCALE), y + (DIALOGUE_NAME_TEXT_Y * DIALOGUE_SCALE), alpha);
        }

        speakerText.reveal(floor(speakerRevealChars)); // typewriter -- harmless no-op once revealChars exceeds the real length, see .md
        DrawCardTextWithShadow(speakerText, x + (DIALOGUE_SPEAKER_TEXT_X * DIALOGUE_SCALE), y + (DIALOGUE_SPEAKER_TEXT_Y * DIALOGUE_SCALE), alpha);

        var _rowY = y + (DIALOGUE_OPTION_START_Y * DIALOGUE_SCALE);

        if (textInputEnabled) {
            var _lineSprite = DialogueOptionSprite(0); // reference only for width/height -- no sprite is drawn here, just a line, see .md
            var _rowW = sprite_get_width(_lineSprite)  * DIALOGUE_SCALE;
            var _rowH = sprite_get_height(_lineSprite) * DIALOGUE_SCALE;
            var _lineX1 = x + (DIALOGUE_OPTION_START_X * DIALOGUE_SCALE) + (DIALOGUE_OPTION_TEXT_OFFSET_X * DIALOGUE_SCALE);
            var _lineX2 = x + (DIALOGUE_OPTION_START_X * DIALOGUE_SCALE) + _rowW - (DIALOGUE_OPTION_TEXT_OFFSET_X * DIALOGUE_SCALE);
            var _lineY  = _rowY + _rowH; // bottom edge of the row -- "aligned vertically where the bottom of an option would be" per spec, see .md

            if (textInputValue != __textInputLastRenderedValue) {
                textInputText = scribble(textInputValue + "|", $"__dialogue{__id}TextInput__") // static caret, no blink -- see .md
                    .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
                    .align(fa_left, fa_middle);
                __textInputLastRenderedValue = textInputValue;
            }

            DrawCardTextWithShadow(textInputText, _lineX1, _rowY + (_rowH / 2), alpha);

            draw_set_color(HOVER_CARD_TEXT_COLOR);
            draw_set_alpha(alpha);
            draw_line_width(_lineX1, _lineY, _lineX2, _lineY, 2); // the signing line itself -- see .md
            draw_set_alpha(1);

            _rowY += _rowH + DIALOGUE_OPTION_ROW_GAP;
        }

        for (var i = 0; i < array_length(options); i++) {
            var _sprite = DialogueOptionSprite(i);
            var _optionX = x + (DIALOGUE_OPTION_START_X * DIALOGUE_SCALE);

            draw_sprite_ext(_sprite, (i == hoveredOption) ? 1 : 0, _optionX, _rowY, DIALOGUE_SCALE, DIALOGUE_SCALE, 0, c_white, alpha);
            DrawCardTextWithShadow(optionTexts[i], _optionX + (DIALOGUE_OPTION_TEXT_OFFSET_X * DIALOGUE_SCALE), _rowY + (DIALOGUE_OPTION_TEXT_OFFSET_Y * DIALOGUE_SCALE), alpha);

            _rowY += (sprite_get_height(_sprite) * DIALOGUE_SCALE) + DIALOGUE_OPTION_ROW_GAP;
        }

        if (exitEnabled) {
            var _exitRect = _ExitRect();
            draw_sprite_ext(sDialogueUIExit, hoveredExit ? 1 : 0, _exitRect.x1, _exitRect.y1, DIALOGUE_SCALE, DIALOGUE_SCALE, 0, c_white, alpha);
        }
    }
}
