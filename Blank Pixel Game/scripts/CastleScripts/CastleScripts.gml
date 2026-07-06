// -----------------------------------------------------------
// CastleScripts -- gives oPlayerCastle/oEnemyCastle real HP, tracked the
// same way as every other damageable thing (maxHealth + damageTaken, via
// GetDamageTaken/SetDamageTaken/GetCurrentHealth, UnitDefinitions.gml, and
// ApplyDamage, UnitCombatHelpers.gml), plus a rolling "no damage taken"
// timer that awards Defensive XP -- 2026-07-06 "XP Age Progression System"
// doc: "No castle damage for 120 secs: +5 XP".
//
// Neither castle object had ANY events before this (both were pure visual
// masks, sCastleWallMask/sEnemyCastleWallMask, invisible, no Create/Step) --
// this is genuinely new infrastructure, not a small wiring tweak.
//
// Correction (2026-07-06, front-edge targeting batch): siege DOES already
// call UnitTryDealDamage directly on the castle instance (UnitStateSiege.gml,
// SWING phase) -- it bypasses the generic "attack" order's oBuildingParent-
// ancestry gate entirely by going straight through GetEnemyCastle(), so the
// castles not being parented to oBuildingParent never mattered for siege
// specifically (only for the player-issued generic "attack Building" order,
// which genuinely can't target a castle). The earlier note here calling
// castles fully untargeted was wrong on that point.
//
// CastleFrontEdgePoint (below) is what siege now approaches instead of the
// generic NearestBuildingEdgePoint (UnitStateAttackMelee.gml) -- see there
// for why: that function assumes every building is 48x48, which castles
// aren't anywhere close to.
// -----------------------------------------------------------

#macro CASTLE_MAX_HEALTH             500  // placeholder -- not sourced from the data sheet, no castle HP number exists yet
#macro CASTLE_NO_DAMAGE_XP_STEPS      7200 // 120 sec * option_game_speed (60fps), at 1x match speed
#macro CASTLE_NO_DAMAGE_XP_AMOUNT     5    // Defensive XP per full CASTLE_NO_DAMAGE_XP_STEPS interval without taking damage

/// @function CastleInit(_instance, _team)
/// @description Call once from a castle's Create event. Sets up the same
///        maxHealth/damageTaken shape every other damageable thing in this
///        project uses (see GetDamageTaken/GetCurrentHealth,
///        UnitDefinitions.gml) plus noDamageTimer, which ApplyDamage
///        (UnitCombatHelpers.gml) generically resets to 0 on any hit.
/// @param {Id.Instance} _instance
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
function CastleInit(_instance, _team) {
    _instance.team          = _team;
    _instance.maxHealth     = CASTLE_MAX_HEALTH;
    _instance.damageTaken   = 0;
    _instance.noDamageTimer = 0; // steps at 1x match speed since the last hit (or since spawn) -- reset by ApplyDamage
}

/// @function CastleStep(_instance)
/// @description Call once per Step from a castle's Step event. Advances
///        noDamageTimer and awards CASTLE_NO_DAMAGE_XP_AMOUNT Defensive XP
///        for every full CASTLE_NO_DAMAGE_XP_STEPS interval reached without
///        interruption -- floor-division against the running timer (same
///        "don't lose progress, handle more than one interval in a single
///        jump" approach GainXP's Fate Token math uses), so this can't
///        under- or over-award if a big matchSpeed step ever crosses more
///        than one interval at once. Does NOT reset after awarding --
///        rolls forward and keeps paying out every subsequent interval for
///        as long as the castle goes untouched, only ever reset back to 0
///        by taking damage (see ApplyDamage).
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
/// @description The nearest point on _castle's FRONT edge to _fromPos --
///        "front" meaning whichever vertical edge of the castle's actual
///        collision box (bbox_left/bbox_right, GameMaker built-ins --
///        already world-space, sprite-mask-accurate, no hardcoded
///        building-size assumption unlike NearestBuildingEdgePoint,
///        UnitStateAttackMelee.gml) sits closer to the room's horizontal
///        center (room_width / 2). This is layout-agnostic on purpose --
///        it doesn't assume "player is on the left" or read _castle.team
///        at all, it just picks whichever side actually faces the middle
///        of the room, so it keeps working even if castle placement ever
///        changes. The X coordinate returned is always exactly that edge
///        (never clamped/blended toward _fromPos -- the front is a single
///        vertical line, not an area); the Y coordinate is _fromPos.y
///        clamped to [bbox_top, bbox_bottom], so a unit approaching from
///        any height along the wall gets a point directly across from it
///        rather than being funneled to one fixed spot -- per 2026-07-06
///        request: "allowing attacks to happen anywhere along its front
///        edge". Used by Siege_Step (UnitStateSiege.gml) in place of
///        NearestBuildingEdgePoint.
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

#macro CASTLE_DEFEND_WAYPOINT_COUNT 6 // how many patrol points to spread along the castle's front wall -- placeholder, not tuned against castle height or expected garrison size

/// @function CastleDefendWaypoints(_castle)
/// @description Patrol waypoints along _castle's front wall, for a unit
///        assigned to defend the castle itself rather than an ordinary
///        oBuildingParent -- added 2026-07-06 for AI castle-under-siege
///        defense (AI_CastleDefense_Step, AIControl.gml). DefendBuildingWaypoints
///        (UnitStateDefend.gml) hardcodes a 4-corner box sized off
///        DEFEND_BUILDING_HALF (24, i.e. a 48x48 building) -- completely wrong
///        for a 350x411 castle, same size-mismatch reason
///        CastleFrontEdgePoint exists instead of NearestBuildingEdgePoint for
///        siege targeting. Reuses the same "front wall" concept as
///        CastleFrontEdgePoint (whichever bbox edge faces the room's
///        horizontal center) but spreads CASTLE_DEFEND_WAYPOINT_COUNT points
///        evenly down its full height instead of a single point, so multiple
///        defenders patrol the whole wall rather than stacking on one spot.
///        Offset outward from the wall by DEFEND_PATROL_MARGIN
///        (UnitStateDefend.gml) -- same margin ordinary building defense
///        uses, referenced directly rather than duplicated.
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
