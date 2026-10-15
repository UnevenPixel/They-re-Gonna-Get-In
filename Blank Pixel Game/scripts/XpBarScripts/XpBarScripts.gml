// The lower HUD's XP bar widget: fill, milestone reveals, tossed Fate
// Token coins. See XpBarScripts.md.

#macro XP_BAR_ORIGIN_X                1616 // GUI-space anchor
#macro XP_BAR_ORIGIN_Y                 842
#macro XP_BAR_SCALE                    2
#macro XP_BAR_MILESTONE_REVEAL_STEPS   20   // steps at 1x match speed
#macro XP_BAR_TOKEN_GRAVITY            0.35 // px/step^2 at 1x match speed
#macro XP_BAR_TOKEN_LAUNCH_SPEED       3.5  // px/step initial upward speed
#macro XP_BAR_TOKEN_SPIN_MIN           6    // deg/step
#macro XP_BAR_TOKEN_SPIN_MAX           14
#macro XP_BAR_TOKEN_FLIP_SPEED         10   // deg/step fed into cos() for the yscale flip
#macro XP_BAR_TOKEN_FALL_DISTANCE      40   // px below start before the coin disappears
#macro XP_BAR_TOKEN_MAX_LIFE           90   // steps -- safety cap

#macro XP_BAR_TOKEN_REGION_HEIGHT 100 // 2026-08-16 request -- height (px) of the region below the bar's bottom edge where gained-token icons scatter, see _RegionRect()/.md. Unrelated to the milestone toss-coin macros above -- see the region-tokens section's own comment block.

// Token drag-to-activate (2026-08-16 follow-up request, "click and hold from this portion of the UI...
// drag this token up to the center of the screen... spend the token to 'activate the machine'") -- a
// THIRD, separate mechanic layered on top of the two above. See StepTokenDrag()/.md.
#macro XP_BAR_TOKEN_ACTIVATE_RADIUS 220 // px, GUI-space -- how close a released drag has to land to FateEngineOverlay's own machine-center point to count as "roughly where the machine is". Untuned judgment call -- request only says "roughly", no exact value given, see .md.

// Fixed x-offsets (right of XP_BAR_ORIGIN_X) for the 4 non-terminal 20%-marks.
global.xpBarMilestoneOffsets = [48, 94, 140, 186];

/// @function XpBarMilestonePercent(_index)
/// @description Fill fraction (0-1) milestone _index represents.
/// @param {Real} _index
/// @returns {Real}
function XpBarMilestonePercent(_index) {
    return (_index + 1) / (array_length(global.xpBarMilestoneOffsets) + 1);
}

/// @function XpBarFillPercent(_team)
/// @description _team's current age-bar fill fraction (0-1). Returns 1 once already at AGE_MAX.
/// @param {Real} _team
/// @returns {Real}
function XpBarFillPercent(_team) {
    var _required = AgeXpRequired(global.age[_team]);
    if (_required == undefined) return 1;
    return clamp(global.resources[_team].xp / _required, 0, 1);
}

/// @function XpBarWidgetHitRect()
/// @description GUI-space bounding rect of the XP bar's backer sprite.
/// @returns {Struct} { x1, y1, x2, y2 }
function XpBarWidgetHitRect() {
    var _x1 = XP_BAR_ORIGIN_X - sprite_get_xoffset(sXpBar) * XP_BAR_SCALE;
    var _y1 = XP_BAR_ORIGIN_Y - sprite_get_yoffset(sXpBar) * XP_BAR_SCALE;
    return {
        x1: _x1,
        y1: _y1,
        x2: _x1 + sprite_get_width(sXpBar) * XP_BAR_SCALE,
        y2: _y1 + sprite_get_height(sXpBar) * XP_BAR_SCALE
    };
}

