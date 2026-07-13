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
///        icon              {Asset.GMSprite} [optional, defaults to undefined]
///               Small (8x8) UI icon shown inline before this unit's name in
///               text, e.g. BuildingHoverDescriptionText's "Trains [icon]
///               Peasant" (BuildingHoverScripts.gml) -- see UnitIconTag
///               below, which turns this into a Scribble inline-sprite tag.
///               2026-07-09 addition -- every unit registered below sets
///               this to its own sXIcon sprite.
///        smallSprite       {Asset.GMSprite} [optional, defaults to undefined]
///               A ~16x20, bottom-center-anchored "small" full-body sprite,
///               distinct from sprites.idle (which is sized for in-world
///               rendering, not a UI window) -- used inside the Item/Unit
///               Window on the building hover card (BuildingHoverItemIcon,
///               BuildingHoverScripts.gml). 2026-07-09 addition, replacing
///               that window's earlier (undersized-for-purpose) use of
///               sprites.idle -- every unit registered below sets this to
///               its own sXSmall sprite.
///        palette           {Asset.GMSprite} [optional, defaults to undefined]
///               A 1px-wide, 2-frame "Pallete" sprite (matching this
///               project's existing spelling of that asset name, e.g.
///               sPeasantPallete) -- frame 0 lists the unit's original
///               swappable colors (one texel per row), frame 1 lists the
///               SAME row's replacement, used by shPaletteSwap to recolor
///               TEAM.ENEMY instances of this unit (PaletteSwapScripts.gml).
///               2026-07-10 addition -- undefined for any unit that doesn't
///               have a Pallete sprite yet (as of this writing, only Mud
///               Golem doesn't -- Bomb Goblin's exists under the misspelled
///               asset name sBombGolbinPallete, used as-is below);
///               PaletteSwapDrawUnit skips shading entirely when this is
///               undefined, so that unit just draws unshaded on both teams
///               until its Pallete sprite exists.
///        availableOrders   {Array<String>} Order names this unit type can receive.
///        tier              {Real} [optional, defaults to 1] Combat-XP tier
///               (see GainXP callers in ApplyDamage, UnitCombatHelpers.gml) --
///               +1/+3/+5 XP to the killer's team for Tier 1/2/3 kills, per
///               the "XP Age Progression System" doc (2026-07-06). Every
///               unit registered below is Tier 1 for now (2026-07-06
///               clarification: "Current Unit's are all tier 1, as we are
///               starting with that for the MVP build. We will add later
///               tiers later.") -- there's no real tier design yet beyond that.
///        tags              {Array<String>} [optional, defaults to []] For search
///               scripts -- see UnitHasTag below.
///        passives          {Array<Struct>} [optional, defaults to []] Still
///               free-text-only ({name, description}) -- shown verbatim on
///               hover cards (UnitHoverStationFlavorText/
///               UnitHoverDeployedPassiveText, UnitHoverScripts.gml). As of
///               2026-07-12, the "Stationed Effect" entry's real numeric
///               magnitude (where one exists) lives SEPARATELY in
///               stationedBonuses below -- passives itself still has no
///               hook and nothing enforces the two stay in sync; keep them
///               worded consistently by hand. "Deployed Effect" entries
///               remain entirely inert (no hook exists for those at all).
///        projectileObject  {Asset.GMObject} [optional, defaults to undefined]
///               The projectile a ranged unit fires -- see SpawnProjectile
///               (ProjectileScripts.gml), which reads this off the firing
///               unit's UnitDefinition. Leave unset for melee units; a
///               "ranged"-tagged unit with no projectileObject just logs and
///               no-ops when it tries to fire (SpawnProjectile), it won't crash.
///        stationCost       {Real} [optional, defaults to 0] Gold cost to
///               station/deploy this unit type, per the "Project Azurite
///               Data Sheets" (2026-07-03) "Station Deploy Cost (GOLD)"
///               column -- 2026-07-11 addition, unit hover card request.
///               Originally purely informational display data for
///               UnitHoverStationFlavorText (UnitHoverScripts.gml); as of
///               2026-07-12 it's ALSO the real, functional gate/spend for
///               both directions -- GetUnitStationCost (StationScripts.gml)
///               wraps it into a spendable Cost struct (Economy.gml), spent
///               via Purchase() by both the "station" order's greedy
///               cheapest-first affordability pass (OrderWiring.gml) and
///               DeployStationedUnit's click-to-deploy action
///               (StationScripts.gml, CastleGarrisonMenu.gml). NOT copied
///               onto live instances by UnitApplyDefinition -- nothing
///               reads it off an instance, every consumer already has the
///               UnitDefinition in hand (GetUnitDefinition), so duplicating
///               it there would just be dead data to keep in sync.
///        stationedBonuses  {Array<Struct>} [optional, defaults to []]
///               2026-07-12 addition -- the FUNCTIONAL counterpart to the
///               "Stationed Effect" passives entry's flavor text. Each
///               entry is {type, amount}: type is one of
///               "allResourceProduction" / "goldProduction" / "unitHealth"
///               / "unitDamage" / "trainingSpeed", amount is a fractional
///               bonus (0.05 = +5%). GetStationedPassiveBonuses
///               (StationScripts.gml) sums `amount` onto
///               StationedBonuses[type + "Bonus"] once per live
///               oUnitStationed of this type on a team -- i.e. every entry
///               here stacks linearly per unit stationed, matching each
///               unit's own "(stacks per X stationed)" flavor wording.
///               Archer's "Ranged attacks from the wall" passive is
///               deliberately NOT represented here -- that would mean a
///               garrisoned (non-live) unit actively firing on enemies, a
///               real new combat mechanic rather than a stat multiplier;
///               explicitly out of scope for the 2026-07-12 pass per user
///               clarification ("skip for now"). Leave stationedBonuses:
///               [] for any unit whose Stationed Effect has no numeric
///               hook yet.
///        gibSprite         {Asset.GMSprite} [optional, defaults to undefined]
///               2026-07-12 addition ("set up gibbing" request) -- this
///               unit's own unique on-death gib sprite (single frame,
///               e.g. sPeasantGib), spawned alongside the general chunks
///               by SpawnUnitDeathGibs (GibScripts.gml). Undefined for any
///               unit with no unique gib sprite yet (Bomb Goblin -- no
///               sprite exists for it; Mud Golem is excluded from the
///               whole gibbing system regardless of this field, see
///               GibScripts.gml).
///        usesGeneralChunks {Bool} [optional, defaults to true]
///               2026-07-12 addition -- false skips the shared
///               sGeneralChunks burst entirely for this unit's death
///               (still gets the instant blood splatter, its own
///               gibSprite if it has one, and the death blood-pixel
///               burst). Only Bomb Goblin sets this false today -- it
///               already has its own explosion animation
///               (sBombGoblinExplode) and no unique gib sprite, so the
///               remaining generic debris chunks would look mismatched.
///        productionBuildingDamageBonus {Real} [optional, defaults to 0]
///               2026-07-12 follow-up -- the FUNCTIONAL counterpart to
///               Knight's "Deployed Effect" flavor text ("Bonus damage
///               against production buildings"), same
///               flavor-text-to-numeric-field pattern stationedBonuses
///               already established. Fractional bonus (0.5 = +50%)
///               applied ONLY when this unit's melee hit lands on a
///               building that's an oResourceBuildingParent (WaterPump/
///               WheatField/Sawmill/GoldMine/IronMine -- see
///               UnitTryDealDamage, UnitCombatHelpers.gml) -- NOT training
///               buildings or the castle. 0 (no bonus) for every unit but
///               Knight. Scoped specifically to "production buildings"
///               per the flavor text's own wording, not a generic
///               vs-any-building bonus -- if a future unit needs a bonus
///               against a DIFFERENT building category, this field's name/
///               scope will need revisiting rather than reusing it as-is.
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

