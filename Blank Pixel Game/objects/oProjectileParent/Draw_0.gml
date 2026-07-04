// Overrides the default sprite draw entirely -- see ProjectileDraw
// (ProjectileScripts.gml) for the arc-offset + arc-following-angle
// rendering. Do not add a plain draw_self() anywhere else on this object;
// it would double-draw.
ProjectileDraw(self);
