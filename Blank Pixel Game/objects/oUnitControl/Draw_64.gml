draw_set_alpha(1);
orderMenu.Draw();
selectionController.DrawTargetingCursor();
blueprintController.Draw();

draw_set_valign(fa_top);
draw_set_halign(fa_left);
draw_text(8,8,string(selectionController.selected) + "\nOrder Menu Open: " + string(orderMenu.isOpen));