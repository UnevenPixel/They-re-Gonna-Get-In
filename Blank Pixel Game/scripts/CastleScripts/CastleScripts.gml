// Castle HP tracking (maxHealth/damageTaken, same shape every damageable
// thing uses) + no-damage Defensive XP timer + front-edge/defend-waypoint
// targeting helpers (castles are far larger than NearestBuildingEdgePoint's
// 48x48 assumption). See CastleScripts.md.

#macro CASTLE_MAX_HEALTH             500  // placeholder -- not sourced from the data sheet, no castle HP number exists yet
#macro CASTLE_NO_DAMAGE_XP_STEPS      7200 // 120 sec * option_game_speed (60fps), at 1x match speed
#macro CASTLE_NO_DAMAGE_XP_AMOUNT     5    // Defensive XP per full CASTLE_NO_DAMAGE_XP_STEPS interval without taking damage

/// @function CastleInit(_instance, _team)
/// @description Call once from a castle's Create event. Sets up maxHealth/damageTaken (same shape every damageable thing uses) plus noDamageTimer, which ApplyDamage resets to 0 on any hit.
/// @param {Id.Instance} _instance
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
function CastleInit(_instance, _team) {
    _instance.team          = _team;
    _instance.maxHealth     = CASTLE_MAX_HEALTH;
    _instance.damageTaken   = 0;
    _instance.noDamageTimer = 0; // steps at 1x match speed since the last hit (or since spawn) -- reset by ApplyDamage
}

/// @function CastleStep(_instance)
/// @description Call once per Step. Advances noDamageTimer and awards CASTLE_NO_DAMAGE_XP_AMOUNT Defensive XP for every full CASTLE_NO_DAMAGE_XP_STEPS interval reached without interruption. Rolls forward indefinitely, only reset by taking damage. See .md.
/// @param {Id.Instance} _instance
function CastleStep(_instance) {
    var _before = _instance.noDamageTimer;
    var _after  = _before + global.matchSpeed;
    _instance.noDamageTimer = _after;

    var _intervalsEarned = floor(_after / CASTLE_NO_DAMAGE_XP_STEPS) - floor(_before / CASTLE_NO_DAMAGE_XP_STEPS);
    if (_intervalsEarned > 0) {
        GainXP(_instance.team, CASTLE_NO_DAMAGE_XP_AMOUNT * _intervalsEarned);
    }
}

/// @function CastleFrontEdgePoint(_castle, _fromPos)
/// @description The nearest point on _castle's FRONT edge to _fromPos -- whichever bbox edge sits closer to the room's horizontal center. Layout-agnostic (doesn't read _castle.team). Y is clamped to the wall's height. Used by Siege_Step in place of NearestBuildingEdgePoint. See .md.
/// @param {Id.Instance}    _castle
/// @param {Struct.Vector2} _fromPos
/// @returns {Struct.Vector2}
function CastleFrontEdgePoint(_castle, _fromPos) {
    var _roomCenterX = room_width / 2;
    var _distLeft    = abs(_castle.bbox_left  - _roomCenterX);
    var _distRight   = abs(_castle.bbox_right - _roomCenterX);
    var _frontX      = (_distLeft < _distRight) ? _castle.bbox_left : _castle.bbox_right;

    var _clampedY = clamp(_fromPos.y, _castle.bbox_top, _castle.bbox_bottom);
    return new Vector2(_frontX, _clampedY);
}

#macro CASTLE_DEFEND_WAYPOINT_COUNT 6 // patrol points spread along the castle's front wall -- placeholder, not tuned against castle height or garrison size

/// @function CastleDefendWaypoints(_castle)
/// @description Patrol waypoints along _castle's front wall, for a unit defending the castle itself rather than an ordinary building -- DefendBuildingWaypoints' 48x48-sized box is wrong for a 350x411 castle. Spreads CASTLE_DEFEND_WAYPOINT_COUNT points down the full wall height, offset by DEFEND_PATROL_MARGIN. See .md.
/// @param {Id.Instance} _castle
/// @returns {Array<Struct.Vector2>}
function CastleDefendWaypoints(_castle) {
    var _roomCenterX = room_width / 2;
    var _distLeft    = abs(_castle.bbox_left  - _roomCenterX);
    var _distRight   = abs(_castle.bbox_right - _roomCenterX);
    var _onLeftSide  = _distLeft < _distRight;
    var _frontX      = _onLeftSide ? _castle.bbox_left  : _castle.bbox_right;
    var _outwardX    = _onLeftSide ? (_frontX - DEFEND_PATROL_MARGIN) : (_frontX + DEFEND_PATROL_MARGIN);

    var _waypoints = [];
    for (var i = 0; i < CASTLE_DEFEND_WAYPOINT_COUNT; i++) {
        var _t = (CASTLE_DEFEND_WAYPOINT_COUNT > 1) ? (i / (CASTLE_DEFEND_WAYPOINT_COUNT - 1)) : 0.5;
        var _y = lerp(_castle.bbox_top, _castle.bbox_bottom, _t);
        array_push(_waypoints, new Vector2(_outwardX, _y));
    }
    return _waypoints;
}
