# oUnitStationed

A garrisoned unit stored at its team's castle. No sprite, no Step, no Draw override (`visible=false` in the object's own properties too, belt-and-suspenders since there's no sprite to draw anyway).

Holds nothing but `team` + the `UnitDataBlock` handed over by `UnitBecomeStationed` (`StationScripts.gml`) -- see that struct's doc comment (`UnitScripts.gml`) for why this is deliberately the ONLY state kept: redeploying later just hands `unitData` back to a fresh live unit and calls `UnitApplyDefinition` again.

## Castle roam (2026-10-14, v0.0.7.4)

Stationed units are now visible as a purely cosmetic castle crowd. Logic lives in `StationScripts.gml` (`CastleRoamInit`/`CastleRoamStep`/`CastleRoamDraw`); this object's Step/Draw events just call them. Create sets `visible = true` (no sprite_index, so nothing auto-draws) and `depth = CASTLE_ROAM_DEPTH` (-450): `oCastleManager` (-412) draws wall index 0, `oCastleTopper` (-480) draws index 1, so the crowd sits between them. Init is lazy (first Step) because `UnitBecomeStationed` sets `team` after Create.

- Path: `pth_CastleRoam` (closed rectangle, 4 points), relative to the wall sprite's top-left, NOT its origin. Enemy path is mirrored horizontally (`width - x`). World position derives from the castle instance's x/y minus the wall sprite's origin offsets.
- Starts idle at a random one of the 4 points, random loop direction; alternates walking (120-420 steps) and standing (90-300), 25% chance to reverse on resume. Speed `CASTLE_ROAM_SPEED` scaled by `global.matchSpeed` (freezes when paused).
- Deviation: x/y offset lerps toward a random target within +/-2 px (`CASTLE_ROAM_MAX_DEVIATION`), re-rolled when reached. Read "factor of 2" as 2 px; tune the macro if more was meant.
- Facing (art faces right, `image_xscale` convention): stopped faces room center; walking faces horizontal travel direction, but walking up faces room center; walking straight down keeps current facing.
- Draws `UnitDefinition.smallSprite` (frames per the follow-up below), feet-anchored, enemy recolored via `PaletteSwapDrawSprite` using the unit's normal palette (assumes it matches the small sprite's colors).
- 2026-10-14 follow-up (v0.0.7.5): Step sets `depth` from the unit's Y, lerped across -413 (smallest Y, behind) to -479 (Y >= 500, in front), staying inside the wall-layer band. Walking alternates frames 0/1 every `CASTLE_ROAM_FRAME_STEPS` (12) steps; standing snaps to frame 0. Frame is clamped to the sprite's frame count in case a small sprite has only one.
- Known limits: no collision; visual only (nothing reads roam position).

- 2026-10-14 fix (v0.0.7.6): reversing direction on resume used to set the target to the point BEFORE the last-reached point, so a unit stopped mid-segment cut diagonally across the rectangle, off the walls. Reversal now swaps `roamIndex`/`roamTarget` so it walks back along the segment it was on.
