// Base unit setup -- FSM registration (LOAD-BEARING, see oUnitParent.md),
// steering agent, live combat state. Per-type stats applied at the bottom
// via UnitApplyDefinition.
unitData = new UnitDataBlock();

team = TEAM.PLAYER;
wanderWait = true;

// HAZARD, LOAD-BEARING: guardRect is derived from `team` AT THIS MOMENT
// (always the TEAM.PLAYER default -- Create runs synchronously before a
// caller can override team). Any spawn path that overrides team afterward
// MUST also recompute `guardRect = GetTeamGuardRect(team);` -- see
// TrainingSpawnUnit for the pattern, and oUnitParent.md for the full hazard.
guardRect = GetTeamGuardRect(team); // mirrored per-team -- see GetTeamGuardRect in UnitScripts.gml
target = noone;

fsm = new StateMachine(self);
fsm.AddState("guard",  new State(Guard_Enter,  Guard_Step, Guard_Draw, Guard_Exit))
   .AddState("defend", new State(Defend_Enter, Defend_Step, undefined, Defend_Exit))
   .AddState("combat", new State(Combat_Enter, Combat_Step, undefined, Combat_Exit))
   .AddState("combatRanged", new State(CombatRanged_Enter, CombatRanged_Step, undefined, CombatRanged_Exit)) // ranged counterpart to "combat" -- see UnitStateCombatRanged.gml
   .AddState("attack", new State(Attack_Enter, Attack_Step, undefined, Attack_Exit))
   .AddState("attackRanged", new State(AttackRanged_Enter, AttackRanged_Step, undefined, AttackRanged_Exit)) // ranged counterpart to "attack" -- see UnitStateAttackRanged.gml
   .AddState("siege",  new State(Siege_Enter,  Siege_Step,  undefined, Siege_Exit))
   .AddState("station", new State(Station_Enter, Station_Step, undefined, undefined)); // see UnitStateStation.gml
fsm.ChangeState("guard");

agent      = new SteeringAgent(x, y, 1, 0.2, 1); // maxSpeed/maxForce/mass here are placeholders -- UnitApplyDefinition overwrites agent.maxSpeed below
controller = new SteeringController(agent);

// Live/runtime combat state only -- base stats come from UnitDefinition,
// see UnitApplyDefinition() at the bottom of this event.
combatTarget      = noone;
attackCooldown    = 0;

//Attacking Buildings
attackBuildingTarget = noone;

// Generic on every unit (cheap bool) so UnitTryDealDamage can set it
// unconditionally without a variable_instance_exists guard. Consumed (and
// reset) in Step_0.gml AFTER fsm.Step() -- see .md and UnitTryDealDamage's
// doc comment.
pendingSelfDestruct = false;

// guardWaypointClaimed is intentionally NOT initialized here -- LOAD-
// BEARING, do not re-add an assignment here. See oUnitParent.md.

// Resolves this unit's UnitDefinition (keyed by object_index) and applies
// every static stat -- must run after fsm/agent/unitData above, and after
// RegisterAllUnitDefinitions() has run at game start.
UnitApplyDefinition(self);
