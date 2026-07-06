// -----------------------------------------------------------
// SteeringAgent -- physical state. One per unit.
// -----------------------------------------------------------

/// @function SteeringAgent(_x, _y, _maxSpeed, _maxForce, _mass)
/// @param {Real} _x
/// @param {Real} _y
/// @param {Real} [_maxSpeed]
/// @param {Real} [_maxForce]
/// @param {Real} [_mass]
function SteeringAgent(_x, _y, _maxSpeed = 3, _maxForce = 0.25, _mass = 1) constructor {
    pos       = new Vector2(_x, _y);
    velocity  = new Vector2(0, 0);
    maxSpeed  = _maxSpeed;
    maxForce  = _maxForce;
    mass      = _mass;

    // Knockback is a separate impulse channel, not a steering force --
    // see SteeringController.Apply() for why it can't just be Add()ed
    // like everything else.
    knockback       = new Vector2(0, 0);
    knockbackFriction = 0.85; // fraction of knockback retained per frame; lower = stops faster

    /// @function Speed()
    /// @returns {Real} Current speed (length of velocity).
    static Speed = function() {
        return velocity.Length();
    }

    /// @function Heading()
    /// @returns {Real} Current heading in degrees (0 if stationary).
    static Heading = function() {
        if (velocity.IsZero()) return 0;
        return velocity.Angle();
    }

    /// @function ApplyKnockback(_force)
    /// Adds an impulse to the knockback channel. Stacks additively with
    /// any existing knockback rather than overwriting it, so a second
    /// hit during recovery compounds instead of resetting.
    /// @param {Struct.Vector2} _force  Direction * magnitude, e.g.
    ///        Vector2FromAngle(_hitAngle, _hitStrength).
    /// @returns {Struct.SteeringAgent} self
    static ApplyKnockback = function(_force) {
        knockback.Add(_force);
        return self;
    }

    /// @function IsStaggered(_threshold)
    /// @param {Real} [_threshold] Knockback length above which the unit counts as staggered.
    /// @returns {Bool} True while knockback is still meaningfully active.
    static IsStaggered = function(_threshold = 0.5) {
        return knockback.LengthSquared() > (_threshold * _threshold);
    }

    /// @function Brake(_friction)
    /// @description Decays velocity toward zero. Call every step a unit is
    ///        meant to be standing still (e.g. UnitIdleInPlace,
    ///        UnitCombatHelpers.gml) -- "add no steering force" is NOT the
    ///        same as "come to a stop": every Steering_* behavior naturally
    ///        decelerates because it computes desired-minus-velocity, but
    ///        skipping all of them just leaves velocity exactly as it was,
    ///        forever, with nothing ever opposing it. Same
    ///        power(friction, matchSpeed) idiom knockback already decays
    ///        with (see SteeringController.Apply above), so this scales
    ///        with match speed the same way -- friction^1 at 1x, friction^0
    ///        == 1 (no decay) while paused.
    /// @param {Real} [_friction] Fraction of velocity retained per step at
    ///        1x match speed. Lower = stops faster.
    /// @returns {Struct.SteeringAgent} self
    static Brake = function(_friction = 0.8) {
        velocity.Scale(power(_friction, global.matchSpeed));
        if (velocity.LengthSquared() < 0.0001) {
            velocity.Set(0, 0);
        }
        return self;
    }

    /// @function SyncToInstance(_inst)
    /// Convenience: sync pos back to GML built-in x/y.
    /// @param {Id.Instance} _inst The instance whose x/y should be written to.
    static SyncToInstance = function(_inst) {
        _inst.x = pos.x;
        _inst.y = pos.y;
    }

    /// @function SyncFromInstance(_inst)
    /// Convenience: pull GML built-in x/y back into pos. Call this after
    /// move_and_collide() has resolved a move, since that function writes
    /// directly to the instance's x/y, not to agent.pos.
    /// @param {Id.Instance} _inst The instance whose x/y should be read from.
    static SyncFromInstance = function(_inst) {
        pos.Set(_inst.x, _inst.y);
    }
}

// -----------------------------------------------------------
// SteeringController -- accumulates + applies forces.
// -----------------------------------------------------------

