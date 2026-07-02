unitData = new UnitDataBlock();

pos = new Vector2(x,y);
team = TEAM.PLAYER;
wanderWait = true;

guardRect = GetTeamGuardRect(team); // mirrored per-team -- see GetTeamGuardRect in UnitScripts.gml
target = noone;

moveVec = new Vector2(0,0);

fsm = new StateMachine(self);
fsm.AddState("guard",  new State(Guard_Enter,  Guard_Step, Guard_Draw, Guard_Exit))
   .AddState("defend", new State(Defend_Enter, Defend_Step, undefined, Defend_Exit))
   .AddState("combat", new State(Combat_Enter, Combat_Step, undefined, Combat_Exit))
   .AddState("attack", new State(Attack_Enter, Attack_Step, undefined, Attack_Exit))
   .AddState("siege",  new State(Siege_Enter,  Siege_Step,  undefined, Siege_Exit));
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

//Guard
guardWaypointClaimed = undefined;

// Resolves this unit's UnitDefinition (keyed by object_index, so this
// correctly picks up oPeasantUnit/etc. even though it's running as
// oUnitParent's inherited Create code) and applies every static stat --
// must run after fsm/agent/unitData above, and after
// RegisterAllUnitDefinitions() has run at game start.
UnitApplyDefinition(self);