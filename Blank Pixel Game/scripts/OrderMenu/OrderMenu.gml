#macro ORDER_MENU_ITEM_HEIGHT 28
#macro ORDER_MENU_WIDTH 140
#macro ORDER_MENU_PADDING 6

function OrderMenu() constructor {
    isOpen       = false;
    x            = 0;
    y            = 0;
    options      = [];   // Array<Struct.Order>
    hoveredIndex = -1;

    /// Opens the menu at a GUI-space position with the given orders.
    /// @param {Real} _x
    /// @param {Real} _y
    /// @param {Array<Struct.Order>} _orders
    /// @return {Struct.OrderMenu} self
    static Open = function(_x, _y, _orders) {
        if (array_length(_orders) == 0) return self; // nothing to show

        x       = _x;
        y       = _y;
        options = _orders;
        isOpen  = true;

        // Keep the menu on-screen if opened near an edge.
        var _w = ORDER_MENU_WIDTH;
        var _h = (array_length(options) * ORDER_MENU_ITEM_HEIGHT) + (ORDER_MENU_PADDING * 2);
        if (x + _w > display_get_gui_width())  x = display_get_gui_width() - _w;
        if (y + _h > display_get_gui_height()) y = display_get_gui_height() - _h;

        return self;
    }

    /// @return {Struct.OrderMenu} self
    static Close = function() {
        isOpen = false;
        options = [];
        hoveredIndex = -1;
        return self;
    }

    /// Call once per Step event while the menu might be open.
    /// @return {String|Undefined} The name of the order clicked this
    ///         frame, or undefined if nothing was clicked. The caller
    ///         is responsible for actually issuing the order (see
    ///         Quick Start in the docs) -- this only reports the click.
    static Update = function() {
        if (!isOpen) return undefined;

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        hoveredIndex = -1;
        var _itemY = y + ORDER_MENU_PADDING;
        for (var i = 0; i < array_length(options); i++) {
            if (_mx >= x && _mx <= x + ORDER_MENU_WIDTH && _my >= _itemY && _my <= _itemY + ORDER_MENU_ITEM_HEIGHT) {
                hoveredIndex = i;
                break;
            }
            _itemY += ORDER_MENU_ITEM_HEIGHT;
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

    /// Call once per Draw GUI event while the menu might be open.
    static Draw = function() {
        if (!isOpen) return;

        var _h = (array_length(options) * ORDER_MENU_ITEM_HEIGHT) + (ORDER_MENU_PADDING * 2);
        draw_rectangle_color(x, y, x + ORDER_MENU_WIDTH, y + _h, c_black, c_black, c_black, c_black, false);
        draw_rectangle_color(x, y, x + ORDER_MENU_WIDTH, y + _h, c_white, c_white, c_white, c_white, true);

        var _itemY = y + ORDER_MENU_PADDING;
        for (var i = 0; i < array_length(options); i++) {
            if (i == hoveredIndex) {
                draw_rectangle_color(
                    x + 2, _itemY, x + ORDER_MENU_WIDTH - 2, _itemY + ORDER_MENU_ITEM_HEIGHT,
                    c_dkgray, c_dkgray, c_dkgray, c_dkgray, false
                );
            }
            draw_set_color(c_white);
            draw_set_halign(fa_left);
            draw_set_valign(fa_middle);
            draw_text(x + ORDER_MENU_PADDING + 4, _itemY + (ORDER_MENU_ITEM_HEIGHT / 2), options[i].label);
            _itemY += ORDER_MENU_ITEM_HEIGHT;
        }
    }
}
