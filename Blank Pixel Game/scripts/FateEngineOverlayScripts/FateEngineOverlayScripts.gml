// -----------------------------------------------------------
// FateEngineOverlayScripts -- the real Fate Engine session overlay: the
// full-screen dim + freeze, the drum machine itself, and temporary
// leave/spin/cashout buttons. 2026-07-13 request.
//
// This replaces oFateEngineDrumTest, the old visual-only test harness --
// deleted 2026-07-13 now that this overlay fully supersedes it.
//
// Opened by clicking the XP bar (XpBarWidgetHitRect(), wired in
// oUnitControl/Step_0.gml). While open:
//   - global.matchSpeed is forced to 0 (restored to whatever it was on
//     Leave()) -- freezes the battlefield. The drums themselves do NOT
//     read global.matchSpeed at all (2026-07-13, FateEngineDrumScripts.gml)
//     -- they're a UI mechanic independent of the match's speed control, so
//     freezing the battlefield doesn't freeze them.
//   - Selection is cleared instantly and targeting/menus/blueprint-drag are
//     all canceled (see Open()).
//   - oUnitControl/Step_0.gml early-exits out of every other Step system
//     (hover controllers, drag-select, menus, camera pan) so nothing shows
//     hover data or responds to input except this overlay -- see that
//     file's isOpen guard.
//   - Draw() is called first thing in oUnitControl/Draw_64.gml (before
//     sRulerBar/sMainUIBarBottom/sUISpellsCloth) so its dim rectangle sits
//     BEHIND the persistent UI bar, which is drawn immediately after and
//     stays fully visible/on top.
//
// Cashout() grants real rewards -- FateEngineRollReward() (2026-07-13,
// FateEngineDrumScripts.gml) is the actual weighted table now, built from
// the currently-registered building types and the 5 currently-active base
// resources, and FateEngineItem carries enough data (rewardType/rewardData)
// for Cashout() below to apply it for real.
//
// ASSUMPTIONS made building this (none of these were explicitly specified;
// flagging per project convention so they can be sanity-checked):
//   1. A fate token is spent ONLY on the spin that STARTS a session -- once
//      isSessionActive is true, further Spin() calls are free ("continue
//      spinning" read as already-paid-for, not a per-pull cost). If tokens
//      should actually be spent every spin, change Spin()'s gate below.
//   2. "Leave... only able to be pressed if a session is not active with a
//      fate token" was read as: Leave is disabled for the whole duration a
//      session is active (a token's already been spent on it) -- you must
//      Cashout to end a session before you can Leave. Once no session is
//      active, Leave always works.
//   3. Buttons are plain rectangles + text per the explicit "temporary"
//      framing in the request -- no generic button sprite/pattern exists
//      yet elsewhere in the project to reuse.
//   4. Spin()'s deceleration duration (FATE_ENGINE_SPIN_DURATION_STEPS) is
//      an arbitrary fixed value -- there's no lever yet to tie real timing
//      to, per the request ("I will add a lever later that will do the
//      spinning, so make the 'spin' be a simple function call").
//   5. The reward table's odds/amounts (FATE_ENGINE_REWARD_*,
//      FateEngineDrumScripts.gml) are a first-pass placeholder split, not a
//      tuned design -- see that file's header.
// -----------------------------------------------------------

#macro FATE_ENGINE_SPIN_DURATION_STEPS 90   // steps (drums run independent of global.matchSpeed, see FateEngineDrumScripts.gml) the drums spend in full "spinning" state before Stop() is called and they begin decelerating/landing

// Render scale for sMainUIBarBottom (oUnitControl/Draw_64.gml) AND
// sFateEngineBody here -- same value shared deliberately so the machine's
// bottom-edge-alignment math against the UI bar (see the constructor) stays
// correct if this ever changes; keep both draw calls' scale arguments in
// sync with this macro if it does.
#macro FATE_ENGINE_MACHINE_UI_BAR_SCALE 2

