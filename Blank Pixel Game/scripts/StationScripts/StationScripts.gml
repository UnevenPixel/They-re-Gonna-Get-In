// -----------------------------------------------------------
// Stationing -- turning a live unit into an invisible, no-fsm garrison
// entry stored at its team's castle, and creating one directly (skipping
// the live/walk-to-castle step entirely) for training buildings placed on
// an inside plot. See UnitStateStation.gml for the "station" order's
// walk-to-castle FSM state that calls UnitBecomeStationed on arrival.
// -----------------------------------------------------------

/// @function StationCastleCorner(_castle)
/// @description Fixed storage point for stationed units at _castle -- the
///        top-left corner of its bbox. Arbitrary: oUnitStationed has no
///        sprite and never renders (see that object), so the exact position
///        only matters as a stable spawn point if/when a future redeploy
///        feature creates a live unit back out from here.
/// @param {Id.Instance} _castle
/// @returns {Struct.Vector2}
function StationCastleCorner(_castle) {
    return new Vector2(_castle.bbox_left, _castle.bbox_top);
}

/// @function UnitBecomeStationed(_unit)
/// @description Transforms a live _unit into a stationed one: creates an
///        oUnitStationed at _unit's team's castle corner (StationCastleCorner),
///        hands it _unit's existing UnitDataBlock as-is (preserving
///        damageTaken/statusEffects/unitType -- see UnitDataBlock,
///        UnitScripts.gml), then destroys _unit directly.
///
///        Destroying directly (not through ApplyDamage) is deliberate --
///        STRATEGIC_XP_LOSE_UNIT (UnitCombatHelpers.gml) is only awarded
///        from ApplyDamage, and oUnitParent has no Destroy event, so this
///        cannot misfire a "lost a unit" penalty for what is actually a
///        successful station.
///
///        If _unit's team has no castle on the board (shouldn't normally
///        happen -- Station_Enter already falls back to "guard" when that's
///        true), falls back to _unit's current position instead of crashing.
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
/// @description Builds a stationed _unitType unit for _team without ever
///        putting a live unit on the battlefield -- used by TrainingSpawnUnit
///        (TrainingScripts.gml) when the training building sits on an inside
///        plot, per the 2026-07-11 request: "Any training buildings that
///        builds a unit when on an inside plot will immediately build a
///        stationed unit instead."
///
///        Spawns a real _unitType instance just to get a correctly
///        UnitApplyDefinition-stamped UnitDataBlock (unitType, etc.), then
///        immediately hands it to UnitBecomeStationed, which destroys it in
///        the same step before it ever runs a Step or Draw event -- so
///        nothing is visible on the battlefield at any point, matching "no
///        rendering."
///
///        Deliberately does NOT award STRATEGIC_XP_FIRST_DEPLOYMENT
///        (TrainingScripts.gml) -- that XP is for a unit's first appearance
///        ON the battlefield, which a directly-stationed unit never has.
///        Flagging this as a judgment call, not an explicit spec answer.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Asset.GMObject} _unitType e.g. oPeasantUnit.
function StationSpawnDirectly(_team, _unitType) {
    var _castle = GetTeamCastle(_team);
    var _pos    = instance_exists(_castle) ? StationCastleCorner(_castle) : new Vector2(0, 0);

    var _unit = instance_create_layer(_pos.x, _pos.y, "Instances", _unitType);
    _unit.team = _team; // overrides oUnitParent's Create-time TEAM.PLAYER default -- same override pattern TrainingSpawnUnit uses

    UnitBecomeStationed(_unit);
}

// -----------------------------------------------------------
// Station/deploy economy -- 2026-07-12 request. UnitDefinition.stationCost
// (UnitDefinitions.gml, a flat gold amount from the "Project Azurite Data
// Sheets") already existed as display-only data for the unit hover card;
// this is what makes it actually spend. Same price both directions, per
// its own doc comment ("Gold cost to station/deploy this unit type").
// -----------------------------------------------------------

#macro STATION_DEPLOY_SPAWN_MARGIN 24 // native px outside the castle's front edge a redeployed unit spawns at -- mirrors TrainingGetSpawnPoint's "just outside the building" idea (TrainingScripts.gml)

/// @function GetUnitStationCost(_unitType)
/// @description Wraps UnitDefinition.stationCost into a spendable Cost
///        struct (Economy.gml) -- shared by both the "station" order's
///        affordability pass (OrderWiring.gml) and DeployStationedUnit
///        below, since the field is priced identically either direction.
/// @param {Asset.GMObject} _unitType
/// @returns {Struct.Cost}
function GetUnitStationCost(_unitType) {
    var _def = GetUnitDefinition(_unitType);
    return new Cost([ new ResourceCost("gold", _def.stationCost) ]);
}

