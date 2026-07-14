// -----------------------------------------------------------
// HUDWidgetScripts -- fixed-position top-level HUD readouts that sit
// alongside the resource bar (DrawResourceBar, ResourceUIScripts.gml) but
// don't fit that file's specific "one row of resource-icon counts" scope.
// Castle Health Widget (2026-07-13 request) is the first of these; an
// Army Limit Widget is planned to follow in this same file.
// -----------------------------------------------------------

#macro CASTLE_HEALTH_WIDGET_X        452 // left edge the icon's LEFT EDGE is anchored to -- 2026-07-13 request ("top left position of this widget")
#macro CASTLE_HEALTH_WIDGET_Y        856 // shared vertical anchor for BOTH the icon and its text -- same "one Y used for both draws" convention DrawResourceBar's _cy uses (ResourceUIScripts.gml); see DrawCastleHealthWidget's doc comment for the caveat this implies given sCastleHealthIcon's off-center origin
#macro CASTLE_HEALTH_WIDGET_TEXT_GAP 10  // px from the icon's right edge to the health text -- matches RESOURCE_BAR_TEXT_GAP's value (ResourceUIScripts.gml) for visual consistency; not an explicit spec number, flag if a different gap is wanted

/// @function DrawCastleHealthWidget(_team)
/// @description Call once per Draw GUI event. Draws _team's castle health
///        as "[sCastleHealthIcon] current/max" starting at
///        (CASTLE_HEALTH_WIDGET_X, CASTLE_HEALTH_WIDGET_Y) -- 2026-07-13
///        request. No-ops if _team currently has no castle instance
///        (shouldn't normally happen mid-match, but avoids a crash rather
///        than reading fields off `noone`).
///
///        X placement: sCastleHealthIcon has a Custom sprite origin (11,10
///        out of a 24x22 frame) -- unlike sResourceIcons (DrawResourceBar),
///        which is a clean Middle-Center origin sprite, this one is NOT
///        exactly centered. Per the request, its drawn LEFT EDGE is
///        anchored exactly at CASTLE_HEALTH_WIDGET_X by drawing the sprite
///        at (CASTLE_HEALTH_WIDGET_X + sprite_get_xoffset(sCastleHealthIcon),
///        CASTLE_HEALTH_WIDGET_Y): adding the sprite's own xoffset shifts
///        its origin exactly xoffset px right of its true left edge, which
///        cancels out and lands that left edge precisely on the anchor.
///        sprite_get_xoffset/sprite_get_width are read live (not hardcoded
///        numbers) so this keeps working if the sprite is ever re-exported
///        at a different size/origin. The sprite is drawn via plain
///        draw_sprite (scale 1) -- per the request, it's already exported
///        at the UI's 2x graphical scale, so it must NOT be scaled up
///        again here.
///
///        Y placement: CASTLE_HEALTH_WIDGET_Y is used directly, unmodified,
///        as the shared vertical anchor for BOTH the icon and the text
///        that follows it -- same "one shared Y for icon + text" pattern
///        DrawResourceBar uses for its own _cy. Per the request ("sprite is
///        center aligned, so draw it vertically aligned with the text"),
///        no yoffset correction is applied the way X gets an xoffset
///        correction. Since sCastleHealthIcon's origin (yoffset 10) isn't
///        exactly half its 22px height, this is a ~1px approximation of
///        true vertical centering -- accepted per the request's own
///        "center aligned" framing rather than computed more precisely.
///
///        Text: fntResource (the same font DrawResourceBar uses for its
///        counts) in HOVER_CARD_TEXT_COLOR (HoverCardScripts.gml) -- this
///        project's one standard "HUD number" color/font pairing, so the
///        widget reads as part of the same UI language as the resource
///        bar. Per the request ("standard font coloring (and shadow)"), a
///        1px drop shadow is drawn first in HOVER_CARD_SHADOW_COLOR,
///        offset by HOVER_CARD_SHADOW_OFFSET (both HoverCardScripts.gml) --
///        this project's only defined shadow color/offset, otherwise only
///        ever applied via Scribble's .blend()/.draw() (DrawCardTextWithShadow,
///        HoverCardScripts.gml). This widget doesn't use Scribble, so the
///        same shadow-then-real-text draw ORDER is replicated by hand with
///        two plain draw_text calls instead -- values reused, mechanism is
///        new. NOTE: DrawResourceBar itself has no shadow (a plain,
///        unshadowed draw_text) -- this widget is deliberately NOT matching
///        that specific example, since the request explicitly asked for a
///        shadow here.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
function DrawCastleHealthWidget(_team) {
    var _castle = GetTeamCastle(_team);
    if (!instance_exists(_castle)) return;

    var _iconX = CASTLE_HEALTH_WIDGET_X + sprite_get_xoffset(sCastleHealthIcon);
    draw_sprite(sCastleHealthIcon, 0, _iconX, CASTLE_HEALTH_WIDGET_Y);

    var _textX = CASTLE_HEALTH_WIDGET_X + sprite_get_width(sCastleHealthIcon) + CASTLE_HEALTH_WIDGET_TEXT_GAP;

    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_font(fntResource);

    var _current = GetCurrentHealth(_castle);
    var _max     = _castle.maxHealth;
    var _text    = string(_current) + "/" + string(_max);

    // Shadow pass first, real text on top -- same draw ORDER
    // DrawCardTextWithShadow (HoverCardScripts.gml) uses for Scribble text,
    // replicated here with plain draw_text since this widget has no
    // Scribble element to call .blend()/.draw() on.
    draw_set_color(HOVER_CARD_SHADOW_COLOR);
    draw_text(_textX, CASTLE_HEALTH_WIDGET_Y + HOVER_CARD_SHADOW_OFFSET, _text);

    draw_set_color(HOVER_CARD_TEXT_COLOR);
    draw_text(_textX, CASTLE_HEALTH_WIDGET_Y, _text);

    // Reset to the default font -- same reasoning as DrawResourceBar's own
    // reset (ResourceUIScripts.gml): nothing else calls draw_set_font, so
    // leaving fntResource active would leak into anything drawn after this
    // in the same Draw GUI event.
    draw_set_font(-1);
}

