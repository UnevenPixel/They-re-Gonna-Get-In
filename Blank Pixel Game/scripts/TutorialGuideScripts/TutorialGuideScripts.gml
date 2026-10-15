// Booger's guided-tutorial HUD presence -- rise/settle arch animation, mood
// portrait, typewriter speech bubble, and the scripted step queue that
// drives both. See TutorialGuideScripts.md.

#macro TUTORIAL_GUIDE_SCALE 2 // matches the UI bar's own 2x convention -- see .md

#macro TUTORIAL_GUIDE_SCREEN_FRACTION_X (4/5) // Booger's visual CENTER sits at this fraction of the GUI width -- 2026-08-13 follow-up request, supersedes the original 2/3 value, see .md
#macro TUTORIAL_GUIDE_MIRROR_SHIFT_FRACTION_X 0.75 // 2026-08-16 request ("when booger goes to the left hand side of the UI bar, shift her to the right by 0.75 of her sprite width") -- fraction of her (TUTORIAL_GUIDE_SCALE-scaled) sprite width added to TUTORIAL_GUIDE_MIRROR_X's own anchor formula, mirrored-position only. See that macro's own comment/.md.
#macro TUTORIAL_GUIDE_X (display_get_gui_width() * TUTORIAL_GUIDE_SCREEN_FRACTION_X + (sprite_get_width(sBoogerPortrait) * TUTORIAL_GUIDE_SCALE) / 2) // her draw-anchor X (flipped sprite's right edge) -- derived so _VisualCenterX() lands exactly on the fraction above, see .md
#macro TUTORIAL_GUIDE_MIRROR_X (display_get_gui_width() * (1 - TUTORIAL_GUIDE_SCREEN_FRACTION_X) - (sprite_get_width(sBoogerPortrait) * TUTORIAL_GUIDE_SCALE) / 2 + (sprite_get_width(sBoogerPortrait) * TUTORIAL_GUIDE_SCALE) * TUTORIAL_GUIDE_MIRROR_SHIFT_FRACTION_X) // 2026-08-13 "reappear mirrored" request -- her draw-anchor X while `mirrored` (UNFLIPPED sprite's LEFT edge), solved so her visual center lands on the MIRROR of TUTORIAL_GUIDE_SCREEN_FRACTION_X (1/5 at the default 4/5). 2026-08-16 follow-up: added a further rightward nudge of TUTORIAL_GUIDE_MIRROR_SHIFT_FRACTION_X (0.75) of her own (scaled) sprite width, per request ("shift her to the right by 0.75 of her sprite width"). Since _VisualCenterX()/the hands/bubble positioning all derive from THIS macro (via _AnchorX()), they automatically track the new shifted center too -- see .md.
#macro TUTORIAL_GUIDE_BAR_DRAW_Y 1080 // must match oUnitControl/Draw_64.gml's own sMainUIBarBottom draw call -- see .md

#macro TUTORIAL_GUIDE_TOP_REVEAL       165 // px of Booger's sprite visible above the UI bar's top edge at rest -- see TUTORIAL_GUIDE_REST_RAISE below, kept separate so this figure stays accurate
#macro TUTORIAL_GUIDE_REST_RAISE       128 // additional px _RestY() sits above TOP_REVEAL's own figure -- cumulative across two 2026-08-13 "raise her resting position" requests (64px, then another 64px), see .md
#macro TUTORIAL_GUIDE_OVERSHOOT        48  // px past resting position during the appear/disappear arch
#macro TUTORIAL_GUIDE_OFFSCREEN_MARGIN 40  // extra px below GUI height for the "fully hidden" start/end position -- judgment call

#macro TUTORIAL_GUIDE_RISE_SECONDS   0.45 // start -> overshoot leg duration -- judgment call, see .md
#macro TUTORIAL_GUIDE_SETTLE_SECONDS 0.22 // overshoot -> rest leg duration -- judgment call, see .md

#macro TUTORIAL_MOOD_STANDARD 0 // sBoogerPortrait frame indices
#macro TUTORIAL_MOOD_HAPPY    1
#macro TUTORIAL_MOOD_SAD      2

#macro TUTORIAL_BUBBLE_GAP_X 24 // gap between Booger's visual center and the speech bubble's near (right) edge -- judgment call, see .md
#macro TUTORIAL_BUBBLE_SCREEN_SHIFT_Y -64 // 2026-08-16 request ("move all speech bubbles, except fate engine dealer, up by 64px, real screen space") -- literal/real-screen-space GUI px, negative = up, applied to _BubbleRect()'s `_by` in BOTH the mirrored and non-mirrored branches (Booger's bubble isn't the excluded "fate engine dealer" one). See .md.
#macro TUTORIAL_BUBBLE_BUFFER 8 // text buffer from the bubble's top-left corner, both axes -- per request. 2026-08-15 follow-up: the bubble sprite itself no longer draws scaled up (see Draw_Bubble()/_BubbleRect()), so this is now applied UNSCALED (native px, matching the bubble's own native draw size) -- was previously ×TUTORIAL_GUIDE_SCALE, see .md.
#macro TUTORIAL_BUBBLE_MIRRORED_TEXT_OFFSET_X 42 // 2026-08-15 request -- X-axis text offset from the bubble rect's LEFT edge, used ONLY while mirrored (see Draw_Bubble()). sSpeechBubbleInGame isn't symmetric (has a tail baked into its art, off-center within its own drawing space), so the plain TUTORIAL_BUBBLE_BUFFER offset (which reads fine non-mirrored) sits wrong once the sprite is flipped for the mirrored layout. 2026-08-15 follow-up (round 2): applied UNSCALED now, same reasoning as TUTORIAL_BUBBLE_BUFFER above -- was native-sprite-space ×TUTORIAL_GUIDE_SCALE as of the FIRST follow-up correction, now that the bubble itself draws at native scale that multiplication is gone too. 2026-08-16 follow-up: bumped 26 -> 42 ("adjust text alignment for flipped speech bubble, moved 16px to the right, real screen space"). Text WRAP WIDTH is unaffected by THIS macro -- only the text's draw-origin X changes, see .md.
#macro TUTORIAL_BUBBLE_TEXT_MAX_WIDTH 312 // native px -- 2026-08-13 request: the sprite has a tail with a horizontal gap on the right side, text must not run into it. Drives the wrap width directly, NOT derived from sprite_get_width() -- see .md. 2026-08-15 follow-up: no longer ×TUTORIAL_GUIDE_SCALE'd at Say()'s point of use, now that the bubble sprite draws at native scale -- see .md.

#macro TUTORIAL_BUBBLE_FRAME_0_HEIGHT 169 // native vertical space, sSpeechBubbleInGame frame 0
#macro TUTORIAL_BUBBLE_FRAME_1_HEIGHT 200 // frame 1
#macro TUTORIAL_BUBBLE_FRAME_2_HEIGHT 230 // frame 2 -- also the sprite's full native height (no top padding)

#macro TUTORIAL_BUBBLE_TYPEWRITER_CHARS_PER_SECOND 50 // 2026-08-16 request ("increase speed of typewriter effect by 25%") -- was 40, 40*1.25=50. DIALOGUE_TYPEWRITER_CHARS_PER_SECOND (DialogueOverlayScripts.gml, a separate system never touched by this conversation) was deliberately left alone -- see .md.

