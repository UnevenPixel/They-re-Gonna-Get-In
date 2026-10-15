// The war room screen, between the hub town and the pre-run (Campaign
// select) screen -- storytelling/tutorial staging ground today, eventually
// leader selection. See WarRoomMenuScripts.md.

#macro WARROOM_SCALE 1 // sWarRoomBG is native 1920x1080, matches the room 1:1 -- see .md

#macro WARROOM_LEADER_X 933
#macro WARROOM_LEADER_Y 348

#macro WARROOM_CONTINUE_X 1077
#macro WARROOM_CONTINUE_Y 609

#macro WARROOM_CONTINUE_PULSE_MIN    0.1 // faint white pulse while hovering -- sWarRoomContinueButton has only one frame, see .md
#macro WARROOM_CONTINUE_PULSE_MAX    0.4
#macro WARROOM_CONTINUE_PULSE_MID    ((WARROOM_CONTINUE_PULSE_MIN + WARROOM_CONTINUE_PULSE_MAX) / 2)
#macro WARROOM_CONTINUE_PULSE_AMP    ((WARROOM_CONTINUE_PULSE_MAX - WARROOM_CONTINUE_PULSE_MIN) / 2)
#macro WARROOM_CONTINUE_PULSE_PERIOD 2 // seconds -- full sine cycle; peak and valley land PULSE_PERIOD/2 (1s) apart, see .md

#macro WARROOM_EXIT_MARGIN 8              // 8px buffer both axes, same treatment PreRun's exit button uses
#macro WARROOM_EXIT_SCALE  DIALOGUE_SCALE // reusing sDialogueUIExit at the same scale used elsewhere