/// @function StationDeploySpawnPoint(_castle)
/// @description Point just outside _castle's FRONT edge (same side
///        CastleFrontEdgePoint, CastleScripts.gml, picks -- whichever of
///        bbox_left/bbox_right actually faces the room's center) to spawn a
///        redeployed unit at, with a small random vertical jitter so
///        back-to-back deploys don't land stacked (mirrors
///        TrainingGetSpawnPoint's spacing reasoning, TrainingScripts.gml).
///        Re-derives the front side itself rather than calling
///        CastleFrontEdgePoint -- that function clamps toward a caller
///        position (there's no unit marching toward the castle here, just
///        a castle to spawn just outside of), and doesn't expose which
///        side it picked for the "push further outward" math below to reuse.
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
/// @description Redeploys ONE stationed _unitType unit belonging to _team
///        back onto the battlefield -- the castle garrison dropdown's
///        click-to-deploy action (CastleGarrisonMenu.gml), 2026-07-12
///        request. Charges GetUnitStationCost via Purchase BEFORE anything
///        else happens, so an unaffordable deploy is a pure no-op (nothing
///        destroyed, nothing spent, nothing spawned).
///
///        Picks whichever live oUnitStationed instance of this type is
///        found first if more than one is garrisoned -- GameMaker's `with`
///        iteration order isn't a meaningful "oldest"/"healthiest" pick,
///        just "any one of them." Flagging since a request that cares
///        WHICH specific one (e.g. always the least-damaged) would need a
///        different selection rule.
///
///        Creates a fresh _unitType instance just outside the team's
///        castle (StationDeploySpawnPoint), overrides its team (same
///        override pattern TrainingSpawnUnit/StationSpawnDirectly use),
///        then swaps in the STATIONED unit's preserved UnitDataBlock
///        (damageTaken/statusEffects/unitType) and re-runs
///        UnitApplyDefinition -- the exact redeploy sequence already
///        documented on UnitDataBlock (UnitScripts.gml). Defaults to
///        "guard" -- the fsm's own built-in starting state, untouched here
///        -- since a deployed unit has no training-building context to
///        default to "defend" against like TrainingSpawnUnit's units do;
///        flagging as a judgment call, not an explicit spec answer.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @param {Asset.GMObject|Undefined} _unitType Undefined is a safe no-op --
///        lets CastleGarrisonMenu's "--" placeholder row / an outside click
///        pass straight through without a separate guard at the call site.
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
    _unit.team      = _team; // overrides oUnitParent's Create-time TEAM.PLAYER default -- same override pattern TrainingSpawnUnit/StationSpawnDirectly use
    _unit.guardRect = GetTeamGuardRect(_unit.team); // same stale-guardRect correction TrainingSpawnUnit applies after a post-Create team override

    _unit.unitData = _stationed.unitData; // hands back the preserved struct (damageTaken/statusEffects/unitType) -- see UnitDataBlock, UnitScripts.gml
    UnitApplyDefinition(_unit); // re-stamp/reapply per the redeploy sequence UnitDataBlock's doc comment already specifies

    instance_destroy(_stationed);

    return true;
}

// -----------------------------------------------------------
// Passive stationed bonuses -- 2026-07-12 request. Every registered unit's
// "Stationed Effect" passive (UnitDefinitions.gml) was flavor-text-only
// until now; UnitDefinition.stationedBonuses is the real, structured
// counterpart, and GetStationedPassiveBonuses below is what every
// consumer (production rate, training speed, unit HP/damage at spawn)
// actually calls. Archer's "Ranged attacks from the wall" is deliberately
// NOT represented -- see stationedBonuses' own doc comment
// (UnitDefinitions.gml) for why (a real combat mechanic, not a
// multiplier -- out of scope this pass per user clarification).
//
// IMPORTANT scope note, flagged rather than silently assumed: HP/damage
// bonuses (unitHealthBonus/unitDamageBonus) are applied ONCE, at a unit's
// spawn/redeploy moment (UnitApplyDefinition, UnitDefinitions.gml) -- NOT
// dynamically re-applied to every already-live unit the instant a new
// Mud Golem/Soldier gets stationed, and not removed retroactively if that
// unit is later deployed back out. Doing this fully dynamically would mean
// tracking each unit's BASE stats separately from its EFFECTIVE stats and
// recomputing every live unit's HP/damage on every station/deploy change --
// a real systemic change to how combat health is tracked, not something
// to fold in silently under a "passive bonuses" request. This pass keeps
// the simpler "current team bonus baked in at spawn time" behavior, same
// spirit as stationCost's own incremental rollout.
// -----------------------------------------------------------

/// @function StationedBonuses()
/// @description Aggregated result of GetStationedPassiveBonuses -- every
///        field is an additive FRACTION (0.05 = +5%), summed across every
///        live oUnitStationed instance on one team that has a matching
///        stationedBonuses entry. Field names are exactly
///        "<type>Bonus" for each stationedBonuses type string
///        (UnitDefinition's doc comment) -- GetStationedPassiveBonuses
///        writes to them via dynamic struct access, so a new type string
///        needs a matching field added here too.
function StationedBonuses() constructor {
    allResourceProductionBonus = 0; // Peasant -- applies to every producing resource building
    goldProductionBonus        = 0; // Bomb Goblin -- gold only, stacks additively with the above
    unitHealthBonus             = 0; // Mud Golem + Soldier share this same pool
    unitDamageBonus              = 0; // Soldier only
    trainingSpeedBonus          = 0; // Knight

    counts = {}; // object_get_name(unitType) -> Real live-stationed count, for the castle hover panel/debugging -- not itself a bonus field
}

/// @function GetStationedPassiveBonuses(_team)
/// @description Scans every live oUnitStationed belonging to _team once and
///        sums their UnitDefinition.stationedBonuses entries into a fresh
///        Struct.StationedBonuses -- one linear stack per unit stationed,
///        matching each passive's own "(stacks per X stationed)" wording.
///        Recomputed fresh every call, not cached anywhere -- same
///        "simplicity over micro-optimization" convention as
///        TrainingTypeLimit (TrainingScripts.gml); called at most once per
///        producing/training building per Step and once per unit spawn,
///        which is a small enough oUnitStationed count on this game's
///        scale not to need a cached/dirty-flag layer.
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
