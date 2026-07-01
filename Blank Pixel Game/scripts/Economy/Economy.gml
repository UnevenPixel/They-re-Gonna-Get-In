function ResourceCost(_resource,_amt) constructor{
    resource    = _resource;
    amt         = _amt;
}

//@description Cost Struct for Any Purchasable
//@parameter {array} Costs Array of costs from ResourceCost struct
function Cost(_costs) constructor{
    wood    = 0;
    wheat   = 0;
    water   = 0;
    iron    = 0;
    gold    = 0;
    meat    = 0;
    bones   = 0;
    coal    = 0;
    weapons = 0;
    coins   = 0;
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
            default:
                break;
        }
    }
    
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

// @function Puchase(_costStruct,_team)
// @desc Purchase an Item with a supplied Cost Struct
// @param {Struct.Cost} _costStruct cost Struct
// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY
// @returns {bool} whether purchase failed or succeeded
function Puchase(_costStruct,_team){
    if (!is_instanceof(_costStruct,Cost)){
        return false;
    }
    if _costStruct.CanAfford(_team){
        var _varNames = struct_get_names(global.resources[_team]);
        for(var i = 0; i < struct_names_count(global.resources[_team]); i ++){
            var _res = _varNames[i];
            var _resAmt = struct_get(global.resources[_team],_res);
            var _costAmt = struct_get(self,_res);
            struct_set(global.resources[_team],_res,_resAmt - _costAmt);
        }
        return true;
    }
    else{
        return false;
    }
}