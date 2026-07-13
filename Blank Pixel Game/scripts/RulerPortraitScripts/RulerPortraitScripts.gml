// -----------------------------------------------------------
// RulerPortraitScripts -- animated ruler portraits for the UI.
//
// One sprite per ruler holds every animation as consecutive frame ranges
// (e.g. sConeliusPortrait: 30 frames covering 6 clips back to back).
// RulerAnimationDefinition/RulerPortraitDefinition describe that layout as
// static data (mirrors UnitDefinition/BuildingDefinition's registry
// pattern); RulerPortraitController is the live, per-instance state
// machine that actually plays it.
//
// 2026-07-11 request's behavior, in the controller's terms: play a clip to
// completion at the portrait's frameAdvance rate, land on whichever idle
// frame (Left/Right) matches the clip's endFacing, sit there for a random
// wait, then pick a new clip at random from whatever's legal to START from
// that facing, and repeat. "Legal to start" is data, not hardcoded --
// RulerAnimationDefinition.startFacing/endFacing let the same controller
// drive any future ruler's portrait without new code, as long as its
// definition is authored correctly (every non-idle clip needs a matching
// idle clip registered for whatever facing it can start from).
// -----------------------------------------------------------

/// @function RulerAnimationDefinition(_name, _startIndex, _frameCount, _startFacing, _endFacing, _isIdle)
/// @description One named animation clip within a ruler portrait's sprite
///        strip -- a contiguous run of frames, played in order.
/// @param {String} _name Human-readable label, e.g. "Blink Left to Right"
///        -- for debugging/logging only, never looked up by name at runtime.
/// @param {Real} _startIndex First image_index frame of this clip within
///        the portrait's sprite.
/// @param {Real} _frameCount Number of consecutive frames, played in order
///        (_startIndex .. _startIndex + _frameCount - 1).
/// @param {Enum.FACING} _startFacing Which way the portrait must ALREADY
///        be facing for this clip to be eligible to start -- see
///        RulerPortraitDefinition.GetPlayableAnimations.
/// @param {Enum.FACING} _endFacing Which way the portrait is facing on the
///        clip's last frame -- determines which idle clip it rests on
///        afterward (RulerPortraitDefinition.GetIdleAnimation).
/// @param {Bool} [_isIdle] True for the single-frame "resting" clips (e.g.
///        Idle Looking Left/Right). Idle clips are never picked as the
///        "next animation" by RulerPortraitController -- they're the rest
///        state a real animation lands ON, not something played on their
///        own initiative. Default false.
function RulerAnimationDefinition(_name, _startIndex, _frameCount, _startFacing, _endFacing, _isIdle = false) constructor {
    name        = _name;
    startIndex  = _startIndex;
    frameCount  = _frameCount;
    startFacing = _startFacing;
    endFacing   = _endFacing;
    isIdle      = _isIdle;
}

// ~10fps at this project's 60fps room speed (see PLOT_HOVER_DELAY_STEPS/
// CASTLE_NO_DAMAGE_XP_STEPS's "60fps" comments for the same room-speed
// assumption elsewhere) -- matches sConeliusPortrait's own authored
// sequence playbackSpeed (10.0, see the sprite's .yy), not an arbitrary
// pick. Override per-portrait via RulerPortraitDefinition's _frameAdvance
// if a future ruler's strip is authored at a different speed.
#macro RULER_PORTRAIT_DEFAULT_FRAME_ADVANCE (10 / 60)

