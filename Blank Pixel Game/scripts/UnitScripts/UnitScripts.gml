/// @function ChooseCombatTarget(_unit)
/// @description Picks a combat target for a unit. Stub -- always returns noone;
///        replace with real target-selection logic (nearest enemy, threat score,
///        etc.) once combat targeting is implemented.
/// @param {Id.Instance} _unit
/// @returns {Id.Instance|Constant.NoOne}
function ChooseCombatTarget(_unit){
    return noone;
}

/// @function UnitDataBlock()
/// @description Per-unit scratch data that doesn't belong on the base object
///        variables -- damage taken, active status effects, and which
///        UnitDefinition this unit is (see UnitApplyDefinition in
///        UnitDefinitions.gml). This is deliberately the ONLY state a
///        stationed unit needs to remember: when oUnitStationed is built, it
///        should hold nothing but a UnitDataBlock, and redeploy by handing
///        this struct to the new instance and calling UnitApplyDefinition
///        again -- unitType is what tells it which definition to reapply.
function UnitDataBlock() constructor{
    damageTaken = 0;
    statusEffects = [];
    unitType = undefined; // Asset.GMObject -- set by UnitApplyDefinition
}

// -----------------------------------------------------------
// A. Sprite and facing
// -----------------------------------------------------------

#macro UNIT_WALK_THRESHOLD 0.25 // minimum speed to show the walk sprite
#macro UNIT_FACE_THRESHOLD 0.75  // minimum speed before image_xscale updates.
                                 // Higher than UNIT_WALK_THRESHOLD so facing
                                 // locks in before the walk sprite switches off,
                                 // preventing the last frames of deceleration
                                 // from flickering the unit's facing direction.

/// @function UnitUpdateSprite(_unit)
/// Updates sprite_index (idle vs walk) and image_xscale (facing)
/// for the calling instance based on its agent's current velocity.
/// Must be called from instance scope.
///
/// Rules:
///   - Never interrupts an in-progress attack animation.
///   - image_xscale only updates above UNIT_FACE_THRESHOLD so facing
///     locks in during deceleration and doesn't flicker as the unit
///     comes to a stop.
///   - Only flips on meaningful horizontal movement (|velocity.x| > 0.1)
///     so a unit moving purely vertically keeps its last facing direction.
///
/// @param {Id.Instance} _unit
function UnitUpdateSprite(_unit) {
    if (_unit.sprite_index == _unit.sprAttack) return;

    var _vel   = _unit.agent.velocity;
    var _speed = _vel.Length();

    // Facing updates at the higher threshold -- locks in before the
    // sprite switches back to idle so there's no last-frame flip.
    if (_speed > UNIT_FACE_THRESHOLD && abs(_vel.x) > 0.1) {
        _unit.image_xscale = (_vel.x >= 0) ? 1 : -1;
    }

    // Sprite switches at the lower threshold.
    _unit.sprite_index = (_speed > UNIT_WALK_THRESHOLD) ? _unit.sprWalk : _unit.sprIdle;
}

// -----------------------------------------------------------
// B. Play area
// -----------------------------------------------------------

/// @function InitPlayArea(_x1, _y1, _x2, _y2)
/// Call once at game/room start with your actual coordinates.
/// "Between the two castle fronts and above the UI strip" --
/// replace the placeholder values below with real ones.
///
/// @param {Real} _x1 Left edge (roughly: player castle front x)
/// @param {Real} _y1 Top edge (top of the playfield)
/// @param {Real} _x2 Right edge (roughly: enemy castle front x)
/// @param {Real} _y2 Bottom edge (top of the UI strip)
function InitPlayArea(_x1, _y1, _x2, _y2) {
    global.playAreaRect = {
        x1: _x1,
        y1: _y1,
        x2: _x2,
        y2: _y2
    };
}

// Example call (replace with real room coordinates):
// InitPlayArea(128, 32, room_width - 128, room_height - 96);
//                                         ^^^^^^^^^^^^^^^^
//                                         96px UI strip at bottom

#macro PLAY_AREA_CONTAIN_MARGIN 8  // how far from the edge the nudge begins
#macro PLAY_AREA_CONTAIN_WEIGHT 0.4 // low weight -- a soft suggestion, not a wall

// -----------------------------------------------------------
// B2. Team guard zones
// -----------------------------------------------------------

/// @function GetTeamGuardRect(_team)
/// @description Returns a team's default guard patrol zone -- what
///        oUnitParent assigns to guardRect at Create time. The player's
///        zone is authored directly, sitting just in front of (i.e. on the
///        battlefield side of) the player castle. Every other team's zone
///        is derived by mirroring it across room_width -- the same axis
///        oCastleManager uses for oPlayerCastle/oEnemyCastle and
///        oOuterPlotSpawner uses for its plots -- so the enemy's zone ends
///        up the same size, the same distance in front of its own castle.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Struct.ShapeRect}
function GetTeamGuardRect(_team) {
    var _playerRect = new ShapeRect(328, 8, 480, 400);

    if (_team == TEAM.PLAYER) {
        return _playerRect;
    }

    return new ShapeRect(
        room_width - _playerRect.x2,
        _playerRect.y1,
        room_width - _playerRect.x1,
        _playerRect.y2
    );
}

// -----------------------------------------------------------
// C. Shared order dispatch
// -----------------------------------------------------------

/// @function IssueOrderToUnits(_orderName, _units, _context)
/// Issues a named order to an array of unit instances. Used by
/// BOTH the player's SelectionController and the AI controller,
/// so both paths go through the same Order.onIssue callback.
///
/// Does NOT handle targeting mode -- that's a player-UI concern
/// managed by SelectionController. When the AI issues an order
/// that would normally require a target click (e.g. "defend"),
/// pass the target directly as _context here; the onIssue
/// callback receives it either way.
///
/// @param {String}          _orderName
/// @param {Array<Id.Instance>} _units
/// @param {*}               [_context] Target instance, position,
///        or whatever the order's onIssue expects.
function IssueOrderToUnits(_orderName, _units, _context = undefined) {
    var _order = GetOrder(_orderName);
    if (_order == undefined) {
        show_debug_message($"IssueOrderToUnits: unknown order '{_orderName}'");
        return;
    }
    if (array_length(_units) == 0) return;
    _order.onIssue(_units, _context);
}
