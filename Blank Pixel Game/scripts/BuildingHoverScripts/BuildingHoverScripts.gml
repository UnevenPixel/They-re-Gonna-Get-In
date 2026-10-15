// Hover/tooltip overlay for placed building instances AND blueprint UI
// slots -- icon row, cost/queue row, paired unit card. See BuildingHoverScripts.md.

#macro BUILDING_HOVER_ICON_ROW_GAP_TOP 4 // native, gap between the name plate and the icon row
#macro BUILDING_HOVER_ICON_GAP_X       4 // native, horizontal gap between adjacent icon-row columns
#macro BUILDING_HOVER_ICON_LABEL_GAP_Y 2 // native, gap between an icon's bottom edge and its label text below it
#macro BUILDING_HOVER_ROW_TO_BODY_GAP  4 // native, gap between the icon row's bottom and the body text below it
#macro BUILDING_HOVER_COST_ROW_GAP_TOP 4 // native, gap between the card's last content and the cost/queue row (mutually exclusive, see .md)
#macro BUILDING_HOVER_QUEUE_GAP_X      6 // already-scaled px, gap between the queue row's 3 sections -- defined in on-screen px (not native*scale) since it sits between a scaled sprite and unscaled text widths
#macro BUILDING_HOVER_QUEUE_BAR_HEIGHT 10 // native, progress bar height (scaled)
#macro BUILDING_HOVER_QUEUE_BAR_MIN_WIDTH 20 // already-scaled px floor so the bar never vanishes/goes negative

// Per-instance counter, same reasoning as HoverCard's global.__hoverCardNextId.
global.__buildingHoverExtrasNextId = 0;

/// @function BuildingHoverTitleCase(_word)
/// @description Capitalizes the first letter only -- "wheat" -> "Wheat".
/// @param {String} _word
/// @returns {String}
function BuildingHoverTitleCase(_word) {
    if (string_length(_word) == 0) return _word;
    return string_upper(string_copy(_word, 1, 1)) + string_copy(_word, 2, string_length(_word) - 1);
}

/// @function BuildingHoverDescriptionText(_def)
/// @description Normal body text -- auto-generated statement of what this building mechanically does. See .md.
/// @param {Struct.BuildingDefinition} _def
/// @returns {String}
function BuildingHoverDescriptionText(_def) {
    if (_def.productionResource != undefined) {
        return $"Produces {ResourceIconTag(_def.productionResource)}{BuildingHoverTitleCase(_def.productionResource)}";
    }

    if (_def.trainsUnit != undefined) {
        var _unitDef = GetUnitDefinition(_def.trainsUnit);
        return (_unitDef != undefined) ? $"Trains {UnitIconTag(_unitDef)}{_unitDef.name}" : "Trains a unit";
    }

    // Neither production nor training -- fall back to the descriptive field
    // directly rather than showing a blank line.
    return _def.description;
}

/// @function BuildingHoverTimerText(_def, _building, _isBlueprint, _team)
/// @description Label drawn below the Timer icon -- rate/sec or train-time/sec, colored per live stationed bonuses vs. base. See .md.
/// @param {Struct.BuildingDefinition} _def
/// @param {Id.Instance|Constant.NoOne} _building A placed building instance, or noone when _isBlueprint is true.
/// @param {Bool} _isBlueprint
/// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY -- indexes GetStationedPassiveBonuses.
/// @returns {String}
function BuildingHoverTimerText(_def, _building, _isBlueprint, _team) {
    var _bonus = GetStationedPassiveBonuses(_team);

    if (_def.productionResource != undefined) {
        var _baseRate = _isBlueprint ? _def.productionRate : _building.productionRate;
        var _goldBonus = (_def.productionResource == "gold") ? _bonus.goldProductionBonus : 0;
        var _multiplier = 1 + _bonus.allResourceProductionBonus + _goldBonus;
        var _effectiveRate = round(_baseRate * _multiplier * 100) / 100;

        var _rateText = string(_effectiveRate);
        if (_effectiveRate > _baseRate) {
            _rateText = $"[{PLOT_HOVER_GOOD_COLOR_TAG}]{_rateText}[/c]";
        } else if (_effectiveRate < _baseRate) {
            _rateText = $"[{PLOT_HOVER_BAD_COLOR_TAG}]{_rateText}[/c]";
        }
        return $"{_rateText} /sec";
    }

    if (_def.trainsUnit != undefined) {
        var _baseTime = _isBlueprint ? _def.trainTime : _building.trainTime;
        var _multiplier = 1 + _bonus.trainingSpeedBonus;
        var _effectiveTime = (_multiplier > 0) ? round((_baseTime / _multiplier) * 10) / 10 : _baseTime;

        var _timeText = string(_effectiveTime);
        if (_effectiveTime < _baseTime) {
            _timeText = $"[{PLOT_HOVER_GOOD_COLOR_TAG}]{_timeText}[/c]";
        } else if (_effectiveTime > _baseTime) {
            _timeText = $"[{PLOT_HOVER_BAD_COLOR_TAG}]{_timeText}[/c]";
        }
        return $"{_timeText} sec";
    }

    return "";
}

