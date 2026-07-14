# They're Gonna Get In! — Patch Notes

## v0.0.4.1

A round of computer opponent tuning based on player feedback.

### The Computer Opponent

- During the earliest age, the computer opponent now focuses its defenses on protecting its resource production first, rather than spreading itself thin across every building it owns.
- If the computer opponent ever finds itself with no units out on the field while under attack, it will recall units from its garrison and start training reinforcements to respond — and it now keeps a small reserve of gold on hand specifically for this.
- Once the computer opponent's army is full, it will start sending its extra units to attack your other buildings once it's confident it can afford to rebuild what it commits, instead of just sitting idle.
- The computer opponent now earns blueprints as it gains experience, the same way a player would from the Fate Engine.

## v0.0.4.0

Garrisoning arrives — send units home to safety and put them to work behind your walls, where they'll grant real benefits to your kingdom instead of just standing idle. Alongside it: bloodier combat, a smarter and tougher computer opponent, a fully animated ruler portrait, and a big batch of interface polish.

### Build & Economy

- Units can now be sent home to garrison inside your castle for safekeeping via a new Station order, and buildings placed on interior plots will garrison their trained units directly instead of sending them out onto the field.
- Garrisoning and redeploying units costs a small amount of gold. Open your castle's garrison list to see everyone stationed there, and click an entry to bring that unit back out onto the battlefield. Stationing several units at once will station as many as you can afford, cheapest first.
- Garrisoned units now grant real, active bonuses to your kingdom — faster resource production, faster training, or tougher units, depending on who's stationed. Hover over your castle to see exactly which bonuses are currently active.
- Fixed an issue that could let a side quietly train past its intended army limits by garrisoning units.
- Your castle's health and your total army size (versus its current limit) are now both shown directly on the HUD. Click the army readout for a full breakdown by unit type, and click any entry there to instantly select every deployed unit of that kind.

### Combat

- Combat is bloodier now — units leave behind gore and blood splatter when they die, and bleed when struck. (The Mud Golem is made of mud, so it's exempt.)
- The Knight now deals significantly more damage against production buildings.
- The Bomb Goblin now actually dies the instant it detonates, matching its own long-standing description.
- Buildings now kick up debris when struck.
- Fixed blood and gore rendering on top of everything else on screen — it now correctly stays on the ground.

### The Computer Opponent

- Rebalanced to be a tougher, smarter opponent: it always keeps a real portion of its army home when going on the offensive, occasionally launches small early scouting raids, garrisons the units that are more valuable defending than fighting, and spreads its standing defenders across all of its buildings instead of stacking them in one place.
- No longer gets stuck sitting at its own army limit without acting, and now prefers building certain structures inside its own walls so trained units go straight into the garrison.
- Reacts to attacks on its buildings almost instantly, and garrisons its own units for the same passive benefits available to the player.
- Fixed a bug where defenders already posted at one building wouldn't respond when a different building came under attack — they'll now correctly redirect to help wherever the fight actually is.

### Interface & Info

- Your ruler now appears as a fully animated portrait on the UI bar, blinking, glancing around, and reacting idly instead of standing still.
- Interface text throughout the game now uses one consistent color.
- Hovering over a training building shows what's currently queued and how long until the next unit is ready; training buildings also display an always-on progress bar and visibly change appearance while actively training.
- Building info cards now show the real, bonus-adjusted production or training speed, highlighted in green or red when a garrison bonus is helping or hurting it.
- Selecting multiple units brings up a new summary panel grouping them by type — click a group to narrow down to the individual units within it.
- Menus and dropdown panels (orders, castle garrison, unit selection) have a new visual style with proper titles, and now open in whichever direction keeps them fully on screen relative to your cursor.
- You can no longer see what the enemy has queued up in their training buildings.
- Blueprint slots now show at a glance whether you can currently afford and place that building.

### Also

- Fixed a crash that could occur when a selected unit died in battle.
- Numerous smaller fixes and behind-the-scenes cleanup.

## v0.0.3.0

A big development milestone — the core base-building and battle loop is now playable start to finish against a computer opponent, with a full combat system, unit and building info at your fingertips, and a first pass at art and polish across the board.

### Build & Economy

- Place buildings from a new blueprint panel: drag a building out and drop it onto an open plot to construct it.
- Five resource types (wheat, wood, water, gold, and iron) are now produced by dedicated buildings and tracked on a resource bar.
- Resource buildings run dry after producing enough over their lifetime, so a growing economy means building more of them rather than letting one carry you forever.
- Where you build matters: plots closer to the front lines grant sturdier, higher-output buildings, while plots tucked inside your walls are cheaper to build on.
- Train soldiers from dedicated buildings, with both a per-building and an army-wide cap on how many you can field at once.
- Six unit types are now trainable: Peasant, Bomb Goblin, Mud Golem, Soldier, Archer, and Knight — each with its own cost, stats, and personality.

### Combat

- Units can now actually take damage, die, and destroy enemy buildings and each other — combat has real stakes for the first time.
- Archers fire real arrows that arc through the air toward their target instead of just swinging at melee range.
- Units automatically size up nearby threats, weighing health, firepower, distance, and who's currently under attack, so they engage smarter than just "whoever's closest."
- Units guarding or defending will jump into a fight the instant an enemy gets close, or the instant they're struck.
- Siege forces can now strike anywhere along the width of a castle's front wall instead of one fixed point, and reliably reach it without getting stuck on the way.

### The Computer Opponent

- The AI now plays a much more complete game: it grows its economy, trains a balanced army, and mounts sieges once it's actually strong enough to.
- It reacts to threats in real time — rushing defenders to a building under attack, and abandoning an assault altogether to rush home if its own castle comes under fire.

### Interface & Info

- Hovering over a plot, building, or blueprint now brings up an info card showing what it does, its cost, and its health.
- Selecting a single unit, or checking out a unit a barracks-type building trains, now shows a dedicated card with that unit's health, damage, and abilities.
- A new XP bar tracks progress through the game's Age system, with milestone rewards and a small token-toss animation when you hit one.
- Enemy units are now visually recolored so you can tell the two sides apart at a glance.
- A first, early look at the "Fate Engine" reward mechanic — a spinning-reel visual effect — has been added as groundwork for a future feature.

### Also

- Numerous smaller fixes across unit movement, targeting, selection, and camera controls to make everything feel more responsive and reliable.
