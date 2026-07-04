unitData = new UnitDataBlock();

pos = new Vector2(x,y);
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

moveVec = new Vector2(0,0);

fsm = new StateMachine(self);
fsm.AddState("guard",  new State(Guard_Enter,  Guard_Step, Guard_Draw, Guard_Exit))
   .AddState("defend", new State(Defend_Enter, Defend_Step, undefined, Defend_Exit))
   .AddState("combat", new State(Combat_Enter, Combat_Step, undefined, Combat_Exit))
   .AddState("combatRanged", new State(CombatRanged_Enter, CombatRanged_Step, undefined, CombatRanged_Exit)) // ranged counterpart to "combat" -- see UnitStateCombatRanged.gml; dispatched by UnitEnterCombat (UnitCombatHelpers.gml) for "ranged"-tagged units
   .AddState("attack", new State(Attack_Enter, Attack_Step, undefined, Attack_Exit))
   .AddState("attackRanged", new State(AttackRanged_Enter, AttackRanged_Step, undefined, AttackRanged_Exit)) // ranged counterpart to "attack" -- see UnitStateAttackRanged.gml; dispatched by the "attack" order (OrderWiring.gml) for "ranged"-tagged units
   .AddState("siege",  new State(Siege_Enter,  Siege_Step,  undefined, Siege_Exit));
fsm.ChangeState("guard");

agent      = new SteeringAgent(x, y, 1, 0.2, 1); // maxSpeed/maxForce/mass here are placeholders -- UnitApplyDefinition overwrites agent.maxSpeed below
controller = new SteeringControll