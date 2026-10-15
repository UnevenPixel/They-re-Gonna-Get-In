// The real Fate Engine session overlay -- dim/freeze, drum machine, a
// physical pull lever (spins the machine), and leave/cashout buttons.
// See FateEngineOverlayScripts.md.

#macro FATE_ENGINE_SPIN_DURATION_STEPS 90 // steps before drums begin landing
#macro FATE_ENGINE_MACHINE_UI_BAR_SCALE 2 // shared with sMainUIBarBottom's draw scale -- keep in sync, see .md

#macro FATE_ENGINE_BUTTON_WIDTH   180
#macro FATE_ENGINE_BUTTON_HEIGHT  50
#macro FATE_ENGINE_BUTTON_GAP     20
#macro FATE_ENGINE_BUTTON_TOP_Y   30

// Open-intro animation (2026-08-14 request) -- gradient tint fades in over
// FATE_ENGINE_INTRO_GRADIENT_STEPS; the tree layers fade+parallax in at
// TWICE that speed (literally half the duration, not a separately-tuned
// value -- see _TreesProgress()); the machine's pop-up-from-bottom begins
// once the trees reach FATE_ENGINE_INTRO_POPUP_TRIGGER_FRACTION of their
// own animation. All three progress ratios are driven off a single shared
// step counter (introElapsedSteps) -- see .md.
//
// Close/leave animation (2026-08-14 follow-up request) -- the SAME three
// stages play in reverse (gradient/trees fade out, trees parallax back out
// to the left, machine pops back down), but UNSTAGGERED -- all three start
// together the instant Leave() is called, off their own closeElapsedSteps
// counter, rather than the open sequence's 90%-trigger delay. See
// _GradientProgress()/_TreesProgress()/_MachineProgress() below (each
// closing-aware) and .md.
//
// 2026-08-14 follow-up: every duration below is x1.5 ("50% slower") from
// the original pass -- FATE_ENGINE_INTRO_GRADIENT_STEPS 60->90,
// FATE_ENGINE_INTRO_POPUP_STEPS 30->45 (FATE_ENGINE_INTRO_TREES_STEPS is a
// derived macro, half of GRADIENT_STEPS, so it follows automatically:
// 30->45). FATE_ENGINE_INTRO_POPUP_TRIGGER_FRACTION is a relative fraction,
// not a duration, so it's untouched by this pass.
#macro FATE_ENGINE_INTRO_GRADIENT_STEPS 90 // ~1.5s @ 60 steps/sec, matching DIALOGUE_FADE_STEPS/PLOT_HOVER_FADE_STEPS's own "steps ~= real seconds at room speed" convention (DialogueOverlayScripts.gml/PlotHoverScripts.gml) -- untuned judgment call, see .md
#macro FATE_ENGINE_INTRO_TREES_STEPS (FATE_ENGINE_INTRO_GRADIENT_STEPS / 2) // "twice as fast" per request -- literal half the gradient's duration, not a separate tuned value
#macro FATE_ENGINE_INTRO_POPUP_TRIGGER_FRACTION 0.9 // "after they are at 90% to final position" per request -- OPEN sequence only, see .md
#macro FATE_ENGINE_INTRO_POPUP_STEPS 45 // ~0.75s -- untuned judgment call, see .md

#macro FATE_ENGINE_TREES_FAR_PARALLAX_DISTANCE  150 // px the FAR layer (index 0) travels while parallaxing in from the left -- untuned judgment call, see .md
#macro FATE_ENGINE_TREES_NEAR_PARALLAX_DISTANCE 350 // px the NEAR layer (index 1) travels -- deliberately larger than the far layer's distance, so it appears to move faster/closer -- the standard parallax depth cue, see .md

#macro FATE_ENGINE_GRADIENT_TINT_COLOR make_color_rgb(0x3A, 0x2E, 0x4A) // matches this overlay's existing button/dim purple -- judgment call, see .md
#macro FATE_ENGINE_GRADIENT_TINT_MAX_ALPHA 0.85 // peak alpha at the gradient's strongest (top-left) corner once fully faded in -- 2026-08-14 follow-up ("make the dimming darker as a whole"), raised from the initial 0.6 pass; replaces the old flat 0.75 full-GUI dim, untuned judgment call, see .md

// Spin lever (2026-08-14 request) -- sFateEngineHandle (3 frames: 0 static
// base plate, 1 the animated lever bar, 2 the grabbable handle/ball) REPLACES
// the old "Spin" button entirely. The whole assembly is positioned relative
// to sFateEngineBody's own draw anchor and drawn inside Draw()'s existing
// machine matrix_world group, so it slides with the rest of the machine
// during the open/close pop animation. See DrawLever()/the lever state
// machine in Update() and .md for the full breakdown -- in particular the
// ambiguity around whether FATE_ENGINE_HANDLE_ALIGN_X/Y and
// FATE_ENGINE_HANDLE_BALL_MAX_DROP_PX are native sprite-space (scaled by
// FATE_ENGINE_MACHINE_UI_BAR_SCALE, the assumption made here) or literal
// on-screen GUI pixels -- FLAG if the alignment looks off by ~2x in-engine.
#macro FATE_ENGINE_HANDLE_ALIGN_X 92  // native-sprite-space px offset from sFateEngineBody's own draw anchor (centerX) to the lever assembly's base anchor, scaled by FATE_ENGINE_MACHINE_UI_BAR_SCALE at draw time -- per request, see .md
#macro FATE_ENGINE_HANDLE_ALIGN_Y -101 // native-sprite-space px offset from bodyBottomY -- negative = up, same scaling as X above, see .md

#macro FATE_ENGINE_LEVER_IDLE_YSCALE   1     // lever (frame 1) yscale multiplier at rest -- multiplies FATE_ENGINE_MACHINE_UI_BAR_SCALE, not a replacement of it, so the lever stays visually consistent with the rest of the (2x-scaled) machine at idle
#macro FATE_ENGINE_LEVER_PULLED_YSCALE -0.25 // lever (frame 1) yscale multiplier at full pull (110px+ of drag) -- per request; the sign flip is what visually "throws" the lever past its pivot

#macro FATE_ENGINE_HANDLE_BALL_MAX_DROP_PX 85 // native-sprite-space px the handle/ball (frame 2) drops below its native draw position at full pull (leverProgress 1, i.e. 110px of mouse drag), scaled by FATE_ENGINE_MACHINE_UI_BAR_SCALE like the alignment offsets above. 2026-08-15 follow-up: was 17, and only kicked in once the lever bar's OWN yscale crossed 0 (the last ~20% of the pull) -- per request ("from the 0 position to 110px mouse movement, the 2nd index of the lever needs to move from 0 to 85px"), now a straight linear map across the WHOLE pull instead, see _LeverHandleBallOffsetY() and .md
#macro FATE_ENGINE_LEVER_PULL_DISTANCE_PX 110 // GUI/mouse-space px of downward drag = full lever travel -- triggers Spin(). Unlike the alignment/drop macros above, this is compared directly against device_mouse_y_to_gui() deltas, so it's intentionally NOT scaled by FATE_ENGINE_MACHINE_UI_BAR_SCALE

#macro FATE_ENGINE_LEVER_HOLD_STEPS   30 // ~0.5s @ 60 steps/sec, per request ("hold at its lowest position for half a second")
#macro FATE_ENGINE_LEVER_RETURN_STEPS 30 // ~0.5s -- ease-back-to-idle duration after the hold; request specified "easing back" but not a duration, untuned judgment call, see .md

// The Dealer (2026-08-14 request) -- sDealer, an 8-frame character sprite
// (2026-08-14 follow-up: sprite resource was updated to 8 frames after the
// original single-frame integration -- frame 0 is her idle/resting face,
// frames 1-7 are a blink played start to finish then looped back to 0, see
// the blink macros/fields/_DealerBlink* functions below and .md) drawn at
// NATIVE (1,1) scale (per request, "will not be scaled up") leaning against
// the machine. Positioned via a "corner" alignment: both sDealer and
// sFateEngineBody each have a conceptual "corner" point (where she's
// leaning) defined as a fixed offset from their OWN origin --
// FATE_ENGINE_DEALER_LEAN_CORNER_X/Y for hers, FATE_ENGINE_BODY_LEAN_CORNER_X/Y
// for the machine's -- and _DealerBasePosition() solves for wherever her
// origin needs to land on screen so the two corner points exactly coincide.
// See _DealerBasePosition()/DrawDealer() and .md. Same scaling ambiguity as
// FATE_ENGINE_HANDLE_ALIGN_X/Y (see that macro's comment above) applies to
// FATE_ENGINE_BODY_LEAN_CORNER_X/Y -- assumed native-sprite-space, scaled by
// FATE_ENGINE_MACHINE_UI_BAR_SCALE. FATE_ENGINE_DEALER_LEAN_CORNER_X/Y is
// NOT scaled, since the dealer herself is drawn at native 1x.
#macro FATE_ENGINE_DEALER_LEAN_CORNER_X 298  // px from sDealer's own origin to her lean corner, in her own (unscaled) draw space -- per request
#macro FATE_ENGINE_DEALER_LEAN_CORNER_Y -325 // same, Y axis

// Dealer blink animation (2026-08-14 follow-up request, "somewhat random
// but rhythmic timing... not constantly, but every few seconds with some
// slight variation"). Idle-timer range, re-rolled after every blink --
// untuned judgment call, the request specified the FEEL ("every few
// seconds", "slight variation") not exact numbers, see .md.
#macro FATE_ENGINE_DEALER_BLINK_INTERVAL_MIN_STEPS 180 // 3s @ 60 steps/sec
#macro FATE_ENGINE_DEALER_BLINK_INTERVAL_MAX_STEPS 300 // 5s

#macro FATE_ENGINE_BODY_LEAN_CORNER_X -64  // native-sprite-space px from sFateEngineBody's own origin to the machine's matching lean corner, scaled by FATE_ENGINE_MACHINE_UI_BAR_SCALE at draw time -- per request, see .md
#macro FATE_ENGINE_BODY_LEAN_CORNER_Y -132 // same, Y axis

// Machine activation (2026-08-16 request, "update the fate token functionality... spend the token to
// 'activate the machine'... when the machine is not active, have the drums be dimmed out, with no symbols
// on them"). machineActive/machineActiveFade (see the FateEngineOverlay() field comments) drive a crossfade
// between a dimmed, symbol-less drum look and the normal lit one -- smooth on the way UP (Activate()), an
// instant snap on the way DOWN (Cashout(), per request "INSTANTLY return to the dimmed state... simulates
// the lights turning on, then cutting out"). See Activate()/Update()/Draw() and .md.
#macro FATE_ENGINE_ACTIVATE_FADE_STEPS 45 // ~0.75s @ 60 steps/sec, matching FATE_ENGINE_INTRO_POPUP_STEPS's own duration -- untuned judgment call, independent of global.matchSpeed like every other animation in this file (matchSpeed is 0 the whole time the overlay is open), see .md
#macro FATE_ENGINE_DRUM_DIMMED_COLOR make_color_rgb(0x40, 0x38, 0x48) // dark, desaturated version of the drum slot's own lit color (0xE1D3EA, see Draw()) -- judgment call, "dimmed out" reading, see .md

