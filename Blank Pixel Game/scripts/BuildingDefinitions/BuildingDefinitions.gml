// -----------------------------------------------------------
// BuildingDefinition -- static, per-building-TYPE metadata (name,
// description, cost, sprite, resource production) used by the Blueprint UI
// to display a building's icon/cost and run the affordability check on
// placement, and by BuildingApplyDefinition below to set up per-instance
// production state at Create time.
//
// Unlike UnitDefinition (UnitDefinitions.gml), most of this is NOT applied
// onto a shared generic instance -- every building type gets its own
// dedicated object (e.g. oWheatField), so there's no "generic
// oBuildingParent instance that needs its stats filled in at runtime" the
// way oPeasantUnit needs UnitApplyDefinition. Production fields are the
// exception -- see BuildingApplyDefinition/BuildingUpdateProduction below.
// -----------------------------------------------------------

/// @function BuildingDefinition(_data)
/// @description Static definition for one building type.
/// @param {Struct} _data Fields:
///        name               {String}         Display name, e.g. "Wheat Field".
///        description        {String}         Flavor/tooltip text.
///        cost               {Struct.Cost}    Production cost (see Economy.gml).
///        sprite             {Asset.GMSprite} Icon drawn in the Blueprint UI slot.
///        productionResource {String}         [optional] Key into the
///               global.resources team struct, e.g. "wheat". Omit for
///               buildings that don't produce anything (e.g. training
///               buildings) -- defaults to undefined/no production.
///        productionRate     {Real}           [optional] Units per second
///               at 1x match speed. Defaults to 0 (no production).
///        trainsUnit         {Asset.GMObject} [optional] Unit type this
///               building trains, e.g. oPeasantUnit. Omit for buildings
///               that don't train anything (e.g. resource buildings) --
///               defaults to undefined/no training.
///        unitsPerBuilding   {Real}           [optional] How many
///               trainsUnit-type units ONE live instance of this building
///               contributes to the team's per-type unit cap (see
///               TrainingTypeLimit in TrainingScripts.gml). Defaults to 0.
///        trainCost          {Struct.Cost}    [optional] Cost paid per
///               unit queued (separate from this building's own placement
///               cost). Required if trainsUnit is set.
///        trainTime          {Real}           [optional] Seconds to train
///               one unit at 1x match speed. Defaults to 0.
///        maxHealth          {Real}           [optional] Building HP -- see
///               ApplyDamage/GetCurrentHealth (UnitCombatHelpers.gml /
///               UnitDefinitions.gml), which now work against buildings the
///               same way they work against units. Defaults to 200 (an
///               unbalanced placeholder, same status every cost/rate number
///               in this file already had -- there's no sheet-sourced
///               building HP yet).
function BuildingDefinition(_data) constructor {
    name        = _data.name;
    description = _data.description;
    cost        = _data.cost;
    sprite      = _data.sprite;

    productionResource = variable_struct_exists(_data, "productionResource") ? _data.productionResource : undefined;
    productionRate      = variable_struct_exists(_data, "productionRate")     ? _data.productionRate     : 0;

    trainsUnit       = variable_struct_exists(_data, "trainsUnit")       ? _data.trainsUnit       : undefined;
    unitsPerBuilding = variable_struct_exists(_data, "unitsPerBuilding") ? _data.unitsPerBuilding : 0;
    trainCost        = variable_struct_exists(_data, "trainCost")        ? _data.trainCost        : undefined;
    trainTime        = variable_struct_exists(_data, "trainTime")        ? _data.trainTime        : 0;

    maxHealth = variable_struct_exists(_data, "maxHealth") ? _data.maxHealth : 200;
}

// -----------------------------------------------------------
// Registry -- keyed by object_index (e.g. oWheatField), mirroring
// UnitDefinitions' registry (see UnitDefinitions.gml for the reasoning).
// -----------------------------------------------------------

global.__buildingDefRegistry = ds_map_create();

/// @function RegisterBuildingDefinition(_objectIndex, _definition)
/// @param {Asset.GMObject} _objectIndex
/// @param {Struct.BuildingDefinition} _definition
function RegisterBuildingDefinition(_objectIndex, _definition) {
    ds_map_set(global.__buildingDefRegistry, _objectIndex, _definition);
}

