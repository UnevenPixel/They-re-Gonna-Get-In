// Static per-unit-TYPE data (UnitDefinition) + registry + shared health/damage
// helpers used by both units and buildings. See UnitDefinitions.md.

/// @function UnitDefinition(_data)
/// @description Static definition for one unit type -- everything identical across every instance of that type. Takes a single struct literal rather than positional args (too many fields for positional safety) -- see .md for the full field reference and per-unit data provenance notes.
/// @param {Struct} _data Fields: name, description, cost, maxHealth, attackDamage, attackRange, attackLeashRange, attackHitFrame, attackCooldownMax, attackAggroRadius, siegeSweepRadius, maxSpeed, sprites, icon, smallSprite, palette, availableOrders, tier, tags, passives, projectileObject, stationCost, stationedBonuses, gibSprite, usesGeneralChunks, productionBuildingDamageBonus. See .md for types/defaults.
function UnitDefinition(_data) constructor {
    name              = _data.name;
    description       = _data.description;
    cost              = _data.cost;
    maxHealth         = _data.maxHealth;
    attackDamage      = _data.attackDamage;
    attackRange       = _data.attackRange;
    attackLeashRange  = _data.attackLeashRange;
    attackHitFrame    = _data.attackHitFrame;
    attackCooldownMax = _data.attackCooldownMax;
    attackAggroRadius = _data.attackAggroRadius;
    siegeSweepRadius  = _data.siegeSweepRadius;
    maxSpeed          = _data.maxSpeed;
    sprites           = _data.sprites;
    icon              = variable_struct_exists(_data, "icon")        ? _data.icon        : undefined;
    smallSprite       = variable_struct_exists(_data, "smallSprite") ? _data.smallSprite : undefined;
    palette           = variable_struct_exists(_data, "palette")    ? _data.palette     : undefined;
    availableOrders   = _data.availableOrders;
    tier              = variable_struct_exists(_data, "tier")     ? _data.tier     : 1;
    tags              = variable_struct_exists(_data, "tags")     ? _data.tags     : [];
    passives          = variable_struct_exists(_data, "passives") ? _data.passives : [];
    projectileObject  = variable_struct_exists(_data, "projectileObject") ? _data.projectileObject : undefined;
    stationCost       = variable_struct_exists(_data, "stationCost") ? _data.stationCost : 0;
    stationedBonuses  = variable_struct_exists(_data, "stationedBonuses") ? _data.stationedBonuses : [];
    gibSprite         = variable_struct_exists(_data, "gibSprite") ? _data.gibSprite : undefined;
    usesGeneralChunks = variable_struct_exists(_data, "usesGeneralChunks") ? _data.usesGeneralChunks : true;
    productionBuildingDamageBonus = variable_struct_exists(_data, "productionBuildingDamageBonus") ? _data.productionBuildingDamageBonus : 0;
}

// Registry keyed by object_index, NOT a string name -- see .md.
global.__unitDefRegistry = ds_map_create();

/// @function RegisterUnitDefinition(_objectIndex, _definition)
/// @param {Asset.GMObject} _objectIndex
/// @param {Struct.UnitDefinition} _definition
function RegisterUnitDefinition(_objectIndex, _definition) {
    ds_map_set(global.__unitDefRegistry, _objectIndex, _definition);
}

/// @function GetUnitDefinition(_objectIndex)
/// @param {Asset.GMObject} _objectIndex
/// @returns {Struct.UnitDefinition|Undefined}
function GetUnitDefinition(_objectIndex) {
    return ds_map_exists(global.__unitDefRegistry, _objectIndex)
        ? global.__unitDefRegistry[? _objectIndex]
        : undefined;
}

/// @function UnitHasTag(_unit, _tag)
/// @description Looks up _unit's UnitDefinition and checks its tags array. Base for search scripts (e.g. "find nearby ranged units").
/// @param {Id.Instance} _unit
/// @param {String} _tag
/// @returns {Bool} False if _unit has no registered definition.
function UnitHasTag(_unit, _tag) {
    var _def = GetUnitDefinition(_unit.object_index);
    return (_def != undefined) && array_contains(_def.tags, _tag);
}

/// @function UnitIconTag(_unitDef)
/// @description Translates a UnitDefinition's icon sprite into the Scribble inline-sprite tag that renders it. See .md.
/// @param {Struct.UnitDefinition} _unitDef
/// @returns {String} The tag, or "" if _unitDef.icon is undefined.
function UnitIconTag(_unitDef) {
    if (_unitDef.icon == undefined) return "";
    return $"[{sprite_get_name(_unitDef.icon)},0]";
}

