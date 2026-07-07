/// @function ResourceCost(_resource, _amt)
/// @description A single resource/amount pair -- the building block used to
///        assemble a Cost struct.
/// @param {String} _resource Resource name matching a key in global.resources,
///        e.g. "wood", "gold".
/// @param {Real} _amt Amount of that resource.
function ResourceCost(_resource,_amt) constructor{
    resource    = _resource;
    amt         = _amt;
}

/// @function Cost(_costs)
/// @description Aggregated cost struct for anything purchasable -- sums an array
///        of ResourceCost entries into one field per resource type (wood, wheat,
///        water, iron, gold, meat, bones, coal, weapons, coins, xp, fateTokens).
///        xp/fateTokens are included here for consistency (CanAfford/Purchase
///        walk global.resources generically) even though nothing is expected
///        to cost XP directly yet -- Fate Tokens are the more likely spend
///        once that system exists (see ProgressionScripts.gml).
/// @param {Array<Struct.ResourceCost>} _costs Array of ResourceCost structs to total up.
function Cost(_costs) constructor{
    wood       = 0;
    wheat      = 0;
    water      = 0;
    iron       = 0;
    gold       = 0;
    meat       = 0;
    bones      = 0;
    coal       = 0;
    weapons    = 0;
    coins      = 0;
    xp         = 0;
    fateTokens = 0;
    for(var i = 0; i < array_length(_costs); i ++){
        if !is_instanceof(_costs[i], ResourceCost) continue;

        switch(_costs[i].resource){
            case "wood":
                wood += _costs[i].amt;
                break;
            case "wheat":
                wheat += _costs[i].amt;
                break;
            case "water":
                water += _costs[i].amt;
                break;
            case "iron":
                iron += _costs[i].amt;
                break;
            case "gold":
                gold += _costs[i].amt;
                break;
            case "meat":
                meat += _costs[i].amt;
                break;
            case "bones":
                bones += _costs[i].amt;
                break;
            case "coal":
                coal += _costs[i].amt;
                break;
            case "weapons":
                weapons += _costs[i].amt;
                break;
            case "coins":
                coins += _costs[i].amt;
                break;
            case "xp":
                xp += _costs[i].amt;
                break;
            case "fateTokens":
                fateTokens += _costs[i].amt;
                break;
            default:
                break;
        }
    }
    
    /// @function CanAfford(_team)
    /// @description Checks whether the given team currently has enough of every
    ///        resource in global.resources to cover this Cost.
    /// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY -- indexes global.resources.
    /// @returns {Bool} True if the team can afford every resource in this cost.
    static CanAfford = function(_team){
        var _varNames = struct_get_names(global.resources[_team]);
        var _findFalse = false;
        for(var i = 0; i < struct_names_count(global.resources[_team]); i ++){
            var _res = _varNames[i];
            var _resAmt = struct_get(global.resources[_team],_res);
            var _costAmt = struct_get(self,_res);
            if _resAmt < _costAmt{
                _findFalse = true;
            }
        }
        
        return !_findFalse;
    }
}

/// @function GetDiscountedCost(_cost, _fraction)
/// @description Returns a NEW Cost struct with every resource field reduced
///        by _fraction (e.g. 0.5 = 50% off), rounded to the nearest whole
///        unit -- this project's resources are whole-integer-only (see
///        Purchase/CanAfford above; also BuildingUpdateProduction,
///        BuildingDefinitions.gml). Does not mutate _cost. Built for the
///        2026-07-06/07 "plot bonuses" request -- see GetPlacementCost
///        (BlueprintScripts.gml), which applies this when a building is
///        placed on a plot that discounts its type.
/// @param {Struct.Cost} _cost
/// @param {Real} _fraction 0-1 fraction to discount off (0.5 = half price).
/// @returns {Struct.Cost}
function GetDiscountedCost(_cost, _fraction) {
    var _discounted = new Cost([]);
    var _names = struct_get_names(_cost);
    for (var i = 0; i < array_length(_names); i++) {
        var _name = _names[i];
        var _amt  = struct_get(_cost, _name);
        if (!is_real(_amt)) continue; // skips CanAfford -- a static method, not a resource field, but struct_get_names can still list it
        struct_set(_