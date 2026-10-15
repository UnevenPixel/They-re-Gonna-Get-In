// The pause menu (Escape). See PauseMenuScripts.md.

/// @function PauseMenu(_settingsOverlay)
/// @description The pause menu. Plain struct -- call Open(...), Update()
///        once per Step, Draw() once per Draw GUI.
/// @param {Struct.SettingsOverlay} _settingsOverlay Shared settings sub-menu instance.
function PauseMenu(_settingsOverlay) constructor {
    isOpen          = false;
    savedMatchSpeed = 1;
    x               = 0;
    y               = 0;
    hoveredIndex    = -1;
    settingsOverlay = _settingsOverlay;

    mainOptions = ["Resume", "Restart", "Settings", "Quit to Desktop", "End Match"];

    pendingConfirmAction = undefined; // "quit" | "endMatch" | undefined -- when set, Update()/Draw() show the confirm sub-menu instead of mainOptions
    confirmHoveredIndex  = -1;
    confirmOptions       = ["Yes", "No"];

    /// @function Open(_selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController)
    /// @description Opens the pause menu: freezes the match and resets
    ///        player input state to a clean slate. No-ops if already open.
    /// @param {Struct.SelectionController} _selectionController
    /// @param {Struct.OrderMenu} _orderMenu
    /// @param {Struct.CastleGarrisonMenu} _castleGarrisonMenu
    /// @param {Struct.ArmyLimitMenu} _armyLimitMenu
    /// @param {Struct.BlueprintController} _blueprintController
    /// @returns {Struct.PauseMenu} self
    static Open = function(_selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController) {
        if (isOpen) return self;

        isOpen               = true;
        pendingConfirmAction = undefined;
        savedMatchSpeed      = global.matchSpeed;
        global.matchSpeed    = 0;

        _selectionController.Deselect();
        _orderMenu.Close();
        _castleGarrisonMenu.Close();
        _armyLimitMenu.Close();
        if (_blueprintController.dragging) _blueprintController.CancelDrag();

        var _pos = PositionDropDownMenuCentered(array_length(mainOptions));
        x = _pos.x;
        y = _pos.y;

        return self;
    }

    /// @function Close()
    /// @description Resumes -- restores global.matchSpeed and closes the menu.
    /// @returns {Struct.PauseMenu} self
    static Close = function() {
        if (!isOpen) return self;
        isOpen               = false;
        pendingConfirmAction = undefined;
        global.matchSpeed    = savedMatchSpeed;
        return self;
    }

    /// @function OpenSettings()
    /// @description Opens the shared SettingsOverlay sub-menu.
    static OpenSettings = function() {
        settingsOverlay.Open();
    }

    /// @function RequestConfirm(_action)
    /// @description Swaps the main list out for the Yes/No confirm sub-menu.
    /// @param {String} _action "quit" | "endMatch"
    static RequestConfirm = function(_action) {
        pendingConfirmAction = _action;
        confirmHoveredIndex  = -1;

        var _pos = PositionDropDownMenuCentered(array_length(confirmOptions));
        x = _pos.x;
        y = _pos.y;
    }

    /// @function CancelConfirm()
    /// @description Backs out of the confirm sub-menu to the main list.
    static CancelConfirm = function() {
        pendingConfirmAction = undefined;

        var _pos = PositionDropDownMenuCentered(array_length(mainOptions));
        x = _pos.x;
        y = _pos.y;
    }

    /// @function DoRestart()
    /// @description Restarts the room.
    static DoRestart = function() {
        isOpen               = false;
        pendingConfirmAction = undefined;
        room_restart();
    }

    /// @function DoQuitOrEndMatch(_action)
    /// @description Both confirm actions resolve here. "quit" ends the game;
    ///        "endMatch" instead returns to the hub town. Either way, ending
    ///        a match this way marks the tutorial complete if it wasn't
    ///        already -- see .md.
    /// @param {String} _action "quit" | "endMatch"
    static DoQuitOrEndMatch = function(_action) {
        CompleteTutorial(); // no-op if already completed -- both actions leave the run, see .md

        if (_action == "endMatch") {
            room_goto(rmHubTown);
        } else {
            game_end();
        }
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

        if (pendingConfirmAction != undefined) {
            confirmHoveredIndex = DropDownMenuHitTest(x, y, array_length(confirmOptions), _mx, _my);

            if (keyboard_check_pressed(vk_escape)) {
                CancelConfirm();
                return;
            }

            if (mouse_check_button_pressed(mb_left)) {
                if (confirmHoveredIndex == 0) { // "Yes"
                    var _action = pendingConfirmAction;
                    pendingConfirmAction = undefined;
                    DoQuitOrEndMatch(_action);
                } else {
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
            if (hoveredIndex == -1) return; // deliberately not a dismiss -- Resume/Escape only

            switch (hoveredIndex) {
                case 0: Close(); break;
                case 1: DoRestart(); break;
                case 2: OpenSettings(); break;
                case 3: RequestConfirm("quit"); break;
                case 4: RequestConfirm("endMatch"); break;
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

        if (pendingConfirmAction != undefined) {
            var _title = (pendingConfirmAction == "quit") ? "Quit to Desktop?" : "End Match?";
            DrawMenuList(_title, confirmOptions, confirmHoveredIndex);
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
