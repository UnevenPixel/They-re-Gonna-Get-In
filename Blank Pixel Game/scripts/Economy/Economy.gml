// Core resource-cost primitives used by every purchasable thing in the game.
// See Economy.md.

/// @function ResourceCost(_resource, _amt)
/// @description A single resource/amount pair -- the building block used to assemble a Cost struct.
/// @param {String} _resource Resource name matching a key in global.resources, e.g. "wood", "gold".
/// @param {Real} _amt Amount of that resource.
function ResourceCost(_resource,_amt) constructor{
    resource    = _resource;
    amt         = _amt;
}

/// @function Cost(_costs)
/// @description Aggregated cost struct for anything purchasable -- sums an array of ResourceCost entries into one field per resource type. See .md.
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
    /// @description Checks whether the given team currently has enough of every resource in global.resources to cover this Cost.
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
/// @description Returns a NEW Cost struct with every resource field reduced by _fraction, rounded to the nearest whole unit. Does not mutate _cost. See .md.
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
        struct_set(_discounted, _name, round(_amt * (1 - _fraction)));
    }
    return _discounted;
}

/// @function Purchase(_costStruct, _team)
/// @description Attempts to purchase an item using a supplied Cost struct. If the team can afford it, deducts the cost from global.resources and records analytics for every resource actually spent.
/// @param {Struct.Cost} _costStruct Cost struct describing what's being bought.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
/// @returns {Bool} True if the purchase succeeded, false if it was rejected (not a Cost struct, or the team couldn't afford it).
function Purchase(_costStruct,_team){
    if (!is_instanceof(_costStruct,Cost)){
        return false;
    }
    if _costStruct.CanAfford(_team){
        var _varNames = struct_get_names(global.resources[_team]);
        for(var i = 0; i < struct_names_count(global.resources[_team]); i ++){
            var _res = _varNames[i];
            var _resAmt = struct_get(global.resources[_team],_res);
            var _costAmt = struct_get(_costStruct,_res);
            struct_set(global.resources[_team],_res,_resAmt - _costAmt);
            if (_costAmt > 0) AnalyticsRecordResourceSpent(_team, _res, _costAmt);
            if (_costAmt > 0 && _team == TEAM.PLAYER) ResourceSpendPopupAdd(_res, _costAmt); // HUD "-##" float -- no-ops for resources without a bar icon
        }
        return true;
    }
    else{
        return false;
    }
}
