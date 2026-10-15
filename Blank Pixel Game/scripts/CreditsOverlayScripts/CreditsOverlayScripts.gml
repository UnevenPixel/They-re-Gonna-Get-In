// The title screen's Credits sub-menu. See CreditsOverlayScripts.md.

#macro CREDITS_PANEL_WIDTH        680
#macro CREDITS_PANEL_PAD_X        40
#macro CREDITS_PANEL_PAD_TOP      30
#macro CREDITS_PANEL_PAD_BOTTOM   90
#macro CREDITS_PANEL_MIN_HEIGHT   300
#macro CREDITS_PANEL_SCREEN_MARGIN 80
#macro CREDITS_BACK_BUTTON_WIDTH  160
#macro CREDITS_BACK_BUTTON_HEIGHT 44

/// @function CreditsOverlay()
/// @description The title screen's Credits sub-menu. Plain struct, owner
///        calls Update() once per Step and Draw() once per Draw GUI.
function CreditsOverlay() constructor {
    isOpen = false;

    creditsText = scribble(
            "[fntDataCard][c_white]iCon Studio TX LLC\n\n" +
            "[FntDataCardItalics][c_lime]STAFF[c_white][sCreditsIcons, 0]\n" +
            "[FntDataCardItalics][c_white]Conner Powell[sConnorPowellCredit]\n[c_gray]Creative Director\n" +
            "[FntDataCardItalics][c_white]Tony (iabusegfuel)[sTonyCredit]\n[c_gray]Assistant Creative Director\n" +
            "[FntDataCardItalics][c_white]Quinn Buchanan[sQuinnCredit]\n[c_gray]Assistant Marketing Director\n" +
            "[FntDataCardItalics][c_white]Benjamin Brimacombe\n[c_gray]Writer\n" +

            "\n[fntDataCard][c_red]ART[c_white][sCreditsIcons, 1]\n" +
            "[FntDataCardItalics][c_white]Astrid[sAstridCredit]\n[c_gray]Lead Artist\n" +
            "[FntDataCardItalics][c_white]cowcowpixel[sCowCredit]\n[c_gray]Animations Artist\n" +
            "[FntDataCardItalics][c_white]Zoltan \"Zolly\"[sZoltanCredit]\n[c_gray]Environment & UI Artist\n" +
            "\n[fntDataCard][c_blue]PROGRAMMING[c_white][sCreditsIcons, 2]\n" +
            "[FntDataCardItalics][c_white]Uneven Pixel[sUnevenPixelCredit]\n[c_gray]Lead Developer, Project Manager\n" +
            "[FntDataCardItalics][c_white]Liam \"bob\"[sLiamCredit]\n[c_gray]Core Development\n\n" +
            "[sDogsCredits]"
        )
        .align(fa_left, fa_top)
        .wrap(CREDITS_PANEL_WIDTH - (CREDITS_PANEL_PAD_X * 2));

    panelHeight = clamp(
        creditsText.get_height() + CREDITS_PANEL_PAD_TOP + CREDITS_PANEL_PAD_BOTTOM,
        CREDITS_PANEL_MIN_HEIGHT,
        display_get_gui_height() - (CREDITS_PANEL_SCREEN_MARGIN * 2)
    );

    /// @function Open()
    /// @returns {Struct.CreditsOverlay} self
    static Open = function() {
        isOpen = true;
        return self;
    }

    /// @function Close()
    /// @returns {Struct.CreditsOverlay} self
    static Close = function() {
        isOpen = false;
        return self;
    }

    /// @function _PanelRect()
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _PanelRect = function() {
        var _w  = CREDITS_PANEL_WIDTH;
        var _h  = panelHeight;
        var _x1 = (display_get_gui_width()  - _w) / 2;
        var _y1 = (display_get_gui_height() - _h) / 2;
        return { x1: _x1, y1: _y1, x2: _x1 + _w, y2: _y1 + _h };
    }

    /// @function _BackButtonRect()
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _BackButtonRect = function() {
        var _panel = _PanelRect();
        var _x1 = _panel.x1 + (CREDITS_PANEL_WIDTH - CREDITS_BACK_BUTTON_WIDTH) / 2;
        var _y2 = _panel.y2 - 24;
        var _y1 = _y2 - CREDITS_BACK_BUTTON_HEIGHT;
        return { x1: _x1, y1: _y1, x2: _x1 + CREDITS_BACK_BUTTON_WIDTH, y2: _y2 };
    }

    /// @function _PointInRect(_px, _py, _rect)
    /// @param {Real} _px
    /// @param {Real} _py
    /// @param {Struct} _rect { x1, y1, x2, y2 }
    /// @returns {Bool}
    static _PointInRect = function(_px, _py, _rect) {
        return (_px >= _rect.x1 && _px <= _rect.x2 && _py >= _rect.y1 && _py <= _rect.y2);
    }

    /// @function Update()
    /// @description Call once per Step while this overlay might be open.
    /// @returns {Struct.CreditsOverlay} self
    static Update = function() {
        if (!isOpen) return self;

        if (keyboard_check_pressed(vk_escape)) {
            Close();
            return self;
        }

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        if (mouse_check_button_pressed(mb_left) && _PointInRect(_mx, _my, _BackButtonRect())) {
            Close();
            return self;
        }

        return self;
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event.
    static Draw = function() {
        if (!isOpen) return;

        draw_set_color(c_black);
        draw_set_alpha(0.75);
        draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
        draw_set_alpha(1);

        var _panel = _PanelRect();
        draw_set_color(SETTINGS_PANEL_FILL_COLOR);
        draw_rectangle(_panel.x1, _panel.y1, _panel.x2, _panel.y2, false);
        draw_set_color(c_white);
        draw_rectangle(_panel.x1, _panel.y1, _panel.x2, _panel.y2, true);

        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text((_panel.x1 + _panel.x2) / 2, _panel.y1 - 30, "Credits");

        creditsText.draw(_panel.x1 + CREDITS_PANEL_PAD_X, _panel.y1 + CREDITS_PANEL_PAD_TOP);

        var _backRect = _BackButtonRect();
        draw_set_color(SETTINGS_TAB_ACTIVE_COLOR);
        draw_rectangle(_backRect.x1, _backRect.y1, _backRect.x2, _backRect.y2, false);
        draw_set_color(c_white);
        draw_rectangle(_backRect.x1, _backRect.y1, _backRect.x2, _backRect.y2, true);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text((_backRect.x1 + _backRect.x2) / 2, (_backRect.y1 + _backRect.y2) / 2, "Back");

        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    }
}
