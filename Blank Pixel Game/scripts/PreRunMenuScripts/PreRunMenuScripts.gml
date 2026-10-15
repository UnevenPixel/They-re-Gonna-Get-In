// The pre-run screen between the hub town and gameplay -- lets the player
// pick a Campaign to play. See PreRunMenuScripts.md.

#macro PRERUN_BG_COLOR      make_color_rgb(59, 46, 34)    // dull aged-wood brown -- placeholder solid fill, see .md
#macro PRERUN_PALETTE_BASE  make_color_rgb(196, 164, 118) // pale bronze
#macro PRERUN_PALETTE_LIGHT merge_color(PRERUN_PALETTE_BASE, c_white, 0.35) // hover/highlight/selected tone
#macro PRERUN_PALETTE_DARK  merge_color(PRERUN_PALETTE_BASE, c_black, 0.35) // panel fill / border tone

#macro PRERUN_TEXT_COLOR c_white

#macro PRERUN_PANEL_MARGIN_LEFT 80  // Campaigns panel anchor -- left side, see .md
#macro PRERUN_PANEL_WIDTH        460
#macro PRERUN_PANEL_TOP          140
#macro PRERUN_HEADER_HEIGHT      56
#macro PRERUN_ENTRY_HEIGHT       72
#macro PRERUN_ENTRY_GAP          16
#macro PRERUN_ENTRY_PAD_X        20

#macro PRERUN_HOVER_LERP_RATE 0.25 // matches HUBTOWN_DIM_LERP_RATE's convention

#macro PRERUN_EXIT_MARGIN 8              // 8x8 buffer from the top-left corner
#macro PRERUN_EXIT_SCALE  DIALOGUE_SCALE // reusing sDialogueUIExit at the same scale DialogueOverlay draws it

#macro PRERUN_PANEL_GAP            6  // buffer on both sides of the flavor box -- campaigns->box AND box->Start button, see .md
#macro PRERUN_FLAVOR_BOTTOM_MARGIN 64
#macro PRERUN_FLAVOR_PAD_X         24
#macro PRERUN_FLAVOR_PAD_TOP       20

#macro PRERUN_START_BUTTON_HEIGHT PRERUN_ENTRY_HEIGHT // matches campaign entry button height, see .md

/// @function CampaignEntry(_name, _action, _flavorText)
/// @description One row in the Campaigns list.
/// @param {String} _name Display name.
/// @param {Function} _action Called on Start Campaign click -- no args.
/// @param {String} _flavorText Shown in the flavor box while this entry is selected.
function CampaignEntry(_name, _action, _flavorText) constructor {
    name       = _name;
    action     = _action;
    flavorText = _flavorText;
    hoverLerp  = 0; // 0 = base tone, 1 = fully highlighted
}

