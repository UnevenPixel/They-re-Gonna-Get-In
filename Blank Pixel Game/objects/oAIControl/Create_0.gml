// One brain per computer-controlled team. Hardcoded to TEAM.ENEMY for now --
// this object represents "the" AI opponent; if the game ever needs the AI to
// play TEAM.PLAYER (e.g. an automated player-side test), promote this to a
// creation-code-set variable the same way oUnitControl's team assumption
// would need to change.
brain = new AIBrain(TEAM.ENEMY);