/// @function SteeringController(_agent)
/// @param {Struct.SteeringAgent} _agent
function SteeringController(_agent) constructor {
    agent        = _agent;
    _accumulated = new Vector2(0, 0);
    wanderAngle  = random_range(0, 360); // wander's persistent angle

    // While agent.knockback's length is above this, steering forces are
    // scaled down rather than ignored outright -- a unit staggering from
    // a hit still weakly fights to recover, it doesn't go fully limp.
    staggerThreshold     = 1.5;
    staggerSteeringScale = 0.15; // how much steering still applies at full stagger

    /// @function Begin()
    /// Reset accumulator. Call at the top of the frame before Add() calls.
    /// @returns {Struct.SteeringController} self
    static Begin = function() {
        _accumulated.Set(0, 0);
        return self;
    }

    /// @function Add(_force, _weight)
    /// Add a weighted force to the accumulator.
    /// @param {Struct.Vector2} _force  Return value of a Steering_* function.
    /// @param {Real}           [_weight]
    /// @returns {Struct.SteeringController} self
    static Add = function(_force, _weight = 1) {
        _accumulated.Add(_force.GetScale(_weight));
        return self;
    }

    /// @function Apply()
    /// Truncate accumulated force, integrate velocity, apply + decay
    /// knockback -- but does NOT move agent.pos. Returns the frame's
    /// total movement delta instead, so the calling instance can run it
    /// through move_and_collide() before committing the move. (Struct
    /// methods can't call move_and_collide themselves -- it reads/writes
    /// the CALLING INSTANCE's x/y and mask, and `self` inside a struct
    /// method is the struct, not an instance.)
    ///
    /// Scaled by global.matchSpeed at the very end, deliberately after
    /// agent.velocity is integrated/clamped -- agent.velocity itself always
    /// represents "speed at 1x", so everything that reads it elsewhere
    /// (Speed(), Heading(), UnitUpdateSprite's walk/idle thresholds,
    /// Steering_AvoidObstacles' feeler-length scaling) stays internally
    /// consistent no matter the match speed. Only the actual pixel
    /// displacement returned here speeds up/slows down/freezes.
    /// @returns {Struct.Vector2} The delta to pass into move_and_collide().
    static Apply = function() {
        // Scale down (not zero) normal steering while staggered, so a hit
        // visibly interrupts intent without making the unit feel inert.
        var _knockbackMag   = agent.knockback.Length();
        var _steeringScale  = (_knockbackMag > staggerThreshold)
            ? staggerSteeringScale
            : 1;

        // Clamp total steering force to maxForce, divide by mass.
        var _force = _accumulated.GetClampLength(agent.maxForce)
                                  .Scale(_steeringScale)
                                  .Divide(agent.mass);

        // Integrate steering into velocity as normal.
        agent.velocity.Add(_force).ClampLength(agent.maxSpeed);

        // Total delta this frame: normal movement + knockback. Knockback
        // bypasses maxSpeed on purpose -- a hit should be able to move a
        // unit faster than its own legs can. global.matchSpeed == 0 makes
        // this (0,0) -- a full movement freeze, exactly what pausing needs.
        var _delta = agent.velocity.GetAdd(agent.knockback).Scale(global.matchSpeed);

        // Decay knockback for next frame -- power(friction, matchSpeed)
        // rather than a flat multiply, so decay speeds up/slows down with
        // match speed the same as everything else (friction^1 == today's
        // behavior at 1x; friction^0 == 1, i.e. no decay at all while
        // paused, instead of quietly bleeding off knockback during a pause).
        agent.knockback.Scale(power(agent.knockbackFriction, global.matchSpeed));
        if (agent.knockback.LengthSquared() < 0.0001) {
            agent.knockback.Set(0, 0);
        }

        return _delta;
    }
}

// -----------------------------------------------------------
// Core behaviors
// -----------------------------------------------------------

/// @function Steering_Seek(_agent, _target)
/// Accelerate toward _target at full speed.
/// @param {Struct.SteeringAgent} _agent
/// @param {Struct.Vector2}       _target
/// @returns {Struct.Vector2} steering force
function Steering_Seek(_agent, _target) {
    var _desired = _target.GetSubtract(_agent.pos)
                          .Normalize()
                          .Scale(_agent.maxSpeed);
    return _desired.Subtract(_agent.velocity);
}

/// @function Steering_Flee(_agent, _from, _radius)
/// Accelerate directly away from _from, while within _radius.
/// Returns zero force outside the radius so units don't flee
/// things they can't see.
/// @param {Struct.SteeringAgent} _agent
/// @param {Struct.Vector2}       _from
/// @param {Real}                 [_radius]
/// @returns {Struct.Vector2} steering force
function Steering_Flee(_agent, _from, _radius = 96) {
    if (_agent.pos.DistanceSquared(_from) > _radius * _radius) {
        return new Vector2(0, 0);
    }
    var _desired = _agent.pos.GetSubtract(_from)
                             .Normalize()
                             .Scale(_agent.maxSpeed);
    return _desired.Subtract(_agent.velocity);
}

