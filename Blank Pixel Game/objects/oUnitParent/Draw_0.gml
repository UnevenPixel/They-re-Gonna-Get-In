if mask_index = sM_UnitMask{
    draw_sprite(sM_UnitShadow,0,x,y);
    if array_contains(oUnitControl.selectionController.selected,id){
        draw_sprite(sM_UnitSelect,0,x,y);
    }
}
// PaletteSwapDrawUnit -- 2