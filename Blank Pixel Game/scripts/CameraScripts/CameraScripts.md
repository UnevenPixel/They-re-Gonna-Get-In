# CameraScripts

## UpdateCameraPan

Edge-of-screen camera panning for view camera 0. When the mouse is within `CAMERA_PAN_EDGE_BUFFER` pixels of the left or right edge of the screen, scrolls the camera horizontally toward that edge. Speed ramps linearly with proximity to the edge -- 0 at the buffer's outer boundary, up to `CAMERA_PAN_MAX_SPEED` right at the edge -- and the camera is clamped so it never scrolls past the room bounds. `_t` is clamped so a cursor that's left the window entirely (negative GUI coords) doesn't push speed past `CAMERA_PAN_MAX_SPEED`.

Vertical-only rooms (view height == room height, as in `rmTestGameplay`) have no vertical panning to do, so this is horizontal-only -- extend with a matching vertical pass if a future room needs it. Call once per Step from a gameplay-room-scoped controller (currently `oUnitControl`).

## WorldToGui

Converts a room-space (world) coordinate to its current on-screen GUI-space equivalent, accounting for view camera 0's current pan position and any view/GUI size mismatch -- the standard room->GUI conversion formula. Needed for room-space elements that must be drawn from a Draw GUI event so they render above every room-space Draw call regardless of instance depth (Draw GUI always runs after every room-layer Draw event) -- 2026-07-11 request; first user is a training building's queue progress bar (`TrainingScripts.gml`'s `DrawTrainingQueueBars`).

## API

- `CAMERA_PAN_EDGE_BUFFER`, `CAMERA_PAN_MAX_SPEED`, `UpdateCameraPan()`.
- `WorldToGui(_x, _y)`.
