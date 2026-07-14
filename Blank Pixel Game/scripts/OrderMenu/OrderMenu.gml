/// @function OrderMenu()
/// @description A GUI-space right-click order menu. Call Open() to show it with a
///        set of orders, Update() once per Step to handle hover/click/dismiss, and
///        Draw() once per Draw GUI to render it. 2026-07-12: rebuilt on the shared
///        drop-down sprite set (DropDownMenuScripts.gml) -- title "Orders", one
///        row per order, no icons (see that file for the row-background/hit-test/
///        sizing helpers every drop-down menu now shares).
///
/// 2026-07-13 additions (auto-open + mnemonic hotkeys request):
///   - OpenCentered(_orders) -- a second entry point alongside Open(), for
///     callers with no triggering click to anchor away from (see its own
///     doc comment). oUnitControl/Step_0.gml now auto-opens this menu the
///     instant a selection populates via ANY method -- Open() (click-
///     anchored) for a drag-box/single-unit click via EndDrag, OpenCentered()
///     for everything else (Army Limit Widget's SelectAllOfType,
///     SelectionSummaryMenu's row-narrow click) -- per the request's literal
///     "if selected through dragging or clicking on the individual unit,
///     open it with the same anchoring rules it normally uses, otherwise
///     open it in the center of the screen."
///   - Mnemonic hotkeys -- one letter per row (prefer the label's own first
///     letter; if an earlier row in THIS menu already claimed it, the next
///     unclaimed letter in the label is used instead), assigned fresh every
///     time options changes (AssignMnemonics, below) since which orders
///     appear varies with the current selection. Checked this project's
///     bundled Scribble build (__scribble_gen_2_parser.gml's
///     _command_tag_lookup_accelerator_map) for an underline tag -- it has
///     none (only font/colour/alpha/scale/alignment/b/i/bi/etc, no "u") --
///     so per the request's explicit fallback ("If not, recolor that letter
///     in white"), the mnemonic letter is recolored c_white instead of
///     underlined. The hotkey itself (Update()) acts exactly like clicking
///     that row, regardless of which visual treatment is used.
function OrderMenu() constructor {
    isOpen             = false;
    x                  = 0;
    y                  = 0;
    options            = [];   // Array<Struct.Order>
    mnemonicCharIndex  = [];   // Array<Real> -- 1-based char index into options[i].label, or -1 if none available
    hoveredIndex       = -1;

    /// @function AssignMnemonics()
    /// @description Internal helper -- (re)computes mnemonicCharIndex for
    ///        the current `options`. Walks each order's label left to right
    ///        and claims the first letter not already claimed by an earlier
    ///        order in this same menu instance; -1 for a row whose entire
    ///        label is exhausted with nothing free (should never happen
    ///        with today's max-5-order menus and 26 letters, but guarded
    ///        rather than assumed). Call anytime `options` is (re)assigned.
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
    /// Opens the menu, anchored away from the triggering click at (_x, _y)
    /// -- 2026-07-13 request: matches the same mouse-dependent, quadrant-
    /// anchor-away-from-cursor logic every hover card already uses, via
    /// PositionDropDownMenuFromClick (DropDownMenuScripts.gml) -- see that
    /// function's own doc comment for the full reasoning. Previously this
    /// opened flush at (_x, _y) with only a far-edge overflow clamp; that
    /// behavior is superseded by this pass.
    /// @param {Real} _x GUI-space X of the triggering click.
    /// @param {Real} _y GUI-space Y of the triggering click.
    /// @param {Array<Struct.Order>} _orders
    /// @returns {Struct.OrderMenu} self
    static Open = function(_x, _y, _orders) {
        if (array_length(_orders) == 0) return self; // nothing to show

        options = _orders;
        isOpen  = true;
        AssignMnemonics();

        var _pos = PositionDropDownMenuFromClick(_x, _y, array_length(options));
        x = _pos.x;
        y = _pos.y;

        return self;
    }

    /// @function OpenCentered(_orders)
    /// @description Opens the menu centered on screen -- 2026-07-13 request,
    ///        for the auto-open-on-selection paths that have no triggering
    ///        click to anchor away from (SelectAllOfType via the Army Limit
    ///        Widget, SelectionSummaryMenu's row-narrow click). Same shape
    ///        as Open() otherwise (mnemonic assignment, empty-orders no-op).
    /// @param {Array<Struct.Order>} _orders
    /// @returns {Struct.OrderMenu} self
    static OpenCentered = function(_orders) {
        if (array_length(_orders) == 0) return self; // nothing to show

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
    /// Call once per Step event while the menu might be open.
    /// @returns {String|Undefined} The name of the order clicked this
    ///         frame, or undefined if nothing was clicked. The caller
    ///         is responsible for actually issuing the order (see
    ///         Quick Start in the docs) -- this only reports the click.
    static Update = function() {
        if (!isOpen) return undefined;

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        hoveredIndex = DropDownMenuHitTest(x, y, array_length(options), _mx, _my);

        // 2026-07-13 request: a mnemonic hotkey acts exactly like clicking
        // its row -- checked before the mouse handling below so a hotkey
        // press this frame can't also fall through to anything else reading
        // mouse state. -1 means that row has no assigned letter (see
        // AssignMnemonics) and is simply skipped.
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
            return _clickedName; // undefined if the click was outside every item -- treat as dismiss
        }

        if (mouse_check_button_pressed(mb_right)) {
            Close(); // right-click anywhere dismisses without issuing anything
        }

        return undefined;
    }

    /// @function Draw()
    /// Call once per Draw GUI event while the menu might be open.
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
                // 2026-07-11 request: matches HOVER_CARD_TEXT_COLOR
                // (HoverCardScripts.gml) -- was c_white.
                draw_set_color(HOVER_CARD_TEXT_COLOR);
                draw_text(_drawX, _textY, _label);
            } else {
                // Split the label into pre-mnemonic / mnemonic / post-mnemonic
                // so exactly one letter draws in the highlight color -- see
                // this file's header for why recolor rather than underline.
                var _pre  = string_copy(_label, 1, _charIndex - 1);
                var _char = string_char_at(_label, _charIndex);
                var _post = string_copy(_label, _charIndex + 1, string_length(_label) - _charIndex);

                draw_set_color(HOVER_CARD_TEXT_COLOR);
                draw_text(_drawX, _textY, _pre);
                _drawX += string_width(_pre);

                draw_set_color(c_white); // mnemonic highlight
                draw_text(_drawX, _textY, _char);
                _drawX += string_width(_char);

                draw_set_color(HOVER_CARD_TEXT_COLOR);
                draw_text(_drawX, _textY, _post);
            }

            _rowY += _rowH;
        }
    }
}