/// @function UnitIconTag(_unitDef)
/// @description Translates a UnitDefinition's icon sprite into the Scribble
///        inline-sprite tag that renders it -- "[spriteName,0]", mirroring
///        ResourceIconTag's shape (ResourceUIScripts.gml) but resolved via
///        sprite_get_name since each unit has its OWN distinct icon sprite
///        asset (sPeasantIcon, sArcherIcon, etc.) rather than one shared
///        frame-strip like sResourceIcons -- so there's no fixed index table
///        to look up, just the sprite's own asset name. 2026-07-09 addition,
///        for "icon before the unit's name" (BuildingHoverDescriptionText,
///        BuildingHoverScripts.gml).
/// @param {Struct.UnitDefinition} _unitDef
/// @returns {String} The tag, or "" if _unitDef.icon is undefined.
function UnitIconTag(_unitDef) {
    if (_unitDef.icon == undefined) return "";
    return $"[{sprite_get_name(_unitDef.icon)},0]";
}

/// @function GetDamageTaken(_instance)
/// @description Reads the current damageTaken value off any damageable
///        instance -- a unit (stored at unitData.damageTaken, so it
///        survives a station/redeploy swap) or a building (stored directly
///        as damageTaken, oBuildingParent -- see BuildingApplyDefinition,
///        BuildingDefinitions.gml -- buildings have no unitData/station
///        concept, so there's nothing to nest it inside). Used by
///        ApplyDamage/GetCurrentHealth so neither has to know which shape
///        _instance is.
/// @param {Id.Instance} _instance
/// @returns {Real}
function GetDamageTaken(_instance) {
    return variable_instance_exists(_instance, "unitData")
        ? _instance.unitData.damageTaken
        : _instance.damageTaken;
}

