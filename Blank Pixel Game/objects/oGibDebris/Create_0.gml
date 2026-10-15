// Generic flying-then-landing debris (chunks/unique gibs/blood pixels all
// reuse this one object). Placeholders -- SpawnGibDebrisSprite/SpawnBloodPixel
// (GibScripts.gml) fill in the real values right after. See oGibDebris.md.
kind       = "sprite"; // "sprite" (chunk/unique gib, drawn with rotation) or "pixel" (blood particle, flat-color dot)
gibSprite  = -1;       // sprite_index to draw when kind == "sprite"
frame      = 0;        // picked once at spawn -- which frame of gibSprite
angle      = 0;        // current draw rotation, degrees -- frozen at whatever it is the instant this lands
spinSpeed  = 0;         // degrees/step at 1x match speed, kind == "sprite" only
pixelColor = c_white;  // kind == "pixel" only
pixelSize  = 1;         // px, kind == "pixel" only

// Fake-gravity arc physics -- see GibDebrisStep (GibScripts.gml) and
// oGibDebris.md for the full model.
vx = 0;
vy = 0;
z  = 0;
vz = 0;