/// @function GetDamageTaken(_instance)
/// @description Reads the current damageTaken value off any damageable instance -- a unit (unitData.damageTaken) or a building (damageTaken directly). See .md.
/// @param {Id.Instance} _instance
/// @returns {Real}
function GetDamageTaken(_instance) {
    return variable_instance_exists(_instance, "unitData")
        ? _instance.unitData.damageTaken
        : _instance.damageTaken;
}

/// @function SetDamageTaken(_instance, _value)
/// @description Writes damageTaken back onto _instance, unit or building -- mirrors GetDamageTaken.
/// @param {Id.Instance} _instance
/// @param {Real} _value
function SetDamageTaken(_instance, _value) {
    if (variable_instance_exists(_instance, "unitData")) {
        _instance.unitData.damageTaken = _value;
    } else {
        _instance.damageTaken = _value;
    }
}

/// @function GetCurrentHealth(_instance)
/// @description Derived from maxHealth minus damageTaken every call -- not stored as its own field, one source of truth. Works for both units and buildings. See .md.
/// @param {Id.Instance} _instance
/// @returns {Real}
function GetCurrentHealth(_instance) {
    return _instance.maxHealth - GetDamageTaken(_instance);
}

/// @function UnitApplyDefinition(_unit)
/// @description Looks up _unit's UnitDefinition and copies every static stat onto the instance, stamps unitData.unitType, and scales maxHealth/attackDamage by the team's live stationed bonuses (baked in once, not retroactive -- see .md). Call once from a unit's Create event, after fsm/agent/unitData exist and RegisterAllUnitDefinitions() has run. Logs and no-ops if no definition is registered.
///        IMPORTANT: _unit.team must already be its FINAL value before this runs -- see .md, every spawn path that sets team after creation must call this again afterward.
/// @param {Id.Instance} _unit
function UnitApplyDefinition(_unit) {
    var _def = GetUnitDefinition(_unit.object_index);
    if (_def == undefined) {
        show_debug_message($"UnitApplyDefinition: no UnitDefinition registered for {object_get_name(_unit.object_index)}. Check RegisterAllUnitDefinitions().");
        return;
    }

    _unit.unitData.unitType = _unit.object_index;

    var _bonus = GetStationedPassiveBonuses(_unit.team);
    _unit.maxHealth         = round(_def.maxHealth    * (1 + _bonus.unitHealthBonus));
    _unit.attackDamage      = round(_def.attackDamage * (1 + _bonus.unitDamageBonus));
    _unit.attackRange       = _def.attackRange;
    _unit.attackLeashRange  = _def.attackLeashRange;
    _unit.attackHitFrame    = _def.attackHitFrame;
    _unit.attackCooldownMax = _def.attackCooldownMax;
    _unit.attackAggroRadius = _def.attackAggroRadius;
    _unit.siegeSweepRadius  = _def.siegeSweepRadius;

    _unit.maxSpeed       = _def.maxSpeed; // flat copy, kept for parity -- nothing currently reads it, see oUnitParent/Create_0.gml
    _unit.agent.maxSpeed = _def.maxSpeed; // the one steering behaviors actually use

    _unit.sprIdle   = _def.sprites.idle;
    _unit.sprWalk   = _def.sprites.walk;
    _unit.sprAttack = _def.sprites.attack;

    _unit.palette = _def.palette; // undefined for units with no Pallete sprite yet -- PaletteSwapDrawUnit handles that gracefully

    _unit.availableOrders = _def.availableOrders;
}

