// -----------------------------------------------------------
// XpBarScripts -- the lower HUD's XP bar widget: bar backer + fill +
// animated 20%-mark "milestone" reveals + a tossed Fate Token coin every
// time a milestone is first reached. 2026-07-06 request.
//
// Sprites (all in the "In Game/UI/Assets" folder):
//   sXpBar           -- backer/frame. Custom origin (4,3) -- drawing it
//                       and sXpBarFill at the SAME point lines the fill up
//                       exactly inside the frame's border automatically.
//   sXpBarFill       -- the progress fill, origin (0,0). Drawn with
//                       draw_sprite_part_ext so only _percent of its width
//                       shows -- 0% = nothing, 100% = its full native
//                       width (121px).
//   sXpBarMilestone  -- a 1px-wide, 8px-tall vertical tick line, origin
//                       (0,0). "Reveals" top-to-bottom via the same
//                       draw_sprite_part_ext approach, on the vertical
//                       axis instead.
//   sFateTokenSmall  -- the tossed coin, origin Middle Center.
//
// Layered on top of the existing Fate Token system in ProgressionScripts.gml
// -- GainXP now awards a Fate Token at every 20/40/60/80/100% mark of
// AgeXpRequired(global.age[team]) (2026-07-06: was 4 quarter-marks of a
// flat 1000, now 5 fifth-marks of a PER-AGE requirement -- 100/150/200 XP
// for Age I->II/II->III/III->IV, per the "XP Age Progression System" doc).
// This widget visualizes 4 of those 5 marks (20/40/60/80%; the 5th
// coincides with the age-up/bar-reset, not a milestone tick) at 4 FIXED
// pixel offsets from the widget's origin (48/94/140/186 -- evenly spaced
// 46px apart, per spec) rather than offsets derived from the fill
// sprite's own width. Percent-fill math re-reads AgeXpRequired every call
// so the bar's effective "100%" changes automatically as the team ages up.
//
// Each milestone is invisible (drawn 0px tall) until its threshold is
// actually met -- only THEN does it reveal top-to-bottom and stay fully
// revealed for the rest of the bar's cycle. Per 2026-07-06 clarification.
//
// XP_BAR_ORIGIN_X/Y and the milestone offsets are GUI-space coordinates
// that already account for the 2x render scale -- same convention as the
// Fate Engine drum layout (FateEngineOverlay, FateEngineOverlayScripts.gml)
// -- only sprite RENDERING needs the explicit xscale/yscale = XP_BAR_SCALE,
// not the positions.
//
// Not a GM instance -- same "plain struct, owner calls Step()/Draw()"
// pattern as BlueprintController/FateDrum. Wired into oUnitControl
// (Create_0/Step_0/Draw_64), same as blueprintController.
// -----------------------------------------------------------

#macro XP_BAR_ORIGIN_X                1616 // GUI-space anchor -- 2026-07-06 request
#macro XP_BAR_ORIGIN_Y                 842
#macro XP_BAR_SCALE                    2    // GUI render scale for every sprite in this widget
#macro XP_BAR_MILESTONE_REVEAL_STEPS   20   // steps at 1x match speed for a milestone's top-to-bottom reveal
#macro XP_BAR_TOKEN_GRAVITY            0.35 // px/step^2 at 1x match speed
#macro XP_BAR_TOKEN_LAUNCH_SPEED       3.5  // px/step initial upward speed
#macro XP_BAR_TOKEN_SPIN_MIN           6    // deg/step
#macro XP_BAR_TOKEN_SPIN_MAX           14
#macro XP_BAR_TOKEN_FLIP_SPEED         10   // deg/step fed into cos() for the yscale flip -- simulates image_yscale on a real instance
#macro XP_BAR_TOKEN_FALL_DISTANCE      40   // px below its start the coin has to fall before it disappears
#macro XP_BAR_TOKEN_MAX_LIFE           90   // steps -- safety cap so a coin can never linger forever regardless of the tuning above

// Fixed x-offsets (right of XP_BAR_ORIGIN_X) for the 4 non-terminal
// 20%-marks (20/40/60/80%), per 2026-07-06 spec, in that order. A plain
// global array (not a #macro) so it's allocated once, not on every Draw --
// same reasoning as global.resourceIconOrder (ResourceUIScripts.gml).
global.xpBarMilestoneOffsets = [48, 94, 140, 186];

/// @function XpBarMilestonePercent(_index)
/// @description The fill fraction (0-1) milestone _index represents --
///        20/40/60/80% for indices 0/1/2/3, matching global.xpBarMilestoneOffsets
///        1:1 and the same 20%-marks GainXP (ProgressionScripts.gml)
///        already awards Fate Tokens at (the 5th, 100%, coincides with the
///        age-up/bar-reset and isn't a milestone tick here).
/// @param {Real} _index
/// @returns {Real}
function XpBarMilestonePercent(_index) {
    return (_index + 1) / (array_length(global.xpBarMilestoneOffsets) + 1);
}

