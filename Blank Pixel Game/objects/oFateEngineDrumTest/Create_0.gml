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
var _centerX = display_get_gui_width() / 2;
var _drumY   = display_get_gui_height() - 338;

drums = [
    new FateDrum(_centerX - 104, _drumY, 56),
    new FateDrum(_centerX,       _drumY, 56),
    new FateDrum(_centerX + 104, _drumY, 56),
];

for (var i = 0; i < array_length(drums); i++) {
    drums[i].Spin();
}
