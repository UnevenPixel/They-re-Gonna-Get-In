// Fate Engine spinning drum render -- fake-3D carousel (depth via cos,
// back-hemisphere item swap) plus the reward roll table. Independent of
// global.matchSpeed. See FateEngineDrumScripts.md.

#macro FATE_DRUM_SLOT_COUNT       5    // items spaced evenly around the cylinder
#macro FATE_DRUM_SPIN_SPEED       18   // degrees/step while spinning
#macro FATE_DRUM_STOP_DECEL       0.6  // degrees/step^2 shed from spin speed while stopping
#macro FATE_DRUM_BACK_ZONE_MIN    150  // degrees -- a slot inside [MIN,MAX] is "at the back", hidden, and eligible to swap
#macro FATE_DRUM_BACK_ZONE_MAX    210
#macro FATE_DRUM_ITEM_SCALE       2    // GUI render scale for every item sprite (48x48 -> 96x96)
#macro FATE_DRUM_LAND_EASE_RATE   0.2  // fraction of the remaining angle-to-target closed per step while "landing"
#macro FATE_DRUM_LAND_SNAP_EPSILON 0.5 // degrees -- close enough to the target to snap exactly and finish landing

#macro FATE_ENGINE_REWARD_BLUEPRINT_CHANCE 0.5  // odds a roll resolves to a blueprint instead of a resource bundle -- placeholder, not tuned
#macro FATE_ENGINE_REWARD_RESOURCE_MIN     20   // resource bundle amount range -- placeholder, not tuned
#macro FATE_ENGINE_REWARD_RESOURCE_MAX     60

global.fateEngineRewardResourceTypes = ["wood", "wheat", "water", "iron", "gold"]; // the 5 currently-active base resources -- see .md

/// @function FateEngineItem(_sprite, _subimg, _label, _rewardType, _rewardData)
/// @description One item shown on a Fate Engine drum -- an icon/label to draw plus enough data to actually grant the reward it represents. See .md.
/// @param {Asset.GMSprite} _sprite
/// @param {Real} _subimg
/// @param {String} _label Display text for the hover tooltip.
/// @param {String} _rewardType "resource" | "blueprint".
/// @param {Struct} _rewardData "resource": { resourceName, amount }. "blueprint": { buildingType }.
function FateEngineItem(_sprite, _subimg, _label, _rewardType, _rewardData) constructor {
    sprite     = _sprite;
    subimg     = _subimg;
    label      = _label;
    rewardType = _rewardType;
    rewardData = _rewardData;
}

/// @function FateEngineRollReward()
/// @description The real Fate Engine reward roll -- coin-flips between a uniform-random blueprint and a uniform-random resource bundle. See .md for the odds/amount reasoning.
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
/// @description A single Fate Engine drum -- fake-3D carousel, see .md. Not a GM instance -- a plain struct; an owning object calls Step()/Draw() once per frame.
/// @param {Real} _x Center X (GUI space).
/// @param {Real} _y Center Y (GUI space).
/// @param {Real} [_radius] Visual radius of the ellipse. Defaults to 48.
function FateDrum(_x, _y, _radius = 48) constructor {
    x      = _x;
    y      = _y;
    radius = _radius;

    spinAngle     = 0;         // current overall rotation, degrees, 0-360
    spinSpeed     = 0;         // degrees/step
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
    /// @description Starts the drum spinning at full speed. No-op if already spinning/stopping.
    static Spin = function() {
        if (state != "stopped") return;
        state     = "spinning";
        spinSpeed = FATE_DRUM_SPIN_SPEED;
    }

    /// @function Stop(_targetItem)
    /// @description Begins decelerating toward a smooth landing on a slot (angle 0). If _targetItem is given, that slot's item is forced to it the moment it lands. See .md.
    /// @param {Struct.FateEngineItem} [_targetItem]
    static Stop = function(_targetItem = undefined) {
        if (state != "spinning") return;
        state         = "stopping";
        pendingResult = _targetItem;
    }

    /// @function Step()
    /// @description Call once per Step while this drum exists. Advances rotation, hands off from "stopping" to a "landing" ease once slow enough, and refreshes any slot that just entered the hidden back zone. Flat per-step rate, independent of global.matchSpeed. See .md.
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
            // Ease the remaining gap to landingTarget down every step.
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
    /// @description Draws every slot currently in the front hemisphere (depth > 0), positioned/scaled/faded by its depth. Every item is additionally drawn at FATE_DRUM_ITEM_SCALE. Text is a separate concern for the caller and is NOT scaled by this. See .md.
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
    /// @description The item currently at the front/landing position. Only meaningful once the drum has actually stopped -- returns undefined while spinning/decelerating.
    /// @returns {Struct.FateEngineItem|Undefined}
    static GetLockedItem = function() {
        if (state != "stopped") return undefined;

        for (var i = 0; i < FATE_DRUM_SLOT_COUNT; i++) {
            if (GetSlotAngle(i) == 0) return slots[i].item;
        }
        return undefined; // shouldn't happen once state == "stopped", but don't hard-crash if it does
    }
}