#macro FATE_ENGINE_BUTTON_WIDTH   180
#macro FATE_ENGINE_BUTTON_HEIGHT  50
#macro FATE_ENGINE_BUTTON_GAP     20
#macro FATE_ENGINE_BUTTON_TOP_Y   30

/// @function FateEngineButtonRects()
/// @description GUI-space bounding rects of the 3 temporary overlay
///        buttons (leave/cashout/spin), centered as a row along the top of
///        the screen. Computed fresh each call (cheap, no state) so Draw()
///        and Update() always agree on hit boxes -- same "derive, don't
///        duplicate" idiom as ArmyLimitWidgetIconRect/XpBarWidgetHitRect.
/// @returns {Struct} { leave, cashout, spin }, each { x1, y1, x2, y2 }.
function FateEngineButtonRects() {
    var _centerX = display_get_gui_width() / 2;
    var _totalW  = FATE_ENGINE_BUTTON_WIDTH * 3 + FATE_ENGINE_BUTTON_GAP * 2;
    var _x1      = _centerX - _totalW / 2;

    var _leave = {
        x1: _x1, y1: FATE_ENGINE_BUTTON_TOP_Y,
        x2: _x1 + FATE_ENGINE_BUTTON_WIDTH, y2: FATE_ENGINE_BUTTON_TOP_Y + FATE_ENGINE_BUTTON_HEIGHT
    };

    var _x2 = _x1 + FATE_ENGINE_BUTTON_WIDTH + FATE_ENGINE_BUTTON_GAP;
    var _cashout = {
        x1: _x2, y1: FATE_ENGINE_BUTTON_TOP_Y,
        x2: _x2 + FATE_ENGINE_BUTTON_WIDTH, y2: FATE_ENGINE_BUTTON_TOP_Y + FATE_ENGINE_BUTTON_HEIGHT
    };

    var _x3 = _x2 + FATE_ENGINE_BUTTON_WIDTH + FATE_ENGINE_BUTTON_GAP;
    var _spin = {
        x1: _x3, y1: FATE_ENGINE_BUTTON_TOP_Y,
        x2: _x3 + FATE_ENGINE_BUTTON_WIDTH, y2: FATE_ENGINE_BUTTON_TOP_Y + FATE_ENGINE_BUTTON_HEIGHT
    };

    return { leave: _leave, cashout: _cashout, spin: _spin };
}

