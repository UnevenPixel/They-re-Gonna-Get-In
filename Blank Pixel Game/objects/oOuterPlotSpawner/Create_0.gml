// Spawns the near/far outer building-plot bands for both sides, mirrored
// off room center, then self-destroys. See oOuterPlotSpawner.md.

var _nearCols      = [512, 560];
var _rowsAbove      = [32, 80];   // both well above center y=207
var _rowsBelow      = [320, 368]; // both well below center y=207

var _farCol = 704; // single column -- both far groups share it, so all 4 far plots line up vertically

// -- Near plots: 8 per side (2 cols x 2 rows x 2 vertical groups) --
for (var i = 0; i < array_length(_nearCols); i++) {
    var _colX = _nearCols[i];

    for (var j = 0; j < array_length(_rowsAbove); j++) {
        SpawnBuildingPlot(_colX, _rowsAbove[j], false, false, TEAM.PLAYER);
        SpawnBuildingPlot(room_width - _colX, _rowsAbove[j], false, false, TEAM.ENEMY);
    }
    for (var j = 0; j < array_length(_rowsBelow); j++) {
        SpawnBuildingPlot(_colX, _rowsBelow[j], false, false, TEAM.PLAYER);
        SpawnBuildingPlot(room_width - _colX, _rowsBelow[j], false, false, TEAM.ENEMY);
    }
}

// -- Far plots: 4 per side (1 shared col x 2 rows x 2 vertical groups) --
for (var j = 0; j < array_length(_rowsAbove); j++) {
    SpawnBuildingPlot(_farCol, _rowsAbove[j], false, true, TEAM.PLAYER);
    SpawnBuildingPlot(room_width - _farCol, _rowsAbove[j], false, true, TEAM.ENEMY);
}
for (var j = 0; j < array_length(_rowsBelow); j++) {
    SpawnBuildingPlot(_farCol, _rowsBelow[j], false, true, TEAM.PLAYER);
    SpawnBuildingPlot(room_width - _farCol, _rowsBelow[j], false, true, TEAM.ENEMY);
}

instance_destroy();
