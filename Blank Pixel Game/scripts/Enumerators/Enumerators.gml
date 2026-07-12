enum ECreditsState{
    FADE_IN,
    HOLD,
    FADE_OUT,
    DONE
}

enum UnitAnimState {
    WANDER,
    COMBAT
}

enum TEAM {
    PLAYER,
    ENEMY
}

// 2026-07-11 request: which direction a ruler portrait's current animation
// frame is facing -- RulerPortraitScripts.gml uses this to decide which
// animations are legal to play next (an animation can only START once the
// portrait is already facing the direction that animation starts in).
enum FACING {
    LEFT,
    RIGHT
}