/// @function BuildingHoverResourceLimitText(_def, _building, _isBlueprint)
/// @description Label under the Item/Unit Window for resource buildings only -- flat limit for blueprints, "remaining/total" off the live instance for placed buildings. See .md.
/// @param {Struct.BuildingDefinition} _def
/// @param {Id.Instance|Constant.NoOne} _building A placed building instance, or noone when _isBlueprint is true.
/// @param {Bool} _isBlueprint
/// @returns {String}
function BuildingHoverResourceLimitText(_def, _building, _isBlueprint) {
    if (_def.productionResource == undefined) return "";

    if (_isBlueprint) {
        return (_def.resourceLimit == undefined) ? "" : string(_def.resourceLimit);
    }

    if (_building.resourceLimit == undefined) return "";
    return $"{_building.resourceLimit - _building.producedTotal}/{_building.resourceLimit}";
}

/// @function BuildingHoverHealthText(_def, _building, _isBlueprint)
/// @description Label under the production-amount line -- flat maxHealth for blueprints, "remaining/max" off the live instance for placed buildings (via GetCurrentHealth). Always returns a value, unlike BuildingHoverResourceLimitText.
/// @param {Struct.BuildingDefinition} _def
/// @param {Id.Instance|Constant.NoOne} _building A placed building instance, or noone when _isBlueprint is true.
/// @param {Bool} _isBlueprint
/// @returns {String}
function BuildingHoverHealthText(_def, _building, _isBlueprint) {
    if (_isBlueprint) return string(_def.maxHealth);
    return $"{GetCurrentHealth(_building)}/{_building.maxHealth}";
}

/// @function BuildingHoverItemIcon(_def)
/// @description Resolves the sprite/frame for the Item/Unit Window -- a resource icon for production buildings, or the trained unit's small sprite for training buildings.
/// @param {Struct.BuildingDefinition} _def
/// @returns {Struct|Undefined} { sprite, image } or undefined if this building neither produces nor trains anything.
function BuildingHoverItemIcon(_def) {
    if (_def.productionResource != undefined) {
        return { sprite: sResourceIcons, image: ResourceIconIndex(_def.productionResource) };
    }

    if (_def.trainsUnit != undefined) {
        var _unitDef = GetUnitDefinition(_def.trainsUnit);
        return (_unitDef != undefined) ? { sprite: _unitDef.smallSprite, image: 0 } : undefined;
    }

    return undefined;
}

