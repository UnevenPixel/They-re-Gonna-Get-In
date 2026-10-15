# StateMachine

Generic finite state machine engine: `State` (a bundle of onEnter/onStep/onDraw/onExit callbacks) and `StateMachine` (owns named states, tracks the current one, dispatches Step/Draw). Used by every unit's FSM (guard/defend/attack/siege/combat states, see `UnitState*.gml`) and by any other struct that wants named-state behavior.

Every callback is called as `(_owner, _machine)` -- `_owner` is whatever was passed to the `StateMachine` constructor (typically the unit instance), `_machine` is the `StateMachine` itself, giving callbacks access to `data` (per-state scratch memory, cleared on every `ChangeState`) and `previousName` (for revert-to-previous logic, e.g. combat states returning to guard/defend).

## API

- `State(_onEnter, _onStep, _onDraw, _onExit)` -- all four callbacks optional.
- `StateMachine(_owner)` -- `AddState(_name, _state)`, `HasState(_name)`, `Current()`, `Is(_name)`, `ChangeState(_name, _force)`, `RevertToPrevious()`, `Step()`, `Draw()`.

`ChangeState` runs the outgoing state's `onExit`, clears `data`, switches, then runs the incoming state's `onEnter`. No-ops if already in the requested state unless `_force` is true (re-runs exit+enter on the same state). `RevertToPrevious()` re-enters whatever state was active before the last `ChangeState` call -- no-op if there is none recorded.
