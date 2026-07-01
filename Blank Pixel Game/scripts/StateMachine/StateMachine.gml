/// @function State(_onEnter, _onStep, _onDraw, _onExit)
/// @param {Function} [_onEnter] (_owner, _machine) -> void. Called once on entering this state.
/// @param {Function} [_onStep]  (_owner, _machine) -> void. Called once per Step() while active.
/// @param {Function} [_onDraw]  (_owner, _machine) -> void. Called once per Draw() while active.
/// @param {Function} [_onExit]  (_owner, _machine) -> void. Called once on leaving this state.
function State(_onEnter = undefined, _onStep = undefined, _onDraw = undefined, _onExit = undefined) constructor {
    onEnter = _onEnter;
    onStep  = _onStep;
    onDraw  = _onDraw;
    onExit  = _onExit;
}

/// @function StateMachine(_owner)
/// @param {Id.Instance|Struct} _owner Whatever this machine belongs to.
///        Passed as the first argument to every callback.
function StateMachine(_owner) constructor {
    owner        = _owner;
    states       = {};         // name (string) -> State
    currentName  = undefined;
    currentState = undefined;
    data         = {};         // cleared on every ChangeState() -- current state's scratch memory
    previousName = undefined;  // name of the state we just left, useful for "return to previous" logic

    /// @function AddState(_name, _state)
    /// @param {String} _name
    /// @param {Struct.State} _state
    /// @returns {Struct.StateMachine} self
    static AddState = function(_name, _state) {
        variable_struct_set(states, _name, _state);
        return self;
    }

    /// @function HasState(_name)
    /// @param {String} _name
    /// @returns {Bool} True if a state with this name has been registered.
    static HasState = function(_name) {
        return variable_struct_exists(states, _name);
    }

    /// @function Current()
    /// @returns {String|Undefined} Name of the currently active state.
    static Current = function() {
        return currentName;
    }

    /// @function Is(_name)
    /// @param {String} _name
    /// @returns {Bool} True if the machine is currently in the named state.
    static Is = function(_name) {
        return currentName == _name;
    }

    /// @function ChangeState(_name, _force)
    /// Transitions to a different state: runs the current state's OnExit,
    /// clears data, switches, then runs the new state's OnEnter.
    /// Does nothing if already in the requested state, unless _force is true.
    /// @param {String} _name
    /// @param {Bool} [_force] Re-enter the same state (re-run OnExit + OnEnter) if true.
    /// @returns {Struct.StateMachine} self
    static ChangeState = function(_name, _force = false) {
        if (!HasState(_name)) {
            show_debug_message($"StateMachine: attempted to change to unregistered state '{_name}'");
            return self;
        }

        if (Is(_name) && !_force) return self;

        if (currentState != undefined && currentState.onExit != undefined) {
            currentState.onExit(owner, self);
        }

        previousName = currentName;
        currentName  = _name;
        currentState = variable_struct_get(states, _name);
        data         = {};

        if (currentState.onEnter != undefined) {
            currentState.onEnter(owner, self);
        }

        return self;
    }

    /// @function RevertToPrevious()
    /// Returns to whatever state was active before the last ChangeState()
    /// call. No-op if there is no previous state recorded.
    /// @returns {Struct.StateMachine} self
    static RevertToPrevious = function() {
        if (previousName != undefined) {
            ChangeState(previousName);
        }
        return self;
    }

    /// @function Step()
    /// Call once per Step event.
    /// @returns {Struct.StateMachine} self
    static Step = function() {
        if (currentState != undefined && currentState.onStep != undefined) {
            currentState.onStep(owner, self);
        }
        return self;
    }

    /// @function Draw()
    /// Call once per Draw event. Safe to omit entirely if a state has no
    /// draw logic -- onDraw is optional per-state, not just per-machine.
    /// @returns {Struct.StateMachine} self
    static Draw = function() {
        if (currentState != undefined && currentState.onDraw != undefined) {
            currentState.onDraw(owner, self);
        }
        return self;
    }
}
