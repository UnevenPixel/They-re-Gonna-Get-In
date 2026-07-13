// oGibDebris -- 2026-07-12 request ("set up gibbing"). Generic flying-then-
// landing debris: general chunks, a unit's own unique gib, and single-pixel
// blood particles all reuse this ONE object, just spawned with different
// fields -- see SpawnGibDebrisSprite/SpawnBloodPixel (GibScripts.gml),
// which always set every field below immediately after
// instance_create_layer, same "Create sets placeholders, the spawning
// function fills in the real ones right after" pattern as
// oResourceProducedParticle.
kind       = "sprite"; // "sprite" (chunk/unique gib, drawn with rotation) or "pixel" (blood particle, flat-color dot)
gibSprite  = -1;       // sprite_index to draw when kind == "sprite"
frame      = 0;        // picked once at spawn -- which frame of gibSprite (sGeneralChunks/sGeneralSplatters have several variants, per-unit gibs have just one)
angle      = 0;        // current draw rotation, degrees -- frozen at whatever it is the instant this lands
spinSpeed  = 0;         // degrees/step at 1x match speed, kind == "sprite" only
pixelColor = c_white;  // kind == "pixel" only
pixelSize  = 1;         // px, kind == "pixel" only

// Fake-gravity arc physics -- see GibDebrisStep (GibScripts.gml) for the
// full model: x/y is the real ground position (slides via vx/vy, dragged
// to a stop by GIB_GROUND_FRICTION -- the "flung away from who killed
// them" component), z/vz is a SEPARATE visual-only height (pulled down by
// GIB_GRAVITY -- the "arch" component, drawn as a y-offset, never
// affecting the real ground position). Landing is detected purely off z
// crossing back down through 0 -- see GibDebrisStep.
vx = 0;
vy = 0;
z  = 0;
vz = 0;