/// @function Steering_Arrive(_agent, _target, _slowRadius)
/// Seek with a deceleration zone -- slows smoothly to a stop at
/// _target rather than overshooting. _slowRadius defines how far
/// out the unit begins to slow down.
/// @param {Struct.SteeringAgent} _agent
/// @param {Struct.Vector2}       _target
/// @param {Real}                 [_slowRadius]
/// @returns {Struct.Vector2} steering force
function Steering_Arrive(_agent, _target, _slowRadius = 64) {
    var _toTarget = _target.GetSubtract(_agent.pos);
    var _dist     = _toTarget.Length();

    if (_dist < 1) return new Vector2(0, 0);

    var _speed   = (_dist < _slowRadius) ? (_agent.maxSpeed * (_dist / (_slowRadius+1))) : _agent.maxSpeed;
    var _desired = _toTarget.GetScale(_speed / _dist); // normalize then scale in one step
    return _desired.Subtract(_agent.velocity);
}

/// @function Steering_Pursue(_agent, _targetPos, _targetVelocity)
/// Seek a predicted future position of a moving target, so the
/// unit feels like it's anticipating rather than always chasing
/// the tail. Lookahead scales with distance / maxSpeed.
/// @param {Struct.SteeringAgent} _agent
/// @param {Struct.Vector2}       _targetPos
/// @param {Struct.Vector2}       _targetVelocity
/// @returns {Struct.Vector2} steering force
function Steering_Pursue(_agent, _targetPos, _targetVelocity) {
    var _toTarget     = _targetPos.GetSubtract(_agent.pos);
    var _lookAhead    = _toTarget.Length() / _agent.maxSpeed;
    var _futureTarget = _targetPos.GetAdd(_targetVelocity.GetScale(_lookAhead));
    return Steering_Seek(_agent, _futureTarget);
}

/// @function Steering_Evade(_agent, _threatPos, _threatVelocity, _radius)
/// Flee a predicted future position of a moving threat.
/// @param {Struct.SteeringAgent} _agent
/// @param {Struct.Vector2}       _threatPos
/// @param {Struct.Vector2}       _threatVelocity
/// @param {Real}                 [_radius]
/// @returns {Struct.Vector2} steering force
function Steering_Evade(_agent, _threatPos, _threatVelocity, _radius = 96) {
    var _toThreat     = _threatPos.GetSubtract(_agent.pos);
    var _lookAhead    = _toThreat.Length() / _agent.maxSpeed;
    var _futureThreat = _threatPos.GetAdd(_threatVelocity.GetScale(_lookAhead));
    return Steering_Flee(_agent, _futureThreat, _radius);
}

/// @function Steering_Wander(_agent, _ctrl, _circleDistance, _circleRadius, _jitterDeg)
/// Smooth random drift. Steers toward a point on a virtual circle
/// projected ahead of the unit, jittering its angle each frame.
/// All persistent state lives on the controller, not the unit.
/// @param {Struct.SteeringAgent}     _agent
/// @param {Struct.SteeringController} _ctrl
/// @param {Real}                     [_circleDistance] How far ahead the virtual circle sits.
/// @param {Real}                     [_circleRadius]   Size of the virtual circle.
/// @param {Real}                     [_jitterDeg]      Max random angle change per frame.
/// @returns {Struct.Vector2} steering force
function Steering_Wander(_agent, _ctrl, _circleDistance = 48, _circleRadius = 24, _jitterDeg = 8) {
    _ctrl.wanderAngle += random_range(-_jitterDeg, _jitterDeg);

    var _heading      = _agent.Heading();
    var _circleCenter = Vector2FromAngle(_heading, _circleDistance).Add(_agent.pos);
    var _displacement = Vector2FromAngle(_heading + _ctrl.wanderAngle, _circleRadius);

    return Steering_Seek(_agent, _circleCenter.Add(_displacement));
}

// -----------------------------------------------------------
// Spatial / social behaviors
// (All take a _neighbors array of SteeringAgent structs.)
// -----------------------------------------------------------

