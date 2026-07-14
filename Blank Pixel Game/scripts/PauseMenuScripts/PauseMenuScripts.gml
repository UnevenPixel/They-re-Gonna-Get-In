// -----------------------------------------------------------
// PauseMenuScripts -- the pause menu. 2026-07-13 request.
//
// Opened via Escape (oUnitControl/Step_0.gml), same basic shape as the
// Fate Engine overlay (FateEngineOverlayScripts.gml): dims the whole screen
// (0.75-alpha black rect) and forces global.matchSpeed to 0, restoring it
// on Resume. Built on the shared drop-down menu sprite set
// (DropDownMenuScripts.gml) -- same title/row/hover rendering every other
// menu in this project uses -- but CENTERED on screen
// (PositionDropDownMenuCentered) rather than click-anchored, since Escape
// has no click position to anchor away from.
//
// Mutually exclusive with the Fate Engine overlay -- oUnitControl/Step_0.gml
// checks fateEngineOverlay.isOpen FIRST and exits before this menu's own
// open-check ever runs, so Escape can't open the pause menu while the Fate
// Engine overlay is up, and (since this menu's own early-exit sits right
// after that check) the XP bar's click-to-open can't open the Fate Engine
// overlay while paused either.
//
// Draw-order deviation from the Fate Engine overlay (worth flagging): the
// Fate Engine overlay's dim is drawn FIRST in Draw_64.gml so it sits BEHIND
// the persistent UI bar (you're still "using" the bar via its XP-bar
// trigger). Pausing is a different kind of interruption -- conceptually you
// leave the play state entirely -- so this menu's dim/panel are drawn LAST
// instead, on top of the UI bar and every other HUD element, covering
// everything. Flagged since the request said "the same black overlay",
// which could be read as "same draw position" rather than "same visual
// style" -- this went with the latter.
//
// Two option lists, matching the request verbatim:
//   Main:    Resume / Restart / Settings / Quit to Desktop / End Match
//   Confirm: Yes / No -- shown instead of the main list after clicking
//            Quit to Desktop or End Match ("make sure that both quit to
//            desktop and end match have a yes or no 'are you sure?' sub
//            menu"). No/click-away/Escape all cancel back to the main list.
//
// Settings is an explicit STUB per the request ("don't wire this one in
// yet, leave it as a stub function") -- OpenSettings() below is
// intentionally empty; clicking that row currently does nothing observable
// (the menu stays open) rather than closing/navigating anywhere.
//
// Restart calls room_restart() -- both oMatchControl and oUnitControl are
// non-persistent (confirmed via their .yy files), so GameMaker fully
// destroys and recreates both on restart, re-running oMatchControl's
// Create_0 event from scratch. That event ALREADY initializes
// global.resources/blueprints/age/ageUpReady/unitsDeployed/armyLimit, the
// starting resource/blueprint loadout, global.matchSpeed, and calls
// AnalyticsInit() -- i.e. everything the request means by "all resources,
// tracking, and match related items reset" -- so no separate manual reset
// function was needed; room_restart() already produces exactly that.
//
// Quit to Desktop and End Match both call game_end() for now, per explicit
// request ("both End match and quit to desktop will just end the game").
// Kept as two separate confirm actions/messages (not merged into one
// button) since the request implies they'll diverge later.
// -----------------------------------------------------------

