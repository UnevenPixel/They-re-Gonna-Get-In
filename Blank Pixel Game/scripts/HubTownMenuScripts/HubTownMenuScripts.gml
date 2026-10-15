// The hub town screen, between the title screen and gameplay. Owns the
// Beggar's tutorial dialogue tree. See HubTownMenuScripts.md.

#macro HUBTOWN_SCALE          1
#macro HUBTOWN_DIM_AMOUNT     0.25
#macro HUBTOWN_DIM_LERP_RATE  0.25

/// @function HubTownOption(_sprite, _action, _x, _y)
/// @description One hoverable/clickable hub-town element's state. _x/_y are the sprite's center point.
/// @param {Asset.GMSprite} _sprite
/// @param {String} _action "beggar" | "castle"
/// @param {Real} _x
/// @param {Real} _y
function HubTownOption(_sprite, _action, _x, _y) constructor {
    sprite = _sprite;
    action = _action;
    width  = sprite_get_width(_sprite);
    height = sprite_get_height(_sprite);

    x = _x;
    y = _y;

    dimLerp = 0; // 0 = full brightness, 1 = fully dimmed by HUBTOWN_DIM_AMOUNT
}

/// @function HubTownMenu()
/// @description The hub town screen. Plain struct owned by oHubTownMenu.
function HubTownMenu() constructor {
    options = [
        new HubTownOption(sBeggarTown, "beggar", 296, 766),
        new HubTownOption(sCastleTown, "castle", 854, 160),
    ];

    hoveredIndex      = -1;
    backgroundDimLerp = 0;

    dialogueOverlay = new DialogueOverlay();
    hubControl      = new HubControl(self); // gates option availability + resolves dialogue openers -- see HubControlScripts.md

    /// @function _OptionRect(_o)
    /// @description Hover hit-test rect, centered on the option's own x/y.
    /// @param {Struct.HubTownOption} _o
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _OptionRect = function(_o) {
        var _w = _o.width  * HUBTOWN_SCALE;
        var _h = _o.height * HUBTOWN_SCALE;
        return {
            x1: _o.x - (_w / 2), y1: _o.y - (_h / 2),
            x2: _o.x + (_w / 2), y2: _o.y + (_h / 2)
        };
    }

    /// @function _HandleOptionAction(_action)
    /// @description Routes a clicked option through HubControl -- no-ops if that action isn't currently available.
    /// @param {String} _action
    static _HandleOptionAction = function(_action) {
        if (!hubControl.IsOptionAvailable(_action)) return;

        switch (_action) {
            case "castle":
                room_goto(rmWarRoom); // War room, then Campaign select -- see WarRoomMenuScripts.md
                break;

            case "beggar":
                var _opener = hubControl.GetDialogueOpener("beggar");
                if (_opener != undefined) _opener();
                break;
        }
    }

    // NOT static, unlike everything else in this file -- these are passed
    // around as bare callback values and invoked from DialogueOverlay's own
    // context. static here caused a self-binding crash. See .md.

    /// @function _OnBeggarMainSelect(_index, _text)
    /// @description dialogueOverlay's onSelect callback for the main node -- dispatches to A/B/C/D.
    /// @param {Real} _index
    /// @param {String} _text
    _OnBeggarMainSelect = function(_index, _text) {
        switch (_index) {
            case 0: _OpenBeggarA1(); break;
            case 1: _OpenBeggarB1(); break;
            case 2: _OpenBeggarC1(); break;
            case 3: _OpenBeggarD1(); break;
        }
    }

    /// @function _OpenBeggarMain()
    /// @description The Beggar's opening line -- also where every other node leads back to.
    _OpenBeggarMain = function() {
        dialogueOverlay.Open(
            "Beggar", "Spare a few Groats?",
            [
                "Spare a few goats? What?",
                "Sorry but I'm as broke as you. I'm just dressed nice for an interview.",
                "Are you going to use it to buy tobacco and ale?",
                "Can you point me to the main castle?"
            ],
            _OnBeggarMainSelect, true, undefined, false, c_yellow, sBeggarPortrait, aBeggarSpeak
        );
    }

    /// @function _OpenBeggarA1()
    /// @description Response A's first follow-up line.
    _OpenBeggarA1 = function() {
        dialogueOverlay.Open(
            "Beggar", "No lad, not goats! Groats! Money! Gold! Every Kingdom in the surrounding area uses Groats. You must be far from home!",
            ["[[Continue]"], // [[ escapes Scribble's literal command-tag-open bracket -- see .md
            _OpenBeggarA2, true, undefined, true, c_yellow, sBeggarPortrait, aBeggarSpeak
        );
    }

    /// @function _OpenBeggarA2()
    /// @description Response A's second follow-up line.
    _OpenBeggarA2 = function() {
        dialogueOverlay.Open(
            "Beggar", "This beautiful little kingdom is called Kyrii. If you brought money from some backwater village, then you're out of luck unless its groats.",
            ["[[Continue]"], // [[ escapes Scribble's literal command-tag-open bracket -- see .md
            _OpenBeggarMain, true, undefined, true, c_yellow, sBeggarPortrait, aBeggarSpeak
        );
    }

    /// @function _OpenBeggarB1()
    /// @description Response B's follow-up line.
    _OpenBeggarB1 = function() {
        dialogueOverlay.Open(
            "Beggar", "You DO look sharp. You remind me of myself when I was younger. .... What?",
            ["[[Continue]"], // [[ escapes Scribble's literal command-tag-open bracket -- see .md
            _OpenBeggarMain, true, undefined, true, c_yellow, sBeggarPortrait, aBeggarSpeak
        );
    }

    /// @function _OpenBeggarC1()
    /// @description Response C's follow-up line.
    _OpenBeggarC1 = function() {
        dialogueOverlay.Open(
            "Beggar", "Who taught you to say that? Your parents? Were they good people?",
            ["[[Continue]"], // [[ escapes Scribble's literal command-tag-open bracket -- see .md
            _OpenBeggarMain, true, undefined, true, c_yellow, sBeggarPortrait, aBeggarSpeak
        );
    }

    /// @function _OpenBeggarD1()
    /// @description Response D's follow-up line.
    _OpenBeggarD1 = function() {
        dialogueOverlay.Open(
            "Beggar", "Ahhh... you have big aspirations huh? Sure. It's the giant castle. Kind of hard to miss.",
            ["[[Continue]"], // [[ escapes Scribble's literal command-tag-open bracket -- see .md
            _OpenBeggarMain, true, undefined, true, c_yellow, sBeggarPortrait, aBeggarSpeak
        );
    }

    /// @function Update()
    /// @description Call once per Step event.
    static Update = function() {
        hubControl.Update(); // must run even while dialogueOverlay is open -- see HubControlScripts.md

        if (dialogueOverlay.isOpen) {
            dialogueOverlay.Update();
            return;
        }

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        hoveredIndex = -1;
        for (var i = 0; i < array_length(options); i++) {
            if (!hubControl.IsOptionAvailable(options[i].action)) continue;

            var _rect = _OptionRect(options[i]);
            if (_mx >= _rect.x1 && _mx <= _rect.x2 && _my >= _rect.y1 && _my <= _rect.y2) {
                hoveredIndex = i;
                break;
            }
        }

        var _anyHovered = (hoveredIndex != -1);

        for (var i = 0; i < array_length(options); i++) {
            var _o      = options[i];
            var _target = (_anyHovered && i != hoveredIndex) ? 1 : 0;
            _o.dimLerp  = lerp(_o.dimLerp, _target, HUBTOWN_DIM_LERP_RATE);
        }

        var _bgTarget     = _anyHovered ? 1 : 0;
        backgroundDimLerp = lerp(backgroundDimLerp, _bgTarget, HUBTOWN_DIM_LERP_RATE);

        if (_anyHovered && mouse_check_button_pressed(mb_left)) {
            _HandleOptionAction(options[hoveredIndex].action);
        }
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event.
    static Draw = function() {
        var _bgColor = merge_color(c_white, c_black, HUBTOWN_DIM_AMOUNT * backgroundDimLerp);
        draw_sprite_ext(sTownBack, 0, 0, 0, HUBTOWN_SCALE, HUBTOWN_SCALE, 0, _bgColor, 1);

        for (var i = 0; i < array_length(options); i++) {
            var _o     = options[i];
            var _color = merge_color(c_white, c_black, HUBTOWN_DIM_AMOUNT * _o.dimLerp);
            draw_sprite_ext(_o.sprite, 0, _o.x, _o.y, HUBTOWN_SCALE, HUBTOWN_SCALE, 0, _color, 1);
        }

        dialogueOverlay.Draw();
    }

    if (!global.playerSaveData.hasSeenBeggarIntro) {
        hubControl.StartBeggarTutorial(); // auto-opens the Beggar's dialogue; hasSeenBeggarIntro is saved once it closes -- see HubControlScripts.md
    }
}