// -----------------------------------------------------------
// Army Limit Widget -- 2026-07-13 request. Second HUD widget in this file
// (see header). Unlike DrawCastleHealthWidget, this one is also
// CLICKABLE -- clicking its icon opens ArmyLimitMenu (ArmyLimitMenu.gml),
// a "Unit Limits" dropdown. This file only owns the passive HUD readout
// (icon + count/max) and the shared icon-hit-rect math the click-to-open
// check needs; the menu itself, its rows, and the row-click selection
// behavior all live in ArmyLimitMenu.gml, same file-per-menu split as
// CastleGarrisonMenu.gml.
// -----------------------------------------------------------

#macro ARMY_LIMIT_WIDGET_X     452 // same X anchor as CASTLE_HEALTH_WIDGET_X -- 2026-07-13 request ("same offset and drawing parameters for horizontal alignment")
#macro ARMY_LIMIT_WIDGET_GAP_Y 10  // px from the Castle Health Icon's BOTTOM edge to the Army Limit Icon's TOP edge -- 2026-07-13 request, exact wording: "10px below this one (from the bottom edge of the Health Icon sprite to the top edge of the army limit icon sprite)"

/// @function ArmyLimitWidgetY()
/// @description The shared vertical anchor (Y) for the Army Limit Widget's
///        icon and text -- same role CASTLE_HEALTH_WIDGET_Y plays for that
///        widget, just COMPUTED rather than a flat macro, since it depends
///        on both sCastleHealthIcon's and sArmyLimitIcon's actual
///        dimensions/origins. Derivation: sCastleHealthIcon's bottom edge
///        is CASTLE_HEALTH_WIDGET_Y + (its height - its yoffset) -- same
///        "anchor + (size - offset)" edge math DrawCastleHealthWidget's X
///        placement uses, just for the bottom edge instead of the right
///        edge. ARMY_LIMIT_WIDGET_GAP_Y below THAT is the Army Limit
///        Icon's own top edge; adding its yoffset back converts that top
///        edge into the origin-relative Y draw_sprite actually needs
///        (mirrors CASTLE_HEALTH_WIDGET_Y's own X-offset-cancels-origin
///        trick, just assembled here instead of being a flat number,
///        since two sprites' geometry are involved instead of one).
///        Recomputed on every call rather than cached -- cheap sprite
///        metadata lookups, same "don't cache" convention as
///        GetStationedPassiveBonuses/TrainingTypeLimit.
/// @returns {Real}
function ArmyLimitWidgetY() {
    var _healthBottomEdge = CASTLE_HEALTH_WIDGET_Y + (sprite_get_height(sCastleHealthIcon) - sprite_get_yoffset(sCastleHealthIcon));
    var _limitTopEdge     = _healthBottomEdge + ARMY_LIMIT_WIDGET_GAP_Y;
    return _limitTopEdge + sprite_get_yoffset(sArmyLimitIcon);
}