/// @function PauseMenu()
/// @description The pause menu. Call Open(...) to show it (needs the same
///        cross-controller dependencies FateEngineOverlay.Open() takes, for
///        the same clean-slate reset reasoning -- see that function's doc
///        comment), Update() once per Step while it might be open, and
///        Draw() once per Draw GUI. Not a GM instance -- a plain struct,
///        same pattern as every other controller oUnitControl owns.
function PauseMenu() constructor {
    isOpen          = false;
    savedMatchSpeed = 1;
    x               = 0;
    y               = 0;
    hoveredIndex    = -1;

    // Row order matches the request verbatim.
    mainOptions = ["Resume", "Restart", "Settings", "Quit to Desktop", "End Match"];

    // Confirm sub-menu state -- Update()/Draw() render THIS instead of the
    // main list whenever pendingConfirmAction is set ("quit" | "endMatch").
    pendingConfirmAction = undefined;
    confirmHoveredIndex  = -1;
    confirmOptions       = ["Yes", "No"];

    /// @function Open(_selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController)
    /// @description Opens the pause menu: freezes the match (saves
    ///        global.matchSpeed, sets it to 0) and resets player input state
    ///        to a clean slate -- same reasoning/shape as
    ///        FateEngineOverlay.Open() (FateEngineOverlayScripts.gml): clears
    ///        selection/targeting, closes every dropdown menu, cancels an
    ///        in-progress blueprint drag. No-ops if already open.
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
    /// @description Resumes -- restores global.matchSpeed and closes the
    ///        menu. Same as clicking "Resume" or pressing Escape while the
    ///        main list is showing.
    /// @returns {Struct.PauseMenu} self
    static Close = function() {
        if (!isOpen) return self;
        isOpen               = false;
        pendingConfirmAction = undefined;
        global.matchSpeed    = savedMatchSpeed;
        return self;
    }

    /// @function OpenSettings()
    /// @description STUB -- per explicit request ("don't wire this one in
    ///        yet, leave it as a stub function"). Intentionally empty;
    ///        clicking "Settings" currently does nothing observable.
    static OpenSettings = function() {
        // Intentionally empty -- see file header.
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
    /// @description Backs out of the confirm sub-menu to the main list
    ///        without doing anything -- "No", Escape, or a click that
    ///        misses "Yes" while confirming all route here.
    static CancelConfirm = function() {
        pendingConfirmAction = undefined;

        var _pos = PositionDropDownMenuCentered(array_length(mainOptions));
        x = _pos.x;
        y = _pos.y;
    }

    /// @function DoRestart()
    /// @description Restarts the room -- see file header for why a plain
    ///        room_restart() call is sufficient to reset every match-related
    ///        global (both oMatchControl and oUnitControl are non-
    ///        persistent, so their Create events re-run from scratch).
    static DoRestart = function() {
        isOpen               = false;
        pendingConfirmAction = undefined;
        room_restart();
    }

    /// @function DoQuitOrEndMatch(_action)
    /// @description Both confirm actions resolve here -- per explicit
    ///        request, both just end the game for now. Kept as one function
    ///        (rather than two identical ones) since the only difference
    ///        today is which confirm title was shown; a future pass that
    ///        actually diverges the two behaviors only needs to change this.
    /// @param {String} _action "quit" | "endMatch"
    static DoQuitOrEndMatch = function(_action) {
        game_end();
    }

    /// @function Update()
    /// @description Call once per Step while this menu might be open.
    ///        No-ops entirely if not open.
    static Update = function() {
        if (!isOpen) return;

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
                    // "No", or a click anywhere else -- cancel back to the
                    // main list rather than requiring an exact hit on "No".
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
            // Unlike OrderMenu, a click outside every row does nothing here
            // -- deliberately NOT a dismiss, so an accidental click near the
            // menu's edge can't silently resume the match. Resume/Escape are
            // the only ways to close the main list without picking an option.
            if (hoveredIndex == -1) return;

            switch (hoveredIndex) {
                case 0: Close(); break;                    // Resume
                case 1: DoRestart(); break;                 // Restart
                case 2: OpenSettings(); break;               // Settings (stub)
                case 3: RequestConfirm("quit"); break;       // Quit to Desktop
                case 4: RequestConfirm("endMatch"); break;   // End Match
            }
        }
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event. No-ops if not open. Draws
    ///        the 0.75-alpha full-screen dim, then either the Yes/No confirm
    ///        sub-menu (if pendingConfirmAction is set) or the main option
    ///        list, centered on screen.
    static Draw = function() {
        if (!isOpen) return;

        draw_set_color(c_black);
        draw_set_alpha(0.75);
        draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
        draw_set_alpha(1);

        if (pendingConfirmAction != undefined) {
            var _title = (pendingConfirmAction == "quit") ? "Quit to Desktop?" : "End Match?";
            DrawMenuList(_title, confirmOptions, confirmHoveredIndex);
        } else {
            DrawMenuList("Paused", mainOptions, hoveredIndex);
        }
    }

    /// @function DrawMenuList(_title, _options, _hoveredIndex)
    /// @description Shared row-drawing loop for both the main list and the
    ///        confirm sub-menu -- internal helper for Draw().
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
