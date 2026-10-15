# PlayerSaveDataScripts

Persistent PLAYER SAVE DATA (progression, unlocks, tutorial-seen flags), as opposed to `SettingsOverlayScripts`' `global.gameSettings` (user preferences, `settings.ini`).

## Core idea

`global.playerSaveData` is a plain struct (same shape as `global.gameSettings`), loaded once at boot via `LoadAndApplyPlayerSaveData()` (`oGameControl/Create_0.gml`, right after `LoadAndApplyGameSettings()`) from `PLAYER_SAVE_FILE` (`playersavedata.json`) -- real JSON via `json_stringify()`/`json_parse()`, not an ini section.

Defensive by field, since new save fields will keep being added over time: `LoadPlayerSaveData()` falls back to `DefaultPlayerSaveData()` for a missing file, an unreadable file, unparsable JSON, a non-struct JSON value, or any individual key missing from an otherwise-valid save -- built via `variable_struct_exists()` per field rather than trusting the loaded struct wholesale, so an old save never produces an `undefined` field once a new one is added.

## API

- `DefaultPlayerSaveData()` → `Struct` -- every field at its default. Also the per-field fallback source in `LoadPlayerSaveData()`.
- `LoadPlayerSaveData()` → `Struct` -- reads `PLAYER_SAVE_FILE`, returns a complete struct (defaults filled in for anything missing/invalid). Doesn't touch `global.playerSaveData` itself.
- `SavePlayerSaveData()` -- writes `global.playerSaveData` to `PLAYER_SAVE_FILE` as pretty-printed JSON. Call immediately after any field changes (no batching/debounce).
- `LoadAndApplyPlayerSaveData()` -- `LoadPlayerSaveData()` straight into `global.playerSaveData`. Called once at boot.
- `ResetTutorialProgress()` -- resets tutorial-flag fields to default and saves. Wired to `SettingsOverlayScripts.gml`'s "Restart Tutorial" button. 2026-08-13: now resets all three tutorial fields below, not just `hasSeenBeggarIntro`.
- `CompleteTutorial()` -- (2026-08-13, new) marks the tutorial fully finished: clears `global.tutorialActive` and, if not already `true`, sets `global.playerSaveData.tutorialCompleted = true` and saves. Idempotent -- safe to call on every run's end, not just the first. Called from `PauseMenuScripts.gml`'s `DoQuitOrEndMatch` (both "Quit to Desktop" and "End Match"). See `WarRoomMenuScripts.md`'s "Tutorial completion" section for the full picture, including a flagged gap: no win/loss detection exists in this project yet, so `CompleteTutorial()` isn't wired to a match actually ending in victory/defeat, only to the player manually leaving via the pause menu.

## Fields

| Field | Default | Consumer |
|---|---|---|
| `hasSeenBeggarIntro` | `false` | `HubTownMenuScripts.gml`/`HubControlScripts.gml` -- gates the Beggar's first-visit tutorial dialogue. Set true when that dialogue CLOSES (`HubControl.Update()`), not when it opens (2026-08-10 change) -- see `HubControlScripts.md`. |
| `hasSeenWarRoomIntro` | `false` | (2026-08-13, new) `WarRoomMenuScripts.gml` -- gates Connelius's first-visit War Room dialogue, same "set on close, not open" shape as `hasSeenBeggarIntro`. See `WarRoomMenuScripts.md`. |
| `tutorialCompleted` | `false` | (2026-08-13, new) Not consumed by anything YET -- this is the flag `PreRunMenuScripts.gml`'s `_PlayTalos()` TODO comment is waiting on (pre-completion routes into the tutorial run, post-completion faces the same AI without tutorial pop-ups). Set via `CompleteTutorial()` above; the branch itself hasn't been wired up. |

## Known assumptions / scope limits (flag if wrong)

- **`ResetPlayerProgress()` ("Restart Progress" button, `SettingsOverlayScripts.gml`) is still a stub.** Today `hasSeenBeggarIntro` is the only save field, so wiring "Restart Progress" now would just duplicate "Restart Tutorial." Real implementation once there's more to reset: overwrite `global.playerSaveData` with `DefaultPlayerSaveData()` + `SavePlayerSaveData()`.
- **Pretty-printed JSON** (`json_stringify(..., true)`) is a judgment call for readability while this is a small, actively-changing dev save file.
- Plain struct, not a constructor/class instance -- matches `global.gameSettings`'s existing shape.