// Activation particle burst (2026-08-16 request, "have the token disappear and a number of purple and gold
// particles rise up from where the token disappeared to"). A plain GUI-space struct-array particle system --
// same "roll your own array of structs, Step()/Draw() them" idiom XpBarWidget's own tossed-coin system
// already uses in this project -- deliberately NOT the room-space ResourceParticleScripts.gml/
// oResourceProducedParticle system, which creates actual room-space instances and would be positioned wrong
// for a GUI-space HUD event like this one. See _SpawnActivateParticles()/.md.
#macro FATE_ENGINE_ACTIVATE_PARTICLE_COUNT       16   // purple+gold particles per burst -- untuned judgment call, see .md
#macro FATE_ENGINE_ACTIVATE_PARTICLE_LIFE        50   // steps before a particle fades out and is removed
#macro FATE_ENGINE_ACTIVATE_PARTICLE_SPEED_MIN   0.6  // px/step initial burst speed range
#macro FATE_ENGINE_ACTIVATE_PARTICLE_SPEED_MAX   1.8
#macro FATE_ENGINE_ACTIVATE_PARTICLE_RISE_BIAS   1.2  // extra px/step of constant upward drift on top of the burst velocity -- per request, "particles rise up", not a purely omnidirectional burst
#macro FATE_ENGINE_ACTIVATE_PARTICLE_SIZE_MIN    2    // half-width/height of each particle's square, px
#macro FATE_ENGINE_ACTIVATE_PARTICLE_SIZE_MAX    4
#macro FATE_ENGINE_ACTIVATE_PARTICLE_PURPLE_COLOR make_color_rgb(0xB0, 0x7C, 0xE8) // matches DEALER_INTRO_TEXT_COLOR's own purple -- judgment call, no other "purple" reference exists in this file, see .md
#macro FATE_ENGINE_ACTIVATE_PARTICLE_GOLD_COLOR   make_color_rgb(230, 162, 43)     // matches TUTORIAL_GUIDE_HIGHLIGHT_COLOR's own gold-orange -- judgment call, see .md

// Corruption (2026-08-16 follow-up request, "show corruption... lights placed at the following
// coordinates... charge up in corruption... faces will go in this order: White, Blue, Green, Yellow,
// Purple"). 5 levels (0-4, one per face color), each with a 4-light "charge" bar that fills via
// re-spins (see Spin()/_GainCorruptionCharge()) and, once full, triggers a level-up: the new level's
// face plays Start -> Loop (held exactly 1 second) -> settles on its own End sprite, and THEN (not
// concurrently) the 4 charge lights instantly switch off in succession, 4 down to 1, before spins are
// allowed again (corruptionLevelingUp). See _BeginCorruptionLevelUp()/_StepCorruptionFace()/
// _StepCorruptionChargeLights()/DrawCorruption() and .md for the full writeup, including the "White"
// vs "Blue" correction made for level 1 (confirmed via AskUserQuestion, not a unilateral guess).
#macro FATE_ENGINE_CORRUPTION_MAX_LEVEL   4 // White(0)/Blue(1)/Green(2)/Yellow(3)/Purple(4) -- matches the 5 sFateEngineFace* color sets and the charge-light sprite table below
#macro FATE_ENGINE_CORRUPTION_CHARGE_MAX  4 // 4 charge-light pairs per level, per the 4 position pairs given in the request

// Charge light positions -- native-sprite-space px relative to sFateEngineBody's own TOP-LEFT corner
// (unlike FATE_ENGINE_HANDLE_ALIGN_X/Y etc above, which are relative to centerX/bodyBottomY), scaled by
// FATE_ENGINE_MACHINE_UI_BAR_SCALE at draw time -- same native-sprite-space family, per request ("native
// pixel measurements, affected by scaling"). Literal coordinates as given, NOT derived via a mirror
// formula (the left/right pairs aren't perfectly symmetric about the body's centerline -- e.g. pair 1 is
// 39/200, not 39/201 -- so using the exact given numbers avoids introducing an assumption). See .md.
global.fateEngineCorruptionLightOffsets = [
    { left: { x: 39, y: 92 }, right: { x: 200, y: 92 } },
    { left: { x: 51, y: 69 }, right: { x: 188, y: 69 } },
    { left: { x: 69, y: 54 }, right: { x: 170, y: 54 } },
    { left: { x: 93, y: 47 }, right: { x: 146, y: 47 } },
];

#macro FATE_ENGINE_CORRUPTION_FACE_OFFSET_X 120 // native-sprite-space px from sFateEngineBody's own top-left corner, per request ("positioned at {120,36}")
#macro FATE_ENGINE_CORRUPTION_FACE_OFFSET_Y 36

// Per-level sprite tables, index 0-4 matches corruptionLevel -- see _BeginCorruptionLevelUp()/DrawCorruption().
global.fateEngineCorruptionFaceStart = [sFateEngineFaceWhiteStart, sFateEngineFaceBlueStart, sFateEngineFaceGreenStart, sFateEngineFaceYellowStart, sFateEngineFacePurpleStart];
global.fateEngineCorruptionFaceLoop  = [sFateEngineFaceWhiteLoop,  sFateEngineFaceBlueLoop,  sFateEngineFaceGreenLoop,  sFateEngineFaceYellowLoop,  sFateEngineFacePurpleLoop];
global.fateEngineCorruptionFaceEnd   = [sFateEngineFaceWhiteEnd,   sFateEngineFaceBlueEnd,   sFateEngineFaceGreenEnd,   sFateEngineFaceYellowEnd,   sFateEngineFacePurpleEnd];

#macro FATE_ENGINE_CORRUPTION_LIGHT_FADE_STEPS   20 // ~0.33s @ 60 steps/sec -- untuned judgment call, "have them fade in when gained" didn't specify a duration, see .md
#macro FATE_ENGINE_CORRUPTION_LOOP_HOLD_STEPS    60 // exactly 1 second @ 60 steps/sec, per request ("for 1 second") -- see .md
#macro FATE_ENGINE_CORRUPTION_SHUTOFF_STEP_STEPS 10 // steps between each light turning off during the post-level-up shutoff succession -- untuned judgment call, "in succession" implies SOME gap but no duration was given, see .md

/// @function _FateEngineGradientAlphaUniform()
/// @description Cached shFateEngineGradientTint u_alpha uniform handle -- fetched once ever (static), same "cache the handle, warn once if not found" convention this project's other custom shaders use (shFlagWave/shPaletteSwap/shDitherDissolve, see FateEngineOverlayScripts.md). See .md.
/// @returns {Real}
function _FateEngineGradientAlphaUniform() {
    static _handle = -2; // -2 = "not fetched yet" sentinel, distinct from shader_get_uniform's own -1 "not found" return
    if (_handle == -2) {
        _handle = shader_get_uniform(shFateEngineGradientTint, "u_alpha");
        if (_handle == -1) show_debug_message("shFateEngineGradientTint: u_alpha uniform not found -- shader/uniform name mismatch?");
    }
    return _handle;
}

/// @function _FateEngineEaseInCubic(_t)
/// @description Cubic ease-in (slow start, accelerating toward the end) -- 2026-08-14 follow-up request ("have the tree parallax ease in slower", "have the fate engine popping up also be lerped/eased in"). Applied to the RAW 0..1 progress ratio before it's fed into a lerp() call, same "eased ratio in, lerp() out" shape TutorialGuideScripts.gml's _AnimCurveY() already established for its own ease-out leg -- this is the mirror-image curve (t^3 instead of 1-(1-t)^3), chosen because "ease IN" specifically means starting slow, not decelerating into place. See .md.
/// @param {Real} _t 0..1.
/// @returns {Real} 0..1.
function _FateEngineEaseInCubic(_t) {
    return _t * _t * _t;
}

/// @function _FateEngineEaseOutCubic(_t)
/// @description Cubic ease-out (fast start, decelerating into the end) -- 2026-08-14 request, used for the spin lever's ease-back-to-idle after a pull (mirrors _FateEngineEaseInCubic's shape, same "eased ratio in, lerp() out" pattern, and matches TutorialGuideScripts.gml's own ease-out convention for things settling into a resting position). See .md.
/// @param {Real} _t 0..1.
/// @returns {Real} 0..1.
function _FateEngineEaseOutCubic(_t) {
    return 1 - power(1 - _t, 3);
}

/// @function FateEngineButtonRects()
/// @description GUI-space rects of the 2 overlay buttons, centered along the top of the screen. 2026-08-14: was 3 (leave/cashout/spin) -- Spin is now the pull lever (see DrawLever()/.md), not a button.
/// @returns {Struct} { leave, cashout }, each { x1, y1, x2, y2 }.
function FateEngineButtonRects() {
    var _centerX = display_get_gui_width() / 2;
    var _totalW  = FATE_ENGINE_BUTTON_WIDTH * 2 + FATE_ENGINE_BUTTON_GAP;
    var _x1      = _centerX - _totalW / 2;

    var _leave = {
        x1: _x1, y1: FATE_ENGINE_BUTTON_TOP_Y,
        x2: _x1 + FATE_ENGINE_BUTTON_WIDTH, y2: FATE_ENGINE_BUTTON_TOP_Y + FATE_ENGINE_BUTTON_HEIGHT
    };

    var _x2 = _x1 + FATE_ENGINE_BUTTON_WIDTH + FATE_ENGINE_BUTTON_GAP;
    var _cashout = {
        x1: _x2, y1: FATE_ENGINE_BUTTON_TOP_Y,
        x2: _x2 + FATE_ENGINE_BUTTON_WIDTH, y2: FATE_ENGINE_BUTTON_TOP_Y + FATE_ENGINE_BUTTON_HEIGHT
    };

    return { leave: _leave, cashout: _cashout };
}