#macro TUTORIAL_GUIDE_HIGHLIGHT_COLOR make_color_rgb(230, 162, 43) // "orange-golden" -- judgment call, no existing macro matched, see .md
#macro TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG "c_tutorialHighlight" // 2026-08-13 -- Scribble inline tag for TUTORIAL_GUIDE_HIGHLIGHT_COLOR, for coloring individual WORDS within an otherwise default-colored line (e.g. "Stationed"/"Deployed"/"Ledger") -- registered via scribble_color_set(), see _EnsureCustomColorsRegistered() below. The line-level `Say()` `_color` param still uses the raw TUTORIAL_GUIDE_HIGHLIGHT_COLOR value directly (no tag needed there, see .md).

// "3 W's" resource-line colors -- 2026-08-13 request ("color water blue, wheat gold, wood brown"). Water
// reuses Scribble's built-in [c_blue] tag (already pre-registered, same convention PLOT_HOVER_GOOD/BAD_COLOR_TAG
// use for c_lime/c_red -- BlueprintScripts.gml). Wheat/wood have no matching built-in, so they're registered as
// new custom Scribble tags via scribble_color_set() -- see _EnsureCustomColorsRegistered() below and .md.
#macro TUTORIAL_RESOURCE_WATER_COLOR_TAG "c_blue"
#macro TUTORIAL_RESOURCE_WHEAT_COLOR_TAG "c_tutorialWheatGold"
#macro TUTORIAL_RESOURCE_WOOD_COLOR_TAG  "c_tutorialWoodBrown"
#macro TUTORIAL_RESOURCE_WHEAT_COLOR make_color_rgb(212, 175, 55) // "gold" -- judgment call
#macro TUTORIAL_RESOURCE_WOOD_COLOR  make_color_rgb(92, 64, 51)   // "brown" -- judgment call

/// @function ChooseTutorialBubbleFrame(_requiredHeight)
/// @description Smallest of frames 0/1/2 tall enough for _requiredHeight, capped at 2 (same "smallest that fits, cap at the biggest" shape as ChooseHoverCardSprite, HoverCardScripts.gml). See .md re: overflow.
/// @param {Real} _requiredHeight Native (unscaled) px -- 2026-08-15 follow-up: both callers (TutorialGuideScripts.gml/DealerIntroScripts.gml) stopped scaling this by their own SCALE macro once their bubble sprites moved to a native (1x) draw scale, see .md.
/// @returns {Real} 0, 1, or 2.
function ChooseTutorialBubbleFrame(_requiredHeight) {
    if (_requiredHeight <= TUTORIAL_BUBBLE_FRAME_0_HEIGHT) return 0;
    if (_requiredHeight <= TUTORIAL_BUBBLE_FRAME_1_HEIGHT) return 1;
    return 2;
}

