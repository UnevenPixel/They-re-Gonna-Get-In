depth = -y;
fsm.Step();

// 2026-07-12 -- see UnitTryDealDamage (UnitCombatHelpers.gml)'s doc comment
// for why this runs here (after fsm.Step() has fully finished this frame)
// instead of destroying the unit synchronously the instant its swing lands.
// Self-damage for maxHealth (not a raw instance_destroy) so it goes through
// ApplyDamage's normal lethal branch -- SpawnUnitDeathGibs, Strategic XP for
// the losing team, analytics -- same bookkeeping as any other death, just
// self-inflicted. _source is noone, not id, so no team is credited Combat
// XP for "killing" its own unit.
if (pendingSelfDestruct) {
    pendingSelfDestruct = false;
    if (instance_exists(id)) {
        ApplyDamage(id, maxHealth, noone);
    }
}