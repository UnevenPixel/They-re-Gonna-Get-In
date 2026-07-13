unitData = new UnitDataBlock();

team = TEAM.PLAYER;
wanderWait = true;

// HAZARD for any future spawn path that creates a unit then overrides
// `team` afterward (e.g. TrainingSpawnUnit in TrainingScripts.gml, and
// eventually whatever redeploys a stationed unit back out through the
// castle gate): guardRect below is derived from `team` AT THIS MOMENT,
// which is always the TEAM.PLAYER default the instant Create runs --
// instance_create_layer() runs Create synchronously, before the caller
// gets a chance to set team to anything else. If you override team after
// creation, also recompute `guardRect = GetTeamGuardRect(team);`
// afterward (see TrainingSpawnUnit for the pattern), and make sure
// nothing team-dependent (a guard waypoint, a patrol side) gets picked
// before that correction lands.
guardRect = GetTeamGuardRect(team); // mirrored per-team -- see GetTeamGuardRect in UnitScripts.gml
target = noone;

fsm = new StateMachine(self);
fsm.AddState("guard",  new State(Guard_Enter,  Guard_Step, Guard_Draw, Guard_Exit))
   .AddState("defend", new State(Defend_Enter, Defend_Step, undefined, Defend_Exit))
   .AddState("combat", new State(Combat_Enter, Combat_Step, undefined, Combat_Exit))
   .AddState("combatRanged", new State(CombatRanged_Enter, CombatRanged_Step, undefined, CombatRanged_Exit)) // ranged counterpart to "combat" -- see UnitStateCombatRanged.gml; dispatched by UnitEnterCombat (UnitCombatHelpers.gml) for "ranged"-tagged units
   .AddState("attack", new State(Attack_Enter, Attack_Step, undefined, Attack_Exit))
   .AddState("attackRanged", new State(AttackRanged_Enter, AttackRanged_Step, undefined, AttackRanged_Exit)) // ranged counterpart to "attack" -- see UnitStateAttackRanged.gml; dispatched by the "attack" order (OrderWiring.gml) for "ranged"-tagged units
   .AddState("siege",  new State(Siege_Enter,  Siege_Step,  undefined, Siege_Exit))
   .AddState("station", new State(Station_Enter, Station_Step, undefined, undefined)); // walks to the unit's own castle then hands off to UnitBecomeStationed (StationScripts.gml) -- see UnitStateStation.gml; dispatched by the "station" order (OrderWiring.gml)
fsm.ChangeState("guard");

agent      = new SteeringAgent(x, y, 1, 0.2, 1); // maxSpeed/maxForce/mass here are placeholders -- UnitApplyDefinition overwrites agent.maxSpeed below
controller = new SteeringController(agent);

// Live/runtime combat state only. Base stats (attackRange, attackDamage,
// attackCooldownMax, sprites, availableOrders, etc.) now come from this
// unit's UnitDefinition -- see UnitApplyDefinition() at the bottom of this
// event, and scripts/UnitDefinitions.
combatTarget      = noone;
attackCooldown    = 0;

//Attacking Buildings
attackBuildingTarget = noone;

// 2026-07-12 request ("update the bomb goblin to die when it explodes") --
// generic on every unit (cheap bool, harmless default) rather than a Bomb-
// Goblin-only field, so UnitTryDealDamage (UnitCombatHelpers.gml) can set
// it unconditionally without a variable_instance_exists guard. Consumed
// (and reset) in Step_0.gml AFTER fsm.Step() -- see that file and
// UnitTryDealDamage's doc comment for why it can't be acted on
// synchronously the instant it's set.
pendingSelfDestruct = false;

// guardWaypointClaimed is intentionally NOT initialized here -- Guard_Enter
// (UnitStateGuard.gml) already sets it the moment fsm.ChangeState("guard")
// runs above, and Guard_Step/Guard_Exit own it from there. A stray
// `guardWaypointClaimed = undefined;` used to sit here and clobber that
// value right after Guard_Enter set it, which is what caused a real crash
// (a sibling unit's clobbered `undefined` claim got read as a Vector2 by
// another unit's GuardPickWaypoint). Don't re-add an assignment here.

// Resolves this unit's UnitDefinition (keyed by object_index, so this
// correctly picks up oPeasantUnit/etc. even though it's running as
// oUnitParent's inherited Create code) and applies every static stat --
// must run after fsm/agent/unitData above, and after
// RegisterAllUnitDefinitions() has run at game start.
UnitApplyDefinition(self);