/// @function GetBuildingDefinition(_objectIndex)
/// @param {Asset.GMObject} _objectIndex
/// @returns {Struct.BuildingDefinition|Undefined}
function GetBuildingDefinition(_objectIndex) {
    return ds_map_exists(global.__buildingDefRegistry, _objectIndex)
        ? global.__buildingDefRegistry[? _objectIndex]
        : undefined;
}

// -----------------------------------------------------------
// Definition registration (call once, e.g. a game-start script) --
// mirrors RegisterAllUnitDefinitions() in UnitDefinitions.gml.
// -----------------------------------------------------------

/// @function RegisterAllBuildingDefinitions()
/// @description Registers every building type's BuildingDefinition. Call
///        once at game start, alongside RegisterAllUnitDefinitions() --
///        wired from oGameControl's Create event.
function RegisterAllBuildingDefinitions() {
    // NOTE: cost/rate/maxHealth are placeholders, not balanced values -- tune freely.
    RegisterBuildingDefinition(oWheatField, new BuildingDefinition({
        name:               "Wheat Field",
        description:        "A basic resource plot that produces wheat over time.",
        // Was 15 wood + 10 coins (pre-dated the sheet's "Wheat Farm" row
        // being consulted for this exact building) -- corrected 2026-07-05
        // to the real sheet-sourced cost, same as the other 4 resource
        // buildings below.
        cost:               new Cost([new ResourceCost("water", 20), new ResourceCost("wood", 10)]),
        sprite:              sWheatField,
        productionResource: "wheat",
        productionRate:      1, // 1 wheat/sec at 1x match speed
        maxHealth:           150,
    }));

    RegisterBuildingDefinition(oPeasantWard, new BuildingDefinition({
        name:             "Peasant Ward",
        description:      "Trains peasants. Each Ward supports up to 4 peasants at once.",
        cost:             new Cost([new ResourceCost("wheat", 40), new ResourceCost("water", 40)]),
        sprite:            sPeasantWard,
        trainsUnit:       oPeasantUnit,
        unitsPerBuilding: 4,
        trainCost:        new Cost([new ResourceCost("water", 20)]),
        trainTime:        10, // seconds per unit at 1x match speed
        maxHealth:        200,
    }));

    // NOTE: build cost + trainsUnit/unitsPerBuilding/trainCost/trainTime
    // below are sourced from the data sheet's Item Costs sheet (build cost)
    // and Unit Stats sheet (everything else) -- these are real values, not
    // placeholders, same status as Peasant Ward above. maxHealth is NOT
    // sheet-sourced (the sheet has no building-HP column) -- still a
    // placeholder like Peasant Ward's.
    RegisterBuildingDefinition(oBoomHut, new BuildingDefinition({
        name:             "Boom Hut",
        description:      "Trains Bomb Goblins. Each Hut supports up to 3 at once.",
        cost:             new Cost([new ResourceCost("gold", 80)]),
        sprite:            sBoomHut,
        trainsUnit:       oBombGoblinUnit,
        unitsPerBuilding: 3,
        trainCost:        new Cost([new ResourceCost("gold", 8)]),
        trainTime:        8,
        maxHealth:        200,
    }));

    RegisterBuildingDefinition(oBogFoundry, new BuildingDefinition({
        name:             "Bog Foundry",
        description:      "Trains Mud Golems. Each Foundry supports up to 1 at once.",
        cost:             new Cost([new ResourceCost("water", 100)]),
        sprite:            sBogFoundry,
        trainsUnit:       oMudGolemUnit,
        unitsPerBuilding: 1,
        trainCost:        new Cost([new ResourceCost("water", 40)]),
        trainTime:        15,
        maxHealth:        250,
    }));

    RegisterBuildingDefinition(oBarracks, new BuildingDefinition({
        name:             "Barracks",
        description:      "Trains Soldiers. Each Barracks supports up to 4 at once.",
        cost:             new Cost([new ResourceCost("wheat", 100), new ResourceCost("gold", 25), new ResourceCost("iron", 50)]),
        sprite:            sBarracks,
        trainsUnit:       oSoldierUnit,
        unitsPerBuilding: 4,
        trainCost:        new Cost([new ResourceCost("wheat", 25), new ResourceCost("wood", 25), new ResourceCost("iron", 25)]),
        trainTime:        15,
        maxHealth:        220,
    }));

    RegisterBuildingDefinition(oArcheryRange, new BuildingDefinition({
        name:             "Archery Range",
        description:      "Trains Archers. Each Range supports up to 3 at once.",
        cost:             new Cost([new ResourceCost("wheat", 50), new ResourceCost("wood", 50)]),
        sprite:            sArcheryRange,
        trainsUnit:       oArcherUnit,
        unitsPerBuilding: 3,
        trainCost:        new Cost([new ResourceCost("wheat", 50), new ResourceCost("gold", 25), new ResourceCost("wood", 25)]),
        trainTime:        10,
        maxHealth:        180,
    }));

    RegisterBuildingDefinition(oRoundTable, new BuildingDefinition({
        name:             "Round Table",
        description:      "Trains Knights. Each Round Table supports up to 3 at once.",
        cost:             new Cost([new ResourceCost("wheat", 70), new ResourceCost("iron", 70)]),
        sprite:            sRoundTable,
        trainsUnit:       oKnightUnit,
        unitsPerBuilding: 3,
        trainCost:        new Cost([new ResourceCost("wheat", 100), new ResourceCost("gold", 25), new ResourceCost("iron", 50)]),
        trainTime:        20,
        maxHealth:        220,
    }));

    // Remaining 4 tier-1 resource buildings -- cost + production rate are
    // real, sheet-sourced values (Item Costs sheet, "Production Buildings"
    // section), same status as Wheat Field's numbers above. maxHealth is
    // NOT sheet-sourced (no building-HP column exists) -- placeholder,
    // matching Wheat Field's 150 since these are the same tier/category.
    RegisterBuildingDefinition(oWaterPump, new BuildingDefinition({
        name:               "Water Pump",
        description:        "A basic resource plot that produces water over time.",
        cost:               new Cost([new ResourceCost("wood", 20)]),
        sprite:              sWaterPump,
        productionResource: "water",
        productionRate:      1, // 1 water/sec at 1x match speed
        maxHealth:           150,
    }));

    RegisterBuildingDefinition(oSawmill, new BuildingDefinition({
        name:               "Sawmill",
        description:        "A basic resource plot that produces wood over time.",
        cost:               new Cost([new ResourceCost("water", 40)]),
        sprite:              sSawmill,
        productionResource: "wood",
        productionRate:      1, // 1 wood/sec at 1x match speed
        maxHealth:           150,
    }));

    RegisterBuildingDefinition(oGoldMine, new BuildingDefinition({
        name:               "Gold Mine",
        description:        "A basic resource plot that produces gold over time.",
        cost:               new Cost([new ResourceCost("water", 70), new ResourceCost("iron", 30)]),
        sprite:              sGoldMine,
        productionResource: "gold",
        productionRate:      1, // 1 gold/sec at 1x match speed
        maxHealth:           150,
    }));

    RegisterBuildingDefinition(oIronMine, new BuildingDefinition({
        name:               "Iron Mine",
        description:        "A basic resource plot that produces iron over time.",
        cost:               new Cost([new ResourceCost("water", 30), new ResourceCost("wood", 60)]),
        sprite:              sIronMine,
        productionResource: "iron",
        productionRate:      1, // 1 iron/sec at 1x match speed
        maxHealth:           150,
    }));
}

