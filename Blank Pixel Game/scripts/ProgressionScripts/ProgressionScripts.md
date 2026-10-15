# ProgressionScripts

XP / Age / Fate Token tracking, built against the "XP Age Progression System" design doc. Two behaviors distinguish this from a naive flat-XP system:

1. XP-to-fill-the-bar is NOT flat across ages -- the doc specifies escalating requirements per transition (Age I->II 100 XP, II->III 150, III->IV 200). See `global.ageXpRequired`/`AgeXpRequired`.
2. Age does NOT advance automatically the instant the bar fills. Per the doc's "Age Advances" section: filling the bar just makes Age Up available (`global.ageUpReady`) -- the player still has to pay a resource cost (`global.ageUpCost`/`AgeUpCost`, gold-only per the doc's own "work in progress, use gold as a starting point" note) via `TryAgeUp` before the age actually advances and XP resets. There's no "Age Up" HUD button wired to `TryAgeUp` yet -- that's a separate UI task.

XP fills a per-team "age bar"; every time it crosses one of 5 equal 20%-marks, the team gets one Fate Token. This part is untouched by the design doc (which doesn't mention Fate Tokens at all) -- confirmed this is meant to keep layering on top of whatever XP system exists underneath.

Ages/blueprint-tier-acquisition odds are still NOT designed yet -- this file only tracks the numbers. Nothing reads `global.age` to affect blueprint odds yet; that's future work.

## TEAM.ENEMY Fate Token substitution

TEAM.ENEMY (the AI) no longer gets Fate Tokens at all -- it has no Fate Engine UI to ever spend one on, so they'd just pile up doing nothing. Each milestone crossed grants it 1-3 random blueprints instead, standing in for what the payout would eventually be once the real Fate Engine reward table exists (`FateEngineDrumScripts.gml`'s drum is still a visual-only test harness). For EACH milestone crossed in a `GainXP` call, rolls a fresh `irandom_range(1, 3)` count and grants that many blueprints, each independently a random registered building type (same idiom `FateDrumRandomPlaceholderItem` uses for its own "blueprint" look). TEAM.PLAYER's behavior is completely unchanged.

## GainXP mechanics

Caps the added XP at `AgeXpRequired(global.age[_team])` -- XP beyond that is discarded this call, not banked (age no longer auto-advances, so there's nowhere to carry it into yet). No-ops entirely if `_team` is already at `AGE_MAX`.

Fate Token/blueprint awards are computed from before/after bar position (`floor(_xpAfter / _interval) - floor(_xpBefore / _interval)`), so a single large XP gain that crosses more than one 20%-mark still awards every token/blueprint batch earned, not just one.

## TryAgeUp

Requires BOTH the age bar to already be full (`global.ageUpReady[_team]`) AND enough resources to cover `AgeUpCost(global.age[_team])` -- filling the bar only unlocks the option, it doesn't pay for itself. On success: spends the cost (`Purchase`, `Economy.gml`), advances `global.age[_team]`, resets that team's xp to 0, clears `ageUpReady`. Safe to call speculatively (e.g. from a future "Age Up" button) without checking state first -- no-ops and returns false if the bar isn't full, already at `AGE_MAX`, or unaffordable.

## API

- `AGE_MAX`, `AGE_FATE_TOKEN_INTERVALS`, `global.ageXpRequired`, `global.ageUpCost`.
- `AgeXpRequired(_age)`, `AgeUpCost(_age)`.
- `GainXP(_team, _amount)`.
- `TryAgeUp(_team)`.