/// @function RegisterAllUnitDefinitions()
/// @description Registers every unit type's UnitDefinition. Call once at game start -- wired in alongside RegisterAllOrders(), both called from oGameControl's Create event.
function RegisterAllUnitDefinitions() {
    // Attack timing/range/speed fields below are still placeholders, not
    // balanced values -- the source data sheet doesn't specify them.
    // maxHealth/attackDamage/cost ARE sheet-sourced. See .md for full
    // per-unit provenance notes and known gaps.
    RegisterUnitDefinition(oPeasantUnit, new UnitDefinition({
        name:              "Peasant",
        description:       "A basic conscript. Cheap, unremarkable, expendable.",
        cost:              new Cost([new ResourceCost("water", 20)]),
        maxHealth:         10,
        attackDamage:      2,
        attackRange:       32,
        attackLeashRange:  320,
        attackHitFrame:    3,
        attackCooldownMax: 60,
        attackAggroRadius: 96,
        siegeSweepRadius:  160,
        maxSpeed:          0.5, // 2026-08-30 follow-up: halved from 1, see .md
        sprites:           new AnimationLibrary(sPeasantIdle, sPeasantWalk, sPeasantAttack),
        icon:              sPeasantIcon,
        smallSprite:       sPeasantSmall,
        palette:           sPeasantPallete,
        availableOrders:   ["guard", "defend", "attack", "siege", "station"],
        tier:              1, // MVP: every unit is Tier 1 for now
        tags:              ["infantry", "melee", "cheap"],
        stationCost:       20,
        passives: [
            {name: "Stationed Effect", description: "+5% all resource production speed per peasant stationed."},
            {name: "Deployed Effect",  description: "Weak melee."},
        ],
        stationedBonuses: [
            {type: "allResourceProduction", amount: 0.05},
        ],
        gibSprite: sPeasantGib,
    }));

    RegisterUnitDefinition(oBombGoblinUnit, new UnitDefinition({
        name:              "Bomb Goblins",
        description:       "Straps on a bomb and sprints at the enemy. Dies on detonation.",
        cost:              new Cost([new ResourceCost("gold", 8)]),
        maxHealth:         6,
        attackDamage:      20, // sheet: "20 AOE" -- self-destruct-on-hit is real, true AoE is not, see .md
        attackRange:       20,
        attackLeashRange:  260,
        attackHitFrame:    2,
        attackCooldownMax: 40,
        attackAggroRadius: 80,
        siegeSweepRadius:  140,
        maxSpeed:          1.1, // sheet: "one of, if not the fastest unit in the game" -- 2026-08-30 follow-up: halved from 2.2, see .md
        sprites:           new AnimationLibrary(sBombGoblinIdle, sBombGoblinWalk, sBombGoblinExplode),
        icon:              sBombGoblinIcon,
        smallSprite:       sBombGoblinSmall,
        palette:           sBombGolbinPallete, // NOTE: asset name is misspelled "Golbin" on disk -- not a typo introduced here, see .md
        availableOrders:   ["guard", "defend", "attack", "siege", "station"],
        tier:              1,
        tags:              ["infantry", "melee", "suicide", "fast"],
        stationCost:       15,
        passives: [
            {name: "Stationed Effect", description: "+15% speed boost to gold production per Bomb Goblin stationed."},
            {name: "Deployed Effect",  description: "One of, if not the fastest unit in the game. Reaches the enemy quickly and inflicts AoE damage, but dies after use."},
            {name: "Notes",           description: "Dies immediately after its swing connects. Their AoE damage also hitting friendly units is still NOT implemented -- only single-target damage exists."},
        ],
        stationedBonuses: [
            {type: "goldProduction", amount: 0.15}, // gold only -- stacks additively with allResourceProduction bonuses from other stationed types
        ],
        usesGeneralChunks: false, // already has its own explosion animation, no unique gib sprite
    }));

    RegisterUnitDefinition(oMudGolemUnit, new UnitDefinition({
        name:              "Mud Golem",
        description:       "A lumbering construct of mud and stone.",
        cost:              new Cost([new ResourceCost("water", 40)]),
        maxHealth:         100,
        attackDamage:      5,
        attackRange:       36,
        attackLeashRange:  300,
        attackHitFrame:    5,
        attackCooldownMax: 90,
        attackAggroRadius: 90,
        siegeSweepRadius:  200,
        maxSpeed:          0.3, // 2026-08-30 follow-up: halved from 0.6, see .md
        sprites:           new AnimationLibrary(sMudGolemIdle, sMudGolemWalk, sMudGolemAttack),
        icon:              sMudGolemIcon,
        smallSprite:       sMudGolemSmall,
        palette:           sMudGolemPallete,
        availableOrders:   ["guard", "defend", "attack", "siege", "station"],
        tier:              1,
        tags:              ["infantry", "melee", "heavy", "tank"],
        stationCost:       25,
        passives: [
            {name: "Stationed Effect", description: "+5% HP to all units (stacks per Mud Golem stationed)."},
            {name: "Deployed Effect",  description: "Upon death, the ground becomes muddy, applying 80% slow for 5 seconds. NOT implemented -- no on-death effect hook exists yet."},
        ],
        stationedBonuses: [
            {type: "unitHealth", amount: 0.05}, // applied at spawn/redeploy time only, not retroactively -- see UnitApplyDefinition
        ],
        // No gibSprite/usesGeneralChunks override -- Mud Golem is excluded
        // from the entire gibbing system directly in GibScripts.gml, not via
        // these fields. See .md.
    }));

    RegisterUnitDefinition(oSoldierUnit, new UnitDefinition({
        name:              "Soldier",
        description:       "Standard melee infantry.",
        cost:              new Cost([new ResourceCost("wheat", 25), new ResourceCost("wood", 25), new ResourceCost("iron", 25)]),
        maxHealth:         20,
        attackDamage:      5,
        attackRange:       32,
        attackLeashRange:  320,
        attackHitFrame:    3,
        attackCooldownMax: 55,
        attackAggroRadius: 100,
        siegeSweepRadius:  170,
        maxSpeed:          0.5, // 2026-08-30 follow-up: halved from 1, see .md
        sprites:           new AnimationLibrary(sSoldierIdle, sSoldierWalk, sSoldierAttack),
        icon:              sSoldierIcon,
        smallSprite:       sSoldierSmall,
        palette:           sSoldierPallete,
        availableOrders:   ["guard", "defend", "attack", "siege", "station"],
        tier:              1,
        tags:              ["infantry", "melee"],
        stationCost:       30,
        passives: [
            {name: "Stationed Effect", description: "+5% damage & HP to all deployed units (stacks per Soldier stationed)."},
            {name: "Deployed Effect",  description: "Melee combat."},
        ],
        stationedBonuses: [
            {type: "unitHealth", amount: 0.05}, // stacks with Mud Golem's unitHealth bonus in the same pool
            {type: "unitDamage", amount: 0.05},
        ],
        gibSprite: sSoldierGib,
    }));

    RegisterUnitDefinition(oArcherUnit, new UnitDefinition({
        name:              "Archer",
        description:       "Ranged infantry armed with a bow.",
        cost:              new Cost([new ResourceCost("wheat", 50), new ResourceCost("gold", 25), new ResourceCost("wood", 25)]),
        maxHealth:         10,
        attackDamage:      3,
        attackRange:       96, // stand-in for "ranged" under the melee-derived attack state shape -- judgment call, not sheet-sourced
        attackLeashRange:  380,
        attackHitFrame:    4,
        attackCooldownMax: 70,
        attackAggroRadius: 140,
        siegeSweepRadius:  160,
        maxSpeed:          0.5, // 2026-08-30 follow-up: halved from 1, see .md
        sprites:           new AnimationLibrary(sArcherIdle, sArcherWalk, sArcherAttack, [
            {name: "projectile", sprite: sArcherProjectile}, // also set as projectileObject below -- reachable off sprites.projectile too
        ]),
        icon:              sArcherIcon,
        smallSprite:       sArcherSmall,
        palette:           sArcherPallete,
        availableOrders:   ["guard", "defend", "attack", "siege", "station"],
        tier:              1,
        tags:              ["infantry", "ranged"],
        projectileObject:  oArcherProjectile, // "attack" order dispatches ranged-tagged units into "attackRanged" instead -- see OrderWiring.gml
        stationCost:       15,
        passives: [
            {name: "Stationed Effect", description: "Ranged attacks from the wall."},
            {name: "Deployed Effect",  description: "Ranged attacks."},
            {name: "Notes",           description: "Upkeep (Stationed): 1 Wheat / 3 sec per data sheet -- still NOT implemented, no upkeep/drain system exists yet."},
        ],
        // stationedBonuses deliberately omitted -- see .md ("Ranged attacks
        // from the wall" is a combat mechanic, not a stat multiplier; out of
        // scope for now).
        gibSprite: sArcherGib,
    }));

    RegisterUnitDefinition(oKnightUnit, new UnitDefinition({
        name:              "Knight",
        description:       "Heavy melee infantry, effective against production buildings.",
        cost:              new Cost([new ResourceCost("wheat", 100), new ResourceCost("gold", 25), new ResourceCost("iron", 50)]),
        maxHealth:         25,
        attackDamage:      6,
        attackRange:       34,
        attackLeashRange:  340,
        attackHitFrame:    4,
        attackCooldownMax: 65,
        attackAggroRadius: 110,
        siegeSweepRadius:  180,
        maxSpeed:          0.45, // 2026-08-30 follow-up: halved from 0.9, see .md
        sprites:           new AnimationLibrary(sKnightIdle, sKnightWalk, sKnightAttack),
        icon:              sKnightIcon,
        smallSprite:       sKnightSmall,
        palette:           sKnightPallete,
        availableOrders:   ["guard", "defend", "attack", "siege", "station"],
        tier:              1,
        tags:              ["infantry", "melee", "heavy"],
        stationCost:       50,
        passives: [
            {name: "Stationed Effect", description: "+5% unit production speed."},
            {name: "Deployed Effect",  description: "+50% bonus damage against production buildings."},
        ],
        productionBuildingDamageBonus: 0.5, // implements the Deployed Effect flavor text above -- see .md
        stationedBonuses: [
            {type: "trainingSpeed", amount: 0.05}, // stacks linearly per Knight stationed like every other unit -- see .md re: wording gap
        ],
        gibSprite: sKnightGib,
    }));
}