/// @function Steering_Separation(_agent, _neighbors, _separationRadius)
/// Push away from nearby neighbors within _separationRadius.
/// Closer neighbors exert a stronger repulsive force (inverse
/// distance weighting).
/// @param {Struct.SteeringAgent}  _agent
/// @param {Array<Struct.SteeringAgent>} _neighbors
/// @param {Real}                  [_separationRadius]
/// @returns {Struct.Vector2} steering force
function Steering_Separation(_agent, _neighbors, _separationRadius = 32) {
    var _steer = new Vector2(0, 0);
    var _count = 0;

    for (var i = 0; i < array_length(_neighbors); i++) {
        var _other = _neighbors[i];
        var _dist  = _agent.pos.Distance(_other.pos);

        if (_dist > 0 && _dist < _separationRadius) {
            // Closer neighbors repel more strongly.
            var _away = _agent.pos.GetSubtract(_other.pos)
                                  .Normalize()
                                  .Scale(1 / _dist);
            _steer.Add(_away);
            _count++;
        }
    }

    if (_count > 0) {
        _steer.Scale(1 / _count)
              .Normalize()
              .Scale(_agent.maxSpeed)
              .Subtract(_agent.velocity);
    }

    return _steer;
}

/// @function Steering_Alignment(_agent, _neighbors, _alignRadius)
/// Match the average velocity of neighbors within _alignRadius.
/// Makes flocks move in the same direction at the same speed.
/// @param {Struct.SteeringAgent}  _agent
/// @param {Array<Struct.SteeringAgent>} _neighbors
/// @param {Real}                  [_alignRadius]
/// @returns {Struct.Vector2} steering force
function Steering_Alignment(_agent, _neighbors, _alignRadius = 64) {
    var _avgVel = new Vector2(0, 0);
    var _count  = 0;

    for (var i = 0; i < array_length(_neighbors); i++) {
        var _other = _neighbors[i];
        if (_agent.pos.Distance(_other.pos) < _alignRadius) {
            _avgVel.Add(_other.velocity);
            _count++;
        }
    }

    if (_count == 0) return new Vector2(0, 0);

    return _avgVel.Scale(1 / _count)
                  .Normalize()
                  .Scale(_agent.maxSpeed)
                  .Subtract(_agent.velocity);
}

/// @function Steering_Cohesion(_agent, _neighbors, _cohesionRadius)
/// Steer toward the center of mass of neighbors within _cohesionRadius.
/// Keeps flocks from drifting apart.
/// @param {Struct.SteeringAgent}  _agent
/// @param {Array<Struct.SteeringAgent>} _neighbors
/// @param {Real}                  [_cohesionRadius]
/// @returns {Struct.Vector2} steering force
function Steering_Cohesion(_agent, _neighbors, _cohesionRadius = 80) {
    var _centerOfMass = new Vector2(0, 0);
    var _count        = 0;

    for (var i = 0; i < array_length(_neighbors); i++) {
        var _other = _neighbors[i];
        if (_agent.pos.Distance(_other.pos) < _cohesionRadius) {
            _centerOfMass.Add(_other.pos);
            _count++;
        }
    }

    if (_count == 0) return new Vector2(0, 0);

    _centerOfMass.Scale(1 / _count);
    return Steering_Seek(_agent, _centerOfMass);
}

/// @function Steering_Flock(_agent, _neighbors, _separationRadius, _alignRadius, _cohesionRadius, _separationWeight, _alignWeight, _cohesionWeight)
/// Convenience wrapper: separation + alignment + cohesion in one
/// call, with individually tunable weights.
/// @param {Struct.SteeringAgent}       _agent
/// @param {Array<Struct.SteeringAgent>} _neighbors
/// @param {Real} [_separationRadius]
/// @param {Real} [_alignRadius]
/// @param {Real} [_cohesionRadius]
/// @param {Real} [_separationWeight]
/// @param {Real} [_alignWeight]
/// @param {Real} [_cohesionWeight]
/// @returns {Struct.Vector2} combined steering force
function Steering_Flock(
    _agent, _neighbors,
    _separationRadius = 32, _alignRadius = 64, _cohesionRadius = 80,
    _separationWeight = 1.5, _alignWeight = 1.0, _cohesionWeight = 1.0
) {
    var _sep  = Steering_Separation(_agent, _neighbors, _separationRadius).Scale(_separationWeight);
    var _ali  = Steering_Alignment( _agent, _neighbors, _alignRadius).Scale(_alignWeight);
    var _coh  = Steering_Cohesion(  _agent, _neighbors, _cohesionRadius).Scale(_cohesionWeight);
    return _sep.Add(_ali).Add(_coh);
}