// -----------------------------------------------------------
// Per-instance application + production tick -- mirrors
// UnitApplyDefinition's role in UnitDefinitions.gml, but scoped to just
// the fields that actually vary at runtime (production state). Everything
// else (sprite, collision, team/radius) already comes from the building's
// own dedicated object, so there's nothing else to copy here.
// -----------------------------------------------------------

/// @function BuildingApplyDefinition(_building)
/// @description Looks up _building's BuildingDefinition by object_index and
///        sets up its per-instance runtime state -- production fields
///        (resource buildings) AND training fields (training buildings)
///        are both set unconditionally, regardless of which kind of
///        building this is; a resource building simply gets trainsUnit ==
///        undefined / trainQueue == 0, which TrainingUpdateQueue treats as
///        a no-op, and a training building gets productionRate == 0,
///        which BuildingUpdateProduction already treats as a no-op. Call
///        once from a building's Create event, after event_inherited()
///        (team/radius) and after RegisterAllBuildingDefinitions() has run
///        at game start. Logs and no-ops if no definition is registered
///        for this object type.
/// @param {Id.Instance} _building
function BuildingApplyDefinition(_building) {
    var _def = GetBuildingDefinition(_building.object_index);
    if (_def == undefined) {
        show_debug_message($"BuildingApplyDefinition: no BuildingDefinition registered for {object_get_name(_building.object_index)}. Check RegisterAllBuildingDefinitions().");
        return;
    }

    _building.productionResource    = _def.productionResource;
    _building.productionRate        = _def.productionRate;
    _building.productionAccumulator = 0; // fractional progress toward the next whole unit -- see BuildingUpdateProduction

    _building.trainsUnit       = _def.trainsUnit;
    _building.unitsPerBuilding = _def.unitsPerBuilding;
    _building.trainCost        = _def.trainCost;
    _building.trainTime        = _def.trainTime;
    _building.trainQueue       = 0; // units waiting to be trained -- see TrainingTryQueueUnit
    _building.trainProgress    = 0; // seconds accumulated toward the next completion -- see TrainingUpdateQueue

    // Same maxHealth/damageTaken pair units carry (UnitApplyDefinition,
    // UnitDefinitions.gml) -- damageTaken lives directly on the instance
    // here rather than nested in a unitData-style wrapper, since buildings
    // have no station/redeploy concept to preserve it across. ApplyDamage/
    // GetCurrentHealth (UnitCombatHelpers.gml / UnitDefinitions.gml) read
    // damageTaken via GetDamageTaken, which already knows to check for
    // unitData first and fall back to this flat field -- see that function.
    _building.maxHealth   = _def.maxHealth;
    _building.damageTaken = 0;
}

