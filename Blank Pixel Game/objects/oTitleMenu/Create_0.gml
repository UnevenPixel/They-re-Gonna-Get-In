// Title/main menu setup + looped title music. See oTitleMenu.md.
settingsOverlay = new SettingsOverlay();
creditsOverlay = new CreditsOverlay();

titleMenu = new TitleMenu(settingsOverlay, creditsOverlay);

global.titleMusicInstance = audio_play_sound(sndTitleMusic, 10, true);

// Re-applies volume now that titleMusicInstance actually exists -- see .md.
ApplyGameSettings();
