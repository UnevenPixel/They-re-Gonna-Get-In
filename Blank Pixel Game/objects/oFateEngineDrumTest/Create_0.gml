// TEMPORARY test harness for the Fate Engine drum render
// (FateEngineDrumScripts.gml) -- verifies the spin / hidden-back-swap /
// land-and-read mechanic in isolation before the real session overlay
// (lock buttons, spin/cash-out flow, corruption) gets built in a later
// task. Remove/replace once that overlay exists.
//
// Layout per 2026-07-05 request: drums centered horizontally on the GUI,
// anchored 338px up from the bottom, at -104/0/+104 from center (already
// accounting for the 2x item render scale -- see FATE_DRUM_ITEM_SCALE,
// FateEngineDrumScripts.gml). Orbit radius (56) isn't specified by that
// request -- placeholder, tune freely.
//
// Per 2026-07-06 request: the whole engine (body + drums) is shifted up
// 268px so it clears the UI's bottom bar. bodyBottomY is kept as an
// instance var so Draw_64 can anchor sFateEngineBody's bottom edge there
// without redoing this math.
//
// Per 2026-07-06 follow-up: drums shifted DOWN by their own whole height
// (orbit diameter, 2 * radius) off that 338px anchor -- no other element
// moves, just the drums relative to the body.
var _centerX     = display_get_gui_width() / 2;
var _bodyOffsetY = 268;
bodyBottomY = display_get_gui_height() - _bodyOffsetY;

var _drumRadius = 56;
var _drumHeight = _drumRadius * 2; // the drum's "whole height" per the 2026-07-06 request
var _drumY = (bodyBottomY - 320) + _drumHeight;

drums = [
    new FateDrum(_centerX - 104, _drumY, _drumRadius),
    new FateDrum(_centerX,       _drumY, _drumRadius),
    new FateDrum(_centerX + 104, _drumY, _drumRadius),
];

for (var i = 0; i < array_length(drums); i++) {
    drums[i].Spin();
}