/// @function BuildingUpdateProduction(_building)
/// @description Delta-time-based resource production, scaled by
///        global.matchSpeed. Accumulates fractional progress on the
///        instance (productionAccumulator) instead of adding a flat amount
///        per frame, so production is frame-rate independent and never
///        caps at "at most one whole unit per frame" -- a rate high enough
///        to cross several whole units within a single frame (e.g. from
///        stacked bonuses, or a slow frame) still awards all of them, each
///        triggering its own PlayResourceProducedEffect call, since
///        resources are whole-integer-only in this game (see Economy.gml).
///        No-op if the building has no production (productionRate <= 0).
///        Call once per Step from a producing building (currently wired
///        from oResourceBuildingParent/Step_0.gml, so every resource
///        building gets this automatically).
/// @param {Id.Instance} _building
function BuildingUpdateProduction(_building) {
    if (_building.productionRate <= 0 || _building.productionResource == undefined) return;

    var _dt = delta_time / 1000000; // microseconds -> seconds, same idiom as oOpeningCredits/Step_0.gml
    _building.productionAccumulator += _building.productionRate * global.matchSpeed * _dt;

    var _wholeUnits = floor(_building.productionAccumulator);
    if (_wholeUnits <= 0) return;

    _building.productionAccumulator -= _wholeUnits;

    var _resources = global.resources[_building.team];
    var _current    = struct_get(_resources, _building.productionResource);
    struct_set(_resources, _building.productionResource, _current + _wholeUnits);

    AnalyticsRecordResourceProduced(_building.team, _building.productionResource, _wholeUnits);

    repeat (_wholeUnits) {
        PlayResourceProducedEffect(_building, _building.productionResource);
    }
}

/// @function PlayResourceProducedEffect(_building, _resource)
/// @description Called exactly once per whole unit of resource produced
///        (BuildingUpdateProduction may call this more than once in a
///        single frame at high production rates -- each call gets its own
///        particle burst). Spawns the resource-produced particle burst
///        (SpawnResourceProducedParticles, ResourceParticleScripts.gml) at
///        _building's position -- no sound/popup text yet, just the
///        particles requested 2026-07-05.
/// @param {Id.Instance} _building
/// @param {String} _resource
function PlayResourceProducedEffect(_building, _resource) {
    SpawnResourceProducedParticles(_building, _resource);
}
