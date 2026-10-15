// Stationing -- live unit <-> invisible garrison entry at the team's castle,
// plus station/deploy economy and passive stationed bonuses. See StationScripts.md.

/// @function CountTeamStationedUnits(_team)
/// @description Total live oUnitStationed belonging to _team, any type. Counts against global.armyLimit -- shared source of truth, see .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Real}
function CountTeamStationedUnits(_team) {
    var _count = 0;
    with (oUnitStationed) {
        if (team == _team) _count++;
    }
    return _count;
}

/// @function CountTeamStationedUnitsOfType(_team, _unitType)
/// @description Counts live oUnitStationed belonging to _team whose preserved unitData.unitType matches _unitType. Stationed counterpart to CountTeamUnitsOfType (TrainingScripts.gml). See .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Asset.GMObject} _unitType e.g. oPeasantUnit.
/// @returns {Real}
function CountTeamStationedUnitsOfType(_team, _unitType) {
    var _count = 0;
    with (oUnitStationed) {
        if (team == _team && unitData.unitType == _unitType) _count++;
    }
    return _count;
}

/// @function StationCastleCorner(_castle)
/// @description Fixed storage point for stationed units at _castle -- the top-left corner of its bbox. Arbitrary -- oUnitStationed never renders. See .md.
/// @param {Id.Instance} _castle
/// @returns {Struct.Vector2}
function StationCastleCorner(_castle) {
    return new Vector2(_castle.bbox_left, _castle.bbox_top);
}

/// @function UnitBecomeStationed(_unit)
/// @description Transforms a live _unit into a stationed one: creates an oUnitStationed at _unit's team's castle corner, hands it _unit's existing UnitDataBlock as-is, then destroys _unit directly (not via ApplyDamage -- see .md re: avoiding a false "lost a unit" XP penalty). Falls back to _unit's current position if the team has no castle.
/// @param {Id.Instance} _unit
function UnitBecomeStationed(_unit) {
    var _castle = GetTeamCastle(_unit.team);
    var _pos    = instance_exists(_castle) ? StationCastleCorner(_castle) : new Vector2(_unit.x, _unit.y);

    var _stationed = instance_create_layer(_pos.x, _pos.y, "Instances", oUnitStationed);
    _stationed.team     = _unit.team;
    _stationed.unitData = _unit.unitData;

    instance_destroy(_unit);
}

/// @function StationSpawnDirectly(_team, _unitType)
/// @description Builds a stationed _unitType unit for _team without ever putting a live unit on the battlefield -- used by TrainingSpawnUnit when a training building sits on an inside plot. Spawns a real instance for a correctly-stamped UnitDataBlock, then immediately hands it to UnitBecomeStationed. Deliberately does NOT award STRATEGIC_XP_FIRST_DEPLOYMENT -- see .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Asset.GMObject} _unitType e.g. oPeasantUnit.
function StationSpawnDirectly(_team, _unitType) {
    var _castle = GetTeamCastle(_team);
    var _pos    = instance_exists(_castle) ? StationCastleCorner(_castle) : new Vector2(0, 0);

    var _unit = instance_create_layer(_pos.x, _pos.y, "Instances", _unitType);
    _unit.team = _team; // overrides oUnitParent's Create-time TEAM.PLAYER default -- same override pattern TrainingSpawnUnit uses

    UnitBecomeStationed(_unit);
}

#macro STATION_DEPLOY_SPAWN_MARGIN 24 // native px outside the castle's front edge a redeployed unit spawns at -- mirrors TrainingGetSpawnPoint's "just outside the building" idea

/// @function GetUnitStationCost(_unitType)
/// @description Wraps UnitDefinition.stationCost into a spendable Cost struct -- shared by the "station" order's affordability pass (OrderWiring.gml) and DeployStationedUnit below, priced identically either direction.
/// @param {Asset.GMObject} _unitType
/// @returns {Struct.Cost}
function GetUnitStationCost(_unitType) {
    var _def = GetUnitDefinition(_unitType);
    return new Cost([ new ResourceCost("gold", _def.stationCost) ]);
}

