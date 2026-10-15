// GUI-space right-click order menu. See OrderMenu.md.

/// @function OrderMenu()
/// @description Call Open()/OpenCentered() to show it, Update() once per
///        Step, Draw() once per Draw GUI.
function OrderMenu() constructor {
    isOpen             = false;
    x                  = 0;
    y                  = 0;
    options            = [];   // Array<Struct.Order>
    mnemonicCharIndex  = [];   // Array<Real> -- 1-based char index into options[i].label, or -1 if none available
    hoveredIndex       = -1;

    /// @function AssignMnemonics()
    /// @description (Re)computes mnemonicCharIndex for the current options. Call whenever options is (re)assigned.
    static AssignMnemonics = function() {
        mnemonicCharIndex = array_create(array_length(options), -1);

        var _used = ds_map_create();
        for (var i = 0; i < array_length(options); i++) {
            var _label = options[i].label;
            for (var c = 1; c <= string_length(_label); c++) {
                var _lower = string_lower(string_char_at(_label, c));
                if (_lower >= "a" && _lower <= "z" && !ds_map_exists(_used, _lower)) {
                    ds_map_add(_used, _lower, true);
                    mnemonicCharIndex[i] = c;
                    break;
                }
            }
        }
        ds_map_destroy(_used);
    }

    /// @function Open(_x, _y, _orders)
    /// @description Opens the menu, anchored away from the triggering click.
    /// @param {Real} _x GUI-space X of the triggering click.
    /// @param {Real} _y GUI-space Y of the triggering click.
    /// @param {Array<Struct.Order>} _orders
    /// @returns {Struct.OrderMenu} self
    static Open = function(_x, _y, _orders) {
        if (array_length(_orders) == 0) return self;

        options = _orders;
        isOpen  = true;
        AssignMnemonics();

        var _pos = PositionDropDownMenuFromClick(_x, _y, array_length(options));
        x = _pos.x;
        y = _pos.y;

        return self;
    }

    /// @function OpenCentered(_orders)
    /// @description Opens the menu centered on screen, for callers with no triggering click.
    /// @param {Array<Struct.Order>} _orders
    /// @returns {Struct.OrderMenu} self
    static OpenCentered = function(_orders) {
        if (array_length(_orders) == 0) return self;

        options = _orders;
        isOpen  = true;
        AssignMnemonics();

        var _pos = PositionDropDownMenuCentered(array_length(options));
        x = _pos.x;
        y = _pos.y;

        return self;
    }

    /// @function Close()
    /// @returns {Struct.OrderMenu} self
    static Close = function() {
        isOpen = false;
        options = [];
        mnemonicCharIndex = [];
        hoveredIndex = -1;
        return self;
    }

    /// @function Update()
    /// @description Call once per Step while the menu might be open.
    /// @returns {String|Undefined} name of the order clicked this frame, or
    ///        undefined if nothing was clicked. Caller issues the order.
    static Update = function() {
        if (!isOpen) return undefined;

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        hoveredIndex = DropDownMenuHitTest(x, y, array_length(options), _mx, _my);

        for (var i = 0; i < array_length(options); i++) {
            var _charIndex = mnemonicCharIndex[i];
            if (_charIndex == -1) continue;

            var _letter = string_upper(string_char_at(options[i].label, _charIndex));
            if (keyboard_check_pressed(ord(_letter))) {
                var _hotkeyName = options[i].name;
                Close();
                return _hotkeyName;
            }
        }

        if (mouse_check_button_pressed(mb_left)) {
            var _clickedName = (hoveredIndex >= 0) ? options[hoveredIndex].name : undefined;
            Close();
            return _clickedName;
        }

        if (mouse_check_button_pressed(mb_right)) {
            Close();
        }

        return undefined;
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event while the menu might be open.
    static Draw = function() {
        if (!isOpen) return;

        DrawDropDownMenuTitle(x, y, "Orders");

        var _rowY = y + DropDownMenuTitleHeight();
        for (var i = 0; i < array_length(options); i++) {
            var _isBottom = (i == array_length(options) - 1);
            var _rowH     = DropDownMenuRowHeight(_isBottom);

            DrawDropDownMenuRowBackground(x, _rowY, _isBottom, (i == hoveredIndex));

            draw_set_halign(fa_left);
            draw_set_valign(fa_middle);

            var _label      = options[i].label;
            var _charIndex  = mnemonicCharIndex[i];
            var _textY      = _rowY + (_rowH / 2);
            var _drawX      = DropDownMenuRowContentX(x);

            if (_charIndex == -1) {
                draw_set_color(HOVER_CARD_TEXT_COLOR);
                draw_text(_drawX, _textY, _label);
            } else {
                // Split pre/mnemonic/post so exactly one letter draws in the highlight color.
                var _pre  = string_copy(_label, 1, _charIndex - 1);
                var _char = string_char_at(_label, _charIndex);
                var _post = string_copy(_label, _charIndex + 1, string_length(_label) - _charIndex);

                draw_set_color(HOVER_CARD_TEXT_COLOR);
                draw_text(_drawX, _textY, _pre);
                _drawX += string_width(_pre);

                draw_set_color(c_white);
                draw_text(_drawX, _textY, _char);
                _drawX += string_width(_char);

                draw_set_color(HOVER_CARD_TEXT_COLOR);
                draw_text(_drawX, _textY, _post);
            }

            _rowY += _rowH;
        }
    }
}
