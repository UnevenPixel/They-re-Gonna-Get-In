# UnitSelection

The player's (and AI's) unit selection and order-issuing system: `Order` (a single issuable command), the order registry, and `SelectionController` (drag box + current selection + target-selection mode).

## Order

`Order(_name, _label, _onIssue, _requiresTarget, _targetValidator)` -- `_name` matches both an entry in a unit's `availableOrders` AND a registered `StateMachine` state name. The default `onIssue` (when not overridden) just calls `fsm.ChangeState(name)` on every unit, guarding each with `instance_exists()` first: `IssueOrderToUnits` is shared by the player's `SelectionController` and the AI controller -- `SelectionController` prunes dead units out of `selected` once per Step (`PruneDeadSelected`), but the AI path doesn't go through that, and even the player path can't guarantee nothing died in the instant between the prune and this callback running. This was flagged in a nightly review as the one place that defensive-existence-check pattern (used everywhere else for cross-instance references like `attackBuildingTarget`/`combatTarget`/`defendTarget`) was missing.

`_requiresTarget` orders (e.g. "defend") don't issue immediately when picked from the menu -- the controller enters target-selection mode and waits for a qualifying click (`SelectionController.BeginTargeting`). `_targetValidator(_instance, _team)` decides whether a clicked instance is legal; `_team` is always the "own team" perspective of whoever is issuing, passed through rather than hardcoded, so the same validator works for either side.

## SelectionController

One instance for the player (created persistent). Not player-exclusive despite `oUnitControl` being the only thing that currently instantiates it -- an AI-driven controller could use this same struct with `_team = TEAM.ENEMY`.

`SELECTION_DRAG_MIN_GUI_Y` (812, out of a 1920x1080 GUI) marks the boundary below which the screen is bottom-panel UI real estate (blueprint panel etc.) rather than playfield -- `BeginDrag()` no-ops if the press starts at or below this line, even over empty panel padding a widget's own hit-test doesn't claim. Only where the drag STARTS is checked; a drag that begins above the line and is dragged down past it is unaffected.

`EndDrag`: a drag smaller than 4px on both axes is treated as a click, not a box, to avoid accidentally clearing selection on a tiny mouse jitter.

`PruneDeadSelected()` removes any selected unit that no longer exists (died since being selected) from `selected`. `ApplyDamage` (`UnitCombatHelpers.gml`) destroys units directly via `instance_destroy` with no hook back into selection state, so nothing else keeps `selected` in sync -- without this, `AvailableOrders`/`IssueOrder`/`UnitSelectHoverController.Step` can all dereference a freed instance. Called once per Step from `oUnitControl/Step_0.gml`, before anything else that frame reads `selected`, rather than guarding every read site individually. Flagged as critical in the same nightly review as the `Order.onIssue` guard above.

`Deselect()` instantly clears the selection and cancels target-selection mode if active -- does NOT touch `dragging` (a drag is a mouse-button-held gesture, not persistent state; `EndDrag` still resolves normally on mouse-up). Added for the Fate Engine overlay's Open() behavior ("all selections will be unselected instantly, and submenus will close") -- the only prior way to clear `selected` was two inline assignments inside `IssueOrder`/`UpdateTargeting`, neither of which fit an external caller wanting a clean-slate reset.

`SelectAllOfType(_unitType)` selects every live instance of `_unitType` on this controller's own team, replacing the current selection -- added for the Army Limit Widget's "Unit Limits" dropdown ("select all deployed units of that type"). "Deployed" means live `oUnitParent` instances on the battlefield -- stationed (garrisoned) units are deliberately excluded; they're a different object (`oUnitStationed`), have no FSM, and were never selectable, matching how `AI_GatherAvailableUnits` (`AIControl.gml`) treats live and stationed units as separate pools.

`IssueOrder(_orderName, _context)` clears `selected` the instant the order actually goes out -- immediately for a no-target order like "guard"/"siege", but not until `UpdateTargeting`'s successful-click branch for a targeted order like "defend"/"attack" (nothing has actually been issued yet at IssueOrder time for those). Units deselect once given an order.

`BeginTargeting`/`UpdateTargeting`: `_targetingJustBegan` swallows the same-frame click that opened targeting mode. `BeginTargeting` (called from `IssueOrder`, itself called the instant the order menu reports a click) runs in the SAME Step event as the first `UpdateTargeting` call -- `mouse_check_button_pressed(mb_left)` is still true for the rest of that Step, since it's the exact same physical press that selected the order from the menu. Without this guard, that stale press gets read as the target click, resolving against wherever the cursor happened to sit on the menu (almost never valid) and canceling targeting mode before the reticle is ever drawn. This fixed a real bug ("sometimes does not bring up the targeting reticle").

`UpdateTargeting` also handles a plot/building resolution quirk: an occupied `oBuildingPlot` is never destroyed once something is built on it (`TryPlaceBlueprint` just sets `occupied = true`) and sits at the exact same x/y as the building on it, so `instance_position(..., all)` can resolve to the plot instead of the building underneath -- the plot fails every real `targetValidator` (not an `oBuildingParent`), so the click would silently do nothing. Rather than an actual mask/sprite swap (every mask in this project is rectangle/bbox collision, not precise -- an empty mask would need a hand-authored sprite), an occupied plot is click-through here: the click is re-resolved against `oBuildingParent`, which matches the building sitting on top. This checks `occupied`, NOT `blocked` (an unrelated meta-progression flag, see `oPlotSpawner`'s interior-grid lockout) -- the two were conflated in an earlier pass and corrected same-day. An unoccupied plot (blocked or not) has nothing built on it and is unaffected.

## API

- `Order(_name, _label, _onIssue, _requiresTarget, _targetValidator)`.
- `RegisterOrder(_order)`, `GetOrder(_name)`, `GetCommonOrders(_units)`.
- `SELECTION_DRAG_MIN_GUI_Y`.
- `SelectionController(_unitObject, _team)` -- `BeginDrag()`, `EndDrag(_additive)`, `GetDragRect()`, `PruneDeadSelected()`, `Deselect()`, `SelectAllOfType(_unitType)`, `AvailableOrders()`, `IssueOrder(_orderName, _context)`, `BeginTargeting(_order)`, `CancelTargeting()`, `UpdateTargeting()`, `DrawDragBox()`.

2026-10-15: `DrawTargetingCursor()` (yellow circle + "Select target for: ..." text) removed -- `sCursorFlag` (CursorScripts.gml) now signals targeting mode.
