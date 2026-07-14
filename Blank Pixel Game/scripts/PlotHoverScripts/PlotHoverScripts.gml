// -----------------------------------------------------------
// PlotHoverScripts -- hover/tooltip data overlay for un-occupied
// oBuildingPlot instances (2026-07-06 request). First real consumer of the
// general-purpose HoverCard base (HoverCardScripts.gml) -- classifies a
// plot into one of 4 kinds (name + normal "bonus" body text + italic
// flavor text) and drives a HoverCard's visibility through a dwell timer +
// fade in/out, suppressed while the player is mid-action elsewhere
// (targeting, dragging a blueprint, or the Fate Engine overlay being open).
//
// Plot classification (see oBuildingPlot's inside/far/blocked fields --
// PlotScripts.gml, oPlotSpawner/Create_0.gml, oOuterPlotSpawner/Create_0.gml):
//   blocked              -> "Blocked Plot"  (meta-progression-locked --
//                            only ever true on INSIDE plots, see
//                            oPlotSpawner's 3x3 interior lock)
//   inside (unblocked)   -> "Castle Plot"   (buildable, within the castle walls)
//   !inside, far         -> "Distant Plot"  (buildable, deep outer ground)
//   !inside, !far        -> "Exterior Plot" (buildable, just outside the walls)
// These 4 are mutually exclusive and exhaustive for every oBuildingPlot
// this project spawns. blocked is checked FIRST since it can coexist with
// inside (the interior 3x3 lock) and always wins -- a locked plot reads as
// "Blocked Plot", not "Castle Plot", until it's unlocked. (The request's
// exact casing was "castle plot" for that one name only -- normalized to
// Title Case here to match the other 3 and every other order/label string
// in this project, e.g. "Defend Building"/"Siege Castle".)
//
// 2026-07-06 follow-up: content is now split across HoverCard's two text
// regions. PlotHoverBonusText (normal body, fntDataCard) states the
// placement bonus per oOuterPlotSpawner's header comment ("resource
// buildings get a placement bonus OUTSIDE the castle; unit-training
// buildings get theirs INSIDE... everything gets a bonus on far plots").
// PlotHoverFlavorText (italic, FntDataCardItalics, rendered inside
// sHoverCardDataWindow below the body) carries the original descriptive
// one-liners from the previous pass.
//
// 2026-07-07 follow-up: the bonus is now REAL, not just describable --
// GetPlacementCost (BlueprintScripts.gml) and ApplyPlotBonuses
// (BuildingDefinitions.gml) implement the actual 50% cost discounts and the
// Distant-plot +50% production-limit/health bonus. PlotHoverBonusText below
// now quotes the concrete numbers instead of the previous qualitative-only
// wording (which had flagged itself as "overpromising before it's real" --
// no longer applicable now that the mechanic exists). See those two
// functions for the authoritative logic; this file's text is just a
// human-readable restatement of it and could drift out of sync if the
// numbers change there without a matching edit here.
//
// Suppression: per request, this must NOT trigger while the player is
// mid-action elsewhere -- SelectionController.isTargeting (attack/defend
// target selection), BlueprintController.dragging (placing a building), or
// global.fateEngineOverlayActive. 2026-07-13: that flag is now real,
// wired infrastructure -- FateEngineOverlay.Open()/Leave()
// (FateEngineOverlayScripts.gml) sets/clears it. Belt-and-suspenders at
// this point rather than load-bearing: oUnitControl/Step_0.gml's own
// isOpen early-exit guard already stops this controller's Step() from
// running at all while the overlay is open.
// -----------------------------------------------------------

#macro PLOT_HOVER_DELAY_STEPS  60 // 5 sec * option_game_speed (60fps) -- see below, deliberately NOT scaled by global.matchSpeed
#macro PLOT_HOVER_FADE_STEPS   20  // ~1/3 sec fade in/out, same real-time basis as the delay above
#macro PLOT_HOVER_CURSOR_GAP   8   // px of daylight between the mouse cursor and the card's nearest edge, in the direction of its anchor -- 2026-07-06 request

// Scribble inline colour tag names for PlotHoverBonusText, 2026-07-07 request
// ("direct and to the point... each bonus effect in green if good, red if
// bad"). Both "c_lime"/"c_red" are pre-registered by Scribble out of the box
// (duplicates of GM's native colour constants -- see
// __scribble_config_colours.gml), so no scribble_color_set() call was
// needed. Every effect line in this file is currently "good" (a discount or
// a stat increase), so PLOT_HOVER_BAD_COLOR_TAG is unused today -- kept
// here as the documented convention for whenever a plot type gets a
// downside worth calling out (e.g. if "greater exposure to attack" on
// Distant plots ever becomes a real mechanical penalty instead of just
// flavor text). Requires HoverCardScripts.gml's DrawCardTextWithShadow to
// blend with c_white (not HOVER_CARD_TEXT_COLOR) on its main pass, or these
// tags would render washed toward F1DEB6 instead of their true colour --
// see that function's 2026-07-07 correction.
#macro PLOT_HOVER_GOOD_COLOR_TAG "c_lime"
#macro PLOT_HOVER_BAD_COLOR_TAG  "c_red"

