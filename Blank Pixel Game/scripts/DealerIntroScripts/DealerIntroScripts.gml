// The Dealer's tutorial-continuation ambush scene -- a timed portrait tease,
// a two-stage Fate Engine reveal, and hand-off into free interactive play.
// See DealerIntroScripts.md.

#macro DEALER_INTRO_SCALE 2 // matches the UI bar's own 2x convention -- duplicated value, not a shared macro with TUTORIAL_GUIDE_SCALE/FATE_ENGINE_MACHINE_UI_BAR_SCALE, see .md

#macro DEALER_INTRO_WAIT_STEPS 3600 // "wait for a minute (in frames)" per request -- 60s @ 60 steps/sec, literal reading, see .md

// Portrait appear/disappear arch -- values copied directly from
// TutorialGuideScripts.gml's own TUTORIAL_GUIDE_* macros, per request
// ("her appear and disappear will animate the same as Booger's character
// portrait does"). Duplicated, not shared/imported -- same "keep each
// system's own macros self-contained even when values coincide" convention
// FateEngineOverlayScripts.gml's own easing/scale macros already follow. See .md.
#macro DEALER_INTRO_TOP_REVEAL       165
#macro DEALER_INTRO_REST_RAISE       128
#macro DEALER_INTRO_OVERSHOOT        48
#macro DEALER_INTRO_OFFSCREEN_MARGIN 40
#macro DEALER_INTRO_RISE_SECONDS     0.45
#macro DEALER_INTRO_SETTLE_SECONDS   0.22

#macro DEALER_INTRO_BAR_DRAW_Y 1080 // must match oUnitControl/Draw_64.gml's own sMainUIBarBottom draw call -- see .md

#macro DEALER_INTRO_TEXT_COLOR make_color_rgb(0xB0, 0x7C, 0xE8) // "purple, for all of her lines" per request -- untuned judgment call, no existing purple body-text color to match, see .md
#macro DEALER_INTRO_TYPEWRITER_CHARS_PER_SECOND 50 // 2026-08-16 request ("increase speed of typewriter effect by 25%") -- was 40, 40*1.25=50. Kept in sync with TUTORIAL_BUBBLE_TYPEWRITER_CHARS_PER_SECOND's own +25% bump -- DIALOGUE_TYPEWRITER_CHARS_PER_SECOND (DialogueOverlayScripts.gml, a separate system never touched by this conversation) was deliberately left alone, see .md.

#macro DEALER_INTRO_BUBBLE_GAP_X 24  // copied from TUTORIAL_BUBBLE_GAP_X. 2026-08-16: no longer used by _MachineBubbleRect() -- see DEALER_INTRO_MACHINE_BUBBLE_SHIFT_X's own comment below.
#macro DEALER_INTRO_BUBBLE_BUFFER 8  // copied from TUTORIAL_BUBBLE_BUFFER. 2026-08-15 follow-up ("don't scale up the text bubbles anymore"): applied UNSCALED now, matching the bubble sprite's own native (1x) draw scale -- was ×DEALER_INTRO_SCALE, see .md. Portrait-stage (non-flipped) bubble text only, as of 2026-08-16 -- see DEALER_INTRO_MACHINE_TEXT_OFFSET_X below for the machine-stage (flipped) bubble's own text offset.
#macro DEALER_INTRO_MACHINE_TEXT_OFFSET_X (DEALER_INTRO_BUBBLE_BUFFER + 16) // 2026-08-16 request ("adjust text alignment for flipped speech bubble, moved 16px to the right, real screen space") -- the machine-stage bubble draws FLIPPED (negative xscale, see Draw_Bubble()), same tail-asymmetry issue TUTORIAL_BUBBLE_MIRRORED_TEXT_OFFSET_X already exists to fix for Booger's own mirrored bubble; this bubble never had an equivalent until now (it previously just reused the plain, non-flip-aware DEALER_INTRO_BUBBLE_BUFFER for both orientations). Applied UNSCALED (real screen space, matching the bubble's native draw scale), machine-stage bubble text only -- see Draw_Bubble()/.md.
#macro DEALER_INTRO_BUBBLE_TEXT_MAX_WIDTH 312 // copied from TUTORIAL_BUBBLE_TEXT_MAX_WIDTH. 2026-08-15 follow-up: no longer ×DEALER_INTRO_SCALE'd at Say()'s point of use, see .md.

#macro DEALER_INTRO_MACHINE_BUBBLE_BOTTOM_OFFSET_Y 320 // px above her sDealer leaning sprite's own origin where the machine-stage bubble's bottom edge sits -- untuned judgment call (rough "head/shoulder height" guess against her 474px-tall sprite), see .md

// 2026-08-15 request -- repositioning nudges for the two bubble layouts, applied on top of their
// existing geometry (_PortraitBubbleRect()/_MachineBubbleRect()).
// 2026-08-15 follow-up correction: the FATE-ENGINE/machine-stage shift (X and Y) is native-sprite-space,
// scaled by DEALER_INTRO_SCALE at the point of use in _MachineBubbleRect() -- matching sSpeechBubbleInGame's
// own DEALER_INTRO_SCALE-scaled draw in that same function (the original pass treated it as a literal
// final GUI px instead, confirmed wrong). The UI-bar/portrait-stage shift stays a literal GUI px, unlike
// the machine one -- not called out in the follow-up, so left as originally implemented; flag if it should
// match too. See .md.
#macro DEALER_INTRO_PORTRAIT_BUBBLE_SHIFT_X -224 // UI-bar/portrait-stage bubble -- cumulative across two requests: -160 (2026-08-15) then another -64 (2026-08-16, "move to the left 64px, real screen space"), both literal/real-screen-space GUI px (see comment above), same "stack into one macro, note the history" convention TUTORIAL_GUIDE_REST_RAISE already established elsewhere in this project.
#macro DEALER_INTRO_PORTRAIT_BUBBLE_SHIFT_Y -64  // 2026-08-16 request ("move all speech bubbles, except fate engine dealer, up by 64px, real screen space") -- UI-bar/portrait-stage bubble only (the machine-stage/Fate-Engine one is explicitly excluded, see _MachineBubbleRect()). Literal/real-screen-space GUI px, negative = up, same space as SHIFT_X directly above.
#macro DEALER_INTRO_MACHINE_BUBBLE_SHIFT_X  96   // 2026-08-16: no longer used -- _MachineBubbleRect()'s `_bx` now aligns directly with her sprite's right edge instead (2026-08-16 request, "align with her right hand sprite border"), superseding this nudge entirely. Left defined (unused) rather than deleted, in case the flush-alignment reading turns out wrong and this nudge needs to come back. See .md.
#macro DEALER_INTRO_MACHINE_BUBBLE_SHIFT_Y  -32  // machine-stage bubble -- shifted UP 32px per request (negative = up, GUI space), native-sprite-space (see comment above). Still in use -- 2026-08-16's "move up 64px" request explicitly EXCLUDES the machine-stage/Fate-Engine bubble, so this vertical nudge is untouched by that pass.

