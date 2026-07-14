// -----------------------------------------------------------
// FateEngineDrumScripts -- the Fate Engine's spinning drum render.
//
// Each drum is a faked 3D cylinder: FATE_DRUM_SLOT_COUNT items sit evenly
// spaced around a vertical ellipse (a classic 2D "fake carousel" trick,
// same idea as a rotating coin/wheel menu). Angle 0 is the front/landing
// position -- straight ahead, facing the player, at the drum's vertical
// center. As spinAngle advances, each slot's angle -> depth (cos) and
// vertical offset (radius * sin) are recomputed every step:
//   depth  +1 at the front (angle 0)   -- full size, fully opaque
//   depth   0 at the sides (angle 90/270) -- edge-on, thin sliver
//   depth  -1 at the back (angle 180)  -- directly behind the front slot,
//                                         same screen position, hidden
// Only slots with depth > 0 (the front hemisphere) are drawn at all --
// the back hemisphere is conceptually occluded by the drum's own body.
// That's exactly where item swapping happens: the instant a slot crosses
// into the back zone, its item is silently replaced, so the "reel"
// appears to cycle through endless items without the player ever seeing
// a swap happen (requirement 1 from the 2026-07-05 Fate Engine drum-render
// task).
//
// Once stopped, GetLockedItem() reads back whichever item is sitting at
// the front/landing position (angle 0) -- that's what a hover tooltip (or
// eventually the cash-out payout) reads off (requirement 2).
//
// The real weighted Fate Engine reward table lives in FateEngineRollReward()
// below (2026-07-13) -- a straight coin-flip between a blueprint reward
// (uniform over every currently-registered building type,
// global.__buildingDefRegistry) and a resource bundle (uniform over the 5
// CURRENTLY ACTIVE base resources -- wood/wheat/water/iron/gold; the other
// 5 slots in global.resourceIconOrder -- meat/bones/coal/weapons/coins --
// aren't produced or spent by anything yet, confirmed via grep, so
// rewarding them would just be inert). This replaces the old
// FateDrumRandomPlaceholderItem stub, which only ever produced a LOOK
// (sprite/subimg/label) with no data behind it -- FateEngineItem now
// carries rewardType/rewardData too so FateEngineOverlay.Cashout()
// (FateEngineOverlayScripts.gml) can actually grant what a drum landed on.
// Odds/amounts below are a first-pass judgment call, not a tuned design
// (no corruption-scaling/event-type rewards exist yet either) -- see
// PATCH_NOTES.md for the full list of what's still a placeholder here.
// Stop() already accepts an optional _targetItem so a future weighted-
// odds-by-corruption pass can still force a drum to land on a specific
// resolved result without touching this file's mechanics again.
//
// All drum items are 48x48 (sFateEngineResources' native size, and every
// building sprite -- oBuildingParent is always 48x48). Drawing them at
// FATE_DRUM_ITEM_SCALE (2x, per 2026-07-05 request) is handled entirely in
// Draw() below -- callers just position drums in GUI space and don't need
// to think about the scale themselves.
//
// 2026-07-13: drum animation (spin/decel/landing, Step() below) no longer
// scales by global.matchSpeed -- the drums are a UI mechanic independent of
// the battlefield's speed control, and FateEngineOverlay freezes
// global.matchSpeed to 0 while open anyway (FateEngineOverlayScripts.gml),
// which would have frozen the drums too if they'd stayed coupled to it.
// Every rate below is now a flat degrees/step (or fraction/step) value.
// -----------------------------------------------------------

#macro FATE_DRUM_SLOT_COUNT       5    // items spaced evenly around the cylinder
#macro FATE_DRUM_SPIN_SPEED       18   // degrees/step while spinning -- independent of global.matchSpeed, see file header
#macro FATE_DRUM_STOP_DECEL       0.6  // degrees/step^2 shed from spin speed while stopping
#macro FATE_DRUM_BACK_ZONE_MIN    150  // degrees -- a slot inside [MIN,MAX] is "at the back", hidden, and eligible to swap
#macro FATE_DRUM_BACK_ZONE_MAX    210
#macro FATE_DRUM_ITEM_SCALE       2    // GUI render scale for every item sprite (48x48 -> 96x96) -- 2026-07-05 request
#macro FATE_DRUM_LAND_EASE_RATE   0.2  // fraction of the remaining angle-to-target closed per step while "landing"
#macro FATE_DRUM_LAND_SNAP_EPSILON 0.5 // degrees -- close enough to the target to snap exactly and finish landing

