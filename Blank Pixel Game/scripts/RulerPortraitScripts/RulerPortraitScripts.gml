// Animated ruler portraits -- static per-ruler clip/frame data
// (RulerAnimationDefinition/RulerPortraitDefinition) plus the live
// per-instance playback state machine (RulerPortraitController). See
// RulerPortraitScripts.md.

/// @function RulerAnimationDefinition(_name, _startIndex, _frameCount, _startFacing, _endFacing, _isIdle)
/// @description One named animation clip within a ruler portrait's sprite strip -- a contiguous run of frames, played in order. See .md.
/// @param {String} _name Human-readable label, for debugging/logging only.
/// @param {Real} _startIndex First image_index frame of this clip within the portrait's sprite.
/// @param {Real} _frameCount Number of consecutive frames, played in order.
/// @param {Enum.FACING} _startFacing Which way the portrait must already be facing for this clip to be eligible to start.
/// @param {Enum.FACING} _endFacing Which way the portrait is facing on the clip's last frame.
/// @param {Bool} [_isIdle] True for single-frame "resting" clips. Default false.
function RulerAnimationDefinition(_name, _startIndex, _frameCount, _startFacing, _endFacing, _isIdle = false) constructor {
    name        = _name;
    startIndex  = _startIndex;
    frameCount  = _frameCount;
    startFacing = _startFacing;
    endFacing   = _endFacing;
    isIdle      = _isIdle;
}

#macro RULER_PORTRAIT_DEFAULT_FRAME_ADVANCE (10 / 60) // ~10fps at 60fps room speed -- matches sConeliusPortrait's authored playbackSpeed

/// @function RulerPortraitDefinition(_sprite, _animations, _frameAdvance)
/// @description Static per-ruler portrait data: which sprite strip, what animation clips live in it, and how fast they play. Register via RegisterRulerPortrait(); look up with GetRulerPortraitDefinition(). See .md.
/// @param {Asset.GMSprite} _sprite The single multi-index portrait strip.
/// @param {Array<Struct.RulerAnimationDefinition>} _animations Every animation clip available on this portrait.
/// @param {Real} [_frameAdvance] Frames advanced per Step at global.matchSpeed == 1. Default RULER_PORTRAIT_DEFAULT_FRAME_ADVANCE.
function RulerPortraitDefinition(_sprite, _animations, _frameAdvance = RULER_PORTRAIT_DEFAULT_FRAME_ADVANCE) constructor {
    sprite       = _sprite;
    animations   = _animations;
    frameAdvance = _frameAdvance;

    /// @function GetIdleAnimation(_facing)
    /// @description Finds this portrait's resting clip for a given facing.
    /// @param {Enum.FACING} _facing
    /// @returns {Struct.RulerAnimationDefinition|Undefined} Undefined if this portrait has no idle clip for that facing.
    static GetIdleAnimation = function(_facing) {
        for (var i = 0; i < array_length(animations); i++) {
            if (animations[i].isIdle && animations[i].startFacing == _facing) return animations[i];
        }
        return undefined;
    }

    /// @function GetPlayableAnimations(_facing)
    /// @description Every non-idle clip eligible to start from the given facing.
    /// @param {Enum.FACING} _facing
    /// @returns {Array<Struct.RulerAnimationDefinition>} Empty if nothing can start from this facing.
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
/// @description Registers every playable ruler's portrait animation data. Call once at game start, alongside RegisterAllOrders/RegisterAllUnitDefinitions/RegisterAllBuildingDefinitions. See .md for Conelius' clip layout.
function RegisterAllRulerPortraits() {
    RegisterRulerPortrait("conelius", new RulerPortraitDefinition(sConeliusPortrait, [
        new RulerAnimationDefinition("Idle Looking Left",   0,  1,  FACING.LEFT,  FACING.LEFT,  true),
        new RulerAnimationDefinition("Blink Left to Right", 1,  4,  FACING.LEFT,  FACING.RIGHT),
        new RulerAnimationDefinition("Idle Looking Right",  5,  1,  FACING.RIGHT, FACING.RIGHT, true),
        new RulerAnimationDefinition("Blink Right",         6,  5,  FACING.RIGHT, FACING.RIGHT),
        new RulerAnimationDefinition("Mustache Wiggle",     11, 5,  FACING.RIGHT, FACING.RIGHT),
        new RulerAnimationDefinition("Looking Around",      16, 14, FACING.RIGHT, FACING.LEFT),
    ]));
}

#macro RULER_PORTRAIT_IDLE_MIN_STEPS 120 // 2 sec at matchSpeed 1 -- ASSUMPTION, flag if the feel is off in-engine
#macro RULER_PORTRAIT_IDLE_MAX_STEPS 300 // 5 sec

/// @function RulerPortraitController(_def)
/// @description Drives one ruler portrait: plays a chosen clip to completion at frameAdvance rate, rests on the matching idle frame for a random duration, then picks a new legal clip at random. One instance per portrait shown on screen. See .md.
/// @param {Struct.RulerPortraitDefinition} _def
function RulerPortraitController(_def) constructor {
    def = _def;

    facing           = FACING.LEFT;
    state            = "idle"; // "idle" or "playing" -- plain string, nothing outside this struct reads it
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
    /// @description Call once per Step event. Scaled by global.matchSpeed throughout (animation playback and idle wait). See .md.
    static Step = function() {
        if (state == "idle") {
            idleTimer -= global.matchSpeed;
            if (idleTimer <= 0) {
                var _pool = def.GetPlayableAnimations(facing);
                if (array_length(_pool) == 0) {
                    // No animation can legally start from this facing -- a
                    // data-authoring gap. Don't spin re-checking an empty
                    // pool every Step -- wait and try again.
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
    /// @description Call once per Draw GUI event. Draws at (_x, _y) using the portrait sprite's own origin.
    /// @param {Real} _x
    /// @param {Real} _y
    /// @param {Real} [_scale] Default 2 -- matches HOVER_CARD_SCALE.
    static Draw = function(_x, _y, _scale = 2) {
        draw_sprite_ext(def.sprite, CurrentImageIndex(), _x, _y, _scale, _scale, 0, c_white, 1);
    }
}
