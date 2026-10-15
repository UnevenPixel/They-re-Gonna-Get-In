// A lightweight Escape pause menu for non-gameplay screens (hub town,
// pre-run, and future hub-town-adjacent screens). See HubPauseMenuScripts.md.

/// @function HubPauseMenu(_settingsOverlay)
/// @description The non-gameplay pause menu. Plain struct -- call Open(),
///        Update() once per Step, Draw() once per Draw GUI.
/// @param {Struct.SettingsOverlay} _settingsOverlay Shared settings sub-menu instance.
function HubPauseMenu(_settingsOverlay) constructor {
    isOpen          = false;
    x               = 0;
    y               = 0;
    hoveredIndex    = -1;
    settingsOverlay = _settingsOverlay;

    mainOptions = ["Options", "Return to Desktop", "Return to Title Menu"];

    pendingConfirm      = false; // true while showing the "Return to Desktop?" Yes/No sub-menu
    confirmHoveredIndex = -1;
    confirmOptions      = ["Yes", "No"];

    /// @function Open()
    /// @description Opens the menu, centered on screen. No-ops if already open.
    /// @returns {Struct.HubPauseMenu} self
    static Open = function() {
        if (isOpen) return self;
        isOpen         = true;
        pendingConfirm = false;

        var _pos = PositionDropDownMenuCentered(array_length(mainOptions));
        x = _pos.x;
        y = _pos.y;

        return self;
    }

    /// @function Close()
    /// @returns {Struct.HubPauseMenu} self
    static Close = function() {
        isOpen         = false;
        pendingConfirm = false;
        return self;
    }

    /// @function OpenSettings()
    /// @description Opens the shared SettingsOverlay sub-menu.
    static OpenSettings = function() {
        settingsOverlay.Open();
    }

    /// @function RequestConfirm()
    /// @description Swaps the main list out for the "Return to Desktop?" Yes/No sub-menu.
    static RequestConfirm = function() {
        pendingConfirm      = true;
        confirmHoveredIndex = -1;

        var _pos = PositionDropDownMenuCentered(array_length(confirmOptions));
        x = _pos.x;
        y = _pos.y;
    }

    /// @function CancelConfirm()
    /// @description Backs out of the confirm sub-menu to the main list.
    static CancelConfirm = function() {
        pendingConfirm = false;

        var _pos = PositionDropDownMenuCentered(array_length(mainOptions));
        x = _pos.x;
        y = _pos.y;
    }

    /// @function _MenuRect()
    /// @description Full on-screen rect (title bar + every row) -- used for
    ///        the click-outside-closes check. See .md.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _MenuRect = function() {
        var _w = DropDownMenuWidth();
        var _h = DropDownMenuTotalHeight(array_length(mainOptions));
        return { x1: x, y1: y, x2: x + _w, y2: y + _h };
    }

    /// @function Update()
    /// @description Call once per Step while this menu might be open.
    static Update = function() {
        if (!isOpen) return;

        if (settingsOverlay.isOpen) {
            settingsOverlay.Update();
            return;
        }

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        if (pendingConfirm) {
            confirmHoveredIndex = DropDownMenuHitTest(x, y, array_length(confirmOptions), _mx, _my);

            if (keyboard_check_pressed(vk_escape)) {
                CancelConfirm();
                return;
            }

            if (mouse_check_button_pressed(mb_left)) {
                if (confirmHoveredIndex == 0) { // "Yes"
                    pendingConfirm = false;
                    game_end();
                } else {
                    // "No" OR a miss click anywhere else -- cancels back to
                    // the main list, same as PauseMenuScripts.gml's confirm
                    // sub-menu. Deliberately NOT the click-outside-CLOSES
                    // behavior the main list uses -- see .md.
                    CancelConfirm();
                }
            }
            return;
        }

        hoveredIndex = DropDownMenuHitTest(x, y, array_length(mainOptions), _mx, _my);

        if (keyboard_check_pressed(vk_escape)) {
            Close();
            return;
        }

        if (mouse_check_button_pressed(mb_left)) {
            if (hoveredIndex != -1) {
                switch (hoveredIndex) {
                    case 0: OpenSettings(); break;
                    case 1: RequestConfirm(); break;
                    case 2: room_goto(rmTitleMenu); break;
                }
                return;
            }

            // Click missed every row -- close only if it's ALSO outside the
            // menu's own bounds (title bar included). A click on the title
            // bar itself is a no-op, not a dismiss. See .md.
            var _rect = _MenuRect();
            if (_mx < _rect.x1 || _mx > _rect.x2 || _my < _rect.y1 || _my > _rect.y2) {
                Close();
            }
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

        if (settingsOverlay.isOpen) {
            settingsOverlay.Draw();
            return;
        }

        if (pendingConfirm) {
            DrawMenuList("Return to Desktop?", confirmOptions, confirmHoveredIndex);
        } else {
            DrawMenuList("Paused", mainOptions, hoveredIndex);
        }
    }

    /// @function DrawMenuList(_title, _options, _hoveredIndex)
    /// @description Shared row-drawing loop for both the main list and the confirm sub-menu.
    /// @param {String} _title
    /// @param {Array<String>} _options
    /// @param {Real} _hoveredIndex
    static DrawMenuList = function(_title, _options, _hoveredIndex) {
        DrawDropDownMenuTitle(x, y, _title);

        var _rowY = y + DropDownMenuTitleHeight();
        for (var i = 0; i < array_length(_options); i++) {
            var _isBottom = (i == array_length(_options) - 1);
            var _rowH     = DropDownMenuRowHeight(_isBottom);

            DrawDropDownMenuRowBackground(x, _rowY, _isBottom, (i == _hoveredIndex));

            draw_set_color(HOVER_CARD_TEXT_COLOR);
            draw_set_halign(fa_left);
            draw_set_valign(fa_middle);
            draw_text(DropDownMenuRowContentX(x), _rowY + (_rowH / 2), _options[i]);

            _rowY += _rowH;
        }
    }
}
