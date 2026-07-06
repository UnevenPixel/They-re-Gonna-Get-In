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
// The actual weighted Fate Engine reward table (resource building /
// training building / resource bundle / event, scaled by corruption) is
// NOT built yet -- see the 2026-07-05 Fate Engine design discussion. Slots
// are populated by FateDrumRandomPlaceholderItem, a stand-in that mixes
// "resource stack" items (sFateEngineResources) and "blueprint" items
// (a random registered building's own sprite), purely so this render/spin
// mechanic is visually testable in isolation with roughly the right look.
// Stop() already accepts an optional _targetItem so the future
// reward-resolution task can force a drum to land on a specific resolved
// result without touching this file again.
//
// All drum items are 48x48 (sFateEngineResources' native size, and every
// building sprite -- oBuildingParent is always 48x48). Drawing them at
// FATE_DRUM_ITEM_SCALE (2x, per 2026-07-05 request) is handled entirely in
// Draw() below -- callers just position drums in GUI space and don't need
// to think about the scale themselves.
// -----------------------------------------------------------

#macro FATE_DRUM_SLOT_COUNT    8    // items spaced evenly around the cylinder
#macro FATE_DRUM_SPIN_SPEED    18   // degrees/step at 1x match speed while spinning
#macro FATE_DRUM_STOP_DECEL    0.6  // degrees/step^2 shed from spin speed while stopping
#macro FATE_DRUM_BACK_ZONE_MIN 150  // degrees -- a slot inside [MIN,MAX] is "at the back", hidden, and eligible to swap
#macro FATE_DRUM_BACK_ZONE_MAX 210
#macro FATE_DRUM_ITEM_SCALE    2    // GUI render scale for every item sprite (48x48 -> 96x96) -- 2026-07-05 request

/// @function FateEngineItem(_sprite, _subimg, _label)
/// @description One item shown on a Fate Engine drum -- just enough to
///        draw an icon and label it on hover. This is deliberately
///        generic (sprite/subimg/label, nothing reward-specific) so the
///        real reward-resolution task can hand the drum any resolved
///        reward (a building, a resource bundle, an event) through the
///        same shape.
/// @param {Asset.GMSprite} _sprite
/// @param {Real} _subimg
/// @param {String} _label Display text for the hover tooltip.
function FateEngineItem(_sprite, _subimg, _label) constructor {
    sprite = _sprite;
    subimg = _subimg;
    label  = _label;
}

/// @function FateDrumRandomPlaceholderItem()
/// @description STUB item source -- a coin-flip between a "resource
///        stack" look (sFateEngineResources, one of the 10 base
///        resources via global.resourceIconOrder, same frame order as
///        sResourceIcons, with a placeholder amount) and a "blueprint"
///        look (a random currently-registered building's own sprite +
///        display name, read generically off
///        global.__buildingDefRegistry so this doesn't need updating as
///        buildings are added). Stands in for the real weighted Fate
///        Engine reward table (resource building / training building /
///        resource bundle / event, scaled by corruption -- not designed
///        yet) purely so the drum's spin/swap/lock mechanic can be built
///        and tested now with roughly the right visual mix. Replace the
///        calls in FateDrum's constructor/Step once that table exists.
/// @returns {Struct.FateEngineItem}
function FateDrumRandomPlaceholderItem() {
    if (irandom(1) == 0) {
        var _index    = irandom(array_length(global.resourceIconOrder) - 1);
        var _resource = global.resourceIconOrder[_index];
        var _amount   = irandom_range(10, 100); // placeholder -- real bundle sizing/odds not designed yet
        return new FateEngineItem(sFateEngineResources, _index, $"{_amount} {_resource}");
    } else {
        var _buildingTypes = ds_map_keys_to_array(global.__buildingDefRegistry);
        var _buildingType  = _buildingTypes[irandom(array_length(_buildingTypes) - 1)];
        var _def           = GetBuildingDefinition(_buildingType);
        return new FateEngineItem(_def.sprite, 0, _def.name);
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
    spinSpeed     = 0;         // degrees/step, at 1x match speed
    state         = "stopped"; // "stopped" | "spinning" | "stopping"
    pendingResult = undefined; // Struct.FateEngineItem|Undefined -- see Stop()

    // One entry per slot: {item, wasInBackZone}. wasInBackZone gates the
    // swap-on-entry so a slot rerolls exactly ONCE per pass through the
    // back zone, not every step while it happens to be sitting there.
    slots = array_create(FATE_DRUM_SLOT_COUNT, undefined);
    for (var i = 0; i < FATE_DRUM_SLOT_COUNT; i++) {
        slots[i] = {
            item          : FateDrumRandomPlaceholderItem(),
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
    /// @description Begins decelerating toward a stop. Once fully
    ///        stopped, the drum snaps to land exactly on a slot (angle 0)
    ///        -- see Step(). If _targetItem is given, that slot's item is
    ///        forced to _targetItem the moment it lands, so a future
    ///        weighted reward roll can dictate the actual result rather
    ///        than leaving it to whatever was already spinning there.
    /// @param {Struct.FateEngineItem} [_targetItem]
    static Stop = function(_targetItem = undefined) {
        if (state != "spinning") return;
        state         = "stopping";
        pendingResult = _targetItem;
    }

    /// @function Step()
    /// @description Call once per Step while this drum exists. Advances
    ///        rotation, handles the stopping snap (+ applying
    ///        pendingResult), and refreshes any slot that just entered
    ///        the hidden back zone.
    static Step = function() {
        if (state == "spinning") {
            spinAngle += spinSpeed * global.matchSpeed;
        } else if (state == "stopping") {
            spinSpeed -= FATE_DRUM_STOP_DECEL * global.matchSpeed;

            // Once slow enough, snap to the nearest slot boundary and stop
            // outright rather than crawling asymptotically toward it --
            // simple placeholder deceleration, tune freely later.
            if (spinSpeed <= FATE_DRUM_STOP_DECEL * 4) {
                var _spacing = 360 / FATE_DRUM_SLOT_COUNT;
                spinAngle = round(spinAngle / _spacing) * _spacing;
                spinSpeed = 0;
                state     = "stopped";

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
                spinAngle += spinSpeed * global.matchSpeed;
            }
        }

        spinAngle = ((spinAngle mod 360) + 360) mod 360;

        for (var i = 0; i < FATE_DRUM_SLOT_COUNT; i++) {
            var _slot       = slots[i];
            var _theta      = GetSlotAngle(i);
            var _inBackZone = (_theta >= FATE_DRUM_BACK_ZONE_MIN && _theta <= FATE_DRUM_BACK_ZONE_MAX);

            if (_inBackZone && !_slot.wasInBackZone) {
                _slot.item = FateDrumRandomPlaceholderItem();
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
