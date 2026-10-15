// Static per-building-TYPE metadata (cost/sprite/production/training) plus
// per-instance production/training setup and the production tick. See
// BuildingDefinitions.md.

/// @function BuildingDefinition(_data)
/// @description Static definition for one building type. See .md for the full field reference.
/// @param {Struct} _data name/description/cost/sprite required; productionResource/productionRate/trainsUnit/unitsPerBuilding/trainCost/trainTime/maxHealth/resourceLimit/hitParticleColorDark/hitParticleColorBright optional.
function BuildingDefinition(_data) constructor {
    name        = _data.name;
    description = _data.description;
    cost        = _data.cost;
    sprite      = _data.sprite;

    productionResource = variable_struct_exists(_data, "productionResource") ? _data.productionResource : undefined;
    productionRate      = variable_struct_exists(_data, "productionRate")     ? _data.productionRate     : 0;
    resourceLimit       = variable_struct_exists(_data, "resourceLimit")      ? _data.resourceLimit      : undefined;

    trainsUnit       = variable_struct_exists(_data, "trainsUnit")       ? _data.trainsUnit       : undefined;
    unitsPerBuilding = variable_struct_exists(_data, "unitsPerBuilding") ? _data.unitsPerBuilding : 0;
    trainCost        = variable_struct_exists(_data, "trainCost")        ? _data.trainCost        : undefined;
    trainTime        = variable_struct_exists(_data, "trainTime")        ? _data.trainTime        : 0;

    maxHealth = variable_struct_exists(_data, "maxHealth") ? _data.maxHealth : 200;

    hitParticleColorDark   = variable_struct_exists(_data, "hitParticleColorDark")   ? _data.hitParticleColorDark   : undefined;
    hitParticleColorBright = variable_struct_exists(_data, "hitParticleColorBright") ? _data.hitParticleColorBright : undefined;
}

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

