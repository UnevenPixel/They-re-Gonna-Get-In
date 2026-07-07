/// @function SpawnBuildingPlot(_x, _y, _inside, _far, _team)
/// @description Creates one oBuildingPlot instance on the "Plots" layer and
///        sets its classification fields directly, instead of every spawner
///        repeating instance_create_layer + five field assignments inline.
///        oBuildingPlot's inside/far/blocked/occupied/team fields are
///        declared as Object Properties (IDE-level, with defaults) rather
///        than in its Create event -- that's this object's existing
///        convention, not something introduced here.
/// @param {Real} _x
/// @param {Real} _y
/// @param {Bool} _inside True if this plot is inside the castle walls.
///        Resource buildings get a placement bonus OUTSIDE the castle;
///        unit-training buildings get theirs INSIDE -- see oBuildingPlot.
/// @param {Bool} _far True if this is an exposed "far" outer plot (more
///        danger of being attacked, bigger bonus for anything placed
///        there). Meaningless when _inside is true -- pass false.
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
/// @description Call right before a building is destroyed (combat death in
///        ApplyDamage, UnitCombatHelpers.gml, or resource depletion in
///        BuildingUpdateProduction, BuildingDefinitions.gml) to free up the
///        oBuildingPlot it was built on -- clears occupied so the plot is
///        buildable again AND, per the 2026-07-06 click-through fix in
///        UnitSelection.gml's UpdateTargeting, clickable/targetable again.
///        Does NOT touch blocked -- that's a separate, meta-progression-owned
///        flag (see oPlotSpawner/Create_0.gml) with nothing to do with
///        whether a building currently sits here; conflating the two was a
///        2026-07-06 mistake, corrected same day (occupied introduced).
///
///        No plot reference is stored on building instances -- TryPlaceBlueprint
///        (BlueprintScripts.gml) always spawns a building at its plot's exact
///        x/y and never destroys the plot, so it's found here by position
///        instead. No-op if no plot exists at _building's position (e.g. a
///        future placement path that doesn't use a plot at all).
/// @param {Id.Instance} _building
function BuildingFreePlot(_building) {
    var _plot = instance_position(_building.x, _building.y, oBuildingPlot);
    if (_plot != noone) {
        _plot.occupied = false;
    }
}