// Suppression hook for the Fate Engine overlay -- see file header. Defaults
// false; set/cleared by FateEngineOverlay.Open()/Leave()
// (FateEngineOverlayScripts.gml, 2026-07-13).
global.fateEngineOverlayActive = false;

/// @function PlotHoverName(_plot)
/// @description The hover card name-plate text for an un-occupied
///        oBuildingPlot -- one of "Blocked Plot"/"Castle Plot"/"Distant
///        Plot"/"Exterior Plot". See file header for the classification
///        order (blocked checked first).
/// @param {Id.Instance} _plot An oBuildingPlot instance.
/// @returns {String}
function PlotHoverName(_plot) {
    if (_plot.blocked) return "Blocked Plot";
    if (_plot.inside)  return "Castle Plot";
    if (_plot.far)     return "Distant Plot";
    return "Exterior Plot";
}

/// @function PlotHoverBonusText(_plot)
/// @description The hover card's NORMAL body text (fntDataCard, above the
///        flavor window) for an un-occupied oBuildingPlot -- states the
///        REAL placement bonus this plot type grants, matching
///        GetPlacementCost (BlueprintScripts.gml) and ApplyPlotBonuses
///        (BuildingDefinitions.gml) exactly (see file header).
///
///        2026-07-07 request: "direct and to the point" -- a category
///        header line (e.g. "Resource Buildings:", left in the card's
///        standard HOVER_CARD_TEXT_COLOR) followed by one line per bonus
///        effect, each wrapped in a PLOT_HOVER_GOOD_COLOR_TAG (lime) or
///        PLOT_HOVER_BAD_COLOR_TAG (red) Scribble colour tag depending on
///        whether it helps or hurts the player -- every effect here is
///        currently a "good" one. Distant plots have TWO category blocks
///        (Resource Buildings, then All Buildings) since their bonus
///        applies differently to different building types; the other two
///        bonus-granting kinds have only one. Blocked plots have no bonus
///        to describe, so this states the lock instead, in plain text with
///        no colour tags (matching the mechanical-fact role this slot
///        plays for the other 3 kinds).
/// @param {Id.Instance} _plot An oBuildingPlot instance.
/// @returns {String}
function PlotHoverBonusText(_plot) {
    if (_plot.blocked) return "This plot is locked and cannot be built on yet.";

    if (_plot.inside) {
        return $"Training Buildings:\n[{PLOT_HOVER_GOOD_COLOR_TAG}]-50% Build Cost[/c]";
    }

    if (_plot.far) {
        return $"Resource Buildings:\n[{PLOT_HOVER_GOOD_COLOR_TAG}]-50% Build Cost[/c]\n[{PLOT_HOVER_GOOD_COLOR_TAG}]+50% Production Yield[/c]\nAll Buildings:\n[{PLOT_HOVER_GOOD_COLOR_TAG}]+50% Health[/c]";
    }

    return $"Resource Buildings:\n[{PLOT_HOVER_GOOD_COLOR_TAG}]-50% Build Cost[/c]";
}

/// @function PlotHoverFlavorText(_plot)
/// @description The hover card's italic flavor text (FntDataCardItalics,
///        rendered inside sHoverCardDataWindow below the body) for an
///        un-occupied oBuildingPlot -- the descriptive one-liners from the
///        previous pass, matching PlotHoverName's classification.
/// @param {Id.Instance} _plot An oBuildingPlot instance.
/// @returns {String}
function PlotHoverFlavorText(_plot) {
    if (_plot.blocked) return "Whatever this plot could become remains sealed for now.";
    if (_plot.inside)  return "An open building plot within your castle walls.";
    if (_plot.far)     return "An open building plot deep in the contested field beyond your walls.";
    return "An open building plot just outside your castle walls.";
}

/// @function PlotHoverSuppressed(_selectionController, _blueprintController)
/// @description True while the player is mid-action elsewhere and plot
///        hover data should NOT trigger (or should hide if already
///        showing) -- targeting an attack/defend order, dragging a
///        blueprint to place a building, the mouse sitting over the
///        Blueprint UI panel at all (2026-07-08 addition -- see
///        BuildingHoverScripts.gml's file header for why: the panel is a
///        GUI-space overlay drawn on top of the game world, so without
///        this check the mouse could sit over both a filled blueprint slot
///        AND a world-space plot underneath it, showing two tooltips at
///        once), or the Fate Engine overlay being open.
/// @param {Struct.SelectionController} _selectionController
/// @param {Struct.BlueprintController} _blueprintController
/// @returns {Bool}
function PlotHoverSuppressed(_selectionController, _blueprintController) {
    return _selectionController.isTargeting
        || _blueprintController.dragging
        || _blueprintController.IsMouseOverPanel()
        || global.fateEngineOverlayActive;
}