/// @function StationDeploySpawnPoint(_castle)
/// @description Point just outside _castle's front edge to spawn a redeployed unit at, with random vertical jitter so back-to-back deploys don't stack. Re-derives the front side itself rather than calling CastleFrontEdgePoint -- see .md.
/// @param {Id.Instance} _castle
/// @returns {Struct.Vector2}
function StationDeploySpawnPoint(_castle) {
    var _roomCenterX = room_width / 2;
    var _distLeft     = abs(_castle.bbox_left  - _roomCenterX);
    var _distRight    = abs(_castle.bbox_right - _roomCenterX);
    var _isFrontRight = (_distRight < _distLeft);

    var _edgeX    = _isFrontRight ? _castle.bbox_right : _castle.bbox_left;
    var _outwardX = _edgeX + (_isFrontRight ? STATION_DEPLOY_SPAWN_MARGIN : -STATION_DEPLOY_SPAWN_MARGIN);

    return new Vector2(_outwardX, _castle.y + random_range(-12, 12));
}

/// @function DeployStationedUnit(_team, _unitType)
/// @description Redeploys ONE stationed _unitType unit belonging to _team back onto the battlefield -- the castle garrison dropdown's click-to-deploy action. Charges GetUnitStationCost before anything else happens. Picks whichever matching stationed instance is found first if more than one exists (with-iteration order, not a meaningful priority -- see .md). Re-runs UnitApplyDefinition per the redeploy sequence UnitDataBlock documents; defaults to "guard" (judgment call, see .md).
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Asset.GMObject|Undefined} _unitType Undefined is a safe no-op -- lets CastleGarrisonMenu's "--" placeholder row / an outside click pass through without a separate guard.
/// @returns {Bool} True if a unit was actually deployed.
function DeployStationedUnit(_team, _unitType) {
    if (_unitType == undefined) return false;

    var _stationed = noone;
    with (oUnitStationed) {
        if (team == _team && unitData.unitType == _unitType) {
            _stationed = id;
            break;
        }
    }

    if (!instance_exists(_stationed)) {
        show_debug_message($"DeployStationedUnit: team {_team} has no stationed {object_get_name(_unitType)} to deploy.");
        return false;
    }

    var _castle = GetTeamCastle(_team);
    if (!instance_exists(_castle)) {
        show_debug_message($"DeployStationedUnit: team {_team} has no castle to deploy {object_get_name(_unitType)} from.");
        return false;
    }

    if (!Purchase(GetUnitStationCost(_unitType), _team)) {
        show_debug_message($"DeployStationedUnit: team {_team} can't afford to deploy {object_get_name(_unitType)} ({GetUnitDefinition(_unitType).stationCost}g).");
        return false;
    }

    var _spawnPos = StationDeploySpawnPoint(_castle);
    var _unit = instance_create_layer(_spawnPos.x, _spawnPos.y, "Instances", _unitType);
    _unit.team      = _team; // overrides oUnitParent's Create-time TEAM.PLAYER default
    _unit.guardRect = GetTeamGuardRect(_unit.team); // same stale-guardRect correction TrainingSpawnUnit applies after a post-Create team override

    _unit.unitData = _stationed.unitData; // hands back the preserved struct -- see UnitDataBlock, UnitScripts.gml
    UnitApplyDefinition(_unit); // re-stamp/reapply per the redeploy sequence UnitDataBlock's doc comment specifies

    instance_destroy(_stationed);

    return true;
}

#macro CASTLE_ROAM_SPEED          0.3  // path px per step at matchSpeed 1
#macro CASTLE_ROAM_MAX_DEVIATION  2    // max px a stationed unit strays from the path on each axis
#macro CASTLE_ROAM_OFFSET_EASE    0.02 // per-step lerp factor of the current deviation toward its target
#macro CASTLE_ROAM_WALK_MIN       120  // steps
#macro CASTLE_ROAM_WALK_MAX       420
#macro CASTLE_ROAM_STOP_MIN       90
#macro CASTLE_ROAM_STOP_MAX       300
#macro CASTLE_ROAM_REVERSE_CHANCE 0.25 // chance to turn around when resuming from a stop
#macro CASTLE_ROAM_DEPTH          -450 // default only; Step re-sorts by Y within the band below
#macro CASTLE_ROAM_DEPTH_NEAR     -413 // band top: just under oCastleManager (-412, wall index 0), used for the smallest Y
#macro CASTLE_ROAM_DEPTH_FAR      -479 // band bottom: just above oCastleTopper (-480, index 1), used for the largest Y
#macro CASTLE_ROAM_SORT_MAX_Y     500  // Y at/after which the sort band is fully used
#macro CASTLE_ROAM_FRAME_STEPS    12   // steps per walk-frame swap (0 <-> 1)

