// -----------------------------------------------------------
// UnitDefinition -- static, per-unit-TYPE data (name, cost, base
// stats, sprites, tags, orders, passives). This is completely
// separate from UnitDataBlock (UnitScripts.gml), which is per-unit-
// INSTANCE runtime state that survives a station/redeploy swap --
// damage taken, status effects, and which UnitDefinition to reapply.
// -----------------------------------------------------------

/// @function UnitDefinition(_data)
/// @description Static definition for one unit type -- everything that's
///        identical across every instance of that type (e.g. every peasant).
///        Takes a single struct literal rather than positional args -- this
///        constructor has too many fields for positional args to stay
///        readable/safe against argument-order mistakes. That's a deliberate
///        deviation from this codebase's usual positional-arg constructor
///        convention (Vector2, Order, ResourceCost, AnimationLibrary, etc.) --
///        flag if you'd rather this matched those instead.
/// @param {Struct} _data Fields:
///        name              {String}   Display name, e.g. "Peasant".
///        description       {String}   Flavor/tooltip text.
///        cost              {Struct.Cost} Production cost (see Economy.gml).
///        maxHealth         {Real}
///        attackDamage      {Real}
///        attackRange       {Real}
///        attackLeashRange  {Real}
///        attackHitFrame    {Real}
///        attackCooldownMax {Real}
///        attackAggroRadius {Real}
///        siegeSweepRadius  {Real}
///        maxSpeed          {Real}
///        sprites           {Struct.AnimationLibrary} idle/walk/attack + extras.
///        availableOrders   {Array<String>} Order names this unit type can receive.
///        tags              {Array<String>} [optional, defaults to []] For search
///               scripts -- see UnitHasTag below.
///        passives          {Array<Struct>} [optional, defaults to []] Shape not
///               designed yet -- no passive-ability system exists. Treat each
///               entry as inert data ({name, description}) until there's an
///               actual hook to call it; flag before building real logic on this.
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
    availableOrders   = _data.availableOrders;
    tags              = variable_struct_exists(_data, "tags")     ? _data.tags     : [];
    passives          = variable_struct_exists(_data, "passives") ? _data.passives : [];
}

// -----------------------------------------------------------
// Registry -- keyed by object_index (e.g. oPeasantUnit), NOT a
// string name like the Order registry uses. This ties directly into
// instance_create_layer for stationed-unit redeploy and removes any
// risk of a definition/object name mismatch. Flag if you'd rather
// this stayed string-keyed for consistency with GetOrder/RegisterOrder.
// -----------------------------------------------------------

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
/// @description Looks up _unit's UnitDefinition and checks its tags array.
///        Intended as the base for search scripts (e.g. "find nearby ranged
///        units") -- add more helpers like this as real search needs come
///        up, rather than guessing ahead at what's needed.
/// @param {Id.Instance} _unit
/// @param {String} _tag
/// @returns {Bool} False if _unit has no registered definition.
function UnitHasTag(_unit, _tag) {
    var _def = GetUnitDefinition(_unit.object_index);
    return (_def != undefined) && array_contains(_def.tags, _tag);
}

/// @function UnitCurrentHealth(_unit)
/// @description Current health is deliberately NOT stored as its own field --
///        it's derived from maxHealth minus unitData.damageTaken every time,
///        so there's only one source of truth for "how hurt is this unit"
///        (unitData.damageTaken) and nothing can drift out of sync with it.
///        This is also exactly the value that survives a station/redeploy
///        swap: unitData carries over, maxHealth comes back from the
///        UnitDefinition looked up via unitData.unitType.
/// @param {Id.Instance} _unit
/// @returns {Real}
function UnitCurrentHealth(_unit) {
    return _unit.maxHealth - _unit.unitData.damageTaken;
}

/// @function UnitApplyDefinition(_unit)
/// @description Looks up _unit's UnitDefinition by object_index and copies
///        every static stat onto the instance -- health cap, attack stats,
///        sprites, availableOrders, and agent.maxSpeed. Also stamps
///        unitData.unitType so a stationed unit knows which definition to
///        reapply when it's redeployed back to "guard" (oUnitStationed,
///        not built yet, should hold nothing but a UnitDataBlock and call
///        this again on redeploy).
///        Call once from a unit's Create event, after fsm/agent/unitData
///        already exist (currently called at the end of
///        oUnitParent/Create_0.gml) and after RegisterAllUnitDefinitions()
///        has run at game start. Logs and no-ops if no definition is
///        registered for this object type.
/// @param {Id.Instance} _unit
function UnitApplyDefinition(_unit) {
    var _def = GetUnitDefinition(_unit.object_index);
    if (_def == undefined) {
        show_debug_message($"UnitApplyDefinition: no UnitDefinition registered for {object_get_name(_unit.object_index)}. Check RegisterAllUnitDefinitions().");
        return;
    }

    _unit.unitData.unitType = _unit.object_index;

    _unit.maxHealth         = _def.maxHealth;
    _unit.attackDamage      = _def.attackDamage;
    _unit.attackRange       = _def.attackRange;
    _unit.attackLeashRange  = _def.attackLeashRange;
    _unit.attackHitFrame    = _def.attackHitFrame;
    _unit.attackCooldownMax = _def.attackCooldownMax;
    _unit.attackAggroRadius = _def.attackAggroRadius;
    _unit.siegeSweepRadius  = _def.siegeSweepRadius;

    _unit.maxSpeed       = _def.maxSpeed; // flat copy, kept for parity -- nothing currently reads it, see note in oUnitParent/Create_0.gml
    _unit.agent.maxSpeed = _def.maxSpeed; // the one steering behaviors actually use

    _unit.sprIdle   = _def.sprites.idle;
    _unit.sprWalk   = _def.sprites.walk;
    _unit.sprAttack = _def.sprites.attack;

    _unit.availableOrders = _def.availableOrders;
}

// -----------------------------------------------------------
// Definition registration (call once, e.g. a game-start script) --
// mirrors RegisterAllOrders() in OrderWiring.gml.
// -----------------------------------------------------------

/// @function RegisterAllUnitDefinitions()
/// @description Registers every unit type's UnitDefinition. Call once at
///        game start -- wired in alongside RegisterAllOrders(), both called
///        from oGameControl's Create event (persistent, only placed in
///        rmInit, so this always runs before any unit is created).
function RegisterAllUnitDefinitions() {
    // NOTE: cost/stat numbers below are placeholders, not balanced values --
    // tune freely, nothing else depends on these specific numbers yet.
    RegisterUnitDefinition(oPeasantUnit, new UnitDefinition({
        name:              "Peasant",
        description:       "A basic conscript. Cheap, unremarkable, expendable.",
        cost:              new Cost([new ResourceCost("wheat", 10), new ResourceCost("coins", 5)]),
        maxHealth:         20,
        attackDamage:      3,
        attackRange:       32,
        attackLeashRange:  320,
        attackHitFrame:    3,
        attackCooldownMax: 60,
        attackAggroRadius: 96,
        siegeSweepRadius:  160,
        maxSpeed:          1,
        sprites:           new AnimationLibrary(sPeasantIdle, sPeasantWalk, sPeasantAttack),
        availableOrders:   ["guard", "defend", "attack", "siege", "station"],
        tags:              ["infantry", "melee", "cheap"],
    }));
}
