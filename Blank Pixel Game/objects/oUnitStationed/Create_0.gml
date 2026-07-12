// oUnitStationed -- a garrisoned unit stored at its team's castle. No
// sprite, no Step, no Draw override (visible=false in the object's own
// properties too, belt-and-suspenders since there's no sprite to draw
// anyway). Holds nothing but team + the UnitDataBlock handed over by
// UnitBecomeStationed (StationScripts.gml) -- see that struct's doc
// comment (UnitScripts.gml) for why this is deliberately the ONLY state
// kept: redeploying later just hands unitData back to a fresh live unit
// and calls UnitApplyDefinition again.
team     = TEAM.PLAYER;
unitData = undefined;