/// @function TutorialGuide()
/// @description Booger's guided-tutorial HUD presence. Owner calls Update()
///        once per Step, and Draw_Behind()/Draw_Front()/Draw_Bubble() (2026-08-14,
///        now THREE draw-order points, not two -- see Draw_Bubble()'s own doc
///        comment) at the draw-order points described in TutorialGuideScripts.md
///        while state != "hidden".
function TutorialGuide() constructor {
    state         = "hidden"; // "hidden" | "appearing" | "idle" | "disappearing"
    animTimer     = 0;        // seconds into the current appear/disappear transition
    y             = 0;        // current GUI-space Y of Booger's (bottom) origin
    handsFrame    = 0;        // sBoogerHands frame index -- 2026-08-13 "switch her hand sprite to index 1" mirror-interlude request, see .md
    mirrored      = false;    // 2026-08-13 "reappear mirrored" request -- true while she's on the opposite (mirrored) side of the screen, facing the opposite direction. See .md and the mirror-interlude fields below.
    pendingMirrorTransition = undefined; // "toMirrored" | "toNormal" | undefined -- set right before Hide() when the NEXT step needs a mirror swap first; consumed once Update()'s "disappearing" case confirms she's fully hidden. See .md.

    mood = TUTORIAL_MOOD_STANDARD;

    bubbleRawText          = ""; // plain pre-Scribble string, AS PASSED TO Say() -- includes any Scribble command/color tags verbatim, kept only for reference
    bubbleVisibleText      = ""; // 2026-08-15 bugfix -- the SAME text after Scribble parses out its own tags (via bubbleText.get_text(), see Say()). The typewriter's char-count bound and the blip system's per-character lookup both use THIS, not bubbleRawText -- see Say()/_UpdateBubble()/.md for why comparing against the raw (tagged) string's length caused the typewriter/blip audio to run on well after the visible text had already finished revealing.
    bubbleRevealChars      = 0;
    typewriterDone         = false;
    bubbleFrame            = 0;
    bubbleColor            = DIALOGUE_SPEAKER_TEXT_COLOR; // default per request -- "the speaker font color we came up with earlier"
    speakerSoundFinishTime = current_time; // per-char blip throttle -- mirrors DialogueOverlay's own, duplicated not shared, see .md

    bubbleText = scribble("", "__tutorialGuideBubble__")
        .starting_format(HOVER_CARD_BODY_FONT, DIALOGUE_SPEAKER_TEXT_COLOR)
        .align(fa_left, fa_top);

    // scriptPhases: array of { steps: [{text,mood,color,frame}, ...], allowedBuildingTypes: [obj, ...] }.
    // A "phase" is one restricted step -- its lines play in order, and on the LAST line a click just
    // dismisses Booger (Hide()) while the phase's restriction stays active; CompleteRestriction() (fired
    // externally once the required building is actually placed) is what starts the NEXT phase, if any.
    // 2026-08-13 request (chained "place water pump" -> "place wheat/sawmill" steps). See .md.
    scriptPhases        = [];
    phaseIndex          = -1;
    scriptIndex         = -1;
    pendingScriptStart  = false; // true while waiting for the appear animation to finish before a phase's first Say()
    pendingPhaseAdvance = false; // true once CompleteRestriction() has queued the next phase but she isn't fully hidden yet -- see Update()'s "disappearing" case
    scriptDismissed     = false; // 2026-08-14 -- true once the player has clicked through this phase's LAST line. _TryAdvancePhase() now requires this in ADDITION to the requirement checks, so a player who places the required building(s) WHILE she's still mid-script doesn't cut her dialogue short and jump straight to the next phase -- see .md ("skips over forcing you" bug).

    restrictionActive      = false; // gates oUnitControl/Step_0.gml's input -- see .md
    allowedBuildingTypes    = [];   // array -- TryPlaceBlueprint's gate accepts ANY type in this list for the whole phase, see .md
    remainingRequiredTypes  = [];   // subset of allowedBuildingTypes not yet placed THIS phase -- an independent COPY, not an alias of allowedBuildingTypes (see _StartNextPhase()'s shared-reference note, same hazard global.blueprints already guards against elsewhere in this project). Phase completes once this is empty -- 2026-08-13 "continue when both are placed" request, see .md.
    requireInside           = false; // 2026-08-13 (Peasant Ward phase) -- per-phase plot-side requirement. false = TryPlaceBlueprint's gate requires !_plot.inside (every earlier phase), true = requires _plot.inside. See .md.
    trainingRequirements    = [];   // array of { unitType, remaining } -- 2026-08-13 (Peasant Ward phase) request: "train N of this unit" as a SEPARATE requirement kind from building placement. Independent per-phase copies, same reasoning as remainingRequiredTypes. See .md and NotifyUnitTrained().

    fateEngineLocked = false; // 2026-08-13 -- set true by StartIntroScript(), deliberately NEVER cleared by this pass ("gameplay other than the fate engine interface opens up"). Gates oUnitControl/Step_0.gml's XP-bar-click-opens-Fate-Engine path independently of restrictionActive, since that clears once the WHOLE guided tutorial ends but the Fate Engine should stay locked past that point. See .md.

    /// @function _EnsureCustomColorsRegistered()
    /// @description One-time Scribble custom-color registration for every tutorial-only inline tag: the "3 W's" line's wheat/wood tags, and (2026-08-13) TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG for inline-highlighting individual words like "Stationed"/"Deployed"/"Ledger". `static _registered` guards this to fire only once EVER per game session (not once per match/per TutorialGuide() construction) since scribble_color_set() internally calls scribble_refresh_everything(), a real cost the library's own docs warn against paying repeatedly. See .md.
    static _EnsureCustomColorsRegistered = function() {
        static _registered = false;
        if (_registered) return;
        _registered = true;
        scribble_color_set("c_tutorialWheatGold", TUTORIAL_RESOURCE_WHEAT_COLOR);
        scribble_color_set("c_tutorialWoodBrown", TUTORIAL_RESOURCE_WOOD_COLOR);
        scribble_color_set("c_tutorialHighlight", TUTORIAL_GUIDE_HIGHLIGHT_COLOR);
    }
    _EnsureCustomColorsRegistered();

    /// @function _RiseFraction()
    /// @description Fraction of the total appear/disappear duration spent on the start<->overshoot leg.
    /// @returns {Real}
    static _RiseFraction = function() {
        return TUTORIAL_GUIDE_RISE_SECONDS / (TUTORIAL_GUIDE_RISE_SECONDS + TUTORIAL_GUIDE_SETTLE_SECONDS);
    }

    /// @function _BarTopY()
    /// @description The bottom UI bar's top edge, GUI space. Must stay in sync with oUnitControl/Draw_64.gml's own sMainUIBarBottom draw call -- see .md.
    /// @returns {Real}
    static _BarTopY = function() {
        return TUTORIAL_GUIDE_BAR_DRAW_Y - sprite_get_height(sMainUIBarBottom) * TUTORIAL_GUIDE_SCALE;
    }

    /// @function _AnchorX()
    /// @description Her current draw-anchor X -- TUTORIAL_GUIDE_X normally, TUTORIAL_GUIDE_MIRROR_X while mirrored. See .md.
    /// @returns {Real}
    static _AnchorX = function() {
        return mirrored ? TUTORIAL_GUIDE_MIRROR_X : TUTORIAL_GUIDE_X;
    }

    /// @function _DrawXScale()
    /// @description Her current draw xscale -- negative (flipped) normally, positive (natural/unflipped) while mirrored, so she visually faces the opposite way once mirrored to the other side of the screen. See .md.
    /// @returns {Real}
    static _DrawXScale = function() {
        return mirrored ? TUTORIAL_GUIDE_SCALE : -TUTORIAL_GUIDE_SCALE;
    }

    /// @function _HandsXScale()
    /// @description sBoogerHands' current draw xscale -- 2026-08-14 "when Booger is flipped, flip the hands too" request. Deliberately the OPPOSITE sign convention from _DrawXScale(): the hands sprite's own natural/unflipped art already reads correctly at the default (non-mirrored) position (positive scale, unchanged from before this request), so it's the MIRRORED case that needs flipping (negative) to keep facing in lockstep with the portrait's own flip. See .md.
    /// @returns {Real}
    static _HandsXScale = function() {
        return mirrored ? -TUTORIAL_GUIDE_SCALE : TUTORIAL_GUIDE_SCALE;
    }

    /// @function _VisualCenterX()
    /// @description Horizontal center of Booger's DRAWN sprite -- NOT her origin/anchor X. Accounts for BOTH the normal flip and the mirrored (2026-08-13) case -- see .md.
    /// @returns {Real}
    static _VisualCenterX = function() {
        var _halfWidth = (sprite_get_width(sBoogerPortrait) * TUTORIAL_GUIDE_SCALE) / 2;
        return mirrored ? (_AnchorX() + _halfWidth) : (_AnchorX() - _halfWidth);
    }

    /// @function _RestY()
    /// @description Booger's settled Y (bottom-origin) -- positions her so TUTORIAL_GUIDE_TOP_REVEAL px of her sprite sit above the bar's top edge, then raises that another TUTORIAL_GUIDE_REST_RAISE px (128, cumulative across two same-day "raise her resting position" requests). See .md.
    /// @returns {Real}
    static _RestY = function() {
        return _BarTopY() - TUTORIAL_GUIDE_TOP_REVEAL - TUTORIAL_GUIDE_REST_RAISE + sprite_get_height(sBoogerPortrait) * TUTORIAL_GUIDE_SCALE;
    }

    /// @function _OvershootY()
    /// @description The arch's peak Y -- TUTORIAL_GUIDE_OVERSHOOT px above (past) _RestY().
    /// @returns {Real}
    static _OvershootY = function() {
        return _RestY() - TUTORIAL_GUIDE_OVERSHOOT;
    }

    /// @function _StartY()
    /// @description Fully-hidden Y -- her sprite's top sits at or below the visible GUI height, plus a safety margin.
    /// @returns {Real}
    static _StartY = function() {
        return display_get_gui_height() + sprite_get_height(sBoogerPortrait) * TUTORIAL_GUIDE_SCALE + TUTORIAL_GUIDE_OFFSCREEN_MARGIN;
    }

    /// @function _AnimCurveY(_t)
    /// @description The shared appear/disappear arch curve: _t 0 = _StartY(), _t = _RiseFraction() = _OvershootY() (the arch peak), _t 1 = _RestY(). Appearing samples this forward (_t = animTimer progress); disappearing samples it backward (_t = 1 - animTimer progress) -- same curve, same smoothing, played in reverse, per request. See .md.
    /// @param {Real} _t 0..1.
    /// @returns {Real}
    static _AnimCurveY = function(_t) {
        var _riseFraction = _RiseFraction();
        var _startY     = _StartY();
        var _overshootY = _OvershootY();
        var _restY      = _RestY();

        if (_t <= _riseFraction) {
            var _local = (_riseFraction <= 0) ? 1 : (_t / _riseFraction);
            var _eased = 1 - power(1 - _local, 3); // ease-out cubic -- decelerates INTO the overshoot peak, see .md
            return lerp(_startY, _overshootY, _eased);
        } else {
            var _local2 = (_riseFraction >= 1) ? 1 : ((_t - _riseFraction) / (1 - _riseFraction));
            var _eased2 = _local2 * _local2 * (3 - 2 * _local2); // smoothstep -- gentle settle-back, see .md
            return lerp(_overshootY, _restY, _eased2);
        }
    }

    /// @function Show()
    /// @description Begins the appear animation from fully hidden. No-op if already appearing/idle.
    /// @returns {Struct.TutorialGuide} self
    static Show = function() {
        if (state == "appearing" || state == "idle") return self;
        state     = "appearing";
        animTimer = 0;
        y         = _StartY();
        return self;
    }

    /// @function Hide()
    /// @description Begins the disappear animation (reverse of Show(), same curve). No-op if already hidden/disappearing.
    /// @returns {Struct.TutorialGuide} self
    static Hide = function() {
        if (state == "hidden" || state == "disappearing") return self;
        state     = "disappearing";
        animTimer = 0;
        return self;
    }

    /// @function Say(_text, _mood, _color, _forceFrame)
    /// @description Opens a new speech bubble: resets the typewriter, picks the mood portrait frame, sizes the bubble frame to fit _text (or uses _forceFrame if given, skipping auto-fit entirely), and sets the text color. Embed Scribble command tags (e.g. "[wave]...[/wave]") directly in _text, same convention DialogueOverlay's dialogue trees use.
    /// @param {String} _text
    /// @param {Real} [_mood] TUTORIAL_MOOD_STANDARD/_HAPPY/_SAD. Defaults to STANDARD.
    /// @param {Color} [_color] Defaults to DIALOGUE_SPEAKER_TEXT_COLOR.
    /// @param {Real} [_forceFrame] If given (0/1/2), used directly instead of ChooseTutorialBubbleFrame's auto-fit -- see .md re: intro script forcing frame 0.
    /// @returns {Struct.TutorialGuide} self
    static Say = function(_text, _mood = TUTORIAL_MOOD_STANDARD, _color = undefined, _forceFrame = undefined) {
        mood        = _mood;
        bubbleColor = (_color != undefined) ? _color : DIALOGUE_SPEAKER_TEXT_COLOR;

        bubbleRawText          = _text;
        bubbleRevealChars      = 0;
        typewriterDone         = false;
        speakerSoundFinishTime = current_time; // allow an immediate blip on this bubble's first revealed character

        var _wrapW = TUTORIAL_BUBBLE_TEXT_MAX_WIDTH; // 2026-08-15 follow-up -- no longer ×TUTORIAL_GUIDE_SCALE, see macro comment/.md
        bubbleText = scribble(_text, "__tutorialGuideBubble__")
            .starting_format(HOVER_CARD_BODY_FONT, bubbleColor)
            .align(fa_left, fa_top)
            .wrap(_wrapW)
            .allow_text_getter(); // 2026-08-15 bugfix -- required for get_text() below, see bubbleVisibleText's field comment/.md

        // 2026-08-15 bugfix: cache the TAG-STRIPPED text once here, rather than measuring typewriter
        // progress against bubbleRawText's raw length (which includes any [wave]/[shake]/[c_tag] markup
        // characters -- inflating the count well past the actual number of VISIBLE glyphs Scribble ever
        // reveals, so typewriterDone/the blip system kept running long after the text visually finished).
        // See bubbleVisibleText's field comment/.md.
        bubbleVisibleText = bubbleText.get_text();

        if (_forceFrame != undefined) {
            bubbleFrame = _forceFrame;
        } else {
            var _requiredHeight = bubbleText.get_height() + (TUTORIAL_BUBBLE_BUFFER * 2); // 2026-08-15 follow-up -- no longer ×TUTORIAL_GUIDE_SCALE, see .md
            bubbleFrame = ChooseTutorialBubbleFrame(_requiredHeight);
        }

        return self;
    }

    /// @function StartIntroScript()
    /// @description The guided-tutorial's four chained phases (2026-08-13, extended three times same day): phase 0
    ///        is the 4-line Water Pump intro (forces the smallest bubble frame -- see .md re: "the largest one
    ///        is too big for how much text is here"); phase 1 is the 5-line "3 W's" follow-up, requiring BOTH
    ///        a Wheat Field and a Sawmill; phase 2 is the 3-line Peasant Ward follow-up, requiring the Ward
    ///        placed INSIDE the walls (the first `requireInside` phase -- every earlier phase required
    ///        outside) plus training 2 Peasants (the first trainingRequirements phase); phase 3 is the 8-line
    ///        Stationed/Deployed explainer -- the first phase with NO gameplay-action requirement at all (pure
    ///        dialogue, completed purely by clicking through the last line -- see _UpdateBubble()), including a
    ///        mid-script mirror-disappear-reappear interlude (see the `transition` step field and
    ///        pendingMirrorTransition/mirrored). Completing phase 3 ends the WHOLE guided tutorial: unlocks
    ///        normal gameplay (restrictionActive clears) EXCEPT the Fate Engine (fateEngineLocked stays true,
    ///        set below), and resumes the AI (unpausing AIBrain.Step()) -- see _TryAdvancePhase()'s final-phase
    ///        branch. Each phase fires automatically once the previous one's restriction is fully satisfied
    ///        (see CompleteRestriction()/NotifyUnitTrained()/_TryAdvancePhase()/_StartNextPhase()). Begins the
    ///        appear animation; phase 0's first Say() fires once she's fully risen.
    /// @returns {Struct.TutorialGuide} self
    static StartIntroScript = function() {
        fateEngineLocked = true; // locked for the ENTIRE guided tutorial, not just while restrictionActive -- see .md and the fateEngineLocked field comment

        scriptPhases = [
            {
                steps: [
                    { text: "Okay! Let's review the basics! Did you know goblins can go up to 30 days without eating? I mean, we would rather eat every second of every day...", mood: TUTORIAL_MOOD_STANDARD, color: undefined, frame: 0 },
                    { text: "[wave]mmmm.... meat....[/wave]", mood: TUTORIAL_MOOD_HAPPY, color: undefined, frame: 0 },
                    { text: "But as long as we have water, we can survive!", mood: TUTORIAL_MOOD_HAPPY, color: undefined, frame: 0 },
                    { text: "Go ahead and build a water pump OUTSIDE your castle walls!", mood: TUTORIAL_MOOD_STANDARD, color: TUTORIAL_GUIDE_HIGHLIGHT_COLOR, frame: 0 },
                ],
                allowedBuildingTypes: [oWaterPump],
            },
            {
                steps: [
                    { text: "Resource production blueprints get a huge benefit if you build them outside the main walls! The city is too crowded and the ground is too hard to be efficient. Place resource blueprints out in the lush, fertile land for cheaper and faster production!", mood: TUTORIAL_MOOD_STANDARD, color: undefined, frame: undefined },
                    { text: "Now we can use the water to build a wheat farm and a sawmill! If you want to win, you have to remember the 3 W's!", mood: TUTORIAL_MOOD_HAPPY, color: undefined, frame: undefined },
                    { text: $"[c_white]{ResourceIconTag("water")}[/c][{TUTORIAL_RESOURCE_WATER_COLOR_TAG}]Water[/c], [c_white]{ResourceIconTag("wheat")}[/c][{TUTORIAL_RESOURCE_WHEAT_COLOR_TAG}]wheat[/c], and [c_white]{ResourceIconTag("wood")}[/c][{TUTORIAL_RESOURCE_WOOD_COLOR_TAG}]wood[/c]!", mood: TUTORIAL_MOOD_HAPPY, color: undefined, frame: undefined }, // 2026-08-15 bugfix: icon tags wrapped in an explicit [c_white] scope so each icon renders untinted (its own natural sprite colors) instead of bleeding into the immediately-following resource-name color tag -- see .md
                    { text: "These are the foundation of any kingdom! Remember to build them outside your walls if you want a MASSIVE bonus.", mood: TUTORIAL_MOOD_STANDARD, color: undefined, frame: undefined },
                    { text: "Build your Wheat Farm and Sawmill once you have the water to do so!", mood: TUTORIAL_MOOD_STANDARD, color: TUTORIAL_GUIDE_HIGHLIGHT_COLOR, frame: undefined },
                ],
                allowedBuildingTypes: [oWheatField, oSawmill],
            },
            {
                steps: [
                    { text: "Now! Let's train some DEADLY peasants! *tee hee*", mood: TUTORIAL_MOOD_HAPPY, color: undefined, frame: undefined },
                    { text: "Unlike resource production blueprints, unit production blueprints get a bonus when built INSIDE of the castle walls.", mood: TUTORIAL_MOOD_STANDARD, color: undefined, frame: undefined },
                    { text: "Go ahead and place one down. Once its built, queue up a few of those yummy looking guys!", mood: TUTORIAL_MOOD_STANDARD, color: TUTORIAL_GUIDE_HIGHLIGHT_COLOR, frame: undefined },
                ],
                allowedBuildingTypes: [oPeasantWard],
                requireInside: true,
                trainingRequirements: [{ unitType: oPeasantUnit, count: 2 }],
            },
            {
                // Every Stationed/Deployed/Ledger occurrence colored per request -- treated as a
                // keyword-highlight rule for whichever term(s) the line's own parenthetical named, not a
                // literal "only the first occurrence" reading. See .md.
                steps: [
                    { text: $"Now here's the fun part! Units are always in one of two states: [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]Stationed[/c] or [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]Deployed[/c]!", mood: TUTORIAL_MOOD_HAPPY, color: undefined, frame: undefined },
                    { text: $"If a unit is trained up inside the city, it is automatically [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]Stationed[/c]. When a unit is [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]stationed[/c], they sit on top of the walls and usually don't participate in combat.", mood: TUTORIAL_MOOD_STANDARD, color: undefined, frame: undefined },
                    { text: $"I can already see the look on your face! What's the point in that, right? Well, [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]Stationed[/c] units provide bonuses to your kingdom! Each one has a different effect!", mood: TUTORIAL_MOOD_HAPPY, color: undefined, frame: undefined },
                    { text: $"When a peasant is [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]Stationed[/c], resource production buildings work faster. When a knight is [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]stationed[/c], your [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]Deployed[/c] units deal more damage!", mood: TUTORIAL_MOOD_STANDARD, color: undefined, frame: undefined },
                    { text: "If you place a training blueprint outside the walls, you won't get the cheaper build cost and boost in production speed.", mood: TUTORIAL_MOOD_STANDARD, color: undefined, frame: undefined },
                    { text: $"BUT, the unit WILL come out [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]deployed[/c] and ready to fight immediately!", mood: TUTORIAL_MOOD_HAPPY, color: undefined, frame: undefined },
                    { text: $"You can always change which units are [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]Stationed[/c] and [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]Deployed[/c] by accessing my [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]Ledger[/c]. Just know it costs a little bit of resources and takes some time for them to transition.", mood: TUTORIAL_MOOD_STANDARD, color: undefined, frame: undefined, transition: "mirror" },
                    { text: "And that's really all I know! Sorry, I can't be more helpful. I've never actually been in a battle myself, hehehehe... If I think of anything else, I'll let you know right away! Access my ledger, deploy those peasants, and go kill those Talos fuckers!", mood: TUTORIAL_MOOD_HAPPY, color: undefined, frame: undefined, transition: "unmirror" },
                ],
                allowedBuildingTypes: [],
            },
        ];
        phaseIndex = -1;
        _StartNextPhase();
        return self;
    }

    /// @function _CurrentSteps()
    /// @description The active phase's step array, or [] before any phase has started.
    /// @returns {Array<Struct>}
    static _CurrentSteps = function() {
        if (phaseIndex < 0 || phaseIndex >= array_length(scriptPhases)) return [];
        return scriptPhases[phaseIndex].steps;
    }

    /// @function _StartNextPhase()
    /// @description Advances phaseIndex, applies the new phase's restriction (placement types/side + any unit-training requirements), and begins the appear animation. Called both from StartIntroScript() (phase 0) and from CompleteRestriction()/NotifyUnitTrained()/Update() (later phases, once Booger is confirmed fully hidden -- see .md).
    static _StartNextPhase = function() {
        phaseIndex += 1;
        var _phase = scriptPhases[phaseIndex];
        allowedBuildingTypes = _phase.allowedBuildingTypes;
        requireInside        = (_phase[$ "requireInside"] != undefined) ? _phase[$ "requireInside"] : false; // [$ ...] accessor -- SAFE for a possibly-absent struct key (dot notation THROWS "not set before reading it" if the literal never declared the key at all, unlike a plain undefined value -- see .md, this was a real bug: every earlier phase's literal omits requireInside entirely)

        // Independent COPY, not `= _phase.allowedBuildingTypes` again -- GML arrays are reference types,
        // so that would make remainingRequiredTypes literally the SAME array as allowedBuildingTypes and
        // deleting a satisfied requirement from one would corrupt the other (which needs to stay complete
        // all phase long, so re-placing an already-satisfied type is still allowed, just not required).
        // Same shared-reference hazard oMatchControl/Create_0.gml's global.blueprints comment already
        // documents elsewhere in this project. See .md.
        remainingRequiredTypes = [];
        for (var i = 0; i < array_length(_phase.allowedBuildingTypes); i++) {
            array_push(remainingRequiredTypes, _phase.allowedBuildingTypes[i]);
        }

        // Same independent-copy reasoning as above, plus each entry needs its OWN fresh { unitType,
        // remaining } struct (not a reference to the phase definition's { unitType, count } struct) since
        // `remaining` gets mutated in place as NotifyUnitTrained() fires -- see .md.
        trainingRequirements = [];
        var _phaseTraining = (_phase[$ "trainingRequirements"] != undefined) ? _phase[$ "trainingRequirements"] : []; // [$ ...] accessor -- same missing-key-throws hazard as requireInside above, see .md
        for (var i = 0; i < array_length(_phaseTraining); i++) {
            array_push(trainingRequirements, { unitType: _phaseTraining[i].unitType, remaining: _phaseTraining[i].count });
        }

        mirrored  = false; // defensive reset -- no phase today relies on carrying a mirror state INTO it from the previous one; see .md
        handsFrame = 0;    // same defensive reset, see .md

        restrictionActive = true;
        scriptIndex        = -1;
        scriptDismissed    = false; // 2026-08-14 -- see field comment above
        pendingScriptStart = true;
        Show();
    }

    /// @function _AdvanceScript()
    /// @description Moves to the next scripted line within the current phase, or stays parked on the last one (a click there dismisses Booger instead -- see _UpdateBubble()).
    static _AdvanceScript = function() {
        scriptIndex += 1;
        var _steps = _CurrentSteps();
        if (scriptIndex >= array_length(_steps)) return;
        var _step = _steps[scriptIndex];
        Say(_step.text, _step.mood, _step.color, _step.frame);
    }

    /// @function CompleteRestriction(_buildingType)
    /// @description Called once a placement satisfying the current phase's restriction actually succeeds (see BlueprintScripts.gml's TryPlaceBlueprint). Checks _buildingType off remainingRequiredTypes if present, then defers to _TryAdvancePhase() -- which only actually advances once EVERY requirement (placement types AND any unit-training counts, see NotifyUnitTrained()) is satisfied. See .md.
    /// @param {Asset.GMObject} _buildingType The type that was just successfully placed.
    /// @returns {Struct.TutorialGuide} self
    static CompleteRestriction = function(_buildingType) {
        var _index = array_get_index(remainingRequiredTypes, _buildingType);
        if (_index != -1) array_delete(remainingRequiredTypes, _index, 1);
        _TryAdvancePhase();
        return self;
    }

    /// @function NotifyUnitTrained(_team, _unitType)
    /// @description Called from TrainingScripts.gml's TrainingSpawnUnit() every time ANY unit finishes training (both the "inside, station-only" and "outside, live unit" branches) -- 2026-08-13 Peasant Ward phase request ("train 2 peasants from it"). No-ops unless the guided restriction is actually active for the player and _unitType is one this phase is still waiting on; otherwise checks one off trainingRequirements' matching entry and defers to _TryAdvancePhase(). See .md re: this being a TEAM-WIDE count, not tied to the specific Ward instance.
    /// @param {Real} _team
    /// @param {Asset.GMObject} _unitType
    /// @returns {Struct.TutorialGuide} self
    static NotifyUnitTrained = function(_team, _unitType) {
        if (_team != TEAM.PLAYER || !restrictionActive) return self;

        for (var i = 0; i < array_length(trainingRequirements); i++) {
            var _req = trainingRequirements[i];
            if (_req.unitType == _unitType && _req.remaining > 0) {
                _req.remaining -= 1;
                break;
            }
        }
        _TryAdvancePhase();
        return self;
    }

    /// @function _TryAdvancePhase()
    /// @description Shared completion check for CompleteRestriction()/NotifyUnitTrained()/_UpdateBubble()'s last-line handler -- the current phase only actually ends once (a) scriptDismissed (the player has clicked through her last line, 2026-08-14) AND (b) remainingRequiredTypes is empty AND (c) every trainingRequirements entry's `remaining` has reached 0. The scriptDismissed check exists specifically so a player who places the required building(s) WHILE she's still mid-script doesn't immediately cut her dialogue short and jump to the next phase -- see .md ("skips over forcing you" bug). No-ops early (and harmlessly) if restrictionActive is already false, since callers can fire after the phase has already completed. Once satisfied: clears the restriction, and if another phase is queued, starts it (immediately if Booger's already hidden -- e.g. the player clicked through to dismiss her already -- otherwise once Update() confirms she's fully hidden, see its "disappearing" case). If this was the last phase, just hides her for good. See .md.
    static _TryAdvancePhase = function() {
        if (!restrictionActive) return;
        if (!scriptDismissed) return;
        if (array_length(remainingRequiredTypes) > 0) return;
        for (var i = 0; i < array_length(trainingRequirements); i++) {
            if (trainingRequirements[i].remaining > 0) return;
        }

        restrictionActive    = false;
        allowedBuildingTypes = [];

        if (phaseIndex + 1 < array_length(scriptPhases)) {
            // 2026-08-15 bugfix: pendingPhaseAdvance must ONLY be set true on the DEFERRED leg (she's
            // still visible, Hide() needs to play out before Update()'s "disappearing" case can safely
            // call _StartNextPhase()) -- NOT on the immediate leg, where _StartNextPhase() already runs
            // right here. The old code set it true unconditionally before branching, so the immediate
            // leg left it stale-true forever after (nothing ever cleared it there). The NEXT phase's own
            // eventual Hide() (e.g. its last line being dismissed, regardless of whether THAT phase's own
            // requirements were actually satisfied) would then be misread by Update()'s "disappearing"
            // case as a still-pending advance from the OLD transition, firing _StartNextPhase() early and
            // skipping the new phase's requirement gate entirely. This is what let a player reach the
            // Peasant Ward phase without having placed the Wheat Field/Sawmill -- see .md.
            if (state == "hidden") {
                _StartNextPhase();
            } else {
                pendingPhaseAdvance = true;
                Hide();
            }
        } else {
            // Whole guided tutorial ends here. CompleteTutorial() clears global.tutorialActive (unpausing
            // AIBrain.Step(), which otherwise early-returns every frame) and idempotently marks the save
            // data's tutorialCompleted flag. 2026-08-16 follow-up: no longer resets oAIControl.brain.hesitancy
            // here -- per request ("remove starting hesitancy after last booger dialogue"), the AI now just
            // resumes with whatever hesitancy it already has (still its untouched constructor starting value,
            // since AIBrain.Step() never ran during the tutorial to move it). fateEngineLocked is deliberately
            // left true -- see its field comment. 2026-08-13. See .md.
            pendingPhaseAdvance = false;
            CompleteTutorial();
            Hide();
            global.dealerIntro.BeginWait(); // 2026-08-14 follow-up -- arms The Dealer's ambush scene (60s wait, then her portrait intro) the moment normal control returns to the player. See DealerIntroScripts.md.
        }
    }

    /// @function _BoogerRect()
    /// @description Click-hit-test rect for Booger herself, GUI space -- clipped to just the portion currently visible above the bar (the part hidden behind the bar shouldn't register a click). Shared by the hit-test and (implicitly, via the same geometry) the Draw_Behind() sprite call. Branches on `mirrored` (2026-08-13): normal her anchor is the sprite's right edge (extends leftward), mirrored her anchor is the left edge (extends rightward) -- see _AnchorX()/.md.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _BoogerRect = function() {
        var _anchorX = _AnchorX();
        var _width   = sprite_get_width(sBoogerPortrait) * TUTORIAL_GUIDE_SCALE;
        return {
            x1: mirrored ? _anchorX : (_anchorX - _width),
            y1: y - sprite_get_height(sBoogerPortrait) * TUTORIAL_GUIDE_SCALE,
            x2: mirrored ? (_anchorX + _width) : _anchorX,
            y2: _BarTopY(),
        };
    }

    /// @function _BubbleRect()
    /// @description The speech bubble's drawn rect, GUI space -- shared by _DrawBubble() (draw + text placement) and the click-hit-test, so the two can't drift apart. Branches on `mirrored` (2026-08-13): normal the bubble sits to the LEFT of her visual center (near/right edge = x2); mirrored it sits to the RIGHT (near/left edge = x1) -- true mirror image of the normal layout, see .md. 2026-08-15 follow-up ("don't scale up the text bubbles anymore"): _bubbleWidth/_frameSpace no longer ×TUTORIAL_GUIDE_SCALE (the sprite now draws at native scale, see Draw_Bubble()). 2026-08-16 follow-up: `_by` now includes TUTORIAL_BUBBLE_SCREEN_SHIFT_Y (up 64px, real screen space, both branches) -- `_bx`/`_by` remain deliberately-adjustable ANCHOR terms, see .md.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _BubbleRect = function() {
        var _by          = _BarTopY() + TUTORIAL_BUBBLE_SCREEN_SHIFT_Y; // 2026-08-16 request, see macro comment/.md
        var _frameSpace  = [TUTORIAL_BUBBLE_FRAME_0_HEIGHT, TUTORIAL_BUBBLE_FRAME_1_HEIGHT, TUTORIAL_BUBBLE_FRAME_2_HEIGHT][bubbleFrame];
        var _bubbleWidth = sprite_get_width(sSpeechBubbleInGame);

        if (mirrored) {
            var _bx = _VisualCenterX() + TUTORIAL_BUBBLE_GAP_X;
            return {
                x1: _bx,
                y1: _by - _frameSpace,
                x2: _bx + _bubbleWidth,
                y2: _by,
            };
        } else {
            var _bx = _VisualCenterX() - TUTORIAL_BUBBLE_GAP_X;
            return {
                x1: _bx - _bubbleWidth,
                y1: _by - _frameSpace,
                x2: _bx,
                y2: _by,
            };
        }
    }

    /// @function _PointInRect(_x, _y, _rect)
    /// @description Plain point-in-rect test against a { x1, y1, x2, y2 } struct, as returned by _BoogerRect()/_BubbleRect().
    /// @returns {Bool}
    static _PointInRect = function(_x, _y, _rect) {
        return (_x >= _rect.x1 && _x <= _rect.x2 && _y >= _rect.y1 && _y <= _rect.y2);
    }

    /// @function _UpdateBubble(_dt)
    /// @description Advances the typewriter (+ throttled voice blip, mirrors DialogueOverlay's per-char approach). Once done: a click on the bubble/Booger advances to the next line within the phase (2026-08-13, replaces the old fixed-wait), UNLESS the upcoming step needs a mirror swap first (its `transition` field -- 2026-08-13 mirror-interlude request, see StartIntroScript()'s phase 3), in which case the click instead starts that swap (Hide() + pendingMirrorTransition; the swap's own Show()/landing is what actually reveals the step's text, via the same pendingScriptStart mechanism the very first phase start uses). On the phase's LAST line, a click just dismisses her (Hide()) -- 2026-08-13 follow-up ("when clicking the last box, have her disappear") -- AND (2026-08-13, action-free-phase request) tries to advance/end the tutorial right there via _TryAdvancePhase(), since a phase with no placement/training requirements (like phase 3) has nothing else that would ever call it. See .md.
    /// @param {Real} _dt Real seconds since last Step.
    static _UpdateBubble = function(_dt) {
        if (!typewriterDone) {
            // 2026-08-15 request: skip straight to the end of the typewriter by clicking the bubble/Booger
            // or pressing space. Completes the reveal and RETURNS immediately -- deliberately does NOT
            // fall through to the advance-check below on this same call, so the press that skipped the
            // typewriter can't ALSO register as "advance to next line" in the same frame. The player has
            // to click/press again afterward to advance, which happens naturally on its own since
            // mouse_check_button_pressed()/keyboard_check_pressed() are only true for the single frame the
            // press actually occurred on -- by the next frame this same press is no longer "pressed". See .md.
            var _mxSkip = device_mouse_x_to_gui(0);
            var _mySkip = device_mouse_y_to_gui(0);
            var _skipClicked = mouse_check_button_pressed(mb_left) && (_PointInRect(_mxSkip, _mySkip, _BubbleRect()) || _PointInRect(_mxSkip, _mySkip, _BoogerRect()));
            if (_skipClicked || keyboard_check_pressed(vk_space)) {
                bubbleRevealChars = string_length(bubbleVisibleText);
                typewriterDone    = true;
                return;
            }

            var _prev = bubbleRevealChars;
            bubbleRevealChars += TUTORIAL_BUBBLE_TYPEWRITER_CHARS_PER_SECOND * _dt;

            // 2026-08-15 bugfix: indexes into bubbleVisibleText (tag-stripped), not bubbleRawText -- see
            // that field's comment/.md. Indexing into the raw (tagged) string here would also have been
            // wrong on its own terms even before the completion-bound fix above, since bubbleRevealChars'
            // count no longer lines up with bubbleRawText's own character positions once any tag is present.
            if (floor(bubbleRevealChars) > floor(_prev) && current_time >= speakerSoundFinishTime) {
                var _charIndex = floor(bubbleRevealChars);
                var _char = (_charIndex >= 1 && _charIndex <= string_length(bubbleVisibleText)) ? string_char_at(bubbleVisibleText, _charIndex) : "";
                if (_char != "" && _char != " " && _char != "\n") {
                    var _gain  = (global.gameSettings.sfxMuted ? 0 : PerceptualGain(global.gameSettings.sfxVolume)) * DIALOGUE_TEXT_BLIP_GAIN_SCALE; // reuses DialogueOverlayScripts.gml's macros -- see .md
                    var _pitch = random_range(DIALOGUE_TEXT_BLIP_PITCH_MIN, DIALOGUE_TEXT_BLIP_PITCH_MAX); // reuses DialogueOverlayScripts.gml's macros -- see .md
                    audio_play_sound(aBoogerSpeak, 1, false, _gain, 0, _pitch);
                    speakerSoundFinishTime = current_time + (1000 * audio_sound_length(aBoogerSpeak)) - DIALOGUE_TEXT_BLIP_OVERLAP_MS;
                }
            }

            if (bubbleRevealChars >= string_length(bubbleVisibleText)) {
                typewriterDone = true;
            }
            return;
        }

        if (!mouse_check_button_pressed(mb_left)) return;

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        if (!_PointInRect(_mx, _my, _BubbleRect()) && !_PointInRect(_mx, _my, _BoogerRect())) return;

        var _steps = _CurrentSteps();
        if (scriptIndex < array_length(_steps) - 1) {
            var _nextStep = _steps[scriptIndex + 1];
            var _nextTransition = _nextStep[$ "transition"]; // [$ ...] accessor -- SAFE for a possibly-absent key; only phase 3's two transition steps declare `transition` at all, every other step (every phase) omits the key entirely, and dot notation would throw on those. See .md.
            if (_nextTransition == "mirror") {
                pendingMirrorTransition = "toMirrored";
                Hide();
            } else if (_nextTransition == "unmirror") {
                handsFrame = 0; // per request: hands switch back to 0 BEFORE the disappear starts, not on landing
                pendingMirrorTransition = "toNormal";
                Hide();
            } else {
                _AdvanceScript();
            }
        } else {
            scriptDismissed = true; // 2026-08-14 -- see field comment; must be set BEFORE _TryAdvancePhase() so a requirement already satisfied earlier (mid-script) can complete right here instead of waiting on a placement/training callback that already fired
            Hide();
            _TryAdvancePhase(); // no-ops harmlessly if this phase still has an outstanding placement/training requirement -- see .md
        }
    }

    /// @function Update()
    /// @description Call once per Step while state != "hidden". Drives the appear/disappear arch and, while idle, the bubble typewriter/advance. See .md.
    /// @returns {Struct.TutorialGuide} self
    static Update = function() {
        var _dt    = delta_time / 1000000; // microseconds -> seconds, same idiom used throughout this project
        var _total = TUTORIAL_GUIDE_RISE_SECONDS + TUTORIAL_GUIDE_SETTLE_SECONDS;
        // _riseFraction (2026-08-14: removed) used to drive handsAboveBar's draw-order swap -- no longer
        // needed now that sBoogerHands always draws above the bar (Draw_Front()), per request ("it would
        // actually make it look like she is pulling herself up"). See Draw_Behind()/Draw_Front() below.

        switch (state) {
            case "hidden":
                return self;

            case "appearing":
                animTimer += _dt;
                var _t = clamp(animTimer / _total, 0, 1);
                y = _AnimCurveY(_t);
                if (_t >= 1) {
                    state = "idle";
                    y     = _RestY();
                    if (mirrored) handsFrame = 1; // "when she lands, switch her hand sprite to index 1" -- only ever true right after the toMirrored landing, since every other Show() happens with mirrored already false. See .md.
                    if (pendingScriptStart) {
                        pendingScriptStart = false;
                        _AdvanceScript();
                    }
                }
                break;

            case "disappearing":
                animTimer += _dt;
                var _t2        = clamp(animTimer / _total, 0, 1);
                var _effective = 1 - _t2;
                y = _AnimCurveY(_effective);
                if (_t2 >= 1) {
                    state = "hidden";
                    if (pendingMirrorTransition != undefined) {
                        mirrored = (pendingMirrorTransition == "toMirrored");
                        pendingMirrorTransition = undefined;
                        pendingScriptStart = true; // reuses the normal "reveal via _AdvanceScript() once landed" mechanism -- see .md
                        Show();
                    } else if (pendingPhaseAdvance) {
                        pendingPhaseAdvance = false;
                        _StartNextPhase();
                    }
                }
                break;

            case "idle":
                y = _RestY();
                _UpdateBubble(_dt);
                break;
        }
        return self;
    }

    /// @function Draw_Behind()
    /// @description Call FIRST among this frame's HUD draw calls (Booger is "the lowest item in the UI" -- everything else, including the persistent bar sprites, draws on top of her). No-ops while hidden. Draws ONLY her portrait -- 2026-08-14: sBoogerHands moved entirely to Draw_Front(), see below.
    static Draw_Behind = function() {
        if (state == "hidden") return;

        draw_sprite_ext(sBoogerPortrait, mood, _AnchorX(), y, _DrawXScale(), TUTORIAL_GUIDE_SCALE, 0, c_white, 1);
    }

    /// @function Draw_Front()
    /// @description Call after the persistent UI bar sprites (see TutorialGuideScripts.md for the exact oUnitControl/Draw_64.gml insertion point). Draws sBoogerHands. No-ops while hidden. 2026-08-14: hands now draw here UNCONDITIONALLY (always above the bar) -- the old below-the-bar/above-the-bar depth-swap (`handsAboveBar`) was removed per request ("it would actually make it look like she is pulling herself up" -- i.e. her hands should always read as gripping the bar's top edge from above, through the whole appear/disappear arch, not just once she's settled). Uses `_HandsXScale()` (2026-08-14, "flip the hands too" request) so they mirror in lockstep with the portrait. The speech bubble itself no longer draws here -- see Draw_Bubble() below, called from a LATER point in oUnitControl/Draw_64.gml so it renders on top of the training queue bars.
    static Draw_Front = function() {
        if (state == "hidden") return;

        draw_sprite_ext(sBoogerHands, handsFrame, _VisualCenterX(), _BarTopY(), _HandsXScale(), TUTORIAL_GUIDE_SCALE, 0, c_white, 1);
    }

    /// @function Draw_Bubble()
    /// @description Draws the current speech bubble (bottom-right sprite origin) and its typewriter-revealed text, top-left anchored with TUTORIAL_BUBBLE_BUFFER on both axes within whichever frame's visible height was chosen. Geometry comes from _BubbleRect() so the draw and the click-hit-test can't drift apart. Branches on `mirrored` (2026-08-13): normal anchors at the rect's right edge with positive xscale (extends left-up, same as always); mirrored anchors at the rect's left edge with negative xscale (extends right-up) -- true mirror image, see .md. No-ops unless `state == "idle"` (only then is there anything to draw). Renamed from the internal `_DrawBubble()` and given its OWN call site (2026-08-14, "draw the speech bubble over top the unit building production bar" request) -- called from oUnitControl/Draw_64.gml AFTER DrawTrainingQueueBars(), separately from Draw_Front(), so it renders on top of those bars instead of underneath them. See .md.
    static Draw_Bubble = function() {
        if (state != "idle") return;

        var _rect = _BubbleRect();

        bubbleText.reveal(floor(bubbleRevealChars));

        // 2026-08-15 follow-up ("don't scale up the text bubbles anymore"): bubble sprite now draws at
        // NATIVE (1x) scale -- was TUTORIAL_GUIDE_SCALE (2x). _rect's anchor terms (_bx, via _VisualCenterX()
        // ± TUTORIAL_BUBBLE_GAP_X) are unchanged (see _BubbleRect()); only the bubble's own drawn size
        // shrunk to match. See .md.
        var _drawX      = mirrored ? _rect.x1 : _rect.x2;
        var _bubbleXScale = mirrored ? -1 : 1;
        draw_sprite_ext(sSpeechBubbleInGame, bubbleFrame, _drawX, _rect.y2, _bubbleXScale, 1, 0, c_white, 1);

        // 2026-08-15 request: mirrored uses its own fixed X offset (the bubble sprite's tail isn't
        // centered in its drawing space, so the plain buffer-derived offset reads off once flipped) --
        // wrap width (set at Say() time) is untouched, so this only shifts where the already-wrapped text
        // starts drawing. 2026-08-15 follow-up (round 2): both offsets now applied UNSCALED (native px),
        // matching the bubble sprite's own now-native draw scale -- see TUTORIAL_BUBBLE_MIRRORED_TEXT_OFFSET_X/
        // TUTORIAL_BUBBLE_BUFFER's own comments/.md.
        var _textX = mirrored
            ? (_rect.x1 + TUTORIAL_BUBBLE_MIRRORED_TEXT_OFFSET_X)
            : (_rect.x1 + TUTORIAL_BUBBLE_BUFFER);
        var _textY = _rect.y1 + TUTORIAL_BUBBLE_BUFFER;

        DrawCardTextWithShadow(bubbleText, _textX, _textY, 1);
    }
}