/// @function FateEngineOverlay()
/// @description The Fate Engine session overlay -- see file header for
///        full behavior. Not a GM instance -- a plain struct, same pattern
///        as every other HUD controller (BlueprintController,
///        SelectionController, XpBarWidget). Owner (oUnitControl) calls
///        Update() once per Step while relevant and Draw() once per
///        Draw GUI, and is responsible for routing the XP bar click into
///        Open() -- see oUnitControl/Step_0.gml/Draw_64.gml.
function FateEngineOverlay() constructor {
    isOpen          = false;
    isSessionActive = false;
    savedMatchSpeed = 1;
    spinTimer       = 0;
    resultsBanked   = true;  // no spin in flight -- see Spin()/Update()
    pendingRewards  = [];    // Array<Struct.FateEngineItem> -- banked once per landed spin, cleared on Cashout()

    var _centerX = display_get_gui_width() / 2;

    // sMainUIBarBottom is drawn via draw_sprite_ext(sMainUIBarBottom, 0, 0,
    // 1080, 2, 2, ...) (oUnitControl/Draw_64.gml) -- same
    // draw-y/scale numbers reproduced here, then backed out through the
    // sprite's own yoffset (its custom origin's actual pixel value,
    // NOT assumed to equal its height) to get the exact GUI-space Y of its
    // top edge. That top edge IS "the top of the bottom UI bar" the fate
    // engine machine's bottom must align with, per request -- same
    // "derive from the real sprite, don't hardcode a guessed offset" idiom
    // as ArmyLimitWidgetIconRect/XpBarWidgetHitRect.
    var _uiBarDrawY = 1080;
    var _uiBarTopY  = _uiBarDrawY - sprite_get_yoffset(sMainUIBarBottom) * FATE_ENGINE_MACHINE_UI_BAR_SCALE;
    bodyBottomY = _uiBarTopY;

    var _drumRadius = 56;
    var _drumHeight = _drumRadius * 2;
    var _drumY      = (bodyBottomY - 320) + _drumHeight; // same relative drum placement oFateEngineDrumTest used

    drums = [
        new FateDrum(_centerX - 104, _drumY, _drumRadius),
        new FateDrum(_centerX,       _drumY, _drumRadius),
        new FateDrum(_centerX + 104, _drumY, _drumRadius),
    ];
    // Unlike oFateEngineDrumTest, drums do NOT auto-spin here -- spinning
    // only starts once Spin() is actually called (button now, lever
    // later), per 2026-07-13 request.

    /// @function Open(_selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController)
    /// @description Opens the overlay: freezes the match (saves
    ///        global.matchSpeed, sets it to 0), and resets player input
    ///        state to a clean slate -- clears selection/targeting,
    ///        closes every dropdown menu, cancels an in-progress blueprint
    ///        drag. Dependencies are passed in explicitly rather than
    ///        reached for by name, matching how every other cross-
    ///        controller interaction in oUnitControl/Step_0.gml already
    ///        works (e.g. castleBonusHoverController.Step's params) --
    ///        this struct has no implicit access to oUnitControl's other
    ///        instance variables. No-ops if already open.
    /// @param {Struct.SelectionController} _selectionController
    /// @param {Struct.OrderMenu} _orderMenu
    /// @param {Struct.CastleGarrisonMenu} _castleGarrisonMenu
    /// @param {Struct.ArmyLimitMenu} _armyLimitMenu
    /// @param {Struct.BlueprintController} _blueprintController
    /// @returns {Struct.FateEngineOverlay} self
    static Open = function(_selectionController, _orderMenu, _castleGarrisonMenu, _armyLimitMenu, _blueprintController) {
        if (isOpen) return self;

        isOpen          = true;
        savedMatchSpeed = global.matchSpeed;
        global.matchSpeed = 0;

        // Pre-existing suppression hook (PlotHoverScripts.gml, declared
        // `global.fateEngineOverlayActive = false` with a comment saying
        // "the real overlay can flip it later without this file needing
        // another pass") -- BuildingHoverController/PlotHoverController's
        // own suppression checks already OR this flag in. Step_0.gml's
        // isOpen early-exit guard already stops those Step() calls from
        // running at all while this overlay is open, so this is belt-and-
        // suspenders rather than load-bearing -- but flipping it keeps this
        // already-wired hook from sitting permanently false/unused.
        global.fateEngineOverlayActive = true;

        _selectionController.Deselect();
        _orderMenu.Close();
        _castleGarrisonMenu.Close();
        _armyLimitMenu.Close();
        if (_blueprintController.dragging) _blueprintController.CancelDrag();

        return self;
    }

    /// @function Leave()
    /// @description Closes the overlay and restores global.matchSpeed to
    ///        whatever it was before Open(). No-ops if not open, or if a
    ///        session is currently active (see file header assumption 2) --
    ///        Cashout first.
    /// @returns {Struct.FateEngineOverlay} self
    static Leave = function() {
        if (!isOpen || isSessionActive) return self;
        isOpen = false;
        global.matchSpeed = savedMatchSpeed;
        global.fateEngineOverlayActive = false; // see Open()
        return self;
    }

    /// @function Spin()
    /// @description Simple function call per 2026-07-13 request (a lever
    ///        will call this directly later). If no session is active,
    ///        spends one Fate Token (TEAM.PLAYER) to start one -- no-ops if
    ///        there isn't one to spend. Either way, spins every drum. No-op
    ///        if a previous spin hasn't finished landing yet (ignores extra
    ///        clicks rather than stacking/corrupting the in-flight spin).
    /// @returns {Struct.FateEngineOverlay} self
    static Spin = function() {
        for (var i = 0; i < array_length(drums); i++) {
            if (drums[i].state != "stopped") return self; // still mid-spin from a previous pull
        }

        if (!isSessionActive) {
            if (global.resources[TEAM.PLAYER].fateTokens <= 0) return self; // nothing to spend -- can't start a session
            global.resources[TEAM.PLAYER].fateTokens -= 1;
            isSessionActive = true;
            pendingRewards  = [];
        }

        for (var i = 0; i < array_length(drums); i++) {
            drums[i].Spin();
        }
        spinTimer     = FATE_ENGINE_SPIN_DURATION_STEPS;
        resultsBanked = false;

        return self;
    }

    /// @function Cashout()
    /// @description Ends the active session and actually grants everything
    ///        in pendingRewards -- 2026-07-13: FateEngineItem now carries
    ///        real reward data (FateEngineDrumScripts.gml), so this is no
    ///        longer a stub. "resource" items add rewardData.amount to
    ///        global.resources[TEAM.PLAYER][rewardData.resourceName];
    ///        "blueprint" items call AddBlueprint(TEAM.PLAYER,
    ///        rewardData.buildingType, 1) (BlueprintScripts.gml). No-ops if
    ///        no session is active.
    /// @returns {Struct.FateEngineOverlay} self
    static Cashout = function() {
        if (!isSessionActive) return self;

        for (var i = 0; i < array_length(pendingRewards); i++) {
            var _reward = pendingRewards[i];
            if (_reward.rewardType == "resource") {
                global.resources[TEAM.PLAYER][$ _reward.rewardData.resourceName] += _reward.rewardData.amount;
            } else if (_reward.rewardType == "blueprint") {
                AddBlueprint(TEAM.PLAYER, _reward.rewardData.buildingType, 1);
            }
        }

        isSessionActive = false;
        pendingRewards  = [];
        return self;
    }

    /// @function Update()
    /// @description Call once per Step while this overlay exists (safe to
    ///        call unconditionally -- no-ops if not open). Advances the
    ///        drums, hands off spin -> stop once spinTimer runs out, banks
    ///        a finished spin's results into pendingRewards, and handles
    ///        clicks on the 3 temporary buttons.
    /// @returns {Struct.FateEngineOverlay} self
    static Update = function() {
        if (!isOpen) return self;

        // 2026-07-13: drum animation is now independent of global.matchSpeed
        // (FateEngineDrumScripts.gml) -- no need to flip it around Step()
        // anymore, so this just calls it directly.
        for (var i = 0; i < array_length(drums); i++) {
            drums[i].Step();
        }

        if (spinTimer > 0) {
            spinTimer -= 1;
            if (spinTimer <= 0) {
                for (var i = 0; i < array_length(drums); i++) {
                    drums[i].Stop();
                }
            }
        }

        if (!resultsBanked) {
            var _allStopped = true;
            for (var i = 0; i < array_length(drums); i++) {
                if (drums[i].state != "stopped") { _allStopped = false; break; }
            }
            if (_allStopped) {
                for (var i = 0; i < array_length(drums); i++) {
                    array_push(pendingRewards, drums[i].GetLockedItem());
                }
                resultsBanked = true;
            }
        }

        if (mouse_check_button_pressed(mb_left)) {
            var _gx    = device_mouse_x_to_gui(0);
            var _gy    = device_mouse_y_to_gui(0);
            var _rects = FateEngineButtonRects();

            var _onLeave   = (_gx >= _rects.leave.x1   && _gx <= _rects.leave.x2   && _gy >= _rects.leave.y1   && _gy <= _rects.leave.y2);
            var _onCashout = (_gx >= _rects.cashout.x1 && _gx <= _rects.cashout.x2 && _gy >= _rects.cashout.y1 && _gy <= _rects.cashout.y2);
            var _onSpin    = (_gx >= _rects.spin.x1    && _gx <= _rects.spin.x2    && _gy >= _rects.spin.y1    && _gy <= _rects.spin.y2);

            if (_onLeave && !isSessionActive) {
                Leave();
            } else if (_onCashout && isSessionActive) {
                Cashout();
            } else if (_onSpin && (isSessionActive || global.resources[TEAM.PLAYER].fateTokens > 0)) {
                Spin();
            }
        }

        return self;
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event, FIRST -- before
    ///        sRulerBar/sMainUIBarBottom/sUISpellsCloth in
    ///        oUnitControl/Draw_64.gml -- so the dim rectangle sits behind
    ///        the persistent UI bar rather than covering it. No-ops if not
    ///        open. Draws, in order: the 0.75-alpha black dim rect, each
    ///        drum's backing panel + the drums themselves (same visuals as
    ///        oFateEngineDrumTest), the machine body sprite, a landed-item
    ///        hover tooltip (carried over from oFateEngineDrumTest), and
    ///        the 3 temporary buttons.
    static Draw = function() {
        if (!isOpen) return;

        draw_set_color(c_black);
        draw_set_alpha(0.75);
        draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
        draw_set_alpha(1);

        draw_set_color(make_color_rgb(0xE1, 0xD3, 0xEA));
        for (var i = 0; i < array_length(drums); i++) {
            var _drum = drums[i];
            draw_rectangle(_drum.x - 50, _drum.y - 69, _drum.x + 50, _drum.y + 69, false);
        }

        for (var i = 0; i < array_length(drums); i++) {
            drums[i].Draw();
        }

        var _centerX = display_get_gui_width() / 2;
        draw_sprite_ext(sFateEngineBody, 0, _centerX, bodyBottomY, FATE_ENGINE_MACHINE_UI_BAR_SCALE, FATE_ENGINE_MACHINE_UI_BAR_SCALE, 0, c_white, 1);

        var _mx = device_mouse_x_to_gui(0);
        var _my = device_mouse_y_to_gui(0);
        for (var i = 0; i < array_length(drums); i++) {
            var _drum  = drums[i];
            var _halfW = 44;
            var _halfH = _drum.radius + 48;
            if (abs(_mx - _drum.x) > _halfW || abs(_my - _drum.y) > _halfH) continue;
            var _item = _drum.GetLockedItem();
            if (_item == undefined) continue;
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
            draw_set_color(c_white);
            draw_text(_mx + 12, _my + 12, _item.label);
        }

        DrawButtons();
    }

    /// @function DrawButtons()
    /// @description Draws the 3 temporary leave/cashout/spin buttons,
    ///        greyed out when disabled. Internal helper for Draw().
    static DrawButtons = function() {
        var _rects = FateEngineButtonRects();

        var _leaveEnabled   = !isSessionActive;
        var _cashoutEnabled = isSessionActive;
        var _spinEnabled    = isSessionActive || global.resources[TEAM.PLAYER].fateTokens > 0;

        DrawOneButton(_rects.leave,   "Leave",   _leaveEnabled);
        DrawOneButton(_rects.cashout, "Cashout", _cashoutEnabled);
        DrawOneButton(_rects.spin,    "Spin",    _spinEnabled);
    }

    /// @function DrawOneButton(_rect, _label, _enabled)
    /// @description Draws one plain rectangle+text button -- placeholder
    ///        styling per the request's explicit "temporary" framing; no
    ///        generic button sprite exists yet elsewhere in the project.
    /// @param {Struct} _rect { x1, y1, x2, y2 }
    /// @param {String} _label
    /// @param {Bool} _enabled
    static DrawOneButton = function(_rect, _label, _enabled) {
        draw_set_alpha(1);
        draw_set_color(_enabled ? make_color_rgb(0x3A, 0x2E, 0x4A) : make_color_rgb(0x55, 0x55, 0x55));
        draw_rectangle(_rect.x1, _rect.y1, _rect.x2, _rect.y2, false);
        draw_set_color(c_white);
        draw_rectangle(_rect.x1, _rect.y1, _rect.x2, _rect.y2, true);

        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(_enabled ? c_white : make_color_rgb(0xAA, 0xAA, 0xAA));
        draw_text((_rect.x1 + _rect.x2) / 2, (_rect.y1 + _rect.y2) / 2, _label);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    }
}