/// @function BuildingHoverExtras()
/// @description Owns the icon-row/cost-row/queue-row Scribble elements and draws them above/below a HoverCard's own content. Call Layout() whenever content changes, feed its result into HoverCard.Show(), then Draw() right after HoverCard.Draw(). See .md.
function BuildingHoverExtras() constructor {
    __id = global.__buildingHoverExtrasNextId++;

    hasTimerText    = false;
    hasLimitText    = false;
    hasItemIcon     = false;
    showCostRow     = false;
    buildingSprite  = noone;
    itemIconSprite  = noone;
    itemIconImage   = 0;
    itemIconOffsetY = 0; // vertical draw offset for the item icon only -- 0 for the (already-centered) resource-icon case, (spriteHeight/2)*HOVER_CARD_SCALE for the bottom-anchored unit smallSprite case

    // Placed training building queue row -- mutually exclusive with
    // showCostRow but shares the same bottom slot/height return value.
    showQueueRow     = false;
    queueIconSprite  = noone;
    queueIconImage   = 0;
    queueIconWidth   = 0; // already-scaled px, cached by Layout for Draw
    queueIconHeight  = 0;
    queueFraction    = 0; // 0-1, trainProgress / trainTime
    queueBarWidth    = 0; // already-scaled px, computed fresh in Layout
    queueRowHeight   = 0;

    timerText = scribble("", $"__buildingHoverExtras{__id}Timer__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_center, fa_top);

    limitText = scribble("", $"__buildingHoverExtras{__id}Limit__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_center, fa_top);

    costText = scribble("", $"__buildingHoverExtras{__id}Cost__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_left, fa_top)
        .wrap(HoverCardBodyWrapWidth());

    queueCountText = scribble("", $"__buildingHoverExtras{__id}QueueCount__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_left, fa_middle);

    queueTimeText = scribble("", $"__buildingHoverExtras{__id}QueueTime__")
        .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
        .align(fa_right, fa_middle);

    /// @function Layout(_def, _building, _isBlueprint, _team)
    /// @description Sets this frame's text content and computes extra vertical space for the icon row (top) and cost/queue row (bottom). Feed the result into HoverCard.Show()'s trailing params.
    /// @param {Struct.BuildingDefinition} _def
    /// @param {Id.Instance|Constant.NoOne} _building A placed building instance, or noone when _isBlueprint is true.
    /// @param {Bool} _isBlueprint
    /// @param {Real} _team TEAM.PLAYER or TEAM.ENEMY -- used for the blueprint cost row's discount lookup and BuildingHoverTimerText's live bonus lookup.
    /// @returns {Struct} { topContentHeight, bottomContentHeight } -- already-scaled on-screen px.
    static Layout = function(_def, _building, _isBlueprint, _team) {
        buildingSprite = _def.sprite;

        var _timerString = BuildingHoverTimerText(_def, _building, _isBlueprint, _team);
        hasTimerText = (_timerString != "");
        if (hasTimerText) {
            timerText = scribble(_timerString, $"__buildingHoverExtras{__id}Timer__")
                .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
                .align(fa_center, fa_top);
        }

        var _icon = BuildingHoverItemIcon(_def);
        hasItemIcon = (_icon != undefined);
        itemIconOffsetY = 0;
        if (hasItemIcon) {
            itemIconSprite = _icon.sprite;
            itemIconImage  = _icon.image;

            // Unit smallSprite is bottom-center anchored -- re-center it by
            // offsetting the draw Y down by half its own height. Resource
            // icons (middle-center origin) need no offset.
            if (_def.trainsUnit != undefined) {
                itemIconOffsetY = (sprite_get_height(itemIconSprite) / 2) * HOVER_CARD_SCALE;
            }
        }

        // Production-amount + health label, under the Item/Unit Window --
        // health is always shown (every building has a maxHealth); production
        // amount only when applicable, each prefixed with its own icon.
        var _limitString  = BuildingHoverResourceLimitText(_def, _building, _isBlueprint);
        var _healthString = BuildingHoverHealthText(_def, _building, _isBlueprint);

        hasLimitText = hasItemIcon; // the label block only makes sense under an actual icon
        if (hasLimitText) {
            var _limitCombined = (_limitString != "")
                ? $"[sUIHammer,0]{_limitString}\n[sUIHeart,0]{_healthString}"
                : $"[sUIHeart,0]{_healthString}";

            limitText = scribble(_limitCombined, $"__buildingHoverExtras{__id}Limit__")
                .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
                .align(fa_center, fa_top);
        }

        // Icon row height -- tallest of the 3 columns. Building Window is a
        // fixed height; Timer/Item columns add their label text's (native,
        // unscaled) height under their icon, only when that column has
        // something to show.
        var _buildingColHeight = sprite_get_height(sHoverCardBuildingWindow) * HOVER_CARD_SCALE;

        var _timerColHeight = 0;
        if (hasTimerText) {
            _timerColHeight = (sprite_get_height(sHoverCardTimer) * HOVER_CARD_SCALE)
                + (BUILDING_HOVER_ICON_LABEL_GAP_Y * HOVER_CARD_SCALE)
                + timerText.get_height();
        }

        var _itemColHeight = 0;
        if (hasItemIcon) {
            _itemColHeight = sprite_get_height(sHoverCardUnitWindow) * HOVER_CARD_SCALE;
            if (hasLimitText) {
                _itemColHeight += (BUILDING_HOVER_ICON_LABEL_GAP_Y * HOVER_CARD_SCALE) + limitText.get_height();
            }
        }

        var _rowHeight = max(_buildingColHeight, _timerColHeight, _itemColHeight);
        var _topContentHeight = _rowHeight + (BUILDING_HOVER_ICON_ROW_GAP_TOP * HOVER_CARD_SCALE) + (BUILDING_HOVER_ROW_TO_BODY_GAP * HOVER_CARD_SCALE);

        // Cost row -- blueprint hover only. See .md for the base+discount
        // coloring rules.
        showCostRow = _isBlueprint;
        var _bottomContentHeight = 0;
        if (showCostRow) {
            var _best         = GetBestAvailablePlacementCost(_team, _def);
            var _discountCost = GetDiscountedCost(_def.cost, PLOT_BONUS_DISCOUNT_FRACTION);
            var _costString   = CostToScribbleTextWithDiscount(_def.cost, _discountCost, _best.discountAvailable, _team);
            showCostRow = (_costString != ""); // a free building has nothing to show
            if (showCostRow) {
                costText = scribble(_costString, $"__buildingHoverExtras{__id}Cost__")
                    .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
                    .align(fa_left, fa_top)
                    .wrap(HoverCardBodyWrapWidth());

                _bottomContentHeight = (BUILDING_HOVER_COST_ROW_GAP_TOP * HOVER_CARD_SCALE) + costText.get_height();
            }
        }

        // Queue row -- placed training buildings only, TEAM.PLAYER-only.
        // Mutually exclusive with the cost row above.
        showQueueRow = (!_isBlueprint && _team == TEAM.PLAYER && _def.trainsUnit != undefined);
        if (showQueueRow) {
            var _unitDef = GetUnitDefinition(_def.trainsUnit);
            showQueueRow = (_unitDef != undefined);
        }
        if (showQueueRow) {
            queueIconSprite = _unitDef.icon; // small inline icon (middle-center anchored) -- no re-centering offset needed, unlike the item icon above
            queueIconImage  = 0;
            queueIconWidth  = (queueIconSprite != undefined) ? sprite_get_width(queueIconSprite)  * HOVER_CARD_SCALE : 0;
            queueIconHeight = (queueIconSprite != undefined) ? sprite_get_height(queueIconSprite) * HOVER_CARD_SCALE : 0;

            queueCountText = scribble(string(_building.trainQueue), $"__buildingHoverExtras{__id}QueueCount__")
                .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
                .align(fa_left, fa_middle);

            queueFraction = (_building.trainTime > 0)
                ? clamp(_building.trainProgress / _building.trainTime, 0, 1)
                : 0;

            // Seconds until the FRONT of the queue completes, ceil'd so it
            // doesn't read "0s" early. "-" when nothing's queued.
            var _remainingString = (_building.trainQueue > 0 && _building.trainTime > 0)
                ? $"{ceil(_building.trainTime - _building.trainProgress)}s"
                : "-";
            queueTimeText = scribble(_remainingString, $"__buildingHoverExtras{__id}QueueTime__")
                .starting_format(HOVER_CARD_BODY_FONT, HOVER_CARD_TEXT_COLOR)
                .align(fa_left, fa_middle);

            // Bar is centered on the card's full width -- its left edge sits
            // (margin + icon + gap + count + gap) in from the card's left
            // edge, mirrored on the right, rather than sized around the time
            // text's width; the time text trails the bar instead.
            var _barLeftOffset = (HOVER_CARD_BODY_MARGIN_X * HOVER_CARD_SCALE) + queueIconWidth
                + BUILDING_HOVER_QUEUE_GAP_X + queueCountText.get_width() + BUILDING_HOVER_QUEUE_GAP_X;
            queueBarWidth = max(BUILDING_HOVER_QUEUE_BAR_MIN_WIDTH, (HOVER_CARD_WIDTH * HOVER_CARD_SCALE) - (2 * _barLeftOffset));

            queueRowHeight = max(
                queueIconHeight,
                BUILDING_HOVER_QUEUE_BAR_HEIGHT * HOVER_CARD_SCALE,
                queueCountText.get_height(),
                queueTimeText.get_height()
            );

            _bottomContentHeight = (BUILDING_HOVER_COST_ROW_GAP_TOP * HOVER_CARD_SCALE) + queueRowHeight;
        }

        return { topContentHeight: _topContentHeight, bottomContentHeight: _bottomContentHeight };
    }

    /// @function Draw(_card, _alpha)
    /// @description Call once per Draw GUI event, immediately after _card.Draw(_alpha).
    /// @param {Struct.HoverCard} _card
    /// @param {Real} _alpha
    static Draw = function(_card, _alpha) {
        var _rowTopY      = _card.GetContentTopY();
        var _cardLeftEdge = _card.x;

        // Building icon window -- top-left of the body.
        var _buildingHalfW   = (sprite_get_width(sHoverCardBuildingWindow) / 2) * HOVER_CARD_SCALE;
        var _buildingCenterX = _cardLeftEdge + (HOVER_CARD_BODY_MARGIN_X * HOVER_CARD_SCALE) + _buildingHalfW;
        var _buildingCenterY = _rowTopY + (sprite_get_height(sHoverCardBuildingWindow) / 2) * HOVER_CARD_SCALE;

        draw_sprite_ext(sHoverCardBuildingWindow, 0, _buildingCenterX, _buildingCenterY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);
        if (buildingSprite != noone) {
            draw_sprite_ext(buildingSprite, 0, _buildingCenterX, _buildingCenterY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);
        }

        var _cursorLeftEdge = _buildingCenterX + _buildingHalfW;

        // Item/Unit window is right-anchored with the same margin as the Building Window's left
        // buffer; the Timer column is centered in the space between the two windows.
        var _cardRightEdge = _card.x + (HOVER_CARD_WIDTH * HOVER_CARD_SCALE);
        var _itemHalfW     = (sprite_get_width(sHoverCardUnitWindow) / 2) * HOVER_CARD_SCALE;
        var _itemCenterX   = _cardRightEdge - (HOVER_CARD_BODY_MARGIN_X * HOVER_CARD_SCALE) - _itemHalfW;
        var _rightBoundX   = hasItemIcon ? (_itemCenterX - _itemHalfW) : (_cardRightEdge - (HOVER_CARD_BODY_MARGIN_X * HOVER_CARD_SCALE));

        // Timer icon + text. sHoverCardTimer has a top-center origin (unlike the
        // other two windows' middle-center), so Y = _rowTopY already aligns it.
        if (hasTimerText) {
            var _timerCenterX = (_cursorLeftEdge + _rightBoundX) / 2;

            draw_sprite_ext(sHoverCardTimer, 0, _timerCenterX, _rowTopY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);

            var _timerTextY = _rowTopY + (sprite_get_height(sHoverCardTimer) * HOVER_CARD_SCALE) + (BUILDING_HOVER_ICON_LABEL_GAP_Y * HOVER_CARD_SCALE);
            DrawCardTextWithShadow(timerText, _timerCenterX, _timerTextY, _alpha);
        }

        // Item/Unit window -- rightmost column.
        if (hasItemIcon) {
            var _itemCenterY = _rowTopY + (sprite_get_height(sHoverCardUnitWindow) / 2) * HOVER_CARD_SCALE;

            draw_sprite_ext(sHoverCardUnitWindow, 0, _itemCenterX, _itemCenterY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);
            draw_sprite_ext(itemIconSprite, itemIconImage, _itemCenterX, _itemCenterY + itemIconOffsetY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);

            if (hasLimitText) {
                var _limitTextY = _rowTopY + (sprite_get_height(sHoverCardUnitWindow) * HOVER_CARD_SCALE) + (BUILDING_HOVER_ICON_LABEL_GAP_Y * HOVER_CARD_SCALE);
                DrawCardTextWithShadow(limitText, _itemCenterX, _limitTextY, _alpha);
            }
        }

        // Cost row -- blueprint hover only, below whatever the card itself drew last.
        if (showCostRow) {
            var _costX = _card.x + HOVER_CARD_BODY_MARGIN_X * HOVER_CARD_SCALE;
            var _costY = _card.GetContentBottomY() + BUILDING_HOVER_COST_ROW_GAP_TOP * HOVER_CARD_SCALE;
            DrawCardTextWithShadow(costText, _costX, _costY, _alpha);
        }

        // Queue row -- placed training buildings only, same bottom slot as
        // the cost row (mutually exclusive).
        if (showQueueRow) {
            var _rowLeftX = _card.x + HOVER_CARD_BODY_MARGIN_X * HOVER_CARD_SCALE;
            var _rowTopY2 = _card.GetContentBottomY() + BUILDING_HOVER_COST_ROW_GAP_TOP * HOVER_CARD_SCALE;
            var _rowMidY  = _rowTopY2 + (queueRowHeight / 2);

            var _iconCenterX = _rowLeftX + (queueIconWidth / 2);
            if (queueIconSprite != undefined) {
                draw_sprite_ext(queueIconSprite, queueIconImage, _iconCenterX, _rowMidY, HOVER_CARD_SCALE, HOVER_CARD_SCALE, 0, c_white, _alpha);
            }

            var _countX = _rowLeftX + queueIconWidth + BUILDING_HOVER_QUEUE_GAP_X;
            DrawCardTextWithShadow(queueCountText, _countX, _rowMidY, _alpha);

            // Progress bar -- plain drawn rectangle (not sprite/Scribble),
            // black background, filled in HOVER_CARD_TEXT_COLOR. Centered on
            // the card's full width -- see Layout's comment on the mirrored offset.
            var _barX1 = _countX + queueCountText.get_width() + BUILDING_HOVER_QUEUE_GAP_X;
            var _barLeftOffset = _barX1 - _card.x;
            var _barX2 = _card.x + (HOVER_CARD_WIDTH * HOVER_CARD_SCALE) - _barLeftOffset;
            if (_barX2 - _barX1 < BUILDING_HOVER_QUEUE_BAR_MIN_WIDTH) _barX2 = _barX1 + BUILDING_HOVER_QUEUE_BAR_MIN_WIDTH;
            var _barY1 = _rowMidY - (BUILDING_HOVER_QUEUE_BAR_HEIGHT * HOVER_CARD_SCALE / 2);
            var _barY2 = _rowMidY + (BUILDING_HOVER_QUEUE_BAR_HEIGHT * HOVER_CARD_SCALE / 2);

            draw_set_alpha(_alpha);
            draw_set_color(c_black);
            draw_rectangle(_barX1, _barY1, _barX2, _barY2, false);
            if (queueFraction > 0) {
                draw_set_color(HOVER_CARD_TEXT_COLOR);
                draw_rectangle(_barX1, _barY1, _barX1 + ((_barX2 - _barX1) * queueFraction), _barY2, false);
            }
            draw_set_alpha(1);

            // Time remaining trails the bar's right edge.
            var _timeX = _barX2 + BUILDING_HOVER_QUEUE_GAP_X;
            DrawCardTextWithShadow(queueTimeText, _timeX, _rowMidY, _alpha);
        }
    }
}

/// @function BuildingHoverSuppressed(_selectionController, _blueprintController)
/// @description True while building hover data should not trigger -- targeting, dragging a blueprint, the mouse over the Blueprint UI panel, or the Fate Engine overlay open. Same shape as PlotHoverSuppressed.
/// @param {Struct.SelectionController} _selectionController
/// @param {Struct.BlueprintController} _blueprintController
/// @returns {Bool}
function BuildingHoverSuppressed(_selectionController, _blueprintController) {
    return _selectionController.isTargeting
        || _blueprintController.dragging
        || _blueprintController.IsMouseOverPanel()
        || global.fateEngineOverlayActive
        || TutorialCharacterSpeaking(); // 2026-08-15 bugfix -- see TutorialCharacterSpeaking()'s own comment (PlotHoverScripts.gml) /.md
}

/// @function BuildingHoverController()
/// @description Owns one HoverCard + one BuildingHoverExtras (+ a paired unit card for training buildings) and drives them for placed building instances. Same dwell/fade/anchor pattern as PlotHoverController -- wire into oUnitControl alongside it. See .md.
function BuildingHoverController() constructor {
    card        = new HoverCard();
    extras      = new BuildingHoverExtras();
    hoverTarget = noone; // the oBuildingParent instance currently being dwelt on, or noone
    hoverTimer  = 0;     // real steps (NOT global.matchSpeed), same basis as PlotHoverController
    alpha       = 0;     // current fade level, 0-1

    // Paired unit hover card, shown alongside this card whenever the
    // hovered building trains a unit. See .md.
    unitCard    = new HoverCard();
    unitExtras  = new UnitHoverExtras();
    hasUnitCard = false;

    /// @function Step(_selectionController, _blueprintController)
    /// @description Call once per Step event. Same dwell/fade/positioning structure as PlotHoverController.Step.
    /// @param {Struct.SelectionController} _selectionController
    /// @param {Struct.BlueprintController} _blueprintController
    static Step = function(_selectionController, _blueprintController) {
        var _candidate = noone;
        if (!BuildingHoverSuppressed(_selectionController, _blueprintController)) {
            var _found = instance_position(mouse_x, mouse_y, oBuildingParent);
            if (_found != noone && GetBuildingDefinition(_found.object_index) != undefined) {
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
            var _def = GetBuildingDefinition(hoverTarget.object_index);

            var _sizes = extras.Layout(_def, hoverTarget, false, hoverTarget.team);
            card.Show(_def.name, BuildingHoverDescriptionText(_def), 0, 0, _def.description, _sizes.topContentHeight, _sizes.bottomContentHeight);

            // Paired unit card -- training buildings only. No live unit
            // instance to read from, so _liveUnit is always noone (max HP
            // only). Cost row is always shown -- see .md.
            hasUnitCard = (_def.trainsUnit != undefined);
            if (hasUnitCard) {
                var _unitDef = GetUnitDefinition(_def.trainsUnit);
                hasUnitCard = (_unitDef != undefined);
                if (hasUnitCard) {
                    ShowUnitHoverCard(unitCard, unitExtras, _unitDef, noone, true);
                }
            }

            var _mx = device_mouse_x_to_gui(0);
            var _my = device_mouse_y_to_gui(0);

            // Anchoring is computed against both cards together when a unit
            // card is showing -- see PositionHoverCardPair's doc.
            // _secondaryAlwaysRight = true: the unit card always sits on the
            // building card's right, regardless of cursor quadrant.
            PositionHoverCardPair(_mx, _my, card, hasUnitCard ? unitCard : noone, HOVER_CARD_PAIR_GAP, true);
        }
    }

    /// @function Draw()
    /// @description Call once per Draw GUI event. No-ops while fully faded out.
    static Draw = function() {
        if (alpha <= 0) return;
        card.Draw(alpha);
        extras.Draw(card, alpha);

        if (hasUnitCard) {
            unitCard.Draw(alpha);
            unitExtras.Draw(unitCard, alpha);
        }
    }
}
