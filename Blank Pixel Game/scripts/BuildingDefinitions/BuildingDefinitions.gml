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
        cost:               new Cost([new ResourceCost("wood", 15), new ResourceCost("coins", 10)]),
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

    RegisterBuildingDefinition(oBarracks, ne