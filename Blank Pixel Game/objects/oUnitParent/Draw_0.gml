// Selection mask, palette-swapped sprite, FSM draw. See oUnitParent.md.
if mask_index == sM_UnitMask{
    draw_sprite(sM_UnitShadow,0,x,y);
    if array_contains(oUnitControl.selectionController.selected,id){
        draw_sprite(sM_UnitSelect,0,x,y);
    }
}
// TEAM.ENEMY units with a registered palette draw recolored via
// shPaletteSwap; everyone else draws as before. See PaletteSwapScripts.gml.
PaletteSwapDrawUnit(id);

fsm.Draw();
