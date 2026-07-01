//CastlePlots

var castleStartPos = new Vector2(80,128);

for(var _xx = 0; _xx < 5; _xx ++){
    for(var _yy = 0; _yy < 5; _yy ++){
        var _rel = new Vector2(_xx*48,_yy*48)
        var _pos = castleStartPos.GetAdd(_rel);
        
        var _block = false;
        if _xx != 0 && _xx != 4 && _yy != 0 && _yy != 4{
            _block = true;
        }
        var _p = instance_create_layer(_pos.x,_pos.y,"Plots",oBuildingPlot);
        _p.blocked = _block;
        _p.inside = true;
    }
}

instance_destroy();