/// @function FateEngineOverlay()
/// @description The Fate Engine session overlay. Plain struct, owner
///        (oUnitControl) calls Update() once per Step and Draw() once per Draw GUI.
function FateEngineOverlay() constructor {
    isOpen          = false;
    isSessionActive = false; // 2026-08-16 follow-up (round 2): now set true ONLY by Activate() (spending a dragged Fate Token) -- Spin() no longer starts sessions itself, see Spin()/Activate()/.md.
    savedMatchSpeed = 1;
    spinTimer       = 0;
    resultsBanked   = true;
    pendingRewards  = []; // Array<Struct.FateEngineItem>, one per drum, REPLACED (not appended to) every time a spin lands (Update()'s resultsBanked block, 2026-08-16 bugfix) -- always reflects only the 3 items currently shown on the tumblers, never a stack of every past spin this session. Cleared on Cashout() (grant) and on Activate()'s own new-session start (2026-08-16 follow-up, round 2 -- moved here from Spin(), which no longer starts sessions).
    hasSpunThisSession = false; // 2026-08-16 follow-up (round 2, "spending the token starts the session, [it does not] resolve until at least one spin has been done") -- true once a spin has actually landed since the session started (Update()'s resultsBanked block). Cashout() requires this alongside isSessionActive, so a session that's been started (machine lit, drums no longer dimmed) but never spun can't be cashed out for nothing. See Cashout()/.md.

    introElapsedSteps = 0; // 2026-08-14 -- steps since this Open(), drives the gradient/trees/machine-popup intro sequence. Reset on every Open(). See _GradientProgress()/_TreesProgress()/_MachineProgress() below and .md.

    closing           = false; // 2026-08-14 follow-up -- true from Leave() until the close animation fully finishes. isOpen stays TRUE the whole time (same "isOpen stays true until the fade completes" idiom DialogueOverlayScripts.gml/PlotHoverScripts.gml already established), so oUnitControl/Step_0.gml keeps suppressing player input until the overlay is actually gone. See .md.
    closeElapsedSteps = 0;  // steps since Leave() was called. Reset every time closing starts.

    // Spin lever (2026-08-14 request) -- replaces the old Spin button. State
    // machine: "idle" -> "dragging" -> "holding" -> "returning" -> "idle".
    // See the lever state machine block in Update() and .md.
    leverState                = "idle"; // "idle" | "dragging" | "holding" | "returning"
    leverProgress             = 0;      // 0..1, 0 = idle (yscale FATE_ENGINE_LEVER_IDLE_YSCALE), 1 = full pull (yscale FATE_ENGINE_LEVER_PULLED_YSCALE)
    leverGrabAnchorY          = 0;       // GUI-space mouse Y captured at the moment of grab -- drag delta is measured from this
    leverHoldTimer            = 0;       // steps remaining held at full pull before easing back, see FATE_ENGINE_LEVER_HOLD_STEPS
    leverReturnStartProgress  = 0;       // leverProgress at the moment "returning" began -- lets an early release (before full pull) ease back from wherever it was, not just from 1, see .md
    leverReturnElapsedSteps   = 0;       // steps since "returning" began

    // Dealer blink animation (2026-08-14 follow-up request) -- state
    // machine: "idle" (waiting out dealerBlinkTimer) -> "blinking" (stepping
    // dealerBlinkFrame 1->7, holding each frame for
    // _DealerBlinkFrameSteps()) -> back to "idle" with a freshly re-rolled
    // dealerBlinkTimer. See the blink block in Update()/DrawDealer() and .md.
    dealerBlinkState = "idle"; // "idle" | "blinking"
    dealerBlinkFrame = 0;      // 0 = idle/resting face, 1..7 = mid-blink -- what DrawDealer() actually renders
    dealerBlinkTimer = irandom_range(FATE_ENGINE_DEALER_BLINK_INTERVAL_MIN_STEPS, FATE_ENGINE_DEALER_BLINK_INTERVAL_MAX_STEPS); // steps until her first blink -- inlined here rather than via a helper since this runs during construction, before this struct's own static methods are guaranteed assigned yet, see .md

    // Machine hold/release + interaction lock (2026-08-14 follow-up request,
    // "Dealer intro" tutorial-continuation scene) -- lets an external caller
    // (DealerIntroScripts.gml) open the overlay with the gradient/trees
    // background playing while the drums/body/lever/Dealer group stays
    // withheld fully off-screen, then release it later on its own cue
    // (ReleaseMachine()), and separately keep the buttons/lever
    // non-interactive even once popped up until a scripted scene finishes
    // (UnlockInteraction()). Every field here defaults to/resets to the
    // "normal" (unheld, unlocked) value on every Open() unless its new
    // optional _holdMachine param is true, so ordinary player-driven Fate
    // Engine sessions (XP-bar click) are completely unaffected -- see
    // _MachineProgress()/_IntroTotalSteps()/Open()/ReleaseMachine()/
    // UnlockInteraction() below and .md.
    machineHeld                = false; // true from a held Open() until ReleaseMachine() -- while true, _MachineProgress() stays pinned at 0 regardless of introElapsedSteps
    machineHoldUsed            = false; // true for the REST of this session once a held Open() happens, even after release -- tells _MachineProgress()/_IntroTotalSteps() to use machineReleaseElapsedSteps instead of the automatic 90%-of-trees trigger, since that trigger's math assumes the machine was never deliberately delayed
    machineReleaseElapsedSteps = 0;     // steps since ReleaseMachine() was called -- drives the machine's pop-up progress once machineHoldUsed, independently of introElapsedSteps (which may have already finished long before release)
    interactionLocked          = false; // true from a held Open() until UnlockInteraction() -- independent of machineHeld/_MachineProgress(), since a scripted scene may keep talking for a while AFTER the machine has fully popped up; suppresses button clicks and lever-grab eligibility (NOT their visibility -- drums/body/lever/Dealer still draw normally) while true

    // Machine activation (2026-08-16 request) -- see the macro block comment above and Activate()/.md.
    machineActive     = false; // true once a dragged Fate Token has been dropped near the machine (Activate(), called from XpBarScripts.gml's drag interaction). Reset instantly false by Cashout() and defensively by every Open() (fresh session starts dimmed).
    machineActiveFade = 0;     // 0 = fully dimmed/no symbols, 1 = fully lit/symbols visible. Eases 0->1 over FATE_ENGINE_ACTIVATE_FADE_STEPS while machineActive (Update()); snaps instantly to 0 whenever machineActive is cleared -- no easing on the way down, per request.
    activateParticles = [];    // { x, y, vx, vy, color, size, life, lifeMax } -- purple/gold burst spawned by Activate(), see _SpawnActivateParticles()/.md.

    // Corruption (2026-08-16 follow-up request) -- see the macro block comment above and
    // _GainCorruptionCharge()/_BeginCorruptionLevelUp()/.md for the full mechanic. Deliberately NOT
    // reset by Open() (unlike machineActive/hasSpunThisSession above) -- this is the MACHINE's own
    // permanent state, carried across every session, not a per-session one. Judgment call, not
    // explicitly specified either way -- flag if corruption should instead reset per session/on Leave().
    corruptionLevel   = 0; // 0-4, White/Blue/Green/Yellow/Purple -- see FATE_ENGINE_CORRUPTION_MAX_LEVEL
    corruptionCharge  = 0; // 0-4, how many of the 4 charge lights toward corruptionLevel+1 are currently lit
    corruptionChargeLightAlpha = [0, 0, 0, 0]; // one per charge-light pair, 0-1 fade-in progress -- see _StepCorruptionChargeLights()/.md. This, not corruptionCharge, is what DrawCorruption() actually reads -- lets a light stay visually lit (alpha 1) through the whole level-up face animation even after corruptionCharge itself resets to 0, until the shutoff sequence below explicitly zeroes it.
    corruptionFlameFrame      = 0; // shared animation frame for the level-3/4 charge lights (sFateEngineFlameYellow/Purple, both animated, unlike sFateEngineLights' static per-level frames) -- see _CorruptionChargeLightSprite()/.md
    corruptionFlameFrameTimer = 0;

    // Corruption face -- Start -> Loop (held 1s) -> idle on own End, see _StepCorruptionFace()/.md.
    corruptionFacePhase      = "idle"; // "idle" | "start" | "loop" -- "idle" draws corruptionLevel's own End sprite at its last frame, per request
    corruptionFaceFrame      = 0;      // current frame within whichever sprite corruptionFacePhase points at (start/loop only -- idle always uses the End sprite's own last frame)
    corruptionFaceFrameTimer = 0;      // steps until corruptionFaceFrame advances, from that sprite's own baked playbackSpeed, see _CorruptionFaceFrameSteps()
    corruptionFaceLoopTimer  = 0;      // steps remaining in the Loop phase's fixed FATE_ENGINE_CORRUPTION_LOOP_HOLD_STEPS hold

    // Post-level-up light shutoff + spin lock -- see _StepCorruptionChargeLights()/Spin()/.md.
    corruptionLevelingUp   = false; // true from the instant a charge-completing re-spin triggers a level-up until the light-shutoff sequence below finishes -- blocks _SpinEligible(), per request ("...before allowing spins again")
    corruptionShutoffIndex = -1;    // -1 = not shutting off; else counts DOWN 3->0 (light pairs "4 to 1", per request), one per FATE_ENGINE_CORRUPTION_SHUTOFF_STEP_STEPS
    corruptionShutoffTimer = 0;

    var _centerX = display_get_gui_width() / 2;

    // Backed out through sMainUIBarBottom's own yoffset so the machine's
    // bottom aligns with the UI bar's real top edge, not a guessed value.
    var _uiBarDrawY = 1080;
    var _uiBarTopY  = _uiBarDrawY - sprite_get_yoffset(sMainUIBarBottom) * FATE_ENGINE_MACHINE_UI_BAR_SCALE;
    bodyBottomY = _uiBarTopY;

    var _drumRadius = 56;
    var _drumHeight = _drumRadius * 2;
    var _drumY      = (bodyBottomY - 320) + _drumHeight;

    drums = [
        new FateDrum(_centerX - 104, _drumY, _drumRadius),
        new FateDrum(_centerX,       _drumY, _drumRadius),
        new FateDrum(_centerX + 104, _drumY, _drumRadius),
    ];

    /// @function Open(_selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController, _holdMachine)
    /// @description Opens the overlay: freezes the match, resets player
    ///        input state to a clean slate. No-ops if already open.
    /// @param {Struct.SelectionController} _selectionController
    /// @param {Struct.OrderMenu} _orderMenu
    /// @param {Struct.CastleGarrisonMenu} _castleGarrisonMenu
    /// @param {Struct.ArmyLimitMenu} _armyLimitMenu
    /// @param {Struct.BlueprintController} _blueprintController
    /// @param {Bool} [_holdMachine] 2026-08-14 follow-up, defaults false (every normal caller, e.g. the XP-bar click, is unaffected). When true: the gradient tint + trees still animate in normally, but the drums/body/lever/Dealer group stays fully off-screen (and buttons/lever stay non-interactive) until a later ReleaseMachine()/UnlockInteraction() call -- see DealerIntroScripts.gml and .md.
    /// @returns {Struct.FateEngineOverlay} self
    static Open = function(_selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController, _holdMachine = false) {
        if (isOpen) return self;

        isOpen          = true;
        savedMatchSpeed = global.matchSpeed;
        global.matchSpeed = 0;
        global.fateEngineOverlayActive = true; // suppression hook read by hover controllers
        introElapsedSteps = 0; // 2026-08-14 -- replay the gradient/trees/machine-popup intro from scratch every Open(), see .md

        // 2026-08-14 follow-up -- start her fresh at the idle face with a
        // newly rolled blink timer, rather than possibly resuming mid-blink
        // from wherever a previous session's close animation cut her off.
        dealerBlinkState = "idle";
        dealerBlinkFrame = 0;
        dealerBlinkTimer = _DealerNextBlinkIntervalSteps();

        // 2026-08-14 follow-up ("Dealer intro" scene) -- see the field
        // comments above and _MachineProgress()/_IntroTotalSteps() below.
        // interactionLocked mirrors _holdMachine here for convenience (a
        // held open always implies "not yet interactive" for this use case)
        // but is unlocked SEPARATELY from the machine's own release, via
        // UnlockInteraction() -- releasing the machine just lets it visually
        // pop up, it doesn't by itself make the buttons/lever clickable.
        machineHeld                = _holdMachine;
        machineHoldUsed            = _holdMachine;
        machineReleaseElapsedSteps = 0;
        interactionLocked          = _holdMachine;

        // 2026-08-16 request -- defensive reset, not explicitly called out by the request (which only
        // names Cashout() as a reset trigger) but consistent with every other field in this block: a fresh
        // session should always start fully dimmed, never carrying over a stale "lit" state from a
        // previous session. See machineActive's own field comment/.md.
        machineActive      = false;
        machineActiveFade  = 0;
        activateParticles  = [];
        hasSpunThisSession = false; // 2026-08-16 follow-up (round 2) -- same defensive-reset reasoning as the three fields above

        _selectionController.Deselect();
        _orderMenu.Close();
        _castleGarrisonMenu.Close();
        _armyLimitMenu.Close();
        if (_blueprintController.dragging) _blueprintController.CancelDrag();

        return self;
    }

    /// @function ReleaseMachine()
    /// @description 2026-08-14 follow-up -- ends a held Open()'s withholding of the drums/body/lever/Dealer group, letting it pop up on its own timer (machineReleaseElapsedSteps, see _MachineProgress()) starting from THIS moment, independent of introElapsedSteps (which may already be long finished). No-ops harmlessly if the overlay was never opened with _holdMachine true. Does NOT by itself unlock interaction -- see UnlockInteraction(). See .md.
    /// @returns {Struct.FateEngineOverlay} self
    static ReleaseMachine = function() {
        machineHeld                = false;
        machineReleaseElapsedSteps = 0;
        return self;
    }

    /// @function UnlockInteraction()
    /// @description 2026-08-14 follow-up -- clears interactionLocked, letting the buttons/lever actually respond to clicks again (assuming they're otherwise eligible, e.g. _MachineProgress() >= 1). Independent of ReleaseMachine() -- a scripted scene may want the machine visually popped up for a while before the player is actually allowed to touch it. See .md.
    /// @returns {Struct.FateEngineOverlay} self
    static UnlockInteraction = function() {
        interactionLocked = false;
        return self;
    }

    /// @function LockInteraction()
    /// @description 2026-08-15 follow-up -- the inverse of UnlockInteraction(), re-locking an already-open, already-popped-up machine. Lets a caller pause player interaction for a SECOND scripted beat without a fresh Open()/hold cycle (e.g. DealerIntroScripts.gml's post-first-spin follow-up monologue). See .md.
    /// @returns {Struct.FateEngineOverlay} self
    static LockInteraction = function() {
        interactionLocked = true;
        return self;
    }

    /// @function Leave()
    /// @description Begins the close/leave animation (2026-08-14 follow-up -- was an instant close). No-op if not open, a session is active, or already closing. global.matchSpeed/global.fateEngineOverlayActive aren't restored/cleared until the close animation actually FINISHES (see Update()) -- isOpen stays true the whole time, so the overlay keeps suppressing player input and the match stays frozen until it's actually gone from screen.
    /// @returns {Struct.FateEngineOverlay} self
    static Leave = function() {
        if (!isOpen || isSessionActive || closing) return self;
        closing = true;
        closeElapsedSteps = 0;
        return self;
    }

    /// @function Spin()
    /// @description Spins every drum. No-op if a previous spin hasn't landed yet, OR (2026-08-16
    ///        follow-up, round 2) if no session is active -- Spin() no longer starts a session or spends a
    ///        Fate Token itself; that now happens exclusively in Activate() (dragging a token onto the
    ///        machine). "Spending the token starts the session" -- see Activate()/_TokenActivateEligible()/
    ///        .md. This is a real behavior change: the lever can no longer be pulled to spend a token and
    ///        start a fresh session on its own -- a token must be dragged in first.
    /// @returns {Struct.FateEngineOverlay} self
    static Spin = function() {
        if (!isSessionActive || corruptionLevelingUp) return self; // 2026-08-16 follow-up (corruption) -- see .md, "...before allowing spins again"

        for (var i = 0; i < array_length(drums); i++) {
            if (drums[i].state != "stopped") return self;
        }

        // 2026-08-16 follow-up (corruption request) -- "each Spin() after the initial one" grants a
        // charge point, per user confirmation. hasSpunThisSession is only true once a PREVIOUS spin in
        // THIS session has already landed (see Update()'s resultsBanked block), so this correctly skips
        // the session's own first spin and grants on every free re-spin after it. See
        // _GainCorruptionCharge()/.md.
        if (hasSpunThisSession) {
            _GainCorruptionCharge();
        }

        for (var i = 0; i < array_length(drums); i++) {
            drums[i].Spin();
        }
        spinTimer     = FATE_ENGINE_SPIN_DURATION_STEPS;
        resultsBanked = false;

        return self;
    }

    /// @function Cashout()
    /// @description Ends the active session and grants everything in pendingRewards. 2026-08-16 follow-up
    ///        (round 2): also requires hasSpunThisSession -- a session that's been started (token spent,
    ///        machine activated) but never actually spun has nothing to resolve yet, per "not resolving
    ///        until at least one spin has been done." See Update()'s resultsBanked block/.md.
    /// @returns {Struct.FateEngineOverlay} self
    static Cashout = function() {
        if (!isSessionActive || !hasSpunThisSession) return self;

        for (var i = 0; i < array_length(pendingRewards); i++) {
            var _reward = pendingRewards[i];
            if (_reward.rewardType == "resource") {
                global.resources[TEAM.PLAYER][$ _reward.rewardData.resourceName] += _reward.rewardData.amount;
            } else if (_reward.rewardType == "blueprint") {
                AddBlueprint(TEAM.PLAYER, _reward.rewardData.buildingType, 1);
            }
        }

        isSessionActive    = false;
        pendingRewards     = [];
        hasSpunThisSession = false;

        // 2026-08-16 request -- "when the machine is cashed out, have it INSTANTLY return to the dimmed
        // state (this simulates the lights turning on, then cutting out)." No easing -- unlike Activate()'s
        // smooth fade-up (see Update()), this is a hard snap to 0. See machineActiveFade's own field comment/.md.
        machineActive     = false;
        machineActiveFade = 0;

        return self;
    }

    /// @function _MachineIsSpinning()
    /// @description True while any drum hasn't landed yet ("stopped") -- 2026-08-14, used to gate the spin lever's grab (can't grab mid-spin). Same check Spin() itself already uses to no-op re-entrant spins.
    /// @returns {Bool}
    static _MachineIsSpinning = function() {
        for (var i = 0; i < array_length(drums); i++) {
            if (drums[i].state != "stopped") return true;
        }
        return false;
    }

    /// @function _SpinEligible()
    /// @description True if the player currently has a way to spin. 2026-08-14: extracted so the lever's grab-gating and the (now-removed) Spin button's old enabled-check use the exact same rule. **2026-08-16 follow-up (round 2): now requires isSessionActive** -- Spin() no longer spends a Fate Token to start a session itself (see Spin()/.md), so a Fate Token no longer makes this true on its own; the lever is only grabbable once a session has already been started by dragging a token onto the machine (Activate()). **2026-08-16 follow-up (corruption): also requires !corruptionLevelingUp** -- the lever stays ungrabbable for the brief post-level-up light-shutoff sequence, see .md.
    /// @returns {Bool}
    static _SpinEligible = function() {
        return isSessionActive && !corruptionLevelingUp; // 2026-08-16 follow-up (corruption) -- can't grab the lever while the post-level-up light-shutoff sequence is still playing, see .md
    }

    /// @function Activate(_x, _y)
    /// @description 2026-08-16 request -- called once a dragged Fate Token is successfully dropped near the machine (see XpBarScripts.gml's StepTokenDrag()). Sets machineActive true (drives the drums' dim<->lit crossfade, see machineActiveFade/Update()/Draw()) and spawns the purple/gold "rise up" particle burst at the drop point. **2026-08-16 follow-up (round 2): also starts the session** ("spending the token starts the session") -- sets isSessionActive true, resets pendingRewards/hasSpunThisSession for the fresh session, exactly what Spin()'s old session-start branch used to do before it was removed (see Spin()/.md). No-op if already active (idempotent, matches this file's other state-transition methods; also now unreachable in practice since _TokenActivateEligible() excludes an already-active session, but kept as a defensive guard). Deliberately does NOT touch global.resources[...].fateTokens/lastFateTokens itself -- the CALLER owns that half of the spend, since it also owns the region-token pile the dragged token visually came from; see .md for the full split of responsibility.
    /// @param {Real} _x GUI-space drop point.
    /// @param {Real} _y
    /// @returns {Struct.FateEngineOverlay} self
    static Activate = function(_x, _y) {
        if (machineActive) return self;
        machineActive      = true;
        isSessionActive    = true; // 2026-08-16 follow-up (round 2) -- spending the token starts the session, see .md
        pendingRewards     = [];   // fresh session, nothing to grant yet -- moved here from Spin()'s old session-start branch
        hasSpunThisSession = false; // session doesn't resolve (Cashout()) until at least one spin lands, see Cashout()/.md
        _SpawnActivateParticles(_x, _y);
        return self;
    }

    /// @function _TokenActivateEligible()
    /// @description True if the machine can currently accept an Activate() call -- fully popped up, not mid-close, not locked by a scripted scene, and (2026-08-16 follow-up, round 2) no session already active. Same three original conditions the buttons/lever/hover-tooltip already use elsewhere in this file (see Update()/Draw()), plus !isSessionActive so a second dragged token can't be dropped onto an already-running session -- there's nothing left to "activate" once a session has already started, and this is also what prevents a real double-spend against the session Activate() itself now owns starting. Read by XpBarScripts.gml's drag-drop check -- a drop that fails this just returns the token to the pile instead of activating. See .md.
    /// @returns {Bool}
    static _TokenActivateEligible = function() {
        return !closing && !interactionLocked && !isSessionActive && _MachineProgress() >= 1;
    }

    /// @function _DistanceToMachineCenter(_x, _y)
    /// @description Straight-line GUI-space distance from (_x, _y) to the machine's own center (the middle drum's position, exactly display_get_gui_width()/2 -- see the constructor). Used by XpBarScripts.gml's token-drag drop-zone check ("drag this token up to the center of the screen... roughly where the machine is"). See .md.
    /// @param {Real} _x
    /// @param {Real} _y
    /// @returns {Real}
    static _DistanceToMachineCenter = function(_x, _y) {
        var _center = drums[1]; // middle drum -- see the constructor
        return point_distance(_x, _y, _center.x, _center.y);
    }

    /// @function _SpawnActivateParticles(_x, _y)
    /// @description Spawns FATE_ENGINE_ACTIVATE_PARTICLE_COUNT purple/gold particles at (_x, _y), each with a random outward burst velocity plus a constant upward rise bias -- per request, "particles rise up from where the token disappeared to." Half purple, half gold on average (randomly chosen per particle). See the macro block's own comment for why this is a separate GUI-space system, not ResourceParticleScripts.gml's room-space one. See .md.
    /// @param {Real} _x
    /// @param {Real} _y
    static _SpawnActivateParticles = function(_x, _y) {
        repeat (FATE_ENGINE_ACTIVATE_PARTICLE_COUNT) {
            var _angle = random(360);
            var _speed = random_range(FATE_ENGINE_ACTIVATE_PARTICLE_SPEED_MIN, FATE_ENGINE_ACTIVATE_PARTICLE_SPEED_MAX);
            array_push(activateParticles, {
                x       : _x,
                y       : _y,
                vx      : lengthdir_x(_speed, _angle),
                vy      : lengthdir_y(_speed, _angle) - FATE_ENGINE_ACTIVATE_PARTICLE_RISE_BIAS,
                color   : (irandom(1) == 0) ? FATE_ENGINE_ACTIVATE_PARTICLE_PURPLE_COLOR : FATE_ENGINE_ACTIVATE_PARTICLE_GOLD_COLOR,
                size    : irandom_range(FATE_ENGINE_ACTIVATE_PARTICLE_SIZE_MIN, FATE_ENGINE_ACTIVATE_PARTICLE_SIZE_MAX),
                life    : FATE_ENGINE_ACTIVATE_PARTICLE_LIFE,
                lifeMax : FATE_ENGINE_ACTIVATE_PARTICLE_LIFE,
            });
        }
    }

    /// @function _GainCorruptionCharge()
    /// @description Lights the next unlit charge-light pair (fading in from 0, see _StepCorruptionChargeLights()) and advances corruptionCharge. Once the 4th light is gained, immediately kicks off the level-up sequence (_BeginCorruptionLevelUp()). No-op once corruptionLevel is already at FATE_ENGINE_CORRUPTION_MAX_LEVEL -- there's no further level to charge toward. Called from Spin() on every re-spin within a session (not the session's FIRST spin) -- 2026-08-16 follow-up, "each Spin() after the initial one" per user confirmation. See .md.
    /// @returns {Struct.FateEngineOverlay} self
    static _GainCorruptionCharge = function() {
        if (corruptionLevel >= FATE_ENGINE_CORRUPTION_MAX_LEVEL) return self;
        if (corruptionCharge >= FATE_ENGINE_CORRUPTION_CHARGE_MAX) return self; // defensive -- shouldn't be reachable, charge is always consumed by _BeginCorruptionLevelUp() the instant it hits max

        corruptionChargeLightAlpha[corruptionCharge] = 0; // (re)start this light's fade-in, see _StepCorruptionChargeLights()
        corruptionCharge += 1;

        if (corruptionCharge >= FATE_ENGINE_CORRUPTION_CHARGE_MAX) {
            _BeginCorruptionLevelUp();
        }

        return self;
    }

    /// @function _BeginCorruptionLevelUp()
    /// @description Advances corruptionLevel, resets the charge counter (the 4 lights themselves stay lit -- see corruptionChargeLightAlpha's own field comment), locks out further spins (corruptionLevelingUp), and kicks off the new level's face Start animation. The lights only actually switch off later, once the face's Loop phase finishes its 1-second hold -- see _StepCorruptionFace()/_StepCorruptionChargeLights()/.md.
    /// @returns {Struct.FateEngineOverlay} self
    static _BeginCorruptionLevelUp = function() {
        corruptionLevel      += 1;
        corruptionCharge      = 0;
        corruptionLevelingUp  = true;

        corruptionFacePhase      = "start";
        corruptionFaceFrame      = 0;
        corruptionFaceFrameTimer = _CorruptionFaceFrameSteps(global.fateEngineCorruptionFaceStart[corruptionLevel]);

        return self;
    }

    /// @function _CorruptionFaceFrameSteps(_sprite)
    /// @description Steps to hold one frame of _sprite before advancing -- same "defer to the sprite's own baked playbackSpeed, converted to steps via room_speed" convention _DealerBlinkFrameSteps() already established in this file, generalized to any sprite (the 15 corruption face Start/Loop/End sprites each have their own authored speed, see .md). Recomputed every call (not cached), cheap and stays correct if a sprite's authored speed is ever retuned.
    /// @param {Asset.GMSprite} _sprite
    /// @returns {Real} Steps (minimum 1).
    static _CorruptionFaceFrameSteps = function(_sprite) {
        var _speed = sprite_get_speed(_sprite);
        var _type  = sprite_get_speed_type(_sprite);
        if (_type == spritespeed_framespersecond && _speed > 0) {
            return max(1, round(room_speed / _speed));
        }
        return max(1, round(_speed)); // spritespeed_framespergameframe -- edge case not expected given these sprites' current authoring, see .md
    }

    /// @function _CorruptionChargeLightSprite()
    /// @description Which sprite/frame the charge lights currently draw with, per corruptionLevel -- 2026-08-16 request, "at corruption level 0-2, use sFateEngineLights indices 0-2 respectively. At corruption level 3 and 4, use sFateEngineFlameYellow and sFateEngineFlamePurple." Levels 0-2 pick a STATIC frame (sFateEngineLights has exactly 3 frames, one per level); levels 3-4 are fully animated flame sprites, sharing ONE tracked animation frame (corruptionFlameFrame) across all currently-lit lights rather than a separate one per light -- simplifying judgment call, flag if the flames should instead be phase-offset from each other for a less uniform flicker. See _StepCorruptionChargeLights()/.md.
    /// @returns {Struct} { sprite, frame }
    static _CorruptionChargeLightSprite = function() {
        switch (corruptionLevel) {
            case 0: return { sprite: sFateEngineLights, frame: 0 };
            case 1: return { sprite: sFateEngineLights, frame: 1 };
            case 2: return { sprite: sFateEngineLights, frame: 2 };
            case 3: return { sprite: sFateEngineFlameYellow, frame: corruptionFlameFrame };
            default: return { sprite: sFateEngineFlamePurple, frame: corruptionFlameFrame }; // level 4 (max)
        }
    }

    /// @function _StepCorruptionChargeLights()
    /// @description Advances every charge-light-related animation: fade-in for lights gained but not yet at full alpha (FATE_ENGINE_CORRUPTION_LIGHT_FADE_STEPS), the shared flame animation frame for levels 3-4, and the post-level-up shutoff succession (corruptionShutoffIndex counting 3->0, each light snapped instantly to alpha 0 -- no fade, per request -- FATE_ENGINE_CORRUPTION_SHUTOFF_STEP_STEPS apart). Clears corruptionLevelingUp the instant the last light (index 0, "light 1") switches off -- 2026-08-16 request, "...before allowing spins again." Called from Update(), unconditionally (independent of global.matchSpeed), same convention as the dealer blink/activation-fade steps elsewhere in this file. See .md.
    static _StepCorruptionChargeLights = function() {
        for (var i = 0; i < corruptionCharge; i++) {
            if (corruptionChargeLightAlpha[i] < 1) {
                corruptionChargeLightAlpha[i] = min(1, corruptionChargeLightAlpha[i] + 1 / FATE_ENGINE_CORRUPTION_LIGHT_FADE_STEPS);
            }
        }

        if (corruptionLevel >= 3) {
            var _sprite = (corruptionLevel == 3) ? sFateEngineFlameYellow : sFateEngineFlamePurple;
            if (corruptionFlameFrameTimer > 0) {
                corruptionFlameFrameTimer -= 1;
            } else {
                corruptionFlameFrame      = (corruptionFlameFrame + 1) mod sprite_get_number(_sprite);
                corruptionFlameFrameTimer = _CorruptionFaceFrameSteps(_sprite);
            }
        }

        if (corruptionShutoffIndex >= 0) {
            if (corruptionShutoffTimer > 0) {
                corruptionShutoffTimer -= 1;
            } else {
                corruptionChargeLightAlpha[corruptionShutoffIndex] = 0; // instant, no fade -- per request
                corruptionShutoffIndex -= 1;
                if (corruptionShutoffIndex >= 0) {
                    corruptionShutoffTimer = FATE_ENGINE_CORRUPTION_SHUTOFF_STEP_STEPS;
                } else {
                    corruptionLevelingUp = false; // 2026-08-16 request -- "...before allowing spins again"
                }
            }
        }
    }

    /// @function _StepCorruptionFace()
    /// @description Advances the corruption face's Start->Loop state machine (see corruptionFacePhase's own field comment). "start": plays global.fateEngineCorruptionFaceStart[corruptionLevel]'s frames once through, then moves to "loop". "loop": cycles global.fateEngineCorruptionFaceLoop[corruptionLevel]'s frames (wrapping) for exactly FATE_ENGINE_CORRUPTION_LOOP_HOLD_STEPS (1 second), then moves back to "idle" (which, per corruptionFacePhase's own doc, just means Draw() shows corruptionLevel's own End sprite at its last frame from that point on) AND kicks off the light-shutoff succession (corruptionShutoffIndex), per request ("when the Loop face sprite is finished playing for a full second, have each instantly shut off in succession"). "idle" has nothing to step. Called from Update(), unconditionally, same convention as _StepCorruptionChargeLights(). See .md.
    static _StepCorruptionFace = function() {
        switch (corruptionFacePhase) {
            case "start":
                var _sprite = global.fateEngineCorruptionFaceStart[corruptionLevel];
                if (corruptionFaceFrameTimer > 0) {
                    corruptionFaceFrameTimer -= 1;
                } else if (corruptionFaceFrame < sprite_get_number(_sprite) - 1) {
                    corruptionFaceFrame      += 1;
                    corruptionFaceFrameTimer  = _CorruptionFaceFrameSteps(_sprite);
                } else {
                    corruptionFacePhase      = "loop";
                    corruptionFaceFrame      = 0;
                    corruptionFaceFrameTimer = _CorruptionFaceFrameSteps(global.fateEngineCorruptionFaceLoop[corruptionLevel]);
                    corruptionFaceLoopTimer  = FATE_ENGINE_CORRUPTION_LOOP_HOLD_STEPS;
                }
                break;

            case "loop":
                var _sprite = global.fateEngineCorruptionFaceLoop[corruptionLevel];
                if (corruptionFaceFrameTimer > 0) {
                    corruptionFaceFrameTimer -= 1;
                } else {
                    corruptionFaceFrame      = (corruptionFaceFrame + 1) mod sprite_get_number(_sprite);
                    corruptionFaceFrameTimer = _CorruptionFaceFrameSteps(_sprite);
                }

                corruptionFaceLoopTimer -= 1;
                if (corruptionFaceLoopTimer <= 0) {
                    corruptionFacePhase    = "idle"; // settles on corruptionLevel's own End sprite, per the general pattern
                    corruptionShutoffIndex = FATE_ENGINE_CORRUPTION_CHARGE_MAX - 1; // "4 to 1" -- see .md
                    corruptionShutoffTimer = FATE_ENGINE_CORRUPTION_SHUTOFF_STEP_STEPS;
                }
                break;
        }
    }

    /// @function DrawCorruption()
    /// @description Draws the 4 charge-light pairs and the corruption face, both anchored to sFateEngineBody's own TOP-LEFT corner in native-sprite-space px (2026-08-16 follow-up request, "relative to the fate engine top left corner, native pixel measurements, affected by scaling"). Called from Draw() right after sFateEngineBody, inside the same matrix_world pop-up/pop-down group, so this slides with the rest of the machine during open/close. See .md.
    static DrawCorruption = function() {
        var _centerX = display_get_gui_width() / 2;
        var _originX = _centerX    - sprite_get_xoffset(sFateEngineBody) * FATE_ENGINE_MACHINE_UI_BAR_SCALE;
        var _originY = bodyBottomY - sprite_get_yoffset(sFateEngineBody) * FATE_ENGINE_MACHINE_UI_BAR_SCALE;

        var _lightInfo = _CorruptionChargeLightSprite();
        for (var i = 0; i < FATE_ENGINE_CORRUPTION_CHARGE_MAX; i++) {
            var _alpha = corruptionChargeLightAlpha[i];
            if (_alpha <= 0) continue;

            var _pair = global.fateEngineCorruptionLightOffsets[i];
            var _lx = _originX + _pair.left.x  * FATE_ENGINE_MACHINE_UI_BAR_SCALE;
            var _ly = _originY + _pair.left.y  * FATE_ENGINE_MACHINE_UI_BAR_SCALE;
            var _rx = _originX + _pair.right.x * FATE_ENGINE_MACHINE_UI_BAR_SCALE;
            var _ry = _originY + _pair.right.y * FATE_ENGINE_MACHINE_UI_BAR_SCALE;

            draw_sprite_ext(_lightInfo.sprite, _lightInfo.frame, _lx, _ly, FATE_ENGINE_MACHINE_UI_BAR_SCALE, FATE_ENGINE_MACHINE_UI_BAR_SCALE, 0, c_white, _alpha);
            draw_sprite_ext(_lightInfo.sprite, _lightInfo.frame, _rx, _ry, FATE_ENGINE_MACHINE_UI_BAR_SCALE, FATE_ENGINE_MACHINE_UI_BAR_SCALE, 0, c_white, _alpha);
        }

        var _faceX = _originX + FATE_ENGINE_CORRUPTION_FACE_OFFSET_X * FATE_ENGINE_MACHINE_UI_BAR_SCALE;
        var _faceY = _originY + FATE_ENGINE_CORRUPTION_FACE_OFFSET_Y * FATE_ENGINE_MACHINE_UI_BAR_SCALE;

        var _faceSprite, _faceFrame;
        switch (corruptionFacePhase) {
            case "start":
                _faceSprite = global.fateEngineCorruptionFaceStart[corruptionLevel];
                _faceFrame  = corruptionFaceFrame;
                break;
            case "loop":
                _faceSprite = global.fateEngineCorruptionFaceLoop[corruptionLevel];
                _faceFrame  = corruptionFaceFrame;
                break;
            default: // "idle"
                _faceSprite = global.fateEngineCorruptionFaceEnd[corruptionLevel];
                _faceFrame  = sprite_get_number(_faceSprite) - 1; // last index, per request ("stopping at its last index for idling")
                break;
        }

        // 2026-08-16 follow-up: sFateEngineFacePurpleEnd's origin is now (16,28), matching every other
        // face Start/Loop/End sprite -- the code-level compensation this draw call previously needed is
        // no longer necessary and has been removed. See .md.
        draw_sprite_ext(_faceSprite, _faceFrame, _faceX, _faceY, FATE_ENGINE_MACHINE_UI_BAR_SCALE, FATE_ENGINE_MACHINE_UI_BAR_SCALE, 0, c_white, 1);
    }

    /// @function _LeverHandleBasePosition()
    /// @description The lever assembly's shared base anchor -- all 3 sFateEngineHandle frames draw from this same (x,y), see DrawLever(). Offset from sFateEngineBody's own draw anchor by FATE_ENGINE_HANDLE_ALIGN_X/Y (native-sprite-space, scaled here by FATE_ENGINE_MACHINE_UI_BAR_SCALE -- see the macro block's comment for the alternate-reading caveat). 2026-08-14.
    /// @returns {Struct} { x, y }
    static _LeverHandleBasePosition = function() {
        var _centerX = display_get_gui_width() / 2;
        var _scale   = FATE_ENGINE_MACHINE_UI_BAR_SCALE;
        return {
            x: _centerX   + FATE_ENGINE_HANDLE_ALIGN_X * _scale,
            y: bodyBottomY + FATE_ENGINE_HANDLE_ALIGN_Y * _scale
        };
    }

    /// @function _DealerBasePosition()
    /// @description The Dealer's (sDealer) draw origin on screen -- 2026-08-14, solved so her own "lean corner" (FATE_ENGINE_DEALER_LEAN_CORNER_X/Y, an offset from HER origin, unscaled since she's drawn native 1x) exactly coincides with the machine's matching corner (FATE_ENGINE_BODY_LEAN_CORNER_X/Y, an offset from sFateEngineBody's origin, scaled by FATE_ENGINE_MACHINE_UI_BAR_SCALE like the lever's alignment offsets). Algebraically: dealerOrigin + dealerCorner = machineCorner, so dealerOrigin = machineCorner - dealerCorner. See DrawDealer() and .md.
    /// @returns {Struct} { x, y }
    static _DealerBasePosition = function() {
        var _centerX = display_get_gui_width() / 2;
        var _scale   = FATE_ENGINE_MACHINE_UI_BAR_SCALE;

        var _machineCornerX = _centerX    + FATE_ENGINE_BODY_LEAN_CORNER_X * _scale;
        var _machineCornerY = bodyBottomY + FATE_ENGINE_BODY_LEAN_CORNER_Y * _scale;

        return {
            x: _machineCornerX - FATE_ENGINE_DEALER_LEAN_CORNER_X,
            y: _machineCornerY - FATE_ENGINE_DEALER_LEAN_CORNER_Y
        };
    }

    /// @function _DealerNextBlinkIntervalSteps()
    /// @description Rolls a fresh idle duration before the Dealer's NEXT blink -- 2026-08-14 follow-up, "somewhat random but rhythmic... every few seconds with some slight variation". Uniform between FATE_ENGINE_DEALER_BLINK_INTERVAL_MIN_STEPS and _MAX_STEPS (3-5s) -- untuned judgment call on the exact range, see .md.
    /// @returns {Real} Steps.
    static _DealerNextBlinkIntervalSteps = function() {
        return irandom_range(FATE_ENGINE_DEALER_BLINK_INTERVAL_MIN_STEPS, FATE_ENGINE_DEALER_BLINK_INTERVAL_MAX_STEPS);
    }

    /// @function _DealerBlinkFrameSteps()
    /// @description Steps to hold each individual blink frame (indices 1-7) before advancing to the next -- 2026-08-14 follow-up, "this animation lives in her existing sprite" so this defers to sDealer's OWN baked playbackSpeed (10 FPS as authored) converted to steps via room_speed, rather than picking a new arbitrary duration. Recomputed every call (not cached) since it's cheap and stays correct if the sprite's authored speed is ever retuned. See .md.
    /// @returns {Real} Steps (minimum 1).
    static _DealerBlinkFrameSteps = function() {
        var _speed = sprite_get_speed(sDealer);
        var _type  = sprite_get_speed_type(sDealer);
        if (_type == spritespeed_framespersecond && _speed > 0) {
            return max(1, round(room_speed / _speed));
        }
        return max(1, round(_speed)); // spritespeed_framespergameframe -- speed is already steps-per-frame, edge case not expected given sDealer's current authoring, see .md
    }

    /// @function _LeverYScale()
    /// @description Current yscale MULTIPLIER for the lever bar (frame 1) -- lerps FATE_ENGINE_LEVER_IDLE_YSCALE (1, idle) to FATE_ENGINE_LEVER_PULLED_YSCALE (-0.25, full pull) over leverProgress. This is a multiplier on top of FATE_ENGINE_MACHINE_UI_BAR_SCALE, not a replacement of it -- see DrawLever(). 2026-08-14.
    /// @returns {Real}
    static _LeverYScale = function() {
        return lerp(FATE_ENGINE_LEVER_IDLE_YSCALE, FATE_ENGINE_LEVER_PULLED_YSCALE, leverProgress);
    }

    /// @function _LeverHandleBallOffsetY()
    /// @description Native-sprite-space px the handle/ball (frame 2) should drop below its native draw position. 2026-08-15 follow-up: now a straight linear map directly off leverProgress (0 at idle/leverProgress 0, FATE_ENGINE_HANDLE_BALL_MAX_DROP_PX (85) at full pull/leverProgress 1) -- per request ("from the 0 position to 110px mouse movement, the 2nd index of the lever needs to move from 0 to 85px"), replacing the original piecewise reading (tied to the lever bar's OWN yscale crossing zero, which only ever let the ball move over the last ~20% of the pull -- the "shifts only a little bit when pulling down" bug this fixes). See .md.
    /// @returns {Real} Native-sprite-space px, NOT yet scaled by FATE_ENGINE_MACHINE_UI_BAR_SCALE -- see DrawLever().
    static _LeverHandleBallOffsetY = function() {
        return lerp(0, FATE_ENGINE_HANDLE_BALL_MAX_DROP_PX, leverProgress);
    }

    /// @function _LeverHandleGrabRect()
    /// @description GUI-space rect of the TOP HALF of the handle sprite's (frame 2, at its idle/rest position) bounding box -- the clickable "grab" region per request ("grab...at the top portion of the handles bounding box"). Computed from sFateEngineHandle's own configured bbox/origin rather than hardcoded, so it stays correct if the sprite is ever resized. "Top half" is a judgment call -- request said "top portion" without an exact fraction, see .md. 2026-08-14.
    /// @returns {Struct} { x1, y1, x2, y2 }
    static _LeverHandleGrabRect = function() {
        var _base  = _LeverHandleBasePosition();
        var _scale = FATE_ENGINE_MACHINE_UI_BAR_SCALE;
        var _xoff  = sprite_get_xoffset(sFateEngineHandle);
        var _yoff  = sprite_get_yoffset(sFateEngineHandle);

        var _left   = _base.x + (sprite_get_bbox_left(sFateEngineHandle)   - _xoff) * _scale;
        var _right  = _base.x + (sprite_get_bbox_right(sFateEngineHandle)  - _xoff) * _scale;
        var _top    = _base.y + (sprite_get_bbox_top(sFateEngineHandle)    - _yoff) * _scale;
        var _bottom = _base.y + (sprite_get_bbox_bottom(sFateEngineHandle) - _yoff) * _scale;

        return { x1: _left, y1: _top, x2: _right, y2: (_top + _bottom) / 2 };
    }

    /// @function _IntroTotalSteps()
    /// @description Full duration of the OPEN-intro sequence, in steps -- caps introElapsedSteps' growth in Update(). 2026-08-14 follow-up: while machineHoldUsed, the machine's own pop-up no longer derives from introElapsedSteps at all (see _MachineProgress()), so this is just the gradient/trees' own duration (max of the two, though gradient's is always longer per FATE_ENGINE_INTRO_TREES_STEPS being half of it). Otherwise (normal/automatic path, unchanged): whichever of the gradient's own duration or the machine pop-up's automatic-trigger finish comes LATER. See .md.
    /// @returns {Real}
    static _IntroTotalSteps = function() {
        if (machineHoldUsed) return max(FATE_ENGINE_INTRO_GRADIENT_STEPS, FATE_ENGINE_INTRO_TREES_STEPS);
        var _popupFinishStep = (FATE_ENGINE_INTRO_TREES_STEPS * FATE_ENGINE_INTRO_POPUP_TRIGGER_FRACTION) + FATE_ENGINE_INTRO_POPUP_STEPS;
        return max(FATE_ENGINE_INTRO_GRADIENT_STEPS, _popupFinishStep);
    }

    /// @function _CloseTotalSteps()
    /// @description Full duration of the CLOSE/leave sequence, in steps -- 2026-08-14 follow-up. Unlike _IntroTotalSteps(), all three stages start together here (no 90%-trigger stagger, per request "have the movement and fade out start immediately, alongside the machine popping down"), so this is simply the longest of the three individual stage durations. Caps closeElapsedSteps' growth in Update().
    /// @returns {Real}
    static _CloseTotalSteps = function() {
        return max(FATE_ENGINE_INTRO_GRADIENT_STEPS, FATE_ENGINE_INTRO_TREES_STEPS, FATE_ENGINE_INTRO_POPUP_STEPS);
    }

    /// @function _GradientProgress()
    /// @description 0..1 fade progress of the play-area gradient tint -- 0->1 while opening, 1->0 while closing (2026-08-14 follow-up: reverse of the open motion, played back over the SAME duration, off closeElapsedSteps instead of introElapsedSteps). Renamed from _IntroGradientProgress() since it now serves both directions.
    /// @returns {Real}
    static _GradientProgress = function() {
        if (closing) return 1 - clamp(closeElapsedSteps / FATE_ENGINE_INTRO_GRADIENT_STEPS, 0, 1);
        return clamp(introElapsedSteps / FATE_ENGINE_INTRO_GRADIENT_STEPS, 0, 1);
    }

    /// @function _TreesProgress()
    /// @description 0..1 fade/parallax progress of the tree layers -- reaches 1 at HALF the gradient's own duration while opening ("twice as fast" per request, see FATE_ENGINE_INTRO_TREES_STEPS); 1->0 over that same (now also halved) duration while closing. Renamed from _IntroTreesProgress() since it now serves both directions.
    /// @returns {Real}
    static _TreesProgress = function() {
        if (closing) return 1 - clamp(closeElapsedSteps / FATE_ENGINE_INTRO_TREES_STEPS, 0, 1);
        return clamp(introElapsedSteps / FATE_ENGINE_INTRO_TREES_STEPS, 0, 1);
    }

    /// @function _MachineProgress()
    /// @description 0..1 pop-up/pop-down progress of the machine body/drums. WHILE OPENING: starts once the trees reach FATE_ENGINE_INTRO_POPUP_TRIGGER_FRACTION (90%) of their OWN animation, not at t=0 -- per request ("after they are at 90% to final position, have the fate engine pop up"). 2026-08-14 follow-up ("Dealer intro" scene): if machineHeld, pinned at 0 regardless of introElapsedSteps -- deliberately withheld until ReleaseMachine(). Once machineHoldUsed (a held Open() happened THIS session, even after release), the automatic 90%-trigger formula is abandoned entirely in favor of machineReleaseElapsedSteps -- that formula assumes the machine starts on its own schedule relative to the trees, which no longer holds once something else is deciding when to release it. WHILE CLOSING (2026-08-14 follow-up): starts immediately at closeElapsedSteps=0, same as the gradient/trees -- per request ("have the movement and fade out start immediately, alongside the machine popping down"), no trigger delay on the way out. Renamed from _IntroMachineProgress() since it now serves both directions.
    /// @returns {Real}
    static _MachineProgress = function() {
        if (closing) return 1 - clamp(closeElapsedSteps / FATE_ENGINE_INTRO_POPUP_STEPS, 0, 1);
        if (machineHeld) return 0;
        if (machineHoldUsed) return clamp(machineReleaseElapsedSteps / FATE_ENGINE_INTRO_POPUP_STEPS, 0, 1);
        var _triggerStep = FATE_ENGINE_INTRO_TREES_STEPS * FATE_ENGINE_INTRO_POPUP_TRIGGER_FRACTION;
        return clamp((introElapsedSteps - _triggerStep) / FATE_ENGINE_INTRO_POPUP_STEPS, 0, 1);
    }

    /// @function Update()
    /// @description Call once per Step. No-ops if not open. See .md for the open-vs-close intro sequencing (2026-08-14 follow-up).
    /// @returns {Struct.FateEngineOverlay} self
    static Update = function() {
        if (!isOpen) return self;

        if (closing) {
            if (closeElapsedSteps < _CloseTotalSteps()) closeElapsedSteps += 1;
        } else {
            if (introElapsedSteps < _IntroTotalSteps()) introElapsedSteps += 1;
            // 2026-08-14 follow-up -- independent of introElapsedSteps (which
            // may already be capped/finished): once released from a held
            // Open(), the machine pops up on its OWN clock starting from
            // the moment ReleaseMachine() was called. No-ops (stays 0,
            // _MachineProgress() stays pinned) while still machineHeld. See
            // _MachineProgress()/.md.
            if (machineHoldUsed && !machineHeld && machineReleaseElapsedSteps < FATE_ENGINE_INTRO_POPUP_STEPS) {
                machineReleaseElapsedSteps += 1;
            }
        }

        for (var i = 0; i < array_length(drums); i++) {
            drums[i].Step();
        }

        if (spinTimer > 0) {
            spinTimer -= 1;
            if (spinTimer <= 0) {
                for (var i = 0; i < array_length(drums); i++) {
                    drums[i].Stop();
                }
            }
        }

        if (!resultsBanked) {
            var _allStopped = true;
            for (var i = 0; i < array_length(drums); i++) {
                if (drums[i].state != "stopped") { _allStopped = false; break; }
            }
            if (_allStopped) {
                // 2026-08-16 bugfix ("spun multiple times, rewarded like 12 buildings"): this must
                // REPLACE pendingRewards with the CURRENT 3 tumbler items, not append to whatever was
                // banked by a previous spin this same session. Re-spinning (free, once a session is
                // active -- see Spin()) is meant to change your mind about what you'll cash out, not
                // stack additional rewards on top -- Cashout() only ever grants the LATEST landed result
                // per drum. `pendingRewards = []` was previously only ever cleared in Spin()'s "starting
                // a brand-new session" branch (2026-08-16 follow-up, round 2: that branch was removed --
                // it's now Activate()'s own new-session reset, see Activate()/.md), so every re-spin
                // within an already-active session kept adding 3 more entries on top of the last landed
                // set instead of superseding them. See .md.
                pendingRewards = [];
                for (var i = 0; i < array_length(drums); i++) {
                    array_push(pendingRewards, drums[i].GetLockedItem());
                }
                resultsBanked = true;
                hasSpunThisSession = true; // 2026-08-16 follow-up (round 2) -- the session can now be Cashout()'d, see Cashout()/.md
            }
        }

        // Machine activation fade + particle burst (2026-08-16 request) -- ticks regardless of
        // closing/pop-animation state, same reasoning as the drums/dealer-blink steps around it.
        // machineActiveFade only ever eases UP here (toward 1, while machineActive); the DOWN case
        // is an instant snap to 0 done directly in Cashout()/Open(), not here -- see their own
        // comments and machineActiveFade's field comment. Independent of global.matchSpeed like
        // every other animation in this file (matchSpeed is 0 the whole time the overlay is open).
        if (machineActive && machineActiveFade < 1) {
            machineActiveFade = min(1, machineActiveFade + 1 / FATE_ENGINE_ACTIVATE_FADE_STEPS);
        }

        for (var i = array_length(activateParticles) - 1; i >= 0; i--) {
            var _p = activateParticles[i];
            _p.x    += _p.vx;
            _p.y    += _p.vy;
            _p.life -= 1;
            if (_p.life <= 0) {
                array_delete(activateParticles, i, 1);
            }
        }

        // Corruption charge lights + face (2026-08-16 follow-up request) -- ticks regardless of
        // closing/pop-animation state, same convention as the blocks above. See
        // _StepCorruptionChargeLights()/_StepCorruptionFace()/.md.
        _StepCorruptionChargeLights();
        _StepCorruptionFace();

        // Dealer blink animation (2026-08-14 follow-up request) -- ticks
        // regardless of closing/pop-animation state, same as the drums
        // above (harmless if she's off-screen mid-slide, and keeps her
        // rhythm running continuously rather than pausing/resuming oddly
        // around the open/close animation). "idle": counts dealerBlinkTimer
        // down to 0, then starts the blink at frame 1. "blinking": holds
        // each frame for _DealerBlinkFrameSteps() (sDealer's own baked
        // playback speed) before advancing; past frame 7 it loops back to
        // the idle face (frame 0) and rolls a fresh randomized wait via
        // _DealerNextBlinkIntervalSteps(). See .md.
        if (dealerBlinkState == "idle") {
            if (dealerBlinkTimer > 0) {
                dealerBlinkTimer -= 1;
            } else {
                dealerBlinkState = "blinking";
                dealerBlinkFrame = 1;
                dealerBlinkTimer = _DealerBlinkFrameSteps();
            }
        } else { // "blinking"
            if (dealerBlinkTimer > 0) {
                dealerBlinkTimer -= 1;
            } else if (dealerBlinkFrame >= 7) {
                dealerBlinkState = "idle";
                dealerBlinkFrame = 0;
                dealerBlinkTimer = _DealerNextBlinkIntervalSteps();
            } else {
                dealerBlinkFrame += 1;
                dealerBlinkTimer  = _DealerBlinkFrameSteps();
            }
        }

        // 2026-08-14: buttons are only clickable once the machine has FULLY
        // popped up AND the overlay isn't already closing -- avoids any
        // window where the drawn button position (which doesn't slide
        // anywhere, see Draw()/DrawButtons() below) could otherwise be
        // clicked before the rest of the overlay has finished its own
        // intro animation, and stops a stray click from re-triggering
        // Leave()/Cashout() while the close animation is already playing.
        // Spin is no longer a button here -- see the lever state machine
        // below, which grants that same "!closing && fully popped up" gate.
        // 2026-08-14 follow-up: also requires !interactionLocked -- a
        // "Dealer intro" scripted scene can have the machine fully popped
        // up while still mid-dialogue, and shouldn't let a stray click
        // trigger Leave()/Cashout() during that window. See .md.
        if (!closing && !interactionLocked && _MachineProgress() >= 1 && mouse_check_button_pressed(mb_left)) {
            var _gx    = device_mouse_x_to_gui(0);
            var _gy    = device_mouse_y_to_gui(0);
            var _rects = FateEngineButtonRects();

            var _onLeave   = (_gx >= _rects.leave.x1   && _gx <= _rects.leave.x2   && _gy >= _rects.leave.y1   && _gy <= _rects.leave.y2);
            var _onCashout = (_gx >= _rects.cashout.x1 && _gx <= _rects.cashout.x2 && _gy >= _rects.cashout.y1 && _gy <= _rects.cashout.y2);

            if (_onLeave && !isSessionActive) {
                Leave();
            } else if (_onCashout && isSessionActive && hasSpunThisSession) { // 2026-08-16 follow-up (round 2) -- matches DrawButtons()'s own _cashoutEnabled, see .md
                Cashout();
            }
        }

        // Spin lever state machine (2026-08-14 request) -- replaces the old
        // Spin button. "idle": watches for a click-and-hold in the top half
        // of the handle's bbox (only once the machine is fully popped up,
        // not closing, not already spinning, and the player is actually
        // allowed to spin -- per request "grabbing the lever is only
        // possible when the machine is not spinning, or when the player is
        // allowed to spin", read as BOTH conditions must hold, see .md).
        // "dragging": leverProgress tracks the mouse 1:1 (no easing -- it's
        // player-driven, not animated) until either 110px of downward travel
        // is reached (full pull -> Spin() fires, moves to "holding") or the
        // mouse is released early (moves to "returning" from wherever it
        // was, see .md). "holding": fixed at full pull for
        // FATE_ENGINE_LEVER_HOLD_STEPS (~0.5s) regardless of mouse state,
        // per request. "returning": eases (ease-OUT, decelerating into rest)
        // back down to leverProgress 0, then back to "idle". See
        // _LeverYScale()/_LeverHandleBallOffsetY()/DrawLever() for how
        // leverProgress actually drives the visuals.
        // 2026-08-14 follow-up: also requires !interactionLocked, same
        // "Dealer intro" reasoning as the button-click gate above -- the
        // lever is drawn (and can visually be seen) well before the player
        // is actually allowed to grab it in that scene. See .md.
        var _leverGrabbable = (!closing && !interactionLocked && _MachineProgress() >= 1 && !_MachineIsSpinning() && _SpinEligible());
        switch (leverState) {
            case "idle":
                if (_leverGrabbable && mouse_check_button_pressed(mb_left)) {
                    var _grabRect = _LeverHandleGrabRect();
                    var _gx = device_mouse_x_to_gui(0);
                    var _gy = device_mouse_y_to_gui(0);
                    if (_gx >= _grabRect.x1 && _gx <= _grabRect.x2 && _gy >= _grabRect.y1 && _gy <= _grabRect.y2) {
                        leverState       = "dragging";
                        leverGrabAnchorY = _gy;
                    }
                }
                break;

            case "dragging":
                if (mouse_check_button(mb_left)) {
                    var _dy = device_mouse_y_to_gui(0) - leverGrabAnchorY;
                    leverProgress = clamp(_dy, 0, FATE_ENGINE_LEVER_PULL_DISTANCE_PX) / FATE_ENGINE_LEVER_PULL_DISTANCE_PX;
                    if (leverProgress >= 1) {
                        leverProgress  = 1;
                        leverState     = "holding";
                        leverHoldTimer = FATE_ENGINE_LEVER_HOLD_STEPS;
                        Spin();
                    }
                } else {
                    // Released before reaching full travel -- not covered
                    // explicitly by the request (which only describes the
                    // full-pull case), so ease back from wherever it was
                    // rather than snapping or continuing to "holding"/Spin().
                    // Judgment call, see .md.
                    leverReturnStartProgress = leverProgress;
                    leverState               = "returning";
                    leverReturnElapsedSteps  = 0;
                }
                break;

            case "holding":
                leverHoldTimer -= 1;
                if (leverHoldTimer <= 0) {
                    leverReturnStartProgress = 1;
                    leverState               = "returning";
                    leverReturnElapsedSteps  = 0;
                }
                break;

            case "returning":
                leverReturnElapsedSteps += 1;
                var _t = clamp(leverReturnElapsedSteps / FATE_ENGINE_LEVER_RETURN_STEPS, 0, 1);
                leverProgress = lerp(leverReturnStartProgress, 0, _FateEngineEaseOutCubic(_t));
                if (_t >= 1) {
                    leverProgress = 0;
                    leverState    = "idle";
                }
                break;
        }

        // 2026-08-14 follow-up: the actual close finalization -- once the
        // close animation has fully played out, restore the match/hover
        // state Leave() used to clear instantly, and only THEN flip isOpen
        // false. Checked last so everything above (drum Step(), etc.) still
        // gets one final Update() on the exact frame closing completes.
        if (closing && closeElapsedSteps >= _CloseTotalSteps()) {
            isOpen  = false;
            closing = false;
            global.matchSpeed = savedMatchSpeed;
            global.fateEngineOverlayActive = false;
        }

        return self;
    }

    /// @function DrawGradientTint()
    /// @description Draws the play-area gradient tint (2026-08-14 request) -- strongest top-left, weakest bottom-right, fading in/out via _GradientProgress() (0->1 opening, 1->0 closing -- 2026-08-14 follow-up). Scoped to (0,0)-(guiWidth, bodyBottomY), "everything above the UI bar edge" -- the persistent UI bar sprite (drawn right after this overlay in oUnitControl/Draw_64.gml) already opaquely covers everything below that, same reasoning the OLD flat full-GUI dim rectangle relied on (the portion of IT below bodyBottomY was always invisible too, hidden under the bar -- see .md). Replaces that old flat 0.75-alpha rectangle entirely.
    static DrawGradientTint = function() {
        var _alpha = _GradientProgress();
        if (_alpha <= 0) return;

        shader_set(shFateEngineGradientTint);
        shader_set_uniform_f(_FateEngineGradientAlphaUniform(), _alpha);

        draw_set_color(FATE_ENGINE_GRADIENT_TINT_COLOR);
        draw_set_alpha(FATE_ENGINE_GRADIENT_TINT_MAX_ALPHA);
        draw_rectangle(0, 0, display_get_gui_width(), bodyBottomY, false);
        draw_set_alpha(1);

        shader_reset();
    }

    /// @function DrawTrees()
    /// @description Draws both sFateEngineTrees layers (2026-08-14 request) -- index 0 (far) then index 1 (near, drawn on top), each fading in/out and parallaxing via _TreesProgress() (reaches 1 at HALF the gradient's own duration while opening -- "twice as fast", see FATE_ENGINE_INTRO_TREES_STEPS -- and 1->0 over that same duration while closing, 2026-08-14 follow-up, unstaggered with the gradient/machine -- see .md). The near layer travels a LARGER distance than the far layer over the same shared progress, the standard depth cue for parallax (closer things sweep across more for the same motion) -- see FATE_ENGINE_TREES_*_PARALLAX_DISTANCE. Drawn at NATIVE (1,1) scale -- per request ("do not scale up the trees, they match the UI scale already"), unlike every other Fate Engine sprite here, which is drawn at FATE_ENGINE_MACHINE_UI_BAR_SCALE. **The PARALLAX (position) lerp uses _FateEngineEaseInCubic() (2026-08-14 follow-up, "ease in slower") -- the fade (alpha) deliberately stays on the raw linear ratio, since the request was specifically about the parallax motion, not the fade. Because _TreesProgress() itself is already the reversed ratio while closing, feeding it through the SAME ease function produces a true reverse-playback of the open animation, not a differently-shaped one.**
    static DrawTrees = function() {
        var _t = _TreesProgress();
        if (_t <= 0) return;

        var _alpha  = lerp(0, 1, _t); // linear fade -- unaffected by the parallax easing below, see .md
        var _eased  = _FateEngineEaseInCubic(_t);
        var _finalX = (display_get_gui_width() - sprite_get_width(sFateEngineTrees)) / 2; // centered in the play space -- sprite is wider than the GUI, so this deliberately overflows both edges symmetrically, see .md
        var _y      = bodyBottomY - sprite_get_height(sFateEngineTrees); // bottom-anchored to the play area's own bottom edge -- top-left origin sprite, see .md

        var _farX  = lerp(_finalX - FATE_ENGINE_TREES_FAR_PARALLAX_DISTANCE,  _finalX, _eased);
        var _nearX = lerp(_finalX - FATE_ENGINE_TREES_NEAR_PARALLAX_DISTANCE, _finalX, _eased);

        draw_sprite_ext(sFateEngineTrees, 0, _farX,  _y, 1, 1, 0, c_white, _alpha); // index 0 -- further back layer, drawn first (underneath)
        draw_sprite_ext(sFateEngineTrees, 1, _nearX, _y, 1, 1, 0, c_white, _alpha); // index 1 -- closer layer, drawn on top
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event, before the UI bar. No-ops if not open. See .md for the full 2026-08-14 open-intro and close/leave sequencing (gradient tint <-> trees fade/parallax <-> machine pop-up/pop-down).
    static Draw = function() {
        if (!isOpen) return;

        DrawGradientTint();
        DrawTrees();

        // Machine body/drums/drum-slot-backgrounds/hover-tooltip all slide up
        // (opening) or down (closing, 2026-08-14 follow-up) together as ONE
        // rigid group -- via a world-matrix translate rather than touching
        // FateDrum's own x/y (which Update()'s spin/landing math and
        // GetLockedItem() still read directly and unaffected -- this offset
        // is purely visual). Buttons are deliberately NOT part of this slide
        // -- see DrawButtons() below and .md. Eased via _FateEngineEaseInCubic()
        // (2026-08-14 follow-up, "have the fate engine popping up also be
        // lerped/eased in") -- same curve as the trees' own parallax; while
        // closing, _MachineProgress() is already the reversed ratio, so this
        // plays back as a true reverse of the pop-up, not a new shape.
        var _popupOffsetY  = lerp(display_get_gui_height(), 0, _FateEngineEaseInCubic(_MachineProgress()));
        var _restoreMatrix = matrix_get(matrix_world);
        matrix_set(matrix_world, matrix_build(0, _popupOffsetY, 0, 0, 0, 0, 1, 1, 1));

        // 2026-08-16 request ("when the machine is not active, have the drums be dimmed out...
        // when the machine activates, have the dimming fade away") -- slot-rectangle fill blends
        // between FATE_ENGINE_DRUM_DIMMED_COLOR and this rectangle's own original lit color across
        // machineActiveFade. See machineActiveFade's field comment/.md.
        draw_set_color(merge_color(FATE_ENGINE_DRUM_DIMMED_COLOR, make_color_rgb(0xE1, 0xD3, 0xEA), machineActiveFade));
        for (var i = 0; i < array_length(drums); i++) {
            var _drum = drums[i];
            draw_rectangle(_drum.x - 50, _drum.y - 69, _drum.x + 50, _drum.y + 69, false);
        }

        // 2026-08-16 request ("...with no symbols on them... the symbols fade in") -- FateDrum.Draw()
        // takes no alpha parameter of its own, so this wraps the whole loop in draw_set_alpha() instead
        // (multiplies with whatever alpha FateDrum.Draw() itself draws at) rather than touching
        // FateEngineDrumScripts.gml. See .md.
        draw_set_alpha(machineActiveFade);
        for (var i = 0; i < array_length(drums); i++) {
            drums[i].Draw();
        }
        draw_set_alpha(1);

        var _centerX = display_get_gui_width() / 2;
        draw_sprite_ext(sFateEngineBody, 0, _centerX, bodyBottomY, FATE_ENGINE_MACHINE_UI_BAR_SCALE, FATE_ENGINE_MACHINE_UI_BAR_SCALE, 0, c_white, 1);

        DrawCorruption(); // 2026-08-16 follow-up -- charge lights + face, drawn on the body before the lever/Dealer (judgment call on z-order, not specified either way, see .md)

        DrawLever(); // 2026-08-14 -- drawn inside this same matrix group so it slides with the machine during open/close, see .md
        DrawDealer(); // 2026-08-14 -- same reasoning: she's leaning ON the machine, so drawn inside this same matrix group to stay attached during open/close -- not explicitly requested like the lever's "attached...for purposes of animation" was, but assumed for consistency, see .md

        // Activation particle burst (2026-08-16 request, see _SpawnActivateParticles()/.md) -- drawn
        // last within this matrix group so the rising particles appear on top of the machine body.
        // Each fades out linearly over its own life/lifeMax, matching the particles' own "rise up and
        // fade" reading of "particles rise up from where the token disappeared to."
        for (var i = 0; i < array_length(activateParticles); i++) {
            var _p = activateParticles[i];
            draw_set_color(_p.color);
            draw_set_alpha(_p.life / _p.lifeMax);
            draw_rectangle(_p.x - _p.size, _p.y - _p.size, _p.x + _p.size, _p.y + _p.size, false);
        }
        draw_set_alpha(1);

        // Hover tooltip gated the same as button clicks below (only once
        // fully popped up, and not while closing -- 2026-08-14 follow-up) --
        // at that point _popupOffsetY is exactly 0, so this stays consistent
        // with the mouse-position comparison against the drums' own
        // unshifted x/y. 2026-08-14 follow-up: also requires
        // !interactionLocked, same "Dealer intro" reasoning as Update()'s
        // button-click/lever-grab gates -- see .md.
        if (!closing && !interactionLocked && _MachineProgress() >= 1) {
            var _mx = device_mouse_x_to_gui(0);
            var _my = device_mouse_y_to_gui(0);
            for (var i = 0; i < array_length(drums); i++) {
                var _drum  = drums[i];
                var _halfW = 44;
                var _halfH = _drum.radius + 48;
                if (abs(_mx - _drum.x) > _halfW || abs(_my - _drum.y) > _halfH) continue;
                var _item = _drum.GetLockedItem();
                if (_item == undefined) continue;
                draw_set_halign(fa_left);
                draw_set_valign(fa_top);
                draw_set_color(c_white);
                draw_text(_mx + 12, _my + 12, _item.label);
            }
        }

        matrix_set(matrix_world, _restoreMatrix);

        // Buttons deliberately drawn OUTSIDE the popup matrix -- they're
        // top-anchored UI chrome (FATE_ENGINE_BUTTON_TOP_Y = 30), not
        // physically part of the bottom-anchored machine graphic, so sliding
        // them up/down alongside it would look disconnected from where they
        // actually live on screen. They're placeholder rectangles anyway
        // (see .md's Assumptions #3, "we will add in the pull handle and
        // proper buttons for everything" next) -- simply switched on once
        // the machine finishes popping up, and switched back OFF the instant
        // closing starts (2026-08-14 follow-up, "movement and fade out
        // start immediately") -- matching Update()'s own click-handling
        // gate exactly so there's no drawn-vs-clickable mismatch window.
        // 2026-08-14 follow-up: also requires !interactionLocked -- a
        // "Dealer intro" scripted scene can leave the machine fully popped
        // up well before the buttons should actually appear/respond. See .md.
        if (!closing && !interactionLocked && _MachineProgress() >= 1) {
            DrawButtons();
        }
    }

    /// @function DrawLever()
    /// @description Draws the 3-frame sFateEngineHandle assembly (2026-08-14 request) -- frame 0 (static base plate), frame 1 (the lever bar, yscale-animated via _LeverYScale()), frame 2 (the handle/ball, y-translated via _LeverHandleBallOffsetY()), all sharing the same base anchor (_LeverHandleBasePosition()). Drawn unconditionally whenever this is reached (i.e. for the whole open/close pop animation, same as the drums/body it's attached to) -- unlike the buttons, which are gated to only appear once fully popped up. See .md.
    static DrawLever = function() {
        var _base  = _LeverHandleBasePosition();
        var _scale = FATE_ENGINE_MACHINE_UI_BAR_SCALE;

        draw_sprite_ext(sFateEngineHandle, 0, _base.x, _base.y, _scale, _scale, 0, c_white, 1); // static base plate -- does nothing, per request

        var _leverYScale = _LeverYScale();
        draw_sprite_ext(sFateEngineHandle, 1, _base.x, _base.y, _scale, _scale * _leverYScale, 0, c_white, 1); // the lever -- idle yscale multiplier 1, full pull -0.25 (negative flips it past its pivot)

        var _ballOffsetY = _LeverHandleBallOffsetY() * _scale; // native-sprite-space offset scaled to on-screen px, see _LeverHandleBallOffsetY()'s own doc comment
        draw_sprite_ext(sFateEngineHandle, 2, _base.x, _base.y + _ballOffsetY, _scale, _scale, 0, c_white, 1); // the handle/ball -- aligned {0,0} to the lever, only moves vertically in tandem with its yscale
    }

    /// @function DrawDealer()
    /// @description Draws sDealer (2026-08-14 request) at NATIVE (1,1) scale -- per request, "will not be scaled up" -- at _DealerBasePosition(), the origin position solved so her own lean corner exactly meets the machine's, see that function's doc comment and .md. Frame is dealerBlinkFrame (2026-08-14 follow-up), not a hardcoded 0 -- 0 is her idle face, 1-7 step through her blink, see the blink state machine in Update().
    static DrawDealer = function() {
        var _pos = _DealerBasePosition();
        draw_sprite_ext(sDealer, dealerBlinkFrame, _pos.x, _pos.y, 1, 1, 0, c_white, 1);
    }

    /// @function DrawButtons()
    /// @description Draws the leave/cashout buttons, greyed out when disabled. 2026-08-14: Spin is no longer a button -- see DrawLever()/the lever state machine in Update().
    static DrawButtons = function() {
        var _rects = FateEngineButtonRects();

        var _leaveEnabled   = !isSessionActive;
        var _cashoutEnabled = isSessionActive && hasSpunThisSession; // 2026-08-16 follow-up (round 2) -- greyed out until at least one spin has landed this session, see Cashout()/.md

        DrawOneButton(_rects.leave,   "Leave",   _leaveEnabled);
        DrawOneButton(_rects.cashout, "Cashout", _cashoutEnabled);
    }

    /// @function DrawOneButton(_rect, _label, _enabled)
    /// @description Draws one plain rectangle+text button.
    /// @param {Struct} _rect { x1, y1, x2, y2 }
    /// @param {String} _label
    /// @param {Bool} _enabled
    static DrawOneButton = function(_rect, _label, _enabled) {
        draw_set_alpha(1);
        draw_set_color(_enabled ? make_color_rgb(0x3A, 0x2E, 0x4A) : make_color_rgb(0x55, 0x55, 0x55));
        draw_rectangle(_rect.x1, _rect.y1, _rect.x2, _rect.y2, false);
        draw_set_color(c_white);
        draw_rectangle(_rect.x1, _rect.y1, _rect.x2, _rect.y2, true);

        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(_enabled ? c_white : make_color_rgb(0xAA, 0xAA, 0xAA));
        draw_text((_rect.x1 + _rect.x2) / 2, (_rect.y1 + _rect.y2) / 2, _label);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    }
}
