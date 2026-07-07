if mask_index = sM_UnitMask{
    draw_sprite(sM_UnitShadow,0,x,y);
    if array_contains(oUnitControl.selectionController.selected,id){
        draw_sprite(sM_UnitSelect,0,x,y);
    }
}
// PaletteSwapDrawUnit -- 2026-07-10 request: TEAM.ENEMY units with a
// registered palette (UnitDefinition.palette) draw recolored via
// shPaletteSwap; everyone else (TEAM.PLAYER, or any unit without a palette
// yet) draws exactly as before -- see PaletteSwapScripts.gml.
PaletteSwapDrawUnit(id);

fsm.Draw();