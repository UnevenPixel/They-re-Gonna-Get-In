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
    // NOTE: cost/rate are placeholders, not balanced values -- tune freely.
    RegisterBuildingDefinition(oWheatField, new BuildingDefinition({
        name:               "Wheat Field",
        description:        "A basic resource plot that produces wheat over time.",
        cost:               new Cost([new ResourceCost("wood", 15), new ResourceCost("coins", 10)]),
        sprite:              sWheatField,
        productionResource: "wheat",
        productionRate:      1, // 1 wheat/sec at 1x match speed
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
/// @description STUB -- called exactly once per whole unit of resource
///        produced (BuildingUpdateProduction may call this more than once
///        in a single frame at high production rates). Replace with the
///        real particle/sound/popup effect; for now just logs, so
///        production is verifiable without real art/audio yet.
/// @param {Id.Instance} _building
/// @param {String} _resource
function PlayResourceProducedEffect(_building, _resource) {
    show_debug_message($"+1 {_resource} produced by {object_get_name(_building.object_index)} ({_building}).");
}
