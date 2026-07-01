unitData = new UnitDataBlock();

pos = new Vector2(x,y);
maxSpeed = 1;
team = "player";
wanderWait = true;

guardRect = new ShapeRect(328,8,480,400);
target = noone;

moveVec = new Vector2(0,0);

fsm = new StateMachine(self);
fsm.AddState("guard",  new State(Guard_Enter,  Guard_Step, Guard_Draw, Guard_Exit))
   .AddState("defend", new State(Defend_Enter, Defend_Step, undefined, Defend_Exit))
   .AddState("combat", new State(Combat_Enter, Combat_Step, undefined, Combat_Exit))
   .AddState("attack", new State(Combat_Enter, Combat_Step, undefined, Combat_Exit))
   .AddState("siege",  new State(Combat_Enter, Combat_Step, undefined, Combat_Exit));
fsm.ChangeState("guard");

agent      = new SteeringAgent(x, y, 1, 0.2, 1);
controller = new SteeringController(agent);

availableOrders = ["guard", "defend", "attack", "siege", "station"];

//Combat
combatTarget      = noone;
attackRange       = 32;
attackLeashRange  = 320;
attackHitFrame    = 3;
attackCooldown    = 0;
attackCooldownMax = 60;
sprIdle           = sM_UnitMask;   // your actual sprite assets
sprAttack         = sM_UnitMask;
sprWalk           = sM_UnitMask;

//Attacking Buildings
attackBuildingTarget = noone;
attackAggroRadius    = 96;

//Siege
siegeSweepRadius   = 160;  // proactive guard search radius during advance

//Guard
guardWaypointClaimed = undefined;