#macro FATE_ENGINE_REWARD_BLUEPRINT_CHANCE 0.5  // odds a roll resolves to a blueprint instead of a resource bundle -- arbitrary 50/50 placeholder, not a tuned design
#macro FATE_ENGINE_REWARD_RESOURCE_MIN     20   // resource bundle amount range -- rough middle-of-the-road against tier-1 building costs (20-150), not tuned
#macro FATE_ENGINE_REWARD_RESOURCE_MAX     60

// The 5 CURRENTLY ACTIVE base resources -- see file header for why
// meat/bones/coal/weapons/coins are excluded. Plain global array (not a
// #macro), same "allocate once" reasoning as global.resourceIconOrder
// (ResourceUIScripts.gml).
global.fateEngineRewardResourceTypes = ["wood", "wheat", "water", "iron", "gold"];

/// @function FateEngineItem(_sprite, _subimg, _label, _rewardType, _rewardData)
/// @description One item shown on a Fate Engine drum -- an icon/label to
///        draw plus, since 2026-07-13, enough data to actually GRANT the
///        reward it represents. Still deliberately generic on the display
///        side (sprite/subimg/label) so a future event-type reward can
///        reuse the same shape; rewardType/rewardData is where the actual
///        payload lives.
/// @param {Asset.GMSprite} _sprite
/// @param {Real} _subimg
/// @param {String} _label Display text for the hover tooltip.
/// @param {String} _rewardType "resource" | "blueprint".
/// @param {Struct} _rewardData "resource": { resourceName, amount }.
///        "blueprint": { buildingType }.
function FateEngineItem(_sprite, _subimg, _label, _rewardType, _rewardData) constructor {
    sprite     = _sprite;
    subimg     = _subimg;
    label      = _label;
    rewardType = _rewardType;
    rewardData = _rewardData;
}

/// @function FateEngineRollReward()
/// @description The real Fate Engine reward roll -- see file header for
///        the full table/odds reasoning. Replaces the old
///        FateDrumRandomPlaceholderItem stub, which only produced a LOOK
///        with no data behind it. Coin-flips (FATE_ENGINE_REWARD_BLUEPRINT_CHANCE)
///        between:
///        - A blueprint: uniform over every currently-registered building
///          type (global.__buildingDefRegistry, read generically so this
///          doesn't need updating as buildings are added -- same idiom
///          GainXP's AI blueprint grant already uses, ProgressionScripts.gml).
///        - A resource bundle: uniform over global.fateEngineRewardResourceTypes
///          (the 5 currently-active base resources), amount uniformly
///          between FATE_ENGINE_REWARD_RESOURCE_MIN/MAX.
/// @returns {Struct.FateEngineItem}
function FateEngineRollReward() {
    if (random(1) < FATE_ENGINE_REWARD_BLUEPRINT_CHANCE) {
        var _buildingTypes = ds_map_keys_to_array(global.__buildingDefRegistry);
        var _buildingType  = _buildingTypes[irandom(array_length(_buildingTypes) - 1)];
        var _def           = GetBuildingDefinition(_buildingType);
        return new FateEngineItem(_def.sprite, 0, _def.name, "blueprint", { buildingType: _buildingType });
    } else {
        var _index    = irandom(array_length(global.fateEngineRewardResourceTypes) - 1);
        var _resource = global.fateEngineRewardResourceTypes[_index];
        var _amount   = irandom_range(FATE_ENGINE_REWARD_RESOURCE_MIN, FATE_ENGINE_REWARD_RESOURCE_MAX);
        return new FateEngineItem(sFateEngineResources, ResourceIconIndex(_resource), $"{_amount} {_resource}", "resource", { resourceName: _resource, amount: _amount });
    }
}