/// @function PreRunMenu()
/// @description The pre-run (Campaign select) screen. Plain struct owned by oPreRunMenu.
function PreRunMenu() constructor {
    hoveredIndex   = -1;
    selectedIndex  = 0; // which campaign's flavor text shows + what Start Campaign launches -- assumes campaigns is non-empty
    hoveredExit    = false;
    hoveredStart   = false;
    startHoverLerp = 0;

    headerText = scribble("Campaigns", "__preRunHeader__")
        .starting_format(HOVER_CARD_BODY_FONT, PRERUN_TEXT_COLOR)
        .align(fa_left, fa_top);

    startText = scribble("Start Campaign", "__preRunStart__")
        .starting_format(HOVER_CARD_BODY_FONT, PRERUN_TEXT_COLOR)
        .align(fa_middle, fa_middle);

    /// @function _PlayTalos()
    /// @description Talos campaign entry's Start Campaign action. See .md re: the not-yet-built tutorial-complete branch.
    static _PlayTalos = function() {
        // TODO: once the in-gameplay tutorial exists, branch on its
        // completion flag here instead of always routing to plain
        // gameplay -- see .md.
        room_goto(rmTestGameplay);
    }

    campaigns = [
        new CampaignEntry(
            "Talos",
            _PlayTalos,
            "Word has reached the Kyrii court: the warlord Talos has massed his forces at the border and means to test just how new an advisor you really are. His army has thrown up a hasty base camp not two days' march from the capital -- more scaffolding than fortress, but enough to keep resupplying his raiders while they pick apart our outer farms and mines. As Kyrii's newest advisor, this one's yours: rally what forces you can, push Talos's raiders back from our lands, and raze that base before it becomes anything sturdier. A quiet victory here would go a long way toward convincing the court -- and the treasury -- that hiring you wasn't a mistake."
        ),
    ];

    entryTexts = array_create(array_length(campaigns));
    for (var i = 0; i < array_length(campaigns); i++) {
        entryTexts[i] = scribble(campaigns[i].name, $"__preRunEntry{i}__")
            .starting_format(HOVER_CARD_BODY_FONT, PRERUN_TEXT_COLOR)
            .align(fa_left, fa_middle);
    }

    /// @function _PanelRect()
    /// @description GUI-space rect of the Campaigns panel.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _PanelRect = function() {
        var _x1 = PRERUN_PANEL_MARGIN_LEFT;
        var _x2 = _x1 + PRERUN_PANEL_WIDTH;
        var _y1 = PRERUN_PANEL_TOP;
        var _y2 = _y1 + PRERUN_HEADER_HEIGHT + (array_length(campaigns) * (PRERUN_ENTRY_HEIGHT + PRERUN_ENTRY_GAP));
        return { x1: _x1, y1: _y1, x2: _x2, y2: _y2 };
    }

    /// @function _EntryRect(_index)
    /// @description GUI-space rect of one Campaigns list entry.
    /// @param {Real} _index
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _EntryRect = function(_index) {
        var _panel = _PanelRect();
        var _y1 = _panel.y1 + PRERUN_HEADER_HEIGHT + (_index * (PRERUN_ENTRY_HEIGHT + PRERUN_ENTRY_GAP));
        return { x1: _panel.x1, y1: _y1, x2: _panel.x2, y2: _y1 + PRERUN_ENTRY_HEIGHT };
    }

    /// @function _FlavorRect()
    /// @description GUI-space rect of the flavor-text box. Its right edge mirrors its left edge around the screen's horizontal center. See .md.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _FlavorRect = function() {
        var _panel  = _PanelRect();
        var _topRow = _EntryRect(0);
        var _x1 = _panel.x2 + PRERUN_PANEL_GAP;
        var _x2 = display_get_gui_width() - _x1; // mirrors _x1 -> box is centered on screen, see .md
        return { x1: _x1, y1: _topRow.y1, x2: _x2, y2: display_get_gui_height() - PRERUN_FLAVOR_BOTTOM_MARGIN };
    }

    /// @function _StartButtonRect()
    /// @description GUI-space rect of the Start Campaign button.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _StartButtonRect = function() {
        var _flavor = _FlavorRect();
        var _x1 = _flavor.x2 + PRERUN_PANEL_GAP;
        return { x1: _x1, y1: _flavor.y2 - PRERUN_START_BUTTON_HEIGHT, x2: _x1 + PRERUN_PANEL_WIDTH, y2: _flavor.y2 };
    }

    /// @function _ExitRect()
    /// @description sDialogueUIExit's on-screen rect, top-left anchored.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _ExitRect = function() {
        var _w = sprite_get_width(sDialogueUIExit)  * PRERUN_EXIT_SCALE;
        var _h = sprite_get_height(sDialogueUIExit) * PRERUN_EXIT_SCALE;
        return { x1: PRERUN_EXIT_MARGIN, y1: PRERUN_EXIT_MARGIN, x2: PRERUN_EXIT_MARGIN + _w, y2: PRERUN_EXIT_MARGIN + _h };
    }

    /// @function _SelectCampaign(_index)
    /// @description Selects a campaign -- updates the flavor box's text and rewraps it to the current flavor box width.
    /// @param {Real} _index
    static _SelectCampaign = function(_index) {
        selectedIndex = _index;
        var _flavor = _FlavorRect();
        flavorText = scribble(campaigns[selectedIndex].flavorText, "__preRunFlavor__")
            .starting_format(HOVER_CARD_BODY_FONT, PRERUN_TEXT_COLOR)
            .align(fa_left, fa_top)
            .wrap(_flavor.x2 - _flavor.x1 - (PRERUN_FLAVOR_PAD_X * 2));
    }

    _SelectCampaign(selectedIndex); // shows the default campaign's flavor text immediately, before any click

    /// @function Update()
    /// @description Call once per Step event.
    static Update = function() {
        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        var _exitRect = _ExitRect();
        hoveredExit = (_mx >= _exitRect.x1 && _mx <= _exitRect.x2 && _my >= _exitRect.y1 && _my <= _exitRect.y2);
        if (hoveredExit && mouse_check_button_pressed(mb_left)) {
            room_goto(rmWarRoom); // 2026-08-13: was rmHubTown -- now backs up one screen at a time now that War Room sits in between, see .md
            return;
        }

        hoveredIndex = -1;
        for (var i = 0; i < array_length(campaigns); i++) {
            var _rect = _EntryRect(i);
            if (_mx >= _rect.x1 && _mx <= _rect.x2 && _my >= _rect.y1 && _my <= _rect.y2) {
                hoveredIndex = i;
                break;
            }
        }

        for (var i = 0; i < array_length(campaigns); i++) {
            var _target = (i == hoveredIndex) ? 1 : 0;
            campaigns[i].hoverLerp = lerp(campaigns[i].hoverLerp, _target, PRERUN_HOVER_LERP_RATE);
        }

        // Clicking an entry SELECTS it (updates the flavor box) -- Start
        // Campaign is what actually launches it. See .md.
        if (hoveredIndex != -1 && mouse_check_button_pressed(mb_left)) {
            _SelectCampaign(hoveredIndex);
        }

        var _startRect = _StartButtonRect();
        hoveredStart   = (_mx >= _startRect.x1 && _mx <= _startRect.x2 && _my >= _startRect.y1 && _my <= _startRect.y2);
        startHoverLerp = lerp(startHoverLerp, hoveredStart ? 1 : 0, PRERUN_HOVER_LERP_RATE);

        if (hoveredStart && mouse_check_button_pressed(mb_left)) {
            campaigns[selectedIndex].action();
        }
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event.
    static Draw = function() {
        draw_set_color(PRERUN_BG_COLOR);
        draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);

        var _exitRect = _ExitRect();
        draw_sprite_ext(sDialogueUIExit, hoveredExit ? 1 : 0, _exitRect.x1, _exitRect.y1, PRERUN_EXIT_SCALE, PRERUN_EXIT_SCALE, 0, c_white, 1);

        var _panel = _PanelRect();
        DrawCardTextWithShadow(headerText, _panel.x1, _panel.y1, 1);

        for (var i = 0; i < array_length(campaigns); i++) {
            var _rect       = _EntryRect(i);
            var _isSelected = (i == selectedIndex);
            var _fill       = merge_color(PRERUN_PALETTE_DARK, PRERUN_PALETTE_LIGHT, campaigns[i].hoverLerp);

            draw_set_color(_fill);
            draw_rectangle(_rect.x1, _rect.y1, _rect.x2, _rect.y2, false);
            draw_set_color(_isSelected ? PRERUN_PALETTE_LIGHT : PRERUN_PALETTE_BASE); // selected entry keeps a brighter border even unhovered -- see .md
            draw_rectangle(_rect.x1, _rect.y1, _rect.x2, _rect.y2, true);

            DrawCardTextWithShadow(entryTexts[i], _rect.x1 + PRERUN_ENTRY_PAD_X, (_rect.y1 + _rect.y2) / 2, 1);
        }

        var _flavor = _FlavorRect();
        draw_set_color(PRERUN_PALETTE_DARK);
        draw_rectangle(_flavor.x1, _flavor.y1, _flavor.x2, _flavor.y2, false);
        draw_set_color(PRERUN_PALETTE_BASE);
        draw_rectangle(_flavor.x1, _flavor.y1, _flavor.x2, _flavor.y2, true);
        DrawCardTextWithShadow(flavorText, _flavor.x1 + PRERUN_FLAVOR_PAD_X, _flavor.y1 + PRERUN_FLAVOR_PAD_TOP, 1);

        var _start     = _StartButtonRect();
        var _startFill = merge_color(PRERUN_PALETTE_DARK, PRERUN_PALETTE_LIGHT, startHoverLerp);
        draw_set_color(_startFill);
        draw_rectangle(_start.x1, _start.y1, _start.x2, _start.y2, false);
        draw_set_color(PRERUN_PALETTE_BASE);
        draw_rectangle(_start.x1, _start.y1, _start.x2, _start.y2, true);
        DrawCardTextWithShadow(startText, (_start.x1 + _start.x2) / 2, (_start.y1 + _start.y2) / 2, 1);
    }
}