/// @function RulerPortraitDefinition(_sprite, _animations, _frameAdvance)
/// @description Static per-ruler portrait data: which sprite strip, what
///        animation clips live in it, and how fast they play. Register one
///        via RegisterRulerPortrait(); look it up with
///        GetRulerPortraitDefinition().
/// @param {Asset.GMSprite} _sprite The single multi-index portrait strip
///        (e.g. sConeliusPortrait). Every RulerAnimationDefinition's
///        startIndex/frameCount indexes into this same sprite.
/// @param {Array<Struct.RulerAnimationDefinition>} _animations Every
///        animation clip available on this portrait, in any order.
/// @param {Real} [_frameAdvance] Frames advanced per Step at
///        global.matchSpeed == 1 (fractional -- accumulated, not rounded,
///        by RulerPortraitController). Default
///        RULER_PORTRAIT_DEFAULT_FRAME_ADVANCE.
function RulerPortraitDefinition(_sprite, _animations, _frameAdvance = RULER_PORTRAIT_DEFAULT_FRAME_ADVANCE) constructor {
    sprite       = _sprite;
    animations   = _animations;
    frameAdvance = _frameAdvance;

    /// @function GetIdleAnimation(_facing)
    /// @description Finds this portrait's resting clip for a given facing
    ///        (isIdle == true && startFacing == _facing).
    /// @param {Enum.FACING} _facing
    /// @returns {Struct.RulerAnimationDefinition|Undefined} Undefined if
    ///        this portrait has no idle clip for that facing -- treat as a
    ///        data-authoring gap, every registered portrait should have
    ///        both an Idle Left and an Idle Right clip.
    static GetIdleAnimation = function(_facing) {
        for (var i = 0; i < array_length(animations); i++) {
            if (animations[i].isIdle && animations[i].startFacing == _facing) return animations[i];
        }
        return undefined;
    }

    /// @function GetPlayableAnimations(_facing)
    /// @description Every non-idle clip eligible to start from the given
    ///        facing -- the pool RulerPortraitController picks a random
    ///        entry from once the idle wait expires.
    /// @param {Enum.FACING} _facing
    /// @returns {Array<Struct.RulerAnimationDefinition>} Empty if nothing
    ///        can start from this facing (shouldn't happen for a properly
    ///        authored portrait, but not enforced here).
    static GetPlayableAnimations = function(_facing) {
        var _result = [];
        for (var i = 0; i < array_length(animations); i++) {
            if (!animations[i].isIdle && animations[i].startFacing == _facing) {
                array_push(_result, animations[i]);
            }
        }
        return _result;
    }
}

// -----------------------------------------------------------
// Ruler portrait registry -- every playable ruler's portrait data, keyed
// by a plain string name (global.selectedRuler indexes into this). Mirrors
// RegisterOrder/GetOrder's registry pattern (UnitSelection.gml).
// -----------------------------------------------------------

global.__rulerPortraitRegistry = {};

/// @function RegisterRulerPortrait(_name, _def)
/// @param {String} _name Key used by global.selectedRuler, e.g. "conelius".
/// @param {Struct.RulerPortraitDefinition} _def
function RegisterRulerPortrait(_name, _def) {
    variable_struct_set(global.__rulerPortraitRegistry, _name, _def);
}

/// @function GetRulerPortraitDefinition(_name)
/// @param {String} _name
/// @returns {Struct.RulerPortraitDefinition|Undefined}
function GetRulerPortraitDefinition(_name) {
    return variable_struct_exists(global.__rulerPortraitRegistry, _name)
        ? variable_struct_get(global.__rulerPortraitRegistry, _name)
        : undefined;
}

/// @function RegisterAllRulerPortraits()
/// @description Registers every playable ruler's portrait animation data.
///        Call once at game start (oGameControl's Create event, alongside
///        RegisterAllOrders/RegisterAllUnitDefinitions/
///        RegisterAllBuildingDefinitions).
function RegisterAllRulerPortraits() {
    // Conelius -- sConeliusPortrait, 30 frames (0-29) across 6 clips, per
    // the 2026-07-11 data sheet: 1 (Idle Left) + 4 (Blink Left to Right) +
    // 1 (Idle Right) + 5 (Blink Right) + 5 (Mustache Wiggle) +
    // 14 (Looking Around) = 30, laid out back to back in that order.
    //
    // Only "Blink Left to Right" starts from LEFT -- every other real
    // animation starts from RIGHT, and only "Looking Around" ends back on
    // LEFT. So from Idle Left, the only thing that can ever play is
    // "Blink Left to Right"; everything else waits for Conelius to look
    // left again via "Looking Around" first. Matches the request's example
    // exactly ("animations that start with him looking left cannot start
    // until he looks left again").
    RegisterRulerPortrait("conelius", new RulerPortraitDefinition(sConeliusPortrait, [
        new RulerAnimationDefinition("Idle Looking Left",   0,  1,  FACING.LEFT,  FACING.LEFT,  true),
        new RulerAnimationDefinition("Blink Left to Right", 1,  4,  FACING.LEFT,  FACING.RIGHT),
        new RulerAnimationDefinition("Idle Looking Right",  5,  1,  FACING.RIGHT, FACING.RIGHT, true),
        new RulerAnimationDefinition("Blink Right",         6,  5,  FACING.RIGHT, FACING.RIGHT),
        new RulerAnimationDefinition("Mustache Wiggle",     11, 5,  FACING.RIGHT, FACING.RIGHT),
        new RulerAnimationDefinition("Looking Around",      16, 14, FACING.RIGHT, FACING.LEFT),
    ]));
}

