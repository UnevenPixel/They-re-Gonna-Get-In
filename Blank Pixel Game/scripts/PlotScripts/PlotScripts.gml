// oBuildingPlot creation + cleanup helpers. See PlotScripts.md.

/// @function SpawnBuildingPlot(_x, _y, _inside, _far, _team)
/// @description Creates one oBuildingPlot on the "Plots" layer and sets its classification fields directly. See .md.
/// @param {Real} _x
/// @param {Real} _y
/// @param {Bool} _inside True if this plot is inside the castle walls.
/// @param {Bool} _far True if this is an exposed "far" outer plot. Meaningless when _inside is true -- pass false.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY -- which side may build here.
/// @returns {Id.Instance} The created oBuildingPlot instance.
function SpawnBuildingPlot(_x, _y, _inside, _far, _team) {
    var _p = instance_create_layer(_x, _y, "Plots", oBuildingPlot);
    _p.inside   = _inside;
    _p.far      = _far;
    _p.blocked  = false;
    _p.occupied = false;
    _p.team     = _team;
    return _p;
}

/// @function BuildingFreePlot(_building)
/// @description Call right before a building is destroyed to free up the oBuildingPlot it was built on -- clears occupied (buildable + clickable again). Does NOT touch blocked. Finds the plot by position -- no plot reference is stored on building instances. See .md.
/// @param {Id.Instance} _building
function BuildingFreePlot(_building) {
    var _plot = instance_position(_building.x, _building.y, oBuildingPlot);
    if (_plot != noone) {
        _plot.occupied = false;
    }
}