/// @function WarRoomMenu()
/// @description The war room screen. Plain struct owned by oWarRoomMenu.
function WarRoomMenu() constructor {
    hoveredContinue    = false;
    hoveredExit        = false;
    continuePulseTimer = 0; // seconds spent hovering this run -- reset to 0 (the trough) each time hover starts fresh, see .md
    continuePulseAlpha = WARROOM_CONTINUE_PULSE_MIN;

    // Static for now -- swappable once leader selection exists (Connelius
    // vs. two other rulers). See .md.
    leaderSprite = sConneliusWarRoom;

    dialogueOverlay      = new DialogueOverlay();
    wasDialogueOverlayOpen = false; // tracks the isOpen true->false transition -- see .md

    advisorName = ""; // player-typed name from Booger's signing-line (node K) -- see .md

    // NOT static, unlike everything else in this file -- these are passed
    // around as bare callback values and invoked from DialogueOverlay's own
    // context. static here caused a self-binding crash in the Beggar tree
    // (HubTownMenuScripts.gml) for the same reason -- see that file's header
    // comment and WarRoomMenuScripts.md.

    /// @function _OnConneliusBSelect(_index, _text)
    /// @description dialogueOverlay's onSelect callback for node B -- dispatches to C/F/H.
    /// @param {Real} _index
    /// @param {String} _text
    _OnConneliusBSelect = function(_index, _text) {
        switch (_index) {
            case 0: _OpenConneliusC(); break;
            case 1: _OpenConneliusF(); break;
            case 2: _OpenConneliusH(); break;
        }
    }

    /// @function _OpenConneliusA()
    /// @description Connelius's opening line -- auto-opens on first War Room entry.
    _OpenConneliusA = function() {
        dialogueOverlay.Open(
            "Connelius", "Hey! You! Servant boy!",
            ["[[Continue]"], // [[ escapes Scribble's literal command-tag-open bracket -- see DialogueOverlayScripts.md
            _OpenConneliusB, true, undefined, true, c_yellow, undefined, aConneliusSpeak
        );
    }

    /// @function _OpenConneliusB()
    /// @description Connelius's demand -- also where the two loop branches (E, G) lead back to.
    _OpenConneliusB = function() {
        dialogueOverlay.Open(
            "Connelius", "Fetch me more wine and my horse!",
            [
                "I'm not a servant",
                "Is it wise to drink and ride?",
                "Okay. Where are the kitchen's and stables?"
            ],
            _OnConneliusBSelect, true, undefined, false, c_yellow, undefined, aConneliusSpeak
        );
    }

    /// @function _OpenConneliusC()
    /// @description Response 1's first follow-up line.
    _OpenConneliusC = function() {
        dialogueOverlay.Open(
            "Connelius", "Are you in Kyrii?",
            ["Yes.", "Uh... I think so?"],
            _OpenConneliusD, true, undefined, false, c_yellow, undefined, aConneliusSpeak
        );
    }

    /// @function _OpenConneliusD()
    /// @description Response 1's second follow-up line.
    _OpenConneliusD = function() {
        dialogueOverlay.Open(
            "Connelius", "And do you know who I am?",
            ["No.", "Uh... I think so?"],
            _OpenConneliusE, true, undefined, false, c_yellow, undefined, aConneliusSpeak
        );
    }

    /// @function _OpenConneliusE()
    /// @description Response 1's payoff -- loops back to B.
    _OpenConneliusE = function() {
        dialogueOverlay.Open(
            "Connelius", "I'm Connelius Delmar, King and ruler of Kyrii, where you happen to stand. And for as long as you stand in Kyrii, I don't care if you're a merchant, a jester, or my own mother risen from her grave! You, are a servant, to your king! Wine! Horse! You! Now!",
            ["[[Continue]"],
            _OpenConneliusB, true, undefined, true, c_yellow, undefined, aConneliusSpeak
        );
    }

    /// @function _OpenConneliusF()
    /// @description Response 2's follow-up line.
    _OpenConneliusF = function() {
        dialogueOverlay.Open(
            "Connelius", "Ugh. You sound like Booger. Or my mother. I hate Booger and my Mother.",
            ["[[Continue]"],
            _OpenConneliusG, true, undefined, true, c_yellow, undefined, aConneliusSpeak
        );
    }

    /// @function _OpenConneliusG()
    /// @description Response 2's payoff -- loops back to B.
    _OpenConneliusG = function() {
        dialogueOverlay.Open(
            "Connelius", "Lighten up, I'm not even drunk! I'm good to ride!",
            ["[[Continue]"],
            _OpenConneliusB, true, undefined, true, c_yellow, undefined, aConneliusSpeak
        );
    }

    /// @function _OpenConneliusH()
    /// @description Response 3's follow-up line -- the advisor-hire branch, does not loop back to B.
    _OpenConneliusH = function() {
        dialogueOverlay.Open(
            "Connelius", "What? Don't you work here?",
            ["No. I came to apply for the advisor position."],
            _OpenConneliusI, true, undefined, false, c_yellow, undefined, aConneliusSpeak
        );
    }

    /// @function _OpenConneliusI()
    /// @description Advisor-hire branch, continued.
    _OpenConneliusI = function() {
        dialogueOverlay.Open(
            "Connelius", "Oh. Well why didn't you say so in the first place lad! You're hired!",
            ["Oh. Just like that?", "Yippee!"],
            _OpenConneliusJ, true, undefined, false, c_yellow, undefined, aConneliusSpeak
        );
    }

    /// @function _OpenConneliusJ()
    /// @description Advisor-hire branch, continued.
    _OpenConneliusJ = function() {
        dialogueOverlay.Open(
            "Connelius", "Yep! Job is so easy even a goblin could do it. In fact, a goblin HAS been doing it. We let her have the role as a joke while we found a replacement for my last advisor. Since I'm a great king, we don't really need an advisor, so I haven't been in a rush to find a replacement. But, the Queen, Materna, is not too fond of the little critter running around the castle. So if you want the role is yours!",
            ["I'll take it."],
            _OpenConneliusK, true, undefined, false, c_yellow, undefined, aConneliusSpeak
        );
    }

    /// @function _OpenConneliusK()
    /// @description Advisor-hire branch, continued.
    _OpenConneliusK = function() {
        dialogueOverlay.Open(
            "Connelius", "Great! Anyway I have super important business to attend to! Booger can train you. Like an advisor... TO MY ADVISOR! HAHAHAHAHA! Now THAT'S funny.",
            ["*Laugh Nervously*"],
            _OpenConneliusL, true, undefined, false, c_yellow, undefined, aConneliusSpeak
        );
    }

    /// @function _OpenConneliusL()
    /// @description Advisor-hire branch's final Connelius line -- [shake] is a real Scribble command
    ///        tag here (not literal text needing escaping). Hands off to Booger on Continue.
    _OpenConneliusL = function() {
        dialogueOverlay.Open(
            "Connelius", "[shake]BOOGER!!![/shake]",
            ["[[Continue]"],
            _OpenBoogerA, true, undefined, true, c_yellow, undefined, aConneliusSpeak
        );
    }

    // ---- Booger's tree (2026-08-13, second pass) -- see .md for the full
    // shape, the "Boog" name-shortening at G, and the K/L signing-line loop.

    /// @function _OnBoogerBSelect(_index, _text)
    /// @description dialogueOverlay's onSelect callback for node B -- dispatches to C/D/E.
    /// @param {Real} _index
    /// @param {String} _text
    _OnBoogerBSelect = function(_index, _text) {
        switch (_index) {
            case 0: _OpenBoogerC(); break;
            case 1: _OpenBoogerD(); break;
            case 2: _OpenBoogerE(); break;
        }
    }

    /// @function _OnBoogerLSelect(_index, _text)
    /// @description dialogueOverlay's onSelect callback for node L -- confirm the name or go back to K to retype it.
    /// @param {Real} _index
    /// @param {String} _text
    _OnBoogerLSelect = function(_index, _text) {
        switch (_index) {
            case 0: _OpenBoogerM(); break;
            case 1: _OpenBoogerK(); break;
        }
    }

    /// @function _OnBoogerSign(_index, _text)
    /// @description dialogueOverlay's onSelect callback for node K's "[Sign]" option. Reads the
    ///        just-typed name out of dialogueOverlay.textInputValue (still valid here -- Close()
    ///        clears keyboard_string, not textInputValue itself, see DialogueOverlayScripts.md).
    ///        An empty/whitespace-only signature re-opens K instead of advancing -- not explicitly
    ///        specified, added defensively so "Your name is ?" can't happen. See .md.
    /// @param {Real} _index
    /// @param {String} _text
    _OnBoogerSign = function(_index, _text) {
        var _typed = string_trim(dialogueOverlay.textInputValue);
        if (_typed == "") {
            _OpenBoogerK(); // empty signature -- reopen K instantly instead of advancing, see .md
            return;
        }
        advisorName = _typed;
        _OpenBoogerL();
    }

    /// @function _OpenBoogerA()
    /// @description Booger's opening line -- Connelius's node L hands off here on Continue.
    _OpenBoogerA = function() {
        dialogueOverlay.Open(
            "Booger", "Yes my lord!!",
            ["[[Continue]"],
            _OpenBoogerB, true, undefined, true, c_yellow, sBoogerPortrait, aBoogerSpeak
        );
    }

    /// @function _OpenBoogerB()
    /// @description Booger's urgent-news setup -- also where loop branches C/D lead back to.
    _OpenBoogerB = function() {
        dialogueOverlay.Open(
            "Booger", "Servant, where is the King? I bring urgent news.",
            [
                "He had important stuff to do.",
                "He is drinking and riding.",
                "I'm not a servant. I'm the new Advisor."
            ],
            _OnBoogerBSelect, true, undefined, false, c_yellow, sBoogerPortrait, aBoogerSpeak
        );
    }

    /// @function _OpenBoogerC()
    /// @description Response 1's follow-up -- loops back to B.
    _OpenBoogerC = function() {
        dialogueOverlay.Open(
            "Booger", "Oh. I'm sure I will have to deal with the repercussions of his actions later.",
            ["[[Continue]"],
            _OpenBoogerB, true, undefined, true, c_yellow, sBoogerPortrait, aBoogerSpeak
        );
    }

    /// @function _OpenBoogerD()
    /// @description Response 2's follow-up -- loops back to B.
    _OpenBoogerD = function() {
        dialogueOverlay.Open(
            "Booger", "Oh. Greaaaat.",
            ["[[Continue]"],
            _OpenBoogerB, true, undefined, true, c_yellow, sBoogerPortrait, aBoogerSpeak
        );
    }

    /// @function _OpenBoogerE()
    /// @description Response 3's follow-up -- the "new Advisor" reveal, does not loop back to B.
    _OpenBoogerE = function() {
        dialogueOverlay.Open(
            "Booger", "What? Are... are you serious? This isn't one of his jokes? I don't have to do this anymore?!",
            ["Not exactly. He said you are to train me. As the advisor to the advisor."],
            _OpenBoogerF, true, undefined, false, c_yellow, sBoogerPortrait, aBoogerSpeak
        );
    }

    /// @function _OpenBoogerF()
    /// @description Advisor-to-the-advisor branch, continued. "Oh. Geaaaat." reproduced verbatim
    ///        as dictated -- distinct spelling from D's "Oh. Greaaaat.", not silently unified. See .md.
    _OpenBoogerF = function() {
        dialogueOverlay.Open(
            "Booger", "Oh. Geaaaat.",
            ["Wait... your name is Booger?"],
            _OpenBoogerG, true, undefined, false, c_yellow, sBoogerPortrait, aBoogerSpeak
        );
    }

    /// @function _OpenBoogerG()
    /// @description The name reveal. Still spoken under the "Booger" display name -- the
    ///        shortened "Boog" name takes effect starting with H, per the request. See .md.
    _OpenBoogerG = function() {
        dialogueOverlay.Open(
            "Booger", "Please just call me Boog. When you have goblin parents, you often get stuck with a horrid name. Most are just too dimwitted to care.",
            ["[[Continue]"],
            _OpenBoogerH, true, undefined, true, c_yellow, sBoogerPortrait, aBoogerSpeak
        );
    }

    /// @function _OpenBoogerH()
    /// @description First node using the shortened "Boog" display name. The war news.
    _OpenBoogerH = function() {
        dialogueOverlay.Open(
            "Boog", "OH! My urgent news! Talos has declared war on us! They plan to march today!",
            ["Is that bad?", "Oh. Cool."],
            _OpenBoogerI, true, undefined, false, c_yellow, sBoogerPortrait, aBoogerSpeak
        );
    }

    /// @function _OpenBoogerI()
    /// @description Both of H's responses land here.
    _OpenBoogerI = function() {
        dialogueOverlay.Open(
            "Boog", "Were you kicked in the head as a child?",
            ["Huh?", "What?"],
            _OpenBoogerJ, true, undefined, false, c_yellow, sBoogerPortrait, aBoogerSpeak
        );
    }

    /// @function _OpenBoogerJ()
    /// @description Both of I's responses land here.
    _OpenBoogerJ = function() {
        dialogueOverlay.Open(
            "Boog", "Oh my God. We are doomed.",
            ["Actually, I used to play army with my friends back home. It should be pretty similar right?"],
            _OpenBoogerK, true, undefined, false, c_yellow, sBoogerPortrait, aBoogerSpeak
        );
    }

    /// @function _OpenBoogerK()
    /// @description The signing line -- option row 0 becomes a typable text field (DialogueOverlay's
    ///        textInputEnabled) seeded with advisorName, so a "let me change it" round-trip from L
    ///        preserves the previously typed name instead of clearing it. See .md.
    _OpenBoogerK = function() {
        dialogueOverlay.Open(
            "Boog", "Honestly... I'm not even sure what I expected. Sure. It's the same. Just sign here to show you're employed by the kingdom of Kyrii.",
            ["[[Sign]"],
            _OnBoogerSign, true, undefined, false, c_yellow, sBoogerPortrait, aBoogerSpeak,
            true, advisorName
        );
    }

    /// @function _OpenBoogerL()
    /// @description Confirms the signed name back to the player.
    _OpenBoogerL = function() {
        dialogueOverlay.Open(
            "Boog", $"Your name is {advisorName}? I mean... I guess it's better than mine...",
            ["Yes", "Wait, let me change it."],
            _OnBoogerLSelect, true, undefined, false, c_yellow, sBoogerPortrait, aBoogerSpeak
        );
    }

    /// @function _OpenBoogerM()
    /// @description Final line -- [To the Wall] ends the War Room intro and drops straight into
    ///        gameplay, bypassing the Pre-Run campaign-select screen entirely. See .md.
    _OpenBoogerM = function() {
        dialogueOverlay.Open(
            "Boog", $"Ok {advisorName}! There's no time to waste! Let's get to the wall!",
            ["[[To the Wall]"],
            _OnBoogerToWall, true, undefined, true, c_yellow, sBoogerPortrait, aBoogerSpeak
        );
    }

    /// @function _OnBoogerToWall(_index, _text)
    /// @description Ends the War Room's tutorial intro tree by leaving the room outright (straight
    ///        into gameplay), NOT by a normal same-room dialogue Close(). Because of that,
    ///        Update()'s generic wasDialogueOverlayOpen close-tracker can never observe this as a
    ///        close (the instance is destroyed by room_goto before its next Step) -- so
    ///        hasSeenWarRoomIntro is written here explicitly, duplicating that guarded-write
    ///        instead of relying on the generic path. See .md -- this is a real gotcha, not
    ///        boilerplate copied by habit.
    /// @param {Real} _index
    /// @param {String} _text
    _OnBoogerToWall = function(_index, _text) {
        if (!global.playerSaveData.hasSeenWarRoomIntro) {
            global.playerSaveData.hasSeenWarRoomIntro = true;
            SavePlayerSaveData();
        }
        room_goto(rmTestGameplay); // same destination _PlayTalos() uses (PreRunMenuScripts.gml) -- skips Pre-Run's campaign-select screen, see .md
    }

    /// @function _ContinueRect()
    /// @description GUI-space rect of the Continue button, derived from the sprite's own dimensions/origin.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _ContinueRect = function() {
        var _w  = sprite_get_width(sWarRoomContinueButton)  * WARROOM_SCALE;
        var _h  = sprite_get_height(sWarRoomContinueButton) * WARROOM_SCALE;
        var _x1 = WARROOM_CONTINUE_X - (sprite_get_xoffset(sWarRoomContinueButton) * WARROOM_SCALE);
        var _y1 = WARROOM_CONTINUE_Y - (sprite_get_yoffset(sWarRoomContinueButton) * WARROOM_SCALE);
        return { x1: _x1, y1: _y1, x2: _x1 + _w, y2: _y1 + _h };
    }

    /// @function _ExitRect()
    /// @description sDialogueUIExit's on-screen rect, top-left anchored.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _ExitRect = function() {
        var _w = sprite_get_width(sDialogueUIExit)  * WARROOM_EXIT_SCALE;
        var _h = sprite_get_height(sDialogueUIExit) * WARROOM_EXIT_SCALE;
        return { x1: WARROOM_EXIT_MARGIN, y1: WARROOM_EXIT_MARGIN, x2: WARROOM_EXIT_MARGIN + _w, y2: WARROOM_EXIT_MARGIN + _h };
    }

    /// @function Update()
    /// @description Call once per Step event.
    static Update = function() {
        // hasSeenWarRoomIntro is set the instant the dialogue actually
        // finishes closing (fade-out included), regardless of whether it
        // reached its natural end or was exited early -- same "any close
        // counts" behavior HubControl uses for the Beggar. Must run even
        // while the dialogue is open, so this check happens BEFORE the
        // early-return below. See .md.
        if (wasDialogueOverlayOpen && !dialogueOverlay.isOpen) {
            if (!global.playerSaveData.hasSeenWarRoomIntro) {
                global.playerSaveData.hasSeenWarRoomIntro = true;
                SavePlayerSaveData();
            }
        }
        wasDialogueOverlayOpen = dialogueOverlay.isOpen;

        if (dialogueOverlay.isOpen) {
            hoveredContinue = false; // no dangling hover state (and no frozen pulse) while the modal dialogue covers the screen
            hoveredExit     = false;
            dialogueOverlay.Update();
            return;
        }

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        var _exitRect = _ExitRect();
        hoveredExit = (_mx >= _exitRect.x1 && _mx <= _exitRect.x2 && _my >= _exitRect.y1 && _my <= _exitRect.y2);
        if (hoveredExit && mouse_check_button_pressed(mb_left)) {
            room_goto(rmHubTown);
            return;
        }

        var _continueRect       = _ContinueRect();
        var _wasHoveredContinue = hoveredContinue;
        hoveredContinue = (_mx >= _continueRect.x1 && _mx <= _continueRect.x2 && _my >= _continueRect.y1 && _my <= _continueRect.y2);

        if (hoveredContinue) {
            if (!_wasHoveredContinue) {
                continuePulseTimer = 0; // fresh hover always starts at the trough (WARROOM_CONTINUE_PULSE_MIN) -- see .md
            }
            continuePulseTimer += delta_time / 1000000; // microseconds -> seconds, same idiom as BuildingUpdateProduction/TitleMenu.Update()

            var _phase = (2 * pi / WARROOM_CONTINUE_PULSE_PERIOD) * continuePulseTimer;
            continuePulseAlpha = WARROOM_CONTINUE_PULSE_MID - (WARROOM_CONTINUE_PULSE_AMP * cos(_phase)); // cos(0) = 1 -> starts at MID - AMP = MIN, see .md
        }

        if (hoveredContinue && mouse_check_button_pressed(mb_left)) {
            room_goto(rmPreRun);
        }
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event.
    static Draw = function() {
        draw_sprite_ext(sWarRoomBG, 0, 0, 0, WARROOM_SCALE, WARROOM_SCALE, 0, c_white, 1);

        draw_sprite_ext(leaderSprite, 0, WARROOM_LEADER_X, WARROOM_LEADER_Y, WARROOM_SCALE, WARROOM_SCALE, 0, c_white, 1);

        draw_sprite_ext(sWarRoomContinueButton, 0, WARROOM_CONTINUE_X, WARROOM_CONTINUE_Y, WARROOM_SCALE, WARROOM_SCALE, 0, c_white, 1);

        if (hoveredContinue) {
            // Additive white pulse, masked to the sprite's own shape/alpha --
            // a multiplicative tint (draw_sprite_ext's normal color param)
            // can't brighten past the source image, so this uses bm_add
            // instead. New blend-mode usage for this codebase -- see .md.
            gpu_set_blendmode(bm_add);
            draw_sprite_ext(sWarRoomContinueButton, 0, WARROOM_CONTINUE_X, WARROOM_CONTINUE_Y, WARROOM_SCALE, WARROOM_SCALE, 0, c_white, continuePulseAlpha);
            gpu_set_blendmode(bm_normal);
        }

        var _exitRect = _ExitRect();
        draw_sprite_ext(sDialogueUIExit, hoveredExit ? 1 : 0, _exitRect.x1, _exitRect.y1, WARROOM_EXIT_SCALE, WARROOM_EXIT_SCALE, 0, c_white, 1);

        dialogueOverlay.Draw();
    }

    if (!global.playerSaveData.hasSeenWarRoomIntro) {
        _OpenConneliusA(); // auto-opens Connelius's tutorial intro on first War Room entry -- see .md
    }
}
