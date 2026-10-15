# SteeringBehaviors

Craig Reynolds-style vector steering (context steering was tried earlier in this project and replaced). `SteeringAgent` holds physical state (one per unit); `SteeringController` accumulates weighted forces from `Steering_*` functions and applies them each frame; the `Steering_*` functions themselves are stateless force calculators.

## SteeringAgent

Knockback is a separate impulse channel, not a steering force -- it bypasses `maxSpeed` (a hit should be able to move a unit faster than its own legs can) and is applied additively in `SteeringController.Apply()` rather than via `Add()`. `ApplyKnockback` stacks additively with any existing knockback rather than overwriting it, so a second hit during recovery compounds instead of resetting.

`Brake()` decays velocity toward zero -- call every step a unit is meant to be standing still. "Add no steering force" is NOT the same as "come to a stop": every `Steering_*` behavior naturally decelerates because it computes desired-minus-velocity, but skipping all of them just leaves velocity exactly as it was, forever, with nothing opposing it. Uses `power(friction, global.matchSpeed)` so decay scales with match speed the same way knockback does (friction^1 at 1x, friction^0 == 1/no decay while paused).

`SyncToInstance`/`SyncFromInstance` bridge `agent.pos` and GML's built-in `x`/`y`. Call `SyncFromInstance` after `move_and_collide()` resolves a move, since that function writes directly to the instance's x/y, not to `agent.pos`.

## SteeringController

`staggerThreshold`/`staggerSteeringScale`: while `agent.knockback`'s length is above the threshold, steering forces are scaled DOWN (not zeroed) -- a unit staggering from a hit still weakly fights to recover, it doesn't go fully limp.

`Apply()` truncates the accumulated force, integrates velocity, applies + decays knockback, but does NOT move `agent.pos` -- it returns the frame's total movement delta instead, so the calling instance can run it through `move_and_collide()` before committing the move. (Struct methods can't call `move_and_collide` themselves -- it reads/writes the CALLING INSTANCE's x/y and mask, and `self` inside a struct method is the struct, not an instance.)

Scaled by `global.matchSpeed` at the very end, deliberately AFTER `agent.velocity` is integrated/clamped -- `agent.velocity` itself always represents "speed at 1x", so everything that reads it elsewhere (`Speed()`, `Heading()`, `UnitUpdateSprite`'s walk/idle thresholds, `Steering_AvoidObstacles`' feeler-length scaling) stays internally consistent no matter the match speed. Only the actual pixel displacement returned here speeds up/slows down/freezes. `global.matchSpeed == 0` makes the delta `(0,0)` -- a full movement freeze, exactly what pausing needs.

## Behaviors

Core: `Steering_Seek`, `Steering_Flee` (zero force outside `_radius`), `Steering_Arrive` (seek with a deceleration zone), `Steering_Pursue`/`Steering_Evade` (seek/flee a predicted future position, lookahead scales with distance/maxSpeed), `Steering_Wander` (smooth random drift via a jittered virtual circle projected ahead of the unit; persistent state lives on the controller, not the unit).

Spatial/social (all take a `_neighbors` array of `SteeringAgent` structs): `Steering_Separation` (push away from close neighbors, inverse-distance weighted), `Steering_Alignment` (match average neighbor velocity), `Steering_Cohesion` (steer toward neighbor center of mass), `Steering_Flock` (convenience wrapper combining all three with tunable weights).

Obstacle avoidance: `Steering_AvoidObstacles` projects a lookahead "feeler" scaled by current speed, finds whichever obstacle most intersects it (not just the nearest -- the nearest might not actually be in the unit's path, via a lateral-distance check), and steers perpendicular away from it, with urgency scaled by proximity.

Boundary containment: `Steering_Contain` is a soft boundary -- seeks back toward the rect's center as the unit approaches an edge within `_margin`, zero force when comfortably inside.

## API

- `SteeringAgent(_x, _y, _maxSpeed, _maxForce, _mass)` -- `Speed()`, `Heading()`, `ApplyKnockback(_force)`, `IsStaggered(_threshold)`, `Brake(_friction)`, `SyncToInstance(_inst)`, `SyncFromInstance(_inst)`.
- `SteeringController(_agent)` -- `Begin()`, `Add(_force, _weight)`, `Apply()`.
- `Steering_Seek(_agent, _target)`, `Steering_Flee(_agent, _from, _radius)`, `Steering_Arrive(_agent, _target, _slowRadius)`, `Steering_Pursue(_agent, _targetPos, _targetVelocity)`, `Steering_Evade(_agent, _threatPos, _threatVelocity, _radius)`, `Steering_Wander(_agent, _ctrl, _circleDistance, _circleRadius, _jitterDeg)`.
- `Steering_Separation(_agent, _neighbors, _separationRadius)`, `Steering_Alignment(_agent, _neighbors, _alignRadius)`, `Steering_Cohesion(_agent, _neighbors, _cohesionRadius)`, `Steering_Flock(_agent, _neighbors, ...)`.
- `Steering_AvoidObstacles(_agent, _obstacles, _feelerLength)` -- `_obstacles`: Array of `{ pos: Vector2, radius: Real }`.
- `Steering_Contain(_agent, _rect, _margin)` -- `_rect`: `{ x1, y1, x2, y2 }`.
