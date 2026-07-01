/// @function AnimationLibrary(_idle, _walk, _attack, _special)
/// @description Bundles a unit's core sprites (idle, walk, attack) with any number
///        of extra named animations, exposed as struct fields matching each
///        _special entry's name -- e.g. `myLib.guard` if one entry is
///        {name: "guard", sprite: sprGuard}.
/// @param {Asset.GMSprite} _idle Sprite to use while idle.
/// @param {Asset.GMSprite} _walk Sprite to use while walking.
/// @param {Asset.GMSprite} _attack Sprite to use while attacking.
/// @param {Array<Struct>} [_special] Extra {name, sprite} entries, each added as
///        its own field on the library (e.g. {name: "guard", sprite: sprGuard}).
function AnimationLibrary(_idle, _walk, _attack, _special = []) constructor{
    idle = _idle;
    walk = _walk;
    attack = _attack;
    for(var i = 0; i < array_length(_special); i ++){
        variable_struct_set(self,_special[i].name,_special[i].sprite);
    }
}