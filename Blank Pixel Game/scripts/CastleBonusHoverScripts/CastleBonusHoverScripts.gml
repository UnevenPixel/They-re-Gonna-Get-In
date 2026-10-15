// Hover menu on the player's castle listing all currently applied stationed
// passive bonuses. See CastleBonusHoverScripts.md.

/// @function CastleBonusHoverBodyText(_bonuses)
/// @description One "+X% Label" line per non-zero field on _bonuses, joined with "\n". Falls back to "No active bonuses." See .md.
/// @param {Struct.StationedBonuses} _bonuses
/// @returns {String}
function CastleBonusHoverBodyText(_bonuses) {
    var _lines = [];

    if (_bonuses.allResourceProductionBonus > 0) {
        array_push(_lines, $"+{round(_bonuses.allResourceProductionBonus * 100)}% All Resource Production");
    }
    if (_bonuses.goldProductionBonus > 0) {
        array_push(_lines, $"+{round(_bonuses.goldProductionBonus * 100)}% Gold Production");
    }
    if (_bonuses.unitHealthBonus > 0) {
        array_push(_lines, $"+{round(_bonuses.unitHealthBonus * 100)}% Unit Health");
    }
    if (_bonuses.unitDamageBonus > 0) {
        array_push(_lines, $"+{round(_bonuses.unitDamageBonus * 100)}% Unit Damage");
    }
    if (_bonuses.trainingSpeedBonus > 0) {
        array_push(_lines, $"+{round(_bonuses.trainingSpeedBonus * 100)}% Unit Training Speed");
    }

    if (array_length(_lines) == 0) return "No active bonuses.";

    var _text = _lines[0];
    for (var i = 1; i < array_length(_lines); i++) {
        _text += "\n" + _lines[i];
    }
    return _text;
}

/// @function CastleBonusHoverController()
/// @description Owns a HoverCard shown while the mouse dwells over the player's own castle. Owner calls Step()/Draw().
function CastleBonusHoverController() constructor {
    card        = new HoverCard();
    hoverTarget = noone; // the oPlayerCastle instance currently being dwelt on, or noone
    hoverTimer  = 0;     // real steps (NOT global.matchSpeed), same basis as every other hover controller here
    alpha       = 0;     // current fade level, 0-1

    /// @function Step(_selectionController, _blueprintController, _garrisonMenuOpen)
    /// @description Resolves this frame's hover candidate, advances/resets the dwell timer, eases alpha toward the target. Same structure as PlotHoverController.Step/BuildingHoverController.Step.
    /// @param {Struct.SelectionController} _selectionController
    /// @param {Struct.BlueprintController} _blueprintController
    /// @param {Bool} _garrisonMenuOpen True while CastleGarrisonMenu is open -- forces this panel to treat the frame as "not hovering," fading it out.
    static Step = function(_selectionController, _blueprintController, _garrisonMenuOpen) {
        var _candidate = noone;
        if (!_garrisonMenuOpen && !BuildingHoverSuppressed(_selectionController, _blueprintController)) {
            var _found = instance_position(mouse_x, mouse_y, oPlayerCastle);
            if (_found != noone) _candidate = _found;
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
            var _bonuses = GetStationedPassiveBonuses(TEAM.PLAYER);
            card.Show("Castle Bonuses", CastleBonusHoverBodyText(_bonuses), 0, 0);

            var _mx    = device_mouse_x_to_gui(0);
            var _my    = device_mouse_y_to_gui(0);
            var _cardW = card.GetWidth();
            var _cardH = card.GetHeight();

            // Same cursor-quadrant anchoring as PlotHoverController.Step.
            var _anchorLeft = (_mx < display_get_gui_width()  / 2);
            var _anchorTop  = (_my < display_get_gui_height() / 2);

            card.x = _anchorLeft ? (_mx + PLOT_HOVER_CURSOR_GAP) : (_mx - PLOT_HOVER_CURSOR_GAP - _cardW);
            card.y = _anchorTop  ? (_my + PLOT_HOVER_CURSOR_GAP) : (_my - PLOT_HOVER_CURSOR_GAP - _cardH);
        }
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event. No-ops while fully faded out.
    static Draw = function() {
        if (alpha <= 0) return;
        card.Draw(alpha);
    }
}