/// @function CastleRoamPathPoint(_team, _index)
/// @description World position of pth_CastleRoam point _index for _team's castle. The path is relative to the wall sprite's top-left; the enemy wall is mirrored horizontally.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Real} _index
/// @returns {Struct.Vector2}
function CastleRoamPathPoint(_team, _index) {
    var _castle = GetTeamCastle(_team);
    var _px     = path_get_point_x(pth_CastleRoam, _index);
    var _py     = path_get_point_y(pth_CastleRoam, _index);
    if (!instance_exists(_castle)) return new Vector2(_px, _py);

    var _sprite = (_team == TEAM.PLAYER) ? sCastleWall : sEnemyCastleWall;
    var _left   = _castle.x - sprite_get_xoffset(_sprite);
    var _top    = _castle.y - sprite_get_yoffset(_sprite);
    var _wx     = (_team == TEAM.PLAYER) ? _left + _px : _left + sprite_get_width(_sprite) - _px;
    return new Vector2(_wx, _top + _py);
}

/// @function CastleRoamInit(_stationed)
/// @description Starts a freshly stationed unit's visual roam at a random pth_CastleRoam point, idle. Call after team is set.
/// @param {Id.Instance} _stationed An oUnitStationed.
function CastleRoamInit(_stationed) {
    with (_stationed) {
        var _count = path_get_number(pth_CastleRoam);
        roamDir    = choose(1, -1);
        roamIndex  = irandom(_count - 1); // last point reached
        roamTarget = (roamIndex + roamDir + _count) mod _count;
        var _start = CastleRoamPathPoint(team, roamIndex);
        roamX      = _start.x;
        roamY      = _start.y;
        roamWalking = false;
        roamTimer   = irandom_range(CASTLE_ROAM_STOP_MIN, CASTLE_ROAM_STOP_MAX);
        roamOffX = 0;
        roamOffY = 0;
        roamOffTargetX = 0;
        roamOffTargetY = 0;
        roamFace = (roamX < room_width / 2) ? 1 : -1;
        roamFrame = 0;
        roamFrameTimer = 0;
        roamReady = true;
    }
}

/// @function CastleRoamStep(_stationed)
/// @description Advances one stationed unit's visual roam: alternates walking along pth_CastleRoam (with smoothly drifting deviation) and standing still, and updates facing.
/// @param {Id.Instance} _stationed An oUnitStationed.
function CastleRoamStep(_stationed) {
    with (_stationed) {
        if (!roamReady) CastleRoamInit(id);
        var _dt = global.matchSpeed;
        if (_dt <= 0) return;

        var _centerFace = function(_x) { return (_x <= room_width / 2) ? 1 : -1; };
        roamTimer -= _dt;

        // lower Y draws behind higher Y (lower depth value = drawn later = in front)
        depth = lerp(CASTLE_ROAM_DEPTH_NEAR, CASTLE_ROAM_DEPTH_FAR, clamp((roamY + roamOffY) / CASTLE_ROAM_SORT_MAX_Y, 0, 1));

        if (!roamWalking) {
            roamFrame      = 0;
            roamFrameTimer = 0;
            roamFace = _centerFace(roamX + roamOffX);
            if (roamTimer <= 0) {
                roamWalking = true;
                roamTimer   = irandom_range(CASTLE_ROAM_WALK_MIN, CASTLE_ROAM_WALK_MAX);
                if (random(1) < CASTLE_ROAM_REVERSE_CHANCE) {
                    // stops usually happen mid-segment: turn back toward the point just left, not a diagonal to the one before it
                    roamDir = -roamDir;
                    var _prevIndex = roamIndex;
                    roamIndex  = roamTarget;
                    roamTarget = _prevIndex;
                }
            }
            return;
        }

        roamFrameTimer += _dt;
        if (roamFrameTimer >= CASTLE_ROAM_FRAME_STEPS) {
            roamFrameTimer -= CASTLE_ROAM_FRAME_STEPS;
            roamFrame = 1 - roamFrame;
        }

        // deviation drifts smoothly toward a random target within +/- the max, re-rolled once reached
        roamOffX = lerp(roamOffX, roamOffTargetX, CASTLE_ROAM_OFFSET_EASE * _dt);
        roamOffY = lerp(roamOffY, roamOffTargetY, CASTLE_ROAM_OFFSET_EASE * _dt);
        if (abs(roamOffX - roamOffTargetX) < 0.1 && abs(roamOffY - roamOffTargetY) < 0.1) {
            roamOffTargetX = random_range(-CASTLE_ROAM_MAX_DEVIATION, CASTLE_ROAM_MAX_DEVIATION);
            roamOffTargetY = random_range(-CASTLE_ROAM_MAX_DEVIATION, CASTLE_ROAM_MAX_DEVIATION);
        }

        var _goal = CastleRoamPathPoint(team, roamTarget);
        var _dx   = _goal.x - roamX;
        var _dy   = _goal.y - roamY;
        var _dist = point_distance(0, 0, _dx, _dy);
        var _step = CASTLE_ROAM_SPEED * _dt;

        if (_dist <= _step) {
            roamX = _goal.x;
            roamY = _goal.y;
            roamIndex  = roamTarget;
            roamTarget = (roamIndex + roamDir + path_get_number(pth_CastleRoam)) mod path_get_number(pth_CastleRoam);
        } else {
            roamX += _dx / _dist * _step;
            roamY += _dy / _dist * _step;
        }

        // facing: going up favors the room center; otherwise the horizontal direction of travel (keeps current if purely vertical down)
        if (_dy < 0 && abs(_dy) >= abs(_dx)) {
            roamFace = _centerFace(roamX + roamOffX);
        } else if (abs(_dx) > 0.01) {
            roamFace = sign(_dx);
        }

        if (roamTimer <= 0) {
            roamWalking = false;
            roamTimer   = irandom_range(CASTLE_ROAM_STOP_MIN, CASTLE_ROAM_STOP_MAX);
        }
    }
}