/// @function XpBarFillPercent(_team)
/// @description _team's current age-bar fill fraction (0-1), against
///        AgeXpRequired(global.age[_team]) (ProgressionScripts.gml) rather
///        than a flat number -- so this automatically reflects whatever
///        the current age's requirement is. Once _team is already at
///        AGE_MAX, AgeXpRequired returns undefined (no bar left to fill);
///        treated as 1 (full) here since there's nothing further to show
///        progress toward.
/// @param {Real} _team
/// @returns {Real}
function XpBarFillPercent(_team) {
    var _required = AgeXpRequired(global.age[_team]);
    if (_required == undefined) return 1;
    return clamp(global.resources[_team].xp / _required, 0, 1);
}

/// @function XpBarWidgetHitRect()
/// @description GUI-space bounding rect of the XP bar's backer sprite
///        (sXpBar), computed from the EXACT same anchor/offset/scale math
///        Draw() uses to draw it (XP_BAR_ORIGIN_X/Y, XP_BAR_SCALE, sXpBar's
///        own custom origin) -- same "derive from the actual sprite,
///        don't hardcode a rect" idiom as ArmyLimitWidgetIconRect
///        (HUDWidgetScripts.gml), so this can never drift out of sync with
///        where the bar is actually rendered. 2026-07-13 request: clicking
///        the XP bar opens the Fate Engine overlay -- oUnitControl's
///        click-to-open hit-test (Step_0.gml) reads this.
/// @returns {Struct} { x1, y1, x2, y2 }, all GUI-space.
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
/// @description The XP bar HUD widget for _team: backer + fill + the 4
///        20%-mark milestone reveals + any in-flight tossed Fate Token
///        coins. Owner calls Step() once per Step and Draw() once per
///        Draw GUI, same as BlueprintController/FateDrum.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
function XpBarWidget(_team) constructor {
    team = _team;

    var _count = array_length(global.xpBarMilestoneOffsets);
    milestoneHit    = array_create(_count, false); // has this milestone already triggered THIS age-bar cycle
    milestoneReveal = array_create(_count, 0);      // 0-1 top-to-bottom reveal progress
    tokens          = [];                            // plain structs -- active tossed coins, see SpawnToken
    lastAge         = global.age[team];               // detects an age-up (bar reset) between Steps

    // Catch-up pass -- if _team's xp is already past a mark when this
    // widget is created (e.g. wired in mid-session), show it as already
    // revealed instead of animating/tossing a coin for an event that
    // already happened.
    var _percent = XpBarFillPercent(team);
    for (var i = 0; i < _count; i++) {
        if (_percent >= XpBarMilestonePercent(i)) {
            milestoneHit[i]    = true;
            milestoneReveal[i] = 1;
        }
    }

    /// @function SpawnToken(_x)
    /// @description Launches one tossed Fate Token coin at GUI position
    ///        (_x, XP_BAR_ORIGIN_Y) -- the top edge of the bar, horizontally
    ///        aligned with whichever milestone just triggered. Tumbles up
    ///        then falls back down under XP_BAR_TOKEN_GRAVITY, spinning and
    ///        flipping the whole way, until it's fallen
    ///        XP_BAR_TOKEN_FALL_DISTANCE px past its start (or
    ///        XP_BAR_TOKEN_MAX_LIFE steps have passed, whichever comes
    ///        first) -- see Step().
    /// @param {Real} _x
    static SpawnToken = function(_x) {
        array_push(tokens, {
            x         : _x,
            startY    : XP_BAR_ORIGIN_Y,
            y         : XP_BAR_ORIGIN_Y,
            vy        : -XP_BAR_TOKEN_LAUNCH_SPEED,
            angle     : 0,     // image_angle-equivalent -- fed straight into draw_sprite_ext
            spinSpeed : choose(1, -1) * random_range(XP_BAR_TOKEN_SPIN_MIN, XP_BAR_TOKEN_SPIN_MAX), // clockwise or counterclockwise, per 2026-07-06 request
            flipPhase : 0,     // image_yscale-equivalent -- see Draw()
            age       : 0,
        });
    }

    /// @function Step()
    /// @description Call once per Step. Detects newly-crossed 20%-marks
    ///        (advancing their reveal + tossing a coin), detects an
    ///        age-up (resets every milestone for the new bar), and
    ///        advances every in-flight coin's toss physics.
    static Step = function() {
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
            // Only an already-HIT milestone reveals -- gating this on
            // milestoneHit (not just running it unconditionally) is the
            // 2026-07-06 fix: previously every milestone silently animated
            // in in its first XP_BAR_MILESTONE_REVEAL_STEPS regardless of
            // whether its threshold had actually been reached yet.
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
    /// @description Call once per Draw GUI event. Draws, in order: the
    ///        backer (sXpBar), the fill (sXpBarFill, via
    ///        draw_sprite_part_ext so only _percent of its width shows),
    ///        each milestone's top-to-bottom reveal (sXpBarMilestone, same
    ///        approach but on the vertical axis), and finally every
    ///        in-flight token coin (sFateTokenSmall) -- drawn LAST so coins
    ///        always render in front of the bar, per 2026-07-06 request.
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
            var _yscale = XP_BAR_SCALE * cos(degtorad(_token.flipPhase)); // oscillates the coin's height -- a fake 3D tumble, same idea as a real instance animating image_yscale
            draw_sprite_ext(sFateTokenSmall, 0, _token.x, _token.y, XP_BAR_SCALE, _yscale, _token.angle, c_white, 1);
        }
    }
}
