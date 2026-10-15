# Enumerators

Shared project-wide enums.

- `ECreditsState` -- `CreditsOverlayScripts.gml`'s fade state machine: `FADE_IN` -> `HOLD` -> `FADE_OUT` -> `DONE`.
- `UnitAnimState` -- `WANDER`/`COMBAT`, coarse animation-selection state for units.
- `TEAM` -- `PLAYER`/`ENEMY`. Indexes every per-team global array/struct (`global.resources`, `global.blueprints`, `global.armyLimit`, `global.analytics`, etc.) throughout the project.
- `FACING` -- `LEFT`/`RIGHT`. Used by `RulerPortraitScripts.gml` and steering/sprite-flip code.

## API

- `ECreditsState`, `UnitAnimState`, `TEAM`, `FACING`.
