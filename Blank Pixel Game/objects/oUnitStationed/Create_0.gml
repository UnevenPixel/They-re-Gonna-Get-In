// A garrisoned unit -- team + UnitDataBlock, plus a cosmetic castle roam. See oUnitStationed.md.
team     = TEAM.PLAYER;
unitData = undefined;

visible   = true; // needed for the Draw event; no sprite_index so nothing auto-draws
depth     = CASTLE_ROAM_DEPTH;
roamReady = false; // CastleRoamStep initializes the rest lazily on first Step, once team is set