/// @function SetDamageTaken(_instance, _value)
/// @description Writes damageTaken back onto _instance, unit or building --
///        see GetDamageTaken for the shape this mirrors.
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
/// @description Current health is deliberately NOT stored as its own field --
///        it's derived from maxHealth minus damageTaken every time (see
///        GetDamageTaken), so there's only one source of truth for "how hurt
///        is this thing" and nothing can drift out of sync with it. Works
///        for both units (maxHealth comes from UnitDefinition, damageTaken
///        survives a station/redeploy swap via unitData) and buildings
///        (maxHealth comes from BuildingDefinition, damageTaken lives
///        directly on the instance). Named generically (not
///        UnitCurrentHealth) now that buildings use this too -- was
///        UnitCurrentHealth, renamed when building HP was added; grep found
///        exactly one caller (ApplyDamage) at rename time.
/// @param {Id.Instance} _instance
/// @returns {Real}
function GetCurrentHealth(_instance) {
    return _instance.maxHealth - GetDamageTaken(_instance);
}

/// @function UnitApplyDefinition(_unit)
/// @description Looks up _unit's UnitDefinition by object_index and copies
///        every static stat onto the instance -- health cap, attack stats,
///        sprites, palette (2026-07-10 addition, for PaletteSwapDrawUnit),
///        availableOrders, and agent.maxSpeed. Also stamps
///        unitData.unitType so a stationed unit knows which definition to
///        reapply when it's redeployed back to "guard" (oUnitStationed,
///        not built yet, should hold nothing but a UnitDataBlock and call
///        this again on redeploy).
///        Call once from a unit's Create event, after fsm/agent/unitData
///        already exist (currently called at the end of
///        oUnitParent/Create_0.gml) and after RegisterAllUnitDefinitions()
///        has run at game start. Logs and no-ops if no definition is
///        registered for this object type.
///
///        2026-07-12 addition: maxHealth/attackDamage are scaled by
///        _unit.TEAM's current unitHealthBonus/unitDamageBonus (Mud Golem/
///        Soldier's stationed passives -- GetStationedPassiveBonuses,
///        StationScripts.gml), rounded to the nearest whole number (HP/
///        damage read as whole numbers everywhere else in this codebase).
///        Bonus is baked in ONCE, at whatever moment this function runs --
///        NOT re-applied retroactively to units already alive when a new
///        Mud Golem/Soldier gets stationed later, and not removed if that
///        unit later redeploys back out. See GetStationedPassiveBonuses'
///        file-header comment (StationScripts.gml) for why this pass
///        deliberately doesn't do full dynamic re-application.
///
///        IMPORTANT: _unit.team must already be its FINAL value before
///        this runs, or the bonus for the WRONG team gets baked in. This
///        function is called from oUnitParent's Create event (still the
///        TEAM.PLAYER default at that point for any spawn path that
///        overrides team AFTER creation -- see the HAZARD comment in
///        oUnitParent/Create_0.gml), so every such path must call this
///        again after its team override. DeployStationedUnit
///        (StationScripts.gml) already did; TrainingSpawnUnit
///        (TrainingScripts.gml) is updated alongside this change to do
///        the same, since it previously relied on the stale Create-time
///        call, which read TEAM.PLAYER's bonuses for an AI-trained unit.
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

    _unit.maxSpeed       = _def.maxSpeed; // flat copy, kept for parity -- nothing currently reads it, see note in oUnitParent/Create_0.gml
    _unit.agent.maxSpeed = _def.maxSpeed; // the one steering behaviors actually use

    _unit.sprIdle   = _def.sprites.idle;
    _unit.sprWalk   = _def.sprites.walk;
    _unit.sprAttack = _def.sprites.attack;

    _unit.palette = _def.palette; // undefined for units with no Pallete sprite yet -- PaletteSwapDrawUnit (PaletteSwapScripts.gml) handles that gracefully

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
    // NOTE: attack timing/range/speed fields below (attackRange,
    // attackLeashRange, attackHitFrame, attackCooldownMax, attackAggroRadius,
    // siegeSweepRadius, maxSpeed) are still placeholders, not balanced values,
    // same as Peasant's always were -- the data sheet (Project Azurite Data
    // Sheets, 2026-07-03) doesn't specify any of these, only
    // name/limit/HP/DMG/cost/upkeep/time/effects/source building. maxHealth,
    // attackDamage, and cost ARE sheet-sourced and should be treated as real
    // going forward.
    //
    // passives below stores each unit's sheet "Stationed Effect"/"Deployed
    // Effect" text as inert data, per this struct's existing documented
    // convention (see passives field comment above) -- no station/deploy
    // system exists yet, so none of this executes. Per-unit Upkeep
    // (Stationed) from the sheet still has no home in either UnitDefinition
    // or BuildingDefinition and is deliberately NOT added as a field --
    // flagging rather than guessing at a shape for a system that isn't
    // designed (upkeep drain). Station Deploy Cost (GOLD), however, now
    // has a home -- stationCost below, 2026-07-11, real sheet values
    // supplied directly by the user for the unit hover card request
    // (Peasant 20 / Bomb Goblin 15 / Mud Golem 25 / Soldier 30 / Archer 15
    // / Knight 50) -- still purely display data, nothing deducts it yet.
    RegisterUnitDefinition(oPeasantUnit, new UnitDefinition({
        name:              "Peasant",
        description:       "A basic conscript. Cheap, unremarkable, expendable.",
        cost:              new Cost([new ResourceCost("water", 20)]), // was wheat10+coins5 -- corrected to match data sheet / PeasantWard.trainCost
        maxHealth:         10, // was 20 -- corrected to match data sheet
        attackDamage:      2,  // was 3 -- corrected to match data sheet
        attackRange:       32,
        attackLeashRange:  320,
        attackHitFrame:    3,
        attackCooldownMax: 60,
        attackAggroRadius: 96,
        siegeSweepRadius:  160,
        maxSpeed:          1,
        sprites:           new AnimationLibrary(sPeasantIdle, sPeasantWalk, sPeasantAttack),
        icon:              sPeasantIcon,
        smallSprite:       sPeasantSmall,
        palette:           sPeasantPallete,
        availableOrders:   ["guard", "defend", "attack", "siege", "station"],
        tier:              1, // MVP: every unit is Tier 1 for now, per 2026-07-06 clarification -- no real tier design yet
        tags:              ["infantry", "melee", "cheap"],
        stationCost:       20, // Gold, per data sheet -- user-supplied 2026-07-11
        passives: [
            {name: "Stationed Effect", description: "+5% all resource production speed per peasant stationed."},
            {name: "Deployed Effect",  description: "Weak melee."},
        ],
        stationedBonuses: [
            {type: "allResourceProduction", amount: 0.05}, // 2026-07-12, see GetStationedPassiveBonuses (StationScripts.gml)
        ],
        gibSprite: sPeasantGib, // 2026-07-12, see GibScripts.gml
    }));

    RegisterUnitDefinition(oBombGoblinUnit, new UnitDefinition({
        name:              "Bomb Goblins",
        description:       "Straps on a bomb and sprints at the enemy. Dies on detonation.",
        cost:              new Cost([new ResourceCost("gold", 8)]),
        maxHealth:         6,
        attackDamage:      20, // sheet lists this as "20 AOE" -- see NOTE below; self-destruct-on-hit is now real (2026-07-12 follow-up, UnitTryDealDamage), AoE (hitting more than the single _target) is still not
        attackRange:       20,
        attackLeashRange:  260,
        attackHitFrame:    2,
        attackCooldownMax: 40,
        attackAggroRadius: 80,
        siegeSweepRadius:  140,
        maxSpeed:          2.2, // sheet: "one of, if not the fastest unit in the game"
        sprites:           new AnimationLibrary(sBombGoblinIdle, sBombGoblinWalk, sBombGoblinExplode),
        icon:              sBombGoblinIcon,
        smallSprite:       sBombGoblinSmall,
        palette:           sBombGolbinPallete, // NOTE: sprite asset name is misspelled "Golbin" (not "Goblin") -- that's the actual existing asset name on disk/in the .yyp, not a typo introduced here; flag if you want it renamed (every other sBombGoblin* asset uses the correct spelling).
        availableOrders:   ["guard", "defend", "attack", "siege", "station"],
        tier:              1, // MVP: every unit is Tier 1 for now, per 2026-07-06 clarification -- no real tier design yet
        tags:              ["infantry", "melee", "suicide", "fast"],
        stationCost:       15, // Gold, per data sheet -- user-supplied 2026-07-11
        passives: [
            {name: "Stationed Effect", description: "+15% speed boost to gold production per Bomb Goblin stationed."},
            {name: "Deployed Effect",  description: "One of, if not the fastest unit in the game. Reaches the enemy quickly and inflicts AoE damage, but dies after use."},
            {name: "Notes",           description: "Dies immediately after its swing connects (2026-07-12 follow-up, UnitTryDealDamage/oUnitParent). Their AoE damage also hitting friendly units is still NOT implemented -- there's no actual area-of-effect damage yet, only the single-target hit every other melee unit deals."},
        ],
        stationedBonuses: [
            {type: "goldProduction", amount: 0.15}, // 2026-07-12, gold only -- stacks additively with allResourceProduction bonuses from other stationed types
        ],
        usesGeneralChunks: false, // 2026-07-12 -- already has its own explosion animation (sBombGoblinExplode) and no unique gib sprite; general debris chunks would look mismatched. Still gets the instant splatter + death blood-pixel burst.
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
        maxSpeed:          0.6,
        sprites:           new AnimationLibrary(sMudGolemIdle, sMudGolemWalk, sMudGolemAttack),
        icon:              sMudGolemIcon,
        smallSprite:       sMudGolemSmall,
        palette:           sMudGolemPallete,
        availableOrders:   ["guard", "defend", "attack", "siege", "station"],
        tier:              1, // MVP: every unit is Tier 1 for now, per 2026-07-06 clarification -- no real tier design yet
        tags:              ["infantry", "melee", "heavy", "tank"],
        stationCost:       25, // Gold, per data sheet -- user-supplied 2026-07-11
        passives: [
            {name: "Stationed Effect", description: "+5% HP to all units (stacks per Mud Golem stationed)."},
            {name: "Deployed Effect",  description: "Upon death, the ground becomes muddy, applying 80% slow for 5 seconds. NOT implemented -- no on-death effect hook exists yet (nothing in this codebase runs on unit death at all)."},
        ],
        stationedBonuses: [
            {type: "unitHealth", amount: 0.05}, // 2026-07-12 -- see UnitApplyDefinition (UnitDefinitions.gml), applied at spawn/redeploy time only, not retroactively to already-live units
        ],
        // No gibSprite/usesGeneralChunks override here -- Mud Golem is
        // excluded from the ENTIRE gibbing system (SpawnUnitDeathGibs/
        // SpawnUnitHitBlood, GibScripts.gml, both hard-exit early for
        // oMudGolemUnit specifically), not via these fields. Per explicit
        // 2026-07-12 request: "except the golem, we will handle his."
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
        maxSpeed:          1,
        sprites:           new AnimationLibrary(sSoldierIdle, sSoldierWalk, sSoldierAttack),
        icon:              sSoldierIcon,
        smallSprite:       sSoldierSmall,
        palette:           sSoldierPallete,
        availableOrders:   ["guard", "defend", "attack", "siege", "station"],
        tier:              1, // MVP: every unit is Tier 1 for now, per 2026-07-06 clarification -- no real tier design yet
        tags:              ["infantry", "melee"],
        stationCost:       30, // Gold, per data sheet -- user-supplied 2026-07-11
        passives: [
            {name: "Stationed Effect", description: "+5% damage & HP to all deployed units (stacks per Soldier stationed)."},
            {name: "Deployed Effect",  description: "Melee combat."},
        ],
        stationedBonuses: [
            {type: "unitHealth", amount: 0.05}, // 2026-07-12, stacks with Mud Golem's unitHealth bonus in the same pool
            {type: "unitDamage", amount: 0.05},
        ],
        gibSprite: sSoldierGib, // 2026-07-12, see GibScripts.gml
    }));

    RegisterUnitDefinition(oArcherUnit, new UnitDefinition({
        name:              "Archer",
        description:       "Ranged infantry armed with a bow.",
        cost:              new Cost([new ResourceCost("wheat", 50), new ResourceCost("gold", 25), new ResourceCost("wood", 25)]),
        maxHealth:         10,
        attackDamage:      3,
        attackRange:       96, // stand-in for "ranged" under the current melee-only attack state -- see NOTE below
        attackLeashRange:  380,
        attackHitFrame:    4,
        attackCooldownMax: 70,
        attackAggroRadius: 140,
        siegeSweepRadius:  160,
        maxSpeed:          1,
        sprites:           new AnimationLibrary(sArcherIdle, sArcherWalk, sArcherAttack, [
            {name: "projectile", sprite: sArcherProjectile}, // also set as projectileObject below (oArcherProjectile) -- this entry is just so the raw sprite is reachable off sprites.projectile too
        ]),
        icon:              sArcherIcon,
        smallSprite:       sArcherSmall,
        palette:           sArcherPallete,
        availableOrders:   ["guard", "defend", "attack", "siege", "station"],
        tier:              1, // MVP: every unit is Tier 1 for now, per 2026-07-06 clarification -- no real tier design yet
        tags:              ["infantry", "ranged"],
        projectileObject:  oArcherProjectile, // "attack" order dispatches ranged-tagged units into "attackRanged" instead of "attack" -- see OrderWiring.gml
        stationCost:       15, // Gold, per data sheet -- user-supplied 2026-07-11
        passives: [
            {name: "Stationed Effect", description: "Ranged attacks from the wall."},
            {name: "Deployed Effect",  description: "Ranged attacks."},
            {name: "Notes",           description: "Upkeep (Stationed): 1 Wheat / 3 sec per data sheet -- still NOT implemented, no upkeep/drain system exists yet. Ranged combat itself IS now real (attackRanged state, UnitStateAttackRanged.gml + oArcherProjectile) -- attackRange is still a judgment call, not sheet-sourced."},
        ],
        // stationedBonuses deliberately omitted (defaults to []) -- "Ranged
        // attacks from the wall" would mean a garrisoned unit actively
        // firing on enemies, a new combat mechanic rather than a stat
        // multiplier. Explicitly out of scope for the 2026-07-12 passive-
        // bonus pass per user clarification ("skip for now") -- Archer
        // contributes no functional stationed bonus yet. Revisit as its
        // own request.
        gibSprite: sArcherGib, // 2026-07-12, see GibScripts.gml
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
        maxSpeed:          0.9,
        sprites:           new AnimationLibrary(sKnightIdle, sKnightWalk, sKnightAttack),
        icon:              sKnightIcon,
        smallSprite:       sKnightSmall,
        palette:           sKnightPallete,
        availableOrders:   ["guard", "defend", "attack", "siege", "station"],
        tier:              1, // MVP: every unit is Tier 1 for now, per 2026-07-06 clarification -- no real tier design yet
        tags:              ["infantry", "melee", "heavy"],
        stationCost:       50, // Gold, per data sheet -- user-supplied 2026-07-11
        passives: [
            {name: "Stationed Effect", description: "+5% unit production speed."},
            {name: "Deployed Effect",  description: "+50% bonus damage against production buildings."},
        ],
        // 2026-07-12 follow-up -- now implemented via
        // productionBuildingDamageBonus below (UnitTryDealDamage,
        // UnitCombatHelpers.gml), 50% picked directly from the request
        // ("Make it 50% more damage for now") -- the flavor text above
        // used to just say "NOT implemented," updated to match.
        productionBuildingDamageBonus: 0.5,
        stationedBonuses: [
            // 2026-07-12 -- flavor text doesn't say "(stacks per Knight
            // stationed)" the way every other unit's does, but
            // GetStationedPassiveBonuses always stacks linearly per unit
            // by design (StationScripts.gml); applying the same rule here
            // for consistency rather than special-casing Knight to a flat
            // one-time bonus. Flagging the wording gap, not treating it as
            // a deliberate "no stacking" spec.
            {type: "trainingSpeed", amount: 0.05},
        ],
        gibSprite: sKnightGib, // 2026-07-12, see GibScripts.gml
    }));
}