/// @function RegisterAllBuildingDefinitions()
/// @description Registers every building type's BuildingDefinition. Call once at game start, alongside RegisterAllUnitDefinitions() -- wired from oGameControl's Create event. See .md for cost/rate data-provenance notes.
function RegisterAllBuildingDefinitions() {
    RegisterBuildingDefinition(oWheatField, new BuildingDefinition({
        name:               "Wheat Field",
        description:        "A basic resource plot that produces wheat over time.",
        cost:               new Cost([new ResourceCost("water", 20), new ResourceCost("wood", 10)]),
        sprite:              sWheatField,
        productionResource: "wheat",
        productionRate:      1, // 1 wheat/sec at 1x match speed
        resourceLimit:       300,
        maxHealth:           100,
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

    RegisterBuildingDefinition(oWaterPump, new BuildingDefinition({
        name:               "Water Pump",
        description:        "A basic resource plot that produces water over time.",
        cost:               new Cost([new ResourceCost("wood", 20)]),
        sprite:              sWaterPump,
        productionResource: "water",
        productionRate:      1, // 1 water/sec at 1x match speed
        resourceLimit:       300,
        maxHealth:           100,
    }));

    RegisterBuildingDefinition(oSawmill, new BuildingDefinition({
        name:               "Sawmill",
        description:        "A basic resource plot that produces wood over time.",
        cost:               new Cost([new ResourceCost("water", 40)]),
        sprite:              sSawmill,
        productionResource: "wood",
        productionRate:      1, // 1 wood/sec at 1x match speed
        resourceLimit:       300,
        maxHealth:           100,
    }));

    RegisterBuildingDefinition(oGoldMine, new BuildingDefinition({
        name:               "Gold Mine",
        description:        "A basic resource plot that produces gold over time.",
        cost:               new Cost([new ResourceCost("water", 70), new ResourceCost("iron", 30)]),
        sprite:              sGoldMine,
        productionResource: "gold",
        productionRate:      1, // 1 gold/sec at 1x match speed
        resourceLimit:       300,
        maxHealth:           100,
    }));

    RegisterBuildingDefinition(oIronMine, new BuildingDefinition({
        name:               "Iron Mine",
        description:        "A basic resource plot that produces iron over time.",
        cost:               new Cost([new ResourceCost("water", 30), new ResourceCost("wood", 60)]),
        sprite:              sIronMine,
        productionResource: "iron",
        productionRate:      1, // 1 iron/sec at 1x match speed
        resourceLimit:       300,
        maxHealth:           100,
    }));
}

/// @function BuildingApplyDefinition(_building)
/// @description Looks up _building's BuildingDefinition and sets up per-instance production + training runtime state (both set unconditionally regardless of building kind -- see .md). Call once from a building's Create event, after event_inherited() and after RegisterAllBuildingDefinitions() has run.
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
    _building.resourceLimit         = _def.resourceLimit; // TOTAL lifetime units this instance may produce -- undefined = unlimited
    _building.producedTotal         = 0; // lifetime units produced so far -- compared against resourceLimit

    _building.trainsUnit       = _def.trainsUnit;
    _building.unitsPerBuilding = _def.unitsPerBuilding;
    _building.trainCost        = _def.trainCost;
    _building.trainTime        = _def.trainTime;
    _building.trainQueue       = 0; // units waiting to be trained -- see TrainingTryQueueUnit
    _building.trainProgress    = 0; // seconds accumulated toward the next completion -- see TrainingUpdateQueue

    _building.maxHealth   = _def.maxHealth;
    _building.damageTaken = 0;
}

#macro PLOT_BONUS_DISTANT_MULTIPLIER 1.5 // +50% maxHealth (and, for production buildings, +50% resourceLimit) on Distant/"far" plots

/// @function ApplyPlotBonuses(_building, _plot)
/// @description Applies Distant-plot stat bonuses: every building gets +50% maxHealth, production buildings also get +50% resourceLimit. No-ops for Castle/Exterior/Blocked plots. Call AFTER the building's Create event (BuildingApplyDefinition) has already run. See .md.
/// @param {Id.Instance} _building A just-created building instance.
/// @param {Id.Instance} _plot The oBuildingPlot it was placed on.
function ApplyPlotBonuses(_building, _plot) {
    if (!_plot.far) return;

    _building.maxHealth = round(_building.maxHealth * PLOT_BONUS_DISTANT_MULTIPLIER);

    if (_building.resourceLimit != undefined) {
        _building.resourceLimit = round(_building.resourceLimit * PLOT_BONUS_DISTANT_MULTIPLIER);
    }
}

#macro ECONOMIC_XP_DEPLETION 8 // XP awarded when a resource building depletes naturally -- see BuildingUpdateProduction

/// @function BuildingUpdateProduction(_building)
/// @description Delta-time-based resource production, scaled by global.matchSpeed, accumulated fractionally so high rates can award multiple whole units per frame. No-op if productionRate <= 0. On hitting resourceLimit: awards ECONOMIC_XP_DEPLETION, frees the plot, and self-destroys. Rate is scaled by the team's stationed passive bonuses. See .md.
/// @param {Id.Instance} _building
function BuildingUpdateProduction(_building) {
    if (_building.productionRate <= 0 || _building.productionResource == undefined) return;

    var _bonus      = GetStationedPassiveBonuses(_building.team);
    var _goldBonus  = (_building.productionResource == "gold") ? _bonus.goldProductionBonus : 0;
    var _multiplier = 1 + _bonus.allResourceProductionBonus + _goldBonus;

    var _dt = delta_time / 1000000; // microseconds -> seconds, same idiom as oOpeningCredits/Step_0.gml
    _building.productionAccumulator += _building.productionRate * _multiplier * global.matchSpeed * _dt;

    var _wholeUnits = floor(_building.productionAccumulator);
    if (_wholeUnits <= 0) return;

    _building.productionAccumulator -= _wholeUnits;

    var _hasLimit    = _building.resourceLimit != undefined;
    var _willDeplete = false;
    if (_hasLimit) {
        var _roomLeft = _building.resourceLimit - _building.producedTotal;
        if (_wholeUnits >= _roomLeft) {
            _wholeUnits  = _roomLeft; // don't overshoot the lifetime cap
            _willDeplete = true;
        }
    }

    if (_wholeUnits > 0) {
        _building.producedTotal += _wholeUnits;

        var _resources = global.resources[_building.team];
        var _current    = struct_get(_resources, _building.productionResource);
        struct_set(_resources, _building.productionResource, _current + _wholeUnits);

        AnalyticsRecordResourceProduced(_building.team, _building.productionResource, _wholeUnits);

        repeat (_wholeUnits) {
            PlayResourceProducedEffect(_building, _building.productionResource);
        }
    }

    if (_willDeplete) {
        GainXP(_building.team, ECONOMIC_XP_DEPLETION);
        BuildingFreePlot(_building); // frees the plot (PlotScripts.gml) so it's buildable + clickable again
        instance_destroy(_building);
    }
}

/// @function PlayResourceProducedEffect(_building, _resource)
/// @description Called once per whole unit of resource produced -- spawns the resource-produced particle burst at _building's position. No sound/popup text yet.
/// @param {Id.Instance} _building
/// @param {String} _resource
function PlayResourceProducedEffect(_building, _resource) {
    SpawnResourceProducedParticles(_building, _resource);
}
