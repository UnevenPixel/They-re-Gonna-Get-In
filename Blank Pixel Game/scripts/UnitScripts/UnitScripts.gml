// Shared unit utilities that don't belong to any one system -- scratch data,
// sprite/facing, play area, team guard zones, order dispatch. See UnitScripts.md.

/// @function UnitDataBlock()
/// @description Per-unit scratch data that survives a station/redeploy swap -- damage taken, status effects, which UnitDefinition this unit is. See .md.
function UnitDataBlock() constructor{
    damageTaken = 0;
    statusEffects = [];
    unitType = undefined; // Asset.GMObject -- set by UnitApplyDefinition
}

#macro UNIT_WALK_THRESHOLD 0.125 // minimum speed to show the walk sprite -- 2026-10-14: halved from 0.25 with the unit speed halving, see .md
#macro UNIT_FACE_THRESHOLD 0.2 // minimum speed before image_xscale updates -- 2026-10-14: was 0.75, which exceeded every unit's maxSpeed except Bomb Goblin after the speed halving; must stay below the slowest maxSpeed (Mud Golem 0.3), see .md

/// @function UnitUpdateSprite(_unit)
/// @description Updates sprite_index (idle vs walk), image_xscale (facing), and image_speed (match-speed-scaled) from the calling instance's agent velocity. Must be called from instance scope. See .md for the full rule set.
/// @param {Id.Instance} _unit
function UnitUpdateSprite(_unit) {
    _unit.image_speed = global.matchSpeed;

    if (_unit.sprite_index == _unit.sprAttack) return;

    var _vel   = _unit.agent.velocity;
    var _speed = _vel.Length();

    if (_speed > UNIT_FACE_THRESHOLD && abs(_vel.x) > 0.05) {
        _unit.image_xscale = (_vel.x >= 0) ? 1 : -1;
    }

    _unit.sprite_index = (_speed > UNIT_WALK_THRESHOLD) ? _unit.sprWalk : _unit.sprIdle;
}

/// @function InitPlayArea(_x1, _y1, _x2, _y2)
/// @description Call once at game/room start with real coordinates -- "between the two castle fronts and above the UI strip."
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

/// @function GetTeamGuardRect(_team)
/// @description Returns a team's default guard patrol zone -- what oUnitParent assigns to guardRect at Create time. See .md for the mirroring logic.
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

/// @function IssueOrderToUnits(_orderName, _units, _context)
/// @description Issues a named order to an array of unit instances. Used by both the player's SelectionController and the AI controller, so both go through the same Order.onIssue callback. Does NOT handle targeting mode -- see .md.
/// @param {String}          _orderName
/// @param {Array<Id.Instance>} _units
/// @param {*}               [_context] Target instance, position, or whatever the order's onIssue expects.
function IssueOrderToUnits(_orderName, _units, _context = undefined) {
    var _order = GetOrder(_orderName);
    if (_order == undefined) {
        show_debug_message($"IssueOrderToUnits: unknown order '{_orderName}'");
        return;
    }
    if (array_length(_units) == 0) return;
    _order.onIssue(_units, _context);
}
