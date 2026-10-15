// Persistent room-space gib-accumulation surface, drawn below every
// y-sorted unit/building. See oGibSurfaceControl.md.
global.gibSurface = surface_create(room_width, room_height);
depth = room_height + 1;