// -----------------------------------------------------------
// RulerPortraitController -- live per-instance playback state.
// -----------------------------------------------------------

// ASSUMPTION (flag if the feel is off in-engine): idle wait between
// animations is a random 2-5 sec at matchSpeed 1, in steps at this
// project's 60fps room speed -- not specified by the request, picked to
// read as "occasionally fidgets" rather than constantly animating or
// standing frozen.
#macro RULER_PORTRAIT_IDLE_MIN_STEPS 120 // 2 sec
#macro RULER_PORTRAIT_IDLE_MAX_STEPS 300 // 5 sec

/// @function RulerPortraitController(_def)
/// @description Drives one ruler portrait: plays a chosen animation clip to
///        completion at the portrait's frameAdvance rate, rests on the
///        matching idle frame for a random duration, then picks a new clip
///        at random from whatever's legal to start from the current
///        facing, per the 2026-07-11 request. One instance per portrait
///        shown on screen -- oUnitControl owns the player's.
/// @param {Struct.RulerPortraitDefinition} _def
function RulerPortraitController(_def) constructor {
    def = _def;

    // Conelius' animation #1 ("Idle Looking Left") is the natural resting
    // default -- see RegisterAllRulerPortraits. A future ruler whose data
    // doesn't register an Idle Left clip would start with currentAnimation
    // undefined; not guarded against here since every ruler is expected to
    // have both idle clips (see GetIdleAnimation's own doc comment).
    facing           = FACING.LEFT;
    state            = "idle"; // "idle" or "playing" -- plain strings, not a #macro/enum, since nothing outside this struct reads it (unlike FACING, which crosses into RulerAnimationDefinition's data)
    currentAnimation = def.GetIdleAnimation(facing);
    frameProgress    = 0; // fractional frame index into currentAnimation while state == "playing"; unused while idle
    
    /// @function RandomIdleDuration()
    /// @description Picks a new random idle wait, in steps at matchSpeed == 1.
    /// @returns {Real}
    static RandomIdleDuration = function() {
        return irandom_range(RULER_PORTRAIT_IDLE_MIN_STEPS, RULER_PORTRAIT_IDLE_MAX_STEPS);
    }
    
    idleTimer        = RandomIdleDuration();

    /// @function Step()
    /// @description Call once per Step event. Scaled by global.matchSpeed
    ///        throughout -- both animation playback and the idle wait --
    ///        so the portrait pauses/fast-forwards along with the rest of
    ///        the match, same idiom as _unit.image_speed = global.matchSpeed
    ///        elsewhere in this codebase.
    static Step = function() {
        if (state == "idle") {
            idleTimer -= global.matchSpeed;
            if (idleTimer <= 0) {
                var _pool = def.GetPlayableAnimations(facing);
                if (array_length(_pool) == 0) {
                    // No animation can legally start from this facing --
                    // a data-authoring gap (every registered portrait
                    // should have at least one). Don't spin re-checking an
                    // empty pool every Step -- wait and try again.
                    idleTimer = RandomIdleDuration();
                    return;
                }
                currentAnimation = _pool[irandom(array_length(_pool) - 1)];
                frameProgress    = 0;
                state            = "playing";
            }
        } else {
            frameProgress += def.frameAdvance * global.matchSpeed;
            if (frameProgress >= currentAnimation.frameCount) {
                facing           = currentAnimation.endFacing;
                currentAnimation = def.GetIdleAnimation(facing);
                frameProgress    = 0;
                state            = "idle";
                idleTimer        = RandomIdleDuration();
            }
        }
    }

    /// @function CurrentImageIndex()
    /// @description The sprite frame to draw this Step.
    /// @returns {Real}
    static CurrentImageIndex = function() {
        if (state == "idle") return currentAnimation.startIndex;
        return currentAnimation.startIndex + min(floor(frameProgress), currentAnimation.frameCount - 1);
    }

    /// @function Draw(_x, _y, _scale)
    /// @description Call once per Draw GUI event. Draws at (_x, _y) using
    ///        the portrait sprite's own origin (bottom-left for every
    ///        portrait registered so far -- see each sprite's .yy).
    /// @param {Real} _x
    /// @param {Real} _y
    /// @param {Real} [_scale] Default 2 -- matches HOVER_CARD_SCALE, this
    ///        project's standard UI upscale factor.
    static Draw = function(_x, _y, _scale = 2) {
        draw_sprite_ext(def.sprite, CurrentImageIndex(), _x, _y, _scale, _scale, 0, c_white, 1);
    }
}