/// @function FateDrum(_x, _y, _radius)
/// @description A single Fate Engine drum. See file header for the
///        depth/back-zone mechanic. Not a GM instance -- a plain struct,
///        same pattern as BlueprintController/SelectionController
///        (BlueprintScripts.gml/UnitSelection.gml): an owning object calls
///        Step()/Draw() once per frame.
/// @param {Real} _x Center X (GUI space).
/// @param {Real} _y Center Y (GUI space).
/// @param {Real} [_radius] Visual radius of the ellipse. Defaults to 48.
function FateDrum(_x, _y, _radius = 48) constructor {
    x      = _x;
    y      = _y;
    radius = _radius;

    spinAngle     = 0;         // current overall rotation, degrees, 0-360
    spinSpeed     = 0;         // degrees/step -- independent of global.matchSpeed, see file header
    state         = "stopped"; // "stopped" | "spinning" | "stopping" | "landing"
    pendingResult = undefined; // Struct.FateEngineItem|Undefined -- see Stop()
    landingTarget = undefined; // Real|Undefined -- the slot-boundary angle "landing" is easing toward, see Step()

    // One entry per slot: {item, wasInBackZone}. wasInBackZone gates the
    // swap-on-entry so a slot rerolls exactly ONCE per pass through the
    // back zone, not every step while it happens to be sitting there.
    slots = array_create(FATE_DRUM_SLOT_COUNT, undefined);
    for (var i = 0; i < FATE_DRUM_SLOT_COUNT; i++) {
        slots[i] = {
            item          : FateEngineRollReward(),
            wasInBackZone : false,
        };
    }

    /// @function GetSlotAngle(_slotIndex)
    /// @param {Real} _slotIndex
    /// @returns {Real} That slot's current angle, 0-360 -- 0 == front/landing.
    static GetSlotAngle = function(_slotIndex) {
        var _spacing = 360 / FATE_DRUM_SLOT_COUNT;
        return ((spinAngle + _slotIndex * _spacing) mod 360 + 360) mod 360;
    }

    /// @function Spin()
    /// @description Starts the drum spinning at full speed. No-op if
    ///        already spinning/stopping.
    static Spin = function() {
        if (state != "stopped") return;
        state     = "spinning";
        spinSpeed = FATE_DRUM_SPIN_SPEED;
    }

    /// @function Stop(_targetItem)
    /// @description Begins decelerating toward a stop. Once slow enough,
    ///        the drum eases smoothly into landing exactly on a slot
    ///        (angle 0) rather than snapping there instantly -- see
    ///        Step()'s "landing" state. If _targetItem is given, that
    ///        slot's item is forced to _targetItem the moment it lands, so
    ///        a future weighted reward roll can dictate the actual result
    ///        rather than leaving it to whatever was already spinning
    ///        there.
    /// @param {Struct.FateEngineItem} [_targetItem]
    static Stop = function(_targetItem = undefined) {
        if (state != "spinning") return;
        state         = "stopping";
        pendingResult = _targetItem;
    }

    /// @function Step()
    /// @description Call once per Step while this drum exists. Advances
    ///        rotation, hands off from "stopping" to a "landing" ease
    ///        once slow enough (see below), and refreshes any slot that
    ///        just entered the hidden back zone. 2026-07-13: runs at a flat
    ///        per-step rate, independent of global.matchSpeed -- see file
    ///        header.
    static Step = function() {
        if (state == "spinning") {
            spinAngle += spinSpeed;
        } else if (state == "stopping") {
            spinSpeed -= FATE_DRUM_STOP_DECEL;

            // Once slow enough, stop decelerating and hand off to
            // "landing" rather than snapping straight to the nearest slot
            // boundary -- an instant snap reads as a jerk/pop. landingTarget
            // is fixed the moment we enter "landing"; Step's "landing"
            // branch eases spinAngle toward it every frame after.
            if (spinSpeed <= FATE_DRUM_STOP_DECEL * 4) {
                var _spacing = 360 / FATE_DRUM_SLOT_COUNT;
                landingTarget = round(spinAngle / _spacing) * _spacing;
                spinSpeed     = 0;
                state         = "landing";
            } else {
                spinAngle += spinSpeed;
            }
        } else if (state == "landing") {
            // Ease the remaining gap to landingTarget down every step
            // (2026-07-06 request: smooth landing instead of a hard snap).
            // The gap is normalized to (-180, 180] first so the drum always
            // eases along the SHORT way around -- since decel can overshoot
            // slightly past the nearest boundary, that short way is
            // sometimes backward ("rubber-banding" back up to the slot it
            // just passed), which is expected and fine here.
            var _delta = landingTarget - spinAngle;
            while (_delta > 180)  _delta -= 360;
            while (_delta <= -180) _delta += 360;

            if (abs(_delta) <= FATE_DRUM_LAND_SNAP_EPSILON) {
                spinAngle = landingTarget;
                state     = "stopped";
                landingTarget = undefined;

                if (pendingResult != undefined) {
                    for (var i = 0; i < FATE_DRUM_SLOT_COUNT; i++) {
                        if (GetSlotAngle(i) == 0) {
                            slots[i].item = pendingResult;
                            break;
                        }
                    }
                    pendingResult = undefined;
                }
            } else {
                spinAngle += _delta * FATE_DRUM_LAND_EASE_RATE;
            }
        }

        spinAngle = ((spinAngle mod 360) + 360) mod 360;

        for (var i = 0; i < FATE_DRUM_SLOT_COUNT; i++) {
            var _slot       = slots[i];
            var _theta      = GetSlotAngle(i);
            var _inBackZone = (_theta >= FATE_DRUM_BACK_ZONE_MIN && _theta <= FATE_DRUM_BACK_ZONE_MAX);

            if (_inBackZone && !_slot.wasInBackZone) {
                _slot.item = FateEngineRollReward();
            }
            _slot.wasInBackZone = _inBackZone;
        }
    }

    /// @function Draw()
    /// @description Draws every slot currently in the front hemisphere
    ///        (depth > 0), positioned/scaled/faded by its depth so the
    ///        drum reads as a spinning cylinder rather than a flat list.
    ///        Every item is drawn at FATE_DRUM_ITEM_SCALE (2x) on top of
    ///        its depth-based shrink -- e.g. a 48x48 item at full front
    ///        depth draws at 96x96, per 2026-07-05 request. Text (hover
    ///        tooltips etc.) is a separate concern for the caller and is
    ///        NOT scaled by this.
    static Draw = function() {
        for (var i = 0; i < FATE_DRUM_SLOT_COUNT; i++) {
            var _theta = GetSlotAngle(i);
            var _rad   = degtorad(_theta);
            var _depth = cos(_rad); // +1 front (landing) .. -1 back (hidden)
            if (_depth <= 0) continue; // back hemisphere -- not drawn, conceptually behind the drum's own front face

            var _offsetY = radius * sin(_rad);
            var _scale   = FATE_DRUM_ITEM_SCALE * (0.35 + 0.65 * _depth); // shrinks toward the top/bottom edge, never all the way to 0
            var _item    = slots[i].item;

            draw_sprite_ext(_item.sprite, _item.subimg, x, y + _offsetY, _scale, _scale, 0, c_white, _depth);
        }
    }

    /// @function GetLockedItem()
    /// @description The item currently at the front/landing position.
    ///        Only meaningful once the drum has actually stopped -- while
    ///        spinning or decelerating there's no single stable answer,
    ///        so this returns undefined. This is what a hover tooltip (or
    ///        eventually cash-out) should read.
    /// @returns {Struct.FateEngineItem|Undefined}
    static GetLockedItem = function() {
        if (state != "stopped") return undefined;

        for (var i = 0; i < FATE_DRUM_SLOT_COUNT; i++) {
            if (GetSlotAngle(i) == 0) return slots[i].item;
        }
        return undefined; // shouldn't happen once state == "stopped", but don't hard-crash if it does
    }
}
