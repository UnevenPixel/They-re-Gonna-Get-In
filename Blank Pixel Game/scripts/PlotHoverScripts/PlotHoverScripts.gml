// Hover/tooltip overlay for un-occupied building plots. Also owns the shared
// dwell/fade/gap macros BuildingHoverScripts.gml and CastleBonusHoverScripts.gml
// reuse. See PlotHoverScripts.md.

// Reads global.gameSettings.hoverDelayWorldItems live every reference (not a
// compile-time constant) so every consumer picks up the setting automatically.
#macro PLOT_HOVER_DELAY_STEPS  (global.gameSettings.hoverDelayWorldItems * 60) // steps @ 60fps, deliberately NOT scaled by global.matchSpeed
#macro PLOT_HOVER_FADE_STEPS   20  // ~1/3 sec fade in/out, same real-time basis as the delay above
#macro PLOT_HOVER_CURSOR_GAP   8   // px of daylight between the mouse cursor and the card's nearest edge, in the direction of its anchor

// Scribble inline colour tag names for PlotHoverBonusText -- see .md.
#macro PLOT_HOVER_GOOD_COLOR_TAG "c_lime"
#macro PLOT_HOVER_BAD_COLOR_TAG  "c_red"

// Suppression hook for the Fate Engine overlay -- set/cleared by
// FateEngineOverlay.Open()/Leave() (FateEngineOverlayScripts.gml).
global.fateEngineOverlayActive = false;

/// @function TutorialCharacterSpeaking()
/// @description 2026-08-15 bugfix -- True while a tutorial character (Booger or The Dealer) is actively
///        visible on screen with dialogue up, and mouse-hover cards should therefore fade out rather than
///        cover their text. Read by PlotHoverSuppressed()/BuildingHoverSuppressed() (CastleBonusHoverController
///        reuses the latter), same "return true, let Step()'s own dwell/fade logic ease the card to alpha 0"
///        shape global.fateEngineOverlayActive already established -- deliberately NOT a "skip Step()
///        entirely" gate, since that FREEZES whatever the card was already showing instead of fading it,
///        which was the actual bug (a card already on screen when she popped up stayed frozen in place,
///        covering her text, instead of easing away). oUnitControl/Step_0.gml was updated to always call
///        the hover controllers' Step() during both a guided-tutorial restriction and the Dealer intro
///        scene's suppression window, relying on this check (not a skipped call) to hide them. Booger:
///        only her "idle" state (bubble actually shown) counts -- matches the precedent already set for
///        gating her OWN hover-Step() calls during a restriction. The Dealer: her whole
///        IsSuppressingInput() window counts, not just a narrower "bubble shown" state -- that window
///        already suppresses everything else in the game for its duration, so covering all of it here is
///        the simpler, consistent choice. See PlotHoverScripts.md.
/// @returns {Bool}
function TutorialCharacterSpeaking() {
    return (global.tutorialGuide.state == "idle") || global.dealerIntro.IsSuppressingInput();
}

/// @function PlotHoverName(_plot)
/// @description Hover card name-plate text for an un-occupied plot. See .md for the classification order.
/// @param {Id.Instance} _plot An oBuildingPlot instance.
/// @returns {String}
function PlotHoverName(_plot) {
    if (_plot.blocked) return "Blocked Plot";
    if (_plot.inside)  return "Castle Plot";
    if (_plot.far)     return "Distant Plot";
    return "Exterior Plot";
}

/// @function PlotHoverBonusText(_plot)
/// @description Normal body text -- states the real placement bonus this plot type grants. See .md; must be kept in sync with GetPlacementCost/ApplyPlotBonuses by hand.
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
/// @description Italic flavor text shown inside sHoverCardDataWindow below the body.
/// @param {Id.Instance} _plot An oBuildingPlot instance.
/// @returns {String}
function PlotHoverFlavorText(_plot) {
    if (_plot.blocked) return "Whatever this plot could become remains sealed for now.";
    if (_plot.inside)  return "An open building plot within your castle walls.";
    if (_plot.far)     return "An open building plot deep in the contested field beyond your walls.";
    return "An open building plot just outside your castle walls.";
}

/// @function PlotHoverSuppressed(_selectionController, _blueprintController)
/// @description True while the player is mid-action elsewhere and plot hover should not trigger. See .md.
/// @param {Struct.SelectionController} _selectionController
/// @param {Struct.BlueprintController} _blueprintController
/// @returns {Bool}
function PlotHoverSuppressed(_selectionController, _blueprintController) {
    return _selectionController.isTargeting
        || _blueprintController.dragging
        || _blueprintController.IsMouseOverPanel()
        || global.fateEngineOverlayActive
        || TutorialCharacterSpeaking(); // 2026-08-15 bugfix -- see TutorialCharacterSpeaking()'s own comment/.md
}

/// @function PlotHoverController()
/// @description Owns one HoverCard and drives it for un-occupied building plots -- dwell timer, fade, cursor-relative anchoring. Owner calls Step()/Draw(). See .md.
function PlotHoverController() constructor {
    card        = new HoverCard();
    hoverTarget = noone; // the oBuildingPlot currently being dwelt on, or noone
    hoverTimer  = 0;     // real steps (NOT global.matchSpeed) spent continuously hovering hoverTarget
    alpha       = 0;     // current fade level, 0-1

    /// @function Step(_selectionController, _blueprintController)
    /// @description Call once per Step event. Resolves this frame's hover candidate, advances/resets the dwell timer, eases alpha toward the target. Only re-Shows/repositions the card while it should be visible -- see .md re: "freeze and fade."
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

        if (_candidate != hoverTarget) {
            hoverTarget = _candidate;
            hoverTimer  = 0;
        } else if (_candidate != noone) {
            hoverTimer += 1;
        }

        var _shouldShow  = (hoverTarget != noone) && (hoverTimer >= PLOT_HOVER_DELAY_STEPS);
        var _targetAlpha = _shouldShow ? 1 : 0;
        var _fadeStep    = 1 / PLOT_HOVER_FADE_STEPS;
        alpha = (alpha < _targetAlpha)
            ? min(_targetAlpha, alpha + _fadeStep)
            : max(_targetAlpha, alpha - _fadeStep);

        if (_shouldShow) {
            card.Show(PlotHoverName(hoverTarget), PlotHoverBonusText(hoverTarget), 0, 0, PlotHoverFlavorText(hoverTarget));

            var _mx    = device_mouse_x_to_gui(0);
            var _my    = device_mouse_y_to_gui(0);
            var _cardW = card.GetWidth();
            var _cardH = card.GetHeight();

            // Each axis anchors independently toward whichever half of the
            // screen the mouse ISN'T in, so the card opens away from the
            // nearest screen edge instead of running off it.
            var _anchorLeft = (_mx < display_get_gui_width()  / 2);
            var _anchorTop  = (_my < display_get_gui_height() / 2);

            card.x = _anchorLeft ? (_mx + PLOT_HOVER_CURSOR_GAP) : (_mx - PLOT_HOVER_CURSOR_GAP - _cardW);
            card.y = _anchorTop  ? (_my + PLOT_HOVER_CURSOR_GAP) : (_my - PLOT_HOVER_CURSOR_GAP - _cardH);

            // Safety-net clamp in case an extreme cursor position still
            // pushes the card off-screen.
            card.x = clamp(card.x, 0, display_get_gui_width()  - _cardW);
            card.y = clamp(card.y, 0, display_get_gui_height() - _cardH);
        }
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event. No-ops while fully faded out.
    static Draw = function() {
        if (alpha <= 0) return;
        card.Draw(alpha);
    }
}