// -----------------------------------------------------------
// Obstacle avoidance
// -----------------------------------------------------------

/// @function Steering_AvoidObstacles(_agent, _obstacles, _feelerLength)
/// Lookahead-based obstacle avoidance. Projects a virtual
/// "feeler" ahead of the unit scaled by speed, then laterally
/// steers away from whichever obstacle overlaps the feeler most.
/// Obstacles are structs with a `pos` (Vector2) and `radius` (Real).
///
/// @param {Struct.SteeringAgent}  _agent
/// @param {Array}                 _obstacles  Array of { pos: Vector2, radius: Real }
/// @param {Real}                  [_feelerLength]
/// @returns {Struct.Vector2} steering force
function Steering_AvoidObstacles(_agent, _obstacles, _feelerLength = 80) {
    // Scale lookahead with current speed so faster units look further ahead.
    var _dynamicLength = _feelerLength * (_agent.Speed() / _agent.maxSpeed);
    _dynamicLength     = max(_dynamicLength, _feelerLength * 0.5); // always at least half

    var _heading      = Vector2FromAngle(_agent.Heading(), _dynamicLength);
    var _feelerTip    = _agent.pos.GetAdd(_heading);

    // Find the obstacle that most intersects the feeler -- not just
    // the nearest, since the nearest might not actually be in our path.
    var _mostThreatening = noone;
    var _minDist         = infinity;

    for (var i = 0; i < array_length(_obstacles); i++) {
        var _o    = _obstacles[i];
        var _dist = _agent.pos.Distance(_o.pos);

        // Cheap lateral distance check: project the obstacle center onto
        // the feeler axis and measure perpendicular offset.
        var _toObs = _o.pos.GetSubtract(_agent.pos);
        var _proj  = _toObs.Dot(_heading.GetNormalize());
        if (_proj < 0 || _proj > _dynamicLength) continue; // behind us or beyond feeler

        var _lateral = sqrt(max(0, _toObs.LengthSquared() - _proj * _proj));
        if (_lateral > _o.radius) continue; // misses the obstacle

        if (_dist < _minDist) {
            _minDist         = _dist;
            _mostThreatening = _o;
        }
    }

    if (_mostThreatening == noone) return new Vector2(0, 0);

    // Steer perpendicular to the heading, away from the obstacle center.
    // Which side: push away from wherever the obstacle is relative to us.
    var _toObs   = _mostThreatening.pos.GetSubtract(_agent.pos);
    var _headDir = Vector2FromAngle(_agent.Heading(), 1);
    var _cross   = _headDir.Cross(_toObs); // positive = obstacle is to our right

    // Rotate heading 90° toward the clear side.
    var _avoidDir = (_cross >= 0)
        ? Vector2FromAngle(_agent.Heading() - 90, _agent.maxSpeed)
        : Vector2FromAngle(_agent.Heading() + 90, _agent.maxSpeed);

    // Scale urgency by how close the obstacle is.
    var _urgency = clamp(1 - (_minDist / _feelerLength), 0, 1);
    return _avoidDir.Subtract(_agent.velocity).Scale(_urgency);
}

// -----------------------------------------------------------
// Boundary containment
// -----------------------------------------------------------

/// @function Steering_Contain(_agent, _rect, _margin)
/// Soft boundary: seek back toward the rect's center as the unit
/// approaches an edge. _margin is how far from the edge the pull
/// begins. Returns zero force when comfortably inside.
/// _rect: { x1, y1, x2, y2 }
/// @param {Struct.SteeringAgent} _agent
/// @param {Struct}               _rect
/// @param {Real}                 [_margin]
/// @returns {Struct.Vector2} steering force
function Steering_Contain(_agent, _rect, _margin = 40) {
    var _cx = (_rect.x1 + _rect.x2) * 0.5;
    var _cy = (_rect.y1 + _rect.y2) * 0.5;
    var _px = _agent.pos.x;
    var _py = _agent.pos.y;

    var _nearEdge = (_px < _rect.x1 + _margin)
                 || (_px > _rect.x2 - _margin)
                 || (_py < _rect.y1 + _margin)
                 || (_py > _rect.y2 - _margin);

    if (!_nearEdge) return new Vector2(0, 0);

    return Steering_Seek(_agent, new Vector2(_cx, _cy));
}
