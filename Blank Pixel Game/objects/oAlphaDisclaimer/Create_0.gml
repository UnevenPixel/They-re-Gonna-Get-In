disclaimerText = scribble(
    "[fntDisclaimer]PRE-ALPHA BUILD\n\n" +
    "[fntDisclaimerBody]This is an early pre-alpha build of the game.\n" +
    "You may encounter bugs, unexpected behaviours, and unpolished assets.\n\n" +
    "Please report any bugs to our discord under the Bug-Reporting thread.\n\n\n\n" +
    "[wave]Press any key to continue.[/wave]"
);

disclaimerTypist = scribble_typist();
disclaimerTypist.in(1,0);

disclaimerText.wrap(room_width * 0.55)
disclaimerText.align(fa_center,fa_middle);