/// @function PlotHoverController()
/// @description Owns one HoverCard (HoverCardScripts.gml) and drives it for
///        un-occupied building plots: a 5-second continuous-hover dwell
///        timer (PLOT_HOVER_DELAY_STEPS) before the card fades in, and a
///        fade-out (same PLOT_HOVER_FADE_STEPS rate) the instant the mouse
///        leaves the plot, the plot becomes occupied, or
///        PlotHoverSuppressed goes true. Same "plain struct, owner calls
///        Step()/Draw()" pattern as BlueprintController/SelectionController/
///        XpBarWidget -- wire into oUnitControl alongside those.
function PlotHoverController() constructor {
    card        = new HoverCard();
    hoverTarget = noone; // the oBuildingPlot currently being dwelt on, or noone
    hoverTimer  = 0;     // real steps (NOT global.matchSpeed) spent continuously hovering hoverTarget -- see file header
    alpha       = 0;     // current fade level, 0-1

    /// @function Step(_selectionController, _blueprintController)
    /// @description Call once per Step event. Resolves this frame's hover
    ///        candidate (mouse-over an un-occupied oBuildingPlot, unless
    ///        PlotHoverSuppressed), advances the dwell timer or resets it
    ///        on a change of target, and eases alpha toward 1 once the
    ///        dwell threshold is reached (or back toward 0 otherwise).
    ///        Only actually (re)positions/re-Shows the card while it
    ///        should be visible -- while fading out, the card keeps
    ///        whatever content/position it last had, which is the desired
    ///        "freeze and fade" look rather than a snap-away.
    /// @param {Struct.SelectionController} _selectionController
    /// @param {Struct.BlueprintController} _blueprintController
    static Step = function(_selectionController, _blueprintController) {
        var _candidate = noone;
        if (!PlotHoverSuppressed(_selectionController, _blueprintController)) {
            var _found = instance_position(mouse_x, mouse_y, oBuildingPlot);
            if (_found != noone && !_found.occupied) {
                _candidate = _found;
            }
        }

        // A different plot (or nothing, or suppression/occupation kicked
        // in) resets the dwell timer -- 5 CONTINUOUS seconds on the same
        // plot is required every time, per spec.
        if (_candidate != hoverTarget) {
            hoverTarget = _candidate;
            hoverTimer  = 0;
        } else if (_candidate != noone) {
            hoverTimer += 1; // real steps -- see PLOT_HOVER_DELAY_STEPS
        }

        var _shouldShow  = (hoverTarget != noone) && (hoverTimer >= PLOT_HOVER_DELAY_STEPS);
        var _targetAlpha = _shouldShow ? 1 : 0;
        var _fadeStep    = 1 / PLOT_HOVER_FADE_STEPS;
        alpha = (alpha < _targetAlpha)
            ? min(_targetAlpha, alpha + _fadeStep)
            : max(_targetAlpha, alpha - _fadeStep);

        if (_shouldShow) {
            // Content/sprite selection doesn't depend on position -- Show()
            // with a placeholder (0,0) first, then position below once
            // card.GetHeight() reflects whichever sprite actually got
            // picked (Short/Mid/Tall). Same "set content, then mutate the
            // public x/y fields directly" approach used throughout this
            // file's history, just driving the full anchor now instead of
            // a flat cursor offset.
            card.Show(PlotHoverName(hoverTarget), PlotHoverBonusText(hoverTarget), 0, 0, PlotHoverFlavorText(hoverTarget));

            var _mx    = device_mouse_x_to_gui(0);
            var _my    = device_mouse_y_to_gui(0);
            var _cardW = card.GetWidth();
            var _cardH = card.GetHeight();

            // Position-sensitive anchoring, 2026-07-06 request: on EACH
            // axis independently, anchor the card's edge nearest the mouse
            // toward whichever half of the screen the mouse ISN'T in, so
            // the card always opens away from the nearest screen edge
            // instead of running off it. E.g. mouse in the bottom-right
            // quadrant -> the card's bottom-right corner sits
            // PLOT_HOVER_CURSOR_GAP px up and to the left of the mouse
            // (card occupies the top-left of the cursor).
            var _anchorLeft = (_mx < display_get_gui_width()  / 2); // mouse in the LEFT half  -> anchor the card's LEFT edge near the mouse (card opens rightward)
            var _anchorTop  = (_my < display_get_gui_height() / 2); // mouse in the TOP half   -> anchor the card's TOP edge near the mouse (card opens downward)

            card.x = _anchorLeft ? (_mx + PLOT_HOVER_CURSOR_GAP) : (_mx - PLOT_HOVER_CURSOR_GAP - _cardW);
            card.y = _anchorTop  ? (_my + PLOT_HOVER_CURSOR_GAP) : (_my - PLOT_HOVER_CURSOR_GAP - _cardH);

            // Safety-net clamp in case an extreme cursor position still
            // pushes the card off-screen (e.g. a very narrow window) --
            // same on-screen-nudge approach as OrderMenu.Open (OrderMenu.gml).
            card.x = clamp(card.x, 0, display_get_gui_width()  - _cardW);
            card.y = clamp(card.y, 0, display_get_gui_height() - _cardH);
        }
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event. No-ops while fully faded
    ///        out (alpha <= 0) rather than drawing an invisible card every frame.
    static Draw = function() {
        if (alpha <= 0) return;
        card.Draw(alpha);
    }
}
