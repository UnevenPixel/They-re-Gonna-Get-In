// Spawns the 5x5 inside-castle plot grid for both sides, mirrored off room
// center, then self-destroys. See oPlotSpawner.md.

var castleStartPos = new Vector2(80,128);

for(var _xx = 0; _xx < 5; _xx ++){
    for(var _yy = 0; _yy < 5; _yy ++){
        var _rel = new Vector2(_xx*48,_yy*48)
        var _pos = castleStartPos.GetAdd(_rel);

        var _block = false;
        if _xx != 0 && _xx != 4 && _yy != 0 && _yy != 4{
            _block = true;
        }

        var _player = SpawnBuildingPlot(_pos.x, _pos.y, true, false, TEAM.PLAYER);
        _player.blocked = _block;

        var _enemy = SpawnBuildingPlot(room_width - _pos.x, _pos.y, true, false, TEAM.ENEMY);
        _enemy.blocked = _block;
    }
}

instance_destroy();
