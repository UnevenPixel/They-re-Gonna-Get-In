// Icon + sparkle-square particle -- depth pushed above all depth=-y sorted
// instances; fields are placeholders, SpawnResourceProducedParticles fills
// in the real ones right after. See oResourceProducedParticle.md.
depth = -room_height - 1;

kind          = "square"; // "icon" (shows a sResourceIcons frame) or "square" (flat-color tiny square)
resourceIndex = 0;        // sResourceIcons frame -- only used when kind == "icon"
color         = c_white;  // only used when kind == "square"
squareSize    = 1;        // px -- only used when kind == "square"
vx            = 0;
vy            = 0;
life          = 1;
lifeMax       = 1;