// 2026-08-15 follow-up ("don't scale up the text bubbles anymore... don't adjust any of their anchor
// points"): the SHIFT/OFFSET macros above are ANCHOR-POINT terms (they feed directly into _bx/_bottomY
// in _PortraitBubbleRect()/_MachineBubbleRect()) -- deliberately left completely untouched by that pass,
// including DEALER_INTRO_MACHINE_BUBBLE_SHIFT_Y's own ×DEALER_INTRO_SCALE multiplication (still present,
// even though the bubble SPRITE itself no longer draws at that scale -- see Draw_Bubble()). Only the bubble's
// own SIZE terms (_bubbleWidth, _frameSpace) and the TEXT terms (DEALER_INTRO_BUBBLE_BUFFER, wrap width)
// changed. Flag if this anchor-side SHIFT macro should also drop its ×DEALER_INTRO_SCALE now that the
// bubble it was originally scale-matched to no longer scales -- not requested, so left alone. See .md.

/// @function DealerIntroScene()
/// @description The Dealer's scripted tutorial-continuation scene. Owner (oUnitControl) calls Update() every Step regardless of phase (the initial wait must keep ticking during otherwise-normal play) and Draw_Behind()/Draw_Front()/Draw_Bubble() at the same three draw-order points TutorialGuideScripts.md documents for Booger. See .md.
function DealerIntroScene() constructor {
    phase     = "inactive"; // "inactive" | "waiting" | "portraitIntro" | "backgroundReveal" | "portraitReturn" | "machineReveal" | "machineDialogue" | "awaitingFirstSpin" | "done" -- see .md for the full state diagram. 2026-08-15 follow-up added "awaitingFirstSpin" (post-first-spin monologue hand-off, see BeginWait()-sibling notes on scriptSteps' "awaitFirstSpin" transition below).
    waitTimer = 0;          // steps remaining in "waiting", see BeginWait()

    sawSpinStart = false; // 2026-08-15 follow-up -- true once _MachineIsSpinning() has been observed true DURING "awaitingFirstSpin"; combined with a later observed-false, this is how the scene detects "the player's first spin has landed" without FateEngineOverlayScripts.gml ever needing to reference this scene (one-directional coupling, see .md). Reset false each time "awaitingFirstSpin" begins.

    // Portrait appear/disappear arch -- same fields/shape as TutorialGuide's
    // own (state/animTimer/y), duplicated not shared. See _AnimCurveY()/.md.
    portraitState     = "hidden"; // "hidden" | "appearing" | "idle" | "disappearing"
    portraitAnimTimer = 0;        // seconds into the current appear/disappear transition
    portraitY         = 0;        // current GUI-space Y of her (bottom) origin

    savedMatchSpeed = 1; // captured the moment the scene begins suppressing input (end of "waiting"), restored in _ConcludeScene() -- this scene owns match-freezing for its whole duration, not just the fate-engine-open portion, see .md

    // scriptSteps: flat array of { text, transition, grantToken }, played in
    // order via scriptIndex. `transition` (optional, "toBackground" |
    // "toMachine" | "awaitFirstSpin") lives on the step that should be
    // preceded by that transition -- same placement convention
    // TutorialGuideScripts.gml's own "mirror"/"unmirror" steps already use
    // (checked one-ahead when dismissing the PRIOR step). `grantToken`
    // (optional bool) grants one Fate Token the moment that step is first
    // shown. See .md.
    //
    // 2026-08-15 follow-up: steps 15-24 (the "Oooooh nice!"...."Goodluck
    // kid!" run) are a SECOND scripted beat, not part of the original
    // ambush -- step 15 carries "awaitFirstSpin" (consumed when step 14,
    // "Just insert the token and pull the lever...", is dismissed): instead
    // of advancing immediately, the scene hands the player back real
    // interactive control (_UpdateBubble()) and waits for their first spin
    // to actually land (Update()'s "awaitingFirstSpin" case) before
    // resuming here. See .md.
    scriptSteps = [
        { text: "Psst. Hey. You." },
        { text: "Yeah you, weird lookin' guy. Come into the woods with me." },
        { text: "Hey Kid.", transition: "toBackground" },
        { text: "You can call me The Dealer. You know you're fucked right?" },
        { text: "You have zero hope of winning this fight. Kyrii is financially destitute." },
        { text: "Sucks to be you, huh? Handed an impossible task on your first day." },
        { text: "[wave]Sigh.[/wave]" },
        { text: "If only there was some magical way to get the resources you needed to win..." },
        { text: "[shake]OH WAIT! THERE IS![/shake]" },
        { text: "[wave]TA-DA!!!!![/wave]", transition: "toMachine" },
        { text: $"Introducing [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]The Fate Engine[/c]!" },
        { text: "Pretty cool right? This puppy right here will give you what you need! And what you don't!" },
        { text: $"Here's a [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]Fate Token[/c].", grantToken: true },
        { text: "First spin is on the house. No strings attached! No fine print! No catch! No... uhhhh..." },
        { text: "Just insert the token and pull the lever..." },
        { text: "[wave]Oooooh nice! It didn't kill you immediately![/wave]", transition: "awaitFirstSpin" },
        { text: $"When you spend a token, it actually give you unlimited spins! If you don't like what you got, [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]you can lock one of the items in and spin again![/c]" },
        { text: "Unfortunately, there IS actually very tiny fine print on this part..." },
        { text: $"[{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]The Fate Engine[/c] gets a little... finnicky... the more times you spin it. Almost like it gets angry." },
        { text: "It can lead to greater rewards though!" },
        { text: "... or greater consequences..." },
        { text: $"Anyway, once you're satisfied with your three items, hit [{TUTORIAL_GUIDE_HIGHLIGHT_COLOR_TAG}]Cash Out[/c]!" },
        { text: "I will reward you with tokens if you're being a good little advisor. I need Talos decimated off the face of this earth." },
        { text: "[wave]And no, I can't tell you why.[/wave]" },
        { text: "Goodluck kid!" },
    ];
    scriptIndex         = -1;
    pendingScriptStart  = false;   // true while waiting for the appear animation to finish before this leg's first Say() -- same name/purpose as TutorialGuide's own field
    pendingAfterHide    = undefined; // "toBackground" | "toMachine" | undefined -- set right before HidePortrait() when the NEXT step needs a scene transition first, consumed once _UpdatePortraitArch()'s "disappearing" case confirms she's fully hidden
    usingMachineBubble  = false;   // false = portrait-anchored bubble (stages A/C), true = machine-anchored mirrored bubble (stage E) -- see Draw_Bubble()/.md
    tokenGranted        = false;   // guards the "Here's a Fate Token" step's grant so it can only ever fire once

    bubbleRawText     = ""; // plain pre-Scribble string, AS PASSED TO Say() -- includes any Scribble command/color tags verbatim, kept only for reference
    bubbleVisibleText = ""; // 2026-08-15 bugfix -- the SAME text after Scribble parses out its own tags (via bubbleText.get_text(), see Say()). The typewriter's char-count bound uses THIS, not bubbleRawText -- see Say()/_UpdateBubble()/.md and TutorialGuideScripts.gml's matching fix.
    bubbleRevealChars = 0;
    typewriterDone    = false;
    bubbleFrame       = 0;

    bubbleText = scribble("", "__dealerIntroBubble__")
        .starting_format(HOVER_CARD_BODY_FONT, DEALER_INTRO_TEXT_COLOR)
        .align(fa_left, fa_top);

    /// @function BeginWait()
    /// @description Arms the ambush -- starts the DEALER_INTRO_WAIT_STEPS countdown (ticked in Update() regardless of phase). No-ops if already armed/running/done (only ever meant to fire once, from TutorialGuideScripts.gml's own tutorial-completion branch). See .md.
    /// @returns {Struct.DealerIntroScene} self
    static BeginWait = function() {
        if (phase != "inactive") return self;
        phase     = "waiting";
        waitTimer = DEALER_INTRO_WAIT_STEPS;
        return self;
    }

    /// @function IsSuppressingInput()
    /// @description True from the moment her portrait starts appearing through the whole scripted scene -- oUnitControl/Step_0.gml exits early (mirroring the fateEngineOverlay.isOpen/pauseMenu.isOpen pattern) whenever this is true. False during "inactive"/"waiting" (normal play continues right up until she appears), "awaitingFirstSpin" (2026-08-15 follow-up -- the player has real interactive control of the still-open Fate Engine here, same as any ordinary session; Step_0.gml's own fateEngineOverlay.isOpen gate handles ticking it, see Update()'s overlay-Update() guard below), and "done" (scene over, player has normal control of the now-open Fate Engine). See .md.
    /// @returns {Bool}
    static IsSuppressingInput = function() {
        return phase != "inactive" && phase != "waiting" && phase != "done" && phase != "awaitingFirstSpin";
    }

    /// @function _RiseFraction()
    /// @description Fraction of the total appear/disappear duration spent on the start<->overshoot leg. Copied from TutorialGuide's own, see .md.
    /// @returns {Real}
    static _RiseFraction = function() {
        return DEALER_INTRO_RISE_SECONDS / (DEALER_INTRO_RISE_SECONDS + DEALER_INTRO_SETTLE_SECONDS);
    }

    /// @function _BarTopY()
    /// @description The bottom UI bar's top edge, GUI space. Must stay in sync with oUnitControl/Draw_64.gml's own sMainUIBarBottom draw call -- see .md.
    /// @returns {Real}
    static _BarTopY = function() {
        return DEALER_INTRO_BAR_DRAW_Y - sprite_get_height(sMainUIBarBottom) * DEALER_INTRO_SCALE;
    }

    /// @function _AnchorX()
    /// @description Her portrait's draw-anchor X -- pinned exactly at the GUI's right edge. sDealerPortrait's origin is bottom-LEFT, and she's drawn with NEGATIVE xscale (flipped, facing left/toward the game -- same convention TutorialGuideScripts.gml's own DEFAULT/non-mirrored Booger placement uses for her own right-side position, see .md), so drawing at exactly guiWidth puts her sprite's (post-flip) RIGHT edge exactly on the screen's right edge, per request ("aligning the right hand side of her sprite with the right hand side of the screen"). Facing direction (flipped vs. not) wasn't specified by the request -- judgment call, see .md.
    /// @returns {Real}
    static _AnchorX = function() {
        return display_get_gui_width();
    }

    /// @function _VisualCenterX()
    /// @description Horizontal center of her drawn portrait sprite.
    /// @returns {Real}
    static _VisualCenterX = function() {
        var _halfWidth = (sprite_get_width(sDealerPortrait) * DEALER_INTRO_SCALE) / 2;
        return _AnchorX() - _halfWidth;
    }

    /// @function _RestY()
    /// @description Her settled Y (bottom-origin) -- positions her so DEALER_INTRO_TOP_REVEAL px of her sprite sit above the bar's top edge, then raised another DEALER_INTRO_REST_RAISE px, same formula shape as TutorialGuide's own _RestY(). See .md.
    /// @returns {Real}
    static _RestY = function() {
        return _BarTopY() - DEALER_INTRO_TOP_REVEAL - DEALER_INTRO_REST_RAISE + sprite_get_height(sDealerPortrait) * DEALER_INTRO_SCALE;
    }

    /// @function _OvershootY()
    /// @returns {Real}
    static _OvershootY = function() {
        return _RestY() - DEALER_INTRO_OVERSHOOT;
    }

    /// @function _StartY()
    /// @description Fully-hidden Y -- her sprite's top sits at or below the visible GUI height, plus a safety margin.
    /// @returns {Real}
    static _StartY = function() {
        return display_get_gui_height() + sprite_get_height(sDealerPortrait) * DEALER_INTRO_SCALE + DEALER_INTRO_OFFSCREEN_MARGIN;
    }

    /// @function _AnimCurveY(_t)
    /// @description The shared appear/disappear arch curve -- identical shape to TutorialGuide's own _AnimCurveY() (ease-out cubic into an overshoot peak, then smoothstep settle-back), duplicated per request ("animate the same as Booger's character portrait does"). _t 0 = _StartY(), _t = _RiseFraction() = _OvershootY() (the peak), _t 1 = _RestY(). See .md.
    /// @param {Real} _t 0..1.
    /// @returns {Real}
    static _AnimCurveY = function(_t) {
        var _riseFraction = _RiseFraction();
        var _startY       = _StartY();
        var _overshootY   = _OvershootY();
        var _restY        = _RestY();

        if (_t <= _riseFraction) {
            var _local = (_riseFraction <= 0) ? 1 : (_t / _riseFraction);
            var _eased = 1 - power(1 - _local, 3);
            return lerp(_startY, _overshootY, _eased);
        } else {
            var _local2 = (_riseFraction >= 1) ? 1 : ((_t - _riseFraction) / (1 - _riseFraction));
            var _eased2 = _local2 * _local2 * (3 - 2 * _local2);
            return lerp(_overshootY, _restY, _eased2);
        }
    }

    /// @function ShowPortrait()
    /// @description Begins the portrait's appear animation from fully hidden. No-op if already appearing/idle. See .md.
    /// @returns {Struct.DealerIntroScene} self
    static ShowPortrait = function() {
        if (portraitState == "appearing" || portraitState == "idle") return self;
        portraitState     = "appearing";
        portraitAnimTimer = 0;
        portraitY         = _StartY();
        return self;
    }

    /// @function HidePortrait()
    /// @description Begins the portrait's disappear animation (reverse of ShowPortrait(), same curve). No-op if already hidden/disappearing. See .md.
    /// @returns {Struct.DealerIntroScene} self
    static HidePortrait = function() {
        if (portraitState == "hidden" || portraitState == "disappearing") return self;
        portraitState     = "disappearing";
        portraitAnimTimer = 0;
        return self;
    }

    /// @function Say(_text)
    /// @description Opens a new speech bubble: resets the typewriter, sizes the bubble frame to fit _text, sets the (fixed, purple) text color. Embed Scribble tags directly in _text -- same convention TutorialGuideScripts.gml/DialogueOverlayScripts.gml use. See .md.
    /// @param {String} _text
    /// @returns {Struct.DealerIntroScene} self
    static Say = function(_text) {
        bubbleRawText     = _text;
        bubbleRevealChars = 0;
        typewriterDone    = false;

        var _wrapW = DEALER_INTRO_BUBBLE_TEXT_MAX_WIDTH; // 2026-08-15 follow-up -- no longer ×DEALER_INTRO_SCALE, see macro comment/.md
        bubbleText = scribble(_text, "__dealerIntroBubble__")
            .starting_format(HOVER_CARD_BODY_FONT, DEALER_INTRO_TEXT_COLOR)
            .align(fa_left, fa_top)
            .wrap(_wrapW)
            .allow_text_getter(); // 2026-08-15 bugfix -- required for get_text() below, see bubbleVisibleText's field comment/.md

        // 2026-08-15 bugfix: cache the TAG-STRIPPED text (matches TutorialGuideScripts.gml's own fix,
        // same root cause) -- several of these lines carry [wave]/[shake]/[c_tag] markup (see scriptSteps
        // above), and comparing the typewriter's progress against the RAW string's length (tags included)
        // meant typewriterDone flipped true well after the visible text had already finished revealing,
        // delaying when the player could click to advance. See bubbleVisibleText's field comment/.md.
        bubbleVisibleText = bubbleText.get_text();

        var _requiredHeight = bubbleText.get_height() + (DEALER_INTRO_BUBBLE_BUFFER * 2); // 2026-08-15 follow-up -- no longer ×DEALER_INTRO_SCALE, see .md
        bubbleFrame = ChooseTutorialBubbleFrame(_requiredHeight); // 2026-08-14 -- reused directly from TutorialGuideScripts.gml: pure sprite-geometry helper (smallest of sSpeechBubbleInGame's 3 frames that fits), no Booger-specific behavior baked in, see .md

        return self;
    }

    /// @function _AdvanceScript()
    /// @description Moves to the next scripted line, granting a Fate Token first if this step calls for it. No-ops past the end of scriptSteps.
    static _AdvanceScript = function() {
        scriptIndex += 1;
        if (scriptIndex >= array_length(scriptSteps)) return;

        var _step = scriptSteps[scriptIndex];
        if (_step[$ "grantToken"] == true && !tokenGranted) { // [$ ...] accessor -- SAFE for a possibly-absent key, same hazard TutorialGuideScripts.gml's own requireInside/trainingRequirements/transition reads already guard against, see .md
            tokenGranted = true;
            global.resources[TEAM.PLAYER].fateTokens += 1; // per request, "Give a Fate Token resource to the player" -- established grant pattern, see ProgressionScripts.gml's own XP-milestone grant, .md
            AnalyticsRecordResourceProduced(TEAM.PLAYER, "fateTokens", 1);
        }

        Say(_step.text);
    }

    /// @function _PointInRect(_x, _y, _rect)
    /// @description Plain point-in-rect test, duplicated from TutorialGuideScripts.gml's own (trivial, stateless -- not worth a cross-file call), see .md.
    /// @returns {Bool}
    static _PointInRect = function(_x, _y, _rect) {
        return (_x >= _rect.x1 && _x <= _rect.x2 && _y >= _rect.y1 && _y <= _rect.y2);
    }

    /// @function _PortraitSpriteRect()
    /// @description Click-hit-test rect for her portrait, GUI space -- the visible-above-the-bar portion only, same clipping reasoning as TutorialGuide's own _BoogerRect(). See .md.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _PortraitSpriteRect = function() {
        var _anchorX = _AnchorX();
        var _width   = sprite_get_width(sDealerPortrait) * DEALER_INTRO_SCALE;
        return {
            x1: _anchorX - _width,
            y1: portraitY - sprite_get_height(sDealerPortrait) * DEALER_INTRO_SCALE,
            x2: _anchorX,
            y2: _BarTopY(),
        };
    }

    /// @function _PortraitBubbleRect()
    /// @description The portrait-stage speech bubble's drawn rect, GUI space -- sits to the LEFT of her visual center (near/right edge = x2), same layout TutorialGuideScripts.gml's own DEFAULT (non-mirrored) Booger bubble uses, appropriate since her portrait sits at the same right-ish side of the screen. Reuses TUTORIAL_BUBBLE_FRAME_0/1/2_HEIGHT and sSpeechBubbleInGame directly (same sprite asset as Booger's own bubble) -- see .md. 2026-08-15 follow-up ("don't scale up the text bubbles anymore"): _bubbleWidth/_frameSpace no longer ×DEALER_INTRO_SCALE (sprite now draws at native scale, see Draw_Bubble()). 2026-08-16: `_by` now also includes DEALER_INTRO_PORTRAIT_BUBBLE_SHIFT_Y (up 64px, real screen space) -- both `_bx`/`_by` remain deliberately-adjustable ANCHOR terms (SHIFT macros nudge them directly), see .md.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _PortraitBubbleRect = function() {
        var _by          = _BarTopY() + DEALER_INTRO_PORTRAIT_BUBBLE_SHIFT_Y; // 2026-08-16 request, see macro comment/.md
        var _frameSpace  = [TUTORIAL_BUBBLE_FRAME_0_HEIGHT, TUTORIAL_BUBBLE_FRAME_1_HEIGHT, TUTORIAL_BUBBLE_FRAME_2_HEIGHT][bubbleFrame];
        var _bubbleWidth = sprite_get_width(sSpeechBubbleInGame);
        var _bx          = _VisualCenterX() - DEALER_INTRO_BUBBLE_GAP_X + DEALER_INTRO_PORTRAIT_BUBBLE_SHIFT_X; // 2026-08-15/2026-08-16 requests, see macro comment/.md
        return {
            x1: _bx - _bubbleWidth,
            y1: _by - _frameSpace,
            x2: _bx,
            y2: _by,
        };
    }

    /// @function _MachineSpriteRect(_fateEngineOverlay)
    /// @description Click-hit-test rect for her sDealer leaning sprite on the machine, GUI space -- only meaningful once _MachineProgress() >= 1 (matrix pop-up offset is 0 by then, so _DealerBasePosition() is directly correct, same reasoning FateEngineOverlayScripts.gml's own hover-tooltip/button gates already rely on). See .md.
    /// @param {Struct.FateEngineOverlay} _fateEngineOverlay
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _MachineSpriteRect = function(_fateEngineOverlay) {
        var _pos = _fateEngineOverlay._DealerBasePosition(); // 2026-08-14 -- reaches into FateEngineOverlay's own (underscore-prefixed but not actually private, GML has no real privacy) corner-alignment helper rather than duplicating that math here, see .md
        var _w   = sprite_get_width(sDealer);
        var _h   = sprite_get_height(sDealer);
        return {
            x1: _pos.x,
            y1: _pos.y - _h,
            x2: _pos.x + _w,
            y2: _pos.y,
        };
    }

    /// @function _MachineBubbleRect(_fateEngineOverlay)
    /// @description The machine-stage speech bubble's drawn rect -- sits to the RIGHT of her sDealer sprite's right edge, per request ("aligning speech bubbles to the right of her sprite on the machine"). Vertically anchored DEALER_INTRO_MACHINE_BUBBLE_BOTTOM_OFFSET_Y px above her origin -- untuned guess at roughly head/shoulder height, see .md. 2026-08-15 follow-up ("don't scale up the text bubbles anymore"): _bubbleWidth/_frameSpace no longer ×DEALER_INTRO_SCALE (sprite now draws at native scale, see Draw_Bubble()). 2026-08-16 request ("aligned with her right hand sprite border"): `_bx` now sits FLUSH with `_rightEdgeX` (her sDealer sprite's own right edge) -- DEALER_INTRO_BUBBLE_GAP_X/DEALER_INTRO_MACHINE_BUBBLE_SHIFT_X are no longer part of this calculation at all, superseded by the flush-alignment reading (see those macros' own comments). `_bottomY` is UNCHANGED -- this bubble is explicitly excluded from the same pass's "move bubbles up 64px" request, see .md.
    /// @param {Struct.FateEngineOverlay} _fateEngineOverlay
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _MachineBubbleRect = function(_fateEngineOverlay) {
        var _pos         = _fateEngineOverlay._DealerBasePosition();
        var _rightEdgeX  = _pos.x + sprite_get_width(sDealer);
        var _frameSpace  = [TUTORIAL_BUBBLE_FRAME_0_HEIGHT, TUTORIAL_BUBBLE_FRAME_1_HEIGHT, TUTORIAL_BUBBLE_FRAME_2_HEIGHT][bubbleFrame];
        var _bubbleWidth = sprite_get_width(sSpeechBubbleInGame);
        var _bottomY     = _pos.y - DEALER_INTRO_MACHINE_BUBBLE_BOTTOM_OFFSET_Y + (DEALER_INTRO_MACHINE_BUBBLE_SHIFT_Y * DEALER_INTRO_SCALE); // anchor term, unchanged -- see macro comment/.md
        var _bx          = _rightEdgeX; // 2026-08-16 request -- flush with her sprite's right edge, see .md
        return {
            x1: _bx,
            y1: _bottomY - _frameSpace,
            x2: _bx + _bubbleWidth,
            y2: _bottomY,
        };
    }

    /// @function _UpdateBubble(_dt, _fateEngineOverlay)
    /// @description Advances the typewriter (2026-08-14: NO voice-blip audio -- no aDealerSpeak-equivalent sound asset exists yet, see .md). Once done, a click on the bubble/her sprite advances to the next line, UNLESS the upcoming step needs a scene transition first (its `transition` field), in which case the click instead hides her portrait and stashes pendingAfterHide -- same shape as TutorialGuide's own mirror-interlude handling. On the LAST line, a click concludes the whole scene instead. See .md.
    /// @param {Real} _dt Real seconds since last Step.
    /// @param {Struct.FateEngineOverlay} _fateEngineOverlay
    static _UpdateBubble = function(_dt, _fateEngineOverlay) {
        if (!typewriterDone) {
            // 2026-08-15 request: skip straight to the end of the typewriter by clicking the bubble/her
            // sprite or pressing space -- same mechanism/guard as TutorialGuideScripts.gml's own fix (see
            // its _UpdateBubble()'s comment for the full "why this can't also advance the same frame"
            // reasoning). RETURNS immediately after skipping, before reaching the advance-click handling
            // below, so this exact press can't also register as an advance this same frame.
            var _mxSkip = device_mouse_x_to_gui(0);
            var _mySkip = device_mouse_y_to_gui(0);
            var _skipClickRect  = usingMachineBubble ? _MachineBubbleRect(_fateEngineOverlay) : _PortraitBubbleRect();
            var _skipSpriteRect = usingMachineBubble ? _MachineSpriteRect(_fateEngineOverlay) : _PortraitSpriteRect();
            var _skipClicked = mouse_check_button_pressed(mb_left) && (_PointInRect(_mxSkip, _mySkip, _skipClickRect) || _PointInRect(_mxSkip, _mySkip, _skipSpriteRect));
            if (_skipClicked || keyboard_check_pressed(vk_space)) {
                bubbleRevealChars = string_length(bubbleVisibleText);
                typewriterDone    = true;
                return;
            }

            bubbleRevealChars += DEALER_INTRO_TYPEWRITER_CHARS_PER_SECOND * _dt;
            // 2026-08-15 bugfix: bounded against bubbleVisibleText (tag-stripped), not bubbleRawText -- see
            // that field's comment/.md.
            if (bubbleRevealChars >= string_length(bubbleVisibleText)) typewriterDone = true;
            return;
        }

        if (!mouse_check_button_pressed(mb_left)) return;

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);

        var _clickRect  = usingMachineBubble ? _MachineBubbleRect(_fateEngineOverlay)  : _PortraitBubbleRect();
        var _spriteRect = usingMachineBubble ? _MachineSpriteRect(_fateEngineOverlay)  : _PortraitSpriteRect();
        if (!_PointInRect(_mx, _my, _clickRect) && !_PointInRect(_mx, _my, _spriteRect)) return;

        if (scriptIndex < array_length(scriptSteps) - 1) {
            var _nextStep       = scriptSteps[scriptIndex + 1];
            var _nextTransition = _nextStep[$ "transition"]; // [$ ...] accessor -- SAFE for a possibly-absent key, see .md
            if (_nextTransition == "toBackground" || _nextTransition == "toMachine") {
                pendingAfterHide = _nextTransition;
                HidePortrait();
            } else if (_nextTransition == "awaitFirstSpin") {
                // 2026-08-15 follow-up -- pause the scripted scene here and hand the player back real
                // interactive control of the already-open, already-popped-up machine (unlike
                // toBackground/toMachine, her portrait/bubble state doesn't change at all -- she's just
                // silent and waiting). Resumes (via _AdvanceScript(), landing on THIS step) once Update()'s
                // "awaitingFirstSpin" case detects the player's first spin has landed. See .md.
                phase        = "awaitingFirstSpin";
                sawSpinStart = false;
                global.matchSpeed = savedMatchSpeed;
                _fateEngineOverlay.UnlockInteraction();
            } else {
                _AdvanceScript();
            }
        } else {
            _ConcludeScene(_fateEngineOverlay);
        }
    }

    /// @function _UpdatePortraitArch(_dt, _fateEngineOverlay, _selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController)
    /// @description Advances the portrait's appear/disappear arch. On landing from "appearing", fires the pending _AdvanceScript() if one was armed. On finishing "disappearing", dispatches pendingAfterHide -- "toBackground" opens the Fate Engine overlay WITH the machine held back (see FateEngineOverlayScripts.gml's Open(..., true)/.md); "toMachine" releases it (ReleaseMachine()). See .md.
    static _UpdatePortraitArch = function(_dt, _fateEngineOverlay, _selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController) {
        var _total = DEALER_INTRO_RISE_SECONDS + DEALER_INTRO_SETTLE_SECONDS;

        switch (portraitState) {
            case "appearing":
                portraitAnimTimer += _dt;
                var _t = clamp(portraitAnimTimer / _total, 0, 1);
                portraitY = _AnimCurveY(_t);
                if (_t >= 1) {
                    portraitState = "idle";
                    portraitY     = _RestY();
                    if (pendingScriptStart) {
                        pendingScriptStart = false;
                        _AdvanceScript();
                    }
                }
                break;

            case "disappearing":
                portraitAnimTimer += _dt;
                var _t2 = clamp(portraitAnimTimer / _total, 0, 1);
                portraitY = _AnimCurveY(1 - _t2);
                if (_t2 >= 1) {
                    portraitState = "hidden";
                    if (pendingAfterHide == "toBackground") {
                        pendingAfterHide = undefined;
                        phase = "backgroundReveal";
                        _fateEngineOverlay.Open(_selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController, true);
                    } else if (pendingAfterHide == "toMachine") {
                        pendingAfterHide = undefined;
                        phase = "machineReveal";
                        _fateEngineOverlay.ReleaseMachine();
                    }
                }
                break;
        }
    }

    /// @function _ConcludeScene(_fateEngineOverlay)
    /// @description Ends the scripted scene: restores match speed, permanently unlocks the Fate Engine's XP-bar-click path (2026-08-14 -- resolves the previously-flagged "fateEngineLocked has no code path that ever clears it" gap, TutorialGuideScripts.md), and unlocks player interaction with the now-open, now-popped-up Fate Engine. The overlay itself is left open -- per request, "after that allow the player to interact with the fate engine". See .md.
    /// @param {Struct.FateEngineOverlay} _fateEngineOverlay
    static _ConcludeScene = function(_fateEngineOverlay) {
        phase = "done";
        global.matchSpeed = savedMatchSpeed;

        // 2026-08-15 bugfix ("whole game froze up after the Fate Engine closed, post-spin"): also resync
        // the OVERLAY's own savedMatchSpeed to the value we just restored above. Root cause: the "toBackground"
        // transition (_UpdatePortraitArch()) calls fateEngineOverlay.Open(..., true) WHILE global.matchSpeed
        // is already 0 (this scene forced it to 0 back at the wait-expiry, well before that call) -- Open()'s
        // own `savedMatchSpeed = global.matchSpeed;` therefore captures 0, not the real pre-ambush speed.
        // The overlay session that Open() call started stays open continuously through the rest of this
        // scene AND into the player's first real, interactive session (Spin/Cashout/Leave) -- Open() is
        // never called again to fix the bad capture. So the FIRST time the player actually clicks Leave and
        // the close animation finishes, FateEngineOverlayScripts.gml's Update() runs
        // `global.matchSpeed = savedMatchSpeed;` using that stale 0 -- freezing the match permanently, since
        // nothing else ever restores it from there. Fixing it here, the moment we know the TRUE correct
        // value (global.matchSpeed, just restored above), is the minimal, single-point fix -- it doesn't
        // touch FateEngineOverlayScripts.gml's own Open()/Leave()/Update() at all, so every other caller
        // (the ordinary XP-bar click, which never has this 0-capture problem) is unaffected. See .md.
        _fateEngineOverlay.savedMatchSpeed = global.matchSpeed;

        global.tutorialGuide.fateEngineLocked = false;
        _fateEngineOverlay.UnlockInteraction();
    }

    /// @function Update(_fateEngineOverlay, _selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController)
    /// @description Call once per Step, unconditionally (cheap no-op while "inactive"/"done"; a plain countdown while "waiting"). Owner should check IsSuppressingInput() right after calling this and exit early if true. See .md.
    /// @param {Struct.FateEngineOverlay} _fateEngineOverlay
    /// @param {Struct.SelectionController} _selectionController
    /// @param {Struct.OrderMenu} _orderMenu
    /// @param {Struct.CastleGarrisonMenu} _castleGarrisonMenu
    /// @param {Struct.ArmyLimitMenu} _armyLimitMenu
    /// @param {Struct.BlueprintController} _blueprintController
    /// @returns {Struct.DealerIntroScene} self
    static Update = function(_fateEngineOverlay, _selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController) {
        if (phase == "inactive" || phase == "done") return self;

        if (phase == "waiting") {
            if (waitTimer > 0) {
                waitTimer -= 1;
                return self;
            }

            // Timer expired -- the ambush begins. Freeze the match (this
            // scene owns that freeze for its whole duration, see
            // savedMatchSpeed's field comment/.md) and clear any in-progress
            // player action, same reset FateEngineOverlay's own Open()
            // already performs, done here too since Open() itself won't
            // fire until the "toBackground" transition, well after this.
            savedMatchSpeed   = global.matchSpeed;
            global.matchSpeed = 0;
            _selectionController.Deselect();
            _orderMenu.Close();
            _castleGarrisonMenu.Close();
            _armyLimitMenu.Close();
            if (_blueprintController.dragging) _blueprintController.CancelDrag();

            phase              = "portraitIntro";
            scriptIndex        = -1;
            pendingScriptStart = true;
            ShowPortrait();
            return self;
        }

        var _dt = delta_time / 1000000; // microseconds -> seconds, same idiom TutorialGuideScripts.gml/AIControl.gml use elsewhere

        _UpdatePortraitArch(_dt, _fateEngineOverlay, _selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController);

        // Keep the Fate Engine's own animation/timers ticking for the whole
        // stretch this scene owns it (background reveal through machine
        // pop-up) -- Step_0.gml's OWN fateEngineOverlay.isOpen gate never
        // gets reached while IsSuppressingInput() is true, so this is the
        // only place it gets Update()'d during that window. 2026-08-15
        // follow-up: gated on IsSuppressingInput() too now -- during
        // "awaitingFirstSpin" that's false, so Step_0.gml's OWN overlay gate
        // DOES get reached (ordinary post-scene behavior) and calls
        // Update() itself; calling it again here would double-tick the
        // overlay's timers/animations for every frame of that window. See .md.
        if (_fateEngineOverlay.isOpen && IsSuppressingInput()) _fateEngineOverlay.Update();

        switch (phase) {
            case "portraitIntro":
            case "portraitReturn":
                if (portraitState == "idle") _UpdateBubble(_dt, _fateEngineOverlay);
                break;

            case "backgroundReveal":
                if (_fateEngineOverlay._GradientProgress() >= 1) {
                    phase = "portraitReturn";
                    pendingScriptStart = true;
                    ShowPortrait();
                }
                break;

            case "machineReveal":
                if (_fateEngineOverlay._MachineProgress() >= 1) {
                    phase = "machineDialogue";
                    usingMachineBubble = true;
                    _AdvanceScript();
                }
                break;

            case "machineDialogue":
                _UpdateBubble(_dt, _fateEngineOverlay);
                break;

            case "awaitingFirstSpin":
                // 2026-08-15 follow-up -- detects "the player's first spin has landed" purely by watching
                // _MachineIsSpinning() flip true then false (drums start, then stop) -- resultsBanked flips
                // true in that SAME Step the drums all stop (FateEngineOverlayScripts.gml's Update()), so by
                // the time we observe spinning go false, pendingRewards already reflects the landed result.
                // Deliberately does NOT reference isSessionActive/resultsBanked directly -- keeps this scene
                // reading only the same public-ish surface (_MachineIsSpinning(), already used elsewhere in
                // this file) rather than reaching further into the overlay's internals. See .md.
                if (_fateEngineOverlay._MachineIsSpinning()) {
                    sawSpinStart = true;
                } else if (sawSpinStart) {
                    savedMatchSpeed   = global.matchSpeed; // re-capture -- this is a SECOND freeze window, independent of the first (see savedMatchSpeed's field comment)
                    global.matchSpeed = 0;
                    _fateEngineOverlay.LockInteraction();
                    phase = "machineDialogue"; // usingMachineBubble is already true from before -- reuses the same machine-stage bubble
                    _AdvanceScript();          // reveals scriptSteps[scriptIndex], the "Oooooh nice!..." step this transition parked on
                }
                break;
        }

        return self;
    }

    /// @function _ArmBehindBar()
    /// @description 2026-08-15 request -- true while her "arm" (frame 1, normally drawn OVER the UI bar by Draw_Front()) should instead draw behind it: during appearing's UPSWING (the long start<->overshoot rise leg) and disappearing's DOWNSWING (the same leg, played backward -- the long final drop). Both map to the same underlying curve leg (_AnimCurveY()'s start<->overshoot span, see _RiseFraction()) -- appearing checks it on the way UP (early portion of animTimer), disappearing checks it on the way DOWN (late portion, since disappearing samples the curve as 1-t). During the short overshoot<->rest settle leg (either direction) and while fully idle/hidden, the arm draws normally (in front) -- only the long transit leg tucks it behind, on the reasoning that her arm shouldn't appear to rest on/reach over the bar while she's still physically in transit through it. See .md.
    /// @returns {Bool}
    static _ArmBehindBar = function() {
        if (portraitState != "appearing" && portraitState != "disappearing") return false;

        var _total        = DEALER_INTRO_RISE_SECONDS + DEALER_INTRO_SETTLE_SECONDS;
        var _riseFraction  = _RiseFraction();
        var _t             = clamp(portraitAnimTimer / _total, 0, 1);

        if (portraitState == "appearing") return _t <= _riseFraction;
        return (1 - _t) <= _riseFraction; // disappearing -- effective curve position is 1-t, see _UpdatePortraitArch()
    }

    /// @function Draw_Behind()
    /// @description Call FIRST among this frame's HUD draw calls, same "lowest item in the UI, drawn before the bar" positioning as TutorialGuide's own Draw_Behind() -- but AFTER fateEngineOverlay.Draw(), so her portrait renders on top of the (possibly already-revealed) Fate Engine background during stage C. Draws sDealerPortrait frame 0 -- per request, "her first frame as a draw under the ui bar" -- and ALSO frame 1 (2026-08-15, see _ArmBehindBar()) while she's mid-transit on the long rise/fall leg, so her arm doesn't poke out in front of the bar while still moving through it. No-ops while her portrait is hidden. See .md.
    static Draw_Behind = function() {
        if (portraitState == "hidden") return;
        draw_sprite_ext(sDealerPortrait, 0, _AnchorX(), portraitY, -DEALER_INTRO_SCALE, DEALER_INTRO_SCALE, 0, c_white, 1);
        if (_ArmBehindBar()) {
            draw_sprite_ext(sDealerPortrait, 1, _AnchorX(), portraitY, -DEALER_INTRO_SCALE, DEALER_INTRO_SCALE, 0, c_white, 1);
        }
    }

    /// @function Draw_Front()
    /// @description Call after the persistent UI bar sprites. Draws sDealerPortrait frame 1 -- per request, "her last frame as a draw over the ui bar" -- EXCEPT while _ArmBehindBar() is true (2026-08-15), in which case Draw_Behind() already drew it this frame instead, so this no-ops to avoid double-drawing. Same (x,y) as Draw_Behind() ("have them move as one unit") -- only the call SITE (and therefore the draw order relative to the bar) differs, not the position. No-ops while hidden. See .md.
    static Draw_Front = function() {
        if (portraitState == "hidden") return;
        if (_ArmBehindBar()) return;
        draw_sprite_ext(sDealerPortrait, 1, _AnchorX(), portraitY, -DEALER_INTRO_SCALE, DEALER_INTRO_SCALE, 0, c_white, 1);
    }

    /// @function Draw_Bubble(_fateEngineOverlay)
    /// @description Draws the current speech bubble + typewriter-revealed text. Portrait-stage layout (stages A/C) mirrors TutorialGuide's own DEFAULT bubble (bottom-right sprite origin, unflipped, near edge to the right); machine-stage layout (stage E) mirrors TutorialGuide's own MIRRORED bubble (negative xscale, near edge to the left) -- per request, "mirror the speech bubble sprite". See .md.
    /// @param {Struct.FateEngineOverlay} _fateEngineOverlay
    static Draw_Bubble = function(_fateEngineOverlay) {
        var _showingPortraitBubble = (!usingMachineBubble) && (portraitState == "idle") && (phase == "portraitIntro" || phase == "portraitReturn");
        var _showingMachineBubble  = usingMachineBubble && (phase == "machineDialogue");
        if (!_showingPortraitBubble && !_showingMachineBubble) return;

        bubbleText.reveal(floor(bubbleRevealChars));

        var _rect = _showingMachineBubble ? _MachineBubbleRect(_fateEngineOverlay) : _PortraitBubbleRect();

        // 2026-08-15 follow-up ("don't scale up the text bubbles anymore"): bubble sprite now draws at
        // NATIVE (1x) scale -- was DEALER_INTRO_SCALE (2x). _rect's anchor terms are unchanged (see
        // _PortraitBubbleRect()/_MachineBubbleRect()); only the bubble's own drawn size shrunk to match.
        // Text buffer below is now applied unscaled too. See .md.
        var _drawX        = _showingMachineBubble ? _rect.x1 : _rect.x2;
        var _bubbleXScale = _showingMachineBubble ? -1 : 1;
        draw_sprite_ext(sSpeechBubbleInGame, bubbleFrame, _drawX, _rect.y2, _bubbleXScale, 1, 0, c_white, 1);

        // 2026-08-16 request ("adjust text alignment for flipped speech bubble, moved 16px to the right"):
        // the machine-stage bubble draws FLIPPED (negative xscale, tail asymmetry reads wrong with the
        // plain buffer, same root cause TUTORIAL_BUBBLE_MIRRORED_TEXT_OFFSET_X already exists to fix for
        // Booger's own mirrored bubble) -- now uses its own DEALER_INTRO_MACHINE_TEXT_OFFSET_X instead of
        // the plain buffer. Portrait-stage (non-flipped) bubble is unaffected. See macro comment/.md.
        var _textX = _rect.x1 + (_showingMachineBubble ? DEALER_INTRO_MACHINE_TEXT_OFFSET_X : DEALER_INTRO_BUBBLE_BUFFER);
        var _textY = _rect.y1 + DEALER_INTRO_BUBBLE_BUFFER;
        DrawCardTextWithShadow(bubbleText, _textX, _textY, 1);
    }
}
