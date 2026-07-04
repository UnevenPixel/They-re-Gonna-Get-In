#macro CAMERA_PAN_EDGE_BUFFER 64 // pixels from the screen edge where panning begins
#macro CAMERA_PAN_MAX_SPEED   8  // pixels per frame, reached right at the screen edge (0px away)

/// @function UpdateCameraPan()
/// @description Edge-of-screen camera panning for view camera 0. When the
///        mouse is within CAMERA_PAN_EDGE_BUFFER pixels of the left or right
///        edge of the screen, scrolls the camera horizontally toward that
///        edge. Speed ramps linearly with proximity to the edge -- 0 at the
///        buffer's outer boundary, up to CAMERA_PAN_MAX_SPEED right at the
///        edge -- and the camera is clamped so it never scrolls past the
///        room bounds. Vertical-only rooms (view height == room height, as
///        in rmTestGameplay) have no vertical panning to do, so this is
///        horizontal-only; extend with a matching vertical pass if a future
///        room needs it. Call once per Step from a gameplay-room-scoped
///        controller (currently oUnitControl).
function UpdateCameraPan() {
    var _cam  = view_camera[0];
    var _camX = camera_get_view_x(_cam);
    var _camW = camera_get_view_width(_cam);

    var _mx   = device_mouse_x_to_gui(0);
    var _guiW = display_get_gui_width();

    var _dx = 0;

    if (_mx < CAMERA_PAN_EDGE_BUFFER) {
        // Clamp _t so a cursor that's left the window entirely (negative
        // GUI coords) doesn't push speed past CAMERA_PAN_MAX_SPEED.
        var _t = clamp(1 - (_mx / CAMERA_PAN_EDGE_BUFFER), 0, 1);
        _dx = -CAMERA_PAN_MAX_SPEED * _t;
    } else if (_mx > _guiW - CAMERA_PAN_EDGE_BUFFER) {
        var _distFromEdge = _guiW - _mx;
        var _t = clamp(1 - (_distFromEdge / CAMERA_PAN_EDGE_BUFFER), 0, 1);
        _dx = CAMERA_PAN_MAX_SPEED * _t;
    }

    if (_dx != 0) {
        var _maxX  = max(0, room_width - _camW);
        var _newX  = clamp(_camX + _dx, 0, _maxX);
        camera_set_view_pos(_cam, _newX, camera_get_view_y(_cam));
    }
}