/// @function ArmyLimitWidgetIconRect()
/// @description GUI-space bounding rect of the Army Limit Widget's icon
///        (sArmyLimitIcon) -- computed from the EXACT same anchor/offset
///        math DrawArmyLimitWidget uses to draw it, so oUnitControl's
///        click-to-open hit-test (Step_0.gml) can never drift out of sync
///        with where the icon is actually rendered.
/// @returns {Struct} { x1, y1, x2, y2 }, all GUI-space.
function ArmyLimitWidgetIconRect() {
    var _y1 = ArmyLimitWidgetY() - sprite_get_yoffset(sArmyLimitIcon);
    var _x1 = ARMY_LIMIT_WIDGET_X;
    return {
        x1: _x1,
        y1: _y1,
        x2: _x1 + sprite_get_width(sArmyLimitIcon),
        y2: _y1 + sprite_get_height(sArmyLimitIcon)
    };
}

/// @function DrawArmyLimitWidget(_team)
/// @description Call once per Draw GUI event. Draws _team's current army
///        usage as "[sArmyLimitIcon] current/max" starting at
///        (ARMY_LIMIT_WIDGET_X, ArmyLimitWidgetY()) -- 2026-07-13 request.
///        Same X-anchor/offset/font/color/shadow drawing parameters as
///        DrawCastleHealthWidget (see that function's doc comment for the
///        full reasoning) -- only the icon sprite, Y position, and the
///        counted values differ.
///
///        "current" is _team's TOTAL unit count -- live (GatherTeamUnits,
///        GatherScripts.gml) + stationed (CountTeamStationedUnits,
///        StationScripts.gml) -- matching this session's established
///        correction that stationed units still count against
///        global.armyLimit (TrainingScripts.gml). Deliberately does NOT
///        add queued units into "current" -- a unit still training isn't
///        a unit yet, per the request's literal "number of units" wording
///        -- even though queued units DO count toward whether MORE can be
///        queued (TrainingTryQueueUnit's own check). "max" is
///        global.armyLimit[_team] directly.
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY.
function DrawArmyLimitWidget(_team) {
    var _y = ArmyLimitWidgetY();

    var _iconX = ARMY_LIMIT_WIDGET_X + sprite_get_xoffset(sArmyLimitIcon);
    draw_sprite(sArmyLimitIcon, 0, _iconX, _y);

    var _textX = ARMY_LIMIT_WIDGET_X + sprite_get_width(sArmyLimitIcon) + CASTLE_HEALTH_WIDGET_TEXT_GAP;

    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_font(fntResource);

    var _current = array_length(GatherTeamUnits(_team)) + CountTeamStationedUnits(_team);
    var _max     = global.armyLimit[_team];
    var _text    = string(_current) + "/" + string(_max);

    // Same shadow-then-real-text draw order as DrawCastleHealthWidget.
    draw_set_color(HOVER_CARD_SHADOW_COLOR);
    draw_text(_textX, _y + HOVER_CARD_SHADOW_OFFSET, _text);

    draw_set_color(HOVER_CARD_TEXT_COLOR);
    draw_text(_textX, _y, _text);

    draw_set_font(-1); // same reset reasoning as DrawCastleHealthWidget/DrawResourceBar
}
