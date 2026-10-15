// y-sort depth, FSM tick, deferred self-destruct. See oUnitParent.md.
depth = -y;
fsm.Step();

// Runs AFTER fsm.Step() has fully finished this frame -- see .md and
// UnitTryDealDamage's doc comment for why. Self-damage for maxHealth (not
// a raw instance_destroy) so it goes through ApplyDamage's normal lethal
// branch. _source is noone so no team is credited a kill for this.
if (pendingSelfDestruct) {
    pendingSelfDestruct = false;
    if (instance_exists(id)) {
        ApplyDamage(id, maxHealth, noone);
    }
}