/// @function CastleRoamDraw(_stationed)
/// @description Draws one stationed unit's small sprite at its roam position (feet-anchored, team-recolored for the enemy), frame 0 or 1 per the walk cycle.
/// @param {Id.Instance} _stationed An oUnitStationed.
function CastleRoamDraw(_stationed) {
    with (_stationed) {
        if (!roamReady || unitData == undefined) return;
        var _def = GetUnitDefinition(unitData.unitType);
        if (_def == undefined || _def.smallSprite == undefined) return;
        var _frame = min(roamFrame, sprite_get_number(_def.smallSprite) - 1); // guard single-frame sprites
        PaletteSwapDrawSprite(_def.palette, team, _def.smallSprite, _frame, round(roamX + roamOffX), round(roamY + roamOffY), roamFace);
    }
}

/// @function StationedBonuses()
/// @description Aggregated result of GetStationedPassiveBonuses -- every field is an additive FRACTION (0.05 = +5%), summed across every live oUnitStationed on one team. Field names are exactly "<type>Bonus" for each stationedBonuses type string -- a new type string needs a matching field added here. See .md.
function StationedBonuses() constructor {
    allResourceProductionBonus = 0; // Peasant -- applies to every producing resource building
    goldProductionBonus        = 0; // Bomb Goblin -- gold only, stacks additively with the above
    unitHealthBonus             = 0; // Mud Golem + Soldier share this same pool
    unitDamageBonus              = 0; // Soldier only
    trainingSpeedBonus          = 0; // Knight

    counts = {}; // object_get_name(unitType) -> Real live-stationed count, for the castle hover panel/debugging -- not itself a bonus field
}

/// @function GetStationedPassiveBonuses(_team)
/// @description Scans every live oUnitStationed belonging to _team once and sums their UnitDefinition.stationedBonuses entries into a fresh StationedBonuses -- one linear stack per unit stationed. Recomputed fresh every call, not cached. See .md.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Struct.StationedBonuses}
function GetStationedPassiveBonuses(_team) {
    var _bonuses = new StationedBonuses();

    with (oUnitStationed) {
        if (team != _team) continue;

        var _type = unitData.unitType;
        var _key  = object_get_name(_type);
        _bonuses.counts[$ _key] = (variable_struct_exists(_bonuses.counts, _key) ? _bonuses.counts[$ _key] : 0) + 1;

        var _def = GetUnitDefinition(_type);
        if (_def == undefined) continue;

        for (var i = 0; i < array_length(_def.stationedBonuses); i++) {
            var _entry     = _def.stationedBonuses[i];
            var _fieldName = _entry.type + "Bonus";
            _bonuses[$ _fieldName] += _entry.amount;
        }
    }

    return _bonuses;
}