/// @function XpBarWidget(_team)
/// @description The XP bar HUD widget for _team. Owner calls Step()/Draw().
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
function XpBarWidget(_team) constructor {
    team = _team;

    var _count = array_length(global.xpBarMilestoneOffsets);
    milestoneHit    = array_create(_count, false); // has this milestone already triggered this age-bar cycle
    milestoneReveal = array_create(_count, 0);      // 0-1 top-to-bottom reveal progress
    tokens          = [];                            // active tossed coins, see SpawnToken
    lastAge         = global.age[team];               // detects an age-up (bar reset) between Steps

    // 2026-08-16 request ("whenever a new fate token is gained, draw one token in a random location [below
    // the bar]") -- a SEPARATE mechanic from the milestoneHit/tokens toss-coin system above, which fires on
    // XP-BAR-FILL milestones, not actual global.resources[team].fateTokens gains. See _SyncRegionTokens()/.md.
    regionTokens   = [];                             // { x, y } -- one per currently-held Fate Token, see _SyncRegionTokens()
    lastFateTokens = global.resources[team].fateTokens; // detects gains/spends between Steps, same before/after-diff idiom as lastAge above

    // 2026-08-16 follow-up request ("click and hold from this portion of the UI... have the large fate
    // token draw at the mouse position") -- see StepTokenDrag()/.md.
    dragging = false; // true while a token has been picked up from regionTokens and is following the mouse
    dragX    = 0;      // GUI-space, only meaningful while dragging
    dragY    = 0;

    var _percent = XpBarFillPercent(team);
    for (var i = 0; i < _count; i++) {
        if (_percent >= XpBarMilestonePercent(i)) {
            milestoneHit[i]    = true;
            milestoneReveal[i] = 1;
        }
    }

    /// @function SpawnToken(_x)
    /// @description Launches one tossed Fate Token coin at (_x, XP_BAR_ORIGIN_Y).
    /// @param {Real} _x
    static SpawnToken = function(_x) {
        array_push(tokens, {
            x         : _x,
            startY    : XP_BAR_ORIGIN_Y,
            y         : XP_BAR_ORIGIN_Y,
            vy        : -XP_BAR_TOKEN_LAUNCH_SPEED,
            angle     : 0,     // image_angle-equivalent
            spinSpeed : choose(1, -1) * random_range(XP_BAR_TOKEN_SPIN_MIN, XP_BAR_TOKEN_SPIN_MAX),
            flipPhase : 0,     // image_yscale-equivalent -- see Draw()
            age       : 0,
        });
    }

    /// @function _RegionRect()
    /// @description GUI-space bounding rect of the region below the bar where gained-Fate-Token icons scatter -- the bar's own width (via XpBarWidgetHitRect()), XP_BAR_TOKEN_REGION_HEIGHT px tall, starting at the bar's bottom edge. 2026-08-16 request. See .md.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _RegionRect = function() {
        var _bar = XpBarWidgetHitRect();
        return {
            x1: _bar.x1,
            y1: _bar.y2,
            x2: _bar.x2,
            y2: _bar.y2 + XP_BAR_TOKEN_REGION_HEIGHT,
        };
    }

    /// @function _SyncRegionTokens()
    /// @description Compares global.resources[team].fateTokens against lastFateTokens every Step (same before/after-diff idiom this struct's own age-up detection already uses for lastAge) -- an increase (a grant, from any of this project's several fateTokens += call sites) spawns that many new regionTokens at a random position within _RegionRect(); a decrease (a spend, e.g. FateEngineOverlay.Spin()) removes that many, so the region always reflects the CURRENT unspent count rather than accumulating forever. See .md.
    static _SyncRegionTokens = function() {
        var _current = global.resources[team].fateTokens;
        var _delta   = _current - lastFateTokens;

        if (_delta > 0) {
            var _rect = _RegionRect();
            repeat (_delta) {
                array_push(regionTokens, {
                    x: random_range(_rect.x1, _rect.x2),
                    y: random_range(_rect.y1, _rect.y2),
                });
            }
        } else if (_delta < 0) {
            repeat (min(-_delta, array_length(regionTokens))) {
                array_delete(regionTokens, array_length(regionTokens) - 1, 1);
            }
        }

        lastFateTokens = _current;
    }

    /// @function StepTokenDrag(_fateEngineOverlay)
    /// @description 2026-08-16 follow-up request -- click-and-hold a token out of regionTokens (only
    /// while _fateEngineOverlay.isOpen) and drag it around at the mouse position; releasing "roughly
    /// where the machine is" spends it to activate the machine, releasing anywhere else just drops it
    /// back into the region pile. One-directional coupling, same convention as DealerIntroScripts.gml's
    /// own relationship to FateEngineOverlay -- this method reaches INTO _fateEngineOverlay's public-ish
    /// _TokenActivateEligible()/_DistanceToMachineCenter()/Activate(), which have zero knowledge of this
    /// file in return. See .md for the full state machine and the known token-double-spend gap against
    /// Spin()'s own separate spend path.
    /// @param {Struct.FateEngineOverlay} _fateEngineOverlay
    static StepTokenDrag = function(_fateEngineOverlay) {
        // The overlay can close (or never have been open) mid-drag -- e.g. some other input forces it
        // shut. Not explicitly covered by the request; judgment call is to just drop the token back into
        // the region pile rather than losing it or leaving it stuck mid-air. See .md.
        if (!_fateEngineOverlay.isOpen) {
            if (dragging) {
                var _rect = _RegionRect();
                array_push(regionTokens, { x: random_range(_rect.x1, _rect.x2), y: random_range(_rect.y1, _rect.y2) });
                dragging = false;
            }
            return;
        }

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        if (!dragging) {
            if (mouse_check_button_pressed(mb_left) && array_length(regionTokens) > 0) {
                var _rect = _RegionRect();
                if (_mx >= _rect.x1 && _mx <= _rect.x2 && _my >= _rect.y1 && _my <= _rect.y2) {
                    // Picks the LAST-pushed region token, not whichever one the mouse happens to be
                    // nearest -- simplest read of "click and hold from this portion of the UI" (the
                    // request treats the region as one pickup zone, not per-icon hit-testing). See .md.
                    array_delete(regionTokens, array_length(regionTokens) - 1, 1);
                    dragging = true;
                }
            }
            return;
        }

        dragX = _mx;
        dragY = _my;

        if (mouse_check_button_released(mb_left)) {
            dragging = false;

            var _eligible = _fateEngineOverlay._TokenActivateEligible() && _fateEngineOverlay._DistanceToMachineCenter(_mx, _my) <= XP_BAR_TOKEN_ACTIVATE_RADIUS;
            if (_eligible) {
                // Spends the token directly here rather than through _SyncRegionTokens()'s own
                // before/after diff -- this token was already removed from regionTokens at pickup, so
                // letting the diff "see" this spend too would double-remove a region icon that's no
                // longer there. lastFateTokens is manually re-synced to the new value so next Step()'s
                // diff starts clean. See _SyncRegionTokens()/.md.
                global.resources[team].fateTokens -= 1;
                lastFateTokens = global.resources[team].fateTokens;
                _fateEngineOverlay.Activate(_mx, _my);
            } else {
                var _rect = _RegionRect();
                array_push(regionTokens, { x: random_range(_rect.x1, _rect.x2), y: random_range(_rect.y1, _rect.y2) });
            }
        }
    }

    /// @function Step(_fateEngineOverlay)
    /// @description Call once per Step. Detects newly-crossed marks, age-ups, advances in-flight coins, steps the token-drag interaction.
    /// @param {Struct.FateEngineOverlay} _fateEngineOverlay 2026-08-16 follow-up -- needed by StepTokenDrag() (isOpen check + machine-eligibility/distance queries). Caller is oUnitControl/Step_0.gml, which already owns both structs -- see .md.
    static Step = function(_fateEngineOverlay) {
        _SyncRegionTokens(); // 2026-08-16 request, see .md
        StepTokenDrag(_fateEngineOverlay); // 2026-08-16 follow-up request, see .md

        if (global.age[team] != lastAge) {
            lastAge = global.age[team];
            for (var i = 0; i < array_length(milestoneHit); i++) {
                milestoneHit[i]    = false;
                milestoneReveal[i] = 0;
            }
        }

        var _percent = XpBarFillPercent(team);

        for (var i = 0; i < array_length(milestoneHit); i++) {
            if (!milestoneHit[i] && _percent >= XpBarMilestonePercent(i)) {
                milestoneHit[i] = true;
                SpawnToken(XP_BAR_ORIGIN_X + global.xpBarMilestoneOffsets[i]);
            }
            if (milestoneHit[i] && milestoneReveal[i] < 1) {
                milestoneReveal[i] = min(1, milestoneReveal[i] + (1 / XP_BAR_MILESTONE_REVEAL_STEPS) * global.matchSpeed);
            }
        }

        for (var i = array_length(tokens) - 1; i >= 0; i--) {
            var _token = tokens[i];
            _token.vy        += XP_BAR_TOKEN_GRAVITY * global.matchSpeed;
            _token.y         += _token.vy * global.matchSpeed;
            _token.angle     += _token.spinSpeed * global.matchSpeed;
            _token.flipPhase += XP_BAR_TOKEN_FLIP_SPEED * global.matchSpeed;
            _token.age       += global.matchSpeed;

            var _fallenPast = (_token.y - _token.startY) >= XP_BAR_TOKEN_FALL_DISTANCE;
            if (_fallenPast || _token.age >= XP_BAR_TOKEN_MAX_LIFE) {
                array_delete(tokens, i, 1);
            }
        }
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event. Coins draw last, on top of the bar.
    static Draw = function() {
        draw_sprite_ext(sXpBar, 0, XP_BAR_ORIGIN_X, XP_BAR_ORIGIN_Y, XP_BAR_SCALE, XP_BAR_SCALE, 0, c_white, 1);

        var _percent = XpBarFillPercent(team);
        var _fillW   = round(_percent * sprite_get_width(sXpBarFill));
        if (_fillW > 0) {
            draw_sprite_part_ext(sXpBarFill, 0, 0, 0, _fillW, sprite_get_height(sXpBarFill), XP_BAR_ORIGIN_X, XP_BAR_ORIGIN_Y, XP_BAR_SCALE, XP_BAR_SCALE, c_white, 1);
        }

        var _milestoneW = sprite_get_width(sXpBarMilestone);
        for (var i = 0; i < array_length(milestoneReveal); i++) {
            if (milestoneReveal[i] <= 0) continue;
            var _revealH = round(milestoneReveal[i] * sprite_get_height(sXpBarMilestone));
            if (_revealH <= 0) continue;

            var _mx = XP_BAR_ORIGIN_X + global.xpBarMilestoneOffsets[i];
            draw_sprite_part_ext(sXpBarMilestone, 0, 0, 0, _milestoneW, _revealH, _mx, XP_BAR_ORIGIN_Y, XP_BAR_SCALE, XP_BAR_SCALE, c_white, 1);
        }

        for (var i = 0; i < array_length(tokens); i++) {
            var _token  = tokens[i];
            var _yscale = XP_BAR_SCALE * cos(degtorad(_token.flipPhase)); // fake 3D tumble
            draw_sprite_ext(sFateTokenSmall, 0, _token.x, _token.y, XP_BAR_SCALE, _yscale, _token.angle, c_white, 1);
        }

        // 2026-08-16 request -- static (no toss/tumble), one per currently-held Fate Token, see
        // _SyncRegionTokens()/.md. Drawn at XP_BAR_SCALE to match every other sprite in this widget.
        for (var i = 0; i < array_length(regionTokens); i++) {
            var _regionToken = regionTokens[i];
            draw_sprite_ext(sFateTokenSmall, 0, _regionToken.x, _regionToken.y, XP_BAR_SCALE, XP_BAR_SCALE, 0, c_white, 1);
        }

        // 2026-08-16 follow-up request ("have the large fate token draw at the mouse position") -- drawn
        // LAST/on top of everything else in this widget so it's never occluded mid-drag. Native (1,1)
        // scale, not XP_BAR_SCALE -- sFateTokenLarge is already its own full size (48x48), unlike
        // sFateTokenSmall which this widget upscales elsewhere; judgment call, see .md.
        if (dragging) {
            draw_sprite_ext(sFateTokenLarge, 0, dragX, dragY, 1, 1, 0, c_white, 1);
        }
